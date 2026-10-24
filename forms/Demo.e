/*
** Demo
**
** Created by DelphE. This file is yours: the form lives in the .gen.e file
** next to it, which DelphE rewrites and inserts at the marker line below.
*/

OPT PREPROCESS
OPT LARGE

MODULE 'muimaster', 'libraries/mui', 'utility/tagitem',
       'amigalib/boopsi'

->>> DELPHE GENERATED CODE (the .gen.e file is inserted here when you compile: do not edit this line)



/*** your code ***/

PROC chkOnChange() OF tDemoSettings
  -> TODO: handle OnChange of chkOn
ENDPROC

PROC btnCloseClick() OF tDemoSettings
  -> TODO: handle OnClick of btnClose
ENDPROC

PROC btnOtherClick() OF tDemoMain
  -> TODO: handle OnClick of btnOther
ENDPROC

PROC main()
  delpheRun()
ENDPROC

PROC btn1Click() OF tTest
    fmDemoSettings.show()
ENDPROC

PROC cycColourChange() OF tKindsDemo
  -> TODO: handle OnChange of cycColour
ENDPROC

PROC radSizeChange() OF tKindsDemo
  -> TODO: handle OnChange of radSize
ENDPROC

PROC sldLevelChange() OF tKindsDemo
  -> TODO: handle OnChange of sldLevel
ENDPROC

PROC lstNamesDoubleClick() OF tKindsDemo
  -> TODO: handle OnDoubleClick of lstNames
ENDPROC
