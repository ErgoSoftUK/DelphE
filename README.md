# DelphE

A Delphi-style visual IDE for Amiga E, written in Amiga E with MUI.

Design a form as a tree of MUI components, bind events to handler procedures,
edit the code, then compile and run, all from one MUI application. Forms are
saved as small text files (`.mform`); the IDE turns them into ordinary Amiga E
source.

## What works

- **One window, Delphi style:** the actions toolbar on top, the Object Inspector
  docked at the left (form drop-down, component palette, component tree and
  properties), the live form and the code on two tabs filling the rest,
  and a status line at the bottom. A Balance bar between the inspector and the
  tabs sets the split, and the inspector can be hidden from the View menu.

- **Form designer:** component tree, property inspector, add / delete / move
  components, live preview of the form as real MUI objects.
- **Components:** groups (vertical, horizontal), Button, Text, String, Check,
  Cycle, Radio, Slider, Gauge, List, Pages (tabs), Spacer, ColGroup (columns), Scroll
  (a scrolling group) and Memo (a multi-line text editor; needs TextEditor.mcc).
  A component whose MUI class is not installed gets a greyed-out palette button.
- **Frames:** a reusable group of components in its own `.mframe` file, like a Delphi frame. Name a
  new file `something.mframe` in the New dialog to make one. A form (or another frame) uses it with
  the Use button on the Layout tab; the frame is built inline in the preview, and your code reaches
  its components as `self.propsPanel.edtName`. Frame paths are relative to the program's folder.
- **Utilities:** non-visual components (a file dialog and a message dialog so far) live in a
  Utilities branch of the window, added from the Utility palette tab. Your code calls them:
  `self.fdlg1.execute()` returns whether a file was chosen (`self.fdlg1.path`), and
  `self.mdlg1.execute()` returns the number of the button pressed.
- **Entries dialog:** a `...` button beside Title/items opens a small editor with
  one entry per line, for Cycle, Radio and List components.
- **Properties:** weight, fixed width/height, font, hint, disabled, group frame,
  and min/max/value for sliders and gauges.
- **Events:** one per component kind (`OnClick`, `OnEnter`, `OnChange`,
  `OnDoubleClick`), bound to a handler procedure.
- **Code generation:** the form becomes `<Name>.gen.e`, which is rewritten every time,
  and a separate `<Name>.e` that is all yours: the generated code is inserted into it
  when you compile, so the editor never shows it. New handlers get a stub appended.
- **Component tree:** double-click a component to jump to its handler in the code (a handler
  name is made for it first if it has none).
- **Code editor** (TextEditor.mcc) with syntax colours, Build and Run, compiler output, and
  jump to the line of a compile error.
- **Project menu** (New, Open, Save, Save As, Quit), **Edit menu** (Undo, Redo,
  Delete, Move up/down) and **Build menu** (Preview, Generate, Build (Right-Amiga+B), Run; Generate is menu-only),
  with unsaved-changes prompts.
- **Projects:** a `.mproj` file lists several forms. Generate writes one program
  holding every form, and a handler can open another form (`fmSettings.show()`).
- **Undo and redo** for every change to the form (up to 40 steps).
- **Drag and drop** in the component tree to reorder components or move them
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
src/Project.e       .mproj reader and writer
src/Preview.e       standalone live preview: Preview [file.mform]
src/designer/       the designer: Designer.e
src/mcc/            E modules for Listtree.mcc, TextEditor.mcc and Toolbar.mcc
Images/             toolbar image strips (actions.iff, layout.iff, input.iff, display.iff, utility.iff)
tools/              development tools: make-icons.ps1 (rebuilds the strips from the
                    LED icon pack), GenTest.e (smoke test for the reader, writer and
                    generator, no MUI) and PenTest.e (shows TextEditor's pen colours)
examples/           example forms and the demo project (demo.mproj)
                    examples/delphe: DelphE described in itself (see GAPS.md)
scratch/            your own test files; git-ignores it, so it stays local
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
src/designer/designer [examples/sample.mform]
src/preview [examples/sample.mform]
```

With no argument, both open `examples/sample.mform`.

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
   component in the tree in the Object Inspector, then edit it just below: its
   name, title, layout properties, and (on the Events page) its handler.
   Names must start with a lowercase letter, and must be unique.
2. Click a component in the **palette** just above the tree to add it inside the
   selected group, or beside the selected component. The Form tab shows the
   result live. The tree has Delete, Up and Down for the selected component, and
   you can also drag an entry to a new place, including into another group.
   Moves the form cannot hold (for example, a second group next to the window's
   one group) are refused and the tree snaps back.
3. **Preview form** (Build menu) shows the form as it is right now.
4. **Build** (compile) and **Run** (toolbar or Build menu) first regenerate
   `<WindowName>.e` next to the `.mform` file, then build and start the program. What it prints (`WriteF`) appears in a
   console window of its own, which closes when the program ends.
   Select a component with a handler and click **Edit** to jump to its procedure.
   Build > **Generate code** regenerates without compiling.

### Projects

A project is a program with more than one form. **Project > New project...**
creates a `.mproj` file with a first form beside it; **Open project...** opens
one (or start the designer with `src/designer/designer examples/demo.mproj`). The
**form drop-down** at the top of the Object Inspector lists the forms: pick one
to edit it. The toolbar has New project and Open project, and the Project menu
has Remove form and Make main form. In a project, **New form** and **Open form**
add to the project, and **Save** writes every form and the project file.

Generating writes a single `<ProjectName>.e` with every form in it, and Build and
Run regenerate and build that program. The first form is the main form and opens at start;
closing it ends the program. Other forms open and close with `show()` and
`hide()`, which every handler can call on the form's global variable, named
`fm` plus the window name (`fmDemoSettings.show()`).

Keep the `DELPHE GENERATED CODE` line in `<Name>.e`: the generated file is inserted there
when you compile. Everything else in that file is yours and is never rewritten. Files
from older versions (generated code inside them) are converted on first generate, with
the old one kept as `.bak`.

## Credits

The toolbar icons come from the LED icons pack by [led24.de](http://led24.de),
licensed under [CC BY-SA 3.0](http://creativecommons.org/licenses/by-sa/3.0/).
See `Images/ICONS.txt`.
