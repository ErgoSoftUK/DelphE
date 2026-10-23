/*
** DelphE form designer
**
**   Designer [file.mform]        (default: forms/sample.mform)
**
** Left: the component tree of the form. Right: properties of the selected
** component. Save writes the .mform back; Preview shows the form as live MUI
** objects in a second window, built from the current in-memory model.
*/

OPT PREPROCESS
OPT LARGE

MODULE 'libraries/gadtools', 'dos/dos', 'exec/memory', 'muimaster', 'libraries/mui', 'utility/tagitem',
       'amigalib/boopsi', 'intuition/classusr',
       '*/FormModel', '*/MForm', '*/Builder', '*/Generator', '*/Util',
       '*/mcc/listtree_mcc', '*/mcc/texteditor_mcc'

ENUM ID_SELECT = 1, ID_NAME, ID_TITLE, ID_SAVE, ID_PREVIEW,
     ID_ADD, ID_DELETE, ID_UP, ID_DOWN, ID_GENERATE,
     ID_HANDLER, ID_DEFHANDLER, ID_EDITHANDLER, ID_SAVECODE, ID_RELOADCODE, ID_COMPILE, ID_RUN, ID_NEW, ID_OPEN, ID_SAVEAS, ID_PROPS

DEF app, win, tree, strName, strTitle, txtKind, txtStatus,
    btnSave, btnPreview, previewWin,
    txtEvent, strHandler, btnDefHandler, btnEditHandler,
    pages, pageTitles, editor, slider, txtCodePath, btnSaveCode, btnReloadCode,
    logEditor, logSlider, btnCompile, btnRun,
    strWeight, strFixW, strFixH, strMin, strMax, strValue, strHint, chkDisabled, chkFrame, numBuf,
    menu, miNew, miOpen, miSave, miSaveAs, miQuit, miPreview, miGenerate, miCompile, miRun,
    dirty, titleBuf1, titleBuf2, titleFlip,
    cycKind, btnAdd, btnDelete, btnUp, btnDown, btnGenerate, kindNames,
    form: PTR TO component, filename,
    selected: PTR TO component, selectedNode

PROC status(msg) IS set(txtStatus, MUIA_Text_Contents, msg)

-> a menu item sends the given return ID to the main loop when chosen
PROC hookMenu(item, id)
  doMethodA(item, [MUIM_Notify, MUIA_Menuitem_Trigger, MUIV_EveryTime,
    app, 2, MUIM_Application_ReturnID, id])
ENDPROC

/*** tree ***/

PROC makeLabel(c: PTR TO component)
  DEF label
  label := String(StrLen(c.name) + 24)
  StringF(label, '\s \s', kindName(c.kind), c.name)
ENDPROC label

PROC addTree(c: PTR TO component, parentNode)
  DEF label, node, ch: PTR TO component, flags
  label := makeLabel(c)
  IF isContainer(c.kind) THEN flags := TNF_LIST OR TNF_OPEN ELSE flags := 0
  node := doMethodA(tree, [MUIM_Listtree_Insert, label, c, parentNode,
                           MUIV_Listtree_Insert_PrevNode_Tail, flags])
  -> label is deliberately not freed: the tree may keep the pointer
  c.uiNode := node
  ch := c.firstChild
  WHILE ch
    addTree(ch, node)
    ch := ch.next
  ENDWHILE
ENDPROC

PROC activeNode()
ENDPROC doMethodA(tree, [MUIM_Listtree_GetEntry, NIL,
                         MUIV_Listtree_GetEntry_Position_Active, 0])

PROC nodeComponent(node: PTR TO muis_listtree_treenode)
  IF node = NIL THEN RETURN NIL
ENDPROC node.tn_User

/*** inspector ***/

PROC onSelect()
  DEF c: PTR TO component, node

  -> apply a half-edited name to the component we are leaving
  commitEdits()

  node := activeNode()
  c := nodeComponent(node)
  selected := c
  selectedNode := node
  IF c = NIL
    set(txtKind, MUIA_Text_Contents, '')
    set(strName, MUIA_String_Contents, '')
    set(strTitle, MUIA_String_Contents, '')
    set(txtEvent, MUIA_Text_Contents, '')
    set(strHandler, MUIA_String_Contents, '')
    set(strHandler, MUIA_Disabled, MUI_TRUE)
    set(btnDefHandler, MUIA_Disabled, MUI_TRUE)
    showProps(NIL)
    RETURN
  ENDIF

  showProps(c)
  set(txtKind, MUIA_Text_Contents, kindName(c.kind))
  set(strName, MUIA_String_Contents, c.name)
  set(strTitle, MUIA_String_Contents, titleOf(c))
  IF eventName(c.kind)
    set(txtEvent, MUIA_Text_Contents, eventName(c.kind))
    set(strHandler, MUIA_String_Contents, handlerOf(c))
    set(strHandler, MUIA_Disabled, FALSE)
    set(btnDefHandler, MUIA_Disabled, FALSE)
  ELSE
    set(txtEvent, MUIA_Text_Contents, '(no events)')
    set(strHandler, MUIA_String_Contents, '')
    set(strHandler, MUIA_Disabled, MUI_TRUE)
    set(btnDefHandler, MUIA_Disabled, MUI_TRUE)
  ENDIF
ENDPROC

/*** layout properties ***/

-> Shows number n in a string gadget (blank if the property is not set)
PROC showNumber(gadget, flags, bit, n)
  IF flags AND bit
    StringF(numBuf, '\d', n)
  ELSE
    StrCopy(numBuf, '', ALL)
  ENDIF
  set(gadget, MUIA_String_Contents, numBuf)
ENDPROC

