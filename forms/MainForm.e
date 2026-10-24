/*
** MainForm
**
** Created by DelphE. This file is yours: the form lives in the .gen.e file
** next to it, which DelphE rewrites and inserts at the marker line below.
*/

OPT PREPROCESS

MODULE 'muimaster', 'libraries/mui', 'utility/tagitem',
       'amigalib/boopsi'

->>> DELPHE GENERATED CODE (the .gen.e file is inserted here when you compile: do not edit this line)

/*** your code ***/

PROC btnOkClick() OF tMainForm
  WriteF('OK!')
ENDPROC

PROC btnCancelClick() OF tMainForm
  WriteF('Cancel!')
ENDPROC

PROC main() HANDLE
  DEF app = NIL, form: PTR TO tMainForm, sigs = 0, id, running

  IF (muimasterbase := OpenLibrary(MUIMASTER_NAME, MUIMASTER_VMIN)) = NIL THEN
    Raise('Failed to open muimaster.library')

  NEW form
  form.create()
  IF form.handle = NIL THEN Raise('Failed to create the window')

  app := ApplicationObject,
    MUIA_Application_Title      , 'MainForm',
    MUIA_Application_Base       , 'DELPHEFORM',
    SubWindow, form.handle,
  End

  IF app = NIL THEN Raise('Failed to create Application.')

  form.connect(app)
  doMethodA(form.handle, [MUIM_Notify, MUIA_Window_CloseRequest, MUI_TRUE,
    app, 2, MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])

  set(form.handle, MUIA_Window_Open, MUI_TRUE)

  running := TRUE
  WHILE running
    id := doMethodA(app, [MUIM_Application_NewInput, {sigs}])
    IF id = MUIV_Application_ReturnID_Quit
      running := FALSE
    ELSE
      form.handleEvent(id)
    ENDIF
    IF running AND sigs THEN sigs := Wait(sigs)
  ENDWHILE

  set(form.handle, MUIA_Window_Open, FALSE)

EXCEPT DO
  IF app THEN Mui_DisposeObject(app)
  IF muimasterbase THEN CloseLibrary(muimasterbase)
  IF exception THEN WriteF('\s\n', exception)
ENDPROC

PROC btn2Click() OF tMainForm
  -> TODO: handle OnClick of btn2
ENDPROC
