# DelphE

A Delphi-style visual IDE for Amiga E, written in Amiga E with MUI.

Status: **early foundation**. The form model and code generator exist and can be
tested without MUI. There is no GUI yet. See `docs/DESIGN.md` for the plan.

## Layout

```
src/FormModel.e   component tree for one form
src/Generator.e   form model -> E source
src/GenTest.e     smoke test: builds a form in code, prints generated source
forms/            example .mform files (format described in docs/DESIGN.md)
Build             AmigaDOS script: compiles modules and runs the smoke test
```

## Building (on the Amiga / in the emulator)

Needs Amiga E v3.3a (`ec`). From the DelphE drawer:

```
execute Build
```

The smoke test prints a generated unit to the shell. Nothing here has been
compiled yet: expect to fix small syntax errors on first run.

## Not yet in place

The MUI E modules (`muimaster`, `libraries/mui`, ...) are not part of stock
EC 3.3a and are needed from the GUI stage onward.
