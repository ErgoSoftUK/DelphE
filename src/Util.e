/*
** DelphE shared helpers: command line and file handling.
*/

OPT MODULE
OPT EXPORT

MODULE 'dos/dos', 'exec/memory', 'asl', 'libraries/asl'

-> The command line arrives with a trailing linefeed (and maybe quotes);
-> returns a clean copy as an E-string, empty if there was no argument.
PROC cleanArg()
  DEF s, n
  s := String(StrLen(arg) + 1)
  StrCopy(s, arg, ALL)
  n := StrLen(s)
  WHILE (n > 0) AND (s[n - 1] <= " ") DO n--
  SetStr(s, n)
  IF (n > 1) AND (s[0] = 34) AND (s[n - 1] = 34)
    StrCopy(s, s + 1, n - 2)
  ENDIF
ENDPROC s

PROC canOpen(name)
  DEF fh
  fh := Open(name, MODE_OLDFILE)
  IF fh THEN Close(fh)
ENDPROC fh <> 0

-> The sample form, found from the DelphE drawer or from src
PROC defaultFormPath()
  IF canOpen('forms/sample.mform') THEN RETURN 'forms/sample.mform'
ENDPROC '/forms/sample.mform'

-> Copies a C-style string into a new E-string
PROC copyStr(p)
  DEF s
  s := String(StrLen(p) + 1)
  StrCopy(s, p, ALL)
ENDPROC s

-> Shows a file requester for forms. Returns the chosen path as a new E-string, or NIL.
PROC askFile(hail, save, dir, file)
ENDPROC askFileEx(hail, save, dir, file, '#?.mform', '.mform')

-> The same for any kind of file: pattern is what the requester lists, ext the
-> extension the result is given if it has none
PROC askFileEx(hail, save, dir, file, pattern, ext)
  DEF req: PTR TO filerequester, path, flags, okText, d, f, n, el
  el := StrLen(ext)
  path := NIL
  flags := FILF_PATGAD
  okText := 'Open'
  IF save
    flags := flags OR FILF_SAVE
    okText := 'Save'
  ENDIF
  IF (aslbase := OpenLibrary('asl.library', 37))
    req := AllocAslRequest(ASL_FILEREQUEST, NIL)
    IF req
      IF AslRequest(req, [ASL_HAIL, hail, ASL_DIR, dir, ASL_FILE, file,
                          ASL_PATTERN, pattern, ASL_FUNCFLAGS, flags,
                          ASL_OKTEXT, okText, NIL])
        d := req.drawer
        f := req.file
        IF StrLen(f) > 0
          path := String(StrLen(d) + StrLen(f) + 12)
          StrCopy(path, d, ALL)
          n := StrLen(d)
          IF n > 0
            IF (d[n - 1] <> ":") AND (d[n - 1] <> "/") THEN StrAdd(path, '/', ALL)
          ENDIF
          StrAdd(path, f, ALL)
          -> always end up with the extension
          n := StrLen(path)
          IF n < el
            StrAdd(path, ext, ALL)
          ELSEIF StrCmp(path + n - el, ext, el) = FALSE
            StrAdd(path, ext, ALL)
          ENDIF
        ENDIF
      ENDIF
      FreeAslRequest(req)
    ENDIF
    CloseLibrary(aslbase)
  ENDIF
ENDPROC path

-> A form/window name from a file path: "forms/my-form.mform" -> "Myform"
PROC nameFromPath(path)
  DEF p, n, i, o, ch, out: PTR TO CHAR
  p := FilePart(path)
  n := StrLen(p)
  out := NewM(n + 8, MEMF_PUBLIC)
  o := 0
  FOR i := 0 TO n - 1
    ch := p[i]
    IF ch = "." THEN JUMP done
    IF ((ch >= "a") AND (ch <= "z")) OR ((ch >= "A") AND (ch <= "Z")) OR ((ch >= "0") AND (ch <= "9"))
      IF (o = 0) AND (ch >= "a") AND (ch <= "z") THEN ch := ch - 32
      out[o] := ch
      o++
    ENDIF
  ENDFOR
done:
  IF (o = 0) OR ((out[0] >= "0") AND (out[0] <= "9"))
    RETURN copyStr('NewForm')
  ENDIF
  out[o] := 0
ENDPROC copyStr(out)

