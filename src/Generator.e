/*
** DelphE code generator
**
** Turns a form model (see FormModel.e) into an E source file.
**
** The file has two kinds of text. Between the DELPHE BEGIN / DELPHE END
** markers is generated code: the form object, create(), connect() and the
** event dispatcher. It is rewritten on every generation. Everything outside
** the markers belongs to the user: the module list, the event handler
** procedures (stubs are appended for new handlers) and main().
**
** Handlers are methods of the form object, so they can use self.<component>.
*/

OPT MODULE
OPT EXPORT

MODULE 'dos/dos', 'exec/memory', '*FormModel'

CONST GEN_OK = 0, GEN_WRITEFAIL = 1, GEN_NOMARKERS = 2

DEF evCounter

PROC put(fh, s) IS Write(fh, s, StrLen(s))

PROC putNum(fh, n)
  DEF s
  s := String(16)
  StringF(s, '\d', n)
  put(fh, s)
  DisposeLink(s)
ENDPROC

PROC indent(fh, depth)
  DEF i
  FOR i := 1 TO depth DO put(fh, '  ')
ENDPROC

-> E strings are single-quoted; \a is an apostrophe
PROC quoted(fh, s)
  DEF i, ch
  IF s = NIL THEN s := ''
  put(fh, '\a')
  FOR i := 0 TO StrLen(s) - 1
    ch := s[i]
    -> inside an E string literal an apostrophe is \a and a backslash is \\
    IF ch = 39
      put(fh, '\\a')
    ELSEIF ch = 92
      put(fh, '\\\\')
    ELSE
      Out(fh, ch)
    ENDIF
  ENDFOR
  put(fh, '\a')
ENDPROC

-> ", MUIA_Weight, 3"-style tag with a number
PROC putPair(fh, text, n)
  put(fh, text)
  putNum(fh, n)
ENDPROC

-> "One|Two" -> ['One', 'Two', NIL]
PROC putItems(fh, s)
  DEF i, start, len, seg
  IF s = NIL THEN s := ''
  len := StrLen(s)
  start := 0
  put(fh, '[')
  FOR i := 0 TO len
    IF (i = len) OR (s[i] = "|")
      seg := String(i - start + 1)
      IF i > start THEN MidStr(seg, s, start, i - start)
      quoted(fh, seg)
      put(fh, ', ')
      DisposeLink(seg)
      start := i + 1
    ENDIF
  ENDFOR
  put(fh, 'NIL]')
ENDPROC

-> A number property, or its default
PROC numOr(c: PTR TO component, bit, v, dflt)
  IF c.propFlags AND bit THEN RETURN v
ENDPROC dflt

-> Optional properties of a leaf widget as tags, each starting with ", "
PROC emitLeafExtras(fh, c: PTR TO component)
  DEF flags
  flags := c.propFlags
  IF flags AND PF_WEIGHT THEN putPair(fh, ', MUIA_Weight, ', c.weight)
  IF flags AND PF_FIXW THEN putPair(fh, ', MUIA_FixWidth, ', c.fixW)
  IF flags AND PF_FIXH THEN putPair(fh, ', MUIA_FixHeight, ', c.fixH)
  IF flags AND PF_DISABLED THEN put(fh, ', MUIA_Disabled, MUI_TRUE')
  IF flags AND PF_HINT
    put(fh, ', MUIA_ShortHelp, ')
    quoted(fh, c.hint)
  ENDIF
ENDPROC

-> Optional properties of a group, one tag per line, each ending with a comma
PROC emitGroupExtras(fh, c: PTR TO component, depth)
  DEF flags
  flags := c.propFlags
  IF flags AND PF_WEIGHT
    indent(fh, depth + 1)
    putPair(fh, 'MUIA_Weight, ', c.weight)
    put(fh, ',\n')
  ENDIF
  IF flags AND PF_FIXW
    indent(fh, depth + 1)
    putPair(fh, 'MUIA_FixWidth, ', c.fixW)
    put(fh, ',\n')
  ENDIF
  IF flags AND PF_FIXH
    indent(fh, depth + 1)
    putPair(fh, 'MUIA_FixHeight, ', c.fixH)
    put(fh, ',\n')
  ENDIF
  IF flags AND PF_DISABLED
    indent(fh, depth + 1)
    put(fh, 'MUIA_Disabled, MUI_TRUE,\n')
  ENDIF
  IF flags AND PF_HINT
    indent(fh, depth + 1)
    put(fh, 'MUIA_ShortHelp, ')
    quoted(fh, c.hint)
    put(fh, ',\n')
  ENDIF
  IF flags AND PF_FRAME
    indent(fh, depth + 1)
    put(fh, 'MUIA_Frame, MUIV_Frame_Group,\n')
    IF c.title
      IF StrLen(c.title) > 0
        indent(fh, depth + 1)
        put(fh, 'MUIA_FrameTitle, ')
        quoted(fh, c.title)
        put(fh, ',\n')
      ENDIF
    ENDIF
  ENDIF
