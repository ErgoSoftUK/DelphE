/*
** DelphE toolchain: which compiler builds the programs, how it is called, and the folder
** handling that goes with it.
*/

OPT MODULE
OPT EXPORT

MODULE 'dos/dos'

-> Makes dir the current directory; returns what leaveDir() needs
PROC enterDir(dir)
  DEF lock, old
  lock := NIL
  old := NIL
  IF StrLen(dir) > 0
    lock := Lock(dir, SHARED_LOCK)
    IF lock THEN old := CurrentDir(lock)
  ENDIF
ENDPROC lock, old

PROC leaveDir(lock, old)
  IF lock
    CurrentDir(old)
    UnLock(lock)
  ENDIF
ENDPROC

-> Which compiler builds the program: the variable DelphECompiler (ec if it is not
-> set), as an E-string. For E-VO: setenv DelphECompiler evo
PROC compilerName()
  DEF s, n
  s := String(40)
  n := GetVar('DelphECompiler', s, 36, 0)
  IF n > 0
    SetStr(s, n)
  ELSE
    StrCopy(s, 'ec', ALL)
  ENDIF
ENDPROC s

-> Is that compiler E-VO? It takes a few extra switches: no progress numbers, and more
-> workspace for the compiler's buffers (the big programs need it).
PROC isEvo(name)
  IF StrLen(name) < 3 THEN RETURN FALSE
  IF (name[StrLen(name) - 3] = "e") OR (name[StrLen(name) - 3] = "E")
    IF (name[StrLen(name) - 2] = "v") OR (name[StrLen(name) - 2] = "V")
      IF (name[StrLen(name) - 1] = "o") OR (name[StrLen(name) - 1] = "O") THEN RETURN TRUE
    ENDIF
  ENDIF
ENDPROC FALSE

-> Is a debug build asked for? The variable DelphEDebug is set to anything but 0. With E-VO the
-> program then also checks every NIL pointer, array index and the stack, and stops with the
-> line it happened on; its console window stays open so that the message can be read.
PROC debugOn()
  DEF s[4]: ARRAY OF CHAR, n
  n := GetVar('DelphEDebug', s, 3, 0)
  IF n <= 0 THEN RETURN FALSE
  IF s[0] = "0" THEN RETURN FALSE
ENDPROC TRUE

-> The full path of a folder (a path relative to the current folder will not do from another
-> folder), ending in : or /, as an E-string, or NIL. An empty path is the current folder.
PROC absoluteDir(dir)
  DEF lock, buf[300]: ARRAY OF CHAR, s, n, ok
  lock := Lock(dir, SHARED_LOCK)
  IF lock = NIL THEN RETURN NIL
  ok := NameFromLock(lock, buf, 298)
  UnLock(lock)
  IF ok = FALSE THEN RETURN NIL
  n := StrLen(buf)
  s := String(n + 2)
  StrCopy(s, buf, ALL)
  IF n > 0
    IF (buf[n - 1] <> ":") AND (buf[n - 1] <> "/") THEN StrAdd(s, '/', ALL)
  ENDIF
ENDPROC s