PROC showFlag(gadget, flags, bit)
  IF flags AND bit
    set(gadget, MUIA_Selected, MUI_TRUE)
  ELSE
    set(gadget, MUIA_Selected, FALSE)
  ENDIF
ENDPROC

-> Fills the property gadgets from c (NIL = blank) and enables the ones that
-> make sense for its kind: groups can have a frame, the window no properties
PROC showProps(c: PTR TO component)
  DEF flags, usable, isGroup, w, fx, fy, mn, mx, vl, isSlider, isGauge
  w := 0
  fx := 0
  fy := 0
  mn := 0
  mx := 0
  vl := 0
  usable := FALSE
  isGroup := FALSE
  isSlider := FALSE
  isGauge := FALSE
  flags := 0
  IF c
    flags := c.propFlags
    w := c.weight
    fx := c.fixW
    fy := c.fixH
    mn := c.minV
    mx := c.maxV
    vl := c.value
    IF c.kind <> CK_WINDOW THEN usable := TRUE
    IF isContainer(c.kind) AND (c.kind <> CK_WINDOW) THEN isGroup := TRUE
    IF c.kind = CK_SLIDER THEN isSlider := TRUE
    IF c.kind = CK_GAUGE THEN isGauge := TRUE
  ENDIF

  showNumber(strWeight, flags, PF_WEIGHT, w)
  showNumber(strFixW, flags, PF_FIXW, fx)
  showNumber(strFixH, flags, PF_FIXH, fy)
  showNumber(strMin, flags, PF_MIN, mn)
  showNumber(strMax, flags, PF_MAX, mx)
  showNumber(strValue, flags, PF_VALUE, vl)
  IF (c <> NIL) AND (flags AND PF_HINT)
    set(strHint, MUIA_String_Contents, c.hint)
  ELSE
    set(strHint, MUIA_String_Contents, '')
  ENDIF
  showFlag(chkDisabled, flags, PF_DISABLED)
  showFlag(chkFrame, flags, PF_FRAME)

  setEnabled(strWeight, usable)
  setEnabled(strFixW, usable)
  setEnabled(strFixH, usable)
  setEnabled(strHint, usable)
  setEnabled(chkDisabled, usable)
  setEnabled(chkFrame, isGroup)
  -> a gauge has no minimum; sliders and gauges both have a maximum and a value
  setEnabled(strMin, isSlider)
  setEnabled(strMax, isSlider OR isGauge)
  setEnabled(strValue, isSlider OR isGauge)
ENDPROC

PROC setEnabled(gadget, enabled)
  IF enabled
    set(gadget, MUIA_Disabled, FALSE)
  ELSE
    set(gadget, MUIA_Disabled, MUI_TRUE)
  ENDIF
ENDPROC

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

-> Reads one number gadget: returns its flag bit (0 = blank) and the value;
-> bad input gives -1 as the value.
PROC readNumber(gadget, bit)
  DEF p, v
  get(gadget, MUIA_String_Contents, {p})
  IF StrLen(p) = 0 THEN RETURN 0, 0, TRUE
  IF isNumber(p) = FALSE THEN RETURN 0, 0, FALSE
  v := Val(p)
ENDPROC bit, v, TRUE

-> Applies the property gadgets to the selected component
PROC commitProps()
  DEF c: PTR TO component, nf, nw, nfx, nfy, nmn, nmx, nvl
  DEF p, sel, bit, v, ok, h: PTR TO CHAR, i
  c := selected
  IF c = NIL THEN RETURN
  IF c.kind = CK_WINDOW THEN RETURN

  nf := 0

  bit, v, ok := readNumber(strWeight, PF_WEIGHT)
  IF ok = FALSE
    status('Weight must be a whole number')
    showProps(c)
    RETURN
  ENDIF
  nf := nf OR bit
  nw := v
  bit, v, ok := readNumber(strFixW, PF_FIXW)
  IF ok = FALSE
    status('Fixed width must be a whole number')
    showProps(c)
    RETURN
  ENDIF
  nf := nf OR bit
  nfx := v
  bit, v, ok := readNumber(strFixH, PF_FIXH)
  IF ok = FALSE
    status('Fixed height must be a whole number')
    showProps(c)
    RETURN
  ENDIF
  nf := nf OR bit
  nfy := v
  bit, v, ok := readNumber(strMin, PF_MIN)
  IF ok = FALSE
    status('Minimum must be a whole number')
    showProps(c)
    RETURN
  ENDIF
  nf := nf OR bit
  nmn := v
  bit, v, ok := readNumber(strMax, PF_MAX)
  IF ok = FALSE
    status('Maximum must be a whole number')
    showProps(c)
    RETURN
  ENDIF
  nf := nf OR bit
  nmx := v
  bit, v, ok := readNumber(strValue, PF_VALUE)
  IF ok = FALSE
    status('Value must be a whole number')
    showProps(c)
    RETURN
  ENDIF
  nf := nf OR bit
  nvl := v

  get(chkDisabled, MUIA_Selected, {sel})
  IF sel THEN nf := nf OR PF_DISABLED
  IF isContainer(c.kind)
    get(chkFrame, MUIA_Selected, {sel})
    IF sel THEN nf := nf OR PF_FRAME
  ENDIF

  get(strHint, MUIA_String_Contents, {p})
  h := copyStr(p)
  -> a double quote would end the quoted hint in the .mform file
  FOR i := 0 TO StrLen(h) - 1
    IF h[i] = 34 THEN h[i] := 39
  ENDFOR
  IF StrLen(h) > 0 THEN nf := nf OR PF_HINT

  IF nf = c.propFlags
    IF (nw = c.weight) AND (nfx = c.fixW) AND (nfy = c.fixH)
      IF (nmn = c.minV) AND (nmx = c.maxV) AND (nvl = c.value)
        IF (nf AND PF_HINT) = 0 THEN RETURN
        IF StrLen(h) = StrLen(c.hint)
          IF StrCmp(h, c.hint, ALL) THEN RETURN
        ENDIF
      ENDIF
    ENDIF
  ENDIF

  c.propFlags := nf
  c.weight := nw
  c.fixW := nfx
  c.fixH := nfy
  c.minV := nmn
  c.maxV := nmx
  c.value := nvl
  c.hint := h
  markDirty()
  status('Properties updated')
