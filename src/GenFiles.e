/*
** DelphE code generator: files. Creates the user's program file or brings it up to date,
** finds handlers whose form is gone, and writes the program the compiler gets (the user's
** file with the generated file inserted at its marker).
*/

OPT MODULE
OPT EXPORT
OPT LARGE

MODULE 'dos/dos', 'exec/memory', '*FormModel', '*Util', '*GenOut', '*GenRuntime', '*Generator'

-> Old-style files had the generated code inside them between DELPHE BEGIN/END
-> markers. Returns the text without those regions, with the marker line where the
-> first one was, and its length; NIL if a region has no END.
PROC stripRegions(buf, len)
  DEF out, o, p, b, e, eEnd, first, m
  out := NewM(len + 200, MEMF_PUBLIC)
  o := 0
  p := 0
  first := TRUE
  b := InStr(buf, beginMark())
  WHILE b <> -1
    e := InStr(buf, endMark(), b)
    IF e = -1 THEN RETURN NIL, 0
    eEnd := InStr(buf, '\n', e)
    IF eEnd = -1 THEN eEnd := len ELSE eEnd := eEnd + 1
    CopyMem(buf + p, out + o, b - p)
    o := o + (b - p)
    IF first
      m := userMarkLine()
      CopyMem(m, out + o, StrLen(m))
      o := o + StrLen(m)
      out[o] := 10
      o++
      first := FALSE
    ENDIF
    p := eEnd
    b := InStr(buf, beginMark(), p)
  ENDWHILE
  CopyMem(buf + p, out + o, len - p)
  o := o + (len - p)
  out[o] := 0
ENDPROC out, o

PROC isIdentCh(c) IS ((c >= "A") AND (c <= "Z")) OR ((c >= "a") AND (c <= "z")) OR ((c >= "0") AND (c <= "9")) OR (c = "_")

-> The handlers in the user's text that belong to a form or frame that no longer
-> exists: "PROC name() OF tType" where tType is none of these forms and frames, is
-> not one of the helper types and is not an object the user defined. Hands the list of them
-> (comma separated) to setOrphans.
PROC scanOrphans(buf: PTR TO CHAR, forms: PTR TO LONG, n)
  DEF p, q, tn, start, i, known, typeName, name, pat, win: PTR TO component, count, list
  list := String(300)
  count := 0
  p := InStr(buf, '() OF t')
  WHILE p <> -1
    start := p
    WHILE (start > 0) AND isIdentCh(buf[start - 1]) DO start--
    q := p + 7
    tn := q
    WHILE isIdentCh(buf[tn]) DO tn++
    typeName := String(tn - q + 1)
    IF tn > q THEN MidStr(typeName, buf, q, tn - q)
    known := FALSE
    FOR i := 0 TO n - 1
      win := forms[i]
      IF StrLen(win.name) = StrLen(typeName)
        IF StrCmp(win.name, typeName, ALL) THEN known := TRUE
      ENDIF
    ENDFOR
    IF StrCmp(typeName, 'FileDialog', ALL) AND (StrLen(typeName) = 10) THEN known := TRUE
    IF StrCmp(typeName, 'MessageDialog', ALL) AND (StrLen(typeName) = 13) THEN known := TRUE
    IF known = FALSE
      pat := String(StrLen(typeName) + 12)
      StrCopy(pat, 'OBJECT t', ALL)
      StrAdd(pat, typeName, ALL)
      IF InStr(buf, pat) <> -1 THEN known := TRUE
    ENDIF
    IF known = FALSE
      count++
      IF count > 1 THEN StrAdd(list, ', ', ALL)
      name := String(p - start + 1)
      IF p > start THEN MidStr(name, buf, start, p - start)
      StrAdd(list, name, ALL)
      StrAdd(list, ' (t', ALL)
      StrAdd(list, typeName, ALL)
      StrAdd(list, ')', ALL)
    ENDIF
    p := InStr(buf, '() OF t', tn)
  ENDWHILE
  IF count = 0 THEN list := NIL
  setOrphans(list)
ENDPROC

-> Does any window have an OnClose handler?
PROC anyWindowHandler(forms: PTR TO LONG, n)
  DEF i, f: PTR TO component
  FOR i := 0 TO n - 1
    f := forms[i]
    IF f.kind = CK_WINDOW
      IF f.handler THEN RETURN TRUE
    ENDIF
  ENDFOR
ENDPROC FALSE

