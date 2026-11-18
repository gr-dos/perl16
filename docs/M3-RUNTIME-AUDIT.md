# M3.1: runtime audit and ownership

M3 (docs/DESIGN.md, section 7; tracking issue #12) replaces Open Watcom's
C runtime in `PERL.EXE` with independently written libraries. M3.1, this
document, comes first. It finds out what the interpreter needs from a
runtime once it is compiled the way a libc16 consumer is. It gives every
symbol and subsystem an owner, and decides whether `libkitchen16` should
exist. It changes no code that goes into `PERL.EXE`.

Measured on 2026-11-17 with:

- Open Watcom 2026-10-01-Build, the snapshot both libc16 0.04 and 0.07 pin;
- libc16 0.07 (then the latest release, `c23f0c7`), pinned at the time in
  `scripts/fetch-libc16` (perl16 now pins libc16 0.15 and libkitchen16
  0.02: sections 11.6 and 11.7);
- Perl 3.044 plus `patches/0001`–`0008`, as at the M2 merge (`51df9eb`).

Section 13 has the commands that reproduce every number.

## 1. Summary

- **The M2 baseline is unchanged.** Moving the libc16 pin from 0.04 to
  0.07 doesn't change the toolchain. `build/dev/PERL.EXE` is still
  282,204 bytes, sha256 `8fc09f08…`, byte for byte M2's. M2's test
  results therefore still apply (section 3).
- **libc16 0.07 covers more.** It provides 53 of the 88 C functions the
  development objects call; 0.04 provided 44. The new ones are `chdir`,
  `fseek`, `ftell`, `fstat`, `qsort`, `abort`, `remove`, `rename` and
  `unlink` (section 4).
- **Compiled against libc16's headers, the picture changes** (section 5,
  `make audit`'s new `scripts/audit-libc16`):
  - **Gone:** Open Watcom's header artefacts (`__IsTable`, `___iob`,
    `__get_errno_ptr`), the six x87 fixups and `__CHP`.
  - **New:** 16 software floating-point helpers (`__FDA`, `__EDM`,
    `__FDI4`, …).
  - **29 functions libc16 already has would not link.** Perl 3 declares
    them itself, K&R style (`char *strcpy();`), or calls them with no
    declaration in scope, so the call sites use the register convention
    (`strcpy_`) instead of libc16's `__cdecl` (`_strcpy`). This is the
    largest piece of perl16 source work in M3.4.
  - Only two of the 25 sources compile with libc16's headers alone.
    With stand-ins for the headers libc16 lacks, all but
    `msdos/dosglob.c` compile. That one still fails because its `qsort`
    callback isn't `__cdecl`.
- **Ownership** (section 6 is the full matrix):

  | Owner | What |
  |---|---|
  | **libc16** | 22 small, standard or conventional interfaces: `setjmp`/`longjmp`, `signal`/`raise`, `system` and the `spawn` family, `atexit`, `time`, `gmtime`, `rand`/`srand`, `getpid`, `isatty`, `dup`/`dup2`, `fdopen`, `rmdir`, `strupr` |
  | **libkitchen16** | floating point: the `-fpc` helpers, `strtod`/`atof`, the `<math.h>` functions Perl uses, and the `printf` family with `%e`/`%f`/`%g` |
  | **perl16** | source conformance with libc16's headers, `environ`, `exec` emulation, the piped-open temporary file, the stack check, and an INT 24h handler |

- **Decision: `libkitchen16` is a go** (section 11). Floating point is
  the one coherent, substantial, reusable need. libc16 has ruled it out
  (its decision 3). Perl 3 can't work without it, and Tcl16 needs the
  same pieces (`strtod`, `sprintf`). It depends on libc16 only for
  `errno` and, in two members, `FILE` output. libc16 never depends on
  it.
- **Floating point:** compile with `-fpc` and implement Open Watcom's
  software floating-point call ABI, which section 8 records from our own
  objects. The target is IEEE 754 binary64, round to nearest even, with
  subnormals. There's no FPU build in M3. Perl uses floating point
  lightly: 74% of the helper call sites convert between `double` and an
  integer.
- **Formatting:** conversions must be correctly rounded, exact in binary
  to decimal. Perl 3 prints every number with `%.20g`, so the 20th digit
  shows (section 9). A fast path for integral values keeps ordinary
  integers cheap.
- **INT 24h:** a perl16 handler through libc16's existing `_harderr`.
  It answers Fail, so DOS never shows Abort, Retry, Fail (section 10).
- **Defect found:** `msdos/config.h` sets `RANDBITS` to 31. Open Watcom's
  `rand()` gives 15 bits, and so will libc16's, so `rand(N)` probably
  never returns more than N/65536. This needs confirming under DOSBox-X,
  then a fix in perl16 (section 7.10).

## 2. Method

Two inventories, both made by `make audit`:

1. **`scripts/audit-externals`** (M0, unchanged). It links the
   development objects, compiled with Open Watcom's headers, with no
   libraries at all. Every unresolved symbol is classified and compared
   by C name with `LIBC16L.LIB`. The report is
   `build/audit/report.txt`.
2. **`scripts/audit-libc16`** (new). It recompiles every interpreter
   source the way a libc16 consumer is compiled (libc16's
   `docs/ABI.md`, "Consumer build"), in the large model, with `-fpc`:

       wcc -q -zq -zl -zld -x -ml -0 -s -fpc -zc -bt=dos -DMSDOS -DCRIPPLED_CC
           -fi=scripts/audit-include/audit.h -Ibuild/src -Imsdos
           -I$(LIBC16)/include -Iscripts/audit-include

   It then links the objects twice with no default libraries: once
   alone, and once with `LIBC16L.LIB`. It reports every external symbol
   with its kind, whether libc16 resolves it, its name in the first
   inventory, and the modules that use it. It also reports compile
   errors, and the runtime functions called with no prototype in scope
   (`W131`). The report is `build/audit/libc16/report.txt`, and
   `diagnostics.txt` sits beside it.

`scripts/audit-include/` stands in for the headers libc16 doesn't have:
`setjmp.h`, `signal.h`, `math.h`, `process.h` and `varargs.h`. It also
supplies the few macros libc16's headers lack (`EPERM`, `ENFILE`,
`EZERO`, `ENAMETOOLONG`, `stdaux`, `stdprn`), through a force-included
`audit.h`. These files are audit-only. They declare only what the
sources use, typed as ISO C or POSIX give it, and in the register
convention. So anything they declare shows up as `name_`, and the
report can tell "libc16 lacks this" from "libc16 has this". They aren't
a design for the eventual headers, and nothing in them comes from
another runtime's headers (their `README`).

The software floating-point ABI and the `__cdecl` treatment of `double`
come from compiling one-line C functions with these flags and
disassembling **our own** objects with `wdis` (section 8). That is the
method libc16's decision 6 allows. No Open Watcom runtime source was
read, and none of its libraries was disassembled. The sizes in section
6.1 come from `build/dev/perl.map`, the map of our own link, which names
each library module and its address.

## 3. Baseline

| | M2 (`51df9eb`) | This branch |
|---|---|---|
| libc16 pin | 0.04 | 0.07 (the same Open Watcom snapshot) |
| `build/dev/PERL.EXE` | 282,204 bytes, sha256 `8fc09f0887e2a9c0…` | identical |
| DGROUP (`check-dgroup`) | 62,928 bytes, 2,608 free | identical |
| `make test` | 21 of 22 smoke tests pass, `fpfmt` todo; `tests/run-install` 35 of 35 | the same executable; CI reruns both |
| `make test-t` | 53 of 72 `t/` scripts, as `tests/t-baseline.txt` | the same executable; CI reruns it |

The emulator tests need DOSBox-X, which the machine this audit was
written on doesn't have. Since `PERL.EXE` is byte-identical, M2's
results stand, and the pull request's CI run repeats them.

M3.4's comparisons use this baseline: `make test`, `make test-t`, and
the size, memory, stack and speed figures in docs/M2-REPORT.md
(sections 4 and 10).

## 4. Refreshed inventory with Open Watcom's headers

104 external symbols in 26 objects (M0 counted 98 in 23; M2 added
`exepath`, `etemp`, `dosglob` and `stk16`).

| Kind | Count | libc16 0.04 | libc16 0.07 |
|---|---|---|---|
| C library functions | 88 | 44 | 53 |
| C library data (`environ`) | 1 | 0 | 0 |
| compiler helpers (`__I4D`, `__I4M`, `__U4D`, `__U4M`, `__CHP`) | 5 | 4 | 4 |
| header artefacts (`__IsTable`, `___iob`, `__get_errno_ptr`) | 3 | n/a | n/a |
| x87 fixups (`FIDRQQ`, …) | 6 | n/a | n/a |
| other (`__STACKLOW`, from `stk16.asm`) | 1 | 0 | 0 |

