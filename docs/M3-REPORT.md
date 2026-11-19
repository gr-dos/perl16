# M3: runtime migration

M3 (docs/DESIGN.md, section 7; tracking issue #12) replaces Open
Watcom's C runtime in `PERL.EXE` with independently written libraries:
libc16, the GR-DOS C runtime, and libkitchen16, created in M3.3 for
floating point, formatting and `<math.h>`. Since M3.4, `make` builds
that executable, the runtime build, and `make test` and `make test-t`
test it. The M2 development build is kept, as `make dev`, for
comparison. [DOS.md](DOS.md) is the user-facing account of how
`PERL.EXE` behaves. [M3-RUNTIME-AUDIT.md](M3-RUNTIME-AUDIT.md) has the
audit, the decisions and the history of each step. This report sums up
the result.

Nothing here is a release. M4 makes the release candidate (section 7),
and until it passes, no binary is published (DESIGN.md, section 8).

Measured on 2026-11-18 with:
- Open Watcom 2026-10-01-Build (libc16's pin), as compiler and linker
  only;
- libc16 0.15 and libkitchen16 0.02;
- DOSBox-X 2026.01.02 (CGA machine, normal core, `cputype=8086`);
- Bison 3.8.2, and Perl 3.044 plus `patches/0001`–`0012`.

The runtime build is 263,310 bytes, sha256 `57c1266c94635fc7…`.
Section 8 has the commands that reproduce every number.

## 1. Summary

- **No Open Watcom runtime.** `PERL.EXE` is linked from perl16's 32
  objects, libc16's large-model library and libkitchen16's, with
  `option nodefaultlibs` (section 3).
  - **`scripts/check-link`** fails the link if the map has a module or
    library from anything else, or an object asks for a default
    library.
  - **`scripts/check-provenance`** fails it if a linked library module
    has no entry in its library's provenance record.
- **The same behaviour as M2, and better where M2 fell short** (section
  2):
  - `fpfmt` passes: numbers are formatted and converted correctly
    rounded, as Perl 3 does on Unix.
  - Comparisons are right with NaNs, infinities, `-0.0` and subnormals.
  - A disk or printer error fails the call without DOS's prompt, and
    `$!` says why.
  - Piped-open temporary files go where `-e`'s do.
  - `system` and `exec` pass `%ENV`, and shell commands reach the
    shell as written.
- **Tests** (section 5):
  - `make test`: 25 of 25 smoke tests, 7 of 7 of the runtime build's
    own, 36 of 36 installation cases, and check-link's own test;
  - `make test-t`: 53 of 72 `t/` scripts, M2's baseline.
- **Size and memory** (section 4): the executable is 18,470 bytes
  smaller than the development build's. It needs 12 to 16 KB less
  conventional memory, and recursion goes about 40% deeper.
- **Speed** (section 4.5): slower than M2, chiefly in floating-point
  arithmetic (software floating point instead of an emulated 8087) and
  output (libc16 doesn't buffer it, gr-dos/libc16#34).

## 2. What changed

| Phase | What | Where |
|---|---|---|
| M3.1 | the runtime inventory, the ownership of every symbol, and the decisions: libkitchen16 go, `-fpc` software floating point, an INT 24h handler in perl16 | #13, #18; M3-RUNTIME-AUDIT.md sections 1–12 |
| M3.2 | libc16 0.08–0.15: `atexit`, `time`, `rand`, `dup`, `setjmp`, `system` and the spawn family, `signal`, the heap's quadratic time fixed, `libc16_systeme` | gr-dos/libc16#19–#22, #27, #30, #31; pinned in #19, #20 |
| M3.3 | libkitchen16 0.02: the `-fpc` helpers, the `printf` family, `strtod`, `<math.h>` | gr-dos/libkitchen16#1, #6; #15, #23 |
| M3.4 | the runtime build: perl16 compiled against both libraries' headers, its own DOS shims, and the switch to it | #16, #17, #20, #24, #25, #26, and this report's PR |

perl16's own code for the runtime build is in `msdos/`
([PROVENANCE.md](PROVENANCE.md)):
- `environ.c`, `exec16.c` and `p16init.asm`: `environ` and the `exec`
  family, which libc16 doesn't have;
- `harderr.c`: the INT 24h handler;
- `p16fp.c`: the numeric tests `wcc -fpc` gets wrong;
- `ctype16.c`: `<ctype.h>` as a table;
- `p16rt.h`: every library prototype, force-included;
- `stk16.asm`: the stack check, on libc16's memory layout.

`patches/0009` to `0012` adapt Perl's sources.

## 3. The link

The runtime build's link (Makefile, `$(RT)/PERL.EXE`) runs four checks.
A failure in any of them fails the build:

| Check | What fails it |
|---|---|
| `scripts/check-w131`, at each compile | a call of a libc16 or libkitchen16 function with no prototype in scope (`-wx`, W131), which would use the wrong calling convention |
| `scripts/check-dgroup` | fewer than 128 bytes of `DGROUP` left (section 4.2) |
| `scripts/check-link` | a module in the map from a file other than perl16's objects, `LIBC16L.LIB` and `LIBK16L.LIB`; a library in the map's "Libraries Used" other than those two; an object with a default-library record (an OMF comment of class 9Fh) |
| `scripts/check-provenance` | a module linked from either library that its `docs/LICENSE-PROVENANCE.md` doesn't mention |

The link as it is now:

| From | Modules |
|---|---|
| perl16's objects (`build/rt/*.obj`) | 30 (of 32: the map lists no module for `dump.obj`, which is empty, or `p16init.obj`, which holds only two entries of libc16's init table) |
| `LIBC16L.LIB`, libc16 0.15 | 103 |
| `LIBK16L.LIB`, libkitchen16 0.02 | 36 |

check-link's own test (`tests/link/run`, in `make test`) runs it on
fixture maps: an approved link passes, and one with a module and
library from `clibl.lib`, an unlisted object, a missing library or an
object with a default-library record fails. Against the development
build's map, check-link fails on every one of Open Watcom's modules and
its three libraries (`clibl.lib`, `math87l.lib`, `emu87.lib`), and on
each object's `emu87` and `math87l` records.

check-provenance finds every linked module in its library's record.
libc16's `systeme` and `envblock` (0.15, gr-dos/libc16#31) are in a
section of their own rather than a row of its Modules table, which it
reports as a warning. Every row of both tables says human review is
pending, which is for M4 (section 7).

The objects are compiled with `-zl -zld -x`, so they carry no
default-library records and see none of Open Watcom's headers. The
compiler emits calls only to helpers the two libraries provide: the
`-fpc` floating-point helpers are libkitchen16's, the integer helpers
(`__I4M`, `__U4D` and the rest) and startup are libc16's, and
`stk16.asm` provides `__STK`.

## 4. Size, memory and speed

### 4.1 Size

| | development (M2) | runtime (M3) |
|---|---|---|
| `PERL.EXE` | 281,780 bytes | 263,310 bytes |
| load image (map, "Memory size") | 323,152 | 309,856 |
| code (the map's `CODE` class) | 260,214 | 244,539 |
| `DGROUP` | 62,928: 10,704 static data, 52,224 stack, 2,608 free | 65,312: 11,040 static data, 54,272 stack, 224 free |

Of the runtime build's image, libkitchen16 is 30.8 KB and 2,000 bytes
of `DGROUP` (gr-dos/libkitchen16#6).

### 4.2 Stack and heap

- **The stack** is 53 KB, the most `DGROUP` holds beside the static
  data. The development build had to leave 2 KB of `DGROUP` free as
  near heap for child processes; libc16 needs none, so the stack takes
  it. `check-dgroup` keeps 128 bytes in reserve, so more static data
  fails the link before it can overflow `DGROUP`.
- **The stack check** (`stk16.asm`) keeps its 2 KB margin for library
  code, which isn't checked. A smaller margin bought only 4 to 6
  levels of recursion (M3-RUNTIME-AUDIT.md, section 11.7).
- **The heap** is libc16's, all far. It lies above the stack and grows
  `PERL.EXE`'s DOS memory block as it needs memory. It never gives
  memory back to DOS, so a child process gets least after Perl's
  largest use, as in M2.

### 4.3 Recursion

`scripts/stack-probe`: the deepest recursion that runs. One level more
is a reported `Stack overflow` (status 255) in every case, never a
crash.

| | simple sub | with `local()` | building a string |
|---|---|---|---|
| development (M2) | 149 | 66 | 121 |
| runtime (M3) | 206 | 103 | 158 |

Perl's own tests need 120 and 50. The runtime build's frames are
smaller and its stack 2 KB larger.

### 4.4 Memory

Conventional memory needed, in KB (`scripts/mem-probe`: the smallest
DOSBox-X `dos mem limit` that runs the workload, then what DOS had free
for a program at that limit):

| Workload | development (M2) | runtime (M3) |
|---|---|---|
| `perl -v` | 352 (319.7 free) | 340 (307.7) |
| short script: scalars, a 300-key hash, a regex, a sub | 408 (375.7) | 396 (363.7) |
| `t/lib.big` (`bigint.pl`, 246 tests) | 440 (407.7) | 424 (391.7) |
| 1,000 strings of 100 bytes in an array | 496 (463.7) | 480 (447.7) |

The runtime build needs 12 to 16 KB less for every workload: a smaller
image, and no near heap kept free in `DGROUP`. The development build's
figures are the same as M2's (M2-REPORT.md, section 4.4).

The memory a child process gets, from `system` (`scripts/child-mem`;
622,240 bytes are free from the command line):

| bytes free for a child | at Perl's start | holding 100 KB of strings | after freeing them |
|---|---|---|---|
| development (M2) | 278,624 | 139,328 | 139,328 |
| runtime (M3) | 297,616 | 160,512 | 160,512 |

A second `PERL.EXE` still doesn't fit beside the first on 640 KB (DOS
error 8).

### 4.5 Speed

Emulated seconds at 4.77 MHz (`scripts/bench`, 315 cycles per
millisecond; `LIBC=1` adds `print` and `ctype`):

| seconds | startup | arith | string | regex | hash | subs | read | bigint | print | ctype |
|---|---|---|---|---|---|---|---|---|---|---|
| development (M2) | 0.3 | 18.6 | 9.2 | 9.3 | 13.7 | 14.4 | 10.0 | 158.3 | 39.4 | 53.5 |
| runtime (M3) | 0.4 | 40.4 | 12.1 | 11.4 | 23.1 | 18.2 | 18.8 | 192.8 | 59.7 | 131.1 |
| runtime ÷ development | | 2.17 | 1.32 | 1.23 | 1.69 | 1.26 | 1.88 | 1.22 | 1.52 | 2.45 |

- **Arithmetic** is the largest cost. Every floating-point operation is
  a far call into libkitchen16's software floating point, where the
  development build ran inline 8087 code under Open Watcom's emulator.
  Perl 3's numbers are all `double`, so every workload pays some of
  it.
- **`print`** writes each item to DOS: libc16's output is unbuffered.
  Buffered output is proposed in gr-dos/libc16#34.
- **`ctype`** measures `\w`, `\s` and `\d` matching and the tokenizer.
  `msdos/ctype16.c`'s table saves 4–5% of it (M3-RUNTIME-AUDIT.md,
  section 11.7); the rest of its gap isn't measured yet.
- **`hash` and `read`** are 1.7 and 1.9 times slower, and where that
  goes isn't measured yet.

## 5. Testing

| Target | What | Result |
|---|---|---|
| `make test` | `tests/link/run`; `tests/run-dos` on `tests/smoke` and on `tests/smoke-rt` (one DOSBox-X session each case); `tests/run-install` (one session, with C:, D: and a read-only E:) | 6 of 6; 25 of 25; 7 of 7; 36 of 36 |
| `make test-t` | Perl 3.044's `t/` against `tests/t-baseline.txt` | 53 of 72, the baseline |
| `make test-dev` | the development build's smoke and installation tests | 24 pass, `fpfmt` todo; 35 of 35 |
| `make test-t-dev` | `t/` under the development build | 53 of 72 |
| `make audit` | the development build's objects, and the sources recompiled against both libraries' headers | all 25 sources compile |

CI runs `make`, `make test` and `make test-t` in its `test` job, and
the development build's targets and `make audit` in its `dev` job.

`tests/smoke-rt` has the cases only the runtime build passes:
- `system` with `%ENV` and quoted commands (`TAILTST.EXE`);
- the numeric comparisons (`FPCTST.EXE`);
- the INT 24h handler (`HARDTST.EXE`, which raises INT 24h itself,
  since DOSBox-X never does);
- the ctype table (`CTYPETST.EXE`);
- `FOPEN_MAX`.

`tests/run-install`'s unit tests of `exepath.c` and `etemp.c`
(`EXETEST.EXE`, `ETEMPTST.EXE`) and of `execl` (`EXECLTST.EXE`) are
built like the runtime build.

## 6. What still uses Open Watcom's runtime

None of these is part of `PERL.EXE` or of anything to be distributed:

- the development build (`make dev`) and the M1 variants (`make
  variants`), kept for comparison;
- `ERR2OUT.EXE` and `TAILTST.EXE`, small-model test tools that both
  builds' tests run, and `FREEMEM.EXE` and `TICKS.EXE`, the probes'
  tools;
- `make audit`, which inventories the development build's objects.

Open Watcom's compiler, assembler, linker and librarian are build
tools, which DESIGN.md, section 8 allows.

## 7. Remaining for M4

- **Physical hardware and real DOS 3.3 and 6.22.** Neither has been
  tested. They are needed for:
  - the stack margin (`STK16_MARGIN`);
  - the `EXEC` pathname forms (M2-REPORT.md, sections 4.5 and 5.2);
  - the INT 24h handler, end to end. DOSBox-X never raises a critical
    error, so a failing DOS call reaching `$!` through it is untested;
  - exit statuses through `COMMAND.COM`. DOSBox-X's returns its own
    status, so backticks and piped opens fail under it in both builds,
    and the tests use `system` with redirection instead.
- **Provenance review.** Both libraries' records say human review is
  pending for every module perl16 links (section 3), and libc16's
  `systeme` and `envblock` need rows in its Modules table.
- **perl16's own license** is still to be chosen (README.md;
  M0-AUDIT.md, section 3).
- **The package.** The layout (`PERL.EXE` and which of Perl 3's `lib`
  files go in `LIB`), the notices (Perl's GPL and `Copying`, libc16's
  and libkitchen16's MIT licenses), and the means to get the
  corresponding source. A release workflow that builds from a tag,
  runs the link checks and tests, and publishes only then.
- **Helpers.** `PERL.EXE` needs no helper program (there is no
  `GLOB.EXE`), so none is to be distributed. If one is added, it goes
  through the same checks.
- **Speed**, optionally: buffered output in libc16 (gr-dos/libc16#34),
  and a look at where the rest of the `ctype` and `arith` gap goes.
- **The development build.** Whether to keep `make dev` after the
  release candidate, as a reference, or drop it.
- **`sort { … } LIST`** still hangs the parser instead of giving a
  syntax error (M2-REPORT.md, section 12), and still needs comparing
  with a Unix Perl 3 build.

## 8. Reproducing

    make                  # build/rt/PERL.EXE, with the link checks
    make test             # check-link's test, smoke tests, smoke-rt,
                          # install tests
    make test-t           # t/ suite
    make dev test-dev test-t-dev audit
                          # the development build and its tests
    make variants         # FREEMEM.EXE and TICKS.EXE (and the M1 variants)
    perl scripts/stack-probe build/dev/PERL.EXE build/rt/PERL.EXE
    perl scripts/mem-probe build/var/FREEMEM.EXE build/upstream/perl-3.044 \
        build/dev/PERL.EXE build/rt/PERL.EXE
    perl scripts/child-mem build/var/FREEMEM.EXE build/dev/PERL.EXE \
        build/rt/PERL.EXE
    LIBC=1 perl scripts/bench build/var/TICKS.EXE build/upstream/perl-3.044 \
        build/dev/PERL.EXE build/rt/PERL.EXE

Section 4.1's sizes are from the file, and from `build/*/perl.map`: its
"Memory size", the sum of its `CODE` class's segments, and
`scripts/check-dgroup`'s line.
