# M1: the exploratory 8086 build

M1 (docs/DESIGN.md) is the development build, `build/dev/PERL.EXE`, measured
on an emulated 8086: what it runs, how big it is, how much memory it needs,
and how its stack behaves. It includes the investigation of issue #5,
DGROUP and stack layout options. Nothing here is a release; every
executable mentioned is linked with Open Watcom's C runtime and must not be
published (DESIGN.md, section 8).

Measured on 2026-11-15 with Open Watcom 2026-10-01-Build (libc16 0.04's
pin), DOSBox-X 2026.01.02 (CGA machine, normal core, `cputype=8086`), Perl
3.044 plus `patches/0001`–`0004`. The development build is 299,084 bytes,
sha256 `5edef575838d589df127a47fb376404d542e847fbf35f386c3e07bb97aa67b09`.
Section 10 has the commands that reproduce every number.

## 1. Summary

- **It runs.**
  - Smoke tests: 12 pass, and 5 known failures are recorded as todo.
  - Perl 3.044's own `t/` suite: 53 of 72 scripts pass.
  - The 19 that fail need Unix: fork, pipes from processes, signals, `/dev/tty`, links, `cpp`, `umask`, and so on (section 3).
- **A defect M1 found and fixed** (patch 0004): Open Watcom's startup passes `main()` no environment.
  - Perl 3 took garbage for `env`, so `%ENV` was always empty.
  - It also emptied the environment of every child process.
  - In some link layouts it hung any script that used `eval`.
- **Stack overflow is not reported, for two reasons** (section 5.2):
  - Open Watcom's handler writes "Stack Overflow!" to the console device, not to standard error.
  - In Perl, the handler then crashes DOS before the program exits.
  - A small replacement `__STK` (`msdos/stk16.asm`) fixes both. It keeps a 2 KB guard margin, writes "Stack overflow" to standard error, and exits with status 255. It reported every overflow in every test, for 3% in speed.
- **The stack per Perl call is the real limit.** A simple Perl sub takes about 1 KB of C stack per call level, and about 3 KB with `local()`.
  - Most of that is `eval()`'s 780-byte frame. Perl recursion re-enters it several times per level.
  - Building with `-DCRIPPLED_CC` turns `str_get`, `str_gnum` and `str_true` from macros into functions. That cuts the frame to 186 bytes and triples recursion depth.
  - It also makes the executable 20 KB smaller, for about 2% in speed.
- **Configurations compared for issue #5** (section 5.4):

  | Stack | Simple recursion depth | Verdict |
  |---|---|---|
  | (a) 32 KB in DGROUP | 33 | the current build |
  | (b) 46 KB in DGROUP | 58 | uses all but 64 bytes of DGROUP, and then child processes fail; 45 KB is the practical limit |
  | (c) 64 KB own segment (SS≠DS) | 63 | works, after working around two runtime assumptions; 6% slower and needs 64 KB more memory |

  Combining `-DCRIPPLED_CC`, a 45 KB stack and the reporting check (`rec`) reaches depth 131, passes every smoke test (including `recurse`, 100 deep) and matches the `t/` baseline.
