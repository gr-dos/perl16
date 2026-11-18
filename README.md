# perl16

Perl 3.044 for 16-bit real-mode MS-DOS (8086/8088, DOS 3.0 or later, no
DOS extender), built with Open Watcom on Linux. The plan is in
[`docs/DESIGN.md`](docs/DESIGN.md). The milestone reports are:

- [`docs/M0-AUDIT.md`](docs/M0-AUDIT.md): source and build audit.
- [`docs/M1-REPORT.md`](docs/M1-REPORT.md): the exploratory 8086 build;
  size, memory, speed and the stack.
- [`docs/M2-REPORT.md`](docs/M2-REPORT.md): core functionality and
  relocation.
- [`docs/M3-RUNTIME-AUDIT.md`](docs/M3-RUNTIME-AUDIT.md): M3.1, what the
  interpreter needs from a runtime against libc16, who provides each
  piece, and the `libkitchen16` decision.

[`docs/DOS.md`](docs/DOS.md) describes how `PERL.EXE` behaves on DOS:
installing it, `@INC`, `-e`, limits, and what DOS can't do.

**Status: M2 (core functionality and relocation) is done**, except for
tests on physical hardware. `PERL.EXE`
runs from any directory on any drive and finds its `LIB` directory
itself. It reports stack overflow instead of crashing, and passes its
smoke, installation and Perl 3 regression tests on an emulated 8086. It
is still a development build linked with Open Watcom's C runtime.
**Those binaries must not be published** (DESIGN.md, section 8). There
is no release yet. M3 replaces the runtime. Its audit (M3.1) is done,
and the libc16 and libkitchen16 releases it called for are pinned.

## Building

You need: `make`, `git`, `curl`, `unzip`, `xz`, `patch`, GNU Bison 3.8.2
(the parser is pinned to it; `make BISON=...` selects another binary),
Perl 5.36 or later and, for the tests, `dosbox-x`.

    make            # build/dev/PERL.EXE (development build only)
    make test       # smoke and installation tests under DOSBox-X, emulated 8086
    make test-t     # Perl 3.044's own t/ suite, against tests/t-baseline.txt
    make variants   # the M1 experimental builds, in build/var
    make measure    # the M1 stack and memory measurements
    make rt         # build/rt/PERL.EXE: libc16 and libkitchen16 instead of
                    # Open Watcom's runtime (M3.4, in progress)
    make test-rt    # the smoke and installation tests of build/rt/PERL.EXE
    make test-t-rt  # the t/ suite under build/rt/PERL.EXE
    make audit      # what the interpreter needs from a C runtime, with
                    # Open Watcom's headers, and with libc16's and libkitchen16's
    make clean

`make` fetches and checks everything else:

- tag `perl-3.044` of the Perl repository (`scripts/fetch-upstream`)
- the pinned libc16 release (`scripts/fetch-libc16`, 0.12)
- the pinned libkitchen16 release (`scripts/fetch-libkitchen16`, 0.02),
  floating point and formatting for M3
- the Open Watcom snapshot that libc16 names (libkitchen16 must name the
  same one)

It then applies `patches/` and generates the parser, which it checks
against `upstream/parser.sha256`.
[`docs/PROVENANCE.md`](docs/PROVENANCE.md) lists every input and change.

## License

Perl 3.044 is distributed under the GNU General Public License, version 1
or later; see its `README` and `Copying`, fetched into
`build/upstream/perl-3.044`. The license for perl16's own files is not yet
decided.
