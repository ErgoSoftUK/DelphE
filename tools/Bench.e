/*
** A small benchmark for comparing compilers and their optimisation switches: the syntax
** highlighter over the designer's own source, 200 times (string handling), and a prime sieve
** to 500000, 40 times (arithmetic and arrays). Run it from the tools folder. Times are in
** ticks, 1/50 second: on a fast emulator the loops are sized to take a few seconds.
*/

OPT LARGE

MODULE 'dos/dos', 'exec/memory', '*/src/Highlight'

PROC now()
  DEF ds: datestamp
  DateStamp(ds)
ENDPROC (ds.minute * 3000) + ds.tick

PROC primes(n)
  DEF flags: PTR TO CHAR, i, j, count
  flags := NewM(n + 1, MEMF_PUBLIC OR MEMF_CLEAR)
  count := 0
  FOR i := 2 TO n
    IF flags[i] = 0
      count++
      j := i + i
      WHILE j <= n
        flags[j] := 1
        j := j + i
      ENDWHILE
    ENDIF
  ENDFOR
ENDPROC count

PROC main()
  DEF fh, size, buf, i, t, out, c
  size := FileLength('/src/designer/Designer.e')
  IF size <= 0
    WriteF('Run this from the tools folder: it reads ../src/designer/Designer.e\n')
    RETURN
  ENDIF
  buf := NewM(size + 2, MEMF_PUBLIC OR MEMF_CLEAR)
  fh := Open('/src/designer/Designer.e', MODE_OLDFILE)
  Read(fh, buf, size)
  Close(fh)

  t := now()
  FOR i := 1 TO 200
    out := highlightText(buf, size)
    IF out THEN FreeVec(out)
  ENDFOR
  WriteF('highlight 200 x \d bytes: \d ticks\n', size, now() - t)

  t := now()
  FOR i := 1 TO 40
    c := primes(500000)
  ENDFOR
  WriteF('primes below 500000, 40 times: \d found, \d ticks\n', c, now() - t)
ENDPROC
