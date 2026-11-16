# perl16 — M0 source and build audit

**Date:** 2026-11-15
**Milestone:** M0 (DESIGN.md, section 7)
**Status:** complete; findings below feed M1–M4

## 1. Summary

- The baseline is tag `perl-3.044` of the Perl repository (commit
  `27e2fb84680b9cc1db17238d5bf10b97626f477f`, tree
  `39824ce086ad815a976233d0edef5992b06e833c`). `scripts/fetch-upstream`
  fetches it and checks all 267 files against `upstream/MANIFEST.sha256`.
- Spinellis's own `perl3.0-44.tar.gz` is the same source as the tag, apart
  from 8.3 file names and whitespace. His `dospatch44` applies to the tag
  unchanged. Everything except its Makefile hunk is needed, and it is kept
  as `patches/0001-dospatch44.patch`.
- With two more small patches (`0002`, `0003`), every module compiles with
  Open Watcom in the large model. The result links against Watcom's stock
  runtime into a 299,052-byte `PERL.EXE`, which runs on an emulated 8086
  under DOSBox-X. That is the M1 exploratory build, reached early.
  `make` reproduces it byte for byte, from any directory.
- `make test` runs 15 smoke scripts: 10 pass, and 5 known 16-bit defects are
  recorded as `todo` (section 8).
- `make audit` lists 98 symbols the interpreter needs from a C runtime.
  libc16 0.04 provides 44 of them. The largest gaps are **floating point**
  (Perl 3 holds every number as a `double`) and a **complete `printf`
  family with floating-point conversions**, which `do_sprintf` and number
  stringification depend on (section 7).
- The 64 KB DGROUP fits only because `-zc` moves string literals into
  code segments. The historical 32 KB stack lives in DGROUP and limits
  Perl recursion to about 50 levels (section 6).

## 2. Baseline

| Source | Identity | Use |
|---|---|---|
| Tag `perl-3.044`, github.com/Perl/perl5 | commit `27e2fb84`, tree `39824ce0`, 267 files | the baseline (`scripts/fetch-upstream`) |
| `perl3.0-44.tar.gz`, Spinellis's DOS page | sha256 `982719e6…` | compared with the tag only |
| `dospatch44` (1999-01-10) | sha256 `8083cee5…` | `patches/0001` is derived from it |
| `README.msdos` | sha256 `755787b5…` | identical to the tag's `msdos/README.msdos` |

`scripts/fetch-reference` fetches the last three and checks them against
`upstream/reference.sha256`. They aren't needed to build.

**Tarball vs tag.** `diff -r` finds only:

- DOS renames: `config_h.SH`, `PACKINGLIST@44`, `perl_man.[1-4]`.
- `t/op.subst` and `lib/nsyslog.pl` are absent from the tarball.
- One trailing space in `lib/syslog.pl`.
- Two `/*NOSTRICT*/` comments in `x2p/hash.c`.

None of these affects the interpreter, so the tag is the better baseline:
it is canonical and verifiable by hash.

**dospatch44, hunk by hunk.** It applies to the tag with no fuzz.

| File | Change | Disposition |
|---|---|---|
| `eval.c` | `alarm` becomes a fatal error under `MSDOS` | kept. Its message said "fork"; `0002` corrects it to "alarm". |
| `msdos/Makefile` | file names, `link` response file | dropped: perl16 doesn't use this Makefile |
| `msdos/config.h` | `SIG_NAME` joined onto one line | kept, **required**: the tag's `SIG_NAME` is split mid-token and stops every module compiling |
| `msdos/config.h` | `S_ISBLK(x)`, `S_ISFIFO(x)` defined as 0 | kept |
| `msdos/msdos.c` | `setuid`, `setgid`, `userinit` stubs | kept |
| `perly.c` | `-v` no longer prints the usage message as well | kept |

## 3. Licensing

- **Perl 3.044:** GPL version 1 or (at your option) any later version
  (`README`; `Copying` is GPL v1). SPDX: `GPL-1.0-or-later`. The README
  also gives Larry Wall's interpretation for linked-in subroutines and
  scripts.
