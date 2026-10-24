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

MODULE 'libraries/gadtools', 'intuition/classes', 'mui/muicustomclass', 'dos/dos', 'exec/memory', 'muimaster', 'libraries/mui', 'utility/tagitem',
       'amigalib/boopsi', 'intuition/classusr',
       '*/FormModel', '*/MForm', '*/Builder', '*/Generator', '*/Util', '*/Project',
       '*/mcc/listtree_mcc', '*/mcc/texteditor_mcc', '*/mcc/toolbar_mcc'

ENUM ID_SELECT = 1, ID_NAME, ID_TITLE, ID_SAVE, ID_PREVIEW,
     ID_DELETE, ID_UP, ID_DOWN, ID_GENERATE,
     ID_HANDLER, ID_DEFHANDLER, ID_EDITHANDLER, ID_SAVECODE, ID_RELOADCODE, ID_COMPILE, ID_RUN, ID_NEW, ID_OPEN, ID_SAVEAS, ID_PROPS,
     ID_SHOWFORM, ID_SHOWINSP, ID_SHOWCODE, ID_TITLEDONE, ID_UNDO, ID_REDO, ID_TREEDROP,
     ID_NEWPROJ, ID_OPENPROJ, ID_FORMSEL, ID_REMOVEFORM, ID_MAKEMAIN, ID_SIZE, ID_ENTRIES, ID_ENTRIESOK

-> palette buttons send ID_PALETTE + the index of their component kind
CONST ID_PALETTE = 100

CONST UNDOMAX = 40, MENUITEMS = 21

DEF mItems[100]: ARRAY OF LONG

-> the project: several forms in one program (projectPath is NIL for a single form)
DEF projectPath, projectName, projCount, projCur, cycForms, cycHolder,
    projPaths[16]: ARRAY OF LONG, projForms[16]: ARRAY OF LONG,
    candPaths[16]: ARRAY OF LONG, candForms[16]: ARRAY OF LONG, candCount, candName

DEF treeMcc: PTR TO mui_customclass

-> undo and redo: copies of the whole form, newest last, with the position of the
-> selected component so it can be selected again
DEF undoTrees[40]: ARRAY OF LONG, undoSel[40]: ARRAY OF LONG,
    redoTrees[40]: ARRAY OF LONG, redoSel[40]: ARRAY OF LONG,
    undoTop, redoTop, lastTitleEdited: PTR TO component

DEF inspPanel, inspBalance, inspShown, pages, pageTitles, cycFont, winEntries, entriesEditor, entriesSlider, btnEntries, btnEntriesOk, btnEntriesCancel,
    liveHolder, livePlaceholder, previewArea, previewHost, sldW, sldH, liveObj, liveStale, actionsBar, paletteBar, paletteBar2,
    inspPages, inspTitles, actionsDef, paletteDef, paletteDef2,
    app, win, tree, strName, strTitle, txtKind, txtStatus,
    previewWin,
    txtEvent, strHandler, btnDefHandler, btnEditHandler,
    editor, slider, txtCodePath, btnSaveCode, btnReloadCode,
    logEditor, logSlider, btnCompile, btnRun,
    strWeight, strFixW, strFixH, strMin, strMax, strValue, strHint, chkDisabled, chkFrame, numBuf,
    dirty, titleBuf1, titleBuf2, titleFlip,
    btnDelete, btnUp, btnDown,
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
  -> label is deliberately not freed: the tree may keep the pointer (freeing it
  -> is suspected of corrupting strings that reuse the memory)
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
  DEF flags, usable, isGroup, w, fx, fy, mn, mx, vl, isSlider, isGauge, isItems, fi
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
  isItems := FALSE
  fi := 0
  flags := 0
  IF c
    flags := c.propFlags
    w := c.weight
    fx := c.fixW
    fy := c.fixH
    mn := c.minV
    mx := c.maxV
    vl := c.value
    IF flags AND PF_FONT THEN fi := c.fontIdx
    IF c.kind <> CK_WINDOW THEN usable := TRUE
    IF isContainer(c.kind) AND (c.kind <> CK_WINDOW) THEN isGroup := TRUE
    IF c.kind = CK_SLIDER THEN isSlider := TRUE
    IF c.kind = CK_GAUGE THEN isGauge := TRUE
    IF (c.kind = CK_CYCLE) OR (c.kind = CK_RADIO) OR (c.kind = CK_LIST) OR (c.kind = CK_PAGES) THEN isItems := TRUE
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
  set(cycFont, MUIA_Cycle_Active, fi)

  setEnabled(strWeight, usable)
  setEnabled(strFixW, usable)
  setEnabled(strFixH, usable)
  setEnabled(strHint, usable)
  setEnabled(chkDisabled, usable)
  setEnabled(cycFont, usable)
  setEnabled(chkFrame, isGroup)
  -> a gauge has no minimum; sliders and gauges both have a maximum and a value
  setEnabled(strMin, isSlider)
  setEnabled(strMax, isSlider OR isGauge)
  setEnabled(strValue, isSlider OR isGauge)
  setEnabled(btnEntries, isItems)
ENDPROC

PROC setEnabled(gadget, enabled)
  IF enabled
    set(gadget, MUIA_Disabled, FALSE)
  ELSE
    set(gadget, MUIA_Disabled, MUI_TRUE)
  ENDIF
ENDPROC

-> Reads one number gadget: returns its flag bit (0 = blank) and the value;
-> bad input gives -1 as the value.
PROC readNumber(gadget, bit)
  DEF p, v
  get(gadget, MUIA_String_Contents, {p})
  IF StrLen(p) = 0 THEN RETURN 0, 0, TRUE
  IF isNumber(p) = FALSE THEN RETURN 0, 0, FALSE
  v := Val(p)
ENDPROC bit, v, TRUE

-> readNumber() for commitProps: on bad input it says so, shows the component's
-> properties again and returns ok = FALSE
PROC readNumberOrComplain(gadget, bit, what, c: PTR TO component)
  DEF b, v, ok, msg
  b, v, ok := readNumber(gadget, bit)
  IF ok = FALSE
    msg := String(StrLen(what) + 32)
    StrCopy(msg, what, ALL)
    StrAdd(msg, ' must be a whole number', ALL)
    status(msg)
    showProps(c)
  ENDIF
ENDPROC b, v, ok

-> Applies the property gadgets to the selected component
PROC commitProps()
  DEF c: PTR TO component, nf, nw, nfx, nfy, nmn, nmx, nvl
  DEF p, sel, bit, v, ok, h: PTR TO CHAR, i, fnt
  c := selected
  IF c = NIL THEN RETURN
  IF c.kind = CK_WINDOW THEN RETURN

  nf := 0

  bit, v, ok := readNumberOrComplain(strWeight, PF_WEIGHT, 'Weight', c)
  IF ok = FALSE THEN RETURN
  nf := nf OR bit
  nw := v
  bit, v, ok := readNumberOrComplain(strFixW, PF_FIXW, 'Fixed width', c)
  IF ok = FALSE THEN RETURN
  nf := nf OR bit
  nfx := v
  bit, v, ok := readNumberOrComplain(strFixH, PF_FIXH, 'Fixed height', c)
  IF ok = FALSE THEN RETURN
  nf := nf OR bit
  nfy := v
  bit, v, ok := readNumberOrComplain(strMin, PF_MIN, 'Minimum', c)
  IF ok = FALSE THEN RETURN
  nf := nf OR bit
  nmn := v
  bit, v, ok := readNumberOrComplain(strMax, PF_MAX, 'Maximum', c)
  IF ok = FALSE THEN RETURN
  nf := nf OR bit
  nmx := v
  bit, v, ok := readNumberOrComplain(strValue, PF_VALUE, 'Value', c)
  IF ok = FALSE THEN RETURN
  nf := nf OR bit
  nvl := v

  get(chkDisabled, MUIA_Selected, {sel})
  IF sel THEN nf := nf OR PF_DISABLED
  IF isContainer(c.kind)
    get(chkFrame, MUIA_Selected, {sel})
    IF sel THEN nf := nf OR PF_FRAME
  ENDIF

  get(cycFont, MUIA_Cycle_Active, {fnt})
  IF fnt > 0 THEN nf := nf OR PF_FONT

  get(strHint, MUIA_String_Contents, {p})
  h := copyStr(p)
  -> a double quote would end the quoted hint in the .mform file
  FOR i := 0 TO StrLen(h) - 1
    IF h[i] = 34 THEN h[i] := 39
  ENDFOR
  IF StrLen(h) > 0 THEN nf := nf OR PF_HINT

  IF nf = c.propFlags
    IF (nw = c.weight) AND (nfx = c.fixW) AND (nfy = c.fixH)
      IF (nmn = c.minV) AND (nmx = c.maxV) AND (nvl = c.value) AND (fnt = c.fontIdx)
        IF (nf AND PF_HINT) = 0 THEN RETURN
        IF StrLen(h) = StrLen(c.hint)
          IF StrCmp(h, c.hint, ALL) THEN RETURN
        ENDIF
      ENDIF
    ENDIF
  ENDIF

  pushUndo()
  c.propFlags := nf
  c.weight := nw
  c.fixW := nfx
  c.fixH := nfy
  c.minV := nmn
  c.maxV := nmx
  c.value := nvl
  c.fontIdx := fnt
  c.hint := h
  markDirty()
  status('Properties updated')
