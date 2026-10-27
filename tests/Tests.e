/*
** DelphE's own unit tests, written with DUnit. They need no MUI and no screen.
**
**   cd tests
**   ec Tests ADDBUF 3 (or: evo Tests NOPROGRESS ADDBUF 3)
**   Tests
**
** Build runs them and writes the report to tests.out. The tests that write files use RAM:dunit.
*/

OPT LARGE

MODULE 'dos/dos', 'exec/memory', '*/dunit/DUnit', '*/src/FormModel', '*/src/MForm',
       '*/src/Util', '*/src/Generator', '*/src/GenOut', '*/src/GenFiles', '*/src/UserFile', '*/src/Highlight'

/*** helpers ***/

-> A writable copy of a string, as zero-terminated memory
PROC mk(text)
  DEF out: PTR TO CHAR, n
  n := StrLen(text)
  out := AllocVec(n + 2, MEMF_PUBLIC OR MEMF_CLEAR)
  IF n > 0 THEN CopyMem(text, out, n)
ENDPROC out

-> A small form: window > root group > button and text, with an event handler on the button
PROC sampleForm()
  DEF w: PTR TO component, root: PTR TO component, b: PTR TO component
  w := newComponent(CK_WINDOW, 'Sample', 'A form')
  root := newComponent(CK_VGROUP, 'root', NIL)
  w.addChild(root)
  b := newComponent(CK_BUTTON, 'btnOk', 'OK')
  b.handler := 'btnOkClick'
  root.addChild(b)
  root.addChild(newComponent(CK_TEXT, 'lblHello', 'Hello'))
ENDPROC w

PROC makeTestDir()
  DEF lock
  lock := CreateDir('RAM:dunit')
  IF lock THEN UnLock(lock)
ENDPROC

/*** FormModel ***/

PROC testKindNames()
  DEF k
  FOR k := CK_WINDOW TO CK_TIMER
    assertEquals(k, kindFromName(kindName(k)), 'every kind has a name that finds it again')
  ENDFOR
  assertEquals(-1, kindFromName('Nonsense'), 'an unknown name')
ENDPROC

-> The table of kinds: a row for each kind of the ENUM, names that find themselves, and events that
-> come with a handler suffix
PROC testKindTable()
  DEF k
  assertEquals(CK_TIMER + 1, ListLen(kindTable()), 'one row for each kind')
  FOR k := CK_WINDOW TO CK_TIMER
    assertNotNil(kindName(k), 'every kind has a name')
    IF eventName(k)
      assertNotNil(eventSuffix(k), 'an event has a handler suffix')
    ELSE
      assertNil(eventSuffix(k), 'and no event has none')
    ENDIF
  ENDFOR
  assertStrEquals('OnClick', eventName(CK_BUTTON), NIL)
  assertStrEquals('Click', eventSuffix(CK_BUTTON), NIL)
  assertStrEquals('btn', kindPrefix(CK_BUTTON), NIL)
  assertStrEquals('Button', kindTitle(CK_BUTTON), NIL)
  assertStrEquals('TextEditor.mcc', kindClass(CK_MEMO), 'a kind that needs a MUI class')
  assertNil(kindClass(CK_BUTTON), NIL)
  assertNil(eventName(99), 'a kind that is not in the table is quiet')
ENDPROC

PROC testChildren()
  DEF g: PTR TO component, a: PTR TO component, b: PTR TO component, c: PTR TO component
  g := newComponent(CK_VGROUP, 'g', NIL)
  a := newComponent(CK_TEXT, 'a', 'A')
  b := newComponent(CK_TEXT, 'b', 'B')
  c := newComponent(CK_TEXT, 'c', 'C')
  g.addChild(a)
  g.addChild(c)
  g.insertAt(b, 1)
  assertEquals(3, g.childCount(), 'three children')
  assertEquals(1, g.indexOf(b), 'b went between a and c')
  assertEquals(a, g.firstChild, NIL)
  assertEquals(c, g.lastChild, NIL)
  g.removeChild(b)
  assertEquals(2, g.childCount(), 'b is gone')
  assertEquals(-1, g.indexOf(b), NIL)
  assertEquals(c, a.next, 'a and c are neighbours again')
ENDPROC

