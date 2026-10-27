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
**
** The work is shared by four modules: GenOut (writing text), GenRuntime (the helpers a generated
** file carries), this one (a form or project to E source), and GenFiles (the user's file and
** the program the compiler gets).
*/

OPT MODULE
OPT EXPORT
OPT LARGE

MODULE 'dos/dos', 'exec/memory', '*FormModel', '*MForm', '*Util', '*GenOut', '*GenRuntime'

CONST GEN_OK = 0, GEN_WRITEFAIL = 1, GEN_NOMARKERS = 2, GEN_NOWINDOW = 3

DEF evCounter, genMainName, genBase, useCounter  -> genBase: the folder that the paths of used frames are relative to


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
-> the line above the user's global variables, which end at the generated code
PROC globalsMark() IS '->>> DELPHE GLOBALS'
PROC globalsMarkLine() IS '->>> DELPHE GLOBALS (your global variables, constants and object types: they must come before the generated code)'
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

/*** windows ***/

-> A window's ID: what the user set, else the first four letters of its name in capitals
PROC windowId(win: PTR TO component)
  DEF s, i, ch, n, nm
  s := String(8)
  IF win.propFlags AND PF_ARG
    StrCopy(s, win.arg, 4)
    RETURN s
  ENDIF
  nm := win.name
  n := StrLen(nm)
  IF n > 4 THEN n := 4
  FOR i := 0 TO n - 1
    ch := nm[i]
    IF (ch >= "a") AND (ch <= "z") THEN ch := ch - 32
    s[i] := ch
  ENDFOR
  SetStr(s, n)
ENDPROC s

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
  IF (isContainer(c.kind) = FALSE) OR isMenuKind(c.kind)
    put(fh, '  ')
    put(fh, c.name)
    IF c.kind = CK_USE
      put(fh, ': PTR TO t')
      put(fh, frameTypeName(c))
    ELSEIF c.kind = CK_TIMER
      put(fh, ': PTR TO tTimer')
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
      putPair(fh, 'SliderObject, MUIA_Numeric_Min, ', numberOr(c, PF_MIN, c.minV, 0))
      putPair(fh, ', MUIA_Numeric_Max, ', numberOr(c, PF_MAX, c.maxV, 100))
      putPair(fh, ', MUIA_Numeric_Value, ', numberOr(c, PF_VALUE, c.value, 0))
      IF c.propFlags AND PF_VERT THEN put(fh, ', MUIA_Group_Horiz, FALSE')
      emitLeafExtras(fh, c)
      put(fh, ', End')
    CASE CK_GAUGE
      put(fh, 'GaugeObject, GaugeFrame, MUIA_Gauge_Horiz, ')
      IF c.propFlags AND PF_VERT THEN put(fh, 'FALSE') ELSE put(fh, 'MUI_TRUE')
      putPair(fh, ', MUIA_Gauge_Max, ', numberOr(c, PF_MAX, c.maxV, 100))
      putPair(fh, ', MUIA_Gauge_Current, ', numberOr(c, PF_VALUE, c.value, 0))
      emitLeafExtras(fh, c)
      put(fh, ', End')
    CASE CK_TIMER
      put(fh, 'delpheTimer(')
      putNum(fh, numberOr(c, PF_VALUE, c.value, 1000))
      IF c.propFlags AND PF_DISABLED THEN put(fh, ', FALSE)') ELSE put(fh, ', TRUE)')
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
    CASE CK_BALANCE
      put(fh, 'BalanceObject')
      emitLeafExtras(fh, c)
      put(fh, ', End')
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

-> The name of the window's menu strip
PROC stripName(win: PTR TO component)
  DEF s: PTR TO component
  s := menustripOf(win)
  IF s THEN RETURN s.name
ENDPROC ''

