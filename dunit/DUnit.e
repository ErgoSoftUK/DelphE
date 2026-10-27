/*
** DUnit: a small unit test framework for Amiga E, in the style of JUnit and NUnit.
**
** E has no reflection, so a test is registered by hand: a procedure with no arguments
** that calls asserts, and its address with duTest(). A failed assert stops that test
** (it raises an exception) and the runner goes on with the next one.
**
**   MODULE 'DUnit'            (the path depends on where you keep it; see Tests.e)
**
**   PROC testAddition()
**     assertEquals(4, 2 + 2, 'two and two')
**   ENDPROC
**
**   PROC main()
**     duBegin('Arithmetic')
**     duTest('addition', {testAddition})
**     duEnd()
**     IF duFinish() = FALSE THEN CleanUp(10)
**   ENDPROC
**
** Optional per suite: duSetUp() and duTearDown() give procedures that run before and
** after every test. Every assert takes a message as its last argument (NIL for none).
** A test that raises some other exception counts as an error, not a failure.
*/

OPT MODULE
OPT EXPORT

MODULE 'dos/dos'

CONST DU_PASS = 0, DU_FAIL = 1, DU_ERROR = 2

OBJECT dutest
  next: PTR TO dutest
  name
  fn
ENDOBJECT

OBJECT dufailure
  next: PTR TO dufailure
  suite
  name
  kind
  text
ENDOBJECT

DEF duTests: PTR TO dutest, duTestsEnd: PTR TO dutest,
    duFails: PTR TO dufailure, duFailsEnd: PTR TO dufailure,
    duSuite, duSetUpFn, duTearDownFn,
    duMsg, duTmp,
    duTotal, duPassed, duFailed, duErrored, duStatus, duStart

/*** the report ***/

PROC duNow()
  DEF ds: datestamp
  DateStamp(ds)
ENDPROC (ds.minute * 3000) + ds.tick

-> A string that can be printed even if it is NIL
PROC duStr(p)
  IF p THEN RETURN p
ENDPROC '(nil)'

PROC duEnsureBuffers()
  IF duMsg = NIL THEN duMsg := String(400)
  IF duTmp = NIL THEN duTmp := String(200)
ENDPROC

/*** raising failures ***/

-> Starts the failure text with the message of the assert, if it has one
PROC duStartText(msg)
  duEnsureBuffers()
  IF msg
    IF StrLen(msg) > 0
      StrCopy(duMsg, msg, ALL)
      StrAdd(duMsg, ': ', ALL)
      RETURN
    ENDIF
  ENDIF
  StrCopy(duMsg, '', ALL)
ENDPROC

PROC fail(msg)
  duEnsureBuffers()
  IF msg THEN StrCopy(duMsg, msg, ALL) ELSE StrCopy(duMsg, 'failed', ALL)
  Raise("DUFL")
ENDPROC

/*** the asserts ***/

PROC assertTrue(cond, msg)
  IF cond THEN RETURN
  duStartText(msg)
  StrAdd(duMsg, 'expected TRUE', ALL)
  Raise("DUFL")
ENDPROC

PROC assertFalse(cond, msg)
  IF cond = FALSE THEN RETURN
  duStartText(msg)
  StrAdd(duMsg, 'expected FALSE', ALL)
  Raise("DUFL")
ENDPROC

PROC assertEquals(expected, actual, msg)
  IF expected = actual THEN RETURN
  duStartText(msg)
  StringF(duTmp, 'expected <\d> but was <\d>', expected, actual)
  StrAdd(duMsg, duTmp, ALL)
  Raise("DUFL")
ENDPROC

PROC assertNotEquals(unexpected, actual, msg)
  IF unexpected <> actual THEN RETURN
  duStartText(msg)
  StringF(duTmp, 'did not expect <\d>', actual)
  StrAdd(duMsg, duTmp, ALL)
  Raise("DUFL")
ENDPROC

-> Both between lo and hi, inclusive
PROC assertInRange(value, lo, hi, msg)
  IF (value >= lo) AND (value <= hi) THEN RETURN
  duStartText(msg)
  StringF(duTmp, '<\d> is not between <\d> and <\d>', value, lo, hi)
  StrAdd(duMsg, duTmp, ALL)
  Raise("DUFL")
ENDPROC