PROC testCloneTree()
  DEF w: PTR TO component, copy: PTR TO component, r: PTR TO component, cr: PTR TO component
  w := sampleForm()
  copy := cloneTree(w)
  assertNotEquals(w, copy, 'a new component')
  r := rootOf(w)
  cr := rootOf(copy)
  assertNotEquals(r, cr, 'the children are copies too')
  assertEquals(2, cr.childCount(), NIL)
  assertStrEquals('btnOk', cr.firstChild.name, NIL)
  assertStrEquals('btnOkClick', cr.firstChild.handler, 'the handler is copied')
  cr.firstChild.title := 'Changed'
  assertStrEquals('OK', r.firstChild.title, 'changing the copy leaves the original alone')
ENDPROC

PROC testNthItem()
  DEF s
  s := nthItem('One|Two|Three', 1)
  assertStrEquals('Two', s, 'the second entry')
  assertStrEquals('Three', nthItem('One|Two|Three', 2), NIL)
  assertNil(nthItem('One|Two', 5), 'past the end')
  assertStrEquals('', nthItem('One||Three', 1), 'an empty entry')
ENDPROC

PROC testParentRules()
  assertTrue(allowedChild(CK_VGROUP, CK_BUTTON), 'a group holds a button')
  assertFalse(allowedChild(CK_VGROUP, CK_FILEDLG), 'a group does not hold a dialog')
  assertTrue(allowedChild(CK_UTILS, CK_TIMER), 'Utilities holds a timer')
  assertFalse(allowedChild(CK_UTILS, CK_BUTTON), 'Utilities holds no button')
  assertTrue(allowedChild(CK_MENUSTRIP, CK_MENU), NIL)
  assertFalse(allowedChild(CK_MENUSTRIP, CK_MENUITEM), 'a strip holds menus, not items')
  assertTrue(allowedChild(CK_MENU, CK_MENUITEM), NIL)
  assertTrue(allowedChild(CK_MENUITEM, CK_MENUITEM), 'a submenu')
  assertTrue(isContainer(CK_SCROLL), NIL)
  assertFalse(isContainer(CK_BUTTON), NIL)
ENDPROC

PROC testRootAndUtilities()
  DEF w: PTR TO component, u: PTR TO component, root: PTR TO component
  w := sampleForm()
  root := rootOf(w)
  assertNotNil(root, 'the window has a root group')
  assertNil(utilitiesOf(w), 'and no Utilities yet')
  u := newComponent(CK_UTILS, 'utilities', NIL)
  w.addChild(u)
  assertEquals(u, utilitiesOf(w), NIL)
  assertEquals(root, rootOf(w), 'the Utilities branch is not the root group')
ENDPROC

/*** MForm ***/

PROC testFormRoundTrip()
  DEF w: PTR TO component, fh, back: PTR TO component, b: PTR TO component, r: PTR TO component
  makeTestDir()
  w := sampleForm()
  r := rootOf(w)
  b := r.firstChild
  b.weight := 200
  b.propFlags := b.propFlags OR PF_WEIGHT OR PF_DISABLED
  fh := Open('RAM:dunit/round.mform', MODE_NEWFILE)
  assertNotNil(fh, 'the file can be written')
  writeForm(fh, w, 0)
  Close(fh)
  back := readForm('RAM:dunit/round.mform')
  assertNotNil(back, 'and read back')
  assertStrEquals('Sample', back.name, NIL)
  assertStrEquals('A form', back.title, NIL)
  r := rootOf(back)
  b := r.firstChild
  assertStrEquals('btnOk', b.name, NIL)
  assertStrEquals('btnOkClick', b.handler, NIL)
  assertEquals(200, b.weight, 'a property')
  assertTrue(b.propFlags AND PF_DISABLED, 'a flag')
  assertEquals(2, r.childCount(), NIL)
ENDPROC

PROC testReadMissingFile()
  assertNil(readForm('RAM:dunit/does-not-exist.mform'), NIL)
ENDPROC

/*** Util ***/

PROC testValidIdent()
  assertTrue(validIdent('btnOk'), NIL)
  assertTrue(validIdent('a_1'), NIL)
  assertFalse(validIdent(''), 'empty')
  assertFalse(validIdent('has space'), NIL)
  assertFalse(validIdent('dash-ed'), NIL)
ENDPROC