The functions 0.07 still lacks, by this inventory, are `_hdopen`,
`_setjmp`, `atan2`, `atexit`, `atof`, `cos`, `dup`, `execl`, `execv`,
`execvp`, `exp`, `fdopen`, `fprintf`, `getpid`, `gmtime`, `isatty`,
`log`, `longjmp`, `modf`, `pow`, `printf`, `rand`, `rmdir`, `signal`,
`sin`, `spawnl`, `spawnvp`, `sprintf`, `sqrt`, `srand`, `strupr`,
`system`, `tempnam`, `time` and `vsprintf`.

## 5. Recompiled with libc16's headers

25 sources, 24 compiled, 131 external symbols:

| Kind | Count | Status |
|---|---|---|
| `__cdecl` calls through libc16's headers (`_strlen`, `___libc16_stdout`, `_errno`, …) | 43 | all resolved by `LIBC16L.LIB` |
| register-convention calls (`name_`) | 65 | 29 to functions libc16 has; 36 to functions it lacks |
| integer helpers (`__I4D`, `__I4M`, `__U4D`, `__U4M`) | 4 | resolved |
| `-fpc` floating-point helpers | 16 | missing |
| data (`environ`) | 1 | missing |
| audit stand-ins (`stdaux`, `stdprn`) | 2 | to remove from the source |

With `LIBC16L.LIB` linked in, 84 symbols are still undefined.

### 5.1 What disappears

- **`__IsTable`.** Open Watcom's `<ctype.h>` macros index this table;
  libc16's `<ctype.h>` has functions only (its `docs/spec/ctype.md`). So
  `isalpha` and the rest become far calls (`_isalpha`, `_isdigit`,
  `_isspace`, …, in 13 modules). The tokenizer and the regular
  expression engine call them per character. M3.4 measures the cost
  (section 7.1).
- **`___iob` and `__get_errno_ptr`.** These become libc16's
  `___libc16_stdin`/`stdout`/`stderr` and a plain `int errno`.
- **The six x87 fixups and `__CHP`.** With `-fpc` there are no x87
  instructions to emulate. `(long)x` calls `__FDI4` instead of `__CHP`.
- **`__STACKLOW`.** It belongs to `stk16.asm`, which `audit-libc16`
  doesn't assemble; section 7.6 covers it.
- **`strpbrk_`.** It is only in `dosglob`, which didn't compile.

### 5.2 What is new

The 16 `-fpc` helpers (section 8):

| Helper | Operation | Calls in Perl's objects |
|---|---|---|
| `__FDI4`, `__FDU4` | `double` to `long`, `unsigned long` (and to `int`, `unsigned`) | 69, 25 |
| `__I4FD`, `__U4FD` | `long`, `unsigned long` (and `int`, `unsigned`) to `double` | 50, 21 |
| `__FDC`, `__EDC` | compare | 13, 7 |
| `__FDA`, `__EDA` | add | 9, 6 |
| `__FDS` | subtract | 4 |
| `__FDM`, `__EDM` | multiply | 4, 4 |
| `__FDD`, `__EDD` | divide | 3, 1 |
| `__FDN` | negate | 5 |
| `__FDFS`, `__FSFD` | `double` to `float`, and back | 1, 2 |

That is 224 call sites. 165 of them (74%) convert between `double` and
an integer, 3 convert to and from `float`, 36 are arithmetic (negation
included) and 20 are comparisons. Beyond the math library, that is all
of Perl's floating point. A correct, simple implementation matters more
than a fast one.

### 5.3 What breaks

**Compile errors** (before `scripts/audit-include` existed, every module
but `directory` and `exepath` failed):

| Error | Modules | Cause | Owner |
|---|---|---|---|
| no `<setjmp.h>`, `jmp_buf` | all 20 that include `perl.h` | `loop_env`, `top_env` | libc16 |
| no `<signal.h>`, `SIG_DFL`, `SIG_IGN` | `doarg`, `stab`, `eval`, `util` | `%SIG` | libc16 |
| no `<varargs.h>` | `util` | `fatal`, `warn`, `mess` | perl16 |
| no `<process.h>`, `P_WAIT` | `msdos`, `popen` | `spawnvp`, `spawnl` | libc16 (spawn), perl16 (include) |
| `EPERM`, `ENFILE`, `EZERO` | `msdos` | DOS error mapping in `msdos.c` | perl16: use libc16's mapping |
| `ENAMETOOLONG` | `etemp` | perl16's own code | perl16 |
| `stdaux`, `stdprn` | `perly` | the `-e` path closes Microsoft's extra streams | perl16: drop |
| `E1071` on `qsort` | `dosglob` | callback isn't `__cdecl` (libc16 `docs/ABI.md`, "Callbacks") | perl16 |

The same applies to `dolist`'s `sortcmp`, which compiles only because
`dolist` calls `qsort` undeclared (`qsort_`, below).

**Register-convention calls to functions libc16 has.** These compile,
but wouldn't link against libc16, or would pass arguments in the wrong
registers:

| Why | Functions |
|---|---|
| declared by Perl, K&R style (`perl.h`, `util.h`, local declarations) | `malloc`, `realloc`, `memcmp`, `memcpy`, `memset`, `strcat`, `strchr`, `strcpy`, `strerror` |
| called with no declaration in scope (`W131`) | `abort`, `atoi`, `chdir`, `chmod`, `close`, `exit`, `free`, `getenv`, `mkdir`, `open`, `qsort`, `read`, `setmode`, `strcmp`, `strlen`, `strncmp`, `strncpy`, `unlink`, `utime`, `write` |

The fix belongs in perl16's patches. Include the right libc16 header in
each module, and guard Perl's own declarations of library functions
(`#ifndef MSDOS`, as upstream does for other systems). That is the
lesson of M0's defect 1, at scale: every call has to see the callee's
real declaration. M3.4 should build with `-wx` and treat `W131` for a
runtime function as an error.

## 6. Ownership matrix

Owners:

- **libc16**: a new interface in libc16, issue in gr-dos/libc16.
- **kitchen**: `libkitchen16` (section 11).
- **perl16**: in this repository, as a patch or under `msdos/`.
- **have**: libc16 0.07 already has it.

Sizes are 8086 code bytes, large model:

- **measured**: libc16's `docs/CONSUMERS.md`, or `build/dev/perl.map`;
- **est.**: an estimate to check in M3.2–M3.4.

"Tests" names where the behaviour is tested now, or will be.

### 6.1 The baseline it replaces

In the M2 executable, Open Watcom's runtime is the single `_TEXT`
segment: **65,375 bytes** of `PERL.EXE`'s code, from 274 library
modules:

- `clibl.lib`: 223 modules, 45,320 bytes;
- `emu87.lib`, the 8087 emulator: 10,923 bytes;
- `math87l.lib`: 22 modules, 9,132 bytes.

The largest single pieces are:

| Module | Bytes |
|---|---|
| the emulator | 10,595 |
| `ldcvt` (floating-point conversion) | 3,473 |
| `fexpand` | 2,934 |
| `tzset` | 2,060 |

A replacement that keeps `PERL.EXE` the same size has about 64 KB to
spend. Section 11.4 estimates 15–25 KB for floating point and
formatting together.

### 6.2 Startup, termination, environment

