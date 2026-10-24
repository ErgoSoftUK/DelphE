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

-> "One|Two|Three" -> a NIL-terminated list of strings, as the Cycle, Radio and
-> List classes want it (the strings are not freed: MUI keeps the pointers)
PROC splitItems(s)
  DEF l, n, i, start, item, len
  len := StrLen(s)
  n := 1
  FOR i := 0 TO len - 1
    IF s[i] = "|" THEN n++
  ENDFOR
  l := List(n + 1)
  start := 0
  FOR i := 0 TO len
    IF (i = len) OR (s[i] = "|")
      item := String(i - start + 1)
      IF i > start THEN MidStr(item, s, start, i - start)
      ListAdd(l, [item], 1)
      start := i + 1
    ENDIF
  ENDFOR
  ListAdd(l, [NIL], 1)
ENDPROC l

-> Optional numbers with a default
PROC numberOr(c: PTR TO component, bit, v, dflt)
  IF c.propFlags AND bit THEN RETURN v
ENDPROC dflt

-> The MUIA_Font value for a font index (see fontName in FormModel)
PROC fontValue(idx)
  SELECT idx
    CASE 1
      RETURN MUIV_Font_Normal
    CASE 2
      RETURN MUIV_Font_Tiny
    CASE 3
      RETURN MUIV_Font_Big
    CASE 4
      RETURN MUIV_Font_Title
    CASE 5
      RETURN MUIV_Font_Fixed
    CASE 6
      RETURN MUIV_Font_List
    CASE 7
      RETURN MUIV_Font_Button
  ENDSELECT
ENDPROC MUIV_Font_Inherit

-> Adds the tags for the component's optional properties; returns the list
PROC addExtras(tags, c: PTR TO component)
  DEF flags
  flags := c.propFlags
  IF flags AND PF_WEIGHT THEN tags := ListAdd(tags, [MUIA_Weight, c.weight])
  IF flags AND PF_FIXW THEN tags := ListAdd(tags, [MUIA_FixWidth, c.fixW])
  IF flags AND PF_FIXH THEN tags := ListAdd(tags, [MUIA_FixHeight, c.fixH])
  IF flags AND PF_DISABLED THEN tags := ListAdd(tags, [MUIA_Disabled, MUI_TRUE])
  IF flags AND PF_FONT THEN tags := ListAdd(tags, [MUIA_Font, fontValue(c.fontIdx)])
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

-> Exactly one tab title per page: the entries of the Pages component's title, then
-> "Page 3" and so on for the pages that have none
PROC pageTitleList(c: PTR TO component, n)
  DEF l, k, count, item
  count := n
  IF count < 1 THEN count := 1
  l := List(count + 1)
  FOR k := 0 TO count - 1
    item := nthItem(titleOf(c), k)
    IF item
      IF StrLen(item) = 0 THEN item := NIL
    ENDIF
    IF item = NIL
      item := String(16)
      IF n = 0 THEN StrCopy(item, '(empty)', ALL) ELSE StringF(item, 'Page \d', k + 1)
    ENDIF
    ListAdd(l, [item], 1)
  ENDFOR
  ListAdd(l, [NIL], 1)
ENDPROC l

PROC buildGroup(c: PTR TO component)
  DEF tags, n, ch: PTR TO component, child, obj, class

  n := 0
  ch := c.firstChild
  WHILE ch
    n++
    ch := ch.next
  ENDWHILE

  tags := List((n * 2) + TAGROOM)
  tags := ListCopy(tags, [TAG_IGNORE, 0])
  class := MUIC_Group
  IF c.kind = CK_HGROUP THEN tags := ListAdd(tags, [MUIA_Group_Horiz, MUI_TRUE])
  IF c.kind = CK_PAGES
    class := MUIC_Register
    tags := ListAdd(tags, [MUIA_Register_Titles, pageTitleList(c, n), MUIA_Register_Frame, MUI_TRUE])
  ENDIF
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

  -> a Register needs at least one page
  IF (c.kind = CK_PAGES) AND (n = 0)
    child := Mui_NewObjectA(MUIC_Rectangle, [TAG_DONE, 0])
    IF child THEN tags := ListAdd(tags, [MUIA_Group_Child, child])
  ENDIF

  tags := ListAdd(tags, [TAG_DONE, 0])
  obj := Mui_NewObjectA(class, tags)
  DisposeLink(tags)
ENDPROC obj

PROC buildObject(c: PTR TO component)
  DEF kind, t, tags, obj, class
  kind := c.kind
  t := titleOf(c)

  IF (kind = CK_VGROUP) OR (kind = CK_HGROUP) OR (kind = CK_PAGES) THEN RETURN buildGroup(c)

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
    CASE CK_CYCLE
      class := MUIC_Cycle
      tags := ListAdd(tags, [MUIA_Font, MUIV_Font_Button, MUIA_Cycle_Entries, splitItems(t)])
    CASE CK_RADIO
      class := MUIC_Radio
      tags := ListAdd(tags, [MUIA_Radio_Entries, splitItems(t)])
    CASE CK_SLIDER
      class := MUIC_Slider
      tags := ListAdd(tags,
        [MUIA_Numeric_Min, numberOr(c, PF_MIN, c.minV, 0),
         MUIA_Numeric_Max, numberOr(c, PF_MAX, c.maxV, 100),
         MUIA_Numeric_Value, numberOr(c, PF_VALUE, c.value, 0)])
    CASE CK_GAUGE
      class := MUIC_Gauge
      tags := ListAdd(tags,
        [MUIA_Frame, MUIV_Frame_Gauge, MUIA_Gauge_Horiz, MUI_TRUE,
         MUIA_Gauge_Max, numberOr(c, PF_MAX, c.maxV, 100),
         MUIA_Gauge_Current, numberOr(c, PF_VALUE, c.value, 0)])
    CASE CK_LIST
      class := MUIC_Listview
      tags := ListAdd(tags, [MUIA_Listview_List,
        Mui_NewObjectA(MUIC_List, [MUIA_Frame, MUIV_Frame_InputList,
                                   MUIA_List_SourceArray, splitItems(t), TAG_DONE, 0])])
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
