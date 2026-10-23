# Builds the Toolbar.mcc image strips (IFF ILBM, 5 bitplanes, colour 0 transparent) from the
# 16x16 PNG icons of the LED icon pack (led24.de, CC BY-SA 3.0).
#
#   powershell -File tools\make-icons.ps1 -IconDir <path to led_icons_icons_pack_120731>
#
# Output: Images\actions.iff and Images\components.iff
param([string]$IconDir = 'Z:\Amiga\XFer\icons\led_icons_icons_pack_120731',
      [string]$OutDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'Images'))

Add-Type -AssemblyName System.Drawing

$strips = [ordered]@{
  'actions'    = 'package', 'box', 'page_2', 'folder', 'disk', 'application_delete', 'eye', 'cog', 'hammer', 'control_play'
  'components' = 'layout_split_vertical', 'layout_split', 'tab', 'font', 'textfield', 'accept',
                 'ui_combo_box', 'target', 'ui_slider_2', 'chart_bar', 'application_view_list'
}
$planes = 5
$colours = 1 -shl $planes
$background = @(170, 170, 170)      # palette entry 0: the transparent colour

function Get-Pixels($names) {
  $list = @()
  for ($i = 0; $i -lt $names.Count; $i++) {
    $bmp = [System.Drawing.Bitmap]::FromFile((Join-Path $IconDir ($names[$i] + '.png')))
    if ($bmp.Width -ne 16 -or $bmp.Height -ne 16) { throw "$($names[$i]) is not 16x16" }
    $list += , $bmp
  }
  return $list
}

# median-cut palette over every opaque pixel of one strip
function Get-Palette($bitmaps, $count) {
  $px = New-Object System.Collections.Generic.List[object]
  foreach ($b in $bitmaps) {
    for ($y = 0; $y -lt 16; $y++) { for ($x = 0; $x -lt 16; $x++) {
      $c = $b.GetPixel($x, $y)
      if ($c.A -ge 128) { $px.Add(@($c.R, $c.G, $c.B)) }
    } }
  }
  $boxes = New-Object System.Collections.Generic.List[object]
  $boxes.Add($px)
  while ($boxes.Count -lt $count) {
    $best = -1; $bestRange = -1; $bestCh = 0
    for ($i = 0; $i -lt $boxes.Count; $i++) {
      $bx = $boxes[$i]; if ($bx.Count -lt 2) { continue }
      for ($ch = 0; $ch -lt 3; $ch++) {
        $min = 255; $max = 0
        foreach ($p in $bx) { if ($p[$ch] -lt $min) { $min = $p[$ch] }; if ($p[$ch] -gt $max) { $max = $p[$ch] } }
        if (($max - $min) -gt $bestRange) { $bestRange = $max - $min; $best = $i; $bestCh = $ch }
      }
    }
    if ($best -lt 0 -or $bestRange -le 0) { break }
    $bx = $boxes[$best]
    $sorted = @($bx | Sort-Object { $_[$bestCh] })
    $mid = [int]($sorted.Count / 2)
    $a = New-Object System.Collections.Generic.List[object]; $b2 = New-Object System.Collections.Generic.List[object]
    for ($k = 0; $k -lt $sorted.Count; $k++) { if ($k -lt $mid) { $a.Add($sorted[$k]) } else { $b2.Add($sorted[$k]) } }
    $boxes.RemoveAt($best); $boxes.Add($a); $boxes.Add($b2)
  }
  $pal = New-Object System.Collections.Generic.List[object]
  foreach ($bx in $boxes) {
    $r = 0; $g = 0; $bl = 0
    foreach ($p in $bx) { $r += $p[0]; $g += $p[1]; $bl += $p[2] }
    $n = [math]::Max($bx.Count, 1)
    $pal.Add(@([int]($r / $n), [int]($g / $n), [int]($bl / $n)))
  }
  return $pal
}

function Nearest($pal, $r, $g, $b) {
  $bestI = 1; $bestD = [int]::MaxValue
  for ($i = 0; $i -lt $pal.Count; $i++) {
    $dr = $pal[$i][0] - $r; $dg = $pal[$i][1] - $g; $db = $pal[$i][2] - $b
    $d = 3 * $dr * $dr + 4 * $dg * $dg + 2 * $db * $db
    if ($d -lt $bestD) { $bestD = $d; $bestI = $i }
  }
  return $bestI + 1          # entry 0 is the background
}

