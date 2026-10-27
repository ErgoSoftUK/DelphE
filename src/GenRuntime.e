/*
** DelphE code generator: the runtime. The helper types and procedures that a generated file
** carries itself (dialogs, timer, exception report), so programs need no extra module.
*/

OPT MODULE
OPT EXPORT
OPT LARGE

MODULE '*FormModel', '*GenOut'

-> Does any of these forms use a component of this kind?
PROC anyUses(forms: PTR TO LONG, n, kind)
  DEF i
  FOR i := 0 TO n - 1
    IF usesKind(forms[i], kind) THEN RETURN TRUE
  ENDFOR
ENDPROC FALSE

-> Object types of the dialogs, which are not MUI objects but small helpers the
-> generated file carries itself, so programs need no extra module
PROC genRuntimeTypes(fh, forms: PTR TO LONG, n)
  IF anyUses(forms, n, CK_FILEDLG)
    put(fh, 'MODULE \aasl\a, \alibraries/asl\a\n\n')
    put(fh, '-> a file requester: set pattern, call execute(), read path\n')
    put(fh, 'OBJECT tFileDialog\n  title: PTR TO CHAR\n  pattern: PTR TO CHAR\n')
    put(fh, '  drawer: PTR TO CHAR   -> an E-string: change it with StrCopy()\n')
    put(fh, '  path: PTR TO CHAR     -> the chosen file, with its drawer\n  save\nENDOBJECT\n\n')
  ENDIF
  IF anyUses(forms, n, CK_TIMER)
    put(fh, 'MODULE \adevices/timer\a, \aexec/io\a, \aexec/ports\a\n\n')
    put(fh, '-> a timer: its OnTimer handler runs every interval; start() and stop() control it\n')
    put(fh, 'OBJECT tTimer\n  port: PTR TO mp\n  req: PTR TO timerequest\n  interval\n  active\n  pending\nENDOBJECT\n\n')
  ENDIF
  IF anyUses(forms, n, CK_MSGDLG)
    put(fh, '-> a message requester: call execute(); it returns the number of the button chosen\n')
    put(fh, 'OBJECT tMessageDialog\n  text: PTR TO CHAR\n  buttons: PTR TO CHAR\n  windowTitle: PTR TO CHAR\nENDOBJECT\n\n')
  ENDIF
ENDPROC

