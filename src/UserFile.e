/*
** DelphE user file sections.
**
** The program file a user edits has three parts, which the Code tab shows in three
** editors:
**
**   modules      the header comment, OPT and MODULE lines
**   ->>> DELPHE GLOBALS ...
**   globals      DEF, CONST and OBJECT: everything global, which E wants before any PROC
**   ->>> DELPHE GENERATED CODE ...
**   code         your procedures and main()
**
** The file stays one plain E file; these procedures cut it into the parts and put the
** parts back together. Files from before the globals marker are split by guessing:
** everything up to the last MODULE statement is modules, the rest above the generated
** code is globals.
*/

OPT MODULE
OPT EXPORT

MODULE 'exec/memory', '*Generator'

OBJECT sections
  modText: PTR TO CHAR      -> each text is zero-terminated memory: free with freeSections()
  modLen
  globText: PTR TO CHAR
  globLen
  codeText: PTR TO CHAR
  codeLen
  hasMarker                 -> does the file have the DELPHE GENERATED CODE line?
  globStart                 -> line of the file where the globals text starts (0 = the first)
  codeStart                 -> line of the file where the code text starts
ENDOBJECT

-> A copy of buf from index a up to (not including) b, as zero-terminated memory
PROC copyRegion(buf: PTR TO CHAR, a, b)
  DEF out: PTR TO CHAR, n
  n := b - a
  IF n < 0 THEN n := 0
  out := AllocVec(n + 2, MEMF_PUBLIC OR MEMF_CLEAR)
  IF out = NIL THEN RETURN NIL
  IF n > 0 THEN CopyMem(buf + a, out, n)
  out[n] := 0
ENDPROC out

-> The index where the line holding index p starts
PROC lineStartOf(buf: PTR TO CHAR, p)
  WHILE (p > 0) AND (buf[p - 1] <> 10) DO p--
ENDPROC p

-> The index just after the end of the line holding p, or len
PROC afterLine(buf: PTR TO CHAR, p, len)
  WHILE (p < len) AND (buf[p] <> 10) DO p++
  IF p < len THEN p++
ENDPROC p

-> How many lines come before index p
PROC linesBefore(buf: PTR TO CHAR, p)
  DEF i, n
  n := 0
  FOR i := 0 TO p - 1
    IF buf[i] = 10 THEN n++
  ENDFOR
ENDPROC n

-> Does the line starting at a (and ending before b) start with the word MODULE?
PROC isModuleLine(buf: PTR TO CHAR, a, b)
  IF (b - a) < 6 THEN RETURN FALSE
ENDPROC StrCmp(buf + a, 'MODULE', 6)

-> Does the line from a to b end in a comma (ignoring spaces and CR)? A MODULE statement
-> continues on the next line then.
PROC endsInComma(buf: PTR TO CHAR, a, b)
  DEF p
  p := b - 1
  WHILE (p >= a) AND ((buf[p] = 10) OR (buf[p] = 13) OR (buf[p] = " ") OR (buf[p] = 9)) DO p--
  IF p < a THEN RETURN FALSE
ENDPROC buf[p] = ","

-> Cuts the file text into its three parts
PROC splitSections(buf: PTR TO CHAR, len)
  DEF s: PTR TO sections, m, mStart, afterM, g, gStart, gAfter, pos, modEnd, cont, le, e
  NEW s
  m := InStr(buf, userMark())
  IF m = -1
    -> not a DelphE file: all of it is code
    s.hasMarker := FALSE
    s.codeText := copyRegion(buf, 0, len)
    s.codeLen := len
    s.modText := copyRegion(buf, 0, 0)
    s.globText := copyRegion(buf, 0, 0)
    RETURN s
  ENDIF
  s.hasMarker := TRUE
  mStart := lineStartOf(buf, m)
  afterM := afterLine(buf, m, len)

  g := InStr(buf, globalsMark())
  IF (g <> -1) AND (g < mStart)
    gStart := lineStartOf(buf, g)
    gAfter := afterLine(buf, g, len)
    s.modText := copyRegion(buf, 0, gStart)
    s.modLen := gStart
    s.globText := copyRegion(buf, gAfter, mStart)
    s.globLen := mStart - gAfter
    s.globStart := linesBefore(buf, gAfter)
  ELSE
    -> no globals line yet: the modules end with the last MODULE statement
    pos := 0
    modEnd := 0
    cont := FALSE
    WHILE pos < mStart
      e := afterLine(buf, pos, len)
      IF e > mStart THEN e := mStart
      le := e
      IF cont OR isModuleLine(buf, pos, le)
        modEnd := e
        cont := endsInComma(buf, pos, le)
      ELSE
        cont := FALSE
      ENDIF
      pos := e
    ENDWHILE
    IF modEnd = 0 THEN modEnd := mStart
    -> blank lines between the parts belong to neither
    pos := modEnd
    WHILE (pos < mStart) AND (buf[pos] = 10) DO pos++
    s.modText := copyRegion(buf, 0, modEnd)
    s.modLen := modEnd
    s.globText := copyRegion(buf, pos, mStart)
    s.globLen := mStart - pos
    s.globStart := linesBefore(buf, pos)
  ENDIF
  s.codeText := copyRegion(buf, afterM, len)
  s.codeLen := len - afterM
  s.codeStart := linesBefore(buf, afterM)
ENDPROC s

PROC freeSections(s: PTR TO sections)
  IF s.modText THEN FreeVec(s.modText)
  IF s.globText THEN FreeVec(s.globText)
  IF s.codeText THEN FreeVec(s.codeText)
  END s
ENDPROC

-> Writes text into out at o; returns the new offset. Adds a newline if the text does not
-> end in one.
PROC putSection(out: PTR TO CHAR, o, text: PTR TO CHAR)
  DEF n
  n := StrLen(text)
  IF n > 0
    CopyMem(text, out + o, n)
    o := o + n
    IF out[o - 1] <> 10
      out[o] := 10
      o++
    ENDIF
  ENDIF
ENDPROC o

-> Puts the three parts back together, with the marker lines between them. Returns the
-> text (free it with FreeVec) and its length.
PROC joinSections(modText: PTR TO CHAR, globText: PTR TO CHAR, codeText: PTR TO CHAR)
  DEF out: PTR TO CHAR, o, gm, um, n
  gm := globalsMarkLine()
  um := userMarkLine()
  n := StrLen(modText) + StrLen(globText) + StrLen(codeText) + StrLen(gm) + StrLen(um) + 8
  out := AllocVec(n, MEMF_PUBLIC OR MEMF_CLEAR)
  IF out = NIL THEN RETURN NIL, 0
  o := 0
  o := putSection(out, o, modText)
  o := putSection(out, o, gm)
  o := putSection(out, o, globText)
  o := putSection(out, o, um)
  -> the code is written as it is: it starts with the line after the marker
  n := StrLen(codeText)
  IF n > 0
    CopyMem(codeText, out + o, n)
    o := o + n
  ENDIF
  out[o] := 0
ENDPROC out, o
