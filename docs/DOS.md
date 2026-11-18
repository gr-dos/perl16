# Perl 3 on DOS: what to expect

How perl16's `PERL.EXE` behaves on DOS: installing it, where it looks for
libraries, and what works differently from Perl 3 on Unix. This
describes the M2 development build. The measurements and decisions behind
it are in [M2-REPORT.md](M2-REPORT.md). There is no release yet. The
development build is linked with Open Watcom's C runtime and must not be
distributed (DESIGN.md, section 8).

## Requirements

- An 8086 or 8088 PC or better, real mode, and DOS 3.0 or later. No DOS
  extender is needed.
- Conventional memory: about 320 KB free to start, 376 KB for a short
  script, and more for data (M2-REPORT.md, section 4.4). On a 640 KB
  machine, plan on 512 KB free or more.
- An 8087 is not needed. Floating point is emulated when there isn't one.

## Installing

Put `PERL.EXE` in any directory on any drive, with a `LIB` directory
beside it for library files:

    X:\ANY\WHERE\PERL.EXE
    X:\ANY\WHERE\LIB\...

Nothing needs to be set in the environment. Perl finds `LIB` from where
`PERL.EXE` was loaded, however it was started: through `PATH`, by
absolute path, from another drive, as `X:PERL.EXE` (the current directory
of X:), as `\DIR\PERL.EXE`, or by a relative path. No helper programs
are needed: there is no `GLOB.EXE`.

## Where `require` and `do` look: `@INC`

`@INC` is, in this order:

1. the directories given with `-I`, in command-line order (`-IDIR` or
   `-I DIR`);
2. `<directory containing PERL.EXE>\LIB`, as a full path, such as
   `C:\PERL\LIB`;
3. `.`, the current directory.

So `-I` comes before the installed library, and the current directory
comes last, as in Perl 3 on Unix, where entry 2 was
`/usr/local/lib/perl`. The first file found is used. Perl 3 has no
`PERLLIB` variable. To add a directory, use `-I`, or change `@INC` in
the script.

Perl finds its directory from the program name DOS 3.0 and later put in
the program's environment block. It makes the name absolute with the
current drive and directory if it isn't already. If that name is
missing or malformed, Perl uses `argv[0]` when it names a directory.
Failing both, entry 2 is left out, and `-I` and `.` still work. This
can only happen with an unusual loader, never from `COMMAND.COM`.

## `perl -e`

The `-e` lines are written to a temporary file named `PLxxxxxx.TMP`. Perl
runs that file and removes it once the script is compiled, or when it
dies before then. The file goes in the first directory that works of:

1. `%TEMP%`
2. `%TMP%`
3. the current directory.

A variable that is unset or empty is skipped. If a directory doesn't
exist or can't be written to, the next one is tried. If none works, Perl
stops with `Can't create temporary file for -e in DIR: REASON` and a
nonzero exit status, where DIR is the last directory tried. So `-e`
works from a read-only drive if `TEMP` or `TMP` names a writable
directory.

The file is created with DOS's "create new file" call. An existing file
is never overwritten, and a name that is taken is retried with another.
DOS has no file permissions, though, so any program can still read or
change the file while Perl runs. On a write-protected floppy, DOS asks
"Abort, Retry, Fail?" before Perl sees the error. Answer F to have Perl
try the next directory.

## Exit status

- `exit N` sets the DOS errorlevel to N.
- An uncaught `die` exits with the value of `$!` if it is nonzero, else
  that of `$? >> 8` if that is, else 255, as on Unix.
- A stack overflow prints `Stack overflow` on standard error and exits
  with status 255. It doesn't crash DOS.
- Running out of memory prints `Out of memory!` and exits with status 1.

## Limits

- **Recursion.** About 150 levels of a simple recursive sub, or 65 with
  `local()`, before `Stack overflow` (M2-REPORT.md, section 4). Perl
  guarantees 120 and 50 in its tests.
  The runtime build (`make rt`, M3.4) goes deeper: about 205, or 100
  with `local()`.
- **Strings, arrays and hash tables.** One string, or the pointer table
  of one array, is limited to 64 KB, as in any large-model DOS program.
  A hash's table stops growing at 8,192 buckets. More keys still work,
  just more slowly. Memory usually runs out first.
- **Lines.** `<FH>` reads lines of any length, and keeps NUL bytes.
- **`sprintf` conversions.** Each conversion is cut to 1,023 bytes:
  `sprintf("%2000d", 7)` gives 1,023 characters, all spaces. A plain
  `%s` is not cut. A `%s` whose flags and width take 190 characters or
  more is treated as a plain `%s`.