ENDPROC

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

PROC nameTaken(c: PTR TO component, name, except: PTR TO component)
  DEF ch: PTR TO component
  IF c <> except
    IF StrLen(c.name) = StrLen(name)
      IF StrCmp(c.name, name, ALL) THEN RETURN TRUE
    ENDIF
  ENDIF
  ch := c.firstChild
  WHILE ch
    IF nameTaken(ch, name, except) THEN RETURN TRUE
    ch := ch.next
  ENDWHILE
ENDPROC FALSE

-> Applies the Name gadget to the selected component (on Enter, when the
-> selection changes, and before Save/Preview).
PROC commitName()
  DEF c: PTR TO component, p, label

  c := selected
  IF c = NIL THEN RETURN
  get(strName, MUIA_String_Contents, {p})
  IF StrLen(p) = StrLen(c.name)
    IF StrCmp(p, c.name, ALL) THEN RETURN
  ENDIF

  IF validIdent(p) = FALSE
    status('Name: letters, digits and _ only')
    set(strName, MUIA_String_Contents, c.name)
    RETURN
  ENDIF
  -> E treats capitalised identifiers as constants
  IF (c.kind <> CK_WINDOW) AND ((p[0] < "a") OR (p[0] > "z"))
    status('Name must start with a lowercase letter')
    set(strName, MUIA_String_Contents, c.name)
    RETURN
  ENDIF
  IF nameTaken(form, p, c)
    status('That name is already used')
    set(strName, MUIA_String_Contents, c.name)
    RETURN
  ENDIF

  c.name := copyStr(p)
  label := makeLabel(c)
  doMethodA(tree, [MUIM_Listtree_Rename, selectedNode, label, 0])
  markDirty()
  status('Renamed')
ENDPROC

-> Called on every change of the Title gadget
PROC onTitle()
  DEF c: PTR TO component, p
  c := selected
  IF c = NIL THEN RETURN
  get(strTitle, MUIA_String_Contents, {p})
  IF StrLen(p) = StrLen(titleOf(c))
    IF StrCmp(p, titleOf(c), ALL) THEN RETURN
  ENDIF
  c.title := copyStr(p)
  markDirty()
  status('Title updated')
ENDPROC

PROC handlerOf(c: PTR TO component)
  IF c.handler THEN RETURN c.handler
ENDPROC ''

-> Applies the Handler gadget to the selected component. An empty handler
-> means "no handler"; otherwise it must be a valid procedure name.
PROC commitHandler()
  DEF c: PTR TO component, p

  c := selected
  IF c = NIL THEN RETURN
  IF eventName(c.kind) = NIL THEN RETURN
  get(strHandler, MUIA_String_Contents, {p})

  IF StrLen(p) = 0
    IF c.handler
      status('Handler cleared')
      markDirty()
    ENDIF
    c.handler := NIL
    RETURN
  ENDIF
  IF StrLen(p) = StrLen(handlerOf(c))
    IF StrCmp(p, handlerOf(c), ALL) THEN RETURN
  ENDIF

  IF validIdent(p) = FALSE
    status('Handler: letters, digits and _ only')
    set(strHandler, MUIA_String_Contents, handlerOf(c))
    RETURN
  ENDIF
  -> procedures, like variables, must not start with a capital in E
  IF (p[0] < "a") OR (p[0] > "z")
    status('Handler must start with a lowercase letter')
    set(strHandler, MUIA_String_Contents, handlerOf(c))
    RETURN
  ENDIF

  c.handler := copyStr(p)
  markDirty()
  status('Handler set (Generate adds the stub)')
ENDPROC

-> Fills the Handler gadget with <component><Click|Enter|Change>
PROC onDefaultHandler()
  DEF c: PTR TO component, h
  c := selected
  IF c = NIL THEN RETURN
  IF eventName(c.kind) = NIL THEN RETURN
  h := String(StrLen(c.name) + 12)
  StringF(h, '\s\s', c.name, eventSuffix(c.kind))
  set(strHandler, MUIA_String_Contents, h)
  commitHandler()
ENDPROC

-> Applies every half-edited gadget to the selected component
PROC commitEdits()
  commitName()
  commitHandler()
  commitProps()
ENDPROC

/*** actions ***/

PROC doSave()
  DEF fh
  commitEdits()
  saveCode()
  fh := Open(filename, MODE_NEWFILE)
  IF fh = NIL
    status('Could not write the file')
    RETURN
  ENDIF
  writeForm(fh, form, 0)
  Close(fh)
  dirty := FALSE
  updateTitle()
  status('Saved')
ENDPROC

-> The generated unit goes next to the .mform file, named after the window
PROC outputPath()
  DEF p, n, s
  p := PathPart(filename)
  n := p - filename
  -> PathPart() points at the final '/', which belongs to the directory part
  IF filename[n] = "/" THEN n++
  s := String(n + StrLen(form.name) + 8)
  IF n > 0 THEN StrCopy(s, filename, n)
  StrAdd(s, form.name, ALL)
  StrAdd(s, '.e', ALL)
ENDPROC s

/*** code editor ***/