PROC testPaths()
  assertStrEquals('Main', nameFromPath('forms/main.mform'), 'name from a path')
  assertStrEquals('XFer:DelphE/examples/', dirPart('XFer:DelphE/examples/sample.mform'), NIL)
  assertStrEquals('', dirPart('sample.mform'), 'no folder')
  assertStrEquals('a/b.e', joinPath('a', 'b.e'), NIL)
  assertStrEquals('a/b.e', joinPath('a/', 'b.e'), NIL)
  assertStrEquals('RAM:b.e', joinPath('a', 'RAM:b.e'), 'a full path is left alone')
  assertStrEquals('sub/x.e', relPath('proj/', 'proj/sub/x.e'), NIL)
  assertTrue(isNumber('123'), NIL)
  assertTrue(isNumber('-5'), NIL)
  assertFalse(isNumber('12a'), NIL)
ENDPROC

/*** Highlight ***/

PROC testHighlightRoundTrip()
  DEF src, hl: PTR TO CHAR, n, copy
  src := 'PROC main()\n  WriteF(\aHi\a) -> a comment\nENDPROC\n'
  hl := highlightText(src, StrLen(src))
  assertNotNil(hl, 'the text was coloured')
  assertTrue(StrLen(hl) > StrLen(src), 'colour codes were added')
  copy := mk(hl)
  stripStyles(copy)
  assertStrEquals(src, copy, 'stripping gives the text back')
ENDPROC

PROC testHighlightKeyword()
  DEF src, hl: PTR TO CHAR
  src := 'DEF x'
  hl := highlightText(src, StrLen(src))
  assertEquals(27, hl[0], 'a keyword starts with a style code (ESC)')
  hl := highlightText('plain', 5)
  assertStrEquals('plain', hl, 'ordinary words are left alone')
ENDPROC

PROC testHighlightIgnoresKeywordInString()
  DEF src, hl: PTR TO CHAR, copy
  src := '\aPROC inside\a'
  hl := highlightText(src, StrLen(src))
  copy := mk(hl)
  stripStyles(copy)
  assertStrEquals(src, copy, NIL)
  -> a string is one colour: only one pair of style codes in the whole text
  assertTrue(StrLen(hl) < (StrLen(src) + 24), 'one colour for the whole string')
ENDPROC

/*** UserFile ***/

PROC sampleProgram()
ENDPROC 'MODULE \amuimaster\a, \alibraries/mui\a,\n       \aamigalib/boopsi\a\n\nDEF a, b\n\n->>> DELPHE GENERATED CODE (x)\n\n/*** your code ***/\n\nPROC foo()\nENDPROC\n'

PROC testSplitSections()
  DEF text, s: PTR TO sections
  text := sampleProgram()
  s := splitSections(text, StrLen(text))
  assertTrue(s.hasMarker, 'the generated-code line was found')
  assertContains('MODULE', s.modText, 'modules')
  assertContains('amigalib/boopsi', s.modText, 'a module on a continuation line')
  assertContains('DEF a, b', s.globText, 'globals')
  assertContains('PROC foo()', s.codeText, 'code')
  assertEquals(-1, InStr(s.codeText, '/*** your code ***/'), 'the your-code comment is not part of the code')
ENDPROC

PROC testSplitNoMarker()
  DEF text, s: PTR TO sections
  text := 'PROC main()\nENDPROC\n'
  s := splitSections(text, StrLen(text))
  assertFalse(s.hasMarker, 'not one of our files')
  assertStrEquals(text, s.codeText, 'all of it is code')
ENDPROC

PROC testJoinSections()
  DEF text, s: PTR TO sections, out, olen, s2: PTR TO sections
  text := sampleProgram()
  s := splitSections(text, StrLen(text))
  out, olen := joinSections(s.modText, s.globText, s.codeText)
  assertNotNil(out, NIL)
  assertContains('DELPHE GLOBALS', out, 'the globals line is added')
  assertContains('DELPHE GENERATED CODE', out, NIL)
  s2 := splitSections(out, olen)
  assertStrEquals(s.globText, s2.globText, 'the globals survive')
  assertStrEquals(s.codeText, s2.codeText, 'and the code')
ENDPROC

PROC testModuleList()
  DEF text, s: PTR TO sections, pre, names, built, disp
  text := sampleProgram()
  s := splitSections(text, StrLen(text))
  pre, names := parseModules(s.modText, s.modLen)
  assertStrEquals('muimaster\nlibraries/mui\namigalib/boopsi\n', names, 'one module per line')
  disp := moduleDisplay(names)
  assertStrEquals('\amuimaster\a, \alibraries/mui\a, \aamigalib/boopsi\a', disp, 'shown on one line')
  built := buildModules(pre, names)
  assertContains('MODULE \amuimaster\a, \alibraries/mui\a, \aamigalib/boopsi\a', built, 'written as one statement')