- **`msdos/*`:** "(C) Copyright 1987–1990 Diomidis Spinellis", under the
  same terms ("as specified in the README file that comes with the perl
  3.0 kit").
- **`regcomp.c`, `regexec.c`:** derived from Henry Spencer's regexp
  (Copyright 1986 University of Toronto), as modified by Larry Wall and
  distributed in the kit. These carry Spencer's permissive notice, which
  needs keeping in the release package.
- **`dospatch44`:** a modification of GPL code by Spinellis. The CC BY-SA
  3.0 GR notice on the web page covers "original material on this page".
  Patch `0001` applies the modification under the GPL. Its trivial hunks
  are recorded with their source and hash, and the patch text isn't
  redistributed.
- **libc16:** MIT, compatible with GPL-1.0-or-later.
- **Generated parser:** `perl.c` comes from bison 3.8.2. Bison's skeleton
  carries the special exception that lets its output be distributed under
  the grammar's terms.
- **Open:** the license of perl16's own files (`msdos/mktemp.c`, scripts,
  patches) has not been chosen yet (DESIGN.md §10). It must be
  GPL-compatible.

## 4. The historical build

From `msdos/Makefile` and `README.msdos`:

- **Compiler:** Microsoft C 5.1, `CFLAGS = -AL -DCRIPPLED_CC -Ox`.
  `consarg.c` and `util.c` (and, after dospatch44, `eval.c`) were built
  without `-Ox` because of optimiser bugs. `CRIPPLED_CC` replaces the
  `str_get`, `str_gnum` and `str_true` macros (`perl.h`) with function
  calls, which makes the code smaller.
- **Link:** `/stack:32767 /NOE`, with `\lib\setargv.obj` for wildcard
  expansion of `argv`. `exepack` was used at install time.
- **Generated sources:** `perl.c` and `perly.h` from `perl.y` (`yacc -d`,
  then `echo 'extern YYSTYPE yylval;' >> perly.h`). The tag ships neither.
  `scripts/yacc-perl` reproduces the step with `bison -y`, and fails
  unless the conflict counts are one of the two outcomes `Makefile.SH`
  documents. Bison 3.8.2 gives 27 shift/reduce and 61 reduce/reduce
  conflicts, which is one of them.
- **Helper programs:** `glob.exe` (`msdos/glob.c`) prints its arguments
  after the C startup has expanded the wildcards, lower-cased and
  NUL-separated. `evalargs.xc` runs `perlglob PATTERN` through `popen`
  for `<*.c>`, but the Makefile names the helper `glob.exe`, so the two
  names don't match. This is relevant to the DESIGN.md §10 question about
  `GLOB.EXE`; see section 9.
- **`config.h`:** a hand-written `msdos/config.h`, copied to the top
  directory. It sets `BIN` and `PRIVLIB` to `/usr/local/...`, `void` is
  usable, `BYTEORDER 0x1234`, and `STDSTDIO` (MSC `FILE` internals).
- **`-P`:** pipes the script through `sed` and `CPPSTDIN "cc -{"`, neither
  of which a DOS system normally has.
- **`@INC`:** `-I` paths, then `PRIVLIB`, then `.` (`perly.c`, around
  line 249). This is where M2's executable-relative `LIB` goes.

## 5. The perl16 build (M0 tooling)

| Target | What |
|---|---|
| `make` | `build/dev/PERL.EXE`, the **development build**: Watcom headers and stock runtime, **never to be published** (DESIGN.md §8) |
| `make test` | `tests/run-dos` runs `tests/smoke/*.pl` under DOSBox-X, one session per case, `cputype=8086` |
| `make audit` | `scripts/audit-externals` writes `build/audit/report.txt` (section 7) |
| `make reference` | fetches the historical material into `build/reference` |

**Source assembly** (`build/src`):

1. Tag `perl-3.044`, then `patches/*.patch` in order.
2. `msdos/{config.h,msdos.c,popen.c,directory.c}` copied to the top
   directory, and `msdos/dir.h` to `sys/dir.h`, as `README.msdos` says.