ENDPROC

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

  pushUndo()
  c.name := copyStr(p)
  label := makeLabel(c)
  doMethodA(tree, [MUIM_Listtree_Rename, selectedNode, label, 0])
  markDirty()
  IF c.kind = CK_WINDOW THEN refreshProjectList()
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
  -> one snapshot for a run of edits to the same title, not one per key
  IF c <> lastTitleEdited
    pushUndo()
    lastTitleEdited := c
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
      pushUndo()
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

  pushUndo()
  c.handler := copyStr(p)
  markDirty()
  status('Handler set (the stub is added when you compile)')
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
  DEF fh, i, p
  commitEdits()
  saveCode()
  IF projectPath
    -> a project saves every form and the project file
    syncCurrent()
    FOR i := 0 TO projCount - 1
      p := joinPath(dirPart(projectPath), projPaths[i])
      fh := Open(p, MODE_NEWFILE)
      IF fh = NIL
        status('Could not write a form file')
        RETURN
      ENDIF
      writeForm(fh, projForms[i], 0)
      Close(fh)
    ENDFOR
    IF writeProjectFile(projectPath, projectName, projPaths, projCount) = FALSE
      status('Could not write the project file')
      RETURN
    ENDIF
  ELSE
    fh := Open(filename, MODE_NEWFILE)
    IF fh = NIL
      status('Could not write the file')
      RETURN
    ENDIF
    writeForm(fh, form, 0)
    Close(fh)
  ENDIF
  dirty := FALSE
  updateTitle()
  status('Saved')
ENDPROC

-> The generated unit goes next to the .mform file, named after the window
PROC programName()
  IF projectPath THEN RETURN projectName
ENDPROC form.name

-> The generated program goes next to the form (or the project file), named
-> after the window (or the project)
PROC outputPath()
  DEF dir, s
  dir := outputDir()
  s := String(StrLen(dir) + StrLen(programName()) + 8)
  StrCopy(s, dir, ALL)
  StrAdd(s, programName(), ALL)
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
    set(txtCodePath, MUIA_Text_Contents, 'No code file yet: Compile or Build > Generate code creates it')
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
  IF projectPath
    res := generateProjectNow(path)
  ELSE
    res := generateFile(path, form)
  ENDIF
  IF res = GEN_WRITEFAIL
    status('Could not write the generated file')
  ELSEIF res = GEN_NOMARKERS
    status('That file has no DELPHE GENERATED CODE line: move it aside first')
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
  showCode()
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
  IF projectPath
    StrAdd(buf, projectName, ALL)
    StrAdd(buf, ' (project)', ALL)
  ELSE
    StrAdd(buf, FilePart(filename), ALL)
  ENDIF
  IF dirty THEN StrAdd(buf, ' *', ALL)
  set(win, MUIA_Window_Title, buf)
ENDPROC

PROC markDirty()
  liveStale := TRUE
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
  projectPath := NIL
  projCount := 0
  form := nf
  filename := path
  dirty := FALSE
  clearUndo()
  rebuildTree(form)
  refreshLive()
  refreshProjectList()
  loadCode()
  updateTitle()
  status('Form opened')
ENDPROC

PROC doOpen()
  DEF path
  IF projectPath
    addExistingForm()
    RETURN
  ENDIF
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
  IF projectPath
    addNewForm()
    RETURN
  ENDIF
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
  IF projectPath
    status('In a project, Save writes every form; Save As is for single forms')
    RETURN
  ENDIF
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

/*** projects ***/

-> The forms are edited one at a time; projForms keeps all of them. Undo and
-> redo can swap the current tree, so it is copied back before it is used.
PROC syncCurrent()
  IF projectPath THEN projForms[projCur] := form
ENDPROC

PROC projectDir() IS dirPart(projectPath)

-> The program is made of every form of the project, the main form first
PROC generateProjectNow(path)
  DEF forms, i
  syncCurrent()
  forms := List(projCount)
  FOR i := 0 TO projCount - 1 DO ListAdd(forms, [projForms[i]], 1)
ENDPROC generateProject(path, projectName, forms, projCount)

-> The Project window's list: the forms by window name, the main form first
PROC refreshProjectList()
  DEF names, i, n, label, active, w: PTR TO component, fresh
  n := 1
  IF projectPath THEN n := projCount
  names := List(n + 1)
  FOR i := 0 TO n - 1
    w := form
    IF projectPath THEN w := projForms[i]
    label := String(StrLen(w.name) + 12)
    StrCopy(label, w.name, ALL)
    IF i = 0 THEN StrAdd(label, ' (main)', ALL)
    ListAdd(names, [label], 1)
  ENDFOR
  ListAdd(names, [NIL], 1)
  active := 0
  IF projectPath THEN active := projCur

  -> a Cycle's entries are fixed when it is made, so a new one replaces the old
  fresh := CycleObject,
    MUIA_Font, MUIV_Font_Button,
    MUIA_Cycle_Entries, names,
    MUIA_Cycle_Active, active,
  End
  IF fresh = NIL THEN RETURN
  doMethodA(cycHolder, [MUIM_Group_InitChange])
  IF cycForms
    doMethodA(cycHolder, [OM_REMMEMBER, cycForms])
    Mui_DisposeObject(cycForms)
  ENDIF
  doMethodA(cycHolder, [OM_ADDMEMBER, fresh])
  doMethodA(cycHolder, [MUIM_Group_ExitChange])
  cycForms := fresh
  doMethodA(cycForms, [MUIM_Notify, MUIA_Cycle_Active, MUIV_EveryTime,
    app, 2, MUIM_Application_ReturnID, ID_FORMSEL])
ENDPROC

-> Makes form i of the project the one being edited
PROC loadFormIndex(i)
  closePreview()
  projCur := i
  form := projForms[i]
  filename := joinPath(projectDir(), projPaths[i])
  selected := NIL
  selectedNode := NIL
  clearUndo()
  rebuildTree(form)
  refreshLive()
  updateTitle()
  IF cycForms THEN set(cycForms, MUIA_Cycle_Active, i)
ENDPROC

PROC switchForm(i)
  commitEdits()
  syncCurrent()
  IF i = projCur THEN RETURN
  loadFormIndex(i)
  status('Form switched (undo history is per form and starts again)')
ENDPROC

PROC onFormSelect()
  DEF i
  IF projectPath = NIL THEN RETURN
  get(cycForms, MUIA_Cycle_Active, {i})
  IF (i >= 0) AND (i < projCount) AND (i <> projCur) THEN switchForm(i)
ENDPROC

-> Is a form with this window name already in the project?
PROC windowNameTaken(name)
  DEF i, w: PTR TO component
  FOR i := 0 TO projCount - 1
    w := projForms[i]
    IF same(w.name, name) THEN RETURN TRUE
  ENDFOR
ENDPROC FALSE

-> name, or name2, name3 ... if that is taken
PROC uniqueFormName(name)
  DEF n, s
  IF windowNameTaken(name) = FALSE THEN RETURN name
  s := String(StrLen(name) + 12)
  n := 2
  REPEAT
    StringF(s, '\s\d', name, n)
    n++
  UNTIL windowNameTaken(s) = FALSE
ENDPROC s

-> A new form: a window with a group and a label
PROC makeStarterForm(name)
  DEF w: PTR TO component, root: PTR TO component
  w := newComponent(CK_WINDOW, name, 'New Form')
  root := newComponent(CK_VGROUP, 'root', NIL)
  w.addChild(root)
  root.addChild(newComponent(CK_TEXT, 'lblHello', 'Hello'))
ENDPROC w