/*
** Creates the user's program file, or brings it up to date: handler stubs are
** appended for handlers it does not define yet, and an old-style file (with the
** generated code inside it) is converted, keeping the old one as path.bak.
** projName is NIL for a single form. Returns GEN_OK, GEN_WRITEFAIL or
** GEN_NOMARKERS (the file has neither marker, so it is not one of ours).
*/
PROC syncUserFile(path, projName, forms: PTR TO LONG, n)
  DEF buf, len, cur, clen, fh, i, win: PTR TO component, appended: PTR TO strbuf, old, res

  appended := sbNew()
  setOrphans(NIL)
  setOldLoop(FALSE)
  buf, len := readAll(path)

  IF buf = NIL
    FOR i := 0 TO n - 1
      win := forms[i]
      collectStubs(win, '', appended, win)
    ENDFOR
    fh := Open(path, MODE_NEWFILE)
    IF fh = NIL
      sbFree(appended)
      RETURN GEN_WRITEFAIL
    ENDIF
    win := forms[0]
    IF projName THEN genProjectHeader(fh, projName) ELSE genHeader(fh, win)
    put(fh, '\n/*** your code ***/\n')
    putMem(fh, appended.buf, appended.len)
    IF projName THEN genProjectMain(fh) ELSE genMain(fh, win)
    closeOut(fh)
    sbFree(appended)
    RETURN GEN_OK
  ENDIF

  res := GEN_OK
  old := FALSE
  cur := buf
  clen := len
  IF InStr(buf, beginMark()) <> -1
    cur, clen := stripRegions(buf, len)
    IF cur = NIL
      res := GEN_NOMARKERS
    ELSE
      old := TRUE
    ENDIF
  ELSEIF InStr(buf, userMark()) = -1
    res := GEN_NOMARKERS
  ENDIF

  IF res = GEN_OK
    scanOrphans(cur, forms, n)
    setOldLoop(FALSE)
    IF InStr(cur, 'delpheRun()') = -1
      IF anyUses(forms, n, CK_TIMER) OR anyWindowHandler(forms, n) THEN setOldLoop(TRUE)
    ENDIF
    FOR i := 0 TO n - 1
      win := forms[i]
      collectStubs(win, cur, appended, win)
    ENDFOR
    IF (old OR (appended.len > 0))
      IF old THEN writeBackup(path, buf, len)
      fh := Open(path, MODE_NEWFILE)
      IF fh = NIL
        res := GEN_WRITEFAIL
      ELSE
        putMem(fh, cur, clen)
        putMem(fh, appended.buf, appended.len)
        closeOut(fh)
      ENDIF
    ENDIF
  ENDIF

  -> the file was read for this one job: give its memory back
  IF (cur <> NIL) AND (cur <> buf) THEN Dispose(cur)
  Dispose(buf)
  sbFree(appended)
ENDPROC res

-> Replaces @@FIRST@@, @@LINES@@ and @@CODE@@ in the generated text with numbers. It stays on
-> its line, so no line numbers move. Returns the new text and its length.
PROC expandMarks(g: PTR TO CHAR, glen, first, glines, codeLines)
  DEF out: PTR TO CHAR, o, i, num: PTR TO CHAR, n
  out := NewM(glen + 64, MEMF_PUBLIC)
  num := String(16)
  o := 0
  i := 0
  WHILE i < glen
    IF (g[i] = "@") AND (g[i + 1] = "@")
      n := -1
      IF StrCmp(g + i, '@@FIRST@@', 9)
        StringF(num, '\d', first)
        n := 9
      ELSEIF StrCmp(g + i, '@@LINES@@', 9)
        StringF(num, '\d', glines)
        n := 9
      ELSEIF StrCmp(g + i, '@@CODE@@', 8)
        StringF(num, '\d', codeLines)
        n := 8
      ENDIF
      IF n > 0
        CopyMem(num, out + o, StrLen(num))
        o := o + StrLen(num)
        i := i + n
      ELSE
        out[o] := g[i]
        o++
        i++
      ENDIF
    ELSE
      out[o] := g[i]
      o++
      i++
    ENDIF
  ENDWHILE
  out[o] := 0
  DisposeLink(num)
ENDPROC out, o


