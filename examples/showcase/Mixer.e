/*
** Mixer
**
** The DelphE showcase: a small mixer with VU meters. The form is in Mixer.mform and
** ChannelStrip.mframe (one strip, used four times); this file is the code behind it.
*/

OPT PREPROCESS
OPT LARGE

MODULE 'muimaster', 'libraries/mui', 'utility/tagitem',
       'amigalib/boopsi'

->>> DELPHE GLOBALS (your global variables, constants and object types: they must come before the generated code)
DEF statusBuf

->>> DELPHE GENERATED CODE (the .gen.e file is inserted here when you compile: do not edit this line)

/*** your code ***/

-> Shows a message in the status line. The text gadget keeps the pointer, so the buffer is
-> a global.
PROC say(msg) OF tMixer
  IF statusBuf = NIL THEN statusBuf := String(240)
  StrCopy(statusBuf, msg, ALL)
  set(self.txtStatus, MUIA_Text_Contents, statusBuf)
ENDPROC

PROC sayPath(prefix, path) OF tMixer
  IF statusBuf = NIL THEN statusBuf := String(240)
  StringF(statusBuf, '\s\s', prefix, path)
  set(self.txtStatus, MUIA_Text_Contents, statusBuf)
ENDPROC

-> Closing the window asks first; setting keepOpen stops it closing
PROC windowClose() OF tMixer
  IF self.mdlgQuit.execute() = 2 THEN self.keepOpen := TRUE
ENDPROC

PROC eq(bass, mid, treble) OF tMixer
  set(self.sldBass, MUIA_Numeric_Value, bass)
  set(self.sldMid, MUIA_Numeric_Value, mid)
  set(self.sldTreble, MUIA_Numeric_Value, treble)
ENDPROC

PROC cycPresetChange() OF tMixer
  DEF p
  get(self.cycPreset, MUIA_Cycle_Active, {p})
  SELECT p
    CASE 0
      self.eq(0, 0, 0)
    CASE 1
      self.eq(6, -2, 5)
    CASE 2
      self.eq(3, 2, 4)
    CASE 3
      self.eq(-2, 1, 3)
  ENDSELECT
ENDPROC

PROC mniLoadSelect() OF tMixer
  IF self.fdlgPreset.execute() THEN self.sayPath('Loaded ', self.fdlgPreset.path)
ENDPROC

PROC mniSaveSelect() OF tMixer
  IF self.fdlgSave.execute() THEN self.sayPath('Saved ', self.fdlgSave.path)
ENDPROC

PROC mniQuitSelect() OF tMixer
  self.keepOpen := FALSE
  self.windowClose()
  IF self.keepOpen = FALSE THEN self.closeWindow()
ENDPROC

PROC mniResetSelect() OF tMixer
  set(self.ch1.sldVol, MUIA_Numeric_Value, 70)
  set(self.ch2.sldVol, MUIA_Numeric_Value, 70)
  set(self.ch3.sldVol, MUIA_Numeric_Value, 70)
  set(self.ch4.sldVol, MUIA_Numeric_Value, 70)
  self.say('Levels reset')
ENDPROC

-> Ticking the menu item mutes (or unmutes) every channel: the strips' own handlers
-> then disable their sliders
PROC mniMuteAllSelect() OF tMixer
  DEF m
  get(self.mniMuteAll, MUIA_Menuitem_Checked, {m})
  set(self.ch1.chkMute, MUIA_Selected, m)
  set(self.ch2.chkMute, MUIA_Selected, m)
  set(self.ch3.chkMute, MUIA_Selected, m)
  set(self.ch4.chkMute, MUIA_Selected, m)
  IF m THEN self.say('All channels muted') ELSE self.say('Channels on')
ENDPROC

PROC mniAboutSelect() OF tMixer
  self.mdlgAbout.execute()
ENDPROC

-> One VU meter: a random level scaled by the volume and smoothed, silent when muted
PROC vuLevel(ch: PTR TO tChannelStrip)
  DEF vol, muted, cur, target, lvl
  get(ch.sldVol, MUIA_Numeric_Value, {vol})
  get(ch.chkMute, MUIA_Selected, {muted})
  get(ch.gauLevel, MUIA_Gauge_Current, {cur})
  IF muted THEN target := 0 ELSE target := Div(Mul(Rnd(100), vol), 100)
  lvl := Div(Mul(cur, 2) + target, 3)
  set(ch.gauLevel, MUIA_Gauge_Current, lvl)
ENDPROC lvl

PROC tmrMetersTimer() OF tMixer
  DEF total
  total := vuLevel(self.ch1) + vuLevel(self.ch2) + vuLevel(self.ch3) + vuLevel(self.ch4)
  set(self.gauMaster, MUIA_Gauge_Current, Div(total, 4))
ENDPROC

-> The strip's own handler: muting greys out its volume slider
PROC chkMuteChange() OF tChannelStrip
  DEF m
  get(self.chkMute, MUIA_Selected, {m})
  set(self.sldVol, MUIA_Disabled, m)
ENDPROC

PROC main()
  delpheRun()
ENDPROC
