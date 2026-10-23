/*
** DelphE builder: form model -> live MUI objects.
**
** Shared by Preview and the designer. Walks the component tree from
** FormModel.e and creates the real MUI objects at runtime. Every object is
** made from a tag list built on the fly, so optional properties (weight,
** fixed size, hint, ...) are just more tags.
*/

OPT MODULE
OPT EXPORT
OPT PREPROCESS

MODULE 'muimaster', 'libraries/mui', 'utility/tagitem', '*FormModel'

CONST TAGROOM = 64

PROC titleOf(c: PTR TO component)
  IF c.title THEN RETURN c.title
ENDPROC ''

-> Adds the tags for the component's optional properties; returns the list
PROC addExtras(tags, c: PTR TO component)
  DEF flags
  flags := c.propFlags
  IF flags AND PF_WEIGHT THEN tags := ListAdd(tags, [MUIA_Weight, c.weight])
  IF flags AND PF_FIXW THEN tags := ListAdd(tags, [MUIA_FixWidth, c.fixW])
  IF flags AND PF_FIXH THEN tags := ListAdd(tags, [MUIA_FixHeight, c.fixH])
  IF flags AND PF_DISABLED THEN tags := ListAdd(tags, [MUIA_Disabled, MUI_TRUE])
  IF flags AND PF_HINT THEN tags := ListAdd(tags, [MUIA_ShortHelp, c.hint])
  IF isContainer(c.kind) AND (c.kind <> CK_WINDOW)
    IF flags AND PF_FRAME
      tags := ListAdd(tags, [MUIA_Frame, MUIV_Frame_Group])
      IF c.title
        IF StrLen(c.title) > 0 THEN tags := ListAdd(tags, [MUIA_FrameTitle, c.title])
      ENDIF
    ENDIF
  ENDIF
ENDPROC tags

PROC buildGroup(c: PTR TO component)
  DEF tags, n, ch: PTR TO component, child, obj

  n := 0
  ch := c.firstChild
  WHILE ch
    n++
    ch := ch.next
  ENDWHILE

  tags := List((n * 2) + TAGROOM)
  tags := ListCopy(tags, [TAG_IGNORE, 0])
  IF c.kind = CK_HGROUP THEN tags := ListAdd(tags, [MUIA_Group_Horiz, MUI_TRUE])
  tags := addExtras(tags, c)

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
  DEF kind, t, tags, obj, class
  kind := c.kind
  t := titleOf(c)

  IF (kind = CK_VGROUP) OR (kind = CK_HGROUP) THEN RETURN buildGroup(c)

  tags := List(TAGROOM)
  tags := ListCopy(tags, [TAG_IGNORE, 0])
  class := NIL

  SELECT kind
    CASE CK_BUTTON
      class := MUIC_Text
      tags := ListAdd(tags,
        [MUIA_Frame, MUIV_Frame_Button, MUIA_Font, MUIV_Font_Button,
         MUIA_Text_Contents, t, MUIA_Text_PreParse, '\ec',
         MUIA_InputMode, MUIV_InputMode_RelVerify,
         MUIA_Background, MUII_ButtonBack])
    CASE CK_TEXT
      class := MUIC_Text
      tags := ListAdd(tags, [MUIA_Frame, MUIV_Frame_Text, MUIA_Text_Contents, t])
    CASE CK_STRING
      class := MUIC_String
      tags := ListAdd(tags, [MUIA_Frame, MUIV_Frame_String, MUIA_String_Contents, t])
    CASE CK_CHECK
      class := MUIC_Image
      tags := ListAdd(tags,
        [MUIA_Frame, MUIV_Frame_ImageButton,
         MUIA_InputMode, MUIV_InputMode_Toggle,
         MUIA_Image_Spec, MUII_CheckMark,
         MUIA_Image_FreeVert, MUI_TRUE,
         MUIA_Selected, FALSE,
         MUIA_Background, MUII_ButtonBack,
         MUIA_ShowSelState, FALSE])
  ENDSELECT

  IF class = NIL
    DisposeLink(tags)
    RETURN NIL
  ENDIF

  tags := addExtras(tags, c)
  tags := ListAdd(tags, [TAG_DONE, 0])
  obj := Mui_NewObjectA(class, tags)
  DisposeLink(tags)
ENDPROC obj

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
