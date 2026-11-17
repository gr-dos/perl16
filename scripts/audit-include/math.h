/* Audit-only (see README): C89 7.5, the functions Perl 3 uses. */
#ifndef AUDIT_MATH_H
#define AUDIT_MATH_H
double atan2(double, double);
double cos(double);
double exp(double);
double log(double);
double modf(double, double *);
double pow(double, double);
double sin(double);
double sqrt(double);
#endif