-> Loads the generated file into the editor (or clears it if there is none)
PROC loadCode()
  DEF path, buf, len
  path := outputPath()
  buf, len := readAll(path)
  IF buf = NIL
    set(editor, MUIA_TextEditor_Contents, '')
    set(txtCodePath, MUIA_Text_Contents, 'No code file yet: click Generate')
  ELSE
    set(editor, MUIA_TextEditor_Contents, buf)
    -> path is not freed: the text gadget may keep the pointer
    set(txtCodePath, MUIA_Text_Contents, path)
  ENDIF
  set(editor, MUIA_TextEditor_HasChanged, FALSE)
ENDPROC

-> Writes the editor's text back to the file if it was changed
PROC saveCode()
  DEF changed, text, fh, path
  get(editor, MUIA_TextEditor_HasChanged, {changed})
  IF changed = FALSE THEN RETURN
  path := outputPath()
  -> with no file there is nothing the editor could belong to
  IF canOpen(path) = FALSE THEN RETURN
  text := doMethodA(editor, [MUIM_TextEditor_ExportText])
  IF text = NIL THEN RETURN
  fh := Open(path, MODE_NEWFILE)
  IF fh
    Write(fh, text, StrLen(text))
    Close(fh)
    set(editor, MUIA_TextEditor_HasChanged, FALSE)
  ELSE
    status('Could not write the code file')
  ENDIF
  FreeVec(text)
ENDPROC

-> Saves the editor, regenerates the marked region (adding handler stubs)
-> and reloads the editor. Returns a GEN_ code.
PROC regenerate()
  DEF path, res
  commitEdits()
  saveCode()
  path := outputPath()
  res := generateFile(path, form)
  IF res = GEN_WRITEFAIL
    status('Could not write the generated file')
  ELSEIF res = GEN_NOMARKERS
    status('That file has no DELPHE BEGIN/END markers: move it aside first')
  ELSE
    loadCode()
  ENDIF
ENDPROC res

PROC doGenerate()
  IF regenerate() = GEN_OK THEN status('Generated: see the Code page')
ENDPROC

-> Shows the Code page with the cursor on the given component's handler
PROC gotoHandler(c: PTR TO component)
  DEF buf, len, sig, p, line, i
  buf, len := readAll(outputPath())
  IF buf = NIL THEN RETURN
  sig := String(StrLen(c.handler) + StrLen(form.name) + 16)
  StrCopy(sig, 'PROC ', ALL)
  StrAdd(sig, c.handler, ALL)
  StrAdd(sig, '() OF t', ALL)
  StrAdd(sig, form.name, ALL)
  p := InStr(buf, sig)
  IF p = -1 THEN RETURN
  line := 0
  FOR i := 0 TO p - 1
    IF buf[i] = 10 THEN line++
  ENDFOR
  set(pages, MUIA_Group_ActivePage, 1)
  set(win, MUIA_Window_ActiveObject, editor)
  set(editor, MUIA_TextEditor_CursorY, line + 1)
ENDPROC

/*** files ***/

-> The window title shows the file and a * while there are unsaved changes.
-> Two buffers alternate so the title pointer changes every time.
PROC updateTitle()
  DEF buf
  IF titleFlip
    buf := titleBuf1
    titleFlip := FALSE
  ELSE
    buf := titleBuf2
    titleFlip := TRUE
  ENDIF
  StrCopy(buf, 'DelphE Designer - ', ALL)
  StrAdd(buf, FilePart(filename), ALL)
  IF dirty THEN StrAdd(buf, ' *', ALL)
  set(win, MUIA_Window_Title, buf)
ENDPROC

PROC markDirty()
  IF dirty = FALSE
    dirty := TRUE
    updateTitle()
  ENDIF
ENDPROC

-> TRUE if it is fine to throw the current form away: nothing unsaved, or the
-> user chose to save or discard. Cancel (or a failed save) returns FALSE.
PROC confirmDiscard()
  DEF r
  IF dirty = FALSE THEN RETURN TRUE
  r := EasyRequestArgs(NIL, [20, 0, 'DelphE Designer',
         'The form has unsaved changes.', 'Save|Discard|Cancel'], NIL, NIL)
  IF r = 1
    doSave()
    RETURN dirty = FALSE
  ENDIF
  IF r = 2 THEN RETURN TRUE
ENDPROC FALSE

-> Loads a form file into the designer
PROC openForm(path)
  DEF nf: PTR TO component
  nf := readForm(path)
  IF nf = NIL
    status('Could not read that form (details on the console)')
    RETURN
  ENDIF
  saveCode()
  closePreview()
  form := nf
  filename := path
  dirty := FALSE
  rebuildTree(form)
  loadCode()
  updateTitle()
  status('Form opened')
ENDPROC

PROC doOpen()
  DEF path
  IF confirmDiscard() = FALSE THEN RETURN
  path := askFile('Open a form', FALSE, outputDir(), '')
  IF path = NIL THEN RETURN
  openForm(path)
ENDPROC

-> Asks before replacing an existing file: TRUE to go ahead
PROC okToOverwrite(path)
  DEF r
  IF canOpen(path) = FALSE THEN RETURN TRUE
  r := EasyRequestArgs(NIL, [20, 0, 'DelphE Designer',
         'That file already exists.', 'Overwrite|Cancel'], NIL, NIL)
ENDPROC r = 1

PROC doNew()
  DEF path, w: PTR TO component, root: PTR TO component, fh
  IF confirmDiscard() = FALSE THEN RETURN
  path := askFile('Create a new form', TRUE, outputDir(), '')
  IF path = NIL THEN RETURN
  IF okToOverwrite(path) = FALSE THEN RETURN

  w := newComponent(CK_WINDOW, nameFromPath(path), 'New Form')
  root := newComponent(CK_VGROUP, 'root', NIL)
  w.addChild(root)
  root.addChild(newComponent(CK_TEXT, 'lblHello', 'Hello'))

  fh := Open(path, MODE_NEWFILE)
  IF fh = NIL
    status('Could not create the file')
    RETURN
  ENDIF
  writeForm(fh, w, 0)
  Close(fh)
  openForm(path)