| API | Perl's use | 0.07 | Owner | Size, complexity | Tests |
|---|---|---|---|---|---|
| `cstart`, `argv` (`main_`, `_cstart_`, `__argc`) | entry; `argv[0]` is `""`, which is fine, because `exepath.c` takes the program's path from the environment block | have | libc16 | measured: 33 shingles; small | libc16 `tests/startup`; perl16 `run-install` |
| `exit` | `exit()`, `die` | have, but it runs nothing first | libc16; `atexit` changes it | small | libc16 `tests/startup/exitst` |
| `atexit` | `popen.c` removes piped-open temporary files at exit | no | **libc16**: C89 7.10.4.2, at least 32 entries, run by `exit` and by return from `main`, in reverse order | est. 100–200; small (a termination table, like the init table) | libc16 `tests/stdlib` |
| `abort` | `perly.c`, after `dump` ("for use with undump") | have | libc16 | measured: 20 + 31 data | libc16 |
| `environ` | `%ENV` (`perly.c`), `setenv` (`util.c`), children (`doarg.c`) | no; deferred in libc16's `docs/CONSUMERS.md` | **perl16**: build a writable `char **environ` from the PSP's environment block at startup (`exepath.c` already parses it). Pass it to children through `spawnve`/`spawnvpe` | est. 200; small | smoke `environ`; `run-install` |
| `getenv` | `COMSPEC`, `TEMP`/`TMP`, `PERLLIB` | have (reads the PSP's environment, not `environ`) | libc16; perl16 must read changes from `environ`, not `getenv`, after `%ENV` changes | measured: 87 shingles | libc16 |
| `_psp`, `intdos`, `intdosx`, `segread` | `exepath.c`, `etemp.c`, `directory.c`, `msdos.c` | have | libc16 | small | `EXETEST.EXE`, `ETEMPTST.EXE` |

### 6.3 Memory, stack and compiler support

| API | Perl's use | 0.07 | Owner | Size, complexity | Tests |
|---|---|---|---|---|---|
| `malloc`, `realloc`, `free`, `calloc` | every allocation (`safemalloc`) | have: far heap above the stack, grows the DOS block, 65,530-byte limit | libc16 | measured: 263 shingles (malloc) | libc16 `tests/heap`; smoke `hashbig` |
| `__I4M`, `__I4D`, `__U4M`, `__U4D` | `long` arithmetic | have | libc16 | measured | libc16 `tests/arith` |
| `__STK` (stack check) | every function; `msdos/stk16.asm` replaces Open Watcom's | not in libc16; consumers build with `-s` | **perl16**: keep `stk16.asm`, compile without `-s`, and take the stack bottom from wlink's `_end` (end of `_BSS`, where libc16's `STACK` begins) instead of `__STACKLOW` | 71 bytes now; trivial | smoke `stackovf`, `recurse`; `scripts/stack-probe` |
| `setjmp`, `longjmp` | `die`, `eval`, `last`/`next`/`redo` (`cmd.c`, `eval.c`, `perly.c`, `str.c`, `util.c`) | no | **libc16**: C89 7.6. Assembly, per model. `jmp_buf` holds `SP`, `BP`, `SI`, `DI`, `DS` and the return address (far in the large model); `SS` is DGROUP in every libc16 model. Declared `__cdecl` like every libc16 function | est. 60–90; small, but the register contract is tricky | libc16 new `tests/setjmp`; smoke `control` |
| floating-point helpers | section 5.2 | no; libc16 decision 3 rules them out | **kitchen** | section 8 | section 8.4 |

### 6.4 Files, directories and handles

| API | Perl's use | 0.07 | Owner | Size, complexity | Tests |
|---|---|---|---|---|---|
| `open`, `close`, `read`, `write`, `lseek`, `setmode` | `doio.c`, `eval.c` | have; a handle is a DOS handle | libc16 | measured | libc16 `tests/io`; smoke `files`, `lines` |
| `stat`, `fstat`, `utime`, `chmod`, `access` | file tests, `utime`, `chmod` | have | libc16 | measured: 303 (`fstat`) | smoke `files` |
| `rename`, `unlink`/`remove`, `mkdir`, `chdir` | Perl built-ins | have | libc16 | measured | smoke `files` |
| `rmdir` | `rmdir` | no | **libc16**: Microsoft C, INT 21h 3Ah, like `mkdir` | est. 30; trivial | libc16 `tests/files` |
| `dup`, `dup2` | `open(F, ">&STDOUT")` (`doio.c`); `util.c`'s `dup2` emulation | no | **libc16**: Microsoft C, INT 21h 45h/46h, carry the handle's text/binary mode | est. 60–100; trivial | libc16 `tests/io`; smoke `files` (`>&STDOUT`) |
| `isatty` | `-t`, interactive `-` script | no | **libc16**: Microsoft C, INT 21h 4400h bit 7 | est. 30; trivial | libc16 `tests/io` |
| `_hdopen` | `etemp.c` wraps the `-e` handle from INT 21h 5Bh | no (Open Watcom's) | **perl16**: under libc16 a handle is already a file descriptor, so drop it. Set the mode with `setmode` | 0 | `ETEMPTST.EXE`, smoke `eopt` |
| `_dos_findfirst`, `_dos_findnext`, `_fullpath`, `strlwr` | `directory.c` (`opendir`), `dosglob.c` | have | libc16; `opendir` stays perl16's (`directory.c`), as libc16 decided for Tcl16 | measured | smoke `glob` |
| `tempnam` | `popen.c`: piped-open temporary file in `TMP` | no | **perl16**: use `etemp.c`'s exclusive creation in `TEMP`, `TMP`, then `.`, which M2 left as a gap (docs/M2-REPORT.md, section 12) | est. 50 (reuse); small | smoke, `run-install` |
| INT 24h handler | write-protected or absent media | `_harderr` is there | **perl16** (section 10) | est. 60; small | `run-install` with a DOSBox-X image that raises INT 24h, as tico16's test does |

### 6.5 Streams

| API | Perl's use | 0.07 | Owner | Size, complexity | Tests |
|---|---|---|---|---|---|
| `fopen`, `fclose`, `fread`, `fwrite`, `fgetc`, `fputc`, `fputs`, `ungetc`, `fseek`, `ftell`, `fflush`, `feof`/`ferror`/`clearerr`, `fileno` | every file handle; `str_gets` reads with `getc` (`STDSTDIO` is off); `doio.c`'s EOF test pushes back a byte | have | libc16 | measured | libc16 `tests/stdio`; smoke, `t/` |
| `fdopen` | `doio.c` (`open` dup forms, pipes), `etemp.c` | no | **libc16**: POSIX, a stream over an open handle in the fixed stream table | est. 100; small | libc16 `tests/stdio` |
| `stdaux`, `stdprn` | `perly.c` closes them | no; not C89 | **perl16**: drop the two `fclose` calls | 0 | smoke `eopt` |

Two libc16 stream properties are not gaps, but M3.4 has to measure them:

- **`FOPEN_MAX` is 8**, so five streams besides the standard three.
  Perl 3 opens a stream per filehandle, and `open(F, ">&STDOUT")` takes
  another. M2's tests stay within this. A script that keeps more than
  five files open will fail with `EMFILE` where Open Watcom allowed 20.
  If that matters, the fix is a libc16 option, not perl16 code.
- **Output is unbuffered.** Every `fputc` and `fputs` is a DOS call,
  and `print` with several arguments makes one per argument. Input is
  buffered.
  `tests/smoke/format` and `scripts/bench` will show the cost. If it's
  large, buffered output belongs in libc16, which would also need
  `atexit` or the termination table to flush it.

### 6.6 Processes and signals

| API | Perl's use | 0.07 | Owner | Size, complexity | Tests |
|---|---|---|---|---|---|
| `system` | `popen.c` (piped opens); `system` with metacharacters goes through `spawnl(COMSPEC)` | no | **libc16**: C89 7.10.4.5 over `COMSPEC /C`. `system(NULL)` says whether a command processor exists | est. 150; small | libc16 new `tests/process`; smoke `environ` |
| `spawnvp`, `spawnl` | `do_aspawn`, `do_spawn` (`msdos.c`) | no | **libc16**: Microsoft C's `spawnv`, `spawnve`, `spawnvp`, `spawnvpe`, `spawnl`, `P_WAIT` only. Builds the command tail (126 bytes at most), an environment block from `envp`, searches `PATH` for the `p` forms, and runs INT 21h 4B00h. Returns the exit code | est. 500–800; medium. Tcl16 wanted `system` too (libc16 #12) | libc16 `tests/process`; smoke `status`, `environ` |
| `execl`, `execv`, `execvp` | `exec` (`doio.c`); re-exec of another interpreter for `#!` (`toke.c`) and of `sperl`/`tperl` (`perly.c`, unreachable on DOS) | no | **perl16**: DOS has no exec. Spawn, then `exit` with the child's status (M2's DOS.md already says so) | est. 50; small | smoke `status` |
| `getpid` | `$$` | no | **libc16**: return the PSP segment, which is unique among running programs. Documented as such | est. 10; trivial | libc16 |
| `signal`, `raise` | `%SIG` (`stab.c`); assigning to or `undef`ing `%SIG` sets every signal from 1 to 31 to `SIG_DFL` (`doarg.c`), so unknown numbers must fail harmlessly (`SIG_ERR`). `eval.c`'s use is in the Unix `fork` path, compiled out | no | **libc16**: C89 7.7. `SIGINT` through INT 23h (Ctrl-C/Ctrl-Break); `SIGABRT` from `abort`; the rest only through `raise`. `SIG_DFL` for `SIGINT` keeps DOS's behaviour. The handler is a `__cdecl` callback | est. 250–400; medium (INT 23h and DOS reentrancy) | libc16 `tests/signal`, raising INT 23h itself, as tico16's test raises INT 24h |

### 6.7 Strings, characters, numbers, time

| API | Perl's use | 0.07 | Owner | Size, complexity | Tests |
|---|---|---|---|---|---|
| `mem*`, `str*` (16 functions), `strdup`, `strerror` | everywhere | have | libc16 | measured | libc16 `tests/string` |
| `strupr` | `util.c` | no | **libc16**: Microsoft C, like `strlwr` | est. 25; trivial | libc16 `tests/string` |
| `isalpha` … `toupper`, `isascii` | tokenizer, regex | have (functions) | libc16 | measured | libc16 `tests/ctype` |
| `atoi` | `doio.c`, `eval.c`, `regcomp.c`, `stab.c`, `toke.c` | have | libc16 | measured | libc16 |
| `qsort` | `sort` (`dolist.c`), glob | have | libc16; perl16 makes `sortcmp`, `sortsub` and `cmp_names` `__cdecl` | measured: 259 | smoke `arrays`, `glob` |
| `rand`, `srand` | `rand`, `srand` | no | **libc16**: C89 7.10.2, `RAND_MAX` 32767. Not C89's example generator, which has poor low bits: a documented 32-bit LCG returning the high 15 bits | est. 60; trivial | libc16 `tests/stdlib`; perl16 test for `rand(N) < N` spread (section 7.10) |
| `time` | `time`, `sleep`, `srand`, `etemp.c` | no (libc16 has `localtime`, `dostime`, `tzset`) | **libc16**: C89 7.12.2.4, the DOS date and time through the same time-zone rules as `localtime` | est. 120; small | libc16 `tests/time` |
| `gmtime` | `gmtime` | no | **libc16**: C89 7.12.3.3, over the existing `timecal` | est. 40; trivial | libc16 `tests/time` |
| `localtime`, `strftime`, `tzset` | `localtime` | have | libc16 | measured | libc16 |
| `strtod`, `atof` | every string to number (`str.c`), literals (`toke.c`), `$]` (`perly.c`) | no | **kitchen** | section 9 | section 9 |
| `atan2`, `cos`, `exp`, `log`, `modf`, `pow`, `sin`, `sqrt` | Perl built-ins; `modf` in `int`, `%` (`consarg.c`, `eval.c`, `dolist.c`) | no | **kitchen** | est. 2.5–4 KB together | section 8.4 |
| `sprintf`, `vsprintf`, `fprintf`, `printf` | `do_sprintf` (`doarg.c`), number to string (`str.c`), messages (`util.c`), 13 modules | no | **kitchen** | section 9 | section 9 |

## 7. Subsystem notes

### 7.1 Character classes

libc16's `<ctype.h>` has functions only, by design. Perl's tokenizer
(`toke.c`) and regex engine (`regexec.c`) test characters in tight
loops, and a far call with `__cdecl` setup costs about 30 cycles on an
8088, more than a table lookup. If `scripts/bench` shows it, the fix is
a perl16-local table macro set (`msdos/ctype16.h`). That is Perl's own
code, not a libc16 change. libc16's functions stay the reference.

### 7.2 `FILE` assumptions

Perl 3 with `STDSTDIO` undefined doesn't touch `FILE`'s fields (patch
`0002` turned it off for Open Watcom). It uses only `fileno`, `getc`,
`ungetc` and `feof`, which libc16 provides as macros or functions. The
`-T`/`-B` filehandle tests need `STDSTDIO` and stay fatal errors, as in
M2. No allocator or `FILE` mixing can happen: M3.4 links only libc16's
streams and heap, and `scripts/audit-libc16`'s second link shows no
Open Watcom symbol is reachable.

### 7.3 `setjmp` and `longjmp`

Perl unwinds `die`, `eval`, loop control and `next` across many frames
with `longjmp`. It relies on C89 semantics, including locals not being
restored: `cmd.c` defines `JMPCLOBBER` for any `__STDC__` compiler, and
Open Watcom is one. The large model needs the far return address, `SP`,
`BP`, `SI`, `DI` and `DS`; `ES` is scratch in libc16's ABI. A `jmp_buf`
of 7 words is enough; reserving 8 leaves room. Owner libc16 (assembly is allowed there
for this, the same as for startup).

### 7.4 Signals

DOS has one asynchronous event a program can catch, Ctrl-C/Ctrl-Break
through INT 23h. DOS calls INT 23h only during a DOS call that checks
for Ctrl-C, at a point where reentering DOS is allowed. So a C handler
called from there can do what a Unix handler can. Perl's `%SIG{'INT'}`
needs `signal(SIGINT, handler)`, and clearing `%SIG` calls `signal(i,
SIG_DFL)` for every `i` from 1 to 31. Everything else in `SIG_NAME` is
accepted (or fails with `SIG_ERR`, which Perl ignores) and is never
delivered. M2's DOS.md already says so.

### 7.5 Startup and environment

libc16's startup passes `main` no environment and has no `environ`.
Patch `0004` already takes the environment from `environ` instead of
`main`'s third argument. perl16 will define `environ` itself
(`msdos/environ.c`): an init-table routine (libc16's decision 8) copies
the PSP environment strings into the heap and builds the array, so
Perl's `setenv` (`util.c`) can `Renew` it as on Unix. Children get it
through `spawnve`/`spawnvpe`, never through the PSP block, which Perl
doesn't change. This is the Perl-specific use libc16 deferred
`environ` over. A general `environ` in libc16 can come later, if a
second consumer needs it.

### 7.6 The stack and its check

libc16's `DGROUP` order is: reserved start, `CONST`, `CONST2`, `_DATA`,
the init table, `_BSS`, `STACK`. wlink's `_end` is the end of `_BSS`,
which is the bottom of the stack. `stk16.asm` changes one symbol. The
consumer flags' `-s` doesn't apply to perl16, which keeps its checks.
libc16's library code is compiled without checks, like Open Watcom's.
So the 2 KB `STK16_MARGIN` stays, and M3.4 measures it again with
`scripts/stack-probe`.

libc16's `DGROUP` should be smaller: no `__IsTable`, no `___iob` array,
no emulator data. A stdin buffer of 128 bytes and a buffer per open
stream are in the fixed table. The stack can then grow back toward
M1's 46 KB limit or beyond, keeping `DGROUP_MIN_FREE`, whose reason (Open
Watcom's spawn needs near heap) also changes. libc16's heap is above
the stack, not in `DGROUP`.

### 7.7 Child processes and memory

libc16's heap grows the program's DOS block (INT 21h 4Ah) as it needs
memory, and never gives it back. A child gets whatever is above the
block. That's the same situation as M2, where children fit beside small
scripts and a second `PERL.EXE` doesn't. M3.4 measures the free memory
seen by a child (`FREEMEM.EXE` under `system`) against M2's figures.

### 7.8 Integer helpers

libc16 already has every integer helper Perl calls, in the large model,
with the register contracts Open Watcom's code generation needs
(`tests/arith`, `regs`). The 64-bit helpers aren't used.

### 7.9 Varargs

`util.c` defines `fatal`, `warn` and `mess` with `<varargs.h>`. libc16
provides `<stdarg.h>`, whose `va_list` walks a `__cdecl`-style stack
argument list, and Watcom's variadic register-convention functions also
take every argument on the stack (patch `0003`). perl16 converts the
three functions to `<stdarg.h>` in a patch, keeping patch `0003`'s
prototypes. That's simpler than shipping a `varargs.h`.

### 7.10 `rand` and `RANDBITS`

`msdos/config.h` defines `RANDBITS 31`, so `eval.c` computes `rand(N)`
as `rand() * N / 2147483648.0`. A C89 `rand` that returns 0 to 32767,
like Open Watcom's and libc16's planned one, makes that less than
N/65536. If the M2 build behaves as this reads, `int(rand(10))` is
always 0. M3.4 confirms it with a new smoke test, `rand.pl`, against
the M2 build. The fix in perl16 is `RANDBITS 15`, matching
`RAND_MAX`, as the Unix `Configure` would have found.

## 8. Floating point

### 8.1 Choice: `-fpc`, no FPU code in M3

| Option | Needs | Verdict |
|---|---|---|
| `-fpi` (inline x87 with emulator fixups), M2 | an 8087 emulator: Open Watcom's is 10.9 KB of `PERL.EXE` and can't ship | no: a clean-room x87 emulator would be larger than the helpers it replaces, and harder to test |
| `-fpi87` (inline x87, no emulator) | an 8087 on every machine | no: the target is a plain 8088 |
| `-fpc` (calls) | the 16 helpers of section 5.2, plus the library | **yes** |

An FPU-using variant (`-fpi87`, linked with the same library, minus
the helpers) is possible later. It isn't M3 work and would be a second
executable, since detecting an FPU can't change code compiled inline.

### 8.2 The `-fpc` call ABI, from our own objects

Recorded from `wcc` output of one-line functions with the M3 flags,
disassembled with `wdis`. This is the method libc16 used for its
integer helpers (its `docs/ABI.md`, "Compiler support routines"):

- **A `double` in registers** is `AX:BX:CX:DX`, `AX` holding bits
  63–48 (sign, exponent, top of the fraction) and `DX` bits 15–0. That
  is the order libc16's 64-bit helpers use.
- **Binary operations.**
  - `__FDA`, `__FDS`, `__FDM`, `__FDD` and `__FDC` take `a` in
    `AX:BX:CX:DX` and `b` as 8 bytes at `SS:SI`, low word first. In the
    large model that is a stack slot or a DGROUP variable.
  - The `__ED` forms take `b` at `ES:SI`, a far operand: `addp(double
    *p, double *q)` loads `*p` into registers, `q` into `ES:SI`, and
    calls `__EDA`.
  - The result is in `AX:BX:CX:DX`.
  - `__FDC` and `__EDC` return the comparison in the flags: the caller
    branches with `jge` and `jne`, as signed integers would. For a NaN,
    whatever flag result is chosen has to be documented.
- **Unary operations and conversions.**
  - `__FDN`, `__FDI4`, `__FDU4` and `__FDFS` take the operand in
    `AX:BX:CX:DX`.
  - `__I4FD` and `__U4FD` take a 32-bit integer in `DX:AX`; an `int`
    is widened with `cwd` first. `__FSFD` takes a `float` in `DX:AX`.
  - The results are a `long` in `DX:AX` (`__FDI4` also serves `(int)`,
    whose caller uses `AX`), or a `double` in `AX:BX:CX:DX`.
- **Calls are far** in the large model (`call far ptr`, `jmp far ptr`
  for tail calls).
- **The second operand isn't written**, by the same reasoning as
  libc16's 64-bit helpers: callers reuse the slot afterwards.
- **Registers preserved:** to be established by the same experiments
  libc16 ran for `__I8M` (loops keeping pointers in `SI`, `DI`, `ES`
  across calls). Until then an implementation should preserve
  everything except the result registers and the flags.

**`double` and `__cdecl` functions,** the way libkitchen16's public
functions will be called:

- **Arguments.** A `double` argument is pushed as 8 bytes, low word
  lowest. In a variadic call (`sprintf(buf, "%g", x)`) it is the same 8
  bytes, so `va_arg(ap, double)` works with libc16's `<stdarg.h>`.
- **Returns.** A `__cdecl` function returning `double` returns, in
  `AX`, the DGROUP offset of an 8-byte result. The caller copies it at
  once (`mov bx,ax` / `mov dx,ss:6[bx]` …). The callee keeps that slot
  in its own static data (`k_ret` compiles to stores into a `_BSS`
  slot). So such functions aren't reentrant from interrupt handlers,
  which doesn't affect Perl.

### 8.3 Arithmetic contract

IEEE 754 binary64:

- round to nearest, ties to even, in every operation and conversion;
- subnormals, signed zeros, infinities and quiet NaNs;
- no exception flags, traps or `<fenv.h>`.

`double` to integer truncates toward zero, as C requires. Out of range
gives an implementation-defined result, which has to be documented,
since Perl stores large numbers in `double` and casts them in `vec`,
`pack` and `substr`. Perl itself checks division by zero ("Illegal
division by zero"), so `__FDD` by zero giving an infinity is never seen
by scripts. `float` is used once (`pack 'f'`) and needs only the two
conversions.

### 8.4 Sizes and tests

These are estimates for a straightforward 8086 implementation:

- the helpers: 2–3.5 KB;
- the eight math functions, with argument reduction: 2.5–4 KB;
- the 8087 emulator they replace: 10.9 KB.

Tests run in the libkitchen16 repository:

- every helper and conversion on DOSBox-X with `cputype=8086`, checked
  against the host's IEEE arithmetic as an oracle: boundary values,
  subnormals, ties, and a large pseudo-random corpus generated on the
  host;
- a register-preservation test like libc16's `regs`;
- `scripts/check-8086` over every member.

## 9. Formatting and numeric conversion

### 9.1 What Perl asks of `printf`

- `do_sprintf` (`doarg.c`) splits a Perl format into single
  conversions and passes each to C `sprintf` with one argument:
  - `%c`;
  - `%d`, `%ld` (`D`), `%u`, `%x`, `%lx`, `%o`, `%lo` (`X`, `O`);
  - `%e`, `%E`, `%f`, `%g`, `%G`;
  - `%s`.

  Each takes the flags `-+ #0`, width and precision, including `*`.
  The result goes to the 1,024-byte global `buf`.
- **Number to string** (`str_2ptr`, `str.c`) is
  `sprintf(s, "%.20g", nv)` into a 30-byte buffer. That's enough for
  `-d.ddddddddddddddddddde-ddd` (27 bytes and the NUL).
- **Messages** use `%s`, `%d`, `%ld`, `%lx`, `%x`, `%c` and `%.*d`
  (`util.c`'s `mess` through `vsprintf`, and `fprintf(stderr, …)`).
  `printf` is only in `regexec.c`'s debugging code.
- Perl 3 has no formatter of its own, so it needs C89's `printf` core
  with floating point. It needs no `%n` or `%p`, and no C99 length
  modifiers or `%a`.

**Defect in Perl 3:** a user precision can overflow `buf`. For example
`sprintf("%.2000f", 1)` writes about 2,000 bytes into a 1,024-byte
static buffer. perl16 should use `snprintf` there once it exists, and
libkitchen16 provides it.

### 9.2 Correctness requirements

- **Exact binary-to-decimal conversion, correctly rounded** (ties to
  even on the exact value) for `%e`, `%f` and `%g` at any precision.
  `print 1/3` must give `0.33333333333333331483`, and `0.1` prints as
  `0.10000000000000000555`, because Perl 3 shows 20 significant digits
  of the binary value. Open Watcom's `printf` gets the 20th digit wrong
  and rounds `%.0f` of 2.5 up, which is `tests/smoke/fpfmt`'s todo.
  The method: multiply-and-divide by powers of ten on a big integer of
  up to about 1,100 bits (138 bytes) for `%f` of the largest and
  smallest values. That needs no floating-point arithmetic, so it
  doesn't depend on the helpers being exact.
- **A fast path:** an integral `double` of magnitude below 2^53,
  formatted with `%g` or `%f`, is printed from a 64-bit integer. That
  gives the same output for any precision large enough. Perl
  stringifies every integer-valued number with `%.20g`, so this is the
  common case, and it needs no big integer.
- **Decimal to binary** (`strtod`, `atof`): correctly rounded, so that
  printing with `%.17g` and reading back gives the same `double`. It
  accepts C89's syntax plus `inf`/`nan`, and handles overflow (`HUGE_VAL`,
  `ERANGE`) and underflow (subnormal or zero, `ERANGE`). Perl's
  `looks_like_number` and `atof` take leading numeric prefixes, which
  `strtod`'s `endptr` already gives.
- **`inf`, `nan`** print as C99 does (`inf`, `-inf`, `nan`). They don't
  occur in Perl 3 scripts except through overflow, and don't happen in
  M2's tests.

### 9.3 Sizes and tests

These are estimates:

- the format core with integer conversions: 1.2–1.8 KB;
- exact floating-point conversion: another 1.5–2.5 KB;
- `strtod`: 1–2 KB;
- the M2 executable's Open Watcom conversion and formatting modules
  that they replace (`ldcvt`, `prtf`, `efgfmt`, `strtod`, …): over
  5.3 KB.

Tests:

- formats checked against the host's C library on a generated corpus:
  flags × width × precision × conversion × boundary values, plus every
  power of ten and two and many random `double`s at `%.17g`, `%.20g`,
  `%.0f` and `%e`;
- `strtod` round trips;
- perl16: `fpfmt` passes and leaves the todo list, and a new smoke test
  covers `sprintf` widths, flags and precision for every conversion.

## 10. INT 24h

**Decision:** perl16 installs a critical-error handler at startup with
libc16's `_harderr`.

The handler:

- returns `_HARDERR_FAIL`, so the DOS call fails and Perl reports the
  error like any other failed `open` or `print`;
- records the device and error code in two words, so a later message
  can say "drive A: is write-protected" instead of only "Permission
  denied". libc16 maps DOS error 83 (fail on INT 24h) to `EACCES`;
- calls no DOS function beyond what DOS allows (none, here).

It's perl16's because the policy (never prompt, fail the call) is the
program's choice, and libc16 already provides the mechanism. DOS 3.0
is the first version with Fail, and perl16 requires DOS 3.0
(DESIGN.md, section 3). DOSBox-X never raises INT 24h, so the test
raises it the way tico16's does (libc16's `docs/CONSUMERS.md`,
"Migration status").

## 11. `libkitchen16`: decision

**Go.** `gr-dos/libkitchen16` is created in M3.3. This is the go/no-go
decision the tracking issue requires.

### 11.1 Evidence

- Floating point and formatting are **needed** (Perl 3 holds every
  number as a `double`, and has no formatter of its own), **substantial**
  (more than 10 KB of code), and **reusable**:
  - Tcl16 needs `strtod`, `sscanf` and `sprintf` (libc16's
    `docs/CONSUMERS.md`, the Tcl16 table);
  - every small gr-dos utility uses `printf`, and replaced it with
    `libc16_` helpers only because libc16 has none;
  - floating-point helpers are needed by any `-fpc` program that
    touches `double`.
- libc16 has ruled all of it out of its own scope: decision 3, and
  "out of scope (decision 3; no floating point)" in the Tcl16 table. So
  the alternative to libkitchen16 is a perl16-private copy that Tcl16
  would have to duplicate.
- **Nothing else qualifies.** Every other gap in section 6 is a small
  standard or conventional interface that fits libc16's existing
  scope, or is Perl-specific.

### 11.2 Scope and API

The members each go in their own object, so a program links only what
it calls:

| Module group | Interface | Depends on |
|---|---|---|
| `fpc` (compiler support, private ABI) | `__FDA`, `__FDS`, `__FDM`, `__FDD`, `__FDC`, `__FDN`, `__EDA`, `__EDS`, `__EDM`, `__EDD`, `__EDC`, `__FDI4`, `__FDU4`, `__I4FD`, `__U4FD`, `__FDFS`, `__FSFD`, and the `float` (`__FS*`) set if a consumer needs it | nothing |
| `fmt` (format core) | `vsnprintf`, `snprintf`, `vsprintf`, `sprintf` (C89/C99 7.19.6), with `%e %f %g %E %G` and the integer conversions; `%a`, `%n`, `%p`, wide characters and locales left out and documented | `fpc`; nothing from libc16 except `<stdarg.h>` and `<stddef.h>` |
| `fmtio` | `vfprintf`, `fprintf`, `printf`, `vprintf` | `fmt` and libc16's `FILE` output (`fwrite`) |
| `conv` | `strtod`, `atof` | `fpc`, libc16's `errno` |
| `math` | C89 7.5: at least `atan2`, `cos`, `exp`, `fabs`, `floor`, `ceil`, `fmod`, `frexp`, `ldexp`, `log`, `log10`, `modf`, `pow`, `sin`, `sqrt`, `tan`, and the rest as consumers ask | `fpc`, libc16's `errno` (`EDOM`, `ERANGE`) |
| `scan` (later, for Tcl16) | `sscanf`, `vsscanf` | `conv` |

Headers:

- libkitchen16 ships `<math.h>`;
- it adds its declarations to `<stdio.h>` and `<stdlib.h>` in its own
  `<kitchen16.h>`, never in libc16's headers. A consumer includes
  `<kitchen16.h>` after libc16's headers. The declarations are
  `__cdecl`, as libc16's are (libc16 decision 2).

### 11.3 Boundaries and policy

- **libc16 doesn't depend on libkitchen16**, and links unchanged
  without it. libkitchen16's dependency on libc16 is limited to
  `errno`, `FILE` output in `fmtio`, and the shared ABI and headers
  (`<stdarg.h>`, `<stddef.h>`). It's pinned by libc16 version and
  documented.
- **The same clean-room and licensing policy as libc16:**
  - MIT;
  - a behavioural spec before each module;
  - no reading of Open Watcom or other runtime sources, and no
    disassembly of their libraries;
  - helpers and formatting code written by a separate session from the
    spec alone;
  - provenance per module;
  - a similarity audit against Open Watcom's libraries before the first
    release;
  - the host's C library only as a test oracle, never as source.
- **Its own repository, release ZIPs, `fetch-libkitchen16` pin script
  and CI**, on the libc16 pattern (libc16's `docs/CONSUMERS.md`, "Using
  libc16"). It uses the same Open Watcom pin, the same three memory
  models, and 8086 only.

### 11.4 Size budget for perl16

The estimates of sections 8.4 and 9.3 add up to about 9–14 KB for what
perl16 links from libkitchen16 (helpers, `fmt`, `fmtio`, `conv`, the
eight math functions). libc16's members Perl calls add a few KB. That
is well under the 65 KB of Open Watcom runtime they replace.

### 11.5 Status

As of 2026-11-18, `gr-dos/libkitchen16` exists. Its first
implementation is merged
([libkitchen16#1](https://github.com/gr-dos/libkitchen16/pull/1),
`d36fac5`) and released as
[0.01](https://github.com/gr-dos/libkitchen16/releases/tag/v0.01). Measured
sizes, speed and a no-coprocessor test followed
([libkitchen16#6](https://github.com/gr-dos/libkitchen16/pull/6)), and the
current release is
[0.02](https://github.com/gr-dos/libkitchen16/releases/tag/v0.02). It
follows sections 11.2 and 11.3:

- **Modules.** `fpc` (the 17 helpers of section 11.2, in the small,
  compact and large models), `fmt`, `fmtio`, `conv` and `math` (all of
  C89 7.5). The libraries are `LIBK16.LIB`, `LIBK16C.LIB` and
  `LIBK16L.LIB`, one member per function, 8086 instructions only. The
  pin script is `consumers/fetch-libkitchen16`.
- **Accuracy.** `%e %f %g` are exactly rounded at any precision, and
  `strtod` and `sqrt` are correctly rounded. The other `math` functions
  are within 4 ulps, and `pow` is exact for integer exponents.
- **Provenance.** Each module's spec and tests came first. A separate
  session wrote each module's code without `src/` or history. Its
  similarity audit puts no member over 0.50; the highest is 0.38. The
  maintainer reviewed the provenance on 2026-11-18.
- **Tests.** `make test` passes 213 checks in each model. The checks
  include DOSBox-X `cputype=8086` runs against host-oracle corpora and
  measured stack depths: `snprintf` uses at most 530 bytes and `pow` at
  most 396.

What this means for perl16:

- **Release 0.02** (0.01 was the first). The pin is `version=0.02`,
  `sha256=2ca356b7d2a23442b7851b10c09cfa577ee3888eaf5b4b899f10ee494162cb85`
  (`libkitchen16-0.02.zip.sha256`). It was built against libc16 0.07.
  perl16 pins it with libc16 0.15 (sections 11.6 and 11.7), which
  libkitchen16 allows (that version or newer). M3.4 links them, and its
  tests show the two work together: libkitchen16 uses libc16's `errno`
  and `FILE` output.
- **Larger than budgeted.** libkitchen16's `make size`
  ([libkitchen16#6](https://github.com/gr-dos/libkitchen16/pull/6))
  links perl16's set of functions in the large model. That is the
  helpers, `sprintf`, `vsprintf`, `fprintf`, `atof`, and `atan2 cos exp
  log modf pow sin sqrt`. They add 30,760 bytes of image and 2,000
  bytes of DGROUP, about twice section 11.4's 9–14 KB estimate. `pow`
  alone is 12 KB. That is still under the 65 KB of Open Watcom runtime
  it replaces. The 2,000 bytes of DGROUP count against perl16's
  DGROUP margin, so M3.4 measures both from `PERL.EXE`'s map.
- **Speed.** Its `make bench` uses the same emulated 4.77 MHz 8088 as
  perl16's `scripts/bench`. An addition takes about 1.1 ms, a
  division 4.9 ms, `sprintf("%.20g")` (every number Perl prints)
  27 ms, `atof` 35 ms, `sin` 72 ms and `pow` 0.4 s, in the large model.
  M3.4 compares perl16's workloads against M2's Open Watcom
  emulator, and reports slowdowns to libkitchen16.
- **Comparisons the compiler gets wrong.**
  [libkitchen16#2](https://github.com/gr-dos/libkitchen16/issues/2),
  closed in 0.02, found two limits in the code `wcc -fpc` generates. The
  helpers can't fix them. They're described in libkitchen16's
  `docs/CONSUMERS.md`, "Migration notes", and `docs/spec/fpc.md`:
  - **NaN.** `x > y` and `x >= y` are true when either is a NaN. Perl 3
    can make one, for example `9**9**9 - 9**9**9`.
  - **A literal zero.** `x == 0.0`, `x != 0.0`, `x < 0.0`, `!x`,
    `if (x)`, `x && y` and `x ? a : b` test only the high 16 bits of
    `x`. So `-0.0` is non-zero, and a subnormal below about `1.4e-309`
    is zero.

  Perl 3's truth test of a number and its comparisons with `0.0` are the
  first places to look. M3.4 rewrites any that matter with
  libkitchen16's tested idioms: a zero that isn't a literal, and an
  explicit NaN test. It adds Perl tests for `<`, `>`, `<=>` and
  truth with a NaN, `-0.0` and a subnormal.
- **`fpfmt` not run yet.** perl16's `fpfmt` smoke test has not been run
  against libkitchen16, because perl16 has not migrated. It is #15's
  remaining acceptance test.

### 11.6 Pins

(M3.4 has since moved libc16 to 0.14, for its heap, and to 0.15, for
`libc16_systeme`: section 11.7. Their headers are 0.12's but for
`libc16_systeme`'s declaration, so what follows still holds.)

perl16 pinned **libc16 0.12** (`scripts/fetch-libc16`) and **libkitchen16
0.02** (`scripts/fetch-libkitchen16`, new), each by its release's
SHA-256. The Makefile fails if the two name different Open Watcom
snapshots. They name the same one, so `build/dev/PERL.EXE` is unchanged
(sha256 `8fc09f08…`, 282,204 bytes). Until M3.4 links them, they serve
the toolchain pin and `make audit`.

`scripts/audit-libc16` now compiles with libkitchen16's headers before
libc16's, as libkitchen16's consumers do, and links `LIBK16L.LIB` with
`LIBC16L.LIB`. The stand-ins for `setjmp.h`, `signal.h`, `process.h` and
`math.h` are gone, because the two libraries provide them. Its
2026-11-18 run, against sections 4 to 6's run against 0.07:

- **Every interface assigned to libc16 or libkitchen16 is in a pinned
  library.** 50 `__cdecl` references resolve in libc16. All 16 `-fpc`
  helpers resolve in libkitchen16.
- **The register-convention calls (section 5.3) remain, and are perl16's
  to fix (#16).**
  - 36 are to libc16 functions: 9 declared by Perl, 27 undeclared.
  - 13 are to libkitchen16's. 10 are the math functions, `atof` and
    `vsprintf`, which Perl declares itself in K&R style. 3 are `printf`,
    `fprintf` and `sprintf`, which are undeclared: nothing includes
    `<kitchen16.h>` yet.
- **Still missing, all perl16's:** `_hdopen`, `execl`, `execv`,
  `execvp` and `environ` (sections 6.2 and 6.6).
- **Three modules don't compile** against the real headers. A callback
  passed to the library has Open Watcom's register convention where
  libc16 declares `__cdecl`:
  - `dosglob.c`'s `qsort` comparison, as before;
  - `stab.c`'s `signal` handler, newly reported because libc16 now has
    `<signal.h>`;
  - `popen.c`'s `atexit` function.

  Perl's own functions in `stab.c` and `popen.c` therefore show as
  missing until they compile. They are on #16's list.


### 11.7 The runtime build (M3.4, in progress)

`make rt` builds `build/rt/PERL.EXE`: the same sources compiled against
libc16 0.15's and libkitchen16 0.02's headers and linked with their
libraries alone (`option nodefaultlibs`), with no Open Watcom runtime.
`make test-rt` runs the smoke and installation tests on it. The
development build (`make`, `make test`) is unchanged and still passes.

**How it compiles (#16).** `msdos/p16rt.h` is force-included in every
module (`wcc -fi`). Under `P16_RT` it includes every libc16 and
libkitchen16 header the interpreter needs, so each library call has its
`__cdecl` prototype in scope before Perl's own K&R declarations, which
agree with them. `patches/0009-p16rt.patch` does the rest:
- `<stdarg.h>` for `deb`, `fatal`, `warn` and `mess`;
- `P16_CB` (`__cdecl` under `P16_RT`) on the `qsort`, `signal` and
  `atexit` callbacks;
- no `stdaux`/`stdprn`;
- libc16's DOS-error mapping in `ioctl`.

It also fixes `setenv`'s call of `strupr`, which passed two arguments to
a one-argument function. The link has no undefined symbol and no
register-convention call to either library.

**perl16's own shims (#17).**
- `environ`: `msdos/environ.c`, set up from libc16's init table
  (`msdos/p16init.asm`).
- `exec`: `msdos/exec16.c`, which spawns with `environ` and exits with
  the child's status. `execl` takes at most 64 arguments, the most a
  126-byte command tail can hold; more fail with `E2BIG` and run
  nothing, as does a longer tail (libc16's spawn). `EXECLTST.EXE`
  (`tests/tools/execltst.c`) tests both limits in `tests/run-install`.
- Spawns: `do_aspawn` and `do_spawn` pass `environ` (`spawnvpe`,
  `spawnve`), so children see `%ENV`.
- Piped opens: the temporary file comes from `etemp.c`'s exclusive
  creation instead of `tempnam`.
- `stk16.asm` takes the stack bottom from `_end`.

**Findings.**
- **Perl's `main` overwrote DOS's memory arena.** libc16's startup calls
  `main(argc, argv)` with `SP` at the top of the stack, which is the end
  of the program's memory block. Perl's `main` has a third parameter,
  `env`, which is therefore the next paragraph: the DOS memory control
  block that follows. Patch 0004's `env = environ;` overwrote it, and the
  program hung before any output reached its file. Under `P16_RT`, `main`
  takes two parameters and `env` is a local. Any libc16 program whose
  `main` writes a parameter it wasn't passed does the same. libc16 could
  guard against it with a few bytes of slack above the stack top.
- **The shell's command was quoted.** libc16's spawn functions quote an
  argument containing a space, and `COMMAND.COM` doesn't undo the
  quoting. Until 0.15, `do_spawn` passed the command as words
  (separated by single spaces), and one containing a double quote went
  through `system()`, with DOS's environment rather than `%ENV`.
  [libc16#31](https://github.com/gr-dos/libc16/issues/31) added
  `libc16_systeme`, which removes both limits (below, #22).
- **libc16 0.12's heap was quadratic with many free blocks**
  ([libc16#30](https://github.com/gr-dos/libc16/issues/30); fixed in
  0.14, below). Measured with libc16 alone, on the emulated 8086:
  - with 2,000 free holes, 2,000 allocations that don't fit them take
    1,123 ticks (62 s);
  - 4,000 growing `realloc`s take 4,099 ticks (225 s);
  - each doubling of the count multiplies the time by four.

  Perl's hashes and strings produce this pattern. A 1,500-key hash takes
  55 s to fill, against 1.3 s in the development build. `hashbig` and
  `recurse` give the right output but take 200 s and 99 s, beyond the
  smoke tests' 60 s limit. Arithmetic and string loops are within 1.5 s
  of the development build.
- **`fpfmt` passes.** libkitchen16's `printf` rounds a tie to even and
  gets the 20th digit right, where Open Watcom's didn't (section 11.5).

**libc16 0.14 (#21).** libc16 0.14
(`sha256=777693e1…faeaa09`, from its release's `.sha256`) replaces the
heap with segregated free lists and boundary tags, so a call's time no
longer grows with the number of blocks (libc16's `docs/spec/heap.md`,
"Performance"). Its headers are byte for byte 0.12's and it names the
same Open Watcom snapshot, so nothing in perl16 changed but the pin.
The link map of the clean rebuild has modules from `LIBC16L.LIB` (107)
and `LIBK16L.LIB` (36) and none from Open Watcom's runtime.

`scripts/bench` timed the M2 workloads and, with `ALLOC=1`, four
allocation-heavy ones (`hash1500` is `tests/smoke/hashbig`, `recurse`
is `tests/smoke/recurse`; `grow` is 3,000 string appends and array
pushes; `temps` is 200 rounds of `split` and `join` over 60 fields).
Emulated seconds at 3,150 cycles per millisecond (ten times
`scripts/bench`'s default, which would leave 0.12's runs at half an
hour each):

| Build | startup | arith | string | regex | hash | subs | read | bigint | hash1500 | grow | temps | recurse |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| dev (M2) | 0.1 | 1.8 | 0.9 | 0.9 | 1.3 | 1.4 | 1.0 | 15.3 | 5.0 | 2.6 | 8.0 | 6.7 |
| rt, libc16 0.12 | 0.1 | 3.9 | 3.2 | 1.8 | 17.5 | 3.2 | 2.0 | 235.3 | 79.8 | 134.9 | 33.3 | 96.6 |
| rt, libc16 0.14 | 0.1 | 3.8 | 1.2 | 1.2 | 2.3 | 1.8 | 1.9 | 18.6 | 8.0 | 3.8 | 8.1 | 7.1 |

- The allocation workloads are 4 to 35 times faster than with 0.12
  (`temps` 4, `hash1500` 10, `recurse` 14, `grow` 35), and within 1.6
  times the development build; `bigint` (`t/lib.big`) is 1.2 times it.
- The 1,500-key hash of the earlier measurement (insertion only) now
  takes 6.1 s of wall time in a `tests/run-dos` session, against 4.2 s
  for the development build and 55 s with 0.12; each figure includes
  about 3 s of DOSBox-X starting.
- What remains slower is not the heap. `arith` is twice the
  development build's, from libkitchen16's soft-float helpers against
  Open Watcom's (section 11.5); `read` is twice it too, not yet
  explained (#17's stream-buffering measurement is the next step).
- 0.14's costs, from its spec: `malloc`, `free` and `realloc` are 1,311
  bytes of code against 621 in the compact model (far data, as here),
  the free lists take 208 bytes of `DGROUP` against 6, and a block is
  at least 12 bytes with far data.

**Tests, 2026-11-18 (DOSBox-X 2026.01.02, emulated 8086), with libc16
0.14.**
- `make test`: 21 passed, `fpfmt` todo; 35 of 35 install cases.
- `make test-rt`: 22 of 22 passed, `hashbig` and `recurse` among them,
  within the unchanged 60 s limit; 36 of 36 install cases (the 35, and
  `EXECLTST.EXE`). `fpfmt` passes, but was still marked todo (now only
  for the development build; below).
- `make test-t-rt`: 53 of 72 `t/` scripts pass, the development
  build's baseline exactly; `lib.big` passes within the 120 s limit.
- With 0.12, `hashbig`, `recurse` and `lib.big` gave the right output
  but timed out, and the runtime tests allowed exactly that until this
  pin (`SLOW` in `tests/run-dos` and `tests/run-t`, which remains for
  any build that needs it).
- `make audit` compiles all 25 sources against libc16 0.14 and
  libkitchen16 0.02. Every `__cdecl` reference resolves, and what's
  missing is perl16's own shims (`environ`, the `exec` family,
  `_hdopen`), which the audit doesn't link.
- CI runs `make rt`, `make test-rt` and `make test-t-rt` in a job of
  their own.

**libc16 0.15 (#22).** libc16 0.15
(`sha256=042b6d2d…0f287`, from its release's `.sha256`) adds
`libc16_systeme(cmd, envp)`
([libc16#31](https://github.com/gr-dos/libc16/issues/31)): `system`
with an environment, which passes `cmd` to `COMSPEC /C` byte for byte.
The only header change is its declaration in `<process.h>`; the Open
Watcom snapshot is the same, so libkitchen16 stays at 0.02. In
`do_spawn` (patch 0009):
- The shell path is `libc16_systeme(cmd, environ)`, replacing both the
  word-splitting `spawnve` and the `system()` fallback for commands
  with a double quote.
- The shell is the one the `COMSPEC` DOS gave Perl names, as before
  (libc16 takes it from its own `getenv`, which reads that block). A
  `COMSPEC` in `%ENV` is passed on but doesn't choose it.
- A command run directly (no `<`, `>` or `|`) is now split as
  libc16's startup splits a command tail, double quotes and
  backslashes included, rather than at every space, so that
  `spawnvpe`'s quoting gives the program the arguments the command
  names. Sending quoted commands to the shell instead would lose their
  exit status: DOSBox-X's `COMMAND.COM /C` returns its own (1 here),
  not the program's.

Compared with the development build (M2), which passes the command
through Open Watcom's `spawnl` and `spawnvp`: a direct program gets
the same arguments, now with `%ENV`; the shell gets the command
unchanged in both. Both builds return the shell's exit status, not the
program's, for a shell command. In both, a second `PERL.EXE` run from
Perl exits with 8, as `docs/DOS.md` says: there isn't the memory for
it.

`tests/smoke-rt` holds the runtime build's own cases, which `make
test-rt` runs with `TAILTST.EXE` (`tests/tools/tailtst.c`), a program
that prints its command tail byte for byte and its environment and
exits with `P16EXIT`:
- `shraw`, with `TAILTST.EXE` as `COMSPEC`:
  - a shell command with double spaces, escaped quotes, a tab, `%`,
    `<`, `>`, `|` and `;` reaches `/C` byte for byte;
  - the environment has the added, changed and deleted variables;
  - a quoted command run directly keeps its arguments and status;
  - one that can't be run falls back to the shell;
  - a `COMSPEC` set in `%ENV` is passed on without choosing the shell;
  - exit statuses 0, 5 and 7 come back;
  - 122 bytes run, and 123 fail with `E2BIG` and run nothing.
- `shenv`, with DOSBox-X's `COMMAND.COM`: a command with two quoted
  arguments and a redirection reaches `TAILTST.EXE` as written with
  `%ENV`, and the shell's own `set` shows `%ENV` too.

`tests/run-dos` gained `# setup:` lines (run before Perl, here to set
`COMSPEC`) and `FILES` (extra fixtures, here `TAILTST.EXE`).

**Tests, 2026-11-18, with libc16 0.15.**
- `make test`: 21 passed, `fpfmt` todo; 35 of 35 install cases.
- `make test-rt`: 22 of 22 smoke, 2 of 2 `smoke-rt`, 36 of 36 install.
  `fpfmt` is among the 22 and is now required: its todo is
  `# todo-dev`, which `tests/run-dos` applies only with `BUILD=dev`
  (`make test`), so a runtime build whose formatting regressed fails
  `make test-rt` and CI (#15).
- `make test-t-rt`: 53 of 72, the baseline.
- `make audit`: all 25 sources compile.
- The link map has `LIBC16L.LIB` (109 modules, `systeme` among them)
  and `LIBK16L.LIB` (36) and nothing of Open Watcom's runtime.
- `scripts/bench ALLOC=1` gives 0.14's figures to the tenth of a
  second, so the heap fix is intact.


## 12. Issue breakdown

These issues were opened from this audit. Each one's scope is the row
below, and its detail is the section of this document it cites.

| Issue | Title | Scope | Phase | Status |
|---|---|---|---|---|
| [gr-dos/libc16#19](https://github.com/gr-dos/libc16/issues/19) | setjmp and longjmp (C89 7.6) | sections 6.3, 7.3 | M3.2 | done in [libc16#24](https://github.com/gr-dos/libc16/pull/24), 0.09 |
| [gr-dos/libc16#20](https://github.com/gr-dos/libc16/issues/20) | system, the spawn family and getpid | section 6.6: `system`, `spawnv`, `spawnve`, `spawnvp`, `spawnvpe`, `spawnl` (`P_WAIT`), `getpid` | M3.2 | done in [libc16#25](https://github.com/gr-dos/libc16/pull/25), 0.10 |
| [gr-dos/libc16#21](https://github.com/gr-dos/libc16/issues/21) | signal and raise (C89 7.7), SIGINT through INT 23h | sections 6.6, 7.4 | M3.2 | done in [libc16#26](https://github.com/gr-dos/libc16/pull/26), 0.11 |
| [gr-dos/libc16#22](https://github.com/gr-dos/libc16/issues/22) | small C89 and Microsoft C functions for perl16 | sections 6.2–6.7: `atexit`; `time`, `gmtime`; `rand`, `srand`; `isatty`, `dup`, `dup2`, `fdopen`, `rmdir`, `strupr` | M3.2 | done in [libc16#23](https://github.com/gr-dos/libc16/pull/23), 0.08 |
| [#15](https://github.com/gr-dos/perl16/issues/15) | M3.3: create gr-dos/libkitchen16 | section 11: `fpc`, `fmt`, `fmtio`, `conv`, `math` | M3.3 | implemented in [libkitchen16#1](https://github.com/gr-dos/libkitchen16/pull/1), released in 0.01 (now 0.02); `fpfmt` passes in the runtime build, which `make test-rt` requires: done |
| [#16](https://github.com/gr-dos/perl16/issues/16) | M3.4: perl16 sources against libc16's headers | section 5.3, 7.9, 7.10: declarations and includes, `__cdecl` callbacks, `<stdarg.h>`, `stdaux`/`stdprn`, `_hdopen`, `RANDBITS` | M3.4 | open |
| [#17](https://github.com/gr-dos/perl16/issues/17) | M3.4: perl16's DOS shims for libc16 | sections 6.2–6.6, 7.1, 7.5–7.7, 10: `environ`, `exec` emulation, the piped-open temporary file, `stk16.asm` on `_end`, the INT 24h handler, the ctype and stream-buffering measurements | M3.4 | open |

The libkitchen16 issue was opened in perl16 because the repository did
not exist yet. M3.3 has since created it (section 11.5), and its own
issues are filed there.

All four libc16 issues are released, and libc16 0.12 (2026-11-18) has every
one of them. 0.12 also reserves code offset 0 in the small and compact
models so that no function pointer is null
([libc16#27](https://github.com/gr-dos/libc16/issues/27)); perl16 is
large-model and unaffected. Section 11.6 has the audit against 0.12 and
libkitchen16 0.02; the counts in sections 4 to 6 are against 0.07.
[libc16#30](https://github.com/gr-dos/libc16/issues/30), the heap's
quadratic time, which M3.4 found, is fixed in 0.14 (#21), and
[libc16#31](https://github.com/gr-dos/libc16/issues/31), `libc16_systeme`, is
in 0.15, which perl16 now pins (#22; section 11.7).

## 13. Reproducing

    make                  # build/dev/PERL.EXE; sha256 8fc09f08… (section 3)
    make audit            # build/audit/report.txt (section 4) and
                          # build/audit/libc16/report.txt (section 5)
    make test test-t      # the M2 baseline (DOSBox-X)

Section 6.1's library sizes come from `build/dev/perl.map`: the
`_TEXT` segment's size, and each library module's extent between
consecutive module start addresses. Section 8.2's experiments compile
small C files with the flags of section 2 and disassemble them with
`wdis -a`. The files are short enough to retype from the description.