ENDPROC

PROC beginMark() IS '->>> DELPHE BEGIN'
PROC endMark() IS '->>> DELPHE END'

/*** fields ***/

PROC declareLeaves(fh, c: PTR TO component)
  DEF ch: PTR TO component
  IF isContainer(c.kind) = FALSE
    put(fh, '  ')
    put(fh, c.name)
    put(fh, '\n')
  ENDIF
  ch := c.firstChild
  WHILE ch
    declareLeaves(fh, ch)
    ch := ch.next
  ENDWHILE
ENDPROC

/*** leaf widgets ***/

PROC leafExpr(fh, c: PTR TO component)
  DEF kind
  kind := c.kind
  SELECT kind
    CASE CK_BUTTON
      IF c.propFlags = 0
        put(fh, 'SimpleButton(')
        quoted(fh, c.title)
        put(fh, ')')
      ELSE
        -> SimpleButton() takes no tags, so spell the button out
        put(fh, 'TextObject, ButtonFrame, MUIA_Font, MUIV_Font_Button, MUIA_Text_Contents, ')
        quoted(fh, c.title)
        put(fh, ', MUIA_Text_PreParse, \a\\ec\a, MUIA_InputMode, MUIV_InputMode_RelVerify, ')
        put(fh, 'MUIA_Background, MUII_ButtonBack')
        emitLeafExtras(fh, c)
        put(fh, ', End')
      ENDIF
    CASE CK_TEXT
      put(fh, 'TextObject, TextFrame, MUIA_Text_Contents, ')
      quoted(fh, c.title)
      emitLeafExtras(fh, c)
      put(fh, ', End')
    CASE CK_STRING
      put(fh, 'StringObject, StringFrame, MUIA_String_Contents, ')
      quoted(fh, c.title)
      emitLeafExtras(fh, c)
      put(fh, ', End')
    CASE CK_CHECK
      IF c.propFlags = 0
        put(fh, 'CheckMark(FALSE)')
      ELSE
        put(fh, 'ImageObject, ImageButtonFrame, MUIA_InputMode, MUIV_InputMode_Toggle, ')
        put(fh, 'MUIA_Image_Spec, MUII_CheckMark, MUIA_Image_FreeVert, MUI_TRUE, ')
        put(fh, 'MUIA_Selected, FALSE, MUIA_Background, MUII_ButtonBack, MUIA_ShowSelState, FALSE')
        emitLeafExtras(fh, c)
        put(fh, ', End')
      ENDIF
    CASE CK_CYCLE
      put(fh, 'CycleObject, MUIA_Font, MUIV_Font_Button, MUIA_Cycle_Entries, ')
      putItems(fh, c.title)
      emitLeafExtras(fh, c)
      put(fh, ', End')
    CASE CK_RADIO
      put(fh, 'RadioObject, MUIA_Radio_Entries, ')
      putItems(fh, c.title)
      emitLeafExtras(fh, c)
      put(fh, ', End')
    CASE CK_SLIDER
      putPair(fh, 'SliderObject, MUIA_Numeric_Min, ', numOr(c, PF_MIN, c.minV, 0))
      putPair(fh, ', MUIA_Numeric_Max, ', numOr(c, PF_MAX, c.maxV, 100))
      putPair(fh, ', MUIA_Numeric_Value, ', numOr(c, PF_VALUE, c.value, 0))
      emitLeafExtras(fh, c)
      put(fh, ', End')
    CASE CK_GAUGE
      putPair(fh, 'GaugeObject, GaugeFrame, MUIA_Gauge_Horiz, MUI_TRUE, MUIA_Gauge_Max, ', numOr(c, PF_MAX, c.maxV, 100))
      putPair(fh, ', MUIA_Gauge_Current, ', numOr(c, PF_VALUE, c.value, 0))
      emitLeafExtras(fh, c)
      put(fh, ', End')
    CASE CK_LIST
      put(fh, 'ListviewObject, MUIA_Listview_List, ListObject, InputListFrame, MUIA_List_SourceArray, ')
      putItems(fh, c.title)
      put(fh, ', End')
      emitLeafExtras(fh, c)
      put(fh, ', End')
  ENDSELECT