ENDPROC

PROC doSaveAs()
  DEF path
  commitEdits()
  path := askFile('Save the form as', TRUE, outputDir(), FilePart(filename))
  IF path = NIL THEN RETURN
  IF okToOverwrite(path) = FALSE THEN RETURN
  saveCode()
  filename := path
  doSave()
  -> the generated file is named after the form's path: show what belongs here
  loadCode()
  updateTitle()
ENDPROC

/*** compile and run ***/

-> The directory part of the generated file's path ('' = current directory)
PROC outputDir()
  DEF p, n, s
  p := PathPart(filename)
  n := p - filename
  IF filename[n] = "/" THEN n++
  s := String(n + 2)
  IF n > 0 THEN StrCopy(s, filename, n)
ENDPROC s

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

-> Compiles the generated file with ec. On errors, shows the output and puts
-> the cursor on the offending line. Returns TRUE if it compiled.
PROC compileCode()
  DEF dir, lock, old, cmd, buf, len, clean, ok, p, line, msg

  commitEdits()
  saveCode()
  IF canOpen(outputPath()) = FALSE
    status('Nothing to compile yet: click Generate first')
    RETURN FALSE
  ENDIF

  status('Compiling...')
  dir := outputDir()
  lock, old := enterDir(dir)
  cmd := String(StrLen(form.name) + 64)
  StrCopy(cmd, 'ec ', ALL)
  StrAdd(cmd, form.name, ALL)
  StrAdd(cmd, ' IGNORECACHE > T:delphe-compile-out', ALL)
  Execute(cmd, 0, 0)
  leaveDir(lock, old)

  buf, len := readAll('T:delphe-compile-out')
  IF buf = NIL
    status('Could not run ec (is it in your path?)')
    RETURN FALSE
  ENDIF
  clean := cleanOutput(buf, len)
  set(logEditor, MUIA_TextEditor_Contents, clean)

  ok := (InStr(clean, 'ERROR:') = -1) AND (InStr(clean, 'no errors') <> -1)
  IF ok
    status('Compiled with no errors')
    RETURN TRUE
  ENDIF

  p := InStr(clean, 'LINE ')
  IF p <> -1
    line := Val(clean + p + 5)
    set(pages, MUIA_Group_ActivePage, 1)
    set(win, MUIA_Window_ActiveObject, editor)
    set(editor, MUIA_TextEditor_CursorY, line - 1)
    msg := String(40)
    StringF(msg, 'Compile error at line \d', line)
    status(msg)
  ELSE
    status('Compile failed: see the output below the editor')
  ENDIF
ENDPROC FALSE

PROC runCode()
  DEF dir, lock, old, cmd
  IF compileCode() = FALSE THEN RETURN
  dir := outputDir()
  lock, old := enterDir(dir)
  cmd := String(StrLen(form.name) + 32)
  StrCopy(cmd, 'run >NIL: <NIL: ', ALL)
  StrAdd(cmd, form.name, ALL)
  Execute(cmd, 0, 0)
  leaveDir(lock, old)
  status('Started')
ENDPROC

PROC doEditHandler()
  DEF c: PTR TO component
  commitEdits()
  c := selected
  IF c = NIL THEN RETURN
  IF c.handler = NIL
    status('Set a handler name first (type one, or click New)')
    RETURN
  ENDIF
  IF regenerate() = GEN_OK THEN gotoHandler(c)
ENDPROC

PROC closePreview()
  IF previewWin
    set(previewWin, MUIA_Window_Open, FALSE)
    doMethodA(app, [OM_REMMEMBER, previewWin])
    Mui_DisposeObject(previewWin)
    previewWin := NIL
  ENDIF
ENDPROC

PROC doPreview()
  DEF w
  commitEdits()
  closePreview()
  w := buildWindow(form)
  IF w = NIL
    status('Could not build the preview (is the form empty?)')
    RETURN
  ENDIF
  doMethodA(w, [MUIM_Notify, MUIA_Window_CloseRequest, MUI_TRUE,
    w, 3, MUIM_Set, MUIA_Window_Open, FALSE])
  doMethodA(app, [OM_ADDMEMBER, w])
  set(w, MUIA_Window_Open, MUI_TRUE)
  previewWin := w
  status('Preview opened')
ENDPROC

/*** editing the tree ***/

-> Rebuilds the tree view from the model and selects 'reselect'
PROC rebuildTree(reselect: PTR TO component)
  -> the old nodes are about to disappear
  selected := NIL
  selectedNode := NIL
  set(tree, MUIA_Listtree_Quiet, MUI_TRUE)
  doMethodA(tree, [MUIM_Listtree_Remove, MUIV_Listtree_Remove_ListNode_Root,
                   MUIV_Listtree_Remove_TreeNode_All, 0])
  addTree(form, MUIV_Listtree_Insert_ListNode_Root)
  loadCode()
  updateTitle()
  set(tree, MUIA_Listtree_Quiet, FALSE)
  IF reselect THEN set(tree, MUIA_Listtree_Active, reselect.uiNode)
ENDPROC

PROC uniqueName(prefix)
  DEF n, s
  s := String(StrLen(prefix) + 12)
  n := 1
  REPEAT
    StringF(s, '\s\d', prefix, n)
    n++
  UNTIL nameTaken(form, s, NIL) = FALSE
ENDPROC s

