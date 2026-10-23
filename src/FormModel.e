/*
** DelphE form model
**
** An in-memory tree of components describing one form (window).
** The designer edits this tree; the generator turns it into E source.
*/

OPT MODULE
OPT EXPORT

ENUM CK_WINDOW, CK_VGROUP, CK_HGROUP, CK_BUTTON, CK_TEXT, CK_STRING, CK_CHECK,
     CK_CYCLE, CK_RADIO, CK_SLIDER, CK_GAUGE, CK_LIST

-> which optional properties a component sets (propFlags); 0 = all defaults
CONST PF_WEIGHT = 1, PF_FIXW = 2, PF_FIXH = 4, PF_DISABLED = 8, PF_FRAME = 16, PF_HINT = 32,
      PF_MIN = 64, PF_MAX = 128, PF_VALUE = 256

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

PROC isContainer(kind) IS (kind = CK_WINDOW) OR (kind = CK_VGROUP) OR (kind = CK_HGROUP)

PROC kindName(kind) IS ListItem(['Window', 'VGroup', 'HGroup', 'Button', 'Text', 'String', 'Check',
                                  'Cycle', 'Radio', 'Slider', 'Gauge', 'List'], kind)

-> returns -1 for an unknown name
PROC kindFromName(s)
  DEF k
  FOR k := CK_WINDOW TO CK_LIST
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
