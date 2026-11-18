/* p16rt.h - the runtime build's view of the C library (M3.4, #16;
 * docs/M3-RUNTIME-AUDIT.md, sections 5.3 and 11.6).
 *
 * The runtime build (build/rt) compiles the interpreter against libc16's
 * and libkitchen16's headers and links their libraries in place of Open
 * Watcom's runtime. Their functions are __cdecl, and Open Watcom calls a
 * function with its own register convention unless a __cdecl prototype is
 * in scope. Perl 3 includes few standard headers and declares most of the
 * library itself, K&R style, so this header is force-included (wcc -fi)
 * in every module of that build: every library function the interpreter
 * calls then has its prototype before any of Perl's own declarations,
 * which perl.h leaves out under P16_RT.
 *
 * libkitchen16's headers come after libc16's, as its consumers include
 * them (its docs/ABI.md, "Consumer build").
 *
 * P16_CB marks a function of Perl's that the library calls back (qsort,
 * signal, atexit): __cdecl in this build, the default convention in the
 * development build, whose runtime is Open Watcom's. */

#ifndef P16RT_H
#define P16RT_H

#ifdef P16_RT

#include <stddef.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>
#include <setjmp.h>
#include <signal.h>
#include <time.h>
#include <fcntl.h>
#include <io.h>
#include <direct.h>
#include <process.h>
#include <dos.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/utime.h>
#include <math.h>
#include <kitchen16.h>
#include "environ.h"		/* environ and exec, perl16's own (#17) */
#include "p16fp.h"		/* comparisons -fpc gets wrong (#16) */
#include "harderr.h"		/* the INT 24h handler (#17) */
#include "ctype16.h"		/* <ctype.h> as table macros (#17) */

/* $!'s text, with what a critical error recorded (harderr.c) */
#define strerror p16_strerror

#define P16_CB __cdecl

#else

#define P16_CB
#include "p16fp.h"

#endif

#endif