ENDPROC

/*** Generator ***/

PROC testGenerate()
  DEF w: PTR TO component, res, buf, len
  makeTestDir()
  DeleteFile('RAM:dunit/Sample.e')
  DeleteFile('RAM:dunit/Sample.gen.e')
  w := sampleForm()
  res := generateFile('RAM:dunit/Sample.e', w)
  assertEquals(GEN_OK, res, 'generating works')
  buf, len := readAll('RAM:dunit/Sample.gen.e')
  assertNotNil(buf, 'the generated file exists')
  assertContains('OBJECT tSample', buf, NIL)
  assertContains('PROC create() OF tSample', buf, NIL)
  assertContains('self.btnOk', buf, 'a field for the button')
  assertContains('delpheRun', buf, 'the program loop')
  buf, len := readAll('RAM:dunit/Sample.e')
  assertNotNil(buf, 'the program file exists')
  assertContains('PROC btnOkClick() OF tSample', buf, 'a stub for the handler')
  assertContains('DELPHE GENERATED CODE', buf, 'and the line the generated code is inserted at')
ENDPROC

PROC testGenerateKeepsUserCode()
  DEF w: PTR TO component, res, buf, len, fh
  makeTestDir()
  w := sampleForm()
  generateFile('RAM:dunit/Keep.e', w)
  buf, len := readAll('RAM:dunit/Keep.e')
  fh := Open('RAM:dunit/Keep.e', MODE_NEWFILE)
  Write(fh, buf, len)
  Write(fh, '\n-> mine\n', 9)
  Close(fh)
  res := generateFile('RAM:dunit/Keep.e', w)
  assertEquals(GEN_OK, res, NIL)
  buf, len := readAll('RAM:dunit/Keep.e')
  assertContains('-> mine', buf, 'the user\as own text is not touched')
ENDPROC

/*** the language ***/

-> An E-string holds at most 32K characters (a bigger String() corrupts memory), which is why
-> long texts in the generator use their own growing buffers
PROC testLongEString()
  DEF s, i, chunk
  s := String(32000)
  assertNotNil(s, 'an E-string of 32000 bytes can be allocated')
  chunk := 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-0123456789-0123456789-0123456789-ABCD'
  FOR i := 1 TO 280
    StrAdd(s, chunk, ALL)
  ENDFOR
  assertEquals(280 * StrLen(chunk), StrLen(s), 'all of it was kept')
ENDPROC

/*** limits: long lines, many handlers, big texts ***/

-> A string of n copies of the character c, then tail
PROC longText(n, c, tail)
  DEF s, i
  s := String(n + StrLen(tail) + 8)
  FOR i := 0 TO n - 1 DO s[i] := c
  SetStr(s, n)
  StrAdd(s, tail, ALL)
ENDPROC s

PROC testLongTitleRoundTrip()
  DEF w: PTR TO component, r: PTR TO component, t: PTR TO component, fh, back: PTR TO component
  makeTestDir()
  w := newComponent(CK_WINDOW, 'Long', 'A form')
  r := newComponent(CK_VGROUP, 'root', NIL)
  w.addChild(r)
  t := newComponent(CK_TEXT, 'lblLong', longText(1500, "a", 'END'))
  r.addChild(t)
  fh := Open('RAM:dunit/long.mform', MODE_NEWFILE)
  writeForm(fh, w, 0)
  Close(fh)
  back := readForm('RAM:dunit/long.mform')
  assertNotNil(back, 'a line of 1500 characters can be read')
  r := rootOf(back)
  t := r.firstChild
  assertEquals(1503, StrLen(t.title), 'all of the title came back')
  assertContains('aaaEND', t.title, 'including its end')
ENDPROC

PROC testLineTooLong()
  DEF fh, text
  makeTestDir()
  text := longText(5000, "b", '"')
  fh := Open('RAM:dunit/toolong.mform', MODE_NEWFILE)
  Write(fh, 'Window W "', 10)
  Write(fh, text, StrLen(text))
  Write(fh, '\n', 1)
  Close(fh)
  assertNil(readForm('RAM:dunit/toolong.mform'), 'a line over the limit is refused, not read in pieces')
ENDPROC

