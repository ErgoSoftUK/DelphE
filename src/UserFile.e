/*
** DelphE user file sections.
**
** The program file a user edits has three parts, which the Code tab shows in three
** editors:
**
**   modules      the header comment, OPT and MODULE lines
**   ->>> DELPHE GLOBALS ...
**   globals      DEF, CONST and OBJECT: everything global, which E wants before any PROC
**   ->>> DELPHE GENERATED CODE ...
**   code         your procedures and main()
**
** The file stays one plain E file; these procedures cut it into the parts and put the
** parts back together. Files from before the globals marker are split by guessing:
** everything up to the last MODULE statement is modules, the rest above the generated
** code is globals.
*/

OPT MODULE
OPT EXPORT

MODULE 'exec/memory', '*Generator'

OBJECT sections
  modText: PTR TO CHAR      -> each text is zero-terminated memory: free with freeSections()
  modLen
  globText: PTR TO CHAR
  globLen
  codeText: PTR TO CHAR
  codeLen
  hasMarker                 -> does the file have the DELPHE GENERATED CODE line?
  globStart                 -> line of the file where the globals text starts (0 = the first)
  codeStart                 -> line of the file where the code text starts
ENDOBJECT

-> The comment that opens the code part; the code editor starts after it
PROC codeMark() IS '/*** your code ***/'

-> A copy of buf from index a up to (not including) b, as zero-terminated memory
PROC copyRegion(buf: PTR TO CHAR, a, b)
  DEF out: PTR TO CHAR, n
  n := b - a
  IF n < 0 THEN n := 0
  out := AllocVec(n + 2, MEMF_PUBLIC OR MEMF_CLEAR)
  IF out = NIL THEN RETURN NIL
  IF n > 0 THEN CopyMem(buf + a, out, n)
  out[n] := 0
ENDPROC out

-> The index where the line holding index p starts
PROC lineStartOf(buf: PTR TO CHAR, p)
  WHILE (p > 0) AND (buf[p - 1] <> 10) DO p--
ENDPROC p

-> The index just after the end of the line holding p, or len
PROC afterLine(buf: PTR TO CHAR, p, len)
  WHILE (p < len) AND (buf[p] <> 10) DO p++
  IF p < len THEN p++
ENDPROC p

-> How many lines come before index p
PROC linesBefore(buf: PTR TO CHAR, p)
  DEF i, n
  n := 0
  FOR i := 0 TO p - 1
    IF buf[i] = 10 THEN n++
  ENDFOR
ENDPROC n

-> Does the line starting at a (and ending before b) start with the word MODULE?
PROC isModuleLine(buf: PTR TO CHAR, a, b)
  IF (b - a) < 6 THEN RETURN FALSE
ENDPROC StrCmp(buf + a, 'MODULE', 6)

-> Does the line from a to b end in a comma (ignoring spaces and CR)? A MODULE statement
-> continues on the next line then.
PROC endsInComma(buf: PTR TO CHAR, a, b)
  DEF p
  p := b - 1
  WHILE (p >= a) AND ((buf[p] = 10) OR (buf[p] = 13) OR (buf[p] = " ") OR (buf[p] = 9)) DO p--
  IF p < a THEN RETURN FALSE
ENDPROC buf[p] = ","