3. `scripts/yacc-perl`.

perl16's own C files (`msdos/` in this repository) are compiled from where
they are.

**Toolchain:**

- Open Watcom `2026-10-01-Build`, the snapshot libc16 0.04 pins
  (`build/libc16/tools/fetch-watcom`, sha256 `e6aa1b1e…`).
- Host tools: bison 3.8.2, GNU patch 2.8, GNU make 4.4.1, Perl 5.42.3 and
  DOSBox-X 2026.01.02.
- Flags: `wcc -q -zq -ml -0 -zc -bt=dos -DMSDOS`; `wlink option
  stack=32k system dos`.
- With default `-fpi`, the floating-point code is inline x87 with emulator
  fixups, and the stock runtime links Watcom's 8087 emulator.

**Reproducibility.** Two clean builds, one in another directory, give the
same `PERL.EXE` (sha256 `4850bf32…`). The only unpinned inputs are the
host tools above. The bison version matters most, since it determines
`perl.c`.

**Patches** (each one's header explains it; `docs/PROVENANCE.md` is the
index):

- `0001-dospatch44.patch` (section 2).
- `0002-watcom-compile.patch`, the minimum for Watcom's ANSI headers:
  - Hide the K&R `time()` and `setenv()` declarations.
  - `EXT` on `statstab` and `statname` (every module defined them).
  - `STDSTDIO` off and `STRERROR` on.
  - `patchlevel.h` included by its own name.
  - `YYDEBUG` tested the way `perl.y` tests it (bison always defines it).
  - A `make_usub()` return value.
  - DOS `mkdir()` takes one argument.
  - `sleep()` and `getenv()` declarations to match Watcom's.
  - `atexit()` in place of MSC `onexit()`.
  - An `rcsid` string that was split across two lines.
- `0003-watcom-varargs.patch`: prototypes for `fatal()`, `warn()` and
  `deb()` (section 9, defect 1).

## 6. Memory layout

The `build/dev/perl.map` load image is 328,608 bytes, including BSS and
stack. DGROUP (one 64 KB segment, addressed near) holds:

| Segment | Bytes |
|---|---|
| `_DATA` | 4,534 |
| `CONST` + `CONST2` | 1,773 |
| `_BSS` | 11,916 |
| `STACK` | 32,768 |
| **total** | about 51,100 of 65,536 |

- Without `-zc`, string literals land in `CONST`/`CONST2` too, and DGROUP
  overflows by 9,680 bytes. `-zc` puts them in the code segment instead,
  which is fine because every pointer is far in the large model.
- The stack is the real constraint. Measured on the 8086 emulator, simple
  recursion survives depth 40 and crashes at 60 with 32 KB. With 46 KB
  (the most DGROUP allows), depth 60 and `fib(15)` work. A `fib`-style
  sub needs about 2 KB of C stack per Perl call level, because
  `eval()`→`cmd_exec()`→`eval()` nest several large frames.
- The overflow is **not reported**: the process dies and takes the batch
  file with it, even though Watcom's stack checks (`__STK`) are compiled
  in. This needs explaining in M1.
  (M1 measured and explained this: docs/M1-REPORT.md, section 5.)
- **Options for M1/M3:**
  - Keep the stack in DGROUP and maximise it (about 46 KB).
  - Put it in its own segment (SS ≠ DS). That needs startup code perl16
    controls, which libc16 provides, and code compiled to not assume
    SS = DGROUP (Watcom `-zu`). It could give 64 KB of stack, and is worth
    measuring.
  - Reduce per-level stack use in `eval()`.
- The minimum RAM to run, and the heap behaviour, have not been measured
  yet (M1).

## 7. Runtime inventory

`make audit` links the 23 objects with no libraries and classifies the 98
unresolved symbols. The full table, with the modules that use each
symbol, is in `build/audit/report.txt`.

