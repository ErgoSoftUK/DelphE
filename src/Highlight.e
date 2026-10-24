/*
** DelphE syntax highlighting for Amiga E source.
**
** TextEditor.mcc takes styled text: ESC b (bold), ESC n (normal) and ESC p[n]
** (pen n). highlightText() turns plain source into that, and stripStyles()
** removes it again, so that files on disk stay plain text.
**
** The pen numbers are the ones that look right on the standard 8-colour MUI
** screen: pens 17 and up are fixed colours, 0 to 8 follow the palette.
*/

OPT MODULE
OPT EXPORT

MODULE 'exec/memory'

ENUM HL_NONE, HL_KEYWORD, HL_STRING, HL_COMMENT, HL_NUMBER

DEF hlOut: PTR TO CHAR, hlOp, hlCur

PROC hlEmit(s: PTR TO CHAR)
  DEF i, n
  n := StrLen(s)
  FOR i := 0 TO n - 1
    hlOut[hlOp] := s[i]
    hlOp++
  ENDFOR
ENDPROC

PROC hlPut(c)
  hlOut[hlOp] := c
  hlOp++
ENDPROC

-> Switches to a style; only writes escape codes when the style changes
PROC hlStyle(st)
  IF st = hlCur THEN RETURN
  IF hlCur <> HL_NONE THEN hlEmit('\en\ep[0]')
  SELECT st
    CASE HL_KEYWORD
      hlEmit('\eb\ep[18]')
    CASE HL_STRING
      hlEmit('\ep[17]')
    CASE HL_COMMENT
      hlEmit('\ep[22]')
    CASE HL_NUMBER
      hlEmit('\ep[26]')
  ENDSELECT
  hlCur := st
ENDPROC

PROC hlIsKeyword(buf: PTR TO CHAR, start, n)
  DEF kw: PTR TO LONG, i, k, s: PTR TO CHAR, same

  -> keywords are upper case, so most identifiers are ruled out by the first letter
  IF (buf[start] < "A") OR (buf[start] > "Z") THEN RETURN FALSE

  kw := ['PROC', 'ENDPROC', 'IF', 'THEN', 'ELSE', 'ELSEIF', 'ENDIF', 'WHILE', 'ENDWHILE',
         'FOR', 'TO', 'STEP', 'ENDFOR', 'REPEAT', 'UNTIL', 'LOOP', 'ENDLOOP', 'SELECT',
         'CASE', 'DEFAULT', 'ENDSELECT', 'OBJECT', 'ENDOBJECT', 'DEF', 'CONST', 'ENUM',
         'SET', 'OPT', 'MODULE', 'PTR', 'ARRAY', 'STRING', 'LIST', 'OF', 'IS', 'NEW', 'END',
         'NIL', 'TRUE', 'FALSE', 'HANDLE', 'EXCEPT', 'DO', 'RETURN', 'EXIT', 'AND', 'OR',
         'NOT', 'SIZEOF', 'EXPORT', 'ALL', 'INC', 'DEC', 'JUMP', 'LONG', 'INT', 'CHAR',
         'FUNC', 'STACK', 'OFFSETOF', 'MOD', 'ENDWHILE', 'OSVERSION', 'PREPROCESS',
         'LARGE', 'REG', 'ELSEIF', 'INCBIN', 'CHAR', 'PRIVATE', 'PUBLIC', 'UNTIL']
  FOR k := 0 TO ListLen(kw) - 1
    s := kw[k]
    IF StrLen(s) = n
      same := TRUE
      i := 0
      WHILE same AND (i < n)
        IF s[i] <> buf[start + i] THEN same := FALSE
        i++
      ENDWHILE
      IF same THEN RETURN TRUE
    ENDIF
  ENDFOR
ENDPROC FALSE

PROC hlIsIdent(c) IS ((c >= "A") AND (c <= "Z")) OR ((c >= "a") AND (c <= "z")) OR ((c >= "0") AND (c <= "9")) OR (c = "_")

PROC hlIsHex(c) IS ((c >= "0") AND (c <= "9")) OR ((c >= "A") AND (c <= "F")) OR ((c >= "a") AND (c <= "f"))

