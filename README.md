# DelphE

A Delphi-style visual IDE for Amiga E, written in Amiga E with MUI.

Design a form as a tree of MUI components, bind events to handler procedures,
edit the code, then compile and run, all from one MUI application. Forms are
saved as small text files (`.mform`); the IDE turns them into ordinary Amiga E
source.

## What works

- **Four windows, Delphi 3 style:** a main window with menus, a toolbar and a
  component palette; the Form window (structure tree beside the live form); the
  Object Inspector; and the Code window. Each remembers its position.

- **Form designer:** component tree, property inspector, add / delete / move
  components, live preview of the form as real MUI objects.
- **Components:** groups (vertical, horizontal), Button, Text, String, Check,
  Cycle, Radio, Slider, Gauge and List.
- **Properties:** weight, fixed width/height, hint, disabled, group frame, and
  min/max/value for sliders and gauges.
- **Events:** one per component kind (`OnClick`, `OnEnter`, `OnChange`,
  `OnDoubleClick`), bound to a handler procedure.
- **Code generation:** one E file per form, containing a regenerated section and
  your own code. Regenerating keeps your handlers and adds stubs for new ones.
- **Code editor** (TextEditor.mcc) with Compile and Run, compiler output, and
  jump to the line of a compile error.
- **Project menu** (New, Open, Save, Save As, Quit), **Edit menu** (Undo, Redo,
  Delete, Move up/down) and **Build menu** (Preview, Generate, Compile, Run),
  with unsaved-changes prompts.
- **Undo and redo** for every change to the form (up to 40 steps).
- **Drag and drop** in the Form window's tree to reorder components or move them
  into another group.

See `docs/DESIGN.md` for how it fits together.

## Requirements

- Amiga E v3.3a (`ec` on your path).
- MUI 3.8 (`muimaster.library`) and the MUI E modules (`libraries/mui`,
  `muimaster`, ...), for example from the Amiga-E MUI developer package. They
  must be where `ec` finds modules (`EMODULES:`).
- `TextEditor.mcc`, `Listtree.mcc` and `Toolbar.mcc` installed. The designer won't start
  without them.
- OS 3.x. Developed against an emulated 68k Amiga.

## Layout

```
src/FormModel.e     the component tree for one form
src/MForm.e         .mform reader and writer
src/Builder.e       form model -> live MUI objects (used by preview and designer)
src/Generator.e     form model -> E source file
src/Util.e          command line, file requester and string helpers
src/Preview.e       standalone live preview: Preview [file.mform]
src/GenTest.e       smoke test for the reader, writer and generator (no MUI)
src/designer/       the designer: Designer.e
src/mcc/            E modules for Listtree.mcc, TextEditor.mcc and Toolbar.mcc
Images/             toolbar image strips (actions.iff, components.iff)
tools/              make-icons.ps1: rebuilds the strips from the LED icon pack
forms/              example forms (sample.mform, kinds.mform, ...)
Build               AmigaDOS script: compiles everything
Watch               optional build watcher (see below)
docs/DESIGN.md      design notes, file formats, E and MUI gotchas
```

## Building

From the DelphE drawer on the Amiga:

```
execute Build
```

Output goes to `build.out`. This compiles the modules, runs the smoke test
(`gentest.out`), and builds `src/preview` and `src/designer/designer`.

## Running

```
src/designer/designer [forms/sample.mform]
src/preview [forms/sample.mform]
```

With no argument, both open `forms/sample.mform`.

## Build watcher

`Watch` lets something outside the Amiga trigger builds, which is handy when
the source tree is shared with a host machine:

```
run execute Watch
```

Creating a file called `build.trigger` runs `Build`; `build.done` appears when
it finishes, and the results are in `build.out`. Creating `build.stop` stops
the watcher.

## Using the designer

1. **Open** a form, or **New** to start one (toolbar or Project menu). Select a
   component in the Form window's tree, then edit it in the Object Inspector:
   its name, title, layout properties, and (on the Events page) its handler.
   Names must start with a lowercase letter, and must be unique.
2. Click a component in the **palette** on the main window to add it inside the
   selected group, or beside the selected component. The Form window shows the
   result live, and has Delete, Up and Down for the selected component. You can
   also drag an entry in the tree to a new place, including into another group.
   Moves the form cannot hold (for example, a second group next to the window's
   one group) are refused and the tree snaps back.
3. **Preview form** (Build menu) shows the form as it is right now.
4. **Generate code** writes `<WindowName>.e` next to the `.mform` file. Select a
   component with a handler and click **Edit** to jump to its procedure.
5. **Compile** and **Run** (toolbar, Build menu or the Code window) build and
   start the program. Windows you have closed come back from the Window menu.

Generated files contain `DELPHE BEGIN` and `DELPHE END` markers. Edit your code
below the markers; the section between them is rewritten on every Generate.

## Credits

The toolbar icons come from the LED icons pack by [led24.de](http://led24.de),
licensed under [CC BY-SA 3.0](http://creativecommons.org/licenses/by-sa/3.0/).
See `Images/ICONS.txt`.