-> Cuts the file text into its three parts
PROC splitSections(buf: PTR TO CHAR, len)
  DEF s: PTR TO sections, m, mStart, afterM, g, gStart, gAfter, pos, modEnd, cont, le, e, cm
  NEW s
  m := InStr(buf, userMark())
  IF m = -1
    -> not a DelphE file: all of it is code
    s.hasMarker := FALSE
    s.codeText := copyRegion(buf, 0, len)
    s.codeLen := len
    s.modText := copyRegion(buf, 0, 0)
    s.globText := copyRegion(buf, 0, 0)
    RETURN s
  ENDIF
  s.hasMarker := TRUE
  mStart := lineStartOf(buf, m)
  afterM := afterLine(buf, m, len)

  g := InStr(buf, globalsMark())
  IF (g <> -1) AND (g < mStart)
    gStart := lineStartOf(buf, g)
    gAfter := afterLine(buf, g, len)
    s.modText := copyRegion(buf, 0, gStart)
    s.modLen := gStart
    s.globText := copyRegion(buf, gAfter, mStart)
    s.globLen := mStart - gAfter
    s.globStart := linesBefore(buf, gAfter)
  ELSE
    -> no globals line yet: the modules end with the last MODULE statement
    pos := 0
    modEnd := 0
    cont := FALSE
    WHILE pos < mStart
      e := afterLine(buf, pos, len)
      IF e > mStart THEN e := mStart
      le := e
      IF cont OR isModuleLine(buf, pos, le)
        modEnd := e
        cont := endsInComma(buf, pos, le)
      ELSE
        cont := FALSE
      ENDIF
      pos := e
    ENDWHILE
    IF modEnd = 0 THEN modEnd := mStart
    -> blank lines between the parts belong to neither
    pos := modEnd
    WHILE (pos < mStart) AND (buf[pos] = 10) DO pos++
    s.modText := copyRegion(buf, 0, modEnd)
    s.modLen := modEnd
    s.globText := copyRegion(buf, pos, mStart)
    s.globLen := mStart - pos
    s.globStart := linesBefore(buf, pos)
  ENDIF
  -> the code starts after the "your code" comment, if there is one
  cm := InStr(buf, codeMark(), afterM)
  IF cm <> -1 THEN afterM := afterLine(buf, cm, len)
  s.codeText := copyRegion(buf, afterM, len)
  s.codeLen := len - afterM
  s.codeStart := linesBefore(buf, afterM)
ENDPROC s

PROC freeSections(s: PTR TO sections)
  IF s.modText THEN FreeVec(s.modText)
  IF s.globText THEN FreeVec(s.globText)
  IF s.codeText THEN FreeVec(s.codeText)
  END s
ENDPROC

-> Writes text into out at o; returns the new offset. Adds a newline if the text does not
-> end in one.
PROC putSection(out: PTR TO CHAR, o, text: PTR TO CHAR)
  DEF n
  n := StrLen(text)
  IF n > 0
    CopyMem(text, out + o, n)
    o := o + n
    IF out[o - 1] <> 10
      out[o] := 10
      o++
    ENDIF
  ENDIF
ENDPROC o

-> Puts the three parts back together, with the marker lines between them. Returns the
-> text (free it with FreeVec) and its length.
PROC joinSections(modText: PTR TO CHAR, globText: PTR TO CHAR, codeText: PTR TO CHAR)
  DEF out: PTR TO CHAR, o, gm, um, n
  gm := globalsMarkLine()
  um := userMarkLine()
  n := StrLen(modText) + StrLen(globText) + StrLen(codeText) + StrLen(gm) + StrLen(um) + 32
  out := AllocVec(n, MEMF_PUBLIC OR MEMF_CLEAR)
  IF out = NIL THEN RETURN NIL, 0
  o := 0
  o := putSection(out, o, modText)
  o := putSection(out, o, gm)
  o := putSection(out, o, globText)
  o := putSection(out, o, um)
  -> the "your code" comment, then the code as it is
  CopyMem('\n/*** your code ***/\n', out + o, 21)
  o := o + 21
  n := StrLen(codeText)
  IF n > 0
    CopyMem(codeText, out + o, n)
    o := o + n
  ENDIF
  out[o] := 0
ENDPROC out, o

/*** the module list ***/

