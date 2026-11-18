/*
 * The exec family for the runtime build (M3.4, #17; docs/M3-RUNTIME-AUDIT.md,
 * section 6.6).
 *
 * DOS can't replace a running program, so exec runs the program as a
 * child with environ (environ.c), waits for it, and exits with its
 * status, as Microsoft C's and Open Watcom's exec functions do on DOS. If
 * the program can't be run, the call returns -1 with errno set by
 * libc16's spawn functions, and Perl goes on.
 *
 * libc16's output streams are unbuffered (its docs/spec/stdio.md), so
 * there is nothing to flush before the child runs.
 */

#include <errno.h>
#include <stdarg.h>
#include <stdlib.h>
#include <process.h>
#include "environ.h"

/* The most arguments execl() takes, arg0 included, and the null: a
 * 126-byte command tail holds at most 63 arguments after arg0, each a
 * space and one character. More fail with E2BIG and nothing is run;
 * fewer can still make a tail too long, which spawnve() refuses with
 * E2BIG. */
#define EXEC_ARGS 65

static int
exec_status(int status)
{
    if (status == -1)
	return -1;
    exit(status);
    return -1;			/* not reached */
}

int
execv(const char *path, char * const *argv)
{
    return exec_status(spawnve(P_WAIT, path, argv, environ));
}

int
execvp(const char *file, char * const *argv)
{
    return exec_status(spawnvpe(P_WAIT, file, argv, environ));
}

int
execl(const char *path, const char *arg0, ...)
{
    char *argv[EXEC_ARGS];
    va_list ap;
    int n = 0;

    argv[n++] = (char *)arg0;
    va_start(ap, arg0);
    if (arg0 != 0)
	while ((argv[n] = va_arg(ap, char *)) != 0)
	    if (++n == EXEC_ARGS) {
		va_end(ap);
		errno = E2BIG;
		return -1;
	    }
    va_end(ap);
    return execv(path, argv);
}