PROC addFormToProject(path, model)
  syncCurrent()
  projPaths[projCount] := relPath(projectDir(), path)
  projForms[projCount] := model
  projCount++
  refreshProjectList()
  commitEdits()
  loadFormIndex(projCount - 1)
  markDirty()
ENDPROC

PROC addNewForm()
  DEF path, w, fh
  IF projCount >= MAXFORMS
    status('A project holds at most 16 forms')
    RETURN
  ENDIF
  path := askFile('Create a new form', TRUE, projectDir(), '')
  IF path = NIL THEN RETURN
  IF okToOverwrite(path) = FALSE THEN RETURN
  w := makeStarterForm(uniqueFormName(nameFromPath(path)))
  fh := Open(path, MODE_NEWFILE)
  IF fh = NIL
    status('Could not create the file')
    RETURN
  ENDIF
  writeForm(fh, w, 0)
  Close(fh)
  addFormToProject(path, w)
  status('Form added to the project')
ENDPROC

PROC addExistingForm()
  DEF path, nf: PTR TO component
  IF projCount >= MAXFORMS
    status('A project holds at most 16 forms')
    RETURN
  ENDIF
  path := askFile('Add a form to the project', FALSE, projectDir(), '')
  IF path = NIL THEN RETURN
  nf := readForm(path)
  IF nf = NIL
    status('Could not read that form (details on the console)')
    RETURN
  ENDIF
  IF windowNameTaken(nf.name)
    status('A form with that window name is already in the project')
    RETURN
  ENDIF
  addFormToProject(path, nf)
  status('Form added to the project')
ENDPROC

PROC doRemoveForm()
  DEF r, i, next
  IF projectPath = NIL
    status('Open or create a project first')
    RETURN
  ENDIF
  IF projCount <= 1
    status('A project needs at least one form')
    RETURN
  ENDIF
  r := EasyRequestArgs(NIL, [20, 0, 'DelphE Designer',
         'Remove this form from the project? Its file is kept.', 'Remove|Cancel'], NIL, NIL)
  IF r <> 1 THEN RETURN
  commitEdits()
  syncCurrent()
  FOR i := projCur TO projCount - 2
    projPaths[i] := projPaths[i + 1]
    projForms[i] := projForms[i + 1]
  ENDFOR
  projCount--
  next := projCur
  IF next >= projCount THEN next := projCount - 1
  refreshProjectList()
  loadFormIndex(next)
  markDirty()
  status('Form removed (generate again; its old code stays in the file)')
ENDPROC

-> The main form is the first one: it opens first and closing it ends the program
PROC doMakeMain()
  DEF p, f
  IF projectPath = NIL
    status('Open or create a project first')
    RETURN
  ENDIF
  commitEdits()
  syncCurrent()
  IF projCur = 0 THEN RETURN
  p := projPaths[0]
  f := projForms[0]
  projPaths[0] := projPaths[projCur]
  projForms[0] := projForms[projCur]
  projPaths[projCur] := p
  projForms[projCur] := f
  projCur := 0
  refreshProjectList()
  markDirty()
  status('Main form changed')
ENDPROC

-> Reads a project file and all its forms into the cand... variables
PROC loadCandidate(path)
  DEF name, count, i, dir, p, nf
  name, count := readProjectFile(path, candPaths, MAXFORMS)
  IF name = NIL THEN RETURN FALSE
  IF count < 1
    WriteF('\s has no forms\n', path)
    RETURN FALSE
  ENDIF
  dir := dirPart(path)
  FOR i := 0 TO count - 1
    p := joinPath(dir, candPaths[i])
    nf := readForm(p)
    IF nf = NIL THEN RETURN FALSE
    candForms[i] := nf
  ENDFOR
  candName := name
  candCount := count
ENDPROC TRUE

PROC adoptCandidate(path)
  DEF i
  projectPath := path
  projectName := candName
  projCount := candCount
  FOR i := 0 TO candCount - 1
    projPaths[i] := candPaths[i]
    projForms[i] := candForms[i]
  ENDFOR
  projCur := 0
ENDPROC

PROC openProject(path)
  IF loadCandidate(path) = FALSE
    status('Could not read that project (details on the console)')
    RETURN
  ENDIF
  saveCode()
  closePreview()
  adoptCandidate(path)
  dirty := FALSE
  refreshProjectList()
  loadFormIndex(0)
  loadCode()
  updateTitle()
  status('Project opened')
ENDPROC

PROC doOpenProject()
  DEF path
  IF confirmDiscard() = FALSE THEN RETURN
  path := askFileEx('Open a project', FALSE, outputDir(), '', '#?.mproj', '.mproj')
  IF path = NIL THEN RETURN
  openProject(path)
ENDPROC

PROC doNewProject()
  DEF path, name, formPath, w, fh, paths[1]: ARRAY OF LONG, n
  IF confirmDiscard() = FALSE THEN RETURN
  path := askFileEx('Create a new project', TRUE, outputDir(), '', '#?.mproj', '.mproj')
  IF path = NIL THEN RETURN
  IF okToOverwrite(path) = FALSE THEN RETURN

  -> the first form lives next to the project file, named after it
  n := StrLen(path)
  formPath := String(n + 8)
  StrCopy(formPath, path, n - 6)
  StrAdd(formPath, '.mform', ALL)
  IF okToOverwrite(formPath) = FALSE THEN RETURN
  w := makeStarterForm('MainForm')
  fh := Open(formPath, MODE_NEWFILE)
  IF fh = NIL
    status('Could not create the first form')
    RETURN
  ENDIF
  writeForm(fh, w, 0)
  Close(fh)

  name := nameFromPath(path)
  paths[0] := FilePart(formPath)
  IF writeProjectFile(path, name, paths, 1) = FALSE
    status('Could not create the project file')
    RETURN
  ENDIF
  openProject(path)
ENDPROC

/*** compile and run ***/

-> The directory part of the generated file's path ('' = current directory)
PROC outputDir()
  IF projectPath THEN RETURN dirPart(projectPath)
ENDPROC dirPart(filename)

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

-> Compiles the generated file with ec. On errors, shows the output and puts
-> the cursor on the offending line. Returns TRUE if it compiled.
PROC compileCode()
  DEF dir, lock, old, cmd, buf, len, clean, ok, p, line, msg, bdir, bfile, first, glines, bl

  -> bring the generated file up to date first (this also saves the editor)
  IF regenerate() <> GEN_OK THEN RETURN FALSE

  status('Compiling...')
  dir := outputDir()

  -> ec gets the user's file with the generated file inserted, in a work drawer
  bdir := 'RAM:delphe-build'
  bl := CreateDir(bdir)
  IF bl THEN UnLock(bl)
  bfile := String(StrLen(bdir) + StrLen(programName()) + 8)
  StrCopy(bfile, bdir, ALL)
  StrAdd(bfile, '/', ALL)
  StrAdd(bfile, programName(), ALL)
  StrAdd(bfile, '.e', ALL)
  first, glines := buildSource(outputPath(), bfile)
  IF first < 0
    status('Could not put the program together: is the DELPHE GENERATED CODE line still there?')
    RETURN FALSE
  ENDIF

  lock, old := enterDir(bdir)
  cmd := String(StrLen(programName()) + 64)
  StrCopy(cmd, 'ec ', ALL)
  StrAdd(cmd, programName(), ALL)
  StrAdd(cmd, ' IGNORECACHE > RAM:delphe-compile-out', ALL)
  Execute(cmd, 0, 0)
  leaveDir(lock, old)

  buf, len := readAll('RAM:delphe-compile-out')
  IF buf = NIL
    status('Could not run ec (is it in your path?)')
    RETURN FALSE
  ENDIF
  clean := cleanOutput(buf, len)
  set(logEditor, MUIA_TextEditor_Contents, clean)

  ok := (InStr(clean, 'ERROR:') = -1) AND (InStr(clean, 'no errors') <> -1)
  IF ok
    -> the program goes next to the source, where Run starts it from
    cmd := String(StrLen(bdir) + StrLen(programName()) + StrLen(dir) + 40)
    StrCopy(cmd, 'copy \q', ALL)
    StrAdd(cmd, bdir, ALL)
    StrAdd(cmd, '/', ALL)
    StrAdd(cmd, programName(), ALL)
    StrAdd(cmd, '\q to \q', ALL)
    StrAdd(cmd, dir, ALL)
    StrAdd(cmd, '\q QUIET', ALL)
    Execute(cmd, 0, 0)
    status('Compiled with no errors')
    RETURN TRUE
  ENDIF

  p := InStr(clean, 'LINE ')
  IF p <> -1
    line := Val(clean + p + 5)
    msg := String(80)
    IF line >= (first + glines)
      -> the compiler saw the inserted generated code: take it out of the count
      line := line - glines
      showCode()
      set(editor, MUIA_TextEditor_CursorY, line - 1)
      StringF(msg, 'Compile error at line \d', line)
    ELSEIF line >= first
      StringF(msg, 'Compile error in the generated code (line \d of the .gen.e file)', line - first + 1)
    ELSE
      showCode()
      set(editor, MUIA_TextEditor_CursorY, line - 1)
      StringF(msg, 'Compile error at line \d', line)
    ENDIF
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
  -> the program's output (WriteF) goes to its own console window, which stays
  -> open after the program ends until it is closed
  cmd := String((StrLen(programName()) * 2) + 80)
  StrCopy(cmd, 'run >CON:20/40/500/200/', ALL)
  StrAdd(cmd, programName(), ALL)
  StrAdd(cmd, '/CLOSE/WAIT <NIL: ', ALL)
  StrAdd(cmd, programName(), ALL)
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

