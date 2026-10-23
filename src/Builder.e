/*
** DelphE builder: form model -> live MUI objects.
**
** Shared by Preview and the designer. Walks the component tree from
** FormModel.e and creates the real MUI objects at runtime.
*/

OPT MODULE
OPT EXPORT
OPT PREPROCESS

MODULE 'muimaster', 'libraries/mui', 'utility/tagitem', '*FormModel'

PROC titleOf(c: PTR TO component)
  IF c.title THEN RETURN c.title
ENDPROC ''

PROC buildGroup(c: PTR TO component)
  DEF tags, n, ch: PTR TO component, child, obj

  n := 0
  ch := c.firstChild
  WHILE ch
    n++
    ch := ch.next
  ENDWHILE

  tags := List((n * 2) + 8)
  tags := ListCopy(tags, [TAG_IGNORE, 0])
  IF c.kind = CK_HGROUP THEN tags := ListAdd(tags, [MUIA_Group_Horiz, MUI_TRUE])

  ch := c.firstChild
  WHILE ch
    child := buildObject(ch)
    IF child = NIL
      DisposeLink(tags)
      RETURN NIL
    ENDIF
    tags := ListAdd(tags, [MUIA_Group_Child, child])
    ch := ch.next
  ENDWHILE

  tags := ListAdd(tags, [TAG_DONE, 0])
  obj := Mui_NewObjectA(MUIC_Group, tags)
  DisposeLink(tags)
ENDPROC obj

PROC buildObject(c: PTR TO component)
  DEF kind, t
  kind := c.kind
  t := titleOf(c)
  SELECT kind
    CASE CK_VGROUP
      RETURN buildGroup(c)
    CASE CK_HGROUP
      RETURN buildGroup(c)
    CASE CK_BUTTON
      RETURN Mui_MakeObjectA(MUIO_Button, [t])
    CASE CK_TEXT
      RETURN Mui_NewObjectA(MUIC_Text,
        [MUIA_Frame, MUIV_Frame_Text, MUIA_Text_Contents, t, TAG_DONE, 0])
    CASE CK_STRING
      RETURN Mui_NewObjectA(MUIC_String,
        [MUIA_Frame, MUIV_Frame_String, MUIA_String_Contents, t, TAG_DONE, 0])
    CASE CK_CHECK
      RETURN Mui_NewObjectA(MUIC_Image,
        [MUIA_Frame, MUIV_Frame_ImageButton,
         MUIA_InputMode, MUIV_InputMode_Toggle,
         MUIA_Image_Spec, MUII_CheckMark,
         MUIA_Image_FreeVert, MUI_TRUE,
         MUIA_Selected, FALSE,
         MUIA_Background, MUII_ButtonBack,
         MUIA_ShowSelState, FALSE,
         TAG_DONE, 0])
  ENDSELECT
ENDPROC NIL

-> Builds the window object for a CK_WINDOW component, or NIL on failure
PROC buildWindow(c: PTR TO component)
  DEF root
  IF c.firstChild = NIL THEN RETURN NIL
  root := buildObject(c.firstChild)
  IF root = NIL THEN RETURN NIL
ENDPROC Mui_NewObjectA(MUIC_Window,
  [MUIA_Window_Title, titleOf(c),
   MUIA_Window_ID, "PREV",
   MUIA_Window_RootObject, root,
   TAG_DONE, 0])
