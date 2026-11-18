/*
 * environ for the runtime build (M3.4, #17; docs/M3-RUNTIME-AUDIT.md,
 * sections 6.2 and 7.5).
 *
 * Perl 3 reads and changes the environment through environ: %ENV is
 * built from it (perly.c), setenv() (util.c) rewrites it, and children
 * are given it (msdos.c, exec16.c). libc16 has no environ: its getenv()
 * reads the PSP's environment block, and its startup passes main() no
 * environment. perl16_environ_init(), an init-table routine
 * (p16init.asm), copies the PSP's environment strings into the heap
 * before main() and points environ at a null-terminated array of them.
 *
 * Changes Perl makes are seen by its children, which are given environ,
 * but not by libc16's getenv(), which still reads the block DOS gave.
 *
 * If there is no environment block, or the heap can't hold a copy,
 * environ is empty. Large model only: the block is read through data
 * pointers, which are far.
 */

#include <stdlib.h>
#include <string.h>
#include <dos.h>
#include "environ.h"

#define ENV_MAX 32768U		/* DOS limits an environment to 32 KB */

static char *no_env[1];

char **environ = no_env;

/* The length of the environment block's strings: the bytes before the
 * empty string that ends them, or 0 if there is none within ENV_MAX. */
static unsigned
env_strings(const char far *blk, unsigned *count)
{
    unsigned off = 0, n = 0;

    while (off < ENV_MAX && blk[off] != '\0') {
	while (off < ENV_MAX && blk[off] != '\0')
	    off++;
	if (off >= ENV_MAX)
	    return 0;
	off++;
	n++;
    }
    if (off >= ENV_MAX)
	return 0;
    *count = n;
    return off;
}

void
perl16_environ_init(void)
{
    unsigned envseg = *(unsigned far *)MK_FP(_psp, 0x2c);
    const char far *blk;
    unsigned len, count, i;
    char **env;

    if (envseg == 0)
	return;
    blk = (const char far *)MK_FP(envseg, 0);
    if ((len = env_strings(blk, &count)) == 0)
	return;
    env = (char **)malloc((count + 1) * sizeof(char *));
    if (env == 0)
	return;
    for (i = 0; i < count; i++) {
	if ((env[i] = strdup((const char *)blk)) == 0) {
	    while (i > 0)
		free(env[--i]);
	    free(env);
	    return;
	}
	blk += strlen(env[i]) + 1;
    }
    env[count] = 0;
    environ = env;
}