PROC doAdd(idx)
  DEF kind, target: PTR TO component, c: PTR TO component

  commitEdits()
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
                              'cyc', 'rad', 'sld', 'gau', 'lst', 'pgs'], idx)),
         ListItem([NIL, NIL, 'Button', 'Label', '', '',
                   'One|Two|Three', 'One|Two|Three', '', '', 'One|Two|Three',
                   'Page 1|Page 2'], idx))
  pushUndo()
  target.addChild(c)
  -> each child of a Pages component is a page: start with two
  IF kind = CK_PAGES
    c.addChild(newComponent(CK_VGROUP, uniqueName('page'), NIL))
    c.addChild(newComponent(CK_VGROUP, uniqueName('page'), NIL))
  ENDIF
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
  pushUndo()
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
  pushUndo()
  p.removeChild(c)
  p.insertAt(c, j)
  rebuildTree(c)
  markDirty()
ENDPROC

/*** main ***/


/*** drag and drop in the tree ***/

-> A Listtree that tells the main loop when something has been dropped on it.
-> The Listtree does the actual moving; onTreeDrop() then brings the model
-> into line with what the tree now shows.
PROC treeDispatcher(cl: PTR TO iclass, obj, msg: PTR TO msg)
  DEF methodID, r
  methodID := msg.methodid
  IF methodID = MUIM_DragDrop
    r := doSuperMethodA(cl, obj, msg)
    doMethodA(app, [MUIM_Application_ReturnID, ID_TREEDROP])
    RETURN r
  ENDIF
ENDPROC doSuperMethodA(cl, obj, msg)

PROC firstChildNode(node)
ENDPROC doMethodA(tree, [MUIM_Listtree_GetEntry, node, MUIV_Listtree_GetEntry_Position_Head, 0])

PROC nextSiblingNode(node)
ENDPROC doMethodA(tree, [MUIM_Listtree_GetEntry, node, MUIV_Listtree_GetEntry_Position_Next,
                         MUIV_Listtree_GetEntry_Flags_SameLevel])

-> Does the tree below this node list the same components, in the same order,
-> as the model has below c?
PROC treeMatches(node, c: PTR TO component)
  DEF child: PTR TO muis_listtree_treenode, d: PTR TO component, mc: PTR TO component
  IF isContainer(c.kind) = FALSE THEN RETURN TRUE
  child := firstChildNode(node)
  mc := c.firstChild
  WHILE child
    d := child.tn_User
    IF mc = NIL THEN RETURN FALSE
    IF d <> mc THEN RETURN FALSE
    IF treeMatches(child, d) = FALSE THEN RETURN FALSE
    mc := mc.next
    child := nextSiblingNode(child)
  ENDWHILE
  IF mc THEN RETURN FALSE
ENDPROC TRUE

-> Is the arrangement the tree now shows one the model can hold? There must be
-> exactly one top-level entry, the window, and the window may hold only a
-> single group.
PROC validDrop(rootNode: PTR TO muis_listtree_treenode)
  DEF wchild: PTR TO muis_listtree_treenode, d: PTR TO component
  IF rootNode = NIL THEN RETURN FALSE
  IF rootNode.tn_User <> form THEN RETURN FALSE
  IF nextSiblingNode(rootNode) THEN RETURN FALSE
  wchild := firstChildNode(rootNode)
  IF wchild
    IF nextSiblingNode(wchild) THEN RETURN FALSE
    d := wchild.tn_User
    IF isContainer(d.kind) = FALSE THEN RETURN FALSE
  ENDIF
ENDPROC TRUE

-> Rebuilds the model's child links from the tree, below this node
PROC relinkFromTree(node, c: PTR TO component)
  DEF child: PTR TO muis_listtree_treenode, d: PTR TO component
  IF isContainer(c.kind) = FALSE THEN RETURN
  c.firstChild := NIL
  c.lastChild := NIL
  child := firstChildNode(node)
  WHILE child
    d := child.tn_User
    d.next := NIL
    d.parent := NIL
    c.addChild(d)
    relinkFromTree(child, d)
    child := nextSiblingNode(child)
  ENDWHILE
ENDPROC

PROC onTreeDrop()
  DEF rootNode
  rootNode := doMethodA(tree, [MUIM_Listtree_GetEntry, MUIV_Listtree_GetEntry_ListNode_Root,
                               MUIV_Listtree_GetEntry_Position_Head, 0])
  IF rootNode = NIL THEN RETURN
  IF treeMatches(rootNode, form) THEN RETURN

  IF validDrop(rootNode) = FALSE
    -> put the tree back the way the model has it
    status('That move is not allowed here')
    IF selected THEN rebuildTree(selected) ELSE rebuildTree(form)
    RETURN
  ENDIF

  pushUndo()
  relinkFromTree(rootNode, form)
  markDirty()
  status('Moved')
ENDPROC

/*** undo and redo ***/

-> Menu items 9 and 10 of each window's menus are Undo and Redo
PROC updateUndoMenu()
  DEF slot, undoItem, redoItem
  FOR slot := 0 TO 0
    undoItem := mItems[slot * MENUITEMS + 9]
    redoItem := mItems[slot * MENUITEMS + 10]
    IF undoTop > 0
      set(undoItem, MUIA_Menuitem_Enabled, MUI_TRUE)
    ELSE
      set(undoItem, MUIA_Menuitem_Enabled, FALSE)
    ENDIF
    IF redoTop > 0
      set(redoItem, MUIA_Menuitem_Enabled, MUI_TRUE)
    ELSE
      set(redoItem, MUIA_Menuitem_Enabled, FALSE)
    ENDIF
  ENDFOR
ENDPROC

PROC clearRedo()
  DEF i
  FOR i := 0 TO redoTop - 1 DO freeTree(redoTrees[i])
  redoTop := 0
ENDPROC

PROC clearUndo()
  DEF i
  FOR i := 0 TO undoTop - 1 DO freeTree(undoTrees[i])
  undoTop := 0
  clearRedo()
  lastTitleEdited := NIL
  updateUndoMenu()
ENDPROC

-> Call this just before changing the form
PROC pushUndo()
  DEF i
  IF undoTop = UNDOMAX
    -> forget the oldest
    freeTree(undoTrees[0])
    FOR i := 1 TO UNDOMAX - 1
      undoTrees[i - 1] := undoTrees[i]
      undoSel[i - 1] := undoSel[i]
    ENDFOR
    undoTop--
  ENDIF
  undoTrees[undoTop] := cloneTree(form)
  undoSel[undoTop] := indexInTree(form, selected)
  undoTop++
  clearRedo()
  lastTitleEdited := NIL
  updateUndoMenu()
ENDPROC

-> Makes f the current form and selects the component at position selIdx
PROC restoreForm(f: PTR TO component, selIdx)
  DEF target: PTR TO component
  form := f
  syncCurrent()
  selected := NIL
  selectedNode := NIL
  lastTitleEdited := NIL
  target := NIL
  IF selIdx >= 0 THEN target := componentAt(form, selIdx)
  IF target = NIL THEN target := form
  rebuildTree(target)
  markDirty()
  updateUndoMenu()
ENDPROC

PROC doUndo()
  DEF i
  commitEdits()
  IF undoTop = 0
    status('Nothing to undo')
    RETURN
  ENDIF
  IF redoTop = UNDOMAX
    freeTree(redoTrees[0])
    FOR i := 1 TO UNDOMAX - 1
      redoTrees[i - 1] := redoTrees[i]
      redoSel[i - 1] := redoSel[i]
    ENDFOR
    redoTop--
  ENDIF
  redoTrees[redoTop] := form
  redoSel[redoTop] := indexInTree(form, selected)
  redoTop++
  undoTop--
  restoreForm(undoTrees[undoTop], undoSel[undoTop])
  status('Undone')