-> Strings are equal if both are NIL, or both are text with the same characters
PROC duSameStr(a, b)
  IF (a = NIL) AND (b = NIL) THEN RETURN TRUE
  IF (a = NIL) OR (b = NIL) THEN RETURN FALSE
  IF StrLen(a) <> StrLen(b) THEN RETURN FALSE
ENDPROC StrCmp(a, b, ALL)

PROC assertStrEquals(expected, actual, msg)
  IF duSameStr(expected, actual) THEN RETURN
  duStartText(msg)
  StringF(duTmp, 'expected <\s> but was <\s>', duStr(expected), duStr(actual))
  StrAdd(duMsg, duTmp, ALL)
  Raise("DUFL")
ENDPROC

PROC assertStrNotEquals(unexpected, actual, msg)
  IF duSameStr(unexpected, actual) = FALSE THEN RETURN
  duStartText(msg)
  StringF(duTmp, 'did not expect <\s>', duStr(actual))
  StrAdd(duMsg, duTmp, ALL)
  Raise("DUFL")
ENDPROC

-> Does text contain part?
PROC assertContains(part, text, msg)
  IF text
    IF part
      IF InStr(text, part) <> -1 THEN RETURN
    ENDIF
  ENDIF
  duStartText(msg)
  StringF(duTmp, '<\s> does not contain <\s>', duStr(text), duStr(part))
  StrAdd(duMsg, duTmp, ALL)
  Raise("DUFL")
ENDPROC

PROC assertNil(p, msg)
  IF p = NIL THEN RETURN
  duStartText(msg)
  StrAdd(duMsg, 'expected NIL', ALL)
  Raise("DUFL")
ENDPROC

PROC assertNotNil(p, msg)
  IF p <> NIL THEN RETURN
  duStartText(msg)
  StrAdd(duMsg, 'expected something but was NIL', ALL)
  Raise("DUFL")
ENDPROC

-> len bytes at a and b are the same
PROC assertMemEquals(a: PTR TO CHAR, b: PTR TO CHAR, len, msg)
  DEF i, same
  same := TRUE
  FOR i := 0 TO len - 1
    IF a[i] <> b[i] THEN same := FALSE
  ENDFOR
  IF same THEN RETURN
  duStartText(msg)
  StringF(duTmp, 'the <\d> bytes differ', len)
  StrAdd(duMsg, duTmp, ALL)
  Raise("DUFL")
ENDPROC

/*** running a procedure and seeing what it raises ***/

PROC duCall(f)
  f()
ENDPROC

-> Runs fn; returns the exception it raised, or 0 if it ended normally
PROC duTrial(fn) HANDLE
  duCall(fn)
  RETURN 0
EXCEPT
  RETURN exception
ENDPROC

-> Passes if fn raises exactly this exception (a number or a code like "NIL")
PROC assertRaises(fn, expected, msg)
  DEF raised
  raised := duTrial(fn)
  IF raised = expected THEN RETURN
  duStartText(msg)
  IF raised = 0
    StrAdd(duMsg, 'expected an exception but none was raised', ALL)
  ELSE
    StringF(duTmp, 'expected exception <\h> but <\h> was raised', expected, raised)
    StrAdd(duMsg, duTmp, ALL)
  ENDIF
  Raise("DUFL")
ENDPROC

-> Passes if fn raises no exception
PROC assertNoRaise(fn, msg)
  DEF raised
  raised := duTrial(fn)
  IF raised = 0 THEN RETURN
  duStartText(msg)
  StringF(duTmp, 'did not expect an exception, but <\h> was raised', raised)
  StrAdd(duMsg, duTmp, ALL)
  Raise("DUFL")
ENDPROC

/*** suites ***/

-> Starts a suite: a name, and an empty list of tests
PROC duBegin(name)
  duEnsureBuffers()
  duSuite := name
  duTests := NIL
  duTestsEnd := NIL
  duSetUpFn := NIL
  duTearDownFn := NIL
  IF duStart = 0 THEN duStart := duNow()
ENDPROC

-> Adds a test: its name and the procedure, written {testName}
PROC duTest(name, fn)
  DEF t: PTR TO dutest
  NEW t
  t.name := name
  t.fn := fn
  IF duTestsEnd THEN duTestsEnd.next := t ELSE duTests := t
  duTestsEnd := t
