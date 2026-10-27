/*
** A DUnit demonstration with a test that fails and one that raises an exception, to show
** what a report with problems looks like. It is not part of the build.
**
**   cd dunit
**   ec Demo        (or: evo Demo NOPROGRESS)
**   Demo
*/

MODULE '*DUnit'

PROC testPasses()
  assertEquals(4, 2 + 2, 'arithmetic works')
ENDPROC

PROC testFails()
  assertStrEquals('hello', 'help', 'greeting')
ENDPROC

PROC testErrors()
  Raise('something went wrong')
ENDPROC

PROC testAlsoPasses()
  assertTrue(StrLen('abc') = 3, NIL)
ENDPROC

PROC main()
  duBegin('Demo')
  duTest('passes', {testPasses})
  duTest('fails', {testFails})
  duTest('raises an exception', {testErrors})
  duTest('also passes', {testAlsoPasses})
  duEnd()
  IF duFinish() = FALSE THEN CleanUp(10)
ENDPROC
