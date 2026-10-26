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

PROC mput(fh, s) IS Write(fh, s, StrLen(s))

/*** writer ***/

PROC mputProp(fh, prefix, n)
  DEF s
  mput(fh, prefix)
  s := String(16)
  StringF(s, '\d', n)
  mput(fh, s)
  DisposeLink(s)
ENDPROC

PROC writeForm(fh, c: PTR TO component, depth)
  DEF i, ch: PTR TO component
  FOR i := 1 TO depth DO mput(fh, '  ')
  mput(fh, kindName(c.kind))
  mput(fh, ' ')
  mput(fh, c.name)
  IF c.title
    mput(fh, ' \q')
    mput(fh, c.title)
    mput(fh, '\q')
  ENDIF
  IF c.handler
    IF eventName(c.kind)
      mput(fh, ' @')
      mput(fh, eventName(c.kind))
      mput(fh, '=')
      mput(fh, c.handler)
    ENDIF
  ENDIF
  IF c.propFlags AND PF_WEIGHT THEN mputProp(fh, ' :weight=', c.weight)
  IF c.propFlags AND PF_FIXW THEN mputProp(fh, ' :fixw=', c.fixW)
  IF c.propFlags AND PF_FIXH THEN mputProp(fh, ' :fixh=', c.fixH)
  IF c.propFlags AND PF_MIN THEN mputProp(fh, ' :min=', c.minV)
  IF c.propFlags AND PF_MAX THEN mputProp(fh, ' :max=', c.maxV)
  IF c.propFlags AND PF_VALUE THEN mputProp(fh, ' :value=', c.value)
  IF c.propFlags AND PF_FONT
    mput(fh, ' :font=')
    mput(fh, fontName(c.fontIdx))
  ENDIF
  IF c.propFlags AND PF_ARG
    mput(fh, ' :arg=\q')
    mput(fh, c.arg)
    mput(fh, '\q')
  ENDIF
  IF c.propFlags AND PF_SAVE THEN mput(fh, ' :save')
  IF c.propFlags AND PF_DISABLED THEN mput(fh, ' :disabled')
  IF c.propFlags AND PF_FRAME THEN mput(fh, ' :frame')
  IF c.propFlags AND PF_HINT
    mput(fh, ' :hint=\q')
    mput(fh, c.hint)
    mput(fh, '\q')
  ENDIF
  mput(fh, '\n')
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
  DEF len, start, tok, inq
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
  inq := FALSE
  WHILE (pos < len) AND ((line[pos] <> " ") OR inq)
    IF line[pos] = 34 THEN inq := (inq = FALSE)
    pos++
  ENDWHILE
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

-> ":name" or ":name=value": does tok name this property?
PROC tokIs(tok, name)
  DEF n
  n := StrLen(name)
  IF StrLen(tok) < (n + 1) THEN RETURN FALSE
  IF StrCmp(tok + 1, name, n) = FALSE THEN RETURN FALSE
  IF tok[n + 1] = 0 THEN RETURN TRUE
  IF tok[n + 1] = "=" THEN RETURN TRUE
ENDPROC FALSE

PROC tokNumber(tok)
  DEF eq, n
  eq := InStr(tok, '=')
  IF eq < 0 THEN RETURN 0
  n := Val(tok + eq + 1)
ENDPROC n

-> the value after '=', without surrounding double quotes
PROC tokString(tok)
  DEF eq, n, h
  eq := InStr(tok, '=')
  IF eq < 0 THEN RETURN String(2)
  n := StrLen(tok) - eq - 1
  IF n >= 2
    IF (tok[eq + 1] = 34) AND (tok[StrLen(tok) - 1] = 34)
      h := String(n)
      IF n > 2 THEN MidStr(h, tok, eq + 2, n - 2)
      RETURN h
    ENDIF
  ENDIF
  h := String(n + 1)
  IF n > 0 THEN MidStr(h, tok, eq + 1, n)
ENDPROC h

PROC applyProp(c: PTR TO component, tok)
  DEF k
  IF tokIs(tok, 'weight')
    c.weight := tokNumber(tok)
    c.propFlags := c.propFlags OR PF_WEIGHT
  ELSEIF tokIs(tok, 'fixw')
    c.fixW := tokNumber(tok)
    c.propFlags := c.propFlags OR PF_FIXW
  ELSEIF tokIs(tok, 'fixh')
    c.fixH := tokNumber(tok)
    c.propFlags := c.propFlags OR PF_FIXH
  ELSEIF tokIs(tok, 'min')
    c.minV := tokNumber(tok)
    c.propFlags := c.propFlags OR PF_MIN
  ELSEIF tokIs(tok, 'max')
    c.maxV := tokNumber(tok)
    c.propFlags := c.propFlags OR PF_MAX
  ELSEIF tokIs(tok, 'value')
    c.value := tokNumber(tok)
    c.propFlags := c.propFlags OR PF_VALUE
  ELSEIF tokIs(tok, 'font')
    k := fontIndex(tokString(tok))
    IF k > 0
      c.fontIdx := k
      c.propFlags := c.propFlags OR PF_FONT
    ENDIF
  ELSEIF tokIs(tok, 'arg')
    c.arg := tokString(tok)
    c.propFlags := c.propFlags OR PF_ARG
  ELSEIF tokIs(tok, 'save')
    c.propFlags := c.propFlags OR PF_SAVE
  ELSEIF tokIs(tok, 'disabled')
    c.propFlags := c.propFlags OR PF_DISABLED
  ELSEIF tokIs(tok, 'frame')
    c.propFlags := c.propFlags OR PF_FRAME
  ELSEIF tokIs(tok, 'hint')
    c.hint := tokString(tok)
    c.propFlags := c.propFlags OR PF_HINT
  ENDIF
ENDPROC

-> Reads a form; returns the window component, or NIL on error.
PROC readForm(filename)
  DEF fh, line, lineNo, pos, level, kindTok, nameTok, titleTok, kind, i
  DEF handlerTok, tok, quoted, propToks
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
      propToks := List(16)
      REPEAT
        tok, pos, quoted := nextToken(line, pos)
        IF tok
          IF quoted
            titleTok := tok
          ELSEIF tok[0] = "@"
            handlerTok := eventHandler(tok)
          ELSEIF tok[0] = ":"
            IF ListLen(propToks) < 16 THEN ListAdd(propToks, [tok], 1)
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
      IF (isRootKind(kind) = FALSE) AND ((nameTok[0] < "a") OR (nameTok[0] > "z"))
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
      FOR i := 0 TO ListLen(propToks) - 1
        applyProp(c, ListItem(propToks, i))
      ENDFOR
      IF level = 0
        IF isRootKind(kind) = FALSE
          WriteF('\s line \d: the first component must be a Window or a Frame\n', filename, lineNo)
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