- **Recommendation: keep SS=DS** (section 6).
  - Adopt the reporting stack check first (M1 doesn't change the default build).
  - Evaluate `-DCRIPPLED_CC` and the largest DGROUP stack as M2 work.
  - Leave SS≠DS until perl16 controls its startup and runtime with libc16 (M3).
  - In this build SS≠DS rests on library code that assumes SS=DGROUP. M1 found two such places and worked around them, and no test can show there are no more.
- **Memory**:
  - The load image is 321 KB. With DOSBox-X's DOS, `perl -v` needs 364 KB of conventional memory, Perl 3's `bigint.pl` tests 440 KB, and 100 KB of strings in an array 504 KB.
  - Each 100-byte string costs about 140 bytes of heap.

## 2. The build

`make` assembles the source in `build/src` and builds `build/dev/PERL.EXE`:
large model (`-ml`), 8086 instructions (`-0`), string literals in the code
segment (`-zc`), inline x87 code with emulator fixups (the default `-fpi`),
Open Watcom's default optimisation, its stack checks, and a 32 KB stack
(`option stack=32k`), as in docs/M0-AUDIT.md, section 6.

| | Bytes |
|---|---|
| `PERL.EXE` | 299,084 |
| load image (map "Memory size") | 328,640 |
| code (class `CODE`) | 277,490 |
| DGROUP | 51,136 |

Code is 212,409 bytes of Perl and 65,034 of the runtime. `eval.c` is
30,698, `toke.c` 30,285 and `perl.c` (the parser) 24,618 bytes.

## 3. What runs

**Smoke tests** (`make test`, `tests/smoke`): 12 pass. The 5 recorded
failures are defects for M2, each explained in its script's `# todo:`
line:

- `packn`
- `vec32`
- `hashbig` (a 16-bit overflow in `hsplit()` at 512 buckets)
- `fpfmt` (Open Watcom's `printf` rounding)
- `recurse` (section 5)

**Perl 3.044's `t/` suite** (`make test-t`, `tests/run-t`, about 2.5 minutes):

- 53 of 72 scripts pass; `tests/t-baseline.txt` has every result.
- A regression from that baseline fails the target, and CI runs it.
- The runner gives each script an 8.3 name and rewrites the long temporary names the scripts use.
- It runs each script in its own DOSBox-X session, so one crash costs only that script.

The 19 failing scripts need things DOS doesn't have:

- `fork`, pipes to and from processes, `kill` and signals (`io.pipe`, `op.fork`, `op.exec`, `io.dup` in part);
- the Unix shell commands `cat`, `echo` to a pipe, `pwd`, `rm` and `cp` (`comp.script`, `io.argv`, `io.fs`, `op.magic`, `base.term`);
- links, `umask`, `/dev/null` and `/dev/tty` (`io.fs`, `op.stat`, `op.mkdir`);
- `cpp` for `-P` (`comp.cpp`);
- `-i.bak` on dot files (`io.inplace`);
- the `perlglob` helper for `<*.c>` (`op.glob`);
- CPU time from `times` (`op.time`).

`comp.multiline`, `op.split`, `op.goto` and `op.write` fail on the same
shell commands or on `/dev/tty` in later tests; their earlier tests pass.

**Speed** (`scripts/bench`): the emulated time of each workload, from BIOS
timer ticks, with DOSBox-X fixed at 315 cycles per millisecond (about a
4.77 MHz 8088). Loading is nearly free in the emulator, because its disk
is a host directory.

| seconds | startup | arith | string | regex | hash | subs | bigint |
|---|---|---|---|---|---|---|---|
| dev | 0.3 | 15.9 | 8.4 | 9.0 | 13.0 | 13.5 | 149.1 |

- `arith` is 2,000 iterations of floating-point arithmetic.
- `string` builds a 2,500-byte string with `sprintf` and `substr`.
- `regex` does a match and a global substitution on each of 100 lines.
- `hash` does 300 stores and lookups and a sorted `keys`.
- `subs` is 500 calls with `local()`.
- `bigint` is `t/lib.big`, 246 tests of Perl 3's `bigint.pl`.
- Floating point is emulated in software (`emu87`). Every number in Perl 3 is a double, so this dominates.

## 4. Memory

### DGROUP

From `build/dev/perl.map`:

| Segment | Bytes |
|---|---|
| `_NULL`, `_AFTERNULL` (`BEGDATA`) | 34 |
| `_DATA` | 4,534 |
| `CONST`, `CONST2` | 1,773 |
| `XI`, `YI` (startup and exit tables) | 102 |
| `_BSS` | 11,916 |
| `STACK` | 32,768 |
| **DGROUP** | **51,136** |
| headroom to 64 KB | 14,400 |

Where the static data comes from (the objects' own segment sizes):

| | `_DATA` | `CONST` | `_BSS` |
|---|---|---|---|
| Perl, all objects | 2,986 | 0 | 10,658 |
| of which `str.c` | 4 | 0 | 8,192 |
| of which `perl.c` (parser tables) | 1,955 | 0 | 2,224 |
| of which `util.c` | 529 | 0 | 0 |
| Open Watcom runtime | 1,539 | 1,766 | 1,253 |
| of which `strerror` | 166 | 790 | 256 |
| of which `fpe87` | 22 | 0 | 516 |

`str.c`'s 8 KB is one buffer: `str_gets()` reads lines through a static
`char buf[8192]` when stdio isn't `STDSTDIO`, as on DOS. It already loops
and appends for longer lines, so it could be a few hundred bytes. That
would give about 7.5 KB more to the stack (section 7).

### Layout

The order in DGROUP is: data, BSS, and the stack at the top. Open Watcom's
startup (`cstart`):

1. sets `__STACKLOW` to the end of BSS;
2. copies the command line and program name to the bottom of the stack and moves `__STACKLOW` above them;
3. shrinks the program's DOS memory block to the end of DGROUP.

The near heap grows above the stack, inside DGROUP's 64 KB, by enlarging
that block (`sbrk`). Allocations that don't fit there come from DOS
memory blocks. With the 46 KB stack, DGROUP is full and every allocation
comes from DOS blocks. That made no measurable difference to speed, but it
breaks child processes (section 5.4).

### Conventional memory needed

`scripts/mem-probe` finds, in 4 KB steps, the least conventional memory
(DOSBox-X `dos mem limit`) in which a workload still prints its expected
result. Each figure is the limit, then (in parentheses) what DOS had free
for a program at that limit, as measured by `tests/tools/freemem.c`.

| Workload | dev | crip | rec | ss64 |
|---|---|---|---|---|
| `perl -v` | 364 (331.7 free) | 344 (311.7) | 356 (323.7) | 376 (343.7) |
| short script: scalars, a 300-key hash, a regex, a sub | 408 (375.7) | 388 (355.7) | 404 (371.7) | 420 (387.7) |
| `t/lib.big` (`bigint.pl`, 246 tests) | 440 (407.7) | 420 (387.7) | 436 (403.7) | 516 (483.7) |
| 1,000 strings of 100 bytes in an array | 504 (471.7) | 484 (451.7) | 492 (459.7) | 580 (547.7) |

- `perl -v` needs 331.7 KB free: the 321 KB image and about 11 KB of heap.
- The strings workload needs 140 KB more than `perl -v`. That is about 140 bytes of heap per 100-byte string (the `STR`, its buffer and the allocator's overhead) plus the array.
- On real DOS 3.3, which uses more memory than DOSBox-X's own DOS, a 512 KB machine runs small scripts. 640 KB is the realistic size.
- The `ss64` figures come out only 12 KB above `dev` for `perl -v`, because when its 64 KB stack can't be allocated it falls back to the normal stack (section 5.4). The `bigint` figure, 76 KB more, is the real cost.

## 5. The stack (issue #5)

### 5.1 How much stack Perl uses

`scripts/stack-probe` finds by bisection the deepest recursion that
finishes, for three kinds of sub:

| Kind | Sub |
|---|---|
| `simple` | `sub d { &d($_[0] + 1) if $_[0] < N; }` |
| `local` | `sub f { local($n) = @_; $n >= N ? 0 : 1 + &f($n + 1); }` |
| `string` | a `local()`, an `sprintf` and a substitution at every level |

On the development build the deepest that finishes is 33, 11 and 37: about
1 KB of C stack per Perl call level for `simple`, and about 3 KB for `local`.

The cause is the frame of `eval()`, Perl's expression evaluator, which is
entered several times per Perl-level call (`eval` → `do_subr` →
`cmd_exec` → `eval` …). Open Watcom reserves stack in the prologue for
every temporary in the whole function:

| Build | Frame of `eval()` | Frame of `cmd_exec()` |
|---|---|---|
| default | 780 bytes | 104 bytes |
| `-DCRIPPLED_CC` | 186 bytes | 0 bytes |

Perl 3's `str_get`, `str_gnum` and `str_true` are macros with nested
conditional expressions; `CRIPPLED_CC` makes them functions. The
historical Microsoft C port was built with `CRIPPLED_CC` (M0-AUDIT.md).

### 5.2 Why overflow isn't reported

Open Watcom calls `__STK` at the entry of every function compiled without
`-s`, with the frame size in AX. From `wdis` of `clibl.lib(stk)`:

- It fails when SP − AX would be at or below `__STACKLOW`, **and SS is
  still the SS it saw at startup**. With any other SS it never fails.
- On failure, `__STKOVERFLOW_` calls `__fatal_runtime_error`. That calls
  `__do_exit_with_msg_` in `cstart`, which:
  1. sets SP to `_end + 0x80`, 128 bytes above BSS;
  2. opens the device `con` (INT 21h/3D01h) and writes "Stack Overflow!" there;
  3. runs the runtime's termination routines (`__FiniRtns`: exit handlers,
     closing streams, the emulator's vectors);
  4. exits with status 1.

So:

- **The message never reaches standard error.** It goes to the screen, so
  a redirected or headless run, like every test here, can't see it.
- **In Perl, the handler crashes.** On the development build every
  recursion past depth 33 kills the DOSBox-X session; DOS never returns to
  the batch file.
  - A small C program that overflows its stack with checks on does exit with status 1 through the same handler, whether or not stdio is in use (it loses its buffered output).
  - What breaks in Perl's case is not pinned down. It is in that termination path, which runs with a 128-byte stack and Perl's open streams to close.
- **The runtime library is not checked.** `printf` and its floating-point
  formatting, `strtod` and the emulator never call `__STK`, so they run
  below the last check with no margin. Their frames are small, though:
  - `__prtf` 112 bytes, `_EFG_Format` 40, `__cvtld` 130, `__Strtold` 60;
  - the emulator's exception handler 94;
  - in all, well under 1 KB. Hardware interrupts also use the current stack.

`msdos/stk16.asm` replaces `__STK` (linked before the C library, so the
library's is ignored):

- It fails when SP − AX would come within a margin (`STK16_MARGIN`, 2,048 bytes in the variants) of `__STACKLOW`.
- It doesn't compare SS.
- It writes "Stack overflow" to handle 2 with INT 21h/40h and exits with INT 21h/4Ch, status 255, without running the C runtime on what is left of the stack.
- With margins of 0 and 2,048 it reported every overflow `scripts/stack-probe` caused, with no crash.
- The 2 KB margin costs about 4 levels of `simple` recursion, and the more complex check costs 3% in speed (section 5.4).

### 5.3 The configurations

Built by `scripts/build-variant` (`make variants`):

| Variant | Build |
|---|---|
| `dev` | the development build |
| `nochk` | `-s`: no stack checks |
| `os` | `-os`: optimise for size |
| `ox` | `-ox`: optimise for speed. In Open Watcom this includes `-s`. |
| `crip` | `-DCRIPPLED_CC` |
| `stk46` | (b): a 46 KB stack, the most DGROUP holds |
| `margin` | `msdos/stk16.asm` with a 2 KB margin |
| `rec` | `crip` and `margin`, with a 45 KB stack |
| `ss64` | (c): a 64 KB stack segment of its own, SS≠DS (section 5.5) |

### 5.4 Measurements

| Variant | `PERL.EXE` | Image | DGROUP | Stack |
|---|---|---|---|---|
| dev | 299,084 | 328,640 | 51,136 | 32,768 |
| nochk | 295,148 | 325,824 | 51,136 | 32,768 |
| os | 297,756 | 327,312 | 51,136 | 32,768 |
| ox | 296,316 | 327,008 | 51,136 | 32,768 |
| crip | 278,572 | 308,064 | 51,136 | 32,768 |
| stk46 | 299,084 | 342,976 | 65,472 | 47,104 |
| margin | 298,732 | 328,704 | 51,136 | 32,768 |
| rec | 278,220 | 321,440 | 64,448 | 46,080 |
| ss64 | 321,724 | 340,384 | 51,264 | 32,768 + 65,536 |

`ss64` still has the DGROUP stack. It is used only by the startup code and
by child processes (section 5.5), and could be much smaller.

Deepest recursion that finishes, and what happens one level deeper:

| Variant | simple | local | string |
|---|---|---|---|
| dev | 33, crash | 11, crash | 37, crash |
| nochk | 33, wrong exit | 11, crash | 37, crash |
| os | 45, wrong exit | 11, crash | 27, wrong exit |
| ox | 29, crash | 13, crash | 24, crash |
| crip | 101, crash | 56, crash | 80, crash |
| stk46 | 58, crash | 22, wrong exit | 41, crash |
| margin | 29, reported | 10, reported | 24, reported |
| rec | 131, reported | 58, reported | 106, reported |
| ss64 | 63, reported | 23, reported | 54, reported |

- "Crash" means the DOSBox-X session died.
- "Wrong exit" means DOS got control back, but the script didn't finish and nothing was reported.
- "Reported" means "Stack overflow" on standard error and exit status 255.
- The depths don't scale with the stack size alone, since each build's frames differ: `-os` gives smaller frames for `simple` and larger ones for `string`.

**The 46 KB stack breaks child processes.** On `stk46`, `system` returns
−1 with "No such file or directory" and backticks return nothing. The `t/`
suite shows this as a failure of `base.lex` test 12, and as `op.glob`
passing, since its expected list is the output of `echo op.*` and is now
empty too. Relinking the `dev` objects with other stacks:

| Stack | DGROUP free | `system` and backticks |
|---|---|---|
| 36, 40, 42, 44 KB | 10,304 to 2,112 | work |
| 45 KB | 1,088 | work |
| 46 KB | 64 | fail |

Presumably Open Watcom's spawn path needs a small allocation from the near
heap; the threshold is what was measured. So 45 KB is the practical
limit of option (b).

Emulated seconds (`scripts/bench`):

| Variant | startup | arith | string | regex | hash | subs | bigint | bigint vs dev |
|---|---|---|---|---|---|---|---|---|
| dev | 0.3 | 15.9 | 8.4 | 9.0 | 13.0 | 13.5 | 149.1 | — |
| nochk | 0.3 | 13.8 | 7.5 | 7.7 | 11.5 | 11.0 | 129.0 | −13% |
| os | 0.3 | 15.8 | 8.5 | 9.0 | 13.0 | 13.5 | 148.9 | 0% |
| ox | 0.3 | 13.6 | 7.4 | 7.7 | 11.4 | 11.0 | 128.4 | −14% |
| crip | 0.3 | 17.9 | 8.9 | 9.0 | 13.3 | 13.8 | 152.6 | +2% |
| stk46 | 0.3 | 15.9 | 8.4 | 9.0 | 13.0 | 13.5 | 148.8 | 0% |
| margin | 0.3 | 16.4 | 8.6 | 9.2 | 13.4 | 14.2 | 153.8 | +3% |
| rec | 0.3 | 18.6 | 9.2 | 9.3 | 13.7 | 14.5 | 158.0 | +6% |
| ss64 | 0.3 | 17.1 | 8.8 | 9.4 | 13.6 | 14.7 | 158.1 | +6% |

- Stack checks cost 13%.
- `-ox` gains almost nothing beyond turning them off, and `-os` changes nothing measurable.
- `CRIPPLED_CC` costs 2% overall and 13% in floating-point arithmetic, where `str_gnum` was inline.

`rec` passes all 13 smoke tests that aren't known failures, and also
`recurse` (marked todo, since the development build fails it). It gets
the same result as `dev` for every `t/` script. Its speed cost is
`CRIPPLED_CC` and the reporting check together.

### 5.5 SS≠DS: what it takes

`ss64` works like this:

- Every module is compiled with `-zu`, so the compiler doesn't assume SS = DGROUP. It addresses locals as SS-relative, and loads DS for DGROUP data.
- `perly.c` is compiled with `-Dmain=perl_main`.
- `msdos/sswitch.c`'s `main()` allocates a 64 KB segment from DOS, moves SS:SP to its top with interrupts off, calls `perl_main()`, and moves back.
- `__STACKLOW` is set to 0 for the new segment.
- Open Watcom's `__STK` never fails on a switched SS (section 5.2), so the variant links `msdos/stk16.asm`.

Checked assumptions:

- **ABI.** In the large model every data pointer is far. A pointer to a local is SS:offset, and the compiler forms it that way, with or without `-zu`. Perl itself needed no change.
- **Interrupts.** Hardware interrupt handlers, BIOS and DOS use the current stack and don't assume SS. The emulator's INT 34h–3Dh handlers run on the user stack. `atan2`, `sin`, `cos`, `exp`, `log`, `sqrt`, `**`, `int`, `hex`, `oct`, number formatting, `localtime`, `time`, `stat`, file I/O and `sort` all give the same results as `dev`.
  - Ctrl-C and Ctrl-Break (INT 23h) and the critical-error handler (INT 24h) were **not** tested, since the harness has no keyboard.
- **C runtime.** `wdis` of every linked runtime module found 58 that read or set SS. Most only form far pointers to locals, which is right on any stack. Code that loads DS from SS is in:
  - `dospawn`, `doexec`, `exvpe`, `spvpe` (processes);
  - `open`, `utime`;
  - `ldcvt`, `zbuf2ld` (number conversion);
  - the emulator.

  Two are wrong for SS≠DS, and the variant works around both:
  1. **Child processes** (found by the `t/` suite). `___dospawn` sets DS to SS, saves SS:SP through that DS, and after INT 21h/4Bh restores them from the real DGROUP. A child started from the separate stack therefore returns to a garbage stack: `system`, backticks and piped `open` crashed.
     - `sswitch.c` wraps `spawnvp`, `spawnv`, `spawnl`, `execvp`, `execv`, `execl` and `system` (Perl's calls are renamed to the wrappers with `-D`).
     - Each wrapper runs the library call on the original DGROUP stack, below `main()`'s frame.
  2. **Near heap growth** (found by reading the code; no test exercises it). `__brk` computes the program block's new size as `(SS − PSP) + break`, which is right only while SS is DGROUP. `msdos/brk16.asm` is the same routine using DGROUP.
     - The near heap can't grow on `ss64` anyway, since the stack segment is the DOS block right after the program. The fix makes that a clean failure rather than a resize request that spans the stack.
  Separately, the change of link layout exposed the environment defect that patch 0004 fixes (section 9). It wasn't an SS assumption, and it affected every build.

  The others passed every test, but this is not proof: each would need a read of its source, against a runtime perl16 will replace anyway.
- **DOS API.** EXEC (4Bh) is the only DOS call that cares where the stack is. Memory: the stack segment is allocated after startup, so it sits right after the program's block. If it can't be allocated, Perl runs on the DGROUP stack without saying so; a real implementation should report that or refuse to start.
- **Stack checks.** These need perl16's own `__STK` (or libc16's).

With those fixes, `ss64` gives the same result as `dev` for every one of
the 72 `t/` scripts, and passes the smoke tests. It is 6% slower: `-zu`
code reloads DS for DGROUP data. Its executable is 22 KB larger, and it
needs 64 KB of conventional memory more.

## 6. Recommendation

1. **Keep SS=DS** for the development build and for the libc16 builds until
   perl16's own startup owns the stack. SS≠DS works, and gives a stack of
   up to 64 KB with DGROUP left for data, but in this build it depends on
   Open Watcom's runtime having no more SS = DGROUP assumptions than the
   two M1 found and worked around. Under libc16 (M3) the startup, process calls
   and allocator are perl16's own, and SS≠DS can be designed in rather than
   patched around. Revisit it then, if the stack is still the limit.
2. **Report overflow, first**: link `msdos/stk16.asm` (or an equivalent in
   libc16) in every build, with a margin of 1–2 KB. It costs 3% in speed
   and makes overflow a clean `die`-like exit instead of a crash.
3. **Get the depth from smaller frames, not a bigger stack**:
   `-DCRIPPLED_CC` triples the depth for 2%, and makes the executable 20 KB
   smaller. Together with a 45 KB stack (and the check), `rec` reaches
   depth 131 for a simple sub and 58 with `local()`, for 6% in speed. The `str_gets()`
   buffer would give 7.5 KB more stack. Leave at least 1 KB of DGROUP
   free, or child processes fail (section 5.4).
4. Keep stack checks on; the 13% is the price of reporting overflow at all.

## 7. Follow-up work

Separate from M1, for M2 unless noted:

- Link a reporting stack check in the development build: `stk16.asm`, maybe with a cheaper check (it reloads DS on every call).
- Build with `-DCRIPPLED_CC`, after running the `t/` suite and the smoke tests on it.
- Shrink the `str_gets()` buffer in `str.c` and give the space to the stack, keeping 1 KB of DGROUP free. Choose the stack size from the map at build time.
- Make the `recurse` smoke test a real limit test: the depth the chosen build guarantees, and a check that one level too deep is reported.
- M3: in libc16's startup, decide the stack layout. If SS≠DS:
  - libc16's process calls, `sbrk` and stack check must not assume SS = DGROUP;
  - startup should report a stack it can't allocate;
  - Ctrl-C, Ctrl-Break and INT 24h must be tested on the switched stack.
- The defects already known: `packn`, `vec32`, `hashbig` (it limits a hash to 511 keys), `fpfmt`; issues #3 and #4.

## 8. Known limitations of the development build

- Stack overflow crashes DOS (section 5.2): about 33 levels of simple recursion, 11 with `local()`.
- A hash with more than 511 keys makes every store split the table until memory runs out (`hashbig`).
- `printf` rounds differently from glibc in the last digit (`fpfmt`).
- `pack("N")`, `vec()` with 32-bit width (`packn`, `vec32`).
- No `fork`, signals, pipes from processes, `perlglob`, `-P` (section 3).
- One object (string, array or hash table) can't exceed 64 KB, as in any large-model program. Memory runs out long before that with many small strings (section 4).
- It is linked with Open Watcom's runtime and can't be distributed.

## 9. Patch 0004: the environment

Open Watcom's `__CMain` (`clibl.lib(cmain086)`) calls `main_` with argc
in AX and argv in CX:BX, and nothing else. Perl 3's `main(argc, argv,
env)` reads `env` from the stack slots above the return address, which
hold whatever `__CMain` pushed. Perl compares it with `environ`, finds
them different, and:

- sets `environ[0]` to null, which empties the environment of every child process (`set` in a child shows no `PATH` or `COMSPEC`);
- builds `%ENV` from the garbage. In the development build that garbage happened to end at once, so `%ENV` was empty.

`%ENV` is only built if the script mentions `ENV` or `eval` (which makes
Perl create every special variable). When `sswitch.c` changed the link
layout, `env` pointed at C840:0000, unmapped memory full of 0xFF bytes,
and `index()` never found the end: every script with an `eval` hung.

The patch sets `env = environ` under `__WATCOMC__`.
`tests/smoke/environ.pl` checks `%ENV` and a child's environment. It fails
on the unpatched build.

## 10. Reproducing

    make                # build/dev/PERL.EXE
    make test           # smoke tests
    make test-t         # Perl 3.044's t/ suite against tests/t-baseline.txt
    make variants       # build/var/*/PERL.EXE and perl.map, FREEMEM.EXE
    make measure        # stack-probe on every variant; mem-probe on dev and ss64
    perl scripts/bench build/var/TICKS.EXE build/upstream/perl-3.044 \
        build/var/*/PERL.EXE
    perl scripts/mem-probe build/var/FREEMEM.EXE build/upstream/perl-3.044 \
        build/var/crip/PERL.EXE

- `make variants` also builds `build/var/FREEMEM.EXE` and `build/var/TICKS.EXE` from `tests/tools`.
- Each probe runs one DOSBox-X session per case.
  - `stack-probe` takes about 2 minutes per variant, and much longer where crashes wait for its 30-second timeout.
  - `mem-probe` takes about 5 minutes per executable.
  - `bench` takes about 4 minutes per executable.
- The emulated times are repeatable to a tick, because the cycle rate is fixed.

How the runtime was examined:

    wlib -q -x .../lib286/dos/clibl.lib        # in an empty directory
    wdis stk.o                                 # __STK
    wdis cstart.o                              # __do_exit_with_msg_
    wdis dospawn.o                             # ___dospawn

Never pass `-n` to `wlib` when listing or extracting: it creates an empty
library in place of the one named.
