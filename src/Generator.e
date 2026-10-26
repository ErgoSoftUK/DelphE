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

MODULE 'dos/dos', 'exec/memory', '*FormModel', '*MForm', '*Util'

CONST GEN_OK = 0, GEN_WRITEFAIL = 1, GEN_NOMARKERS = 2, GEN_NOWINDOW = 3

DEF orphanList, evCounter, genBase, useCounter  -> genBase: the folder that the paths of used frames are relative to

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

-> The MUIV_Font_ constant for a font index (see fontName in FormModel)
PROC fontConst(idx) IS ListItem(['', 'MUIV_Font_Normal', 'MUIV_Font_Tiny', 'MUIV_Font_Big', 'MUIV_Font_Title', 'MUIV_Font_Fixed', 'MUIV_Font_List', 'MUIV_Font_Button'], idx)

-> Optional properties of a leaf widget as tags, each starting with ", "
PROC emitLeafExtras(fh, c: PTR TO component)
  DEF flags
  flags := c.propFlags
  IF flags AND PF_WEIGHT THEN putPair(fh, ', MUIA_Weight, ', c.weight)
  IF flags AND PF_FIXW THEN putPair(fh, ', MUIA_FixWidth, ', c.fixW)
  IF flags AND PF_FIXH THEN putPair(fh, ', MUIA_FixHeight, ', c.fixH)
  IF flags AND PF_DISABLED THEN put(fh, ', MUIA_Disabled, MUI_TRUE')
  IF effectiveFont(c) > 0
    put(fh, ', MUIA_Font, ')
    put(fh, fontConst(effectiveFont(c)))
  ENDIF
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
  IF flags AND PF_FONT
    indent(fh, depth + 1)
    put(fh, 'MUIA_Font, ')
    put(fh, fontConst(c.fontIdx))
    put(fh, ',\n')
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
-> the line in the user's file where the generated file is inserted at compile time
PROC userMark() IS '->>> DELPHE GENERATED CODE'
PROC userMarkLine() IS '->>> DELPHE GENERATED CODE (the .gen.e file is inserted here when you compile: do not edit this line)'
PROC endMark() IS '->>> DELPHE END'

-> The text that identifies a region's marker line. With a tag it ends in " |"
-> so that "form Main" is never mistaken for the start of "form MainForm".
PROC markerText(isBegin, tag)
  DEF s
  s := String(80 + StrLen(tag))
  IF isBegin THEN StrCopy(s, beginMark(), ALL) ELSE StrCopy(s, endMark(), ALL)
  StrAdd(s, ' ', ALL)
  StrAdd(s, tag, ALL)
  StrAdd(s, ' |', ALL)
ENDPROC s

-> Writes a region's opening line (isBegin) or closing line
PROC markLine(fh, isBegin, tag)
  DEF m
  IF tag
    m := markerText(isBegin, tag)
    put(fh, m)
    DisposeLink(m)
  ELSEIF isBegin
    put(fh, beginMark())
  ELSE
    put(fh, endMark())
  ENDIF
ENDPROC

/*** frames ***/

-> The frame a Use component refers to, read from its file, or NIL
PROC frameOf(c: PTR TO component)
  DEF path
  IF (c.propFlags AND PF_ARG) = FALSE THEN RETURN NIL
  IF genBase THEN path := joinPath(genBase, c.arg) ELSE path := copyStr(c.arg)
ENDPROC readForm(path)

-> The type name of a used frame, for a field's declaration
PROC frameTypeName(c: PTR TO component)
  DEF f: PTR TO component
  f := frameOf(c)
  IF f THEN RETURN f.name
ENDPROC 'MissingFrame'

-> Does the list already hold a frame of this name?
PROC frameListed(frames, name)
  DEF i, f: PTR TO component
  FOR i := 0 TO ListLen(frames) - 1
    f := ListItem(frames, i)
    IF StrLen(f.name) = StrLen(name)
      IF StrCmp(f.name, name, ALL) THEN RETURN TRUE
    ENDIF
  ENDFOR
ENDPROC FALSE

