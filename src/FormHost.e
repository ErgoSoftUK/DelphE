/*
** FormHost: opens the generated MainForm unit in a real MUI application.
** Proves that generated code compiles and runs; the preview pane in the
** designer will do the same thing in-process.
*/

OPT PREPROCESS

MODULE 'muimaster', 'libraries/mui', 'utility/tagitem', 'amigalib/boopsi',
       '*MainForm'

PROC main() HANDLE
  DEF app = NIL, form: PTR TO tMainForm, sigs = 0

  IF (muimasterbase := OpenLibrary(MUIMASTER_NAME, MUIMASTER_VMIN)) = NIL THEN
    Raise('Failed to open muimaster.library')

  NEW form
  form.create()

  app := ApplicationObject,
    MUIA_Application_Title      , 'FormHost',
    MUIA_Application_Version    , '$VER: FormHost 0.1 (23.10.26)',
    MUIA_Application_Description, 'DelphE generated form host',
    MUIA_Application_Base       , 'FORMHOST',
    SubWindow, form.handle,
  End

  IF app = NIL THEN Raise('Failed to create Application.')

  doMethodA(form.handle, [MUIM_Notify, MUIA_Window_CloseRequest, MUI_TRUE,
    app, 2, MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])

  set(form.handle, MUIA_Window_Open, MUI_TRUE)

  WHILE (doMethodA(app, [MUIM_Application_NewInput, {sigs}]) <> MUIV_Application_ReturnID_Quit)
    IF sigs THEN sigs := Wait(sigs)
  ENDWHILE

  set(form.handle, MUIA_Window_Open, FALSE)

EXCEPT DO
  IF app THEN Mui_DisposeObject(app)
  IF muimasterbase THEN CloseLibrary(muimasterbase)
  IF exception THEN WriteF('\s\n', exception)
ENDPROC
