/*
** DelphE's own unit tests, written with DUnit. They need no MUI and no screen.
**
**   cd tests
**   ec Tests          (or: evo Tests NOPROGRESS ADDBUF 3)
**   Tests
**
** Build runs them and writes the report to tests.out. The tests that write files use RAM:dunit.
*/

OPT LARGE

MODULE 'dos/dos', 'exec/memory', '*/dunit/DUnit', '*/src/FormModel', '*/src/MForm',
       '*/src/Util', '*/src/Generator', '*/src/UserFile', '*/src/Highlight'

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

PROC main()
  duBegin('FormModel')
  duTest('kind names', {testKindNames})
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