/*
** Returns a copy of buf (len characters, zero-terminated) with the styles in it,
** in memory the caller frees with FreeVec(), or NIL if there is no memory. Each
** line starts and ends in the plain style, so a style never spans a line.
*/
PROC highlightText(buf: PTR TO CHAR, len)
  DEF i, c, n, depth, quote

  hlOut := AllocVec((len * 13) + 64, MEMF_PUBLIC)
  IF hlOut = NIL THEN RETURN NIL
  hlOp := 0
  hlCur := HL_NONE
  depth := 0
  i := 0

  WHILE i < len
    c := buf[i]
    IF c = 10
      hlStyle(HL_NONE)
      hlPut(10)
      i++
    ELSEIF depth > 0
      -> inside a /* */ comment (they nest)
      hlStyle(HL_COMMENT)
      IF (c = "/") AND (buf[i + 1] = "*")
        depth++
        hlPut(c)
        hlPut("*")
        i := i + 2
      ELSEIF (c = "*") AND (buf[i + 1] = "/")
        depth--
        hlPut(c)
        hlPut("/")
        i := i + 2
        IF depth = 0 THEN hlStyle(HL_NONE)
      ELSE
        hlPut(c)
        i++
      ENDIF
    ELSEIF (c = "/") AND (buf[i + 1] = "*")
      depth := 1
      hlStyle(HL_COMMENT)
      hlPut(c)
      hlPut("*")
      i := i + 2
    ELSEIF (c = "-") AND (buf[i + 1] = ">")
      hlStyle(HL_COMMENT)
      WHILE (i < len) AND (buf[i] <> 10)
        hlPut(buf[i])
        i++
      ENDWHILE
    ELSEIF (c = 39) OR (c = 34)
      -> a string or a "ABCD" constant: ends at the same quote or the end of the line
      quote := c
      hlStyle(HL_STRING)
      hlPut(c)
      i++
      WHILE (i < len) AND (buf[i] <> 10) AND (buf[i] <> quote)
        IF (buf[i] = "\\") AND (i + 1 < len) AND (buf[i + 1] <> 10)
          hlPut(buf[i])
          hlPut(buf[i + 1])
          i := i + 2
        ELSE
          hlPut(buf[i])
          i++
        ENDIF
      ENDWHILE
      IF (i < len) AND (buf[i] = quote)
        hlPut(quote)
        i++
      ENDIF
      hlStyle(HL_NONE)
    ELSEIF (c >= "0") AND (c <= "9")
      hlStyle(HL_NUMBER)
      WHILE (i < len) AND (buf[i] >= "0") AND (buf[i] <= "9")
        hlPut(buf[i])
        i++
      ENDWHILE
      IF (buf[i] = ".") AND (buf[i + 1] >= "0") AND (buf[i + 1] <= "9")
        hlPut(".")
        i++
        WHILE (i < len) AND (buf[i] >= "0") AND (buf[i] <= "9")
          hlPut(buf[i])
          i++
        ENDWHILE
      ENDIF
      hlStyle(HL_NONE)
    ELSEIF ((c = "$") AND hlIsHex(buf[i + 1])) OR ((c = "%") AND ((buf[i + 1] = "0") OR (buf[i + 1] = "1")))
      hlStyle(HL_NUMBER)
      hlPut(c)
      i++
      WHILE (i < len) AND hlIsHex(buf[i])
        hlPut(buf[i])
        i++
      ENDWHILE
      hlStyle(HL_NONE)
    ELSEIF hlIsIdent(c)
      n := 0
      WHILE (i + n < len) AND hlIsIdent(buf[i + n]) DO n++
      IF hlIsKeyword(buf, i, n) THEN hlStyle(HL_KEYWORD) ELSE hlStyle(HL_NONE)
      WHILE n > 0
        hlPut(buf[i])
        i++
        n--
      ENDWHILE
      hlStyle(HL_NONE)
    ELSE
      hlStyle(HL_NONE)
      hlPut(c)
      i++
    ENDIF
  ENDWHILE
  hlStyle(HL_NONE)
  hlOut[hlOp] := 0
ENDPROC hlOut

/*
** Removes the styles from buf (zero-terminated) in place and returns the new
** length. Any ESC b / i / u / n and ESC p[n] is dropped, whatever order the
** editor wrote them in.
*/
PROC stripStyles(buf: PTR TO CHAR)
  DEF r, w, c
  r := 0
  w := 0
  WHILE buf[r] <> 0
    c := buf[r]
    IF c = 27
      r++
      IF buf[r] = "p"
        r++
        IF buf[r] = "["
          WHILE (buf[r] <> "]") AND (buf[r] <> 0) DO r++
          IF buf[r] = "]" THEN r++
        ENDIF
      ELSEIF buf[r] <> 0
        r++
      ENDIF
    ELSE
      buf[w] := c
      w++
      r++
    ENDIF
  ENDWHILE
  buf[w] := 0
ENDPROC w
