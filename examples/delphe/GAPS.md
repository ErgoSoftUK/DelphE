# DelphE describing itself: what is missing

This project models DelphE's own windows with DelphE's components. Where something
could not be said, the form has a placeholder starting with `[needs ...]`. The list
below is what DelphE would have to learn before these forms could replace the
hand-written windows in `src/designer/Designer.e`.

| Gap | Where it shows | Notes |
|-----|----------------|-------|
| Menu strip | done | `main.mform` now has the Project, Edit, Build and View menus, as MenuStrip, Menu and MenuItem components |
| Toolbar.mcc | action toolbar, the four palette tabs | needs an image-strip property and a button list |
| Listtree.mcc | component tree | plus drag and drop, which is a custom class |
| Balance bar | between inspector and editor, and inside the inspector | easy: a MUI built-in |
| Vertical slider | preview height slider | a slider orientation property |
| Window properties | all forms | window ID, size, centred position, open at start |
| Label component | `Text lblX` rows | a frameless, right-aligned label; Label2() and an alignment property |
| Text alignment | `txtEvent` | `\er` pre-parse, `MUIA_FixWidthTxt` |
| Editor options | memo components | fixed font, plain export, read-only |
| Preview host | form tab | a group the program fills at run time (a "placeholder" component) |
| Run-time lists | form drop-down, the Cycle's entries change at run time | an API, not a designer feature: just generated fields |
| Group spacing | memo with its scrollbar | covered inside the Memo component |
| Components the code needs by name | `cycForms`, `sldW` ... | work today; events and properties are enough |

Frames are now supported: `properties.mframe` and `events.mframe` are used by `main.mform`
instead of the placeholders that used to stand in for them.

What does work: the Entries dialog, the Properties page and the Events page can be
described completely (labels, strings, a cycle, checkmarks with spacers, buttons, a
memo); `main.mform` is the best approximation of the main window with what exists.
