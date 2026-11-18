/*
 * Unit test of msdos/exec16.c's execl() under DOS, runtime build only:
 * the argument cap and the command-tail limit. tests/run-install runs it
 * as C:\WORK\BIN\EXECLTST.EXE and compares its output.
 *
 * - 65 arguments, one over the cap, fail with E2BIG and run nothing.
 * - 3 arguments whose tail is 127 bytes fail with E2BIG from spawnve()
 *   and run nothing.
 * - 64 arguments, the cap, with a tail of exactly 126 bytes, run this
 *   program again as a child, which prints what it was given; execl()
 *   then exits with the child's status.
 *
 * A child run by mistake prints its line and ends the test early, so
 * the output shows it. Built against libc16 (Makefile, EXECLTST.EXE).
 */

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include "environ.h"

#define SELF "C:\\WORK\\BIN\\EXECLTST.EXE"

/* 61 one-character arguments: with arg0, "c" and "z", 64 in all, and a
 * tail of 2 + 61 * 2 + 2 = 126 bytes. */
#define X4  "x", "x", "x", "x"
#define X16 X4, X4, X4, X4
#define X61 X16, X16, X16, X4, X4, X4, "x"

static void
refused(const char *what, int r)
{
    printf("%s: %s\n", what,
	   r == -1 && errno == E2BIG ? "E2BIG" : "WRONG");
}

int
main(int argc, char **argv)
{
    static char long_arg[125];
    int r;

    if (argc > 1 && strcmp(argv[1], "c") == 0) {
	printf("child: %d arguments, last %s\n", argc, argv[argc - 1]);
	return 0;
    }

    errno = 0;
    r = execl(SELF, SELF, "c", X61, "z", "z", (char *)0);
    refused("65 arguments", r);

    /* " c" and " " and 124 characters: 127 bytes */
    memset(long_arg, 'y', sizeof long_arg - 1);
    errno = 0;
    r = execl(SELF, SELF, "c", long_arg, (char *)0);
    refused("127-byte tail", r);

    printf("64 arguments, 126-byte tail:\n");
    execl(SELF, SELF, "c", X61, "z", (char *)0);
    printf("WRONG: execl returned, errno %d\n", errno);
    return 1;
}
