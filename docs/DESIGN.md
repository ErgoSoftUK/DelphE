# DelphE design

## Goal

A Delphi-inspired IDE for Amiga E: design a form visually, wire events to
procedures, edit code, build and run, all inside one MUI application.

## Core idea

MUI lays out with groups and weights, not x/y coordinates, so the designer
edits a **component tree**, not a canvas of positioned controls.

```
Window
  VGroup
    Text   lblName
    String edtName
    HGroup
      Button btnOk
      Button btnCancel
```

Because MUI objects are built from tag lists at runtime, the designer builds
the **real MUI objects** for its preview, so the preview is the genuine article.

## Pipeline

```
 .mform file --MForm--> component tree --Builder--> live MUI objects (preview)
                              |
                              +--Generator--> <Window>.e --ec--> program
```

1. `MForm.e` reads and writes `.mform` files.
2. `FormModel.e` holds the tree: a `component` object with kind, name, title,
   handler, properties and child/sibling links.
3. `Builder.e` creates MUI objects from the tree at runtime.
4. `Generator.e` writes E source for the same tree.
5. The designer edits the tree and drives all of the above.

Generated code, not runtime reflection: E has no reflection, and generated
source keeps the compiled program independent of the IDE.

## Components

| Kind    | Title means                 | Event           | Notes                          |
|---------|-----------------------------|-----------------|--------------------------------|
| Window  | window title                |                 | one root group; no properties  |
| VGroup  | frame title (if framed)     |                 | container                      |
| HGroup  | frame title (if framed)     |                 | container                      |
| Button  | label                       | `OnClick`       |                                |
| Text    | text                        |                 |                                |
| String  | initial contents            | `OnEnter`       | fires on Return                |
| Check   | (none)                      | `OnChange`      |                                |
| Cycle   | entries, separated by `\|`  | `OnChange`      |                                |
| Radio   | entries, separated by `\|`  | `OnChange`      |                                |
| Slider  | (none)                      | `OnChange`      | min / max / value              |
| Gauge   | (none)                      |                 | max / value                    |
| List    | entries, separated by `\|`  | `OnDoubleClick` | static entries                 |
| Pages   | tab titles, separated by `\|` |               | container: each child is a page |
| Spacer  | (none)                      |                 | empty space; give it a weight or size |
| ColGroup | (none)                     |                 | container; Value = number of columns |
| Scroll  | (none)                      |                 | container: its children scroll in a virtual group |
| Memo    | initial text                |                 | TextEditor.mcc with its scrollbar; needs that class |
| Utilities | (none)                    |                 | the window's last child; holds the non-visual components below |
| FileDialog | requester title        |                 | non-visual; `:arg` = pattern, `:save` = save mode; `execute()` |
| MessageDialog | the message         |                 | non-visual; `:arg` = buttons separated by `|`; `execute()` gives the button number |

Optional properties (any component except the window): weight, fixed width,
fixed height, font, hint (bubble help) and disabled; groups also have a frame.
Properties left blank are simply not emitted, so MUI's defaults apply.

**Non-visual components.** The window's children are the form (its root group, always
first) and, once a non-visual component is added, a `Utilities` branch (always last).
`rootOf` and `utilitiesOf` in FormModel.e find them; the Builder and Generator use only
the root group. Utility kinds (`isUtilityKind`) may live only in that branch, and visual
kinds may not: `doAdd` places them, and `validDrop` refuses a drag that would break the
rule. The Utilities node itself cannot be moved, and has no properties. Utilities get a
field in the form object like any other leaf, typed as a small helper object (`tFileDialog`,
`tMessageDialog`) that the `.gen.e` carries itself, with its procedures, only if a form uses
them (`genRuntimeTypes` and `genRuntimeProcs`; in a project the procedures come after the
globals). They need no extra module. The `:arg` property holds a file dialog's pattern or a
message dialog's buttons.