function BE16([int]$v) { return [byte[]]@((($v -shr 8) -band 255), ($v -band 255)) }
function BE32([int]$v) { return [byte[]]@((($v -shr 24) -band 255), (($v -shr 16) -band 255), (($v -shr 8) -band 255), ($v -band 255)) }
function Chunk([string]$id, [byte[]]$data) {
  $out = [System.Collections.Generic.List[byte]]::new()
  $out.AddRange([System.Text.Encoding]::ASCII.GetBytes($id)); $out.AddRange([byte[]](BE32 $data.Length)); $out.AddRange($data)
  if ($data.Length % 2) { $out.Add(0) }
  return $out.ToArray()
}

New-Item -ItemType Directory -Force $OutDir | Out-Null
foreach ($name in $strips.Keys) {
  $names = $strips[$name]
  $bitmaps = Get-Pixels $names
  $pal = Get-Palette $bitmaps ($colours - 1)
  # Toolbar.mcc wants N icons of width x as N*x+(N-1): 1 pixel separator columns
  $w = 17 * $names.Count - 1; $h = 16; $rowBytes = 2 * [int][math]::Floor(($w + 15) / 16)

  # chunky index per pixel; 0 = transparent
  $idx = New-Object 'int[,]' $h, $w
  $mask = New-Object 'bool[,]' $h, $w
  for ($i = 0; $i -lt $bitmaps.Count; $i++) {
    for ($y = 0; $y -lt 16; $y++) { for ($x = 0; $x -lt 16; $x++) {
      $c = $bitmaps[$i].GetPixel($x, $y)
      if ($c.A -ge 128) { $idx[$y, (17 * $i + $x)] = Nearest $pal $c.R $c.G $c.B }
    } }
  }

  $body = [System.Collections.Generic.List[byte]]::new()
  for ($y = 0; $y -lt $h; $y++) {
    for ($p = 0; $p -lt $planes; $p++) {          # bitplanes only: colour 0 is the transparent colour
      $row = New-Object byte[] $rowBytes
      for ($x = 0; $x -lt $w; $x++) {
        $bit = $false
        $bit = (($idx[$y, $x] -shr $p) -band 1) -eq 1
        if ($bit) { $byteIx = [int][math]::Floor($x / 8); $row[$byteIx] = $row[$byteIx] -bor (0x80 -shr ($x % 8)) }
      }
      $body.AddRange([byte[]]$row)
    }
  }

  $bmhd = [System.Collections.Generic.List[byte]]::new()
  $bmhd.AddRange([byte[]](BE16 $w)); $bmhd.AddRange([byte[]](BE16 $h)); $bmhd.AddRange([byte[]](BE16 0)); $bmhd.AddRange([byte[]](BE16 0))
  $bmhd.Add($planes); $bmhd.Add(2); $bmhd.Add(0); $bmhd.Add(0)     # planes, mskHasTransparentColor, no compression, pad
  $bmhd.AddRange([byte[]](BE16 0)); $bmhd.Add(1); $bmhd.Add(1); $bmhd.AddRange([byte[]](BE16 $w)); $bmhd.AddRange([byte[]](BE16 $h))

  $cmap = New-Object byte[] (3 * $colours)
  $cmap[0] = $background[0]; $cmap[1] = $background[1]; $cmap[2] = $background[2]
  for ($i = 0; $i -lt $pal.Count; $i++) { for ($k = 0; $k -lt 3; $k++) { $cmap[3 * ($i + 1) + $k] = [byte]$pal[$i][$k] } }

  $form = [System.Collections.Generic.List[byte]]::new()
  $form.AddRange([System.Text.Encoding]::ASCII.GetBytes('ILBM'))
  $form.AddRange([byte[]](Chunk 'BMHD' $bmhd.ToArray())); $form.AddRange([byte[]](Chunk 'CMAP' $cmap)); $form.AddRange([byte[]](Chunk 'BODY' $body.ToArray()))
  $file = [System.Collections.Generic.List[byte]]::new()
  $file.AddRange([System.Text.Encoding]::ASCII.GetBytes('FORM')); $file.AddRange([byte[]](BE32 $form.Count)); $file.AddRange([byte[]]$form.ToArray())
  $path = Join-Path $OutDir ($name + '.iff')
  [System.IO.File]::WriteAllBytes($path, $file.ToArray())
  "{0}: {1} icons, {2}x{3}, {4} colours -> {5}" -f $name, $names.Count, $w, $h, ($pal.Count + 1), $path
  foreach ($b in $bitmaps) { $b.Dispose() }
}
