/*
 * CTYPETST: msdos/ctype16.h's macros against libc16's <ctype.h>
 * functions, for every value from EOF to 255 (#17). Compiled like the
 * runtime build, whose msdos/p16rt.h includes ctype16.h; this file takes
 * each macro's result, then #undefs it to call libc16's function. Prints
 * each disagreement and a count; never distributed.
 */

#include <ctype.h>
#include <stdio.h>
#include "ctype16.h"

#define N 12

static void
macros(int c, int *r)
{
    r[0] = isalnum(c) != 0;
    r[1] = isalpha(c) != 0;
    r[2] = isascii(c) != 0;
    r[3] = iscntrl(c) != 0;
    r[4] = isdigit(c) != 0;
    r[5] = isgraph(c) != 0;
    r[6] = islower(c) != 0;
    r[7] = isprint(c) != 0;
    r[8] = ispunct(c) != 0;
    r[9] = isspace(c) != 0;
    r[10] = isupper(c) != 0;
    r[11] = isxdigit(c) != 0;
}

#undef isalnum
#undef isalpha
#undef isascii
#undef iscntrl
#undef isdigit
#undef isgraph
#undef islower
#undef isprint
#undef ispunct
#undef isspace
#undef isupper
#undef isxdigit

static void
functions(int c, int *r)
{
    r[0] = isalnum(c) != 0;
    r[1] = isalpha(c) != 0;
    r[2] = isascii(c) != 0;
    r[3] = iscntrl(c) != 0;
    r[4] = isdigit(c) != 0;
    r[5] = isgraph(c) != 0;
    r[6] = islower(c) != 0;
    r[7] = isprint(c) != 0;
    r[8] = ispunct(c) != 0;
    r[9] = isspace(c) != 0;
    r[10] = isupper(c) != 0;
    r[11] = isxdigit(c) != 0;
}

int
main(void)
{
    static const char *name[N] = { "isalnum", "isalpha", "isascii",
	"iscntrl", "isdigit", "isgraph", "islower", "isprint", "ispunct",
	"isspace", "isupper", "isxdigit" };
    int m[N], f[N], c, i, bad = 0, checked = 0;

    for (c = EOF; c <= 255; c++) {
	macros(c, m);
	functions(c, f);
	for (i = 0; i < N; i++) {
	    checked++;
	    if (m[i] != f[i]) {
		printf("%s(%d): table %d, libc16 %d\n", name[i], c, m[i], f[i]);
		bad++;
	    }
	}
    }
    printf("ctype16: %d checks, %d differ\n", checked, bad);
    return bad != 0;
}
