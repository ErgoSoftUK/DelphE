# DelphE showcase: Amiga Mixer

A small mixer with VU meters, built with DelphE. It is meant for screenshots and as a tour of what
DelphE can do.

Open `Mixer.mform` in the designer (`src/designer/designer examples/showcase/Mixer.mform`), then
Build and Run (Right-Amiga+B, Right-Amiga+R).

## What is in it

| Feature | Where |
|---|---|
| A frame (`ChannelStrip.mframe`: VU gauge, volume slider, mute) used four times | the Mixer tab; `ch1` to `ch4` in the tree |
| Vertical sliders and gauges | the channel strips |
| Pages (tabs), column groups, a radio group, cycles, a memo | the Equaliser and Output tabs |
| A menu strip with shortcuts, a separator and a checkmark item | Project, Mixer and Help menus |
| Window properties: ID, size, centred | the Mixer window |
| OnClose, with a message dialog that can cancel the close | closing the window |
| A timer driving the meters | `tmrMeters`, every 120 ms |
| File dialogs and message dialogs | Load and Save preset, About |
| The code behind it, in three parts | the Code tab: modules, globals, code |

## Screenshot ideas

1. **The designer, whole window:** `Mixer.mform` open, the Mixer tab showing, the Properties page of a
   component selected (try `sldVol` in `ChannelStrip.mframe`, or the window itself for its ID).
2. **The component palette:** the Layout, Input, Display and Utility tabs.
3. **The tree:** expanded, showing the frames, the Utilities branch and the menu strip.
4. **The Code tab:** modules, globals and code with syntax colours; a handler such as `vuLevel`.
5. **The running program:** the Mixer tab with the meters moving, and a muted channel greyed out.
6. **The menus open:** Project and Mixer menus, and the About requester.
7. **The frame being edited:** `ChannelStrip.mframe` in the designer next to the form that uses it.