ENDPROC

PROC createLeaves(fh, c: PTR TO component)
  DEF ch: PTR TO component
  IF isContainer(c.kind) = FALSE
    put(fh, '  self.')
    put(fh, c.name)
    put(fh, ' := ')
    leafExpr(fh, c)
    put(fh, '\n')
  ENDIF
  ch := c.firstChild
  WHILE ch
    createLeaves(fh, ch)
    ch := ch.next
  ENDWHILE
ENDPROC

/*** containers ***/

-> Emits one expression with no trailing comma; the caller adds it.
PROC containerExpr(fh, c: PTR TO component, depth)
  DEF ch: PTR TO component, kind

  IF isContainer(c.kind) = FALSE
    put(fh, 'self.')
    put(fh, c.name)
    RETURN
  ENDIF

  kind := c.kind
  SELECT kind
    CASE CK_WINDOW
      put(fh, 'WindowObject,\n')
      indent(fh, depth + 1)
      put(fh, 'MUIA_Window_Title, ')
      quoted(fh, c.title)
      put(fh, ',\n')
      indent(fh, depth + 1)
      -> a window ID is a 4-char ULONG ("MAIN"), not a string pointer
      put(fh, 'MUIA_Window_ID, \qMAIN\q,\n')
      indent(fh, depth + 1)
      put(fh, 'WindowContents,\n')
      ch := c.firstChild
      IF ch
        indent(fh, depth + 2)
        containerExpr(fh, ch, depth + 2)
        put(fh, ',\n')
      ENDIF
    CASE CK_VGROUP
      put(fh, 'VGroup,\n')
      emitGroupExtras(fh, c, depth)
      emitChildren(fh, c, depth)
    CASE CK_HGROUP
      put(fh, 'HGroup,\n')
      emitGroupExtras(fh, c, depth)
      emitChildren(fh, c, depth)
  ENDSELECT

  indent(fh, depth)
  put(fh, 'End')
ENDPROC

PROC emitChildren(fh, c: PTR TO component, depth)
  DEF ch: PTR TO component
  ch := c.firstChild
  WHILE ch
    indent(fh, depth + 1)
    put(fh, 'Child, ')
    containerExpr(fh, ch, depth + 1)
    put(fh, ',\n')
    ch := ch.next
  ENDWHILE
ENDPROC

/*** events ***/

-> Event numbers are handed out in tree order; connect() and handleEvent()
-> walk the tree the same way, so they agree.
PROC emitConnect(fh, c: PTR TO component)
  DEF ch: PTR TO component, kind
  kind := c.kind
  IF c.handler
    IF eventName(kind)
      evCounter++
      put(fh, '  doMethodA(self.')
      put(fh, c.name)
      SELECT kind
        CASE CK_BUTTON
          put(fh, ', [MUIM_Notify, MUIA_Pressed, FALSE, app, 2, MUIM_Application_ReturnID, ')
        CASE CK_STRING
          put(fh, ', [MUIM_Notify, MUIA_String_Acknowledge, MUIV_EveryTime, app, 2, MUIM_Application_ReturnID, ')
        CASE CK_CHECK
          put(fh, ', [MUIM_Notify, MUIA_Selected, MUIV_EveryTime, app, 2, MUIM_Application_ReturnID, ')
        CASE CK_CYCLE
          put(fh, ', [MUIM_Notify, MUIA_Cycle_Active, MUIV_EveryTime, app, 2, MUIM_Application_ReturnID, ')
        CASE CK_RADIO
          put(fh, ', [MUIM_Notify, MUIA_Radio_Active, MUIV_EveryTime, app, 2, MUIM_Application_ReturnID, ')
        CASE CK_SLIDER
          put(fh, ', [MUIM_Notify, MUIA_Numeric_Value, MUIV_EveryTime, app, 2, MUIM_Application_ReturnID, ')
        CASE CK_LIST
          put(fh, ', [MUIM_Notify, MUIA_Listview_DoubleClick, MUI_TRUE, app, 2, MUIM_Application_ReturnID, ')
      ENDSELECT
      putNum(fh, evCounter)
      put(fh, '])\n')
    ENDIF
  ENDIF
  ch := c.firstChild
  WHILE ch
    emitConnect(fh, ch)
    ch := ch.next
  ENDWHILE
ENDPROC

