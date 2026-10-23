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

Because MUI objects are built from tag lists at runtime, the designer can
build the **real MUI objects** for its preview (with notifications off), so
the preview is the genuine article.

## Pipeline

1. `.mform` file  ->  form model (tree of `component`)
2. form model  ->  generated E unit (`Generator.e`); never hand-edited
3. user code lives in a separate file and holds the event handler procs
4. build = `ec` on the project, errors parsed and jumped to in the editor

Generated code, not runtime reflection: E has no reflection, and generated
source keeps the compiled program independent of the IDE.

## Generated unit shape

```e
OBJECT MainForm
  handle
  lblName
  edtName
  btnOk
  btnCancel
ENDOBJECT

PROC create() OF MainForm
  self.lblName := TextObject, TextFrame, MUIA_Text_Contents, 'Name:', End
  ...
  self.handle := WindowObject, ... End
ENDPROC
```

Leaf widgets are created first so they can be named, then groups and the
window are assembled around them.

## .mform format (proposed, parser not written yet)

Indented text, one component per line: `Kind name "title"`, children indented.

```
Window MainForm "Hello DelphE"
  VGroup root
    Text lblName "Name:"
    String edtName ""
    HGroup row
      Button btnOk "OK"
      Button btnCancel "Cancel"
```

## Roadmap

1. Form model + generator (done in draft; untested on an Amiga)
2. `.mform` reader/writer
3. Live preview: form model -> real MUI objects
4. Designer UI: component palette, tree view, property inspector
5. Event bindings -> handler stubs in the user's file
6. Code editor (TextEditor.mcc), build/run, compiler error jump
7. Project files, undo, more components

## Open questions

- Which MUI E modules / headers to build on (stock EC lacks them)
- Which third-party MCCs are acceptable (TextEditor, NList, Listtree)
- Target: AmigaOS 3.x / MUI 3.8 assumed
