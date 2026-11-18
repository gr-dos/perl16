/*
 * perl16: numeric tests that wcc -fpc would get wrong (#16;
 * docs/M3-RUNTIME-AUDIT.md, section 11.5; libkitchen16's
 * docs/spec/fpc.md, "Comparison").
 *
 * The runtime build compiles floating point to calls of libkitchen16's
 * helpers (-fpc). Two kinds of comparison come out wrong there:
 *
 * - x == 0.0, x != 0.0, x < 0.0, x > 0.0 and !x with a literal zero call
 *   no helper: the compiler tests only the high 16 bits of x, so -0.0 is
 *   non-zero (and negative) and a subnormal below about 1.4e-309 is
 *   zero. Compared with P16_ZERO, a zero the compiler can't see, they
 *   call the helper and are right.
 * - x > y and x >= y are true when either is a NaN: the helper reports
 *   an unordered pair as greater, and the compiler branches on the same
 *   flags for > as for <=. p16_gt() and p16_ge() test for a NaN first.
 *   <, <=, == and != are right with a NaN.
 *
 * In the development build, whose floating point is Open Watcom's, these
 * are the plain operators.
 */

#ifndef PERL16_P16FP_H
#define PERL16_P16FP_H

#ifdef P16_RT

extern volatile double p16_zero;	/* 0.0, in p16fp.c */
#define P16_ZERO p16_zero

int p16_isnan(double x);
int p16_gt(double a, double b);
int p16_ge(double a, double b);

#else

#define P16_ZERO 0.0
#define p16_gt(a, b) ((a) > (b))
#define p16_ge(a, b) ((a) >= (b))

#endif

#endif