PROC doAdd()
  DEF idx, kind, target: PTR TO component, c: PTR TO component

  commitEdits()
  get(cycKind, MUIA_Cycle_Active, {idx})
  kind := idx + 1          -> the cycle lists VGroup..Check, which follow CK_WINDOW

  target := selected
  IF target = NIL THEN target := form
  IF isContainer(target.kind) = FALSE THEN target := target.parent

  IF target.kind = CK_WINDOW
    IF target.firstChild
      status('The window already has a root group: select a group first')
      RETURN
    ENDIF
    IF isContainer(kind) = FALSE
      status('The window needs a group at the top')
      RETURN
    ENDIF
  ENDIF

  c := newComponent(kind,
         uniqueName(ListItem(['vgrp', 'hgrp', 'btn', 'lbl', 'edt', 'chk',
                              'cyc', 'rad', 'sld', 'gau', 'lst'], idx)),
         ListItem([NIL, NIL, 'Button', 'Label', '', '',
                   'One|Two|Three', 'One|Two|Three', '', '', 'One|Two|Three'], idx))
  target.addChild(c)
  rebuildTree(c)
  markDirty()
  status('Added')
ENDPROC

PROC doDelete()
  DEF c: PTR TO component, p: PTR TO component
  commitEdits()
  c := selected
  IF c = NIL THEN RETURN
  IF c.kind = CK_WINDOW
    status('The window cannot be deleted')
    RETURN
  ENDIF
  p := c.parent
  p.removeChild(c)
  rebuildTree(p)
  markDirty()
  status('Deleted')
ENDPROC

PROC doMove(delta)
  DEF c: PTR TO component, p: PTR TO component, i, j
  commitEdits()
  c := selected
  IF c = NIL THEN RETURN
  p := c.parent
  IF p = NIL THEN RETURN
  i := p.indexOf(c)
  j := i + delta
  IF (j < 0) OR (j >= p.childCount()) THEN RETURN
  p.removeChild(c)
  p.insertAt(c, j)
  rebuildTree(c)
  markDirty()
ENDPROC

/*** main ***/

