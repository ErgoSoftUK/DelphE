/*
** Preview: opens a .mform file as a live MUI window, no compile step.
**
**   Preview [file.mform]        (default: examples/sample.mform)
*/

OPT PREPROCESS

MODULE 'muimaster', 'libraries/mui', 'utility/tagitem', 'amigalib/boopsi',
       '*FormModel', '*MForm', '*Builder', '*Util'

PROC main() HANDLE
  DEF app = NIL, win, form: PTR TO component, sigs = 0, filename

  filename := cleanArg()
  IF StrLen(filename) = 0 THEN filename := defaultFormPath()

  form := readForm(filename)
  IF form = NIL THEN Raise('Could not read the form')

  IF (muimasterbase := OpenLibrary(MUIMASTER_NAME, MUIMASTER_VMIN)) = NIL THEN
    Raise('Failed to open muimaster.library')

  win := buildWindow(form)
  IF win = NIL THEN Raise('Failed to build the window')

  app := ApplicationObject,
    MUIA_Application_Title      , 'DelphE Preview',
    MUIA_Application_Version    , '$VER: Preview 0.1 (23.10.26)',
    MUIA_Application_Description, 'Live preview of a DelphE form',
    MUIA_Application_Base       , 'DELPHEPREVIEW',
    SubWindow, win,
  End

  IF app = NIL THEN Raise('Failed to create Application.')

  doMethodA(win, [MUIM_Notify, MUIA_Window_CloseRequest, MUI_TRUE,
    app, 2, MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])

  set(win, MUIA_Window_Open, MUI_TRUE)

  WHILE (doMethodA(app, [MUIM_Application_NewInput, {sigs}]) <> MUIV_Application_ReturnID_Quit)
    IF sigs THEN sigs := Wait(sigs)
  ENDWHILE

  set(win, MUIA_Window_Open, FALSE)

EXCEPT DO
  IF app THEN Mui_DisposeObject(app)
  IF muimasterbase THEN CloseLibrary(muimasterbase)
  IF exception THEN WriteF('\s\n', exception)
ENDPROC
