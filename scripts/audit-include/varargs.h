/* Audit-only (see README): the traditional <varargs.h> interface, over
 * libc16's <stdarg.h>. Enough to compile, not to run: va_start does not
 * find the arguments. */
#ifndef AUDIT_VARARGS_H
#define AUDIT_VARARGS_H
#include <stdarg.h>
#define va_alist void *__audit_va_first, ...
#define va_dcl
#undef va_start
#define va_start(ap) ((ap) = (char *)0)
#endif
