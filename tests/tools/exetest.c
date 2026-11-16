/*
 * Unit tests of msdos/exepath.c under DOS: environment blocks of every
 * shape, absolute paths from the current drive and directories, and the
 * library directory. tests/run-install runs it with C:\WORK\SUB current
 * on C: and \TOOLS\PERL current on D:, and compares its output.
 *
 * Build (large model, like PERL.EXE): see the Makefile's test-tools.
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "exepath.h"

static int failed;

static void
env_case(const char *what, const char *block, unsigned size, const char *want)
{
    char out[EXEPATH_MAX];
    int rc = exepath_from_env((const char far *)block, size, out, sizeof(out));
    const char *got = rc == 0 ? out : "(invalid)";

    if (strcmp(got, want) != 0)
	failed++;
    printf("env %-12s %s%s\n", what, got,
      strcmp(got, want) == 0 ? "" : "  <- WRONG");
}

static void
abs_case(const char *name, const char *want)
{
    char out[EXEPATH_MAX];
    int rc = exepath_absolute(name, out, sizeof(out));
    const char *got = rc == 0 ? out : "(invalid)";

    if (strcmp(got, want) != 0)
	failed++;
    printf("abs %-16s %s%s\n", name, got,
      strcmp(got, want) == 0 ? "" : "  <- WRONG");
}

static void
lib_case(const char *path, const char *want)
{
    char buf[EXEPATH_MAX];
    const char *got;

    strcpy(buf, path);
    got = exepath_libdir(buf, sizeof(buf)) == 0 ? buf : "(none)";
    if (strcmp(got, want) != 0)
	failed++;
    printf("lib %-16s %s%s\n", path, got,
      strcmp(got, want) == 0 ? "" : "  <- WRONG");
}

int
main(int argc, char **argv)
{
    static char long_block[300];
    char *lib;

    /* the shapes DOS 3.0+ makes */
    env_case("normal", "A=1\0B=22\0\0\1\0C:\\PERL\\PERL.EXE\0", 32,
      "C:\\PERL\\PERL.EXE");
    env_case("no strings", "\0\1\0D:\\X.EXE\0", 12, "D:\\X.EXE");
    env_case("relative", "P=1\0\0\1\0X:PERL.EXE\0", 19, "X:PERL.EXE");
    /* what has to be refused */
    env_case("count 0", "A=1\0\0\0\0C:\\P.EXE\0", 17, "(invalid)");
    env_case("no end", "A=1\0B=2", 7, "(invalid)");
    env_case("no count", "A=1\0\0", 5, "(invalid)");
    env_case("unended", "A=1\0\0\1\0C:\\P.EXE", 15, "(invalid)");
    env_case("empty name", "A=1\0\0\1\0\0", 9, "(invalid)");
    env_case("control", "A=1\0\0\1\0C:\\P\x01.EXE\0", 17, "(invalid)");
    env_case("null", 0, 100, "(invalid)");
    memcpy(long_block, "A=1\0\0\1\0", 7);
    memset(long_block + 7, 'X', 200);
    long_block[207] = '\0';
    env_case("too long", long_block, sizeof(long_block), "(invalid)");

    abs_case("C:\\PERL\\P.EXE", "C:\\PERL\\P.EXE");
    abs_case("\\PERL\\P.EXE", "C:\\PERL\\P.EXE");
    abs_case("P.EXE", "C:\\WORK\\SUB\\P.EXE");
    abs_case("BIN\\P.EXE", "C:\\WORK\\SUB\\BIN\\P.EXE");
    abs_case("D:P.EXE", "D:\\TOOLS\\PERL\\P.EXE");
    abs_case("d:p.exe", "D:\\TOOLS\\PERL\\p.exe");
    abs_case("D:\\P.EXE", "D:\\P.EXE");
    abs_case("D:/A/P.EXE", "D:\\A/P.EXE");
    abs_case("Q:P.EXE", "(invalid)");

    lib_case("C:\\PERL\\PERL.EXE", "C:\\PERL\\LIB");
    lib_case("C:\\PERL.EXE", "C:\\LIB");
    lib_case("D:/A/PERL.EXE", "D:/A/LIB");
    lib_case("C:\\PERL\\", "(none)");
    lib_case("PERL.EXE", "(none)");

    /* this program's own, from its environment block */
    lib = perl16_libdir(argv[0]);
    printf("self %s\n", lib ? lib : "(none)");

    printf(failed ? "exetest: %d WRONG\n" : "exetest: all right\n", failed);
    return failed != 0;
}
