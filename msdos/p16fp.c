/*
 * perl16: numeric tests that wcc -fpc would get wrong, for the runtime
 * build (p16fp.h; #16).
 */

#include "p16fp.h"

volatile double p16_zero = 0.0;

/* A NaN by its bits: all ones in the exponent, a non-zero fraction. No
 * helper is called, so this is right whatever the compiler does with a
 * comparison. */
int
p16_isnan(double x)
{
    unsigned short *w = (unsigned short *)&x;	/* w[3]: bits 63..48 */

    return (w[3] & 0x7FF0) == 0x7FF0
	&& ((w[3] & 0x000F) | w[2] | w[1] | w[0]) != 0;
}

/* a > b and a >= b, false when either is a NaN */
int
p16_gt(double a, double b)
{
    return !p16_isnan(a) && !p16_isnan(b) && a > b;
}

int
p16_ge(double a, double b)
{
    return !p16_isnan(a) && !p16_isnan(b) && a >= b;
}