-> Are two strings equal?
PROC same(a, b)
  IF StrLen(a) <> StrLen(b) THEN RETURN FALSE
  IF StrCmp(a, b, ALL) THEN RETURN TRUE
ENDPROC FALSE

-> The directory part of a path, including its trailing / or : ('' if none)
PROC dirPart(path)
  DEF p, n, s
  p := PathPart(path)
  n := p - path
  -> PathPart() points at the final '/', which belongs to the directory part
  IF path[n] = "/" THEN n++
  s := String(n + 2)
  IF n > 0 THEN StrCopy(s, path, n)
ENDPROC s

-> rel (a path relative to dir) as a full path; absolute paths are left alone
PROC joinPath(dir, rel)
  DEF s, i, n
  FOR i := 0 TO StrLen(rel) - 1
    IF rel[i] = ":" THEN RETURN copyStr(rel)
  ENDFOR
  IF StrLen(dir) = 0 THEN RETURN copyStr(rel)
  s := String(StrLen(dir) + StrLen(rel) + 2)
  StrCopy(s, dir, ALL)
  n := StrLen(dir)
  IF (dir[n - 1] <> ":") AND (dir[n - 1] <> "/") THEN StrAdd(s, '/', ALL)
  StrAdd(s, rel, ALL)
ENDPROC s

-> full as a path relative to dir, if it lies inside it
PROC relPath(dir, full)
  IF StrLen(dir) > 0
    IF StrLen(full) > StrLen(dir)
      IF StrCmp(full, dir, StrLen(dir)) THEN RETURN copyStr(full + StrLen(dir))
    ENDIF
  ENDIF
ENDPROC copyStr(full)

-> Does the name end in .mproj?
PROC isProjectFile(name)
  DEF n
  n := StrLen(name)
  IF n < 6 THEN RETURN FALSE
  IF StrCmp(name + n - 6, '.mproj', 6) THEN RETURN TRUE
ENDPROC FALSE

-> letters, digits and underscore only
PROC validIdent(s)
  DEF i, ch
  IF StrLen(s) = 0 THEN RETURN FALSE
  FOR i := 0 TO StrLen(s) - 1
    ch := s[i]
    IF ((ch >= "a") AND (ch <= "z")) OR ((ch >= "A") AND (ch <= "Z")) OR ((ch >= "0") AND (ch <= "9")) OR (ch = "_")
    ELSE
      RETURN FALSE
    ENDIF
  ENDFOR
ENDPROC TRUE

-> a whole number, optionally negative
PROC isNumber(s)
  DEF i, first
  IF StrLen(s) = 0 THEN RETURN FALSE
  first := 0
  IF s[0] = "-" THEN first := 1
  IF first >= StrLen(s) THEN RETURN FALSE
  FOR i := first TO StrLen(s) - 1
    IF (s[i] < "0") OR (s[i] > "9") THEN RETURN FALSE
  ENDFOR
ENDPROC TRUE

-> Skips the parameters of a console escape sequence; returns the new index
PROC skipCsi(buf: PTR TO CHAR, len, i)
  WHILE (i < len) AND ((buf[i] < 64) OR (buf[i] > 126)) DO i++
  i++
ENDPROC i

-> Compiler output without the escape sequences and control characters
PROC cleanOutput(buf: PTR TO CHAR, len)
  DEF out: PTR TO CHAR, i, o, ch
  out := NewM(len + 1, MEMF_PUBLIC)
  i := 0
  o := 0
  WHILE i < len
    ch := buf[i]
    IF ch = 27
      i := skipCsi(buf, len, i + 2)
    ELSEIF ch = $9B
      i := skipCsi(buf, len, i + 1)
    ELSEIF (ch >= 32) OR (ch = 10)
      out[o] := ch
      o++
      i++
    ELSE
      i++
    ENDIF
  ENDWHILE
  out[o] := 0
ENDPROC out

-> The path of a toolbar image, wherever the program is run from
PROC imagePath(name)
  DEF prefixes: PTR TO LONG, i, s
  prefixes := ['PROGDIR://Images/', 'PROGDIR:Images/', 'Images/', '/Images/']
  FOR i := 0 TO 3
    s := String(StrLen(prefixes[i]) + StrLen(name) + 2)
    StrCopy(s, prefixes[i], ALL)
    StrAdd(s, name, ALL)
    IF canOpen(s) THEN RETURN s
  ENDFOR
ENDPROC s