ENDPROC

PROC doRedo()
  commitEdits()
  IF redoTop = 0
    status('Nothing to redo')
    RETURN
  ENDIF
  undoTrees[undoTop] := form
  undoSel[undoTop] := indexInTree(form, selected)
  undoTop++
  redoTop--
  restoreForm(redoTrees[redoTop], redoSel[redoTop])
  status('Redone')
ENDPROC

PROC showCode()
  set(pages, MUIA_Group_ActivePage, 1)
  set(win, MUIA_Window_ActiveObject, editor)
ENDPROC


-> Hides or shows the Object Inspector, to give the form and code the whole window
PROC toggleInspector()
  IF inspShown
    set(inspPanel, MUIA_ShowMe, FALSE)
    set(inspBalance, MUIA_ShowMe, FALSE)
    inspShown := FALSE
  ELSE
    set(inspPanel, MUIA_ShowMe, MUI_TRUE)
    set(inspBalance, MUIA_ShowMe, MUI_TRUE)
    inspShown := TRUE
  ENDIF
ENDPROC

PROC showFormTab()
  set(pages, MUIA_Group_ActivePage, 0)
ENDPROC


/*** live view ***/

-> Rebuilds the form's real MUI objects inside the Form window
PROC refreshLive()
  DEF obj
  liveStale := FALSE
  doMethodA(liveHolder, [MUIM_Group_InitChange])
  IF liveObj
    doMethodA(liveHolder, [OM_REMMEMBER, liveObj])
    Mui_DisposeObject(liveObj)
    liveObj := NIL
  ENDIF
  IF form.firstChild
    obj := buildObject(form.firstChild)
    IF obj
      -> the placeholder only stops an empty box; beside the form it would take
      -> the spare space and push the form to the bottom
      IF livePlaceholder
        doMethodA(liveHolder, [OM_REMMEMBER, livePlaceholder])
        Mui_DisposeObject(livePlaceholder)
        livePlaceholder := NIL
      ENDIF
      doMethodA(liveHolder, [OM_ADDMEMBER, obj])
      liveObj := obj
    ENDIF
  ENDIF
  IF (liveObj = NIL) AND (livePlaceholder = NIL)
    livePlaceholder := RectangleObject, MUIA_Weight, 1, End
    IF livePlaceholder THEN doMethodA(liveHolder, [OM_ADDMEMBER, livePlaceholder])
  ENDIF
  doMethodA(liveHolder, [MUIM_Group_ExitChange])
ENDPROC

-> The form's framed box inside empty space: p and q are its width and height as a
-> percentage of the area. A weight is fixed when an object is made, so a size
-> change builds a new one (see resizePreview).
PROC makePreviewArea(p, q)
  DEF box, restW, restH
  restW := 100 - p
  restH := 100 - q
  box := VGroup,
    Child, HGroup,
      MUIA_Weight, q,
      Child, liveHolder := VGroup,
        GroupFrame,
        MUIA_Weight, p,
        Child, livePlaceholder := RectangleObject, MUIA_Weight, 1, End,
      End,
      Child, RectangleObject, MUIA_Weight, restW, End,
    End,
    Child, RectangleObject, MUIA_Weight, restH, End,
  End
ENDPROC box

-> Replaces the preview area with one of the size the sliders say, and rebuilds the
-> form in it
PROC resizePreview()
  DEF p, q, fresh, old, oldPlaceholder
  get(sldW, MUIA_Numeric_Value, {p})
  get(sldH, MUIA_Numeric_Value, {q})
  old := liveHolder
  oldPlaceholder := livePlaceholder
  fresh := makePreviewArea(p, q)
  IF fresh = NIL
    liveHolder := old
    livePlaceholder := oldPlaceholder
    RETURN
  ENDIF
  doMethodA(previewHost, [MUIM_Group_InitChange])
  doMethodA(previewHost, [OM_REMMEMBER, previewArea])
  Mui_DisposeObject(previewArea)
  liveObj := NIL
  doMethodA(previewHost, [OM_ADDMEMBER, fresh])
  doMethodA(previewHost, [MUIM_Group_ExitChange])
  previewArea := fresh
  refreshLive()
ENDPROC

/*** menus and toolbars ***/

-> Every window gets its own copy of the menus, because an Amiga menu bar
-> belongs to the active window. The items are remembered in mItems (12 per
-> window) so hookMenus() can connect them once the application exists.
PROC makeMenu(slot)
  DEF strip, m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13, m14, m15, m16, m17, m18, m19, m20, m21, base
  strip := MenustripObject,
    MUIA_Family_Child, MenuObjectT('Project'),
      MUIA_Family_Child, m1 := MenuitemObject,
        MUIA_Menuitem_Title, 'New project...', End,
      MUIA_Family_Child, m2 := MenuitemObject,
        MUIA_Menuitem_Title, 'Open project...', End,
      MUIA_Family_Child, MenuitemObject,
        MUIA_Menuitem_Title, NM_BARLABEL, End,
      MUIA_Family_Child, m3 := MenuitemObject,
        MUIA_Menuitem_Title, 'New form...', MUIA_Menuitem_Shortcut, 'N', End,
      MUIA_Family_Child, m4 := MenuitemObject,
        MUIA_Menuitem_Title, 'Open form...', MUIA_Menuitem_Shortcut, 'O', End,
      MUIA_Family_Child, m5 := MenuitemObject,
        MUIA_Menuitem_Title, 'Remove form from project', End,
      MUIA_Family_Child, m6 := MenuitemObject,
        MUIA_Menuitem_Title, 'Make main form', End,
      MUIA_Family_Child, MenuitemObject,
        MUIA_Menuitem_Title, NM_BARLABEL, End,
      MUIA_Family_Child, m7 := MenuitemObject,
        MUIA_Menuitem_Title, 'Save', MUIA_Menuitem_Shortcut, 'S', End,
      MUIA_Family_Child, m8 := MenuitemObject,
        MUIA_Menuitem_Title, 'Save As...', MUIA_Menuitem_Shortcut, 'A', End,
      MUIA_Family_Child, MenuitemObject,
        MUIA_Menuitem_Title, NM_BARLABEL, End,
      MUIA_Family_Child, m9 := MenuitemObject,
        MUIA_Menuitem_Title, 'Quit', MUIA_Menuitem_Shortcut, 'Q', End,
    End,
    MUIA_Family_Child, MenuObjectT('Edit'),
      MUIA_Family_Child, m10 := MenuitemObject,
        MUIA_Menuitem_Title, 'Undo', MUIA_Menuitem_Shortcut, 'Z', End,
      MUIA_Family_Child, m11 := MenuitemObject,
        MUIA_Menuitem_Title, 'Redo', MUIA_Menuitem_Shortcut, 'Y', End,
      MUIA_Family_Child, MenuitemObject,
        MUIA_Menuitem_Title, NM_BARLABEL, End,
      MUIA_Family_Child, m12 := MenuitemObject,
        MUIA_Menuitem_Title, 'Delete component', MUIA_Menuitem_Shortcut, 'D', End,
      MUIA_Family_Child, m13 := MenuitemObject,
        MUIA_Menuitem_Title, 'Move up', MUIA_Menuitem_Shortcut, 'U', End,
      MUIA_Family_Child, m14 := MenuitemObject,
        MUIA_Menuitem_Title, 'Move down', MUIA_Menuitem_Shortcut, 'J', End,
    End,
    MUIA_Family_Child, MenuObjectT('Build'),
      MUIA_Family_Child, m15 := MenuitemObject,
        MUIA_Menuitem_Title, 'Preview form', MUIA_Menuitem_Shortcut, 'P', End,
      MUIA_Family_Child, MenuitemObject,
        MUIA_Menuitem_Title, NM_BARLABEL, End,
      MUIA_Family_Child, m16 := MenuitemObject,
        MUIA_Menuitem_Title, 'Generate code', MUIA_Menuitem_Shortcut, 'G', End,
      MUIA_Family_Child, m17 := MenuitemObject,
        MUIA_Menuitem_Title, 'Compile', MUIA_Menuitem_Shortcut, 'C', End,
      MUIA_Family_Child, m18 := MenuitemObject,
        MUIA_Menuitem_Title, 'Run', MUIA_Menuitem_Shortcut, 'R', End,
    End,
    MUIA_Family_Child, MenuObjectT('View'),
      MUIA_Family_Child, m19 := MenuitemObject,
        MUIA_Menuitem_Title, 'Form tab', MUIA_Menuitem_Shortcut, '1', End,
      MUIA_Family_Child, m20 := MenuitemObject,
        MUIA_Menuitem_Title, 'Code tab', MUIA_Menuitem_Shortcut, '2', End,
      MUIA_Family_Child, m21 := MenuitemObject,
        MUIA_Menuitem_Title, 'Show/hide object inspector', MUIA_Menuitem_Shortcut, '3', End,
    End,
  End
  IF strip = NIL THEN Raise('Failed to create the menus')
  base := slot * MENUITEMS
  mItems[base] := m1
  mItems[base + 1] := m2
  mItems[base + 2] := m3
  mItems[base + 3] := m4
  mItems[base + 4] := m5
  mItems[base + 5] := m6
  mItems[base + 6] := m7
  mItems[base + 7] := m8
  mItems[base + 8] := m9
  mItems[base + 9] := m10
  mItems[base + 10] := m11
  mItems[base + 11] := m12
  mItems[base + 12] := m13
  mItems[base + 13] := m14
  mItems[base + 14] := m15
  mItems[base + 15] := m16
  mItems[base + 16] := m17
  mItems[base + 17] := m18
  mItems[base + 18] := m19
  mItems[base + 19] := m20
  mItems[base + 20] := m21