| Kind | Count | In libc16 0.04 |
|---|---|---|
| C library functions | 83 | 41 |
| C library data (`environ`) | 1 | 0 |
| compiler helpers | 5 | 3: `__I4D`, `__U4D`, `__U4M`. Missing: `__STK` (dropped by `-s`) and `__CHP` (float-to-integer truncation) |
| Watcom header artefacts (`__IsTable`, `___iob`, `__get_errno_ptr`) | 3 | n/a: replaced by whatever libc16's headers use |
| 8087 fixups (`FIDRQQ` …) | 6 | n/a: go away with `-fpc` |

The objects use Watcom's register convention and libc16 uses `__cdecl`,
so they can't simply be linked against libc16. The audit compares by C
name. M3 has to rebuild against libc16's headers.

**Missing from libc16 0.04, grouped.** libc16 0.05, unreleased, adds
`rename`, `unlink`, `fseek` and `ftell`.

- **Floating point:**
  - math: `atan2 cos exp log modf pow sin sqrt`
  - conversion: `atof`
  - formatting: `%e %f %g` in `sprintf`
  - the helper `__CHP`
  - with `-fpc`, Watcom's software floating-point helpers (`__FDA`,
    `__FDM`, …), which the release can't take from Watcom
  - The x87 analysis (`check-8086`) shows the only non-8086 instructions
    in Perl's own objects are 1,059 emulated x87 instructions.
    **This is the largest single piece of runtime work.**
- **Formatted output:** `sprintf` (13 modules), `fprintf`, `printf`,
  `vsprintf`. `do_sprintf` (`doarg.c`) passes each conversion straight to
  the C `sprintf`: `%c %d %ld %u %x %lx %o %lo %e %f %g %E %G %s` with
  flags, width and precision. Number-to-string conversion is
  `sprintf("%.20g")` (`str.c`). Perl 3 has no formatter of its own, so it
  needs a full ANSI `printf` core with floating point. That is the
  clearest case for a `libkitchen16` (DESIGN.md §6), shared with any
  other consumer that needs `%f`/`%g`.