-> Adds the frames that c uses, and those they use, to the list: each frame once,
-> after the frames it depends on, so that its type can refer to theirs
PROC collectFrames(c: PTR TO component, frames, depth)
  DEF ch: PTR TO component, f: PTR TO component
  IF depth > 8 THEN RETURN
  IF c.kind = CK_USE
    f := frameOf(c)
    IF f
      IF frameListed(frames, f.name) = FALSE
        collectFrames(f, frames, depth + 1)
        IF frameListed(frames, f.name) = FALSE THEN ListAdd(frames, [f], 1)
      ENDIF
    ENDIF
  ENDIF
  ch := c.firstChild
  WHILE ch
    collectFrames(ch, frames, depth)
    ch := ch.next
  ENDWHILE
ENDPROC

-> The windows followed by the frames they use, as one list (n entries of forms
-> are windows). Sets the folder the frame paths are relative to.
PROC withFrames(path, forms: PTR TO LONG, n)
  DEF all, i, frames
  genBase := dirPart(path)
  frames := List(40)
  FOR i := 0 TO n - 1 DO collectFrames(forms[i], frames, 0)
  all := List(n + ListLen(frames) + 1)
  FOR i := 0 TO n - 1 DO ListAdd(all, [forms[i]], 1)
  FOR i := 0 TO ListLen(frames) - 1 DO ListAdd(all, [ListItem(frames, i)], 1)
ENDPROC all

/*** fields ***/

PROC declareLeaves(fh, c: PTR TO component)
  DEF ch: PTR TO component
  IF isContainer(c.kind) = FALSE
    put(fh, '  ')
    put(fh, c.name)
    IF c.kind = CK_USE
      put(fh, ': PTR TO t')
      put(fh, frameTypeName(c))
    ELSEIF c.kind = CK_FILEDLG
      put(fh, ': PTR TO tFileDialog')
    ELSEIF c.kind = CK_MSGDLG
      put(fh, ': PTR TO tMessageDialog')
    ENDIF
    put(fh, '\n')
    IF c.kind = CK_MEMO
      put(fh, '  ')
      put(fh, c.name)
      put(fh, 'Slider\n')
    ENDIF
  ENDIF
  ch := c.firstChild
  WHILE ch
    declareLeaves(fh, ch)
    ch := ch.next
  ENDWHILE
ENDPROC

/*** leaf widgets ***/

-> The title of the window a component belongs to
PROC windowTitle(c: PTR TO component)
  WHILE c.parent DO c := c.parent
  IF c.title THEN RETURN c.title
ENDPROC ''

