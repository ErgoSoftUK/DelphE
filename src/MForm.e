/*
** DelphE .mform reader and writer
**
** One component per line, two spaces of indent per nesting level:
**
**   Kind name "title"
**
** The title is optional (groups don't need one). See docs/DESIGN.md.
*/

OPT MODULE
OPT EXPORT

MODULE 'dos/dos', '*FormModel'

CONST MAXDEPTH = 16

PROC put(fh, s) IS Write(fh, s, StrLen(s))

/*** writer ***/

PROC writeForm(fh, c: PTR TO component, depth)
  DEF i, ch: PTR TO component
  FOR i := 1 TO depth DO put(fh, '  ')
  put(fh, kindName(c.kind))
  put(fh, ' ')
  put(fh, c.name)
  IF c.title
    put(fh, ' \q')
    put(fh, c.title)
    put(fh, '\q')
  ENDIF
  IF c.handler
    IF eventName(c.kind)
      put(fh, ' @')
      put(fh, eventName(c.kind))
      put(fh, '=')
      put(fh, c.handler)
    ENDIF
  ENDIF
  put(fh, '\n')
  ch := c.firstChild
  WHILE ch
    writeForm(fh, ch, depth + 1)
    ch := ch.next
  ENDWHILE
ENDPROC

/*** reader ***/

-> Returns the next token (a new E-string, or NIL at end of line) and the
-> position after it. A token in double quotes may contain spaces.
PROC nextToken(line, pos)
  DEF len, start, tok
  len := StrLen(line)
  WHILE (pos < len) AND (line[pos] = " ") DO pos++
  IF pos >= len THEN RETURN NIL, pos, FALSE

  IF line[pos] = 34
    pos++
    start := pos
    WHILE (pos < len) AND (line[pos] <> 34) DO pos++
    tok := String(pos - start + 1)
    -> MidStr treats a length of 0 as "the rest of the string"
    IF pos > start THEN MidStr(tok, line, start, pos - start)
    IF pos < len THEN pos++
    RETURN tok, pos, TRUE
  ENDIF

  start := pos
  WHILE (pos < len) AND (line[pos] <> " ") DO pos++
  tok := String(pos - start + 1)
  MidStr(tok, line, start, pos - start)
ENDPROC tok, pos, FALSE

-> "@OnClick=handler" -> a copy of "handler", or NIL
PROC eventHandler(tok)
  DEF eq, n, h
  eq := InStr(tok, '=')
  IF eq < 0 THEN RETURN NIL
  n := StrLen(tok) - eq - 1
  IF n < 1 THEN RETURN NIL
  h := String(n + 1)
  MidStr(h, tok, eq + 1, n)
ENDPROC h

-> Reads a form; returns the window component, or NIL on error.
PROC readForm(filename)
  DEF fh, line, lineNo, pos, level, kindTok, nameTok, titleTok, kind, i
  DEF handlerTok, tok, quoted
  DEF c: PTR TO component, win: PTR TO component, parent: PTR TO component
  DEF stack[MAXDEPTH]: ARRAY OF LONG

  lineNo := 0
  win := NIL
  FOR i := 0 TO MAXDEPTH - 1 DO stack[i] := NIL

  fh := Open(filename, MODE_OLDFILE)
  IF fh = NIL
    WriteF('Cannot open \s\n', filename)
    RETURN NIL
  ENDIF

  line := String(255)
  WHILE (ReadStr(fh, line) <> -1) OR (StrLen(line) > 0)
    lineNo++
    kindTok, pos := nextToken(line, 0)

    IF kindTok
      -> indentation is the position of the first token
      pos := 0
      WHILE (pos < StrLen(line)) AND (line[pos] = " ") DO pos++
      level := Div(pos, 2)
      kindTok, pos := nextToken(line, pos)
      nameTok, pos := nextToken(line, pos)

      -> the rest: a quoted title and/or an unquoted @Event=handler
      titleTok := NIL
      handlerTok := NIL
      REPEAT
        tok, pos, quoted := nextToken(line, pos)
        IF tok
          IF quoted
            titleTok := tok
          ELSEIF tok[0] = "@"
            handlerTok := eventHandler(tok)
          ELSEIF titleTok = NIL
            titleTok := tok
          ENDIF
        ENDIF
      UNTIL tok = NIL

      kind := kindFromName(kindTok)
      IF kind = -1
        WriteF('\s line \d: unknown component kind "\s"\n', filename, lineNo, kindTok)
        Close(fh)
        RETURN NIL
      ENDIF
      IF nameTok = NIL
        WriteF('\s line \d: component has no name\n', filename, lineNo)
        Close(fh)
        RETURN NIL
      ENDIF
      -> E treats capitalised identifiers as constants; windows get a t prefix
      IF (kind <> CK_WINDOW) AND ((nameTok[0] < "a") OR (nameTok[0] > "z"))
        WriteF('\s line \d: name "\s" must start with a lowercase letter\n', filename, lineNo, nameTok)
        Close(fh)
        RETURN NIL
      ENDIF
      IF level >= MAXDEPTH
        WriteF('\s line \d: nested too deeply\n', filename, lineNo)
        Close(fh)
        RETURN NIL
      ENDIF

      c := newComponent(kind, nameTok, titleTok)
      c.handler := handlerTok
      IF level = 0
        IF kind <> CK_WINDOW
          WriteF('\s line \d: the first component must be a Window\n', filename, lineNo)
          Close(fh)
          RETURN NIL
        ENDIF
        win := c
      ELSE
        IF stack[level - 1] = NIL
          WriteF('\s line \d: bad indentation\n', filename, lineNo)
          Close(fh)
          RETURN NIL
        ENDIF
        parent := stack[level - 1]
        parent.addChild(c)
      ENDIF
      stack[level] := c
    ENDIF
  ENDWHILE

  Close(fh)
ENDPROC win
