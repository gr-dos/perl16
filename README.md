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
  piece, and the `libkitchen16` decision; and M3.4's runtime build,
  step by step.
- [`docs/M3-REPORT.md`](docs/M3-REPORT.md): the runtime migration's
  result; size, memory, speed, the link checks, and what is left for
  M4.

[`docs/DOS.md`](docs/DOS.md) describes how `PERL.EXE` behaves on DOS:
installing it, `@INC`, `-e`, limits, and what DOS can't do.

**Status: M3 (runtime migration): the runtime build is the default.**
`make` builds `PERL.EXE` with libc16 and libkitchen16, independently
written runtimes, and no Open Watcom runtime code: the link fails if
any gets in (`scripts/check-link`). It runs from any directory on any
drive and finds its `LIB` directory itself. It reports stack overflow
instead of crashing, and passes its smoke, installation and Perl 3
regression tests on an emulated 8086. Tests on physical hardware and
the human review of the libraries' provenance records remain
(docs/M3-REPORT.md, section 7). There is no release yet: M4 makes the
release candidate, and **no binary may be published before it**
(DESIGN.md, section 8). The M2 development build, linked with Open
Watcom's runtime, is still there for comparison (`make dev`), and must
never be published.

## Building

You need: `make`, `git`, `curl`, `unzip`, `xz`, `patch`, GNU Bison 3.8.2
(the parser is pinned to it; `make BISON=...` selects another binary),
Perl 5.36 or later and, for the tests, `dosbox-x`.

    make            # build/rt/PERL.EXE, with libc16 and libkitchen16, and
                    # the link checks
    make test       # smoke and installation tests under DOSBox-X, emulated 8086
    make test-t     # Perl 3.044's own t/ suite, against tests/t-baseline.txt
    make dev        # build/dev/PERL.EXE, the M2 development build, with
                    # Open Watcom's runtime (never to be published)
    make test-dev   # its smoke and installation tests
    make test-t-dev # the t/ suite under it
    make variants   # the M1 experimental builds, in build/var
    make measure    # the M1 stack and memory measurements
    make audit      # what the interpreter needs from a C runtime, with
                    # Open Watcom's headers, and with libc16's and libkitchen16's
    make clean

`make` fetches and checks everything else:

- tag `perl-3.044` of the Perl repository (`scripts/fetch-upstream`)
- the pinned libc16 release (`scripts/fetch-libc16`, 0.15)
- the pinned libkitchen16 release (`scripts/fetch-libkitchen16`, 0.02),
  floating point, formatting and `<math.h>`
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
