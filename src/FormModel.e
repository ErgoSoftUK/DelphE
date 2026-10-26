/*
** DelphE form model
**
** An in-memory tree of components describing one form (window).
** The designer edits this tree; the generator turns it into E source.
*/

OPT MODULE
OPT EXPORT

ENUM CK_WINDOW, CK_VGROUP, CK_HGROUP, CK_BUTTON, CK_TEXT, CK_STRING, CK_CHECK,
     CK_CYCLE, CK_RADIO, CK_SLIDER, CK_GAUGE, CK_LIST, CK_PAGES,
     CK_SPACER, CK_COLGROUP, CK_SCROLL, CK_MEMO,
     CK_UTILS, CK_FILEDLG, CK_MSGDLG, CK_FRAME, CK_USE,
     CK_MENUSTRIP, CK_MENU, CK_MENUITEM

-> which optional properties a component sets (propFlags); 0 = all defaults
CONST PF_WEIGHT = 1, PF_FIXW = 2, PF_FIXH = 4, PF_DISABLED = 8, PF_FRAME = 16, PF_HINT = 32,
      PF_MIN = 64, PF_MAX = 128, PF_VALUE = 256, PF_FONT = 512, PF_ARG = 1024, PF_SAVE = 2048

OBJECT component
  kind
  name
  title
  parent:     PTR TO component
  firstChild: PTR TO component
  lastChild:  PTR TO component
  next:       PTR TO component
  handler                             -> name of the event handler procedure, or NIL
  propFlags                           -> PF_ bits
  weight                              -> MUIA_Weight (PF_WEIGHT)
  fixW                                -> MUIA_FixWidth (PF_FIXW)
  fixH                                -> MUIA_FixHeight (PF_FIXH)
  hint                                -> MUIA_ShortHelp (PF_HINT)
  minV                                -> slider minimum (PF_MIN)
  maxV                                -> slider/gauge maximum (PF_MAX)
  value                               -> slider/gauge value (PF_VALUE)
  fontIdx                             -> one of MUI's standard fonts, see fontName (PF_FONT)
  arg                                 -> a file dialog's pattern, a message dialog's buttons (PF_ARG)
  uiNode                              -> designer's tree node for this component
ENDOBJECT

PROC newComponent(kind, name, title)
  DEF c: PTR TO component
  NEW c
  c.kind  := kind
  c.name  := name
  c.title := title
ENDPROC c

PROC addChild(child: PTR TO component) OF component
  child.parent := self
  IF self.lastChild THEN self.lastChild.next := child ELSE self.firstChild := child
  self.lastChild := child
ENDPROC

PROC isContainer(kind) IS (kind = CK_WINDOW) OR (kind = CK_VGROUP) OR (kind = CK_HGROUP) OR (kind = CK_PAGES) OR (kind = CK_COLGROUP) OR (kind = CK_SCROLL) OR (kind = CK_UTILS) OR (kind = CK_FRAME) OR
                          (kind = CK_MENUSTRIP) OR (kind = CK_MENU) OR (kind = CK_MENUITEM)

PROC kindName(kind) IS ListItem(['Window', 'VGroup', 'HGroup', 'Button', 'Text', 'String', 'Check',
                                  'Cycle', 'Radio', 'Slider', 'Gauge', 'List', 'Pages', 'Spacer', 'ColGroup', 'Scroll', 'Memo',
                                  'Utilities', 'FileDialog', 'MessageDialog', 'Frame', 'Use',
                                  'MenuStrip', 'Menu', 'MenuItem'], kind)

-> returns -1 for an unknown name
PROC kindFromName(s)
  DEF k
  FOR k := CK_WINDOW TO CK_MENUITEM
    IF StrLen(s) = StrLen(kindName(k))
      IF StrCmp(kindName(k), s, ALL) THEN RETURN k
    ENDIF
  ENDFOR
ENDPROC -1

-> Inserts child so that it ends up at position index (0 = first)
PROC insertAt(child: PTR TO component, index) OF component
  DEF prev: PTR TO component, c: PTR TO component, i
  child.parent := self
  prev := NIL
  c := self.firstChild
  i := 0
  WHILE c AND (i < index)
    prev := c
    c := c.next
    i++
  ENDWHILE
  child.next := c
  IF prev THEN prev.next := child ELSE self.firstChild := child
  IF c = NIL THEN self.lastChild := child
ENDPROC

