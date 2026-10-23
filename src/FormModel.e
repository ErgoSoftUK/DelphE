/*
** DelphE form model
**
** An in-memory tree of components describing one form (window).
** The designer edits this tree; the generator turns it into E source.
*/

OPT MODULE
OPT EXPORT

ENUM CK_WINDOW, CK_VGROUP, CK_HGROUP, CK_BUTTON, CK_TEXT, CK_STRING, CK_CHECK

OBJECT component
  kind
  name
  title
  parent:     PTR TO component
  firstChild: PTR TO component
  lastChild:  PTR TO component
  next:       PTR TO component
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

PROC kindName(kind) IS ListItem(['Window', 'VGroup', 'HGroup', 'Button', 'Text', 'String', 'Check'], kind)

-> returns -1 for an unknown name
PROC kindFromName(s)
  DEF k
  FOR k := CK_WINDOW TO CK_CHECK
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