ENDPROC strip


PROC hookMenus(windows)
  DEF ids, slot, k
  ids := [ID_NEWPROJ, ID_OPENPROJ, ID_NEW, ID_OPEN, ID_REMOVEFORM, ID_MAKEMAIN,
          ID_SAVE, ID_SAVEAS, MUIV_Application_ReturnID_Quit,
          ID_UNDO, ID_REDO, ID_DELETE, ID_UP, ID_DOWN,
          ID_PREVIEW, ID_GENERATE, ID_COMPILE, ID_RUN,
          ID_SHOWFORM, ID_SHOWCODE, ID_SHOWINSP]
  FOR slot := 0 TO windows - 1
    FOR k := 0 TO MENUITEMS - 1
      hookMenu(mItems[slot * MENUITEMS + k], ListItem(ids, k))
    ENDFOR
  ENDFOR
ENDPROC

-> A toolbar button sends the given return ID to the main loop when pressed
PROC hookButton(bar, idx, id)
  doMethodA(bar, [MUIM_Toolbar_Notify, idx, MUIV_Toolbar_Notify_Pressed, FALSE,
    app, 2, MUIM_Application_ReturnID, id])
ENDPROC

/*** main ***/

/*** building the program ***/

PROC makeTree()
  -> No construct/destruct hooks: the string hook would copy our component
  -> pointer as if it were a string. The component is stored as-is in tn_User.
  treeMcc := eMui_CreateCustomClass(NIL, MUIC_Listtree, NIL, 4, {treeDispatcher})
  IF treeMcc = NIL THEN Raise('Could not create the tree class (is Listtree.mcc installed?)')
  -> new entries go to the end of a group; empty groups can still take drops
  tree := NewObjectA(treeMcc.mcc_class, NIL,
    [MUIA_Frame, MUIV_Frame_InputList,
     MUIA_Listtree_EmptyNodes, MUI_TRUE,
     MUIA_Listtree_DuplicateNodeName, MUI_TRUE,
     MUIA_Listtree_SortHook, MUIV_Listtree_SortHook_Tail,
     TAG_DONE, 0])
  IF tree = NIL THEN Raise('Could not create the tree')
ENDPROC

PROC makeEditors()
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
ENDPROC

-> The two toolbars: actions, and the component palette
PROC makeToolbars()
  -> toolbar: the buttons are numbered in order, spaces included
  actionsDef := buildBank([
    Toolbar_HintButton(0, 'New project', NIL),
    Toolbar_HintButton(0, 'Open project', NIL),
    Toolbar_Space,
    Toolbar_HintButton(0, 'New form (added to the project if there is one)', NIL),
    Toolbar_HintButton(0, 'Open form (added to the project if there is one)', NIL),
    Toolbar_HintButton(0, 'Save (every form of a project)', NIL),
    Toolbar_Space,
    Toolbar_HintButton(0, 'Remove this form from the project', NIL),
    Toolbar_Space,
    Toolbar_HintButton(0, 'Preview the form in its own window', NIL),
    Toolbar_Space,
    Toolbar_HintButton(0, 'Compile', NIL),
    Toolbar_HintButton(0, 'Compile and run', NIL),
    Toolbar_End])
  actionsBar := ToolbarObject,
    MUIA_Toolbar_ImageType, MUIV_Toolbar_ImageType_File,
    MUIA_Toolbar_ImageNormal, imagePath('actions.iff'),
    MUIA_Toolbar_Description, actionsDef,
    MUIA_ShortHelp, TRUE,
  End
  IF actionsBar = NIL THEN Raise('Could not create the toolbar (is Toolbar.mcc installed?)')

  -> the palette is two short rows rather than one long one: a Toolbar never
  -> wraps, so a single row would fix the inspector's width
  paletteDef := buildBank([
    Toolbar_HintButton(0, 'Add a vertical group', NIL),
    Toolbar_HintButton(0, 'Add a horizontal group', NIL),
    Toolbar_HintButton(0, 'Add a button', NIL),
    Toolbar_HintButton(0, 'Add a text label', NIL),
    Toolbar_HintButton(0, 'Add a string gadget', NIL),
    Toolbar_HintButton(0, 'Add a checkmark', NIL),
    Toolbar_End])
  paletteBar := ToolbarObject,
    MUIA_Toolbar_ImageType, MUIV_Toolbar_ImageType_File,
    MUIA_Toolbar_ImageNormal, imagePath('palette1.iff'),
    MUIA_Toolbar_Description, paletteDef,
    MUIA_ShortHelp, TRUE,
  End
  IF paletteBar = NIL THEN Raise('Could not create the component palette')

  paletteDef2 := buildBank([
    Toolbar_HintButton(0, 'Add a cycle gadget', NIL),
    Toolbar_HintButton(0, 'Add radio buttons', NIL),
    Toolbar_HintButton(0, 'Add a slider', NIL),
    Toolbar_HintButton(0, 'Add a gauge', NIL),
    Toolbar_HintButton(0, 'Add a list', NIL),
    Toolbar_HintButton(0, 'Add pages (tabs)', NIL),
    Toolbar_End])
  paletteBar2 := ToolbarObject,
    MUIA_Toolbar_ImageType, MUIV_Toolbar_ImageType_File,
    MUIA_Toolbar_ImageNormal, imagePath('palette2.iff'),
    MUIA_Toolbar_Description, paletteDef2,
    MUIA_ShortHelp, TRUE,
  End
  IF paletteBar2 = NIL THEN Raise('Could not create the component palette')
ENDPROC

PROC makeMainWindow()
  inspShown := TRUE

  -> the whole program in one window: toolbars on top, the inspector docked at
  -> the left, the form and code tabs filling the rest, the status line below
  win := WindowObject,
    MUIA_Window_Title, 'DelphE Designer',
    MUIA_Window_ID, "DSGN",
    MUIA_Window_Menustrip, makeMenu(0),
    MUIA_Window_LeftEdge, 0,
    MUIA_Window_TopEdge, MUIV_Window_TopEdge_Delta(0),
    MUIA_Window_Width, MUIV_Window_Width_Screen(100),
    MUIA_Window_Height, MUIV_Window_Height_Screen(95),
    WindowContents, VGroup,
      Child, HGroup,
        Child, actionsBar,
        Child, HSpace(0),
      End,
      Child, HGroup,
        Child, inspPanel,
        Child, inspBalance := BalanceObject, End,
        Child, pages,
      End,
      Child, txtStatus := TextObject, TextFrame, MUIA_Text_Contents, 'Ready', End,
    End,
  End
ENDPROC