PROC leafExpr(fh, c: PTR TO component)
  DEF kind
  kind := c.kind
  SELECT kind
    CASE CK_BUTTON
      IF (c.propFlags = 0) AND (effectiveFont(c) = 0)
        put(fh, 'SimpleButton(')
        quoted(fh, c.title)
        put(fh, ')')
      ELSE
        -> SimpleButton() takes no tags, so spell the button out
        put(fh, 'TextObject, ButtonFrame, MUIA_Text_Contents, ')
        quoted(fh, c.title)
        put(fh, ', MUIA_Text_PreParse, \a\\ec\a, MUIA_InputMode, MUIV_InputMode_RelVerify, ')
        put(fh, 'MUIA_Background, MUII_ButtonBack')
        IF effectiveFont(c) = 0 THEN put(fh, ', MUIA_Font, MUIV_Font_Button')
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
      put(fh, 'CycleObject, MUIA_Cycle_Entries, ')
      putItems(fh, c.title)
      IF effectiveFont(c) = 0 THEN put(fh, ', MUIA_Font, MUIV_Font_Button')
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
    CASE CK_FILEDLG
      put(fh, 'delpheFileDialog(')
      quoted(fh, c.title)
      put(fh, ', ')
      IF c.propFlags AND PF_ARG
        quoted(fh, c.arg)
      ELSE
        put(fh, '\a#?\a')
      ENDIF
      IF c.propFlags AND PF_SAVE THEN put(fh, ', TRUE)') ELSE put(fh, ', FALSE)')
    CASE CK_MSGDLG
      put(fh, 'delpheMessageDialog(')
      quoted(fh, c.title)
      put(fh, ', ')
      IF c.propFlags AND PF_ARG
        quoted(fh, c.arg)
      ELSE
        put(fh, '\aOK\a')
      ENDIF
      put(fh, ', ')
      quoted(fh, windowTitle(c))
      put(fh, ')')
    CASE CK_SPACER
      put(fh, 'RectangleObject')
      emitLeafExtras(fh, c)
      put(fh, ', End')
    CASE CK_MEMO
      -> the extras go on the group around the editor and its scrollbar
      put(fh, 'Mui_NewObjectA(\aTextEditor.mcc\a, [MUIA_TextEditor_Slider, self.')
      put(fh, c.name)
      put(fh, 'Slider, MUIA_TextEditor_Contents, ')
      quoted(fh, c.title)
      put(fh, ', TAG_DONE])')
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
  IF c.kind = CK_USE
    -> an instance of a frame: its events get their own range of ids
    useCounter++
    put(fh, '  NEW self.')
    put(fh, c.name)
    put(fh, '\n  self.')
    put(fh, c.name)
    put(fh, '.idBase := self.idBase + ')
    putNum(fh, useCounter * 1000)
    put(fh, '\n  self.')
    put(fh, c.name)
    put(fh, '.create()\n')
  ELSEIF isContainer(c.kind) = FALSE
    IF c.kind = CK_MEMO
      put(fh, '  self.')
      put(fh, c.name)
      put(fh, 'Slider := ScrollbarObject, MUIA_Group_Horiz, FALSE, End\n')
    ENDIF
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

  IF c.kind = CK_USE
    -> the frame's group inside a plain group that takes this use's weight, size, ...
    put(fh, 'VGroup,\n')
    emitGroupExtras(fh, c, depth)
    indent(fh, depth + 1)
    put(fh, 'Child, self.')
    put(fh, c.name)
    put(fh, '.handle,\n')
    indent(fh, depth)
    put(fh, 'End')
    RETURN
  ENDIF

  IF c.kind = CK_MEMO
    put(fh, 'HGroup,\n')
    indent(fh, depth + 1)
    put(fh, 'MUIA_Group_Spacing, 0,\n')
    emitGroupExtras(fh, c, depth)
    indent(fh, depth + 1)
    put(fh, 'Child, self.')
    put(fh, c.name)
    put(fh, ',\n')
    indent(fh, depth + 1)
    put(fh, 'Child, self.')
    put(fh, c.name)
    put(fh, 'Slider,\n')
    indent(fh, depth)
    put(fh, 'End')
    RETURN
  ENDIF

  IF isContainer(c.kind) = FALSE
    put(fh, 'self.')
    put(fh, c.name)
    RETURN
  ENDIF

  kind := c.kind
  IF kind = CK_FRAME
    ch := rootOf(c)
    IF ch
      containerExpr(fh, ch, depth)
    ELSE
      put(fh, 'RectangleObject, End')
    ENDIF
    RETURN
  ENDIF
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
      ch := rootOf(c)
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
    CASE CK_COLGROUP
      put(fh, 'ColGroup(')
      putNum(fh, numOr(c, PF_VALUE, c.value, 2))
      put(fh, '),\n')
      emitGroupExtras(fh, c, depth)
      emitChildren(fh, c, depth)
    CASE CK_SCROLL
      -> the children go in a virtual group, which the scroll group scrolls
      put(fh, 'ScrollgroupObject,\n')
      emitGroupExtras(fh, c, depth)
      indent(fh, depth + 1)
      put(fh, 'MUIA_Scrollgroup_Contents, VirtgroupObject,\n')
      emitChildren(fh, c, depth + 1)
      indent(fh, depth + 1)
      put(fh, 'End,\n')
    CASE CK_PAGES
      put(fh, 'RegisterGroup(')
      putPageTitles(fh, c)
      put(fh, '),\n')
      indent(fh, depth + 1)
      put(fh, 'MUIA_Register_Frame, MUI_TRUE,\n')
      emitGroupExtras(fh, c, depth)
      emitChildren(fh, c, depth)
      -> a Register needs at least one page
      IF c.firstChild = NIL
        indent(fh, depth + 1)
        put(fh, 'Child, RectangleObject, End,\n')
      ENDIF
  ENDSELECT

  indent(fh, depth)
  put(fh, 'End')
ENDPROC

