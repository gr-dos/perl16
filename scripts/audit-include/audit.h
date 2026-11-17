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
