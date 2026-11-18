/* Force-included by scripts/audit-libc16; see README. */
#ifndef EPERM
#define EPERM 1
#endif
#ifndef ENFILE
#define ENFILE 23
#endif
#ifndef EZERO
#define EZERO 0
#endif
#ifndef ENAMETOOLONG
#define ENAMETOOLONG 38
#endif
/* Microsoft C's extra streams, which perly.c closes. */
extern void *__audit_stdaux;
extern void *__audit_stdprn;
#define stdaux ((void *)__audit_stdaux)
#define stdprn ((void *)__audit_stdprn)
/* The library-callback convention msdos/p16rt.h gives the runtime build
 * (#16), which this audit doesn't force-include. */
#ifndef P16_CB
#define P16_CB __cdecl
#endif

/* msdos/p16fp.h's numeric tests (#16), as the development build has
 * them: the audit compiles the sources, and doesn't link p16fp.c. */
#ifndef P16_ZERO
#define P16_ZERO 0.0
#define p16_gt(a, b) ((a) > (b))
#define p16_ge(a, b) ((a) >= (b))
#endif
