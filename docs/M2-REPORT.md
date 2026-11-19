# M2: core functionality and relocation

M2 (docs/DESIGN.md, section 7; tracking issue #10) makes the development
build behave like an installable DOS program and checks the language
basics on an emulated 8086. It fixes the 16-bit defects M0 found, gives
the interpreter a stack that reports overflow instead of crashing, and
derives `@INC` from where `PERL.EXE` is. It also makes `-e` safe, settles
globbing and `-P`, and pins the parser. [DOS.md](DOS.md) is the
user-facing account of how the result behaves. This report has the
decisions and the evidence.

Nothing here is a release. `build/dev/PERL.EXE` is still linked with Open
Watcom's C runtime and must not be published (DESIGN.md, section 8).

Measured on 2026-11-16 with Open Watcom 2026-10-01-Build (libc16 0.04's
pin), DOSBox-X 2026.01.02 (CGA machine, normal core, `cputype=8086`),
Bison 3.8.2, and Perl 3.044 plus `patches/0001`–`0008`. The development
build is 282,204 bytes, sha256
`8fc09f0887e2a9c0…`. Section 12 has the commands that reproduce every
number.

## 1. Summary

- **Language basics work** on an emulated 8086:
  - smoke tests: 21 of 22 pass (`make test`, `tests/smoke`);
  - `tests/run-install`: 35 install and relocation cases pass;
  - Perl 3.044's own `t/` suite: 53 of 72 scripts pass, the same as M1;
    the other 19 need Unix (section 3).
  - One known failure is left: `fpfmt`, Open Watcom's `printf` rounding,
    which goes with the runtime in M3.
- **16-bit defects fixed** (patch 0005, section 3.2):
  - `pack`/`unpack` `N`;
  - `pack` of out-of-range numbers;
  - `vec()` 16 and 32;
  - hashes of more than 409 keys;
  - `sleep` with no argument.
- **`str_gets()`** (patch 0006, issue #9): its buffer is 512 bytes, not
  8 KB of DGROUP, and lines with NUL bytes are no longer truncated.
- **The stack** (issues #7 and #8, section 4). The default build now has:
  - `-DCRIPPLED_CC`;
  - `msdos/stk16.asm`'s reporting stack check;
  - a 51 KB stack, sized to leave 2 KB of DGROUP free for child
    processes.

  Simple recursion goes 149 levels deep (M1: 33), and 66 with `local()`
  (M1: 11). Overflow prints `Stack overflow` and exits with status 255,
  where M1 crashed DOS. The executable is 16,880 bytes smaller, and 6%
  slower.
- **`@INC`** (section 5): `-I` directories, then
  `<directory of PERL.EXE>\LIB`, then `.`. The directory comes from the
  pathname DOS 3.x puts after the environment, made absolute. It is right
  for every invocation in DESIGN.md's table, from other drives, and from
  unrelated and read-only current directories.
- **`-e`** (issues #3 and #4, section 6):
  - the file is created exclusively (INT 21h/5Bh) in `TEMP`, `TMP` or
    the current directory;
  - a clear error and nonzero status if none works;
  - always removed.
- **Glob** (section 7): done in-process. There is no `GLOB.EXE`; the
  historical port's helper was never found under the name Perl ran.
- **`-P`** (section 8): refused with a clear message, since it needs
  `sed` and a C preprocessor.
- **DOS policy** (section 8): unsupported Unix operations die with a
  message `eval` can catch. `tests/smoke/unsupp.pl` lists them, and
  DOS.md says how to tell them from bugs.
- **Parser pinned** (issue #2, section 9): Bison 3.8.2, and the generated
  `perl.c` and `perly.h` are checked against `upstream/parser.sha256`.

## 2. What changed

| Change | Files | Section |
|---|---|---|
| 16-bit `int` defects | `patches/0005-16bit-int.patch` | 3.2 |
| `str_gets()` buffer and NUL bytes | `patches/0006-str-gets.patch` | 3.3, 4 |
| `@INC`, `-e`, `-P` | `patches/0007-dos-inc-etemp.patch`, `msdos/exepath.c`, `msdos/etemp.c` | 5, 6, 8 |
| glob | `patches/0008-dos-glob.patch`, `msdos/dosglob.c` | 7 |
| stack check, `CRIPPLED_CC`, 51 KB stack | `Makefile`, `msdos/stk16.asm`, `scripts/check-dgroup` | 4 |
| parser pin | `scripts/yacc-perl`, `upstream/parser.sha256` | 9 |
| tests | `tests/run-install`, `tests/tools/{exetest,etemptst,err2out}.c`, `tests/smoke/*` | 11 |

`msdos/mktemp.c` is gone: nothing calls `mktemp()` any more. Upstream
files are still changed only by `patches/`, and each patch's header
explains it (docs/PROVENANCE.md).

## 3. Language functionality

### 3.1 Coverage

| Area | Tests |
|---|---|
| scalars, numbers, strings | `scalars`, `printf`, `fpfmt` (todo) |
| arrays, lists | `arrays` |
| hashes, including past the old 409-key limit | `hashes`, `hashbig` |
| control flow, subroutines, `eval`/`die` | `control` |
| recursion and its limit | `recurse`, `stackovf` |
| regular expressions, `tr`, `split` | `regex` |
| formats | `format` |
| text and binary files, file tests, `rename`, `unlink` | `files`, `lines` |
| `pack`, `unpack`, `vec` | `packn`, `vec32` |
| `require`, `do FILE`, `%INC` | `require`; `tests/run-install` for `@INC` and `-I` |
| `-e`, `-v` | `eopt`, `version`; `tests/run-install` for `TEMP`/`TMP` |
| exit status (errorlevel) | `status`, `stackovf`; every `run-install` case |
| `%ENV` and child processes | `environ` |
| globbing | `glob` |
| unsupported operations | `unsupp` |

Perl 3.044's `t/` suite (`make test-t`) gives the same 53 of 72 as in M1,
against the same `tests/t-baseline.txt`. The 19 failures need `fork`,
pipes to processes, signals, Unix shell commands, links, `/dev/tty`, `cpp`
or CPU times (docs/M1-REPORT.md, section 3). None of M2's fixes was
caught by a `t/` script, because the suite has no case past 16-bit
limits.

### 3.2 Defects fixed (patch 0005)

Each is in upstream code and shows with any 16-bit `int`. The historical
Microsoft C port probably had them too.

| Defect | Cause | Test |
|---|---|---|
| `pack("N")`/`unpack("N")` lost the high 16 bits | `my_htonl()`, `my_ntohl()` return `long` but were called undeclared | `packn` |
| `pack("n", 65535)` packed 32768 | `(short)` of a double: Open Watcom converts through 16 bits and gives 0x8000 when out of range. The same for `c`, `C`, `s`, `S`, `i` | `packn` |
| `vec($v, 0, 32)` lost its top half; `vec(…, 16)` was negative from 0x8000 | an `unsigned char`, promoted to 16-bit `int`, shifted by 8, 16 and 24 | `vec32` |
| a hash with more than about 409 keys died with "Reallocation too large" | `tbl_max * FILLPCT` overflowed at 512 buckets, so every store split the table | `hashbig` (1,500 keys, deletes, `each`) |
| `sleep` with no argument | `(32767<<16)+32767` in an `int` | — |

The hash table also stops doubling at 8,192 buckets (32 KB). One more
doubling would exceed the 64 KB block limit and be fatal, so beyond that
the chains get longer. Memory runs out before that matters: 3,000 keys
already exhausted DOSBox-X's 640 KB in the first version of `hashbig`.

### 3.3 `str_gets()` (patch 0006, issue #9)

Without `STDSTDIO`, `str_gets()` reads characters into a static buffer and
copies it into the string, looping for longer lines. The loop was already
right for any line length. The buffer only sets how many passes a long
line takes, so 512 bytes is enough. `tests/smoke/lines.pl` reads lines of
0 to 5,000 characters, including every length from 507 to 512 and 1,019
to 1,021 around the buffer's edges. It also reads paragraph mode across
the edge, and a last line with no newline. Its expected output came from
the M1 build, which had the 8 KB buffer.

The same test found a second defect. The copy used `str_set()` and
`str_cat()`, which stop at a NUL byte, so a line read from a binary file
lost the rest of the line, and a line starting with NUL read as end of
file. The DOS path now copies by length, as the Unix (`STDSTDIO`) code
does.

Effect: DGROUP's BSS fell from 11,916 to 4,240 bytes, and the space went
to the stack (section 4). Reading speed is unchanged (section 4.4).

## 4. The stack (issues #7, #8, #9)

### 4.1 The default build

| | M1 (`main`) | M2 |
|---|---|---|
| compiler flags | `-ml -0 -zc` | plus `-DCRIPPLED_CC` |
| stack check | Open Watcom's `__STK` | `msdos/stk16.asm`, 2,048-byte margin |
| stack | 32,768 | 52,224 (51 KB) |
| `str_gets()` buffer | 8,192 | 512 |
| `PERL.EXE` | 299,084 | 282,204 |
| load image | 328,640 | 323,536 |
| code | 277,490 | 260,607 |
| DGROUP | 51,136 | 62,928 |
| DGROUP free | 14,400 | 2,608 |

`scripts/check-dgroup` reads the map at link time and fails the build if
less than `DGROUP_MIN_FREE` (2,048) bytes of DGROUP are left. Static data
that grows can't then quietly eat the space child processes need. To
build with other values, run `make STACK=... STK16_MARGIN=...
DGROUP_MIN_FREE=...`.

### 4.2 How much DGROUP to leave free

M1 found that with 64 bytes of DGROUP free, child processes fail, and
with 1,088 they work. Open Watcom's spawn path takes a little near heap.
The M2 objects were linked with stacks from 51 KB to 53.5 KB. `system`
and backticks were run with the DOSBox-X environment (131 bytes), then
with 650 bytes of extra variables (as much as its shell allows):

| Stack | DGROUP free | `system`, backticks, small environment | large environment |
|---|---|---|---|
| 51 KB | 2,624 | work | work |
| 53,500 bytes | 1,348 | work | work |
| 53 KB | 576 | fail (−1) | work |

The failure isn't even monotonic in the environment's size, so the
threshold isn't simply the environment's copy. 2 KB free is about twice
the smallest margin that worked. That gives the 51 KB stack, 2,608 bytes
free in the final build.

### 4.3 Recursion

`scripts/stack-probe`, deepest recursion that finishes, and what happens
one level deeper:

| Build | simple | `local()` | string |
|---|---|---|---|
| M1 `dev`: 32 KB, no `CRIPPLED_CC`, Watcom `__STK` | 33, crash | 11, crash | 37, crash |
| M1 `crip`: 32 KB, `CRIPPLED_CC` | 101, crash | 56, crash | 80, crash |
| M1 `rec`: 45 KB, `CRIPPLED_CC`, `stk16` | 131, reported | 58, reported | 106, reported |
| **M2 default**: 51 KB, `CRIPPLED_CC`, `stk16` | **149, reported** | **66, reported** | **121, reported** |

- "Reported" means `Stack overflow` on standard error and exit status
  255, with DOS intact.
- `CRIPPLED_CC` gives most of the depth, by shrinking `eval()`'s frame
  from 780 to 186 bytes. The stack size and the smaller buffer give the
  rest.
- `tests/smoke/recurse.pl` checks 120 simple levels, 50 with `local()`
  and `fib(15)`, with margin below the measured limits.
- `tests/smoke/stackovf.pl` recurses without limit and checks the
  message and status.

### 4.4 Cost

Emulated seconds at 4.77 MHz (`scripts/bench`):

| seconds | startup | arith | string | regex | hash | subs | read | bigint | bigint vs M1 |
|---|---|---|---|---|---|---|---|---|---|
| M1 | 0.3 | 15.9 | 8.4 | 9.0 | 13.0 | 13.5 | 9.9 | 149.1 | — |
| M2 | 0.3 | 18.6 | 9.1 | 9.3 | 13.7 | 14.5 | 10.0 | 158.4 | +6% |

- M2 is 6% slower overall, as M1 measured for its `rec` variant:
  `CRIPPLED_CC` costs about 2% (13% in floating-point arithmetic, where
  `str_gnum` was inline), and the reporting check about 3%.
- `read`, the new workload (a 60 KB file, 608 lines, 8 of them 3,000
  characters long), is within a tick: the 512-byte buffer costs nothing
  measurable.

Conventional memory needed, in KB (`scripts/mem-probe`: the smallest DOSBox-X
`dos mem limit` that runs the workload, then what DOS had free for a
program at that limit):

| Workload | M1 | M2 |
|---|---|---|
| `perl -v` | 364 (331.7 free) | 352 (319.7) |
| short script: scalars, a 300-key hash, a regex, a sub | 408 (375.7) | 408 (375.7) |
| `t/lib.big` (`bigint.pl`, 246 tests) | 440 (407.7) | 440 (407.7) |
| 1,000 strings of 100 bytes in an array | 504 (471.7) | 496 (463.7) |

The 19 KB larger stack costs no memory overall. The code is 17 KB
smaller, and the 7.5 KB `str_gets()` buffer and the near heap that
DGROUP's headroom used to hold make up the rest. `perl -v` needs 12 KB
less than M1, and no workload needs more.

### 4.5 Physical hardware

Not tested: no 8088 machine was available for M2. Everything here is
DOSBox-X. The stack check doesn't depend on timing, but the DGROUP margin
for child processes should be confirmed on real DOS 3.3 and 6.22, whose
`COMMAND.COM` and EXEC differ from DOSBox-X's. That is a release check
(M4).

### 4.6 Compatibility with libc16 (M3)

The choices are build options, not code that assumes Open Watcom:

- `CRIPPLED_CC` is upstream's.
- The stack size is a linker option.
- `stk16.asm` depends only on Open Watcom's `__STK` calling convention
  (frame size in AX) and `__STACKLOW`.

libc16's startup will have to provide `__STACKLOW`, or `stk16.asm` will
have to change with it. The 2 KB DGROUP margin is a property of Open
Watcom's spawn and has to be measured again against libc16's.

## 5. `@INC` from the executable's directory

### 5.1 How it works

`msdos/exepath.c`, called from `main()` (patch 0007):

1. If DOS is 3.0 or later, find the PSP (INT 21h/62h) and the
   environment segment at PSP:2Ch.
2. Read the environment block only up to the end of its DOS memory block,
   when the arena header before it looks valid, and at most 32 KB. Skip
   the strings to the empty one, and check the word after it, which must
   be nonzero. The pathname after that is accepted only if it is
   terminated, non-empty, shorter than 144 bytes and free of control
   characters.
3. Otherwise use `argv[0]`, if it has a drive or a directory in it.
4. Make the name absolute:
   - `X:\...` stays as it is.
   - `\...` gets the current drive (INT 21h/19h).
   - `X:NAME` gets the current directory of X: (INT 21h/47h), so a
     drive-relative name keeps its DOS meaning.
   - `NAME` gets the current drive and directory.

   Perl hasn't changed directory yet, so these are the loader's. Nothing
   else is normalised. DOS resolves `.` and `..` itself.
5. Replace the file name with `LIB`.
6. Push the result between the `-I` directories and `.`. If any step
   fails, push nothing.

`PRIVLIB` is not used on DOS. The only other uses of `PRIVLIB` and `BIN`
in Perl 3 are `-P` (section 8), `sperl`/`tperl` re-execution (`DOSUID`
and `TAINT`, neither defined on DOS) and `unexec` (not defined). So none
needs a DOS path.

### 5.2 What was tested

`tests/run-install` installs `PERL.EXE` as `C:\PERL\PERL.EXE` and
`D:\TOOLS\PERL\PERL.EXE`, each with a `LIB\RELOC.PL` that names its
installation. A `RELOC.PL` in the current directory and another in an
`-I` directory check precedence. Each case prints `@INC` and which
`RELOC.PL` `require` loaded:

| Case | Current | Command | `@INC` |
|---|---|---|---|
| PATH, from another drive | `C:\WORK\SUB` | `perl` (PATH=`D:\TOOLS\PERL`) | `D:\TOOLS\PERL\LIB;.` |
| PATH in lower case | `C:\WORK\SUB` | `perl` (PATH=`d:\tools\perl`) | `D:\TOOLS\PERL\LIB;.` |
| absolute, other drive | `C:\WORK\SUB` | `D:\TOOLS\PERL\PERL.EXE` | `D:\TOOLS\PERL\LIB;.` |
| drive-relative | `C:`, with D: at `\TOOLS\PERL` | `D:PERL.EXE` | `D:\TOOLS\PERL\LIB;.` |
| drive-relative with directory | D: at `\TOOLS` | `D:PERL\PERL.EXE` | `D:\TOOLS\PERL\LIB;.` |
| root-relative | `C:\WORK\SUB` | `\PERL\PERL.EXE` | `C:\PERL\LIB;.` |
| root-relative on D: | `D:\TOOLS\PERL` | `\TOOLS\PERL\PERL.EXE` | `D:\TOOLS\PERL\LIB;.` |
| relative | `C:\` | `PERL\PERL.EXE` | `C:\PERL\LIB;.` |
| relative with `..` | `C:\WORK\SUB` | `..\..\PERL\PERL.EXE` | `C:\PERL\LIB;.` |
| relative on D: | `D:\TOOLS` | `PERL\PERL.EXE` | `D:\TOOLS\PERL\LIB;.` |
| read-only current drive | `E:\RO` | `D:\TOOLS\PERL\PERL.EXE` | `D:\TOOLS\PERL\LIB;.` |
| `-IC:\WORK\ALT` | | | `C:\WORK\ALT;D:\TOOLS\PERL\LIB;.`, `-I` wins |
| `-I C:\WORK\ALT -I.` | | | `C:\WORK\ALT;.;D:\TOOLS\PERL\LIB;.` |
| no `RELOC.PL` in `LIB` | | | `.`'s is found |
| `-e "require ..."` | | | `LIB`'s is found |

DOSBox-X's shell passes EXEC a fully qualified name in every case: the
`..` case arrives as `C:\PERL\PERL.EXE`. So the resolution in step 4 is
there for other loaders. `tests/tools/exetest.c` tests it directly, under
DOS, with C: at `\WORK\SUB` and D: at `\TOOLS\PERL`. It feeds
`exepath_from_env()` well-formed environment blocks (with strings,
without, with a relative name) and malformed ones:

- a count of 0;
- no end to the strings;
- no count;
- an unterminated name;
- an empty name;
- a control character;
- a null block;
- a name longer than the limit.

It also checks `exepath_absolute()` on every form of name, including an
invalid drive, and `exepath_libdir()`. A loader that leaves the
environment malformed can't be arranged from `COMMAND.COM`, which is why
this is a unit test.

## 6. `-e` temporary files (issues #3 and #4)

Perl 3 runs `-e` by writing the lines to a file. The historical port used
`mktemp("plXXXXXX")` in the current directory. That has three faults:

- it fails on a read-only drive;
- `mktemp` only checks that a name is free, so another program could
  take the name between the check and the open;
- perl16's M0 `mktemp` counted up from `pl000000`, so the names were
  predictable.

`msdos/etemp.c` instead does this:

- **Directories:** `TEMP`, then `TMP`, then the current directory. Unset
  or empty variables are skipped. If creation in a directory fails for
  any reason (path not found, access denied, too long), the next is
  tried. If none works: `Can't create temporary file for -e in DIR:
  REASON`, nonzero exit status. `TEMP` may end in `\`, or be a bare
  drive (`D:`), which means that drive's current directory.
- **Names:** `PLxxxxxx.TMP`, with six base-32 digits from a linear
  congruential generator. It is seeded from the BIOS tick count, the PSP
  segment and the time.
- **Creation:** INT 21h/5Bh, "create new file", which fails if the name
  exists. An existing file is never opened or truncated, and checking
  and creating are one operation. A name that exists is retried with the
  next name, 32 times per directory, before that directory counts as
  failed. Open Watcom's `open(O_CREAT|O_EXCL)` was not used:
  disassembled, it opens (3Dh) and then creates (3Ch), which is the same
  race again.
- **Writing:** the handle goes to stdio with `_hdopen()` and `fdopen()`.
  An error writing or closing the file is fatal and removes it, rather
  than running a truncated script.
- **Cleanup:** as before, Perl removes the file after compiling the
  script, or in `fatal()` if it dies first. That covers syntax errors,
  `die` and `exit`. `tests/run-install` checks that no `PL*.TMP` is left
  anywhere after all its cases.

`tests/run-install` covers `TEMP`, `TEMP` with a trailing `\`, `TMP`
alone, an invalid `TEMP` falling back to `TMP` and to the current
directory, `TEMP` as a bare drive, and neither variable set. It also
covers a read-only current drive with and without `TEMP` (the error
message and status), syntax errors, `die`, `exit 3`, and several `-e`
options. `tests/tools/etemptst.c` compiles `etemp.c` with a fixed seed,
so every call tries the same names in order. It checks that 33 calls get
33 distinct files, that no file's contents were touched by a later call,
and that the 33rd lands in the next directory, after the 32 names in
`TEMP` are taken.

Limitations: DOS has no permissions, so any program can still read,
change or delete the file while Perl runs. Exclusive creation prevents
collisions, not interference. On a write-protected floppy DOS raises a
critical error ("Abort, Retry, Fail?") before Perl sees anything.
Installing an INT 24h handler is runtime work for M3.

## 7. Globbing and `GLOB.EXE`

Perl 3 globs by reading a command's output: `perlglob PATTERN |` on
MS-DOS (`evalargs.xc`), with NUL-separated names. The historical port
built its helper as `glob.exe`, so `<*.c>` never worked as shipped
(docs/M0-AUDIT.md, section 4). A helper also costs a child process. That
means `COMMAND.COM`, the helper's own memory beside Perl's, and the
limits section 4.2 measured.

**Decision: no helper.** `msdos/popen.c`'s `mypopen()` (patch 0008)
recognises `perlglob PATTERNS`. It writes the expansion itself, with
`msdos/dosglob.c`, to the temporary file it would have run a command
into. Nothing else about globbing or piped opens changes, so the result
is what `glob.exe` would have printed, made deterministic:

- Words are split on blanks.
- A word without `*` or `?` is passed through, like a shell.
- Otherwise DOS matches the last component, with INT 21h find
  first/next. These are DOS's rules: `*.*` matches every name, and `*`
  only names without an extension. Directories match; hidden and system
  files, `.` and `..` don't.
- Matches are sorted and lower-cased, as `msdos/directory.c`'s `readdir`
  does, and written after the word's directory part as given.
- No match gives nothing.

The DTA is saved and restored around the search.

`tests/smoke/glob.pl` checks extensions, `*.*` against `*`, `?`, `/` and
`\`, a directory, no match, a literal word, an interpolated pattern, a
`while (<...>)` loop, and that `$/` is restored. `t/op.glob` still fails
its test 1, which compares with `echo op.*` (`COMMAND.COM` doesn't
expand it), and passes the rest.

## 8. `-P`, and Unix operations on DOS

**`-P`** pipes the script through `sed` and `CPPSTDIN` (`cc -{`, a
Microsoft C option) with `-I` and `PRIVLIB`. DOS has neither program, and
no 16-bit C preprocessor that takes those options is commonly
installed. Under MSDOS, `-P` is now a fatal error: `-P is not supported
on MS-DOS (it needs sed and a C preprocessor)`. Before, it failed later
and less clearly. `tests/run-install` checks the message and status.
`t/comp.cpp` fails as before.

**Policy for DOS-inapplicable operations.** Perl 3 already compiles most
Unix-only operations under MSDOS to `fatal("Unsupported function
NAME")`, or a similar message. perl16 keeps that and makes it the
policy:

1. An operation DOS can't provide **dies with a message naming it**,
   catchable by `eval`, with no crash and no silent wrong result. These
   are intentional limitations. DOS.md lists them, and
   `tests/smoke/unsupp.pl` checks every message, so any change is
   noticed. They are: `fork`, `wait`, `kill`, `alarm`, `pipe`,
   `getppid`, `umask`, `chown`, `link`, `symlink`, `readlink`, `chroot`,
   the socket functions, the password and group functions, `getlogin`,
   `truncate`, `fcntl`, System V IPC, four-argument `select`, `-T`/`-B`
   on filehandles, `-i` without a backup extension, and `-P`.
2. An operation DOS can **approximate** does so, and DOS.md says how:
   - `system`, `exec` and backticks spawn, through `COMMAND.COM` for
     redirection.
   - Piped opens run sequentially through a temporary file.
   - `sleep` polls the clock.
   - IDs are 0.
   - `chmod` sets only the read-only attribute.
   - `stat` has no inodes or owners.
3. **Anything else is a regression** to be fixed: a crash, a hang, a
   nonzero exit without a message, or a wrong result where Perl 3 on
   Unix is right. The `t/` baseline (`tests/t-baseline.txt`) records why
   each failing script fails. A new failure, or a different one, fails
   `make test-t`.

## 9. Parser reproducibility (issue #2)

`scripts/yacc-perl` requires `bison --version` to report 3.8.2. It runs
`bison -y -d`, keeps the conflict-count check, and compares `perl.c` and
`perly.h` with `upstream/parser.sha256`. A different Bison, or a changed
`perl.y`, fails with a message that says what to do. The script's header
gives the procedure for moving the pin (`YACC_PERL_UPDATE=1`). `BISON=`
selects another binary.

CI installs Ubuntu 24.04's `bison`, which is 3.8.2. Two builds from clean
in different directories give identical parser files and an identical
`PERL.EXE`. The M1 build, rebuilt from `main` in a separate worktree,
reproduced M1's `PERL.EXE` byte for byte (sha256 `5edef575…`). The
upstream source tarball's sha256 is recorded in `docs/PROVENANCE.md`.
Building Bison from that tarball in the build (a tool bootstrap) is not
done. The version check and the output hash make any Bison that
produces different code fail instead.

## 10. Memory and limits

- **Image:** 323,536 bytes loaded. Conventional memory needed: section
  4.4. A 512 KB machine runs small scripts. 640 KB is the realistic size,
  as in M1.
- **Recursion:** 149 simple levels, 66 with `local()`, then a reported
  overflow.
- **One object:** a string, an array's pointer table, or a hash's bucket
  table is limited to 64 KB. Hash tables stop growing at 8,192 buckets.
- **Children:** a child process needs its own memory beside Perl's
  (DOS error 8 otherwise). Small DOS commands fit. A second `PERL.EXE`
  doesn't, on 640 KB.

## 11. Testing

| Target | What | Time |
|---|---|---|
| `make test` | `tests/run-dos` on `tests/smoke` (22 cases, one DOSBox-X session each), then `tests/run-install` (35 cases in one session, with C:, D: and a read-only E:) | about 2 minutes |
| `make test-t` | Perl 3.044's `t/` against `tests/t-baseline.txt` | about 2.5 minutes |

`tests/run-install` needs three small DOS programs, which `make test`
builds from `tests/tools`. They are linked with Open Watcom's runtime
like `PERL.EXE`, and likewise never published:

- `EXETEST.EXE` and `ETEMPTST.EXE`, the unit tests above;
- `ERR2OUT.EXE`, which runs a command with standard error sent to
  standard output. DOS can't redirect standard error, and a second
  `PERL.EXE` won't fit beside the first to capture it.

## 12. Remaining limitations and release blockers

For M3 (runtime migration):

- `fpfmt`: Open Watcom's `printf` rounding.
- A critical-error (INT 24h) handler, so that a write-protected disk
  fails without a prompt.
- Piped-open temporary files use Open Watcom's `tempnam()` (`TMP`, else
  the root) rather than `-e`'s order.
- `stk16.asm`'s dependence on `__STACKLOW`, and the DGROUP margin, to be
  measured again against libc16 (section 4.6).

Not investigated in M2:

- `sort { … } LIST`, which is Perl 4 syntax, hangs the parser instead of
  giving a syntax error (docs/M0-AUDIT.md, section 9). It still needs
  comparing with a Unix Perl 3 build to tell whether it is a port bug.

For M4 (release):

- Physical hardware, and real DOS 3.3 and 6.22, for the stack margin and
  the EXEC pathname forms (sections 4.5 and 5.2).
- No binary in this report may be published.

## 13. Reproducing

Since M3, `make` builds the runtime build (M3-REPORT.md). The commands
below are as they were for M2; today they are `make dev`, `make
test-dev` and `make test-t-dev`.

    make                  # build/dev/PERL.EXE (prints the DGROUP check)
    make test             # smoke tests and install tests
    make test-t           # t/ suite
    make variants         # build/var/*: the M1 variants from the current
                          # source, and FREEMEM.EXE and TICKS.EXE
    perl scripts/stack-probe build/dev/PERL.EXE
    perl scripts/bench build/var/TICKS.EXE build/upstream/perl-3.044 \
        M1/PERL.EXE build/dev/PERL.EXE
    perl scripts/mem-probe build/var/FREEMEM.EXE build/upstream/perl-3.044 \
        M1/PERL.EXE build/dev/PERL.EXE

`M1/PERL.EXE` is `make` run on commit `1ab1e35` (the M1 merge), for
example in a `git worktree` sharing `build/tools`, `build/upstream` and
`build/libc16`. The DGROUP experiment of section 4.2 relinks
`build/dev/*.obj` with `wlink option stack=N` and runs `system("echo
...")` and backticks with and without extra environment variables.
