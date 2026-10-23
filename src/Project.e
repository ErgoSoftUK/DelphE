/*
** DelphE project files (.mproj): a program made of several forms.
**
**   Project MyApp
**   Form "main.mform"
**   Form "settings.mform"
**
** The form paths are relative to the project file's folder. The first form
** is the main form: closing it ends the program.
*/

OPT MODULE
OPT EXPORT

MODULE 'dos/dos', '*MForm', '*Util'

CONST MAXFORMS = 16

PROC wr(fh, s) IS Write(fh, s, StrLen(s))

-> Reads the project name and fills paths (an array of at most max entries)
-> with the form paths as written in the file. Returns the name and the count,
-> or NIL, 0 if the file can't be read or has no name.
PROC readProjectFile(path, paths: PTR TO LONG, max)
  DEF fh, line, name, count, kindTok, valTok, pos, quoted
  name := NIL
  count := 0
  fh := Open(path, MODE_OLDFILE)
  IF fh = NIL
    WriteF('Cannot open \s\n', path)
    RETURN NIL, 0
  ENDIF
  line := String(255)
  WHILE (ReadStr(fh, line) <> -1) OR (StrLen(line) > 0)
    kindTok, pos, quoted := nextToken(line, 0)
    IF kindTok
      valTok, pos, quoted := nextToken(line, pos)
      IF valTok
        IF same(kindTok, 'Project')
          name := valTok
        ELSEIF same(kindTok, 'Form')
          IF count < max
            paths[count] := valTok
            count++
          ENDIF
        ENDIF
      ENDIF
    ENDIF
  ENDWHILE
  Close(fh)
  IF name = NIL
    WriteF('\s has no Project line\n', path)
    RETURN NIL, 0
  ENDIF
ENDPROC name, count

PROC writeProjectFile(path, name, paths: PTR TO LONG, count)
  DEF fh, i
  fh := Open(path, MODE_NEWFILE)
  IF fh = NIL THEN RETURN FALSE
  wr(fh, 'Project \q')
  wr(fh, name)
  wr(fh, '\q\n')
  FOR i := 0 TO count - 1
    wr(fh, 'Form \q')
    wr(fh, paths[i])
    wr(fh, '\q\n')
  ENDFOR
  Close(fh)
ENDPROC TRUE