PROC testUnknownProperty()
  DEF fh, w: PTR TO component, text, r: PTR TO component
  makeTestDir()
  text := 'Window W "T"\n  VGroup root\n    Button b "B" :bogus :weight=5\n'
  fh := Open('RAM:dunit/unknown.mform', MODE_NEWFILE)
  Write(fh, text, StrLen(text))
  Close(fh)
  w := readForm('RAM:dunit/unknown.mform')
  assertNotNil(w, 'an unknown property does not stop the form loading')
  r := rootOf(w)
  w := r.firstChild
  assertEquals(5, w.weight, 'and the known one next to it is kept')
ENDPROC

PROC testManyHandlers()
  DEF w: PTR TO component, r: PTR TO component, b: PTR TO component, i, name, hnd, buf, len
  makeTestDir()
  DeleteFile('RAM:dunit/Big.e')
  DeleteFile('RAM:dunit/Big.gen.e')
  w := newComponent(CK_WINDOW, 'Big', 'Many')
  r := newComponent(CK_VGROUP, 'root', NIL)
  w.addChild(r)
  FOR i := 1 TO 300
    name := String(16)
    StringF(name, 'btn\d', i)
    hnd := String(24)
    StringF(hnd, 'btn\dClick', i)
    b := newComponent(CK_BUTTON, name, 'B')
    b.handler := hnd
    r.addChild(b)
  ENDFOR
  assertEquals(GEN_OK, generateFile('RAM:dunit/Big.e', w), 'generating works')
  buf, len := readAll('RAM:dunit/Big.e')
  assertNotNil(buf, NIL)
  assertContains('PROC btn1Click() OF tBig', buf, 'the first stub')
  assertContains('PROC btn300Click() OF tBig', buf, 'the last stub: the stubs buffer was big enough')
ENDPROC

PROC testBigGeneratedText()
  DEF w: PTR TO component, r: PTR TO component, buf, len, res
  makeTestDir()
  DeleteFile('RAM:dunit/Huge.e')
  DeleteFile('RAM:dunit/Huge.gen.e')
  w := newComponent(CK_WINDOW, 'Huge', 'Big text')
  r := newComponent(CK_VGROUP, 'root', NIL)
  w.addChild(r)
  r.addChild(newComponent(CK_TEXT, 'lblHuge', longText(20000, "x", 'THE-END')))
  res := generateFile('RAM:dunit/Huge.e', w)
  assertEquals(GEN_OK, res, NIL)
  buf, len := readAll('RAM:dunit/Huge.gen.e')
  assertNotNil(buf, NIL)
  assertTrue(len > 20000, 'a text bigger than the output buffer was written')
  assertContains('xxxTHE-END', buf, 'complete, to its last character')
ENDPROC

PROC main()
  duBegin('Limits')
  duTest('a long title round trip', {testLongTitleRoundTrip})
  duTest('a line that is too long', {testLineTooLong})
  duTest('an unknown property', {testUnknownProperty})
  duTest('many handlers', {testManyHandlers})
  duTest('a text bigger than the output buffer', {testBigGeneratedText})
  duEnd()

  duBegin('Language')
  duTest('long E-strings', {testLongEString})
  duEnd()

  duBegin('FormModel')
  duTest('kind names', {testKindNames})
  duTest('the table of kinds', {testKindTable})
  duTest('children', {testChildren})
  duTest('cloneTree', {testCloneTree})
  duTest('nthItem', {testNthItem})
  duTest('which kinds may go where', {testParentRules})
  duTest('root group and utilities', {testRootAndUtilities})
  duEnd()

  duBegin('MForm')
  duTest('write and read back', {testFormRoundTrip})
  duTest('missing file', {testReadMissingFile})
  duEnd()

  duBegin('Util')
  duTest('validIdent', {testValidIdent})
  duTest('paths', {testPaths})
  duEnd()

  duBegin('Highlight')
  duTest('round trip', {testHighlightRoundTrip})
  duTest('keyword', {testHighlightKeyword})
  duTest('keyword inside a string', {testHighlightIgnoresKeywordInString})
  duEnd()

  duBegin('UserFile')
  duTest('split', {testSplitSections})
  duTest('split without a marker', {testSplitNoMarker})
  duTest('join', {testJoinSections})
  duTest('module list', {testModuleList})
  duEnd()

  duBegin('Generator')
  duTest('generate a form', {testGenerate})
  duTest('regenerate keeps user code', {testGenerateKeepsUserCode})
  duEnd()

  IF duFinish() = FALSE THEN CleanUp(10)
ENDPROC