-> The objects of a menu strip, from the items up: a menu is made of its items
PROC createMenuTree(fh, c: PTR TO component)
  DEF ch: PTR TO component, t
  t := c.title
  ch := c.firstChild
  WHILE ch
    createMenuTree(fh, ch)
    ch := ch.next
  ENDWHILE
  put(fh, '  self.')
  put(fh, c.name)
  put(fh, ' := ')
  IF c.kind = CK_MENUSTRIP
    put(fh, 'MenustripObject')
  ELSEIF c.kind = CK_MENU
    put(fh, 'MenuObject, MUIA_Menu_Title, ')
    quoted(fh, c.title)
  ELSE
    put(fh, 'MenuitemObject, MUIA_Menuitem_Title, ')
    -> a title of "-" is a separator bar (NM_BARLABEL, which is -1)
    IF (StrLen(t) = 1) AND (t[0] = "-") THEN put(fh, '-1') ELSE quoted(fh, c.title)
    IF c.propFlags AND PF_ARG
      IF StrLen(c.arg) > 0
        put(fh, ', MUIA_Menuitem_Shortcut, ')
        quoted(fh, c.arg)
      ENDIF
    ENDIF
    IF c.propFlags AND PF_SAVE THEN put(fh, ', MUIA_Menuitem_Checkit, MUI_TRUE')
    IF c.propFlags AND PF_DISABLED THEN put(fh, ', MUIA_Menuitem_Enabled, FALSE')
  ENDIF
  ch := c.firstChild
  WHILE ch
    put(fh, ', MUIA_Family_Child, self.')
    put(fh, ch.name)
    ch := ch.next
  ENDWHILE
  put(fh, ', End\n')
ENDPROC

PROC createLeaves(fh, c: PTR TO component)
  DEF ch: PTR TO component
  IF c.kind = CK_MENUSTRIP
    createMenuTree(fh, c)
    RETURN
  ENDIF
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
      -> a window ID is a 4-char ULONG ("MAIN"), not a string pointer; it is what MUI
      -> remembers the window's place under, so each form needs its own
      put(fh, 'MUIA_Window_ID, \q')
      put(fh, windowId(c))
      put(fh, '\q,\n')
      IF c.propFlags AND PF_FIXW
        indent(fh, depth + 1)
        putPair(fh, 'MUIA_Window_Width, ', c.fixW)
        put(fh, ',\n')
      ENDIF
      IF c.propFlags AND PF_FIXH
        indent(fh, depth + 1)
        putPair(fh, 'MUIA_Window_Height, ', c.fixH)
        put(fh, ',\n')
      ENDIF
      IF c.propFlags AND PF_CENTER
        indent(fh, depth + 1)
        put(fh, 'MUIA_Window_LeftEdge, MUIV_Window_LeftEdge_Centered,\n')
        indent(fh, depth + 1)
        put(fh, 'MUIA_Window_TopEdge, MUIV_Window_TopEdge_Centered,\n')
      ENDIF
      indent(fh, depth + 1)
      IF menustripOf(c)
        put(fh, 'MUIA_Window_Menustrip, self.')
        put(fh, stripName(c))
        put(fh, ',\n')
        indent(fh, depth + 1)
      ENDIF
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
      putNum(fh, numberOr(c, PF_VALUE, c.value, 2))
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
-> Does this component have an event that goes through a return ID? A timer's event
-> is polled instead.
PROC hasEvent(c: PTR TO component)
  IF c.handler = NIL THEN RETURN FALSE
  IF eventName(c.kind) = NIL THEN RETURN FALSE
  IF c.kind = CK_TIMER THEN RETURN FALSE
ENDPROC TRUE

PROC emitConnect(fh, c: PTR TO component)
  DEF ch: PTR TO component, kind
  kind := c.kind
  IF kind = CK_USE
    put(fh, '  self.')
    put(fh, c.name)
    put(fh, '.connect(app)\n')
  ENDIF
  IF hasEvent(c)
    evCounter++
    IF kind = CK_WINDOW
      put(fh, '  doMethodA(self.handle')
    ELSE
      put(fh, '  doMethodA(self.')
      put(fh, c.name)
    ENDIF
    SELECT kind
      CASE CK_WINDOW
        put(fh, ', [MUIM_Notify, MUIA_Window_CloseRequest, MUI_TRUE, app, 2, MUIM_Application_ReturnID, ')
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
      CASE CK_MENUITEM
        put(fh, ', [MUIM_Notify, MUIA_Menuitem_Trigger, MUIV_EveryTime, app, 2, MUIM_Application_ReturnID, ')
    ENDSELECT
    put(fh, 'self.idBase + ')
    putNum(fh, evCounter)
    put(fh, '])\n')
  ENDIF
  ch := c.firstChild
  WHILE ch
    emitConnect(fh, ch)
    ch := ch.next
  ENDWHILE