PROC genRuntimeProcs(fh, forms: PTR TO LONG, n)
  -> what the program says when it stops on an exception: Raise('text') gives a string, and
  -> NILCHECK, ARRAYCHECK and STACKCHECK throw a short code with the line it happened on
  put(fh, 'PROC delpheReport(ex, info)\n  DEF b[8]: ARRAY OF CHAR, i, c, n, ok, line\n  n := 0\n  ok := TRUE\n')
  put(fh, '  FOR i := 0 TO 3\n    c := Shr(ex, 24 - Mul(i, 8)) AND 255\n')
  put(fh, '    IF (c = 0) AND (n = 0)\n      -> the code NIL has only three characters\n')
  put(fh, '    ELSEIF (c < 32) OR (c > 126)\n      ok := FALSE\n    ELSE\n      b[n] := c\n      n++\n    ENDIF\n  ENDFOR\n')
  put(fh, '  b[n] := 0\n  IF (ok = FALSE) OR (n < 3)\n    WriteF(\a\\s\\n\a, ex)\n    RETURN\n  ENDIF\n')
  put(fh, '  IF StrCmp(b, \aNIL\a, 3) AND (n = 3)\n    WriteF(\aStopped: a NIL pointer was used\a)\n')
  put(fh, '  ELSEIF StrCmp(b, \aINDX\a, 4)\n    WriteF(\aStopped: an array index was out of range\a)\n')
  put(fh, '  ELSEIF StrCmp(b, \aSTCK\a, 4)\n    WriteF(\aStopped: the stack ran out\a)\n')
  put(fh, '  ELSE\n    WriteF(\aStopped: \\s\a, b)\n  ENDIF\n')
  put(fh, '  IF info > 0\n    IF info >= (DELPHE_FIRST + DELPHE_LINES)\n      line := info - DELPHE_LINES - DELPHE_CODE\n')
  put(fh, '      IF line > 0 THEN WriteF(\a, in your code at line \\d of the Code editor\a, line) ELSE WriteF(\a, in your header or globals (line \\d of the file)\a, info - DELPHE_LINES)\n')
  put(fh, '    ELSEIF info >= DELPHE_FIRST\n      WriteF(\a, in the generated code (line \\d of the .gen.e file)\a, info - DELPHE_FIRST + 1)\n')
  put(fh, '    ELSE\n      WriteF(\a, in your header (line \\d)\a, info)\n    ENDIF\n  ENDIF\n  WriteF(\a\\n\a)\nENDPROC\n\n')
  IF anyUses(forms, n, CK_FILEDLG)
    put(fh, 'PROC delpheFileDialog(title, pattern, save)\n  DEF d: PTR TO tFileDialog\n  NEW d\n')
    put(fh, '  d.title := title\n  d.pattern := pattern\n  d.drawer := String(260)\n  d.path := String(260)\n  d.save := save\nENDPROC d\n\n')
    put(fh, 'PROC execute() OF tFileDialog\n  DEF req: PTR TO filerequester, ok, flags, okText, n\n')
    put(fh, '  ok := FALSE\n  flags := FILF_PATGAD\n  okText := \aOpen\a\n')
    put(fh, '  IF self.save\n    flags := flags OR FILF_SAVE\n    okText := \aSave\a\n  ENDIF\n')
    put(fh, '  IF (aslbase := OpenLibrary(\aasl.library\a, 37))\n')
    put(fh, '    req := AllocAslRequest(ASL_FILEREQUEST, NIL)\n    IF req\n')
    put(fh, '      IF AslRequest(req, [ASL_HAIL, self.title, ASL_DIR, self.drawer, ASL_PATTERN, self.pattern,\n')
    put(fh, '                          ASL_FUNCFLAGS, flags, ASL_OKTEXT, okText, NIL])\n')
    put(fh, '        StrCopy(self.drawer, req.drawer, ALL)\n        StrCopy(self.path, req.drawer, ALL)\n')
    put(fh, '        n := StrLen(self.path)\n')
    put(fh, '        IF n > 0\n          IF (self.path[n - 1] <> \a:\a) AND (self.path[n - 1] <> \a/\a) THEN StrAdd(self.path, \a/\a, ALL)\n        ENDIF\n')
    put(fh, '        StrAdd(self.path, req.file, ALL)\n        ok := TRUE\n      ENDIF\n      FreeAslRequest(req)\n    ENDIF\n')
    put(fh, '    CloseLibrary(aslbase)\n  ENDIF\nENDPROC ok\n\n')
  ENDIF
  IF anyUses(forms, n, CK_TIMER)
    put(fh, 'PROC delpheTimer(ms, active)\n  DEF t: PTR TO tTimer\n  NEW t\n  t.interval := ms\n')
    put(fh, '  t.port := CreateMsgPort()\n  IF t.port\n    t.req := CreateIORequest(t.port, SIZEOF timerequest)\n')
    put(fh, '    IF t.req\n      IF OpenDevice(TIMERNAME, UNIT_VBLANK, t.req, 0) <> 0\n')
    put(fh, '        DeleteIORequest(t.req)\n        t.req := NIL\n      ENDIF\n    ENDIF\n  ENDIF\n')
    put(fh, '  IF t.req\n    IF active THEN t.start()\n  ENDIF\nENDPROC t\n\n')
    put(fh, 'PROC arm() OF tTimer\n  self.req.io.command := TR_ADDREQUEST\n')
    put(fh, '  self.req.time.secs := Div(self.interval, 1000)\n  self.req.time.micro := Mul(Mod(self.interval, 1000), 1000)\n')
    put(fh, '  SendIO(self.req)\n  self.pending := TRUE\nENDPROC\n\n')
    put(fh, 'PROC start() OF tTimer\n  IF self.req = NIL THEN RETURN\n  self.active := TRUE\n')
    put(fh, '  IF self.pending = FALSE THEN self.arm()\nENDPROC\n\n')
    put(fh, 'PROC stop() OF tTimer\n  self.active := FALSE\n  IF self.pending\n')
    put(fh, '    IF CheckIO(self.req) = NIL THEN AbortIO(self.req)\n    WaitIO(self.req)\n    self.pending := FALSE\n  ENDIF\nENDPROC\n\n')
    put(fh, '-> TRUE once each time the interval has passed\n')
    put(fh, 'PROC fired() OF tTimer\n  IF self.req = NIL THEN RETURN FALSE\n  IF self.pending = FALSE THEN RETURN FALSE\n')
    put(fh, '  IF CheckIO(self.req) = NIL THEN RETURN FALSE\n  WaitIO(self.req)\n  self.pending := FALSE\n')
    put(fh, '  IF self.active THEN self.arm()\nENDPROC TRUE\n\n')
    put(fh, 'PROC sigMask() OF tTimer\n  IF self.port = NIL THEN RETURN 0\nENDPROC Shl(1, self.port.sigbit)\n\n')
    put(fh, 'PROC release() OF tTimer\n  IF self.req = NIL THEN RETURN\n  self.stop()\n  CloseDevice(self.req)\n')
    put(fh, '  DeleteIORequest(self.req)\n  self.req := NIL\n  DeleteMsgPort(self.port)\n  self.port := NIL\nENDPROC\n\n')
  ENDIF
  IF anyUses(forms, n, CK_MSGDLG)
    put(fh, 'PROC delpheMessageDialog(text, buttons, windowTitle)\n  DEF d: PTR TO tMessageDialog\n  NEW d\n')
    put(fh, '  d.text := text\n  d.buttons := buttons\n  d.windowTitle := windowTitle\nENDPROC d\n\n')
    put(fh, 'PROC execute() OF tMessageDialog\n  DEF n, i, r\n  n := 1\n')
    put(fh, '  FOR i := 0 TO StrLen(self.buttons) - 1\n    IF self.buttons[i] = \a|\a THEN n++\n  ENDFOR\n')
    put(fh, '  r := EasyRequestArgs(NIL, [20, 0, self.windowTitle, self.text, self.buttons], NIL, NIL)\n')
    put(fh, '  -> EasyRequest gives 0 for the last button\n  IF r = 0 THEN r := n\nENDPROC r\n\n')
  ENDIF
ENDPROC

-> The generated file has no module for TextEditor.mcc, so a memo gets its tags as constants
PROC genConstants(fh, forms: PTR TO LONG, n)
  DEF i, used
  -> where the generated code sits in the program the compiler sees: buildSource puts
  -> the numbers in, so that a line in an error message (NILCHECK and the like) can be
  -> traced back to the user's code
  put(fh, 'CONST DELPHE_FIRST = @@FIRST@@, DELPHE_LINES = @@LINES@@, DELPHE_CODE = @@CODE@@\n\n')
  used := FALSE
  FOR i := 0 TO n - 1
    IF usesKind(forms[i], CK_MEMO) THEN used := TRUE
  ENDFOR
  IF used
    put(fh, '-> tags of TextEditor.mcc (the Memo component)\nCONST MUIA_TextEditor_Contents = $ad000002, MUIA_TextEditor_Slider = $ad00001a\n\n')
  ENDIF
ENDPROC
