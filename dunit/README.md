# DUnit

A small unit test framework for Amiga E, in the style of JUnit and NUnit. It needs nothing but the
`dos.library`, so it works from a shell, in a build script, or from a watcher.

## A test

A test is a procedure with no arguments that calls asserts. E has no reflection, so each test is
registered by hand with the address of its procedure, `{name}`:

```
MODULE '*/dunit/DUnit'

PROC testAddition()
  assertEquals(4, 2 + 2, 'two and two')
ENDPROC

PROC main()
  duBegin('Arithmetic')
  duTest('addition', {testAddition})
  duEnd()
  IF duFinish() = FALSE THEN CleanUp(10)
ENDPROC
```

The report prints a dot for each test that passes, `F` for a failure and `E` for an error, then the
totals and the details of anything that went wrong:

```
Demo: .FE.  (4 tests)

Tests run: 4, passed: 2, failures: 1, errors: 1  (0.00 s)
FAIL  Demo / fails
      greeting: expected <hello> but was <help>
ERROR Demo / raises an exception
      unexpected exception: something went wrong
FAILED
```

A **failure** is a failed assert. An **error** is any other exception the test raised, `Raise('text')`,
a code such as `"NIL"`, or a number. `duFinish()` returns TRUE if everything passed, so `CleanUp(10)`
gives the shell a return code to test.

## The asserts

The last argument of every assert is a message, or NIL for none.

| Assert | Passes when |
|---|---|
| `assertTrue(cond, msg)`, `assertFalse(cond, msg)` | the condition is true or false |
| `assertEquals(expected, actual, msg)` | two numbers are equal |
| `assertNotEquals(unexpected, actual, msg)` | they differ |
| `assertInRange(value, lo, hi, msg)` | `lo <= value <= hi` |
| `assertStrEquals(expected, actual, msg)` | two strings are equal; two NILs are equal |
| `assertStrNotEquals(unexpected, actual, msg)` | they differ |
| `assertContains(part, text, msg)` | `text` contains `part` |
| `assertNil(p, msg)`, `assertNotNil(p, msg)` | the pointer is NIL or not |
| `assertMemEquals(a, b, len, msg)` | `len` bytes are the same |
| `assertRaises({proc}, exception, msg)` | the procedure raises exactly that exception |
| `assertNoRaise({proc}, msg)` | the procedure raises nothing |
| `fail(msg)` | never: it always fails the test |

## Suites and fixtures

`duBegin(name)` starts a suite and `duEnd()` runs it; use as many as you like in one program, and
`duFinish()` adds them up. `duSetUp({proc})` and `duTearDown({proc})`, called after `duBegin`, give a
procedure that runs before and one that runs after each test of that suite. The teardown runs even
when the test failed.

## Files

- `DUnit.e`: the framework, a module. Compile it first (`ec DUnit` in this folder).
- `SelfTest.e`: DUnit tested with DUnit.
- `Demo.e`: a suite with a failure and an error, to see what a report looks like.

## Notes

- **Compilers.** It works with `ec` and with E-VO. E-VO warns "variable used as function" for the one
  line that calls a registered test; that is how it is meant to work.
- **Module paths.** The `*` in a module path means the folder of the source file for `ec`, and the
  current folder for E-VO: compile from the folder the test is in and both agree.
- **Messages.** The text of a failed assert is built in a buffer that holds about 400 characters.
- **One thread.** A test runs in the program's own task: DUnit does no multitasking and does not
  catch a crash, only exceptions.
