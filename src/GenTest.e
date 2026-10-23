/*
** Smoke test for the .mform reader/writer and the generator.
** Needs no MUI: reads forms/sample.mform, echoes it back through the writer,
** prints the generated source and writes it to MainForm.e for FormHost.
*/

MODULE 'dos/dos', '*FormModel', '*MForm', '*Generator'

PROC main()
  DEF win: PTR TO component, fh

  win := readForm('/forms/sample.mform')
  IF win = NIL
    WriteF('Could not read the form\n')
    RETURN
  ENDIF

  WriteF('--- .mform round trip ---\n')
  writeForm(stdout, win, 0)

  WriteF('\n--- generated source ---\n')
  generateUnit(stdout, win)

  fh := Open('MainForm.e', MODE_NEWFILE)
  IF fh
    generateUnit(fh, win)
    Close(fh)
  ENDIF
ENDPROC