-> The tab titles of a Pages component as an E list: exactly one per page, as in
-> the live form
PROC putPageTitles(fh, c: PTR TO component)
  DEF n, k, count, item, ch: PTR TO component
  n := 0
  ch := c.firstChild
  WHILE ch
    n++
    ch := ch.next
  ENDWHILE
  count := n
  IF count < 1 THEN count := 1
  put(fh, '[')
  FOR k := 0 TO count - 1
    item := nthItem(c.title, k)
    IF item
      IF StrLen(item) = 0 THEN item := NIL
    ENDIF
    IF item
      quoted(fh, item)
    ELSEIF n = 0
      put(fh, '\a(empty)\a')
    ELSE
      put(fh, '\aPage ')
      putNum(fh, k + 1)
      put(fh, '\a')
    ENDIF
    put(fh, ', ')
  ENDFOR
  put(fh, 'NIL]')
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
  IF kind = CK_USE
    put(fh, '  self.')
    put(fh, c.name)
    put(fh, '.connect(app)\n')
  ENDIF
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
      put(fh, 'self.idBase + ')
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

-> Passes every event on to the frames this one uses, which react to their own range
PROC emitForwards(fh, c: PTR TO component)
  DEF ch: PTR TO component
  IF c.kind = CK_USE
    put(fh, '  self.')
    put(fh, c.name)
    put(fh, '.handleEvent(id)\n')
  ENDIF
  ch := c.firstChild
  WHILE ch
    emitForwards(fh, ch)
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

PROC genObject(fh, win: PTR TO component)
  put(fh, 'OBJECT t')
  put(fh, win.name)
  put(fh, '\n  handle\n  idBase\n')
  declareLeaves(fh, win)
  put(fh, 'ENDOBJECT\n\n')
ENDPROC

PROC genProcs(fh, win: PTR TO component)
  put(fh, 'PROC create() OF t')
  put(fh, win.name)
  put(fh, '\n')
  useCounter := 0
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
    -> event numbers are relative to idBase so that several forms can share a loop
    put(fh, '  DEF ev\n  ev := id - self.idBase\n  SELECT ev\n')
    evCounter := 0
    emitDispatch(fh, win)
    put(fh, '  ENDSELECT\n')
  ENDIF
  emitForwards(fh, win)
  put(fh, 'ENDPROC\n\n')

  -> only a window can be shown and hidden
  IF win.kind = CK_WINDOW
    put(fh, 'PROC show() OF t')
    put(fh, win.name)
    put(fh, '\n  set(self.handle, MUIA_Window_Open, MUI_TRUE)\nENDPROC\n\n')

    put(fh, 'PROC hide() OF t')
    put(fh, win.name)
    put(fh, '\n  set(self.handle, MUIA_Window_Open, FALSE)\nENDPROC\n\n')
  ENDIF

ENDPROC

-> part: 0 = object and procedures in one region, 1 = just the object,
-> 2 = just the procedures (a program with several forms needs every OBJECT
-> before its global variables, which must come before any procedure)
PROC genRegion(fh, win: PTR TO component, tag, part)
  markLine(fh, TRUE, tag)
  put(fh, ' (generated by DelphE: edit the form in the designer, not here)\n\n')
  IF part <> 2 THEN genObject(fh, win)
  IF part <> 1 THEN genProcs(fh, win)
  markLine(fh, FALSE, tag)
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
          StrAdd(appended, ' (components are fields of self, e.g. self.', ALL)
          StrAdd(appended, c.name, ALL)
          StrAdd(appended, ')', ALL)
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
  put(fh, '\n**\n** Created by DelphE. This file is yours: the form itself lives in the .gen.e file\n')
  put(fh, '** next to it, which DelphE rewrites and inserts at the marker line below.\n*/\n\n')
  put(fh, 'OPT PREPROCESS\n\n')
  put(fh, 'MODULE \amuimaster\a, \alibraries/mui\a, \autility/tagitem\a,\n')
  put(fh, '       \aamigalib/boopsi\a\n\n')
  put(fh, userMarkLine())
  put(fh, '\n')
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

-> The generated file that belongs to a program file: Main.e -> Main.gen.e
PROC genPath(path)
  DEF s, n
  n := StrLen(path)
  s := String(n + 8)
  StrCopy(s, path, ALL)
  IF n > 2
    IF (path[n - 2] = ".") AND ((path[n - 1] = "e") OR (path[n - 1] = "E")) THEN SetStr(s, n - 2)
  ENDIF
  StrAdd(s, '.gen.e', ALL)
