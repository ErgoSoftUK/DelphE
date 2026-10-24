/*
** Smoke test for the .mform reader/writer and the generator.
** Needs no MUI: reads examples/sample.mform, echoes it back through the writer,
** then creates or updates MainForm.e (a complete program) with generateFile().
*/

MODULE '*/src/FormModel', '*/src/MForm', '*/src/Generator'

PROC main()
  DEF win: PTR TO component, res, first, glines

  win := readForm('/examples/sample.mform')
  IF win = NIL
    WriteF('Could not read the form\n')
    RETURN
  ENDIF

  WriteF('--- .mform round trip ---\n')
  writeForm(stdout, win, 0)

  res := generateFile('MainForm.e', win)
  WriteF('\n--- generateFile: \d (0 = ok) ---\n', res)

  -> the program the compiler gets: MainForm.e with MainForm.gen.e put into it
  first, glines := buildSource('MainForm.e', 'MainFormBuilt.e')
  WriteF('--- buildSource: generated code at line \d, \d lines ---\n', first, glines)
ENDPROC
