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

-> Shows a file requester. Returns the chosen path as a new E-string, or NIL.
PROC askFile(hail, save, dir, file)
  DEF req: PTR TO filerequester, path, flags, okText, d, f, n
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
                          ASL_PATTERN, '#?.mform', ASL_FUNCFLAGS, flags,
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
          -> always end up with a .mform file
          n := StrLen(path)
          IF n < 6
            StrAdd(path, '.mform', ALL)
          ELSEIF StrCmp(path + n - 6, '.mform', 6) = FALSE
            StrAdd(path, '.mform', ALL)
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
