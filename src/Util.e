/*
** DelphE shared helpers: command line and file handling.
*/

OPT MODULE
OPT EXPORT

MODULE 'dos/dos'

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