PROC main() HANDLE
  DEF sigs = 0, id, running

  app := NIL
  previewWin := NIL
  dirty := FALSE
  titleFlip := FALSE
  numBuf := String(16)
  titleBuf1 := String(400)
  titleBuf2 := String(400)

  filename := cleanArg()
  IF StrLen(filename) = 0 THEN filename := defaultFormPath()

  form := readForm(filename)
  IF form = NIL THEN Raise('Could not read the form')

  IF (muimasterbase := OpenLibrary(MUIMASTER_NAME, MUIMASTER_VMIN)) = NIL THEN
    Raise('Failed to open muimaster.library')

  -> No construct/destruct hooks: the string hook would copy our component
  -> pointer as if it were a string. The component is stored as-is in tn_User.
  kindNames := ['VGroup', 'HGroup', 'Button', 'Text', 'String', 'Check',
                'Cycle', 'Radio', 'Slider', 'Gauge', 'List', NIL]

  tree := ListtreeObject,
    InputListFrame,
  End

  pageTitles := ['Form', 'Code', NIL]

  slider := ScrollbarObject,
    MUIA_Group_Horiz, FALSE,
  End
  editor := TextEditorObject,
    MUIA_TextEditor_ExportHook, MUIV_TextEditor_ExportHook_Plain,
    MUIA_TextEditor_Slider, slider,
  End
  IF editor
    set(editor, MUIA_TextEditor_FixedFont, MUI_TRUE)
  ELSE
    Raise('Could not create the editor (is TextEditor.mcc installed?)')
  ENDIF

  logSlider := ScrollbarObject,
    MUIA_Group_Horiz, FALSE,
  End
  logEditor := TextEditorObject,
    MUIA_TextEditor_ExportHook, MUIV_TextEditor_ExportHook_Plain,
    MUIA_TextEditor_Slider, logSlider,
    MUIA_TextEditor_ReadOnly, MUI_TRUE,
  End
  IF logEditor = NIL THEN Raise('Could not create the output pane')
  set(logEditor, MUIA_TextEditor_FixedFont, MUI_TRUE)

  menu := MenustripObject,
    MUIA_Family_Child, MenuObjectT('Project'),
      MUIA_Family_Child, miNew := MenuitemObject,
        MUIA_Menuitem_Title, 'New...', MUIA_Menuitem_Shortcut, 'N', End,
      MUIA_Family_Child, miOpen := MenuitemObject,
        MUIA_Menuitem_Title, 'Open...', MUIA_Menuitem_Shortcut, 'O', End,
      MUIA_Family_Child, miSave := MenuitemObject,
        MUIA_Menuitem_Title, 'Save', MUIA_Menuitem_Shortcut, 'S', End,
      MUIA_Family_Child, miSaveAs := MenuitemObject,
        MUIA_Menuitem_Title, 'Save As...', MUIA_Menuitem_Shortcut, 'A', End,
      MUIA_Family_Child, MenuitemObject,
        MUIA_Menuitem_Title, NM_BARLABEL, End,
      MUIA_Family_Child, miQuit := MenuitemObject,
        MUIA_Menuitem_Title, 'Quit', MUIA_Menuitem_Shortcut, 'Q', End,
    End,
    MUIA_Family_Child, MenuObjectT('Build'),
      MUIA_Family_Child, miPreview := MenuitemObject,
        MUIA_Menuitem_Title, 'Preview form', MUIA_Menuitem_Shortcut, 'P', End,
      MUIA_Family_Child, MenuitemObject,
        MUIA_Menuitem_Title, NM_BARLABEL, End,
      MUIA_Family_Child, miGenerate := MenuitemObject,
        MUIA_Menuitem_Title, 'Generate code', MUIA_Menuitem_Shortcut, 'G', End,
      MUIA_Family_Child, miCompile := MenuitemObject,
        MUIA_Menuitem_Title, 'Compile', MUIA_Menuitem_Shortcut, 'C', End,
      MUIA_Family_Child, miRun := MenuitemObject,
        MUIA_Menuitem_Title, 'Run', MUIA_Menuitem_Shortcut, 'R', End,
    End,
  End
  IF menu = NIL THEN Raise('Failed to create the menus')

  win := WindowObject,
    MUIA_Window_Title, 'DelphE Designer',
    MUIA_Window_ID, "DSGN",
    MUIA_Window_Menustrip, menu,
    WindowContents, VGroup,
      Child, pages := RegisterGroup(pageTitles),
        MUIA_Register_Frame, MUI_TRUE,
      Child, VGroup,
      Child, HGroup,
        Child, cycKind := Cycle(kindNames),
        Child, btnAdd := SimpleButton('Add'),
        Child, btnDelete := SimpleButton('Delete'),
        Child, btnUp := SimpleButton('Move Up'),
        Child, btnDown := SimpleButton('Move Down'),
      End,
      Child, HGroup,
        Child, ListviewObject,
          MUIA_Weight, 40,
          MUIA_Listview_List, tree,
        End,
        Child, VGroup,
          MUIA_Weight, 60,
          GroupFrameT('Properties'),
          Child, ColGroup(2),
            Child, Label2('Kind:'),
            Child, txtKind := TextObject, TextFrame, MUIA_Text_Contents, '', End,
            Child, Label2('Name:'),
            Child, strName := StringObject, StringFrame, MUIA_String_Contents, '', End,
            Child, Label2('Title/items:'),
            Child, strTitle := StringObject, StringFrame, MUIA_String_Contents, '', End,
            -> acts as a label: right-aligned, and no weight so it can't claim the width
            -> that belongs to the gadget column
            Child, txtEvent := TextObject,
              MUIA_Text_PreParse, '\er',
              MUIA_Text_Contents, '',
              MUIA_FixWidthTxt, '(no events) ',
              MUIA_Weight, 0,
            End,
            Child, HGroup,
              Child, strHandler := StringObject, StringFrame, MUIA_String_Contents, '', End,
              Child, btnDefHandler := SimpleButton('New'),
              Child, btnEditHandler := SimpleButton('Edit'),
            End,
            Child, Label2('Weight:'),
            Child, strWeight := StringObject, StringFrame, MUIA_String_Contents, '', End,
            Child, Label2('Fixed width:'),
            Child, strFixW := StringObject, StringFrame, MUIA_String_Contents, '', End,
            Child, Label2('Fixed height:'),
            Child, strFixH := StringObject, StringFrame, MUIA_String_Contents, '', End,
            Child, Label2('Minimum:'),
            Child, strMin := StringObject, StringFrame, MUIA_String_Contents, '', End,
            Child, Label2('Maximum:'),
            Child, strMax := StringObject, StringFrame, MUIA_String_Contents, '', End,
            Child, Label2('Value:'),
            Child, strValue := StringObject, StringFrame, MUIA_String_Contents, '', End,
            Child, Label2('Hint:'),
            Child, strHint := StringObject, StringFrame, MUIA_String_Contents, '', End,
            Child, Label2('Disabled:'),
            Child, chkDisabled := CheckMark(FALSE),
            Child, Label2('Frame:'),
            Child, chkFrame := CheckMark(FALSE),
          End,
          Child, VSpace(0),
        End,
      End,
      End,
      Child, VGroup,
        Child, HGroup,
          Child, txtCodePath := TextObject, TextFrame, MUIA_Text_Contents, '', End,
          Child, btnSaveCode := SimpleButton('Save Code'),
          Child, btnReloadCode := SimpleButton('Reload'),
          Child, btnCompile := SimpleButton('Compile'),
          Child, btnRun := SimpleButton('Run'),
        End,
        Child, HGroup,
          MUIA_Weight, 80,
          MUIA_Group_Spacing, 0,
          Child, editor,
          Child, slider,
        End,
        Child, HGroup,
          MUIA_Weight, 20,
          MUIA_Group_Spacing, 0,
          Child, logEditor,
          Child, logSlider,
        End,
      End,
      End,
      Child, txtStatus := TextObject, TextFrame, MUIA_Text_Contents, 'Ready', End,
    End,
  End

  IF win = NIL THEN Raise('Failed to create the window')

  app := ApplicationObject,
    MUIA_Application_Title      , 'DelphE Designer',
    MUIA_Application_Version    , '$VER: Designer 0.1 (23.10.26)',
    MUIA_Application_Description, 'DelphE form designer',
    MUIA_Application_Base       , 'DELPHEDESIGNER',
    SubWindow, win,
  End

  IF app = NIL THEN Raise('Failed to create Application.')

  doMethodA(win, [MUIM_Notify, MUIA_Window_CloseRequest, MUI_TRUE,
    app, 2, MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])
  doMethodA(tree, [MUIM_Notify, MUIA_Listtree_Active, MUIV_EveryTime,
    app, 2, MUIM_Application_ReturnID, ID_SELECT])
  doMethodA(strName, [MUIM_Notify, MUIA_String_Acknowledge, MUIV_EveryTime,
    app, 2, MUIM_Application_ReturnID, ID_NAME])
  doMethodA(strTitle, [MUIM_Notify, MUIA_String_Contents, MUIV_EveryTime,
    app, 2, MUIM_Application_ReturnID, ID_TITLE])
  doMethodA(strHandler, [MUIM_Notify, MUIA_String_Acknowledge, MUIV_EveryTime,
    app, 2, MUIM_Application_ReturnID, ID_HANDLER])
  doMethodA(btnDefHandler, [MUIM_Notify, MUIA_Pressed, FALSE,
    app, 2, MUIM_Application_ReturnID, ID_DEFHANDLER])
  doMethodA(strWeight, [MUIM_Notify, MUIA_String_Acknowledge, MUIV_EveryTime,
    app, 2, MUIM_Application_ReturnID, ID_PROPS])
  doMethodA(strFixW, [MUIM_Notify, MUIA_String_Acknowledge, MUIV_EveryTime,
    app, 2, MUIM_Application_ReturnID, ID_PROPS])
  doMethodA(strFixH, [MUIM_Notify, MUIA_String_Acknowledge, MUIV_EveryTime,
    app, 2, MUIM_Application_ReturnID, ID_PROPS])
  doMethodA(strMin, [MUIM_Notify, MUIA_String_Acknowledge, MUIV_EveryTime,
    app, 2, MUIM_Application_ReturnID, ID_PROPS])
  doMethodA(strMax, [MUIM_Notify, MUIA_String_Acknowledge, MUIV_EveryTime,
    app, 2, MUIM_Application_ReturnID, ID_PROPS])
  doMethodA(strValue, [MUIM_Notify, MUIA_String_Acknowledge, MUIV_EveryTime,
    app, 2, MUIM_Application_ReturnID, ID_PROPS])
  doMethodA(strHint, [MUIM_Notify, MUIA_String_Acknowledge, MUIV_EveryTime,
    app, 2, MUIM_Application_ReturnID, ID_PROPS])
  doMethodA(chkDisabled, [MUIM_Notify, MUIA_Selected, MUIV_EveryTime,
    app, 2, MUIM_Application_ReturnID, ID_PROPS])
  doMethodA(chkFrame, [MUIM_Notify, MUIA_Selected, MUIV_EveryTime,
    app, 2, MUIM_Application_ReturnID, ID_PROPS])
  doMethodA(btnEditHandler, [MUIM_Notify, MUIA_Pressed, FALSE,
    app, 2, MUIM_Application_ReturnID, ID_EDITHANDLER])
  doMethodA(btnSaveCode, [MUIM_Notify, MUIA_Pressed, FALSE,
    app, 2, MUIM_Application_ReturnID, ID_SAVECODE])
  doMethodA(btnReloadCode, [MUIM_Notify, MUIA_Pressed, FALSE,
    app, 2, MUIM_Application_ReturnID, ID_RELOADCODE])
  hookMenu(miNew, ID_NEW)
  hookMenu(miOpen, ID_OPEN)
  hookMenu(miSave, ID_SAVE)
  hookMenu(miSaveAs, ID_SAVEAS)
  hookMenu(miQuit, MUIV_Application_ReturnID_Quit)
  hookMenu(miPreview, ID_PREVIEW)
  hookMenu(miGenerate, ID_GENERATE)
  hookMenu(miCompile, ID_COMPILE)
  hookMenu(miRun, ID_RUN)
  doMethodA(btnCompile, [MUIM_Notify, MUIA_Pressed, FALSE,
    app, 2, MUIM_Application_ReturnID, ID_COMPILE])
  doMethodA(btnRun, [MUIM_Notify, MUIA_Pressed, FALSE,
    app, 2, MUIM_Application_ReturnID, ID_RUN])
  doMethodA(btnAdd, [MUIM_Notify, MUIA_Pressed, FALSE,
    app, 2, MUIM_Application_ReturnID, ID_ADD])
  doMethodA(btnDelete, [MUIM_Notify, MUIA_Pressed, FALSE,
    app, 2, MUIM_Application_ReturnID, ID_DELETE])
  doMethodA(btnUp, [MUIM_Notify, MUIA_Pressed, FALSE,
    app, 2, MUIM_Application_ReturnID, ID_UP])
  doMethodA(btnDown, [MUIM_Notify, MUIA_Pressed, FALSE,
    app, 2, MUIM_Application_ReturnID, ID_DOWN])

  addTree(form, MUIV_Listtree_Insert_ListNode_Root)

  set(win, MUIA_Window_Open, MUI_TRUE)

  running := TRUE
  WHILE running
    id := doMethodA(app, [MUIM_Application_NewInput, {sigs}])
    SELECT id
      CASE MUIV_Application_ReturnID_Quit
        IF confirmDiscard() THEN running := FALSE
      CASE ID_SELECT
        onSelect()
      CASE ID_NAME
        commitEdits()
      CASE ID_TITLE
        onTitle()
      CASE ID_HANDLER
        commitHandler()
      CASE ID_DEFHANDLER
        onDefaultHandler()
      CASE ID_PROPS
        commitProps()
      CASE ID_EDITHANDLER
        doEditHandler()
      CASE ID_SAVECODE
        saveCode()
        status('Code saved')
      CASE ID_RELOADCODE
        loadCode()
        status('Code reloaded from disk')
      CASE ID_NEW
        doNew()
      CASE ID_OPEN
        doOpen()
      CASE ID_SAVEAS
        doSaveAs()
      CASE ID_COMPILE
        compileCode()
      CASE ID_RUN
        runCode()
      CASE ID_SAVE
        doSave()
      CASE ID_PREVIEW
        doPreview()
      CASE ID_GENERATE
        doGenerate()
      CASE ID_ADD
        doAdd()
      CASE ID_DELETE
        doDelete()
      CASE ID_UP
        doMove(-1)
      CASE ID_DOWN
        doMove(1)
    ENDSELECT
    IF running AND sigs THEN sigs := Wait(sigs)
  ENDWHILE

  saveCode()
  set(win, MUIA_Window_Open, FALSE)

EXCEPT DO
  IF app THEN Mui_DisposeObject(app)
  IF muimasterbase THEN CloseLibrary(muimasterbase)
  IF exception THEN WriteF('\s\n', exception)
ENDPROC