ENDPROC s

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
  IF anyUses(forms, n, CK_MSGDLG)
    put(fh, '-> a message requester: call execute(); it returns the number of the button chosen\n')
    put(fh, 'OBJECT tMessageDialog\n  text: PTR TO CHAR\n  buttons: PTR TO CHAR\n  windowTitle: PTR TO CHAR\nENDOBJECT\n\n')
  ENDIF
ENDPROC

PROC genRuntimeProcs(fh, forms: PTR TO LONG, n)
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
  used := FALSE
  FOR i := 0 TO n - 1
    IF usesKind(forms[i], CK_MEMO) THEN used := TRUE
  ENDFOR
  IF used
    put(fh, '-> tags of TextEditor.mcc (the Memo component)\nCONST MUIA_TextEditor_Contents = $ad000002, MUIA_TextEditor_Slider = $ad00001a\n\n')
  ENDIF
ENDPROC

-> Opens the generated file and writes its banner
PROC openGenFile(path)
  DEF fh
  fh := Open(path, MODE_NEWFILE)
  IF fh THEN put(fh, '-> Generated by DelphE from the form: do not edit. It is inserted into the program\n-> file at compile time, and rewritten every time you generate, compile or run.\n\n')
ENDPROC fh

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
-> not one of the helper types and is not an object the user defined. Fills
-> orphanList with them, comma separated.
PROC scanOrphans(buf: PTR TO CHAR, forms: PTR TO LONG, n)
  DEF p, q, tn, start, i, known, typeName, name, pat, win: PTR TO component, count
  orphanList := String(300)
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
      IF count > 1 THEN StrAdd(orphanList, ', ', ALL)
      name := String(p - start + 1)
      IF p > start THEN MidStr(name, buf, start, p - start)
      StrAdd(orphanList, name, ALL)
      StrAdd(orphanList, ' (t', ALL)
      StrAdd(orphanList, typeName, ALL)
      StrAdd(orphanList, ')', ALL)
    ENDIF
    p := InStr(buf, '() OF t', tn)
  ENDWHILE
  IF count = 0 THEN orphanList := NIL
ENDPROC

-> The orphaned handlers found by the last generation, or NIL if there were none
PROC orphanReport() IS orphanList

/*
** Creates the user's program file, or brings it up to date: handler stubs are
** appended for handlers it does not define yet, and an old-style file (with the
** generated code inside it) is converted, keeping the old one as path.bak.
** projName is NIL for a single form. Returns GEN_OK, GEN_WRITEFAIL or
** GEN_NOMARKERS (the file has neither marker, so it is not one of ours).
*/
PROC syncUserFile(path, projName, forms: PTR TO LONG, n)
  DEF buf, len, cur, clen, fh, i, win: PTR TO component, appended, old

  appended := String(30000)
  orphanList := NIL
  buf, len := readAll(path)

  IF buf = NIL
    FOR i := 0 TO n - 1
      win := forms[i]
      collectStubs(win, '', appended, win)
    ENDFOR
    fh := Open(path, MODE_NEWFILE)
    IF fh = NIL THEN RETURN GEN_WRITEFAIL
    win := forms[0]
    IF projName THEN genProjectHeader(fh, projName) ELSE genHeader(fh, win)
    put(fh, '\n/*** your code ***/\n')
    put(fh, appended)
    IF projName THEN genProjectMain(fh) ELSE genMain(fh, win)
    Close(fh)
    RETURN GEN_OK
  ENDIF

  old := FALSE
  cur := buf
  clen := len
  IF InStr(buf, beginMark()) <> -1
    cur, clen := stripRegions(buf, len)
    IF cur = NIL THEN RETURN GEN_NOMARKERS
    old := TRUE
  ELSEIF InStr(buf, userMark()) = -1
    RETURN GEN_NOMARKERS
  ENDIF

  scanOrphans(cur, forms, n)
  FOR i := 0 TO n - 1
    win := forms[i]
    collectStubs(win, cur, appended, win)
  ENDFOR
  IF (old = FALSE) AND (StrLen(appended) = 0) THEN RETURN GEN_OK

  IF old THEN writeBackup(path, buf, len)
  fh := Open(path, MODE_NEWFILE)
  IF fh = NIL THEN RETURN GEN_WRITEFAIL
  Write(fh, cur, clen)
  put(fh, appended)
  Close(fh)