**Frames.** A frame is a file like a form whose root is `Frame Name` (no window title or
settings) with one root group; `isRootKind` covers windows and frames. A `Use` component
(`:arg` = the frame file, relative to the program's folder) puts one inside a form or another
frame. The preview reads the file and builds the group inline (`buildUse`, folder set with
`setFrameBase`). `generateFile` and `generateProject` collect every frame a form uses
(`withFrames`, dependencies first, once each) and write, before the forms, an `OBJECT` and
`create`, `connect` and `handleEvent` for each, using the same code as for a window but with
the root group as the object (no `show` or `hide`). A use is a typed field; its instance gets
its own range of event ids (`idBase := self.idBase + 1000 * n`; forms of a project start at
100000, 200000, ...), `connect` and `handleEvent` of the parent pass on to it, and a plain
group around the frame's group carries the use's weight, size and so on. Handlers of a frame
are methods of its type and live in the user file, with stubs appended as for forms. A frame
cannot be generated alone; it comes with the forms that use it.

A component can need a MUI class beyond MUI itself (`kindClass` in FormModel.e; today only
Memo, with `TextEditor.mcc`). The designer checks whether the class file is in `MUI:Libs/MUI/`
or `LIBS:MUI/` (`classInstalled` in Util.e) and greys out the palette button if not. The
live preview shows a note in place of a missing Memo. Generated programs get the editor's
tag values as `CONST`s instead of importing a module. The check only covers the machine
running DelphE, not the one the program runs on.
## The .mform format

Indented text, one component per line, two spaces per nesting level:

```
Kind name "title" @Event=handler :property :property=value
```

```
Window MainForm "Hello DelphE"
  VGroup root :frame :weight=50
    Text lblName "Name:" :hint="Your name"
    String edtName ""
    HGroup row
      Button btnOk "OK" @OnClick=btnOkClick :weight=0
      Button btnCancel "Cancel" :disabled
    Slider sldLevel :min=-5 :max=20 :value=7 @OnChange=sldLevelChange
```

- The title is quoted and optional. Everything after it is unquoted.
- `@OnClick=handler` binds the kind's event to a procedure name.
- Properties: `:weight=N`, `:fixw=N`, `:fixh=N`, `:min=N`, `:max=N`,
  `:value=N`, `:font=name` (normal, tiny, big, title, fixed, list or button),
  `:hint="text"`, `:disabled`, `:frame`.
- Names must start with a lowercase letter (E treats capitalised identifiers as
  constants). Window names are exempt because the generator prefixes `t`.

## Generated file

Each form generates two files: the generated code, `<WindowName>.gen.e`, and the
program the user edits, `<WindowName>.e`. The generated file is never edited and
is kept out of version control.

```e
/* <WindowName>.e: header, OPT PREPROCESS, MODULE list ...        (yours)  */

->>> DELPHE GENERATED CODE (the .gen.e file is inserted here when you compile ...)

PROC btnOkClick() OF tMainForm                                    (yours)
  -> TODO: handle OnClick of btnOk (components are fields of self, e.g. self.btnOk)
ENDPROC

PROC main() ...                                                   (yours)
```

```e
-> <WindowName>.gen.e                                        (rewritten each time)
OBJECT tMainForm                              -> one field per component
  handle
  btnOk
  ...
ENDOBJECT

PROC create() OF tMainForm   -> build the MUI objects, window last
PROC connect(app) OF tMainForm   -> MUIM_Notify -> ReturnID per bound event
PROC handleEvent(id) OF tMainForm   -> SELECT id, call the handler methods
```

- **Why no INCLUDE:** Amiga E has no source include, only precompiled modules,
  and generated code that calls the user's handlers cannot be a module. So
  `buildSource` writes the program that `ec` compiles: the user's file with the
  `.gen.e` text inserted after the marker line. That file goes to
  `RAM:delphe-build/`, and the executable is copied next to the source after a
  successful compile.
- Compiler errors are traced back: `buildSource` returns the first inserted line
  and the number of inserted lines, so a line after the insertion is shown
  minus that count, and a line inside it is reported as being in the generated
  code. Local `.m` modules next to the source are not found, because `ec` runs
  in the work drawer.
- Handlers are **methods of the form object**, so they can use
  `self.edtName` and friends. E's methods are statically bound, which is why the
  handlers are in the same program as the object instead of a subclass.
- Generating only appends a stub for any handler the user's file does not define
  yet; the rest of that file is never rewritten. A file with neither the marker
  line nor old-style markers is refused, not overwritten.
- **Old-style files** (generated code between `->>> DELPHE BEGIN` / `END`
  markers) are converted the first time they are generated: the marked regions
  are removed, the marker line takes the place of the first, and the old file is
  kept as `<file>.bak`.
- Event numbers are assigned in tree order; `connect` and `handleEvent` walk the
  tree the same way so they always agree.

## The designer

One window, in the style of Delphi 3. MUI keeps its position and size.

- **Actions toolbar**, across the top: new and open project, new and open form,
  save, remove form, preview, generate, compile, run. It and the component palette
  are `Toolbar.mcc` with the strips in `Images/` (built by `tools/make-icons.ps1`).
- **Object Inspector**, docked at the left, top to bottom:
  - a drop-down of the project's forms (a Cycle gadget, rebuilt when the list
    changes, because a Cycle's entries are fixed when it is made) and the kind of
    the selected component;
  - the **component palette**, which belongs here because it only ever acts on
    the selection in the tree below it: clicking a button adds that kind to the
    selected group (or beside the selected component). It is split into
    three tabs (Layout, Input, Display) of short toolbars, because a Toolbar
    never wraps: one long row would fix the inspector's minimum width and make
    the splitter useless. `palKinds1..3` list the kinds on each tab in button
    order; a button's ID is `ID_PALETTE + kind - 1`;
  - the **component tree** (`Listtree.mcc`) with Delete / Up / Down, so the tree
    sits right beside the form selector;
  - a Balance bar, so you can trade height between the tree and the properties;
  - a Properties page (name, title or entries, with a `...` button that opens the
    entries dialog: a small window with a text editor, one entry per line, that
    turns the lines into the `One|Two|Three` the model stores; weight, fixed size, min/max/value,
    hint, disabled, frame) and an Events page (the handler, with New and Edit).

  The tree also takes **drag and drop**. It is a small subclass of
  `Listtree.mcc` (`treeDispatcher`, created with `eMui_CreateCustomClass`) that
  lets the Listtree do the moving and then posts a return ID. `onTreeDrop` checks
  the new arrangement (one window at the top, holding one group), then either
  takes an undo snapshot and rebuilds the model's child links from the tree, or
  rebuilds the tree from the model to undo the move. The tree uses
  `MUIV_Listtree_SortHook_Tail`, so a drop onto a closed group appends rather
  than sorting alphabetically. Each drop is one undo step.

  Leaf-onto-leaf exchange (a Listtree feature) did not work reliably here, and
  an attempt to do the drop ourselves with `MUIM_Listtree_TestPos` picked the
  wrong target, so both were dropped. Use Up / Down or drag onto a group.
- **Form and Code tabs**, filling the rest. **Form** is the **live form**: the
  real MUI objects, rebuilt after each change, in a framed box whose width and
  height are set by two sliders, as a percentage of the area (0% is the smallest
  the form can be, 100% fills it): width along the top, height docked at the left.
  The sliders show no number, only the knob. The box is placed with weights and
  the empty space beside and below it takes the rest. A weight is fixed when an
  object is made, so each slider move replaces the area and rebuilds the form in
  it. MUI has no free
  positioning to drag, so components are selected in the tree, not by clicking
  them in the live form. **Code** is `TextEditor.mcc` showing your program file (the generated code is not in it), the
  file name above it, and a read-only pane for compiler output. Save, Build and
  Run live in the toolbar and menus. Edit,
  a compile error and the View menu's Code tab item all switch to the Code tab.
- A Balance bar sits between the inspector and the tabs, and the View menu can
  hide the inspector altogether. There is one window, so one menu bar and one
  set of tooltips: with several windows, an Amiga menu bar and MUI's bubble help
  only follow the active window.
- **Menus:** Project (New project, Open project, New form, Open form, Remove
  form, Make main form, Save, Save As, Quit), Edit (Undo, Redo, Delete,
  Move up, Move down), Build (Preview, Generate, Build, Run) and View (Form tab,
  Code tab, Show/hide object inspector).
- Edits commit when you press Return, change the selection, or Save, Preview,
  Generate, Build or Run. Build and Run regenerate first; Generate has no
  toolbar button. Checkmarks and titles apply immediately.
- A `*` in the window title marks unsaved changes; New, Open and Quit ask first.
- **Undo / redo** keeps whole-form snapshots: just before each change the
  form is deep-copied (`cloneTree`) onto an undo stack of up to 40, together
  with the position of the selected component so it can be selected again.
  Undo moves the live form onto the redo stack and restores the snapshot; any
  new change clears redo. A run of edits to the same title is one step.
  Strings are shared between copies, which is safe because they are replaced,
  never edited in place. Opening a form clears both stacks.
- Build runs `ec <program> IGNORECACHE` on the combined source in `RAM:delphe-build`, reads
  the output, copies the program next to the source and, on an error, jumps to its line.
- Menu shortcuts take precedence over the code editor's own keys: Build is Right-Amiga+B
  so that C (copy) stays with the editor. Undo and Redo
  are context-sensitive: on the Code tab they send UNDO and REDO to the editor
  (`MUIM_TextEditor_ARexxCmd`), elsewhere they act on the form; the menu items
  are always enabled.

### How Designer.e is organised

`Designer.e` is one program with shared state: the windows and gadgets, the form
being edited and the project are global variables, because E modules can only
share globals through matching `EXPORT DEF`s in every module, and a missed one
silently becomes a private copy. So the file is kept in sections instead, each
introduced by a `/*** ... ***/` comment:

- the tree and inspector (`addTree`, `onSelect`, `commitName`, `commitProps`, ...)
- files, undo and redo, drag and drop, projects, compile and run
- building the program: `makeTree`, `makeEditors`, `makeToolbars`,
  the panels (`makeInspectorPanel`, `makeEditorPanel`) and `makeMainWindow`, `makeApplication`, `connectEvents`, `openWindows`
- the loop: `handleId` (one return ID) and `mainLoop`; `main` just calls these
  in order and cleans up

Anything that needs no global state lives in a module instead: string and file
helpers in `Util.e` (`validIdent`, `isNumber`, `cleanOutput`, `imagePath`, path
functions, the file requester), and model queries in `FormModel.e` (`nameTaken`,
`cloneTree`, `indexInTree`, ...).

## Projects

A **project** (`.mproj`, read and written by `Project.e`) is a program with
several forms:

```
Project "Demo"
Form "demo_main.mform"
Form "demo_settings.mform"
```

Form paths are relative to the project file. The first is the main form.

**One program, all the forms.** `generateProject` writes a single
`<ProjectName>.gen.e`, because E modules cannot import each other and a handler
of one form must be able to reach another (`fmDemoSettings.show()`). In order:

1. `type <Form>`: the `OBJECT` of each form
2. `globals`: `DEF delpheApp, fmA: PTR TO tA, ...` (a global `DEF` must come
   before any procedure, and after the `OBJECT` it uses)
3. `form <Form>`: `create`, `connect`, `handleEvent`, `show`, `hide` of each form
4. `project`: `delpheRun()`, which creates every form, builds the application
   with all the windows, connects them, shows the main form and runs the loop

`<ProjectName>.e` holds the marker line (where all of that goes), then the user's
code, ending with `main()`, which calls `delpheRun()`.

**Event numbers** are relative to a per-form `idBase` (1000, 2000, ...), so
several forms can share the one main loop: every form's `handleEvent` is called
with each id and only reacts to its own range.

**In the designer** one form is edited at a time and the project keeps all the
forms in memory (`projForms`, `projPaths`). The form drop-down in the Object Inspector lists them. Save
writes every form and the project file. Undo history is per form: it is cleared
when you switch.
A project holds at most 16 forms.

## Building and testing

`Build` compiles everything and runs `GenTest`, which reads `examples/sample.mform`,
writes it back through the writer, and creates `tools/MainForm.e` and its `.gen.e`; the
program `ec` then compiles (`MainFormBuilt`) is put together by `buildSource`, as for a real
compile.
`Watch` lets a host machine trigger builds by creating a file; see the README.

## E and MUI gotchas found along the way

These cost time, so they are written down.

- Capitalised identifiers are constants. Object types and component names must
  start lowercase (the generator uses `tMainForm`).
- `SELECT` needs a plain variable, not `c.kind`.
- `StringF` swallowed the `()` in a format string; build such text with `StrAdd`.
- `MidStr` with a length of 0 means "the rest of the string".
- A `Listtree` with `MUIV_Listtree_ConstructHook_String` copies the *user data*
  as a string. Store component pointers without hooks.
- `MUIA_Window_ID` and similar IDs are four-character constants (`"MAIN"`), not
  strings.
- A `*` module path is relative to the source file's folder, so the designer
  imports `*/FormModel` from `src/designer/`.
- A big program needs `OPT LARGE` (`reference(s) out of 32k range`).
- `PathPart()` points at the final `/`, not after it.
- `SimpleButton()` and `CheckMark()` take no extra tags, so buttons with
  properties are written out in full.
- Bubble help works but is slow by default: lower the delay in MUI Settings.
- Arithmetic such as `100 - p` inside a tag list (`[... MUIA_Weight, 100 - p ...]`
  or the `Child, ... End` macros) is a syntax error: work it out into a variable
  first.
- A Toolbar never wraps, and its width sets the minimum width of whatever holds it.

## Roadmap

Done: form model, `.mform` reader/writer, live preview, generator, designer,
events, code editor with build and run, properties, more component kinds,
menus, file handling.

Ideas, roughly in order of value:

- Projects: several forms sharing one `main()`.
- More properties (fonts, colours) and components (pages, menus, string lists).
- A debugger front end (`edbg`).

## Dependencies on the Amiga side

- Amiga E v3.3a and the MUI E modules (see the README).
- `TextEditor.mcc` and `Listtree.mcc`; the E modules for them are in `src/mcc/`.
- Target: AmigaOS 3.x with MUI 3.8.