- **stdio:** `fdopen fprintf fseek ftell`. Perl also relies on buffered
  streams and `ungetc` (`doio.c`'s EOF test), and libc16 streams are
  unbuffered, so performance needs measuring.
- **Files and directories:** `chdir dup fstat isatty rename rmdir unlink`.
- **Processes:** `system spawnl spawnvp execl execv execvp getpid abort`.
  The DOS `popen` emulation (`msdos/popen.c`) runs the command into a
  temporary file using `system` and `tempnam`.
- **Control:** `setjmp longjmp` (`die`, `eval`, `last`/`next`), `signal`,
  `atexit`.
- **Time:** `time gmtime` (libc16 has `localtime`).
- **Other:** `qsort rand srand strupr tempnam environ`.

## 8. Smoke tests (development build, emulated 8086)

| Case | Result |
|---|---|
| `version` (`-v`), `scalars`, `arrays`, `hashes` (300 keys), `regex`, `control` (subs, recursion, labels, `eval`/`die`), `printf`, `files` (text and binary mode, file tests, rename, unlink), `status` (exit status), `eopt` (`-e`) | pass |
| `packn` | todo: defect 2 |
| `vec32` | todo: defect 3 |
| `hashbig` | todo: defect 4 |
| `recurse` | todo: section 6 |
| `fpfmt` | todo: defect 6 |

## 9. Defects found

(M2 fixed defects 2–4 and the `sleep` warning in 5, and decided every item
in 7 except the `sort { … } LIST` hang, which is still open:
docs/M2-REPORT.md.)

Each defect is in upstream code unless noted, and applies to any 16-bit
`int` build, so the historical MSC port probably had defects 2–5 as well.

1. **`die` and `warn` messages were garbage; some `die`s crashed DOS.**
   Fixed in `0003`. `fatal`/`warn`/`deb` are `<varargs.h>` functions,
   which Watcom implements as stack-based variadics. Unprototyped callers
   passed the first arguments in registers. The lesson for M3: any
   function defined with `...` needs a prototype in scope at every call.
2. **`pack`/`unpack` with `N` lose the high 16 bits.** `my_htonl()` and
   `my_ntohl()` (`util.c`) return `long` but are called undeclared
   (`doarg.c`, `dolist.c`). Fix: declare them in `perl.h`.
3. **`vec()` with width 32 is wrong.** `doarg.c` around line 1404 shifts
   an `int` by 16 and 24. Fix: cast to `unsigned long` before shifting.
4. **A hash with more than about 409 keys dies** ("Reallocation too
   large"). `hsplit()` computes `tbl_max * FILLPCT` (`hash.c` lines 300
   and 334) in 16 bits; at 512 buckets the threshold goes negative, every
   insert splits, and the table hits the 64 KB allocation cap. Fix: `long`
   arithmetic. After that, the cap of 16,384 buckets in a 64 KB block
   still limits hash size, as `0xffff` checks in `util.c` do for any
   single allocation.
5. **Other 16-bit warnings to review in M2.**
   - `sleep` with no argument computes `(32767<<16)+32767` (`eval.c`
     around line 1392).
   - 224 calls without prototypes. The other functions they call return
     `int` or nothing, or the call ignores a pointer result (`strncpy`,
     `strupr`), so no further truncation was found. They should be
     declared anyway.
   - 49 "missing return value" warnings.
6. **Watcom `printf` rounding (development build only).** Ties round away
   from zero (`%.0f` of 2.5 gives 3), and the 20th significant digit is
   truncated rather than rounded, so `print 1/3` ends in …482, not glibc's
   …483. Perl 3 prints numbers with `%.20g`, so this is visible. Whatever
   replaces the formatter in M3 should be correctly rounded.
7. **Unsupported or questionable on DOS, to decide in M2.**
   - `-T`/`-B` on a filehandle (needs `STDSTDIO`) is now a fatal error.
   - `-P` needs `sed` and a C preprocessor.
   - `-e` writes `plXXXXXX` in the current directory, which fails on a
     write-protected disk; it should use `TEMP`/`TMP`.
   - Globbing runs `perlglob`, while the historical build produced
     `glob.exe`.
   - `PRIVLIB` is `/usr/local/lib/perl`.
   - Invalid Perl 4 syntax `sort { … } LIST` hangs the parser instead of
     reporting a syntax error. Compare with a Unix Perl 3 build before
     deciding whether it's a port bug.

## 10. Status of DESIGN.md §10 investigations

| Investigation | Status after M0 |
|---|---|
| External symbol inventory; how much formatting Perl uses | **done** (section 7). Full `printf` with floating point is needed. |
| `libkitchen16`: whether and how | evidence now favours it, for the `printf` core and floating point/maths; the API is still open |
| Historical patch needed; `GLOB.EXE` distributed | patch: yes, less the Makefile (section 2). Glob: naming mismatch found; decide in M2. |
| Watcom helpers, startup, stack, software floating point | helpers listed (section 7); stack is the binding constraint (section 6); floating point is the largest gap |
| Executable path from PSP environment | not started (M2) |
| Memory footprint, model, script size, RAM minimum | large model confirmed workable; image and DGROUP measured (section 6); runtime RAM not yet measured |
| Unix-like features, regression scope | smoke suite started; Perl 3's own `t/` not yet run |
| SPDX / helper licensing | Perl `GPL-1.0-or-later`; perl16's own files undecided (section 3) |

## 11. Recommended next steps

- **M1:**
  - Measure minimum RAM and heap use, and the size cost of `-os`/`-ox`
    and `CRIPPLED_CC`.
  - Find out why stack overflow isn't reported.
  - Run Perl 3's own `t/` suite under the harness.
- **M2:**
  - Fix defects 2–4.
  - Implement the executable-relative `@INC`.
  - Settle glob, `-P` and `-e`.
- **M3:**
  - Switch to libc16's headers and `-fpc`.
  - Decide the floating-point and `printf` home (`libkitchen16`).
  - Evaluate a separate stack segment.

## 12. Reproducing this audit

    make && make test && make audit     # build, smoke tests, inventory
    make reference                      # the historical material, for section 2