ENDPROC GEN_OK

-> Writes the generated file (path.gen.e) and updates the user's file. Returns
-> GEN_OK, GEN_WRITEFAIL or GEN_NOMARKERS.
PROC generateFile(path, win: PTR TO component)
  DEF gp, fh, res, all, i
  gp := genPath(path)
  all := withFrames(path, [win], 1)
  fh := openGenFile(gp)
  IF fh = NIL THEN RETURN GEN_WRITEFAIL
  genConstants(fh, all, ListLen(all))
  genRuntimeTypes(fh, all, ListLen(all))
  genRuntimeProcs(fh, all, ListLen(all))
  -> the frames the form uses come first, each with its object and procedures
  FOR i := 1 TO ListLen(all) - 1
    genRegion(fh, ListItem(all, i), NIL, 0)
  ENDFOR
  genRegion(fh, win, NIL, 0)
  Close(fh)
  res := syncUserFile(path, NIL, all, ListLen(all))
ENDPROC res

/*
** Writes the program the compiler gets: the user's file with the generated file
** inserted after its marker line. Returns the number of the first inserted line
** and how many lines were inserted, so that compiler messages can be traced
** back, or -1, 0 if the files cannot be read or have no marker.
*/
PROC buildSource(userPath, buildPath)
  DEF buf, len, gbuf, glen, m, nx, fh, i, first, glines
  buf, len := readAll(userPath)
  gbuf, glen := readAll(genPath(userPath))
  IF (buf = NIL) OR (gbuf = NIL) THEN RETURN -1, 0
  m := InStr(buf, userMark())
  IF m = -1 THEN RETURN -1, 0
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

  fh := Open(buildPath, MODE_NEWFILE)
  IF fh = NIL THEN RETURN -1, 0
  Write(fh, buf, nx)
  Write(fh, gbuf, glen)
  IF glen > 0
    IF gbuf[glen - 1] <> 10 THEN Write(fh, '\n', 1)
  ENDIF
  IF len > nx THEN Write(fh, buf + nx, len - nx)
  Close(fh)
ENDPROC first, glines

/*** projects: several forms in one program ***/

PROC genProjectHeader(fh, projName)
  put(fh, '/*\n** ')
  put(fh, projName)
  put(fh, '\n**\n** Created by DelphE. This file is yours: the forms live in the .gen.e file\n')
  put(fh, '** next to it, which DelphE rewrites and inserts at the marker line below.\n*/\n\n')
  put(fh, 'OPT PREPROCESS\nOPT LARGE\n\n')
  put(fh, 'MODULE \amuimaster\a, \alibraries/mui\a, \autility/tagitem\a,\n')
  put(fh, '       \aamigalib/boopsi\a\n\n')
  put(fh, userMarkLine())
  put(fh, '\n')
ENDPROC

-> "form MainForm" / "type MainForm": the tag of a form's region
PROC formTag(prefix, win: PTR TO component)
  DEF s
  s := String(StrLen(win.name) + StrLen(prefix) + 4)
  StrCopy(s, prefix, ALL)
  StrAdd(s, ' ', ALL)
  StrAdd(s, win.name, ALL)
ENDPROC s

-> The global variables: one pointer per form, and the application
PROC genGlobalsRegion(fh, forms: PTR TO LONG, n)
  DEF i, win: PTR TO component
  markLine(fh, TRUE, 'globals')
  put(fh, ' (generated by DelphE: edit the project in the designer, not here)\n\n')
  put(fh, 'DEF delpheApp')
  FOR i := 0 TO n - 1
    win := forms[i]
    put(fh, ',\n    fm')
    put(fh, win.name)
    put(fh, ': PTR TO t')
    put(fh, win.name)
  ENDFOR
  put(fh, '\n\n')
  markLine(fh, FALSE, 'globals')
  put(fh, '\n')
ENDPROC