-> Detaches child (and its subtree) from this component
PROC removeChild(child: PTR TO component) OF component
  DEF prev: PTR TO component, c: PTR TO component
  prev := NIL
  c := self.firstChild
  WHILE c
    IF c = child
      IF prev THEN prev.next := c.next ELSE self.firstChild := c.next
      IF self.lastChild = c THEN self.lastChild := prev
      c.next := NIL
      c.parent := NIL
      RETURN
    ENDIF
    prev := c
    c := c.next
  ENDWHILE
ENDPROC

-> Position of child among its siblings, or -1
PROC indexOf(child: PTR TO component) OF component
  DEF c: PTR TO component, i
  c := self.firstChild
  i := 0
  WHILE c
    IF c = child THEN RETURN i
    i++
    c := c.next
  ENDWHILE
ENDPROC -1

PROC childCount() OF component
  DEF c: PTR TO component, n
  c := self.firstChild
  n := 0
  WHILE c
    n++
    c := c.next
  ENDWHILE
ENDPROC n

-> Each kind with an event has exactly one, named here (NIL = no events)
PROC eventName(kind)
  SELECT kind
    CASE CK_BUTTON
      RETURN 'OnClick'
    CASE CK_STRING
      RETURN 'OnEnter'
    CASE CK_CHECK
      RETURN 'OnChange'
    CASE CK_CYCLE
      RETURN 'OnChange'
    CASE CK_RADIO
      RETURN 'OnChange'
    CASE CK_SLIDER
      RETURN 'OnChange'
    CASE CK_LIST
      RETURN 'OnDoubleClick'
    CASE CK_MENUITEM
      RETURN 'OnSelect'
  ENDSELECT
ENDPROC NIL

-> Suffix for a default handler name: btnOk + Click = btnOkClick
PROC eventSuffix(kind)
  SELECT kind
    CASE CK_BUTTON
      RETURN 'Click'
    CASE CK_STRING
      RETURN 'Enter'
    CASE CK_CHECK
      RETURN 'Change'
    CASE CK_CYCLE
      RETURN 'Change'
    CASE CK_RADIO
      RETURN 'Change'
    CASE CK_SLIDER
      RETURN 'Change'
    CASE CK_LIST
      RETURN 'DoubleClick'
    CASE CK_MENUITEM
      RETURN 'Select'
  ENDSELECT
ENDPROC NIL

-> A deep copy of c and everything under it. Strings are shared with the
-> original: they are never changed in place, only replaced, so that is safe.
PROC cloneTree(c: PTR TO component)
  DEF n: PTR TO component, ch: PTR TO component
  NEW n
  n.kind := c.kind
  n.name := c.name
  n.title := c.title
  n.handler := c.handler
  n.propFlags := c.propFlags
  n.weight := c.weight
  n.fixW := c.fixW
  n.fixH := c.fixH
  n.hint := c.hint
  n.minV := c.minV
  n.maxV := c.maxV
  n.value := c.value
  n.fontIdx := c.fontIdx
  n.arg := c.arg
  ch := c.firstChild
  WHILE ch
    n.addChild(cloneTree(ch))
    ch := ch.next
  ENDWHILE
ENDPROC n

-> Frees the component objects of a tree (not the strings they point to)
PROC freeTree(c: PTR TO component)
  DEF ch: PTR TO component, nx: PTR TO component
  IF c = NIL THEN RETURN
  ch := c.firstChild
  WHILE ch
    nx := ch.next
    freeTree(ch)
    ch := nx
  ENDWHILE
  END c
ENDPROC

-> The next component in tree order (parent before children), or NIL
PROC nextInTree(c: PTR TO component)
  IF c.firstChild THEN RETURN c.firstChild
  WHILE c
    IF c.next THEN RETURN c.next
    c := c.parent
  ENDWHILE
ENDPROC NIL

-> Position of target in tree order starting at root, or -1
PROC indexInTree(root: PTR TO component, target: PTR TO component)
  DEF c: PTR TO component, n
  n := 0
  c := root
  WHILE c
    IF c = target THEN RETURN n
    n++
    c := nextInTree(c)
  ENDWHILE
ENDPROC -1

-> The component at that position, or NIL
PROC componentAt(root: PTR TO component, n)
  DEF c: PTR TO component
  c := root
  WHILE c AND (n > 0)
    c := nextInTree(c)
    n--
  ENDWHILE
ENDPROC c

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