PROC makeInspectorPanel()
  inspTitles := ['Properties', 'Events', NIL]

  -> the Object Inspector, docked at the left: form drop-down, component tree and
  -> properties
  inspPanel := VGroup,
    MUIA_Weight, 30,
      -> the form being edited: pick another form of the project here
      Child, cycHolder := VGroup,
        Child, cycForms := CycleObject,
          MUIA_Font, MUIV_Font_Button,
          MUIA_Cycle_Entries, ['(form)', NIL],
        End,
      End,
      Child, txtKind := TextObject, TextFrame, MUIA_Text_Contents, '', End,
      -> the component palette: it adds to the selection in the tree just below
      -> a stretchy space on each side keeps it centred and lets the inspector
      -> be resized without the palette's width getting in the way
      Child, HGroup,
        Child, HSpace(0),
        Child, VGroup, GroupFrameT('Add component'),
          Child, paletteBar,
          Child, paletteBar2,
        End,
        Child, HSpace(0),
      End,
      -> the component tree, with what acts on the selected component
      Child, VGroup,
        MUIA_Weight, 40,
        Child, ListviewObject,
          MUIA_Listview_DragType, MUIV_Listview_DragType_Immediate,
          MUIA_Listview_List, tree,
        End,
        Child, HGroup,
          Child, btnDelete := SimpleButton('Delete'),
          Child, btnUp := SimpleButton('Up'),
          Child, btnDown := SimpleButton('Down'),
        End,
      End,
      Child, BalanceObject, End,
      Child, inspPages := RegisterGroup(inspTitles),
        MUIA_Weight, 60,
        MUIA_Register_Frame, MUI_TRUE,
        Child, VGroup,
          Child, ColGroup(2),
            Child, Label2('Name:'),
            Child, strName := StringObject, StringFrame, MUIA_String_Contents, '', End,
            Child, Label2('Title/items:'),
            Child, HGroup,
              Child, strTitle := StringObject, StringFrame, MUIA_String_Contents, '', End,
              -> for a Cycle, Radio or List: edit the entries one per line
              Child, btnEntries := SimpleButton('...'),
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
            Child, Label2('Font:'),
            -> MUI's standard fonts; they follow the user's MUI preferences
            Child, cycFont := CycleObject,
              MUIA_Font, MUIV_Font_Button,
              MUIA_Cycle_Entries, ['Default', 'Normal', 'Tiny', 'Big', 'Title', 'Fixed', 'List', 'Button', NIL],
            End,
            Child, Label2('Disabled:'),
            -> a fixed-size gadget would stop its whole column stretching, so each
            -> checkmark gets a stretchy neighbour
            Child, HGroup,
              Child, chkDisabled := CheckMark(FALSE),
              Child, HSpace(0),
            End,
            Child, Label2('Frame:'),
            Child, HGroup,
              Child, chkFrame := CheckMark(FALSE),
              Child, HSpace(0),
            End,
          End,
          Child, VSpace(0),
        End,
        Child, VGroup,
          Child, ColGroup(2),
            -> acts as a label: right-aligned, and no weight so it can't claim the
            -> width that belongs to the gadget column
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
          End,
          Child, VSpace(0),
        End,
      End,
  End
ENDPROC

PROC makeEditorPanel()
  pageTitles := ['Form', 'Code', NIL]

  -> the live form and the generated code, as two tabs filling the rest of the window
  pages := RegisterGroup(pageTitles),
    MUIA_Weight, 70,
    MUIA_Register_Frame, MUI_TRUE,
    -> The form's size is set with two sliders, as a share of the area (0% is the
    -> smallest the form can be, 100% fills the area): width along the top, height
    -> docked at the left. A two-column grid keeps the width slider starting where
    -> the height slider ends; the empty top-left cell is just a gap. The form sits
    -> in a framed box of that size.
    Child, ColGroup(2),
      Child, RectangleObject, MUIA_Weight, 0, End,
      Child, sldW := SliderObject,
        MUIA_Numeric_Min, 0,
        MUIA_Numeric_Max, 100,
        MUIA_Numeric_Value, 70,
        MUIA_Numeric_Format, '',
        MUIA_ShortHelp, 'Width of the form, as a share of the area',
      End,
      Child, sldH := SliderObject,
        MUIA_Slider_Horiz, FALSE,
        MUIA_Numeric_Min, 0,
        MUIA_Numeric_Max, 100,
        MUIA_Numeric_Value, 70,
        MUIA_Numeric_Format, '',
        MUIA_ShortHelp, 'Height of the form, as a share of the area',
      End,
      Child, previewHost := VGroup,
        Child, previewArea := makePreviewArea(70, 70),
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
  End
ENDPROC

-> All the windows go into one application
-> The entries dialog: a small window with a text editor, one entry per line, that
-> edits a Cycle, Radio or List's entries without typing | by hand
PROC makeEntriesWindow()
  entriesSlider := ScrollbarObject,
    MUIA_Group_Horiz, FALSE,
  End
  entriesEditor := TextEditorObject,
    MUIA_TextEditor_ExportHook, MUIV_TextEditor_ExportHook_Plain,
    MUIA_TextEditor_Slider, entriesSlider,
  End
  IF entriesEditor = NIL THEN Raise('Could not create the entries editor')
  set(entriesEditor, MUIA_TextEditor_FixedFont, MUI_TRUE)

  winEntries := WindowObject,
    MUIA_Window_Title, 'Entries',
    MUIA_Window_ID, "DENT",
    MUIA_Window_LeftEdge, MUIV_Window_LeftEdge_Centered,
    MUIA_Window_TopEdge, MUIV_Window_TopEdge_Centered,
    MUIA_Window_Width, 260,
    MUIA_Window_Height, 220,
    WindowContents, VGroup,
      Child, TextObject, MUIA_Text_Contents, 'One entry per line:', End,
      Child, HGroup,
        MUIA_Group_Spacing, 0,
        Child, entriesEditor,
        Child, entriesSlider,
      End,
      Child, HGroup,
        Child, btnEntriesOk := SimpleButton('OK'),
        Child, btnEntriesCancel := SimpleButton('Cancel'),
      End,
    End,
  End
ENDPROC

-> "One|Two" -> "One" and "Two" on separate lines
PROC itemsToLines(s)
  DEF out: PTR TO CHAR, i, len
  len := StrLen(s)
  out := NewM(len + 2, MEMF_PUBLIC)
  FOR i := 0 TO len - 1
    IF s[i] = "|" THEN out[i] := 10 ELSE out[i] := s[i]
  ENDFOR
  out[len] := 0
ENDPROC out

-> The editor's lines as "One|Two": blank lines and surrounding spaces are dropped,
-> and a | inside an entry becomes a /
PROC linesToItems(text)
  DEF out: PTR TO CHAR, i, len, ch, lineStart, s, e, k, o, c, trimming
  len := StrLen(text)
  out := NewM(len + 2, MEMF_PUBLIC)
  o := 0
  lineStart := 0
  FOR i := 0 TO len
    ch := 10
    IF i < len THEN ch := text[i]
    IF ch = 10
      e := i
      trimming := TRUE
      WHILE trimming AND (e > lineStart)
        IF text[e - 1] <= " " THEN e-- ELSE trimming := FALSE
      ENDWHILE
      s := lineStart
      trimming := TRUE
      WHILE trimming AND (s < e)
        IF text[s] <= " " THEN s++ ELSE trimming := FALSE
      ENDWHILE
      IF e > s
        IF o > 0
          out[o] := "|"
          o++
        ENDIF
        FOR k := s TO e - 1
          c := text[k]
          IF c = "|" THEN c := "/"
          out[o] := c
          o++
        ENDFOR
      ENDIF
      lineStart := i + 1
    ENDIF
  ENDFOR
  out[o] := 0
ENDPROC copyStr(out)

PROC openEntries()
  DEF c: PTR TO component
  c := selected
  IF c = NIL THEN RETURN
  IF (c.kind <> CK_CYCLE) AND (c.kind <> CK_RADIO) AND (c.kind <> CK_LIST) AND (c.kind <> CK_PAGES) THEN RETURN
  set(entriesEditor, MUIA_TextEditor_Contents, itemsToLines(titleOf(c)))
  set(winEntries, MUIA_Window_Open, MUI_TRUE)
  set(winEntries, MUIA_Window_Activate, MUI_TRUE)
  set(winEntries, MUIA_Window_ActiveObject, entriesEditor)
ENDPROC

-> OK in the entries dialog: the lines become the component's title (its entries)
PROC applyEntries()
  DEF text, items
  text := doMethodA(entriesEditor, [MUIM_TextEditor_ExportText])
  IF text = NIL THEN RETURN
  items := linesToItems(text)
  FreeVec(text)
  set(winEntries, MUIA_Window_Open, FALSE)
  set(strTitle, MUIA_String_Contents, items)
  onTitle()
ENDPROC