ENDPROC

-> A procedure to run before each test of the suite, and one to run after it
PROC duSetUp(fn)
  duSetUpFn := fn
ENDPROC

PROC duTearDown(fn)
  duTearDownFn := fn
ENDPROC

-> The text of an exception that was not a failed assert: a string from Raise('text'),
-> a four-letter code, or a number
PROC duDescribe(ex, info)
  DEF b[8]: ARRAY OF CHAR, i, c, n, ok
  duEnsureBuffers()
  n := 0
  ok := TRUE
  FOR i := 0 TO 3
    c := Shr(ex, 24 - Mul(i, 8)) AND 255
    IF (c = 0) AND (n = 0)
      -> a three-letter code starts with a zero byte
    ELSEIF (c < 32) OR (c > 126)
      ok := FALSE
    ELSE
      b[n] := c
      n++
    ENDIF
  ENDFOR
  b[n] := 0
  IF ok AND (n >= 3)
    StringF(duMsg, 'unexpected exception "\s" (info \d)', b, info)
  ELSEIF ex > 1000
    StringF(duMsg, 'unexpected exception: \s', ex)
  ELSE
    StringF(duMsg, 'unexpected exception \d (info \d)', ex, info)
  ENDIF
ENDPROC

-> The teardown must never stop the run
PROC duTearDownSafe() HANDLE
  IF duTearDownFn THEN duCall(duTearDownFn)
EXCEPT
  duStatus := duStatus
ENDPROC

-> One test, with its setup and teardown. Sets duStatus and, if it did not pass, duMsg.
PROC duRunOne(t: PTR TO dutest) HANDLE
  duStatus := DU_PASS
  StrCopy(duMsg, '', ALL)
  IF duSetUpFn THEN duCall(duSetUpFn)
  duCall(t.fn)
EXCEPT DO
  IF exception = "DUFL"
    duStatus := DU_FAIL
  ELSEIF exception <> 0
    duStatus := DU_ERROR
    duDescribe(exception, exceptioninfo)
  ENDIF
  duTearDownSafe()
ENDPROC

PROC duRecord(t: PTR TO dutest)
  DEF f: PTR TO dufailure, s
  NEW f
  f.suite := duSuite
  f.name := t.name
  f.kind := duStatus
  s := String(StrLen(duMsg) + 1)
  StrCopy(s, duMsg, ALL)
  f.text := s
  IF duFailsEnd THEN duFailsEnd.next := f ELSE duFails := f
  duFailsEnd := f
ENDPROC

-> Runs the suite's tests in the order they were added, printing . for a pass, F for a failure
-> and E for an error. Returns the number of tests that did not pass.
PROC duEnd()
  DEF t: PTR TO dutest, bad, n
  WriteF('\s: ', duStr(duSuite))
  bad := 0
  n := 0
  t := duTests
  WHILE t
    duRunOne(t)
    duTotal++
    n++
    IF duStatus = DU_PASS
      duPassed++
      WriteF('.')
    ELSEIF duStatus = DU_FAIL
      duFailed++
      bad++
      WriteF('F')
      duRecord(t)
    ELSE
      duErrored++
      bad++
      WriteF('E')
      duRecord(t)
    ENDIF
    t := t.next
  ENDWHILE
  WriteF('  (\d tests)\n', n)
ENDPROC bad

-> Prints the totals and every failure. Returns TRUE if everything passed.
PROC duFinish()
  DEF f: PTR TO dufailure, elapsed
  elapsed := duNow() - duStart
  WriteF('\nTests run: \d, passed: \d, failures: \d, errors: \d  (\d.\z\r\d[2] s)\n',
         duTotal, duPassed, duFailed, duErrored, Div(elapsed, 50), Mul(Mod(elapsed, 50), 2))
  f := duFails
  WHILE f
    IF f.kind = DU_FAIL THEN WriteF('FAIL  ') ELSE WriteF('ERROR ')
    WriteF('\s / \s\n      \s\n', duStr(f.suite), duStr(f.name), duStr(f.text))
    f := f.next
  ENDWHILE
  IF (duFailed = 0) AND (duErrored = 0)
    WriteF('OK\n')
    RETURN TRUE
  ENDIF
  WriteF('FAILED\n')
ENDPROC FALSE