PROC emitDispatch(fh, c: PTR TO component)
  DEF ch: PTR TO component, kind
  kind := c.kind
  IF c.handler
    IF eventName(kind)
      evCounter++
      put(fh, '    CASE ')
      putNum(fh, evCounter)
      put(fh, '\n      self.')
      put(fh, c.handler)
      put(fh, '()\n')
    ENDIF
  ENDIF
  ch := c.firstChild
  WHILE ch
    emitDispatch(fh, ch)
    ch := ch.next
  ENDWHILE
ENDPROC

PROC countEvents(c: PTR TO component)
  DEF ch: PTR TO component, n
  n := 0
  IF c.handler
    IF eventName(c.kind) THEN n := 1
  ENDIF
  ch := c.firstChild
  WHILE ch
    n := n + countEvents(ch)
    ch := ch.next
  ENDWHILE
ENDPROC n

/*** the generated region ***/

PROC genRegion(fh, win: PTR TO component)
  put(fh, beginMark())
  put(fh, ' (generated by DelphE: edit the form in the designer, not here)\n\n')

  put(fh, 'OBJECT t')
  put(fh, win.name)
  put(fh, '\n  handle\n')
  declareLeaves(fh, win)
  put(fh, 'ENDOBJECT\n\n')

  put(fh, 'PROC create() OF t')
  put(fh, win.name)
  put(fh, '\n')
  createLeaves(fh, win)
  put(fh, '  self.handle := ')
  containerExpr(fh, win, 1)
  put(fh, '\nENDPROC\n\n')

  put(fh, 'PROC connect(app) OF t')
  put(fh, win.name)
  put(fh, '\n')
  evCounter := 0
  emitConnect(fh, win)
  put(fh, 'ENDPROC\n\n')

  put(fh, 'PROC handleEvent(id) OF t')
  put(fh, win.name)
  put(fh, '\n')
  IF countEvents(win) > 0
    put(fh, '  SELECT id\n')
    evCounter := 0
    emitDispatch(fh, win)
    put(fh, '  ENDSELECT\n')
  ENDIF
  put(fh, 'ENDPROC\n')

  put(fh, endMark())
  put(fh, '\n')
ENDPROC

/*** the user's part ***/

-> Appends to 'appended' a stub for every handler that buf does not define yet
PROC collectStubs(c: PTR TO component, buf, appended, win: PTR TO component)
  DEF ch: PTR TO component, sig
  IF c.handler
    IF eventName(c.kind)
      sig := String(StrLen(c.handler) + StrLen(win.name) + 16)
      -> built with StrAdd: StringF swallowed the "()" of the signature
      StrCopy(sig, 'PROC ', ALL)
      StrAdd(sig, c.handler, ALL)
      StrAdd(sig, '() OF t', ALL)
      StrAdd(sig, win.name, ALL)
      IF InStr(buf, sig) = -1
        IF InStr(appended, sig) = -1
          StrAdd(appended, '\n', ALL)
          StrAdd(appended, sig, ALL)
          StrAdd(appended, '\n  -> TODO: handle ', ALL)
          StrAdd(appended, eventName(c.kind), ALL)
          StrAdd(appended, ' of ', ALL)
          StrAdd(appended, c.name, ALL)
          StrAdd(appended, '\nENDPROC\n', ALL)
        ENDIF
      ENDIF
      DisposeLink(sig)
    ENDIF
  ENDIF
  ch := c.firstChild
  WHILE ch
    collectStubs(ch, buf, appended, win)
    ch := ch.next
  ENDWHILE
ENDPROC

PROC genHeader(fh, win: PTR TO component)
  put(fh, '/*\n** ')
  put(fh, win.name)
  put(fh, '\n**\n** Created by DelphE. The part between the DELPHE markers is regenerated;\n')
  put(fh, '** everything else is yours.\n*/\n\n')
  put(fh, 'OPT PREPROCESS\n\n')
  put(fh, 'MODULE \amuimaster\a, \alibraries/mui\a, \autility/tagitem\a,\n')
  put(fh, '       \aamigalib/boopsi\a\n\n')
ENDPROC

