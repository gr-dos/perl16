# perl16 — provenance

What perl16 is built from, and every change it makes to that.

## Upstream

| What | Where | Pinned by |
|---|---|---|
| Perl 3.044 (perl 3.0 patch level 44, 1991), Larry Wall, GPL-1.0-or-later | tag `perl-3.044`, https://github.com/Perl/perl5 | `scripts/fetch-upstream`: commit `27e2fb84680b9cc1db17238d5bf10b97626f477f`, tree `39824ce086ad815a976233d0edef5992b06e833c`, `upstream/MANIFEST.sha256` |
| The MS-DOS port (`msdos/` in the tag), Diomidis Spinellis, same terms | as above | as above |

The repository doesn't contain the upstream source. The build fetches it
into `build/upstream` and assembles `build/src` from it (Makefile).

## Reference material (not built)

| What | Pinned by |
|---|---|
| `dospatch44`, `perl3.0-44.tar.gz`, `README.msdos`, from https://www2.dmst.aueb.gr/dds/sw/ports/dosperl/ | `scripts/fetch-reference`, `upstream/reference.sha256` |

## Changes to upstream files

They are applied in order from `patches/`, and each patch's header gives
its reasons.

| Patch | Author | Files | Summary |
|---|---|---|---|
| `0001-dospatch44.patch` | derived from Diomidis Spinellis's dospatch44 (1999) | `eval.c`, `msdos/config.h`, `msdos/msdos.c`, `perly.c` | the maintenance patch, less its `msdos/Makefile` hunk |
| `0002-watcom-compile.patch` | perl16 | `cons.c`, `eval.c`, `msdos/config.h`, `msdos/directory.c`, `msdos/msdos.c`, `msdos/popen.c`, `perl.h`, `perly.c`, `toke.c`, `util.h` | compile under Open Watcom C with its headers |
| `0003-watcom-varargs.patch` | perl16 | `perl.h` | prototypes for the `<varargs.h>` functions, for Watcom's calling convention |
| `0004-watcom-environ.patch` | perl16 | `perly.c` | take the environment from `environ`, since Watcom passes `main()` none |
| `0005-16bit-int.patch` | perl16 | `doarg.c`, `eval.c`, `hash.c`, `perl.h` | 16-bit `int` defects: `pack`/`unpack` `N`, `pack` casts, `vec()` 16/32, hash growth past 512 buckets, `sleep` |
| `0006-str-gets.patch` | perl16 | `str.c` | `str_gets()`: a 512-byte buffer in place of 8 KB of DGROUP, and lines with NUL bytes kept whole |
| `0007-dos-inc-etemp.patch` | perl16 | `perly.c` | `@INC` from `PERL.EXE`'s directory, the `-e` file in `TEMP`/`TMP` created exclusively, `-P` refused |
| `0008-dos-glob.patch` | perl16 | `msdos/popen.c` | `<*.c>` without a helper program |
| `0009-p16rt.patch` | perl16 | `cmd.c`, `dolist.c`, `msdos/msdos.c`, `msdos/popen.c`, `perly.c`, `stab.c`, `util.c` | compile and run against libc16 and libkitchen16 (M3.4): `<stdarg.h>`, `__cdecl` callbacks, `main` with two parameters, `environ` for children, the piped-open file from `etemp.c` |
| `0010-randbits.patch` | perl16 | `msdos/config.h` | `RANDBITS` 15: both runtimes' `rand()` gives 15 bits (#16) |
| `0011-sprintf-snprintf.patch` | perl16 | `doarg.c` | `do_sprintf()` formats each conversion with `snprintf()`, cut to 1,023 bytes, rather than overrunning `buf` (#16) |
| `0012-fpc-compare.patch` | perl16 | `cmd.c`, `consarg.c`, `doio.c`, `eval.c`, `perl.h`, `str.c` | truth, `<=>`, `>`, `>=` and division by zero with `msdos/p16fp.h`, right under `wcc -fpc` for `-0.0`, subnormals and NaNs (#16) |

## Generated files

`perl.c` and `perly.h` are generated from `perl.y` by `scripts/yacc-perl`
(bison in yacc mode), as upstream's `Makefile.SH` does. They aren't
stored. The parser is pinned: the script requires GNU Bison 3.8.2
(`bison-3.8.2.tar.xz`, sha256
`9bba0214ccf7f1079c5d59210045227bcf619519840ebfa80cd3849cff5a5bf2`,
signed by key `7DF84374B1EE1F9764BBE25D0DDCAA3278D5264E`), and checks
both files against `upstream/parser.sha256`. The script's header gives
the procedure for changing the pin.

## perl16's own files

| File | Purpose |
|---|---|
| `msdos/exepath.c`, `exepath.h` | the directory `PERL.EXE` was loaded from, for `@INC` (docs/M2-REPORT.md, section 5) |
| `msdos/etemp.c`, `etemp.h` | the `-e` temporary file (docs/M2-REPORT.md, section 6) |
| `msdos/dosglob.c`, `dosglob.h` | filename globbing (docs/M2-REPORT.md, section 7) |
| `msdos/stk16.asm` | the stack check: a guard margin, and overflow reported on standard error with status 255; in the default build since M2 (docs/M2-REPORT.md, section 4); on `_end` in the runtime build (M3.4) |
| `msdos/p16rt.h` | force-included in every module: the library prototypes in the runtime build, and `P16_CB`, the callback convention (M3.4) |
| `msdos/environ.c`, `environ.h`, `msdos/exec16.c`, `msdos/p16init.asm` | `environ` and the `exec` family, which libc16 doesn't have; runtime build only (M3.4) |
| `msdos/p16fp.c`, `p16fp.h` | numeric tests `wcc -fpc` gets wrong: a zero the compiler can't see, and `>` and `>=` false with a NaN; runtime build only (M3.4, #16) |
| `msdos/sswitch.c`, `msdos/brk16.asm` | running Perl on a stack segment of its own (SS != DS); M1 experiment, not in the default build |
| `scripts/audit-include/*` | audit-only stand-ins for what libc16's and libkitchen16's headers lack, used by `scripts/audit-libc16` and never by the build; written from ISO C and POSIX (their `README`; docs/M3-RUNTIME-AUDIT.md, section 2) |
| `scripts/fetch-libc16`, `scripts/fetch-libkitchen16` | copies of libc16's and libkitchen16's `consumers/` fetch scripts (MIT), set to the pinned releases: libc16 0.15 and libkitchen16 0.02, each checked by its release's SHA-256 |
| `scripts/*`, `tests/*`, `Makefile` | build, audit and test tooling |
| `upstream/*.sha256` | hashes of the upstream source, reference material and generated parser |

Their license is still to be chosen (docs/M0-AUDIT.md, section 3).
