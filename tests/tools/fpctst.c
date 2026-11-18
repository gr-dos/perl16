/*
 * FPCTST: the C layer under tests/smoke-rt/fpcmp.pl (#16). Compiled like
 * the runtime build (wcc -fpc, libkitchen16's helpers), it prints how
 * the compiler's own comparisons treat -0.0, a subnormal whose high 16
 * bits are clear, and a NaN, then the same tests written with
 * msdos/p16fp.h, which patch 0012 uses in the interpreter.
 *
 * The first block records the compiler, not perl16: a literal 0.0 and a
 * truth test look only at the high 16 bits, and > and >= are true with
 * a NaN (libkitchen16's docs/spec/fpc.md). If a compiler change fixes
 * them, this output changes, and p16fp.h may no longer be needed. The
 * second block must stay as it is. Values are made from their bits, so
 * nothing but the comparisons is tested. Linked with p16fp.obj; never
 * distributed.
 */

#include <stdio.h>
#include "p16fp.h"

typedef union {
    double d;
    unsigned short w[4];		/* w[3]: bits 63..48 */
} bits;

static double
make(unsigned short w3, unsigned short w0)
{
    bits b;

    b.w[3] = w3;
    b.w[2] = 0;
    b.w[1] = 0;
    b.w[0] = w0;
    return b.d;
}

static char
tf(int c)
{
    return c ? 'T' : 'F';
}

int
main(void)
{
    static const char *name[] = { "+0", "-0", "subnormal", "nan", "1" };
    double v[5], one = make(0x3FF0, 0);
    int i;

    v[0] = make(0x0000, 0);
    v[1] = make(0x8000, 0);
    v[2] = make(0x0000, 1);	/* 4.9e-324, the smallest */
    v[3] = make(0x7FF8, 0);	/* a quiet NaN */
    v[4] = one;

    printf("compiler: x!=0.0 !x x<0.0 x>0.0 x>1 x>=1 | "
	   "p16fp: x!=ZERO x<ZERO p16_gt(x,ZERO) p16_gt(x,1) p16_ge(x,1) "
	   "isnan\n");
    for (i = 0; i < 5; i++) {
	double x = v[i];

	printf("%-9s %c%c%c%c%c%c %c%c%c%c%c%c\n", name[i],
	       tf(x != 0.0), tf(!x), tf(x < 0.0), tf(x > 0.0),
	       tf(x > one), tf(x >= one),
	       tf(x != P16_ZERO), tf(x < P16_ZERO), tf(p16_gt(x, P16_ZERO)),
	       tf(p16_gt(x, one)), tf(p16_ge(x, one)), tf(p16_isnan(x)));
    }
    return 0;
}