-> The k-th entry (counting from 0) of "One|Two|Three" as a new E-string, or NIL if
-> there are fewer
PROC nthItem(s, k)
  DEF i, start, len, n, item
  len := StrLen(s)
  start := 0
  n := 0
  FOR i := 0 TO len
    IF (i = len) OR (s[i] = "|")
      IF n = k
        item := String(i - start + 1)
        IF i > start THEN MidStr(item, s, start, i - start)
        RETURN item
      ENDIF
      n++
      start := i + 1
    ENDIF
  ENDFOR
ENDPROC NIL

-> MUI's standard fonts, which follow the user's MUI preferences; 0 means "not set"
PROC fontName(idx) IS ListItem(['', 'normal', 'tiny', 'big', 'title', 'fixed', 'list', 'button'], idx)

-> The index of a font name (1 to 7), or 0 if it is not one
PROC fontIndex(name)
  DEF k
  FOR k := 1 TO 7
    IF StrLen(name) = StrLen(fontName(k))
      IF StrCmp(name, fontName(k), ALL) THEN RETURN k
    ENDIF
  ENDFOR
ENDPROC 0

-> The font index a component ends up with: its own, else the nearest ancestor's, else 0.
-> MUI only passes a group's font on to children that have no font of their own, and
-> buttons, cycles and the like do, so the designer sets it on each widget explicitly.
PROC effectiveFont(c: PTR TO component)
  WHILE c
    IF c.propFlags AND PF_FONT THEN RETURN c.fontIdx
    c := c.parent
  ENDWHILE
ENDPROC 0

-> The MUI class file a kind needs beyond MUI itself, or NIL for the built-in ones
PROC kindClass(kind)
  IF kind = CK_MEMO THEN RETURN 'TextEditor.mcc'
ENDPROC NIL

-> Does c or anything under it have this kind?
PROC usesKind(c: PTR TO component, kind)
  DEF ch: PTR TO component
  IF c.kind = kind THEN RETURN TRUE
  ch := c.firstChild
  WHILE ch
    IF usesKind(ch, kind) THEN RETURN TRUE
    ch := ch.next
  ENDWHILE
ENDPROC FALSE

-> Non-visual components (dialogs and the like) live in the Utilities branch of the
-> window, which is its last child; the form itself is the first
PROC isUtilityKind(kind) IS (kind = CK_FILEDLG) OR (kind = CK_MSGDLG) OR (kind = CK_MENUSTRIP)

-> The window's root group: its first child that is not the Utilities branch, or NIL
PROC rootOf(win: PTR TO component)
  DEF ch: PTR TO component
  ch := win.firstChild
  WHILE ch
    IF ch.kind <> CK_UTILS THEN RETURN ch
    ch := ch.next
  ENDWHILE
ENDPROC NIL

-> The window's Utilities branch, or NIL if it has none
PROC utilitiesOf(win: PTR TO component)
  DEF ch: PTR TO component
  ch := win.firstChild
  WHILE ch
    IF ch.kind = CK_UTILS THEN RETURN ch
    ch := ch.next
  ENDWHILE
ENDPROC NIL

-> The roots of a file: a window (a form) or a frame (a reusable group that forms
-> and other frames can use). Each holds one root group.
PROC isRootKind(kind) IS (kind = CK_WINDOW) OR (kind = CK_FRAME)

-> The parts of a menu: a strip (one per window, in the Utilities branch) holds menus,
-> a menu holds items, and an item can hold items (a submenu)
PROC isMenuKind(kind) IS (kind = CK_MENUSTRIP) OR (kind = CK_MENU) OR (kind = CK_MENUITEM)

PROC isVisualKind(kind) IS (isUtilityKind(kind) = FALSE) AND (isMenuKind(kind) = FALSE) AND (kind <> CK_UTILS) AND (isRootKind(kind) = FALSE)

-> May a component of kind child be directly under one of kind parent?
PROC allowedChild(parent, child)
  SELECT parent
    CASE CK_UTILS
      RETURN isUtilityKind(child)
    CASE CK_MENUSTRIP
      RETURN child = CK_MENU
    CASE CK_MENU
      RETURN child = CK_MENUITEM
    CASE CK_MENUITEM
      RETURN child = CK_MENUITEM
  ENDSELECT
ENDPROC isVisualKind(child)

-> The window's menu strip, or NIL if it has none
PROC menustripOf(win: PTR TO component)
  DEF u: PTR TO component, ch: PTR TO component
  u := utilitiesOf(win)
  IF u = NIL THEN RETURN NIL
  ch := u.firstChild
  WHILE ch
    IF ch.kind = CK_MENUSTRIP THEN RETURN ch
    ch := ch.next
  ENDWHILE
ENDPROC NIL