PROC genMain(fh, win: PTR TO component)
  put(fh, '\nPROC main() HANDLE\n')
  put(fh, '  DEF app = NIL, form: PTR TO t')
  put(fh, win.name)
  put(fh, ', sigs = 0, id, running\n\n')
  put(fh, '  IF (muimasterbase := OpenLibrary(MUIMASTER_NAME, MUIMASTER_VMIN)) = NIL THEN\n')
  put(fh, '    Raise(\aFailed to open muimaster.library\a)\n\n')
  put(fh, '  NEW form\n')
  put(fh, '  form.create()\n')
  put(fh, '  IF form.handle = NIL THEN Raise(\aFailed to create the window\a)\n\n')
  put(fh, '  app := ApplicationObject,\n')
  put(fh, '    MUIA_Application_Title      , ')
  quoted(fh, win.name)
  put(fh, ',\n')
  put(fh, '    MUIA_Application_Base       , \aDELPHEFORM\a,\n')
  put(fh, '    SubWindow, form.handle,\n')
  put(fh, '  End\n\n')
  put(fh, '  IF app = NIL THEN Raise(\aFailed to create Application.\a)\n\n')
  put(fh, '  form.connect(app)\n')
  put(fh, '  doMethodA(form.handle, [MUIM_Notify, MUIA_Window_CloseRequest, MUI_TRUE,\n')
  put(fh, '    app, 2, MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])\n\n')
  put(fh, '  set(form.handle, MUIA_Window_Open, MUI_TRUE)\n\n')
  put(fh, '  running := TRUE\n')
  put(fh, '  WHILE running\n')
  put(fh, '    id := doMethodA(app, [MUIM_Application_NewInput, {sigs}])\n')
  put(fh, '    IF id = MUIV_Application_ReturnID_Quit\n')
  put(fh, '      running := FALSE\n')
  put(fh, '    ELSE\n')
  put(fh, '      form.handleEvent(id)\n')
  put(fh, '    ENDIF\n')
  put(fh, '    IF running AND sigs THEN sigs := Wait(sigs)\n')
  put(fh, '  ENDWHILE\n\n')
  put(fh, '  set(form.handle, MUIA_Window_Open, FALSE)\n\n')
  put(fh, 'EXCEPT DO\n')
  put(fh, '  IF app THEN Mui_DisposeObject(app)\n')
  put(fh, '  IF muimasterbase THEN CloseLibrary(muimasterbase)\n')
  put(fh, '  IF exception THEN WriteF(\a\\s\\n\a, exception)\n')
  put(fh, 'ENDPROC\n')
ENDPROC

/*** files ***/

-> Returns the whole file as a zero-terminated buffer and its length,
-> or NIL, 0 if it does not exist.
PROC readAll(path)
  DEF fh, size, buf
  size := FileLength(path)
  IF size < 0 THEN RETURN NIL, 0
  fh := Open(path, MODE_OLDFILE)
  IF fh = NIL THEN RETURN NIL, 0
  buf := NewM(size + 1, MEMF_PUBLIC)
  IF size > 0 THEN Read(fh, buf, size)
  Close(fh)
ENDPROC buf, size

PROC writeBackup(path, buf, len)
  DEF fh, bak
  bak := String(StrLen(path) + 8)
  StrCopy(bak, path, ALL)
  StrAdd(bak, '.bak', ALL)
  fh := Open(bak, MODE_NEWFILE)
  IF fh
    Write(fh, buf, len)
    Close(fh)
  ENDIF
ENDPROC

/*
** Creates path, or updates it if it exists: the generated region is replaced
** and stubs are appended for handlers it does not define yet. The previous
** file is kept as path.bak. Returns GEN_OK, GEN_WRITEFAIL or GEN_NOMARKERS.
*/
PROC generateFile(path, win: PTR TO component)
  DEF buf, len, fh, b, e, eEnd, appended

  appended := String(20000)
  buf, len := readAll(path)

  IF buf = NIL
    collectStubs(win, '', appended, win)
    fh := Open(path, MODE_NEWFILE)
    IF fh = NIL THEN RETURN GEN_WRITEFAIL
    genHeader(fh, win)
    genRegion(fh, win)
    put(fh, '\n/*** your code ***/\n')
    put(fh, appended)
    genMain(fh, win)
    Close(fh)
    RETURN GEN_OK
  ENDIF

  b := InStr(buf, beginMark())
  e := InStr(buf, endMark())
  IF (b = -1) OR (e = -1) OR (e < b) THEN RETURN GEN_NOMARKERS

  -> the region ends after the line holding the END marker
  eEnd := InStr(buf, '\n', e)
  IF eEnd = -1 THEN eEnd := len ELSE eEnd := eEnd + 1

  collectStubs(win, buf, appended, win)
  writeBackup(path, buf, len)

  fh := Open(path, MODE_NEWFILE)
  IF fh = NIL THEN RETURN GEN_WRITEFAIL
  IF b > 0 THEN Write(fh, buf, b)
  genRegion(fh, win)
  IF len > eEnd THEN Write(fh, buf + eEnd, len - eEnd)
  put(fh, appended)
  Close(fh)
ENDPROC GEN_OK