ENDPROC

PROC emitDispatch(fh, c: PTR TO component)
  DEF ch: PTR TO component
  IF hasEvent(c)
    evCounter++
    put(fh, '    CASE ')
    putNum(fh, evCounter)
    IF c.kind = CK_WINDOW
      -> the handler may set self.keepOpen to stop the window closing
      put(fh, '\n      self.keepOpen := FALSE\n      self.')
      put(fh, c.handler)
      put(fh, '()\n      IF self.keepOpen = FALSE THEN self.closeWindow()\n')
    ELSE
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

-> What each form does with its timers, and those of the frames it uses:
-> mode 0 = call the handler of each timer that has gone off, 1 = the signals to wait
-> for, 2 = give the timers back
PROC emitTimerWalk(fh, c: PTR TO component, mode)
  DEF ch: PTR TO component
  IF c.kind = CK_TIMER
    SELECT mode
      CASE 0
        put(fh, '  IF self.')
        put(fh, c.name)
        put(fh, '.fired()\n')
        IF c.handler
          put(fh, '    self.')
          put(fh, c.handler)
          put(fh, '()\n')
        ENDIF
        put(fh, '  ENDIF\n')
      CASE 1
        put(fh, '  m := m OR self.')
        put(fh, c.name)
        put(fh, '.sigMask()\n')
      CASE 2
        put(fh, '  self.')
        put(fh, c.name)
        put(fh, '.release()\n')
    ENDSELECT
  ELSEIF c.kind = CK_USE
    put(fh, '  ')
    IF mode = 1 THEN put(fh, 'm := m OR ')
    put(fh, 'self.')
    put(fh, c.name)
    IF mode = 0 THEN put(fh, '.poll()\n')
    IF mode = 1 THEN put(fh, '.timerMask()\n')
    IF mode = 2 THEN put(fh, '.releaseTimers()\n')
  ENDIF
  ch := c.firstChild
  WHILE ch
    emitTimerWalk(fh, ch, mode)
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
  IF hasEvent(c) THEN n := 1
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
  IF win.kind = CK_WINDOW THEN put(fh, '  keepOpen\n')
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

  -> timers: the program loop calls poll() and waits for timerMask()
  put(fh, 'PROC poll() OF t')
  put(fh, win.name)
  put(fh, '\n')
  emitTimerWalk(fh, win, 0)
  put(fh, 'ENDPROC\n\n')
  put(fh, 'PROC timerMask() OF t')
  put(fh, win.name)
  put(fh, '\n  DEF m\n  m := 0\n')
  emitTimerWalk(fh, win, 1)
  put(fh, 'ENDPROC m\n\n')
  put(fh, 'PROC releaseTimers() OF t')
  put(fh, win.name)
  put(fh, '\n')
  emitTimerWalk(fh, win, 2)
  put(fh, 'ENDPROC\n\n')

  -> only a window can be shown and hidden
  IF win.kind = CK_WINDOW
    -> what closing the window does: the main form ends the program, another just hides
    put(fh, 'PROC closeWindow() OF t')
    put(fh, win.name)
    put(fh, '\n')
    IF StrLen(win.name) = StrLen(genMainName)
      IF StrCmp(win.name, genMainName, ALL)
        put(fh, '  doMethodA(delpheApp, [MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])\n')
      ELSE
        put(fh, '  set(self.handle, MUIA_Window_Open, FALSE)\n')
      ENDIF
    ELSE
      put(fh, '  set(self.handle, MUIA_Window_Open, FALSE)\n')
    ENDIF
    put(fh, 'ENDPROC\n\n')
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
PROC collectStubs(c: PTR TO component, buf, appended: PTR TO strbuf, win: PTR TO component)
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
        IF InStr(appended.buf, sig) = -1
          sbAdd(appended, '\n')
          sbAdd(appended, sig)
          sbAdd(appended, '\n  -> TODO: handle ')
          sbAdd(appended, eventName(c.kind))
          sbAdd(appended, ' of ')
          sbAdd(appended, c.name)
          sbAdd(appended, ' (components are fields of self, e.g. self.')
          sbAdd(appended, c.name)
          sbAdd(appended, ')')
          sbAdd(appended, '\nENDPROC\n')
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