-> The modules section as the Modules control wants it: everything except the MODULE
-> statements ("pre": the header comment, OPT lines, ...) and the names of the modules,
-> one per line, as zero-terminated memory to free with FreeVec. NIL, NIL if out of memory.
PROC parseModules(text: PTR TO CHAR, len)
  DEF pre: PTR TO CHAR, names: PTR TO CHAR, po, no, pos, e, i, c, inq, cont
  pre := AllocVec(len + 2, MEMF_PUBLIC OR MEMF_CLEAR)
  names := AllocVec(len + 2, MEMF_PUBLIC OR MEMF_CLEAR)
  IF (pre = NIL) OR (names = NIL)
    IF pre THEN FreeVec(pre)
    IF names THEN FreeVec(names)
    RETURN NIL, NIL
  ENDIF
  po := 0
  no := 0
  pos := 0
  cont := FALSE
  inq := FALSE
  WHILE pos < len
    e := afterLine(text, pos, len)
    IF cont OR isModuleLine(text, pos, e)
      -> a MODULE statement: the names are what is between the apostrophes
      FOR i := pos TO e - 1
        c := text[i]
        IF inq
          IF c = 39
            inq := FALSE
            names[no] := 10
            no++
          ELSEIF (c <> 10) AND (c <> 13)
            names[no] := c
            no++
          ENDIF
        ELSEIF c = 39
          inq := TRUE
        ENDIF
      ENDFOR
      cont := endsInComma(text, pos, e)
    ELSE
      FOR i := pos TO e - 1
        pre[po] := text[i]
        po++
      ENDFOR
      cont := FALSE
    ENDIF
    pos := e
  ENDWHILE
  pre[po] := 0
  names[no] := 0
ENDPROC pre, names

-> The names as they are shown in one line: 'muimaster', 'libraries/mui'
PROC moduleDisplay(names: PTR TO CHAR)
  DEF out: PTR TO CHAR, o, i, n, first, c
  n := StrLen(names)
  out := AllocVec((n * 2) + 8, MEMF_PUBLIC OR MEMF_CLEAR)
  IF out = NIL THEN RETURN NIL
  o := 0
  first := TRUE
  FOR i := 0 TO n - 1
    c := names[i]
    IF first
      IF o > 0
        out[o] := ","
        out[o + 1] := " "
        o := o + 2
      ENDIF
      out[o] := 39
      o++
      first := FALSE
    ENDIF
    IF c = 10
      out[o] := 39
      o++
      first := TRUE
    ELSE
      out[o] := c
      o++
    ENDIF
  ENDFOR
  out[o] := 0
ENDPROC out

-> The modules section for the file: pre, then one MODULE statement naming the modules,
-> wrapped to fit, then a blank line. Zero-terminated memory to free with FreeVec.
PROC buildModules(pre: PTR TO CHAR, names: PTR TO CHAR)
  DEF out: PTR TO CHAR, o, i, n, col, start, k, wl
  n := StrLen(names)
  out := AllocVec(StrLen(pre) + (n * 3) + 80, MEMF_PUBLIC OR MEMF_CLEAR)
  IF out = NIL THEN RETURN NIL
  o := 0
  o := putSection(out, o, pre)
  IF n > 0
    CopyMem('MODULE ', out + o, 7)
    o := o + 7
    col := 7
    start := 0
    FOR i := 0 TO n - 1
      IF names[i] = 10
        wl := i - start
        IF start > 0
          -> after the first: a comma, and a new line when this one would run past 72
          IF col + wl + 4 > 72
            CopyMem(',\n       ', out + o, 9)
            o := o + 9
            col := 7
          ELSE
            CopyMem(', ', out + o, 2)
            o := o + 2
            col := col + 2
          ENDIF
        ENDIF
        out[o] := 39
        o++
        FOR k := start TO i - 1
          out[o] := names[k]
          o++
        ENDFOR
        out[o] := 39
        o++
        col := col + wl + 2
        start := i + 1
      ENDIF
    ENDFOR
    out[o] := 10
    out[o + 1] := 10
    o := o + 2
  ENDIF
  out[o] := 0
ENDPROC out
