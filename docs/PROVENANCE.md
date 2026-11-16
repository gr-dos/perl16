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

## Generated files

`perl.c` and `perly.h` are generated from `perl.y` by `scripts/yacc-perl`
(bison in yacc mode), as upstream's `Makefile.SH` does. They aren't
stored.

## perl16's own files

| File | Purpose |
|---|---|
| `msdos/mktemp.c` | `mktemp()`, which neither Open Watcom's runtime nor libc16 has |
| `scripts/*`, `tests/*`, `Makefile` | build, audit and test tooling |

Their license is still to be chosen (docs/M0-AUDIT.md, section 3).
