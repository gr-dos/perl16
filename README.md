# perl16

Perl 3.044 for 16-bit real-mode MS-DOS (8086/8088, DOS 3.0 or later, no
DOS extender), built with Open Watcom on Linux. The plan is in
[`docs/DESIGN.md`](docs/DESIGN.md), and the findings of the first
milestones are in [`docs/M0-AUDIT.md`](docs/M0-AUDIT.md) (source and build
audit) and [`docs/M1-REPORT.md`](docs/M1-REPORT.md) (the exploratory
8086 build: size, memory, speed and the stack).

**Status: M1 (the exploratory 8086 build) is done.** The interpreter builds
and runs on an emulated 8086, but only as a development build linked with
Open Watcom's C runtime. **Those binaries must not be published**
(DESIGN.md, section 8). There is no release yet.

## Building

You need: `make`, `git`, `curl`, `unzip`, `xz`, `patch`, `bison`, Perl 5.36
or later and, for the tests, `dosbox-x`.

    make            # build/dev/PERL.EXE (development build only)
    make test       # smoke tests under DOSBox-X, emulated 8086
    make test-t     # Perl 3.044's own t/ suite, against tests/t-baseline.txt
    make variants   # the M1 experimental builds, in build/var
    make measure    # the M1 stack and memory measurements
    make audit      # what the interpreter needs from a C runtime
    make clean

`make` fetches and checks everything else:

- tag `perl-3.044` of the Perl repository (`scripts/fetch-upstream`)
- the pinned libc16 release (`scripts/fetch-libc16`)
- the Open Watcom snapshot that libc16 names

It then applies `patches/` and generates the parser.
[`docs/PROVENANCE.md`](docs/PROVENANCE.md) lists every input and change.

## License

Perl 3.044 is distributed under the GNU General Public License, version 1
or later; see its `README` and `Copying`, fetched into
`build/upstream/perl-3.044`. The license for perl16's own files is not yet
decided.