/*** projects: several forms in one program ***/

PROC genProjectHeader(fh, projName)
  put(fh, '/*\n** ')
  put(fh, projName)
  put(fh, '\n**\n** Created by DelphE. This file is yours: the forms live in the .gen.e file\n')
  put(fh, '** next to it, which DelphE rewrites and inserts at the marker line below.\n*/\n\n')
  put(fh, 'OPT PREPROCESS\nOPT LARGE\n\n')
  put(fh, 'MODULE \amuimaster\a, \alibraries/mui\a, \autility/tagitem\a,\n')
  put(fh, '       \aamigalib/boopsi\a\n\n')
  put(fh, globalsMarkLine())
  put(fh, '\n\n')
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
  -> closing the first (main) form quits; the others just hide. A form with an
  -> OnClose handler does that itself, after the handler has run (closeWindow).
  FOR i := 0 TO n - 1
    win := forms[i]
    IF win.handler = NIL
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
    ENDIF
  ENDFOR

  win := forms[0]
  put(fh, '\n  fm')
  put(fh, win.name)
  put(fh, '.show()\n')
  -> the other forms that are to be open from the start
  FOR i := 1 TO n - 1
    win := forms[i]
    IF win.propFlags AND PF_OPEN
      put(fh, '  fm')
      put(fh, win.name)
      put(fh, '.show()\n')
    ENDIF
  ENDFOR
  put(fh, '\n')
  put(fh, '  running := TRUE\n  WHILE running\n')
  put(fh, '    id := doMethodA(app, [MUIM_Application_NewInput, {sigs}])\n')
  put(fh, '    IF id = MUIV_Application_ReturnID_Quit\n      running := FALSE\n    ELSE\n')
  FOR i := 0 TO n - 1
    win := forms[i]
    put(fh, '      fm')
    put(fh, win.name)
    put(fh, '.handleEvent(id)\n')
  ENDFOR
  put(fh, '    ENDIF\n    IF running\n')
  -> timers that have gone off run their handlers; then wait for MUI or a timer
  FOR i := 0 TO n - 1
    win := forms[i]
    put(fh, '      fm')
    put(fh, win.name)
    put(fh, '.poll()\n')
  ENDFOR
  put(fh, '      IF sigs THEN sigs := Wait(sigs')
  FOR i := 0 TO n - 1
    win := forms[i]
    put(fh, ' OR fm')
    put(fh, win.name)
    put(fh, '.timerMask()')
  ENDFOR
  put(fh, ')\n    ENDIF\n  ENDWHILE\n\n')
  FOR i := 0 TO n - 1
    win := forms[i]
    put(fh, '  fm')
    put(fh, win.name)
    put(fh, '.hide()\n')
  ENDFOR
  put(fh, '\nEXCEPT DO\n')
  FOR i := 0 TO n - 1
    win := forms[i]
    put(fh, '  IF fm')
    put(fh, win.name)
    put(fh, ' THEN fm')
    put(fh, win.name)
    put(fh, '.releaseTimers()\n')
  ENDFOR
  put(fh, '  IF app THEN Mui_DisposeObject(app)\n')
  put(fh, '  IF muimasterbase THEN CloseLibrary(muimasterbase)\n')
  put(fh, '  IF exception THEN delpheReport(exception, exceptioninfo)\n')
  put(fh, 'ENDPROC\n')
  markLine(fh, FALSE, 'project')
  put(fh, '\n')
ENDPROC

PROC genProjectMain(fh)
  put(fh, '\nPROC main()\n  delpheRun()\nENDPROC\n')
ENDPROC


-> The form whose window opens first (the main form of a project)
PROC setMainForm(name)
  genMainName := name
ENDPROC