-> Writes the program the compiler gets: the user's file with the generated file inserted after
-> its marker line. Returns the number of the first inserted line and how many lines were
-> inserted, so that compiler messages can be traced back, or -1, 0 if the files cannot be
-> read or have no marker.
PROC buildSource(userPath, buildPath)
  DEF buf, len, gbuf, glen, g2, g2len, m, nx, fh, i, first, glines, cm, codeLine, codeLines, gp
  gp := genPath(userPath)
  buf, len := readAll(userPath)
  gbuf, glen := readAll(gp)
  DisposeLink(gp)
  IF (buf = NIL) OR (gbuf = NIL)
    IF buf THEN Dispose(buf)
    IF gbuf THEN Dispose(gbuf)
    RETURN -1, 0
  ENDIF
  m := InStr(buf, userMark())
  IF m = -1
    Dispose(buf)
    Dispose(gbuf)
    RETURN -1, 0
  ENDIF
  nx := InStr(buf, '\n', m)
  IF nx = -1 THEN nx := len ELSE nx := nx + 1

  first := 1
  FOR i := 0 TO nx - 1
    IF buf[i] = 10 THEN first++
  ENDFOR
  glines := 0
  FOR i := 0 TO glen - 1
    IF gbuf[i] = 10 THEN glines++
  ENDFOR
  IF glen > 0
    IF gbuf[glen - 1] <> 10 THEN glines++
  ENDIF

  -> the line of the user's file that the code starts on (after the "your code" comment)
  codeLine := nx
  cm := InStr(buf, '/*** your code ***/', nx)
  IF cm <> -1
    codeLine := InStr(buf, '\n', cm)
    IF codeLine = -1 THEN codeLine := len ELSE codeLine := codeLine + 1
  ENDIF
  codeLines := 0
  FOR i := 0 TO codeLine - 1
    IF buf[i] = 10 THEN codeLines++
  ENDFOR
  g2, g2len := expandMarks(gbuf, glen, first, glines, codeLines)
  Dispose(gbuf)

  fh := Open(buildPath, MODE_NEWFILE)
  IF fh = NIL
    Dispose(buf)
    Dispose(g2)
    RETURN -1, 0
  ENDIF
  Write(fh, buf, nx)
  Write(fh, g2, g2len)
  IF g2len > 0
    IF g2[g2len - 1] <> 10 THEN Write(fh, '\n', 1)
  ENDIF
  IF len > nx THEN Write(fh, buf + nx, len - nx)
  Close(fh)
  Dispose(buf)
  Dispose(g2)
ENDPROC first, glines

-> Writes the generated file (path.gen.e) and updates the user's file. Returns
-> GEN_OK, GEN_WRITEFAIL or GEN_NOMARKERS.
PROC generateFile(path, win: PTR TO component)
ENDPROC generateProject(path, win.name, [win], 1)


/*
** Writes the generated file of a project (path.gen.e): one OBJECT region per
** form, the globals region, one procedure region per form and the run region,
** then updates the user's file. forms is a list of window components (the
** first is the main form). Returns GEN_OK, GEN_WRITEFAIL or GEN_NOMARKERS.
*/
PROC generateProject(path, projName, forms: PTR TO LONG, n)
  DEF fh, i, win: PTR TO component, tag, all, total

  win := forms[0]
  setMainForm(win.name)

  all := withFrames(path, forms, n)
  total := ListLen(all)
  fh := openGenFile(genPath(path))
  IF fh = NIL THEN RETURN GEN_WRITEFAIL
  genConstants(fh, all, total)
  genRuntimeTypes(fh, all, total)
  -> the objects of the frames, then of the forms
  FOR i := n TO total - 1
    win := ListItem(all, i)
    tag := formTag('type', win)
    genRegion(fh, win, tag, 1)
    DisposeLink(tag)
  ENDFOR
  FOR i := 0 TO n - 1
    win := forms[i]
    tag := formTag('type', win)
    genRegion(fh, win, tag, 1)
    DisposeLink(tag)
  ENDFOR
  genGlobalsRegion(fh, forms, n)
  genRuntimeProcs(fh, all, total)
  FOR i := n TO total - 1
    win := ListItem(all, i)
    tag := formTag('form', win)
    genRegion(fh, win, tag, 2)
    DisposeLink(tag)
  ENDFOR
  FOR i := 0 TO n - 1
    win := forms[i]
    tag := formTag('form', win)
    genRegion(fh, win, tag, 2)
    DisposeLink(tag)
  ENDFOR
  genRunRegion(fh, projName, forms, n)
  closeOut(fh)
ENDPROC syncUserFile(path, projName, all, total)