PROC makeApplication()
  IF (win = NIL) OR (winEntries = NIL) THEN Raise('Failed to create the window')

  app := ApplicationObject,
    MUIA_Application_Title      , 'DelphE Designer',
    MUIA_Application_Version    , '$VER: Designer 0.2 (23.10.26)',
    MUIA_Application_Description, 'DelphE form designer',
    MUIA_Application_Base       , 'DELPHEDESIGNER',
    SubWindow, win,
    SubWindow, winEntries,
  End

  IF app = NIL THEN Raise('Failed to create Application.')
ENDPROC

-> Connects gadgets, menus and toolbar buttons to the main loop
PROC connectEvents()
  DEF i, ids

  -> closing the window quits
  doMethodA(win, [MUIM_Notify, MUIA_Window_CloseRequest, MUI_TRUE,
    app, 2, MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])
  doMethodA(sldW, [MUIM_Notify, MUIA_Numeric_Value, MUIV_EveryTime,
    app, 2, MUIM_Application_ReturnID, ID_SIZE])
  doMethodA(sldH, [MUIM_Notify, MUIA_Numeric_Value, MUIV_EveryTime,
    app, 2, MUIM_Application_ReturnID, ID_SIZE])
  doMethodA(btnEntries, [MUIM_Notify, MUIA_Pressed, FALSE,
    app, 2, MUIM_Application_ReturnID, ID_ENTRIES])
  doMethodA(btnEntriesOk, [MUIM_Notify, MUIA_Pressed, FALSE,
    app, 2, MUIM_Application_ReturnID, ID_ENTRIESOK])
  doMethodA(btnEntriesCancel, [MUIM_Notify, MUIA_Pressed, FALSE,
    winEntries, 3, MUIM_Set, MUIA_Window_Open, FALSE])
  doMethodA(winEntries, [MUIM_Notify, MUIA_Window_CloseRequest, MUI_TRUE,
    winEntries, 3, MUIM_Set, MUIA_Window_Open, FALSE])
  doMethodA(tree, [MUIM_Notify, MUIA_Listtree_Active, MUIV_EveryTime,
    app, 2, MUIM_Application_ReturnID, ID_SELECT])
  doMethodA(strName, [MUIM_Notify, MUIA_String_Acknowledge, MUIV_EveryTime,
    app, 2, MUIM_Application_ReturnID, ID_NAME])
  doMethodA(strTitle, [MUIM_Notify, MUIA_String_Contents, MUIV_EveryTime,
    app, 2, MUIM_Application_ReturnID, ID_TITLE])
  doMethodA(strTitle, [MUIM_Notify, MUIA_String_Acknowledge, MUIV_EveryTime,
    app, 2, MUIM_Application_ReturnID, ID_TITLEDONE])
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
  doMethodA(cycFont, [MUIM_Notify, MUIA_Cycle_Active, MUIV_EveryTime,
    app, 2, MUIM_Application_ReturnID, ID_PROPS])
  doMethodA(btnEditHandler, [MUIM_Notify, MUIA_Pressed, FALSE,
    app, 2, MUIM_Application_ReturnID, ID_EDITHANDLER])
  doMethodA(btnSaveCode, [MUIM_Notify, MUIA_Pressed, FALSE,
    app, 2, MUIM_Application_ReturnID, ID_SAVECODE])
  doMethodA(btnReloadCode, [MUIM_Notify, MUIA_Pressed, FALSE,
    app, 2, MUIM_Application_ReturnID, ID_RELOADCODE])
  doMethodA(btnCompile, [MUIM_Notify, MUIA_Pressed, FALSE,
    app, 2, MUIM_Application_ReturnID, ID_COMPILE])
  doMethodA(btnRun, [MUIM_Notify, MUIA_Pressed, FALSE,
    app, 2, MUIM_Application_ReturnID, ID_RUN])
  doMethodA(btnDelete, [MUIM_Notify, MUIA_Pressed, FALSE,
    app, 2, MUIM_Application_ReturnID, ID_DELETE])
  doMethodA(btnUp, [MUIM_Notify, MUIA_Pressed, FALSE,
    app, 2, MUIM_Application_ReturnID, ID_UP])
  doMethodA(btnDown, [MUIM_Notify, MUIA_Pressed, FALSE,
    app, 2, MUIM_Application_ReturnID, ID_DOWN])

  hookMenus(1)
  updateUndoMenu()

  -> toolbar buttons are numbered in order, spaces included; 0 = a space
  ids := [ID_NEWPROJ, ID_OPENPROJ, 0, ID_NEW, ID_OPEN, ID_SAVE, 0, ID_REMOVEFORM, 0,
          ID_PREVIEW, 0, ID_COMPILE, ID_RUN]
  FOR i := 0 TO 12
    IF ListItem(ids, i) > 0 THEN hookButton(actionsBar, i, ListItem(ids, i))
  ENDFOR
  FOR i := 0 TO 11
    IF i < 6 THEN hookButton(paletteBar, i, ID_PALETTE + i) ELSE hookButton(paletteBar2, i - 6, ID_PALETTE + i)
  ENDFOR
ENDPROC

PROC openWindows()
  addTree(form, MUIV_Listtree_Insert_ListNode_Root)
  loadCode()

  refreshProjectList()
  set(win, MUIA_Window_Open, MUI_TRUE)
  showProps(NIL)
  refreshLive()
  updateTitle()
ENDPROC

-> Handles one return ID; returns FALSE when it is time to quit
PROC handleId(id)
  DEF running
  running := TRUE
  IF (id >= ID_PALETTE) AND (id < (ID_PALETTE + 12))
    doAdd(id - ID_PALETTE)
  ELSE
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
      CASE ID_TREEDROP
        onTreeDrop()
      CASE ID_UNDO
        doUndo()
      CASE ID_REDO
        doRedo()
      CASE ID_DELETE
        doDelete()
      CASE ID_UP
        doMove(-1)
      CASE ID_DOWN
        doMove(1)
      CASE ID_SHOWFORM
        showFormTab()
      CASE ID_SHOWINSP
        toggleInspector()
      CASE ID_SHOWCODE
        showCode()
      CASE ID_NEWPROJ
        doNewProject()
      CASE ID_OPENPROJ
        doOpenProject()
      CASE ID_FORMSEL
        onFormSelect()
      CASE ID_REMOVEFORM
        doRemoveForm()
      CASE ID_MAKEMAIN
        doMakeMain()
      CASE ID_SIZE
        resizePreview()
      CASE ID_ENTRIES
        openEntries()
      CASE ID_ENTRIESOK
        applyEntries()
    ENDSELECT
  ENDIF
ENDPROC running

PROC mainLoop()
  DEF sigs = 0, id, running
  running := TRUE
  WHILE running
    id := doMethodA(app, [MUIM_Application_NewInput, {sigs}])
    running := handleId(id)

    -> typing in the title box does not rebuild on every key; Return, or any
    -> other action, brings the live form up to date
    IF running AND liveStale AND (id <> ID_TITLE) THEN refreshLive()
    IF running AND sigs THEN sigs := Wait(sigs)
  ENDWHILE
ENDPROC

PROC main() HANDLE
  app := NIL
  previewWin := NIL
  liveObj := NIL
  liveStale := FALSE
  dirty := FALSE
  titleFlip := FALSE
  numBuf := String(16)
  titleBuf1 := String(400)
  titleBuf2 := String(400)

  filename := cleanArg()
  IF StrLen(filename) = 0 THEN filename := defaultFormPath()

  IF isProjectFile(filename)
    IF loadCandidate(filename) = FALSE THEN Raise('Could not read the project')
    adoptCandidate(filename)
    form := projForms[0]
    filename := joinPath(dirPart(projectPath), projPaths[0])
  ELSE
    form := readForm(filename)
    IF form = NIL THEN Raise('Could not read the form')
  ENDIF

  IF (muimasterbase := OpenLibrary(MUIMASTER_NAME, MUIMASTER_VMIN)) = NIL THEN
    Raise('Failed to open muimaster.library')

  makeTree()
  makeEditors()
  makeToolbars()
  makeInspectorPanel()
  makeEditorPanel()
  makeMainWindow()
  makeEntriesWindow()
  makeApplication()
  connectEvents()
  openWindows()
  mainLoop()

  saveCode()
  set(win, MUIA_Window_Open, FALSE)

EXCEPT DO
  IF app THEN Mui_DisposeObject(app)
  IF treeMcc THEN Mui_DeleteCustomClass(treeMcc)
  IF muimasterbase THEN CloseLibrary(muimasterbase)
  IF exception THEN WriteF('\s\n', exception)
ENDPROC
