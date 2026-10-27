/*
** DUnit tested with DUnit: the asserts pass when they should, and raise when they should.
**
**   cd dunit
**   ec SelfTest          (or: evo SelfTest NOPROGRESS)
**   SelfTest
*/

MODULE '*DUnit'

DEF counter, torn

/*** helpers: each makes one assert fail ***/

PROC failTrue()
  assertTrue(FALSE, NIL)
ENDPROC

PROC failFalse()
  assertFalse(TRUE, NIL)
ENDPROC

PROC failEquals()
  assertEquals(1, 2, 'numbers')
ENDPROC

PROC failNotEquals()
  assertNotEquals(5, 5, NIL)
ENDPROC

PROC failRange()
  assertInRange(11, 1, 10, NIL)
ENDPROC

PROC failStr()
  assertStrEquals('abc', 'abd', NIL)
ENDPROC

PROC failStrNil()
  assertStrEquals('abc', NIL, NIL)
ENDPROC

PROC failContains()
  assertContains('xyz', 'hello world', NIL)
ENDPROC

PROC failNil()
  assertNil(7, NIL)
ENDPROC

PROC failNotNil()
  assertNotNil(NIL, NIL)
ENDPROC

PROC failMem()
  assertMemEquals('abcd', 'abce', 4, NIL)
ENDPROC

PROC failPlain()
  fail('on purpose')
ENDPROC

PROC raiseBoom()
  Raise("BOOM")
ENDPROC

PROC raiseNothing()
  counter := counter + 0
ENDPROC

/*** the tests ***/

PROC testPassingAsserts()
  assertTrue(TRUE, NIL)
  assertFalse(FALSE, NIL)
  assertEquals(3, 1 + 2, NIL)
  assertNotEquals(3, 4, NIL)
  assertInRange(5, 1, 10, NIL)
  assertInRange(1, 1, 10, 'lower bound is inside')
  assertInRange(10, 1, 10, 'upper bound is inside')
  assertStrEquals('same', 'same', NIL)
  assertStrEquals(NIL, NIL, 'two NILs are equal')
  assertStrNotEquals('a', 'b', NIL)
  assertContains('lo wo', 'hello world', NIL)
  assertNil(NIL, NIL)
  assertNotNil(5, NIL)
  assertMemEquals('abcd', 'abcd', 4, NIL)
ENDPROC

PROC testFailingAssertsRaise()
  assertRaises({failTrue}, "DUFL", 'assertTrue')
  assertRaises({failFalse}, "DUFL", 'assertFalse')
  assertRaises({failEquals}, "DUFL", 'assertEquals')
  assertRaises({failNotEquals}, "DUFL", 'assertNotEquals')
  assertRaises({failRange}, "DUFL", 'assertInRange')
  assertRaises({failStr}, "DUFL", 'assertStrEquals')
  assertRaises({failStrNil}, "DUFL", 'assertStrEquals with NIL')
  assertRaises({failContains}, "DUFL", 'assertContains')
  assertRaises({failNil}, "DUFL", 'assertNil')
  assertRaises({failNotNil}, "DUFL", 'assertNotNil')
  assertRaises({failMem}, "DUFL", 'assertMemEquals')
  assertRaises({failPlain}, "DUFL", 'fail')
ENDPROC

PROC testFailureMessages()
  duTrial({failEquals})
  assertStrEquals('numbers: expected <1> but was <2>', duMsg, NIL)
  duTrial({failStr})
  assertStrEquals('expected <abc> but was <abd>', duMsg, NIL)
  duTrial({failStrNil})
  assertContains('<(nil)>', duMsg, 'a NIL string is shown')
  duTrial({failPlain})
  assertStrEquals('on purpose', duMsg, NIL)
ENDPROC

PROC testAssertRaises()
  assertRaises({raiseBoom}, "BOOM", NIL)
  assertRaises({testBadRaises}, "DUFL", 'wrong exception is a failure')
  assertNoRaise({raiseNothing}, NIL)
  assertRaises({testBadNoRaise}, "DUFL", 'no exception is a failure')
ENDPROC

PROC testBadRaises()
  assertRaises({raiseBoom}, "OTHR", NIL)
ENDPROC

PROC testBadNoRaise()
  assertRaises({raiseNothing}, "BOOM", NIL)
ENDPROC

PROC testDescribe()
  duDescribe("NIL", 12)
  assertContains('"NIL"', duMsg, 'a three-letter code')
  assertContains('info 12', duMsg, NIL)
  duDescribe("INDX", 3)
  assertContains('"INDX"', duMsg, 'a four-letter code')
  duDescribe(42, 0)
  assertContains('exception 42', duMsg, 'a number')
ENDPROC

/*** fixtures: set up runs before each test, tear down after ***/

PROC setUpCounter()
  counter := counter + 1
ENDPROC

PROC tearDownCounter()
  torn := torn + 1
ENDPROC

PROC testSetUpRanFirst()
  assertEquals(1, counter, 'the first test')
ENDPROC

PROC testSetUpRunsEachTime()
  assertEquals(2, counter, 'the second test')
  assertEquals(1, torn, 'the first test was torn down')
ENDPROC

PROC testTearDownAfterFailure()
  assertEquals(3, counter, NIL)
  assertEquals(2, torn, NIL)
ENDPROC

PROC main()
  duBegin('Asserts')
  duTest('passing asserts', {testPassingAsserts})
  duTest('failing asserts raise', {testFailingAssertsRaise})
  duTest('failure messages', {testFailureMessages})
  duTest('assertRaises', {testAssertRaises})
  duTest('describing exceptions', {testDescribe})
  duEnd()

  counter := 0
  torn := 0
  duBegin('Fixtures')
  duSetUp({setUpCounter})
  duTearDown({tearDownCounter})
  duTest('set up before the first test', {testSetUpRanFirst})
  duTest('set up before each test', {testSetUpRunsEachTime})
  duTest('tear down after each test', {testTearDownAfterFailure})
  duEnd()

  IF duFinish() = FALSE THEN CleanUp(10)
ENDPROC