-> The procedure that creates every form, runs the application and cleans up
PROC genRunRegion(fh, projName, forms: PTR TO LONG, n)
  DEF i, win: PTR TO component
  markLine(fh, TRUE, 'project')
  put(fh, ' (generated by DelphE: edit the project in the designer, not here)\n\n')
  put(fh, 'PROC delpheRun() HANDLE\n')
  put(fh, '  DEF app = NIL, sigs = 0, id, running\n\n')
  put(fh, '  IF (muimasterbase := OpenLibrary(MUIMASTER_NAME, MUIMASTER_VMIN)) = NIL THEN\n')
  put(fh, '    Raise(\aFailed to open muimaster.library\a)\n\n')

  FOR i := 0 TO n - 1
    win := forms[i]
    put(fh, '  NEW fm')
    put(fh, win.name)
    put(fh, '\n  fm')
    put(fh, win.name)
    put(fh, '.idBase := ')
    putNum(fh, Mul(i + 1, 100000))
    put(fh, '\n  fm')
    put(fh, win.name)
    put(fh, '.create()\n  IF fm')
    put(fh, win.name)
    put(fh, '.handle = NIL THEN Raise(\aFailed to create a window\a)\n')
  ENDFOR

  put(fh, '\n  app := ApplicationObject,\n')
  put(fh, '    MUIA_Application_Title      , ')
  quoted(fh, projName)
  put(fh, ',\n    MUIA_Application_Base       , \aDELPHEPROJECT\a,\n')
  FOR i := 0 TO n - 1
    win := forms[i]
    put(fh, '    SubWindow, fm')
    put(fh, win.name)
    put(fh, '.handle,\n')
  ENDFOR
  put(fh, '  End\n\n')
  put(fh, '  IF app = NIL THEN Raise(\aFailed to create Application.\a)\n')
  put(fh, '  delpheApp := app\n\n')

  FOR i := 0 TO n - 1
    win := forms[i]
    put(fh, '  fm')
    put(fh, win.name)
    put(fh, '.connect(app)\n')
  ENDFOR
  put(fh, '\n')
  -> closing the first (main) form quits; the others just hide
  FOR i := 0 TO n - 1
    win := forms[i]
    put(fh, '  doMethodA(fm')
    put(fh, win.name)
    put(fh, '.handle, [MUIM_Notify, MUIA_Window_CloseRequest, MUI_TRUE,\n')
    IF i = 0
      put(fh, '    app, 2, MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])\n')
    ELSE
      put(fh, '    fm')
      put(fh, win.name)
      put(fh, '.handle, 3, MUIM_Set, MUIA_Window_Open, FALSE])\n')
    ENDIF
  ENDFOR

  win := forms[0]
  put(fh, '\n  fm')
  put(fh, win.name)
  put(fh, '.show()\n\n')
  put(fh, '  running := TRUE\n  WHILE running\n')
  put(fh, '    id := doMethodA(app, [MUIM_Application_NewInput, {sigs}])\n')
  put(fh, '    IF id = MUIV_Application_ReturnID_Quit\n      running := FALSE\n    ELSE\n')
  FOR i := 0 TO n - 1
    win := forms[i]
    put(fh, '      fm')
    put(fh, win.name)
    put(fh, '.handleEvent(id)\n')
  ENDFOR
  put(fh, '    ENDIF\n    IF running AND sigs THEN sigs := Wait(sigs)\n  ENDWHILE\n\n')
  FOR i := 0 TO n - 1
    win := forms[i]
    put(fh, '  fm')
    put(fh, win.name)
    put(fh, '.hide()\n')
  ENDFOR
  put(fh, '\nEXCEPT DO\n')
  put(fh, '  IF app THEN Mui_DisposeObject(app)\n')
  put(fh, '  IF muimasterbase THEN CloseLibrary(muimasterbase)\n')
  put(fh, '  IF exception THEN WriteF(\a\\s\\n\a, exception)\n')
  put(fh, 'ENDPROC\n')
  markLine(fh, FALSE, 'project')
  put(fh, '\n')
ENDPROC

PROC genProjectMain(fh)
  put(fh, '\nPROC main()\n  delpheRun()\nENDPROC\n')
ENDPROC

/*
** Writes the generated file of a project (path.gen.e): one OBJECT region per
** form, the globals region, one procedure region per form and the run region,
** then updates the user's file. forms is a list of window components (the
** first is the main form). Returns GEN_OK, GEN_WRITEFAIL or GEN_NOMARKERS.
*/
PROC generateProject(path, projName, forms: PTR TO LONG, n)
  DEF fh, i, win: PTR TO component, tag, all, total

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
  Close(fh)
ENDPROC syncUserFile(path, projName, all, total)