- **File names.** DOS 8.3 names. `/` and `\` both work as separators
  in file names Perl passes to DOS. In a string, `\` needs escaping as
  usual (`"C:\\DIR"`).

## Files

Files are opened in text mode: `CR LF` reads as `\n`, and `\n` is
written as `CR LF`. Use `binmode(FH)` for binary data. `-s` gives the
size on disk, `CR`s included.

- **Open files.** In the runtime build, five files can be open at
  once beside `STDIN`, `STDOUT` and `STDERR` (libc16's `FOPEN_MAX` is
  8). Another `open` fails with "Too many open files" until one is
  closed. A duplicated handle such as `open(STDERR, ">&STDOUT")` counts
  while it is open. The development build allows about 20.
- **Disk and printer errors.** In the runtime build, a drive that isn't
  ready, a write-protected disk or a printer out of paper never stops
  Perl with DOS's "Abort, Retry, Fail?". The call fails, and `$!` says
  why: "Permission denied (drive A: not ready)". The development
  build leaves DOS's prompt in place.

## Globbing

`<*.c>` and `<DIR\*.*>` are expanded by Perl itself, with DOS's wildcard
rules:

- `*` and `?` work only in the last part of a path.
- `*.*` matches every name, and `*` only names without an extension.
- Directories match too. Hidden and system files, `.` and `..` don't.
- The results are sorted and lower-cased, after the directory part as
  you wrote it (`<GL\*.TXT>` gives `GL\a.txt` and so on).
- A pattern that matches nothing gives nothing. A word with no wildcard
  is returned as it is.
- Patterns are separated by blanks.
- In an interpolated pattern, write `/` as the separator: `\` is an
  escape there.

## Processes

- **Running commands.** `system`, `exec` and backticks run commands with
  `spawn`, through `COMMAND.COM` (`COMSPEC`) when the command has `<`,
  `>` or `|` in it. The child gets the environment, `%ENV` included. It
  needs conventional memory beside Perl's: small DOS commands fit, but a
  second `PERL.EXE` usually doesn't (DOS error 8).
  - In the runtime build (`make rt`, M3.4), a command with `<`, `>` or
    `|`, or one that can't be run directly (a `COMMAND.COM` built-in
    such as `echo` or `set`), reaches `COMSPEC /C` exactly as written,
    double quotes, spaces and `%` included, with `%ENV` as the
    environment. The shell is the one `COMSPEC` named when Perl
    started; changing `$ENV{'COMSPEC'}` passes the new value on but
    doesn't change the shell. The command can be at most 122
    characters (`$!` is then "Arg list too long").
  - A command run directly is split into arguments as a C program's
    startup splits its command line, so `prog "a b"` gives `prog` one
    argument, `a b`, and `system` returns its exit status. Through the
    shell, `system` returns the shell's exit status, which DOSBox-X's
    `COMMAND.COM` doesn't take from the program.
- **Piped opens.** These are emulated with temporary files.
  `open(F, "cmd |")` runs `cmd` to completion first, then reads its
  output. `open(F, "| cmd")` collects what you print, and runs `cmd` on
  it when F is closed.
- **`sleep`** waits by polling the clock.

## Not available on DOS

These are intentional limitations, not bugs. Each one dies with a
message, which `eval` can catch, and `tests/smoke/unsupp.pl` checks
them:

| Operation | Message |
|---|---|
| `fork`, `wait`, `kill`, `alarm`, `pipe`, `getppid` | `Unsupported function NAME` |
| `umask`, `chown`, `link`, `symlink`, `readlink`, `chroot` | `Unsupported function NAME` |
| `socket` and the other socket functions | `Unsupported socket function` |
| `getpw*`, `getgr*`, `getlogin` | `Unsupported password function` and so on |
| `truncate` | `truncate not implemented` |
| `fcntl`, System V IPC (`msgget` and so on), `select` with four arguments | `... not implemented` |
| `-T` and `-B` on a filehandle (on a file name they work) | `-T and -B not implemented on filehandles` |
| in-place editing (`-i`) without a backup extension | `Can't do inplace edit without backup` |
| `-P` (C preprocessor) | `-P is not supported on MS-DOS (it needs sed and a C preprocessor)` |

Some things return something but mean little on DOS:

- user and group IDs are 0;
- `chmod` sets only the read-only attribute;
- `stat` has no inode numbers, links or owners;
- `times` has no CPU times;
- signals other than those DOS raises (Ctrl-C) never arrive.

Anything else that fails where Perl 3 on Unix works should be reported
as a bug. That includes a crash or hang instead of a message, or a
nonzero exit without one.

## Known problems

- Numbers are formatted by Open Watcom's `printf`. Ties round away from
  zero (`%.0f` of 2.5 gives 3), and the 20th significant digit can be
  wrong, so `print 1/3` ends differently from Perl 3 on Unix. This goes
  away with perl16's own runtime (M3).
- In this build, temporary files for piped opens go where Open Watcom's
  `tempnam()` puts them (`TMP`, else the root directory), not where
  `-e`'s do.
- In this build, comparisons with a NaN (`9**9**9 - 9**9**9`) or an
  infinity can be wrong: Open Watcom's floating-point emulator makes a
  NaN equal to every number, and `0 == 9**9**9` true. The runtime build
  (`make rt`, M3.4) compares them as Perl 3 does on an IEEE machine,
  and treats `-0.0` and the smallest numbers (below about `1e-308`)
  correctly too (docs/M3-RUNTIME-AUDIT.md, section 11.7).
