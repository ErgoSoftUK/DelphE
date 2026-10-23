/*
** Smoke test for the .mform reader/writer and the generator.
** Needs no MUI: reads forms/sample.mform, echoes it back through the writer,
** then creates or updates MainForm.e (a complete program) with generateFile().
*/

MODULE '*FormModel', '*MForm', '*Generator'

PROC main()
  DEF win: PTR TO component, res

  win := readForm('/forms/sample.mform')
  IF win = NIL
    WriteF('Could not read the form\n')
    RETURN
  ENDIF

  WriteF('--- .mform round trip ---\n')
  writeForm(stdout, win, 0)

  res := generateFile('MainForm.e', win)
  WriteF('\n--- generateFile: \d (0 = ok) ---\n', res)
ENDPROC
