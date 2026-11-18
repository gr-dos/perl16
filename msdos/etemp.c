/*
 * The temporary file for perl -e (issues #3 and #4; docs/M2-REPORT.md,
 * section 6).
 *
 * Perl 3 writes the -e lines to a file and runs that. The historical
 * port named it with mktemp("plXXXXXX") in the current directory, which
 * fails on a write-protected or read-only drive, and mktemp only checks
 * that the name is free, so another program could take it before the
 * file is opened.
 *
 * Here the file goes in the first directory of TEMP, TMP and the current
 * directory in which it can be created. Each name is created with DOS
 * 3.0's "create new file" (INT 21h, AH=5Bh), which fails if the name
 * exists, so an existing file is never opened or truncated and checking
 * and creating are one step. Names are PLxxxxxx.TMP, the x's from a
 * generator seeded from the BIOS clock and the PSP; a name that exists
 * is retried with the next one, up to ETEMP_TRIES times per directory.
 *
 * DOS has no permissions to speak of: any program can still open, change
 * or delete the file while Perl runs. Exclusive creation prevents
 * collisions and clobbering, not interference. A write-protected floppy
 * makes DOS ask "Abort, Retry, Fail?" (INT 24h) before the error reaches
 * Perl; answering Fail moves on to the next directory.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <errno.h>
#include <io.h>
#include <fcntl.h>
#include <dos.h>
#include "etemp.h"

#ifndef MK_FP
#define MK_FP(seg, off) ((void far *)(((unsigned long)(seg) << 16) | (unsigned)(off)))
#endif

#define ETEMP_TRIES 32

#define DOSERR_EXISTS	0x50	/* file exists */

static unsigned long etemp_state;

/* The seed: BIOS ticks since midnight, the PSP segment, the time. */
#ifndef ETEMP_SEED
static unsigned long
etemp_seed(void)
{
    union REGS r;
    unsigned long ticks = *(unsigned long far *)MK_FP(0x40, 0x6c);

    r.h.ah = 0x62;
    intdos(&r, &r);
    return ticks ^ ((unsigned long)r.x.bx << 13) ^ (unsigned long)time(0);
}
#define ETEMP_SEED etemp_seed()
#endif

/* The next name, PLxxxxxx.TMP, into name (13 bytes). */
static void
etemp_name(char *name)
{
    static const char digits[] = "0123456789ABCDEFGHIJKLMNOPQRSTUV";
    unsigned long v;
    int i;

    etemp_state = etemp_state * 1103515245UL + 12345UL;
    v = etemp_state >> 2;
    name[0] = 'P';
    name[1] = 'L';
    for (i = 2; i < 8; i++) {
	name[i] = digits[(unsigned)v & 31];
	v >>= 5;
    }
    strcpy(name + 8, ".TMP");
}

/* Create path if it doesn't exist; the DOS handle, or -(DOS error). */
static int
create_new(const char *path)
{
    union REGS r;
    struct SREGS s;

    segread(&s);
    r.h.ah = 0x5b;
    r.x.cx = 0;			/* normal attributes */
    s.ds = FP_SEG(path);
    r.x.dx = FP_OFF(path);
    intdosx(&r, &r, &s);
    return r.x.cflag ? -(int)r.x.ax : (int)r.x.ax;
}

#if defined(__WATCOMC__) && !defined(P16_RT)
/* Close DOS handle h without the C runtime, which doesn't know it. */
static void
close_handle(int h)
{
    union REGS r;

    r.h.ah = 0x3e;
    r.x.bx = h;
    intdos(&r, &r);
}
#endif

/*
 * A stdio stream writing DOS handle h, in text mode; if there can't be
 * one, h is closed.
 */
static FILE *
stream_for(int h)
{
    FILE *fp;
#if defined(__WATCOMC__) && !defined(P16_RT)
    int fd = _hdopen(h, O_WRONLY | O_TEXT);	/* tell the runtime about h */

    if (fd < 0) {
	close_handle(h);
	return 0;
    }
#else
    int fd = h;			/* libc16: a DOS handle is a descriptor, text mode */
#endif
    if ((fp = fdopen(fd, "w")) == 0)
	close(fd);
    return fp;
}

/* errno for a DOS error code. */
static int
dos_errno(int err)
{
    switch (err) {
    case 2:
    case 3:
	return ENOENT;
    case 4:
	return EMFILE;
    default:
	return EACCES;
    }
}

/*
 * Create the file in dir ("" for the current directory). Returns the
 * stream and sets *namep to the malloc'd pathname, or returns a null
 * pointer with errno set: EEXIST if every name tried existed, ENAMETOOLONG
 * if dir is too long, or the error DOS gave.
 */
static FILE *
etemp_in(const char *dir, char **namep)
{
    char path[ETEMP_PATH_MAX];
    size_t len = strlen(dir);
    char *base;
    int tries, h;
    FILE *fp;

    if (len + 1 + 12 + 1 > sizeof(path)) {
#ifdef ENAMETOOLONG
	errno = ENAMETOOLONG;
#else
	errno = EINVAL;		/* libc16 has no ENAMETOOLONG */
#endif
	return 0;
    }
    strcpy(path, dir);
    if (len > 0 && path[len - 1] != '\\' && path[len - 1] != '/'
     && path[len - 1] != ':')
	path[len++] = '\\';
    base = path + len;
    for (tries = 0; tries < ETEMP_TRIES; tries++) {
	etemp_name(base);
	h = create_new(path);
	if (h == -DOSERR_EXISTS)
	    continue;
	if (h < 0) {
	    errno = dos_errno(-h);
	    return 0;
	}
	if ((fp = stream_for(h)) == 0 || (*namep = strdup(path)) == 0) {
	    if (fp)
		fclose(fp);
	    remove(path);
	    errno = ENOMEM;
	    return 0;
	}
	return fp;
    }
    errno = EEXIST;
    return 0;
}

/*
 * Create the -e file: in TEMP, else TMP, else the current directory,
 * skipping a variable that is unset or empty. Returns the stream and
 * sets *namep, or returns a null pointer with errno from the last
 * directory tried, and *where naming that directory.
 */
FILE *
perl16_etemp(char **namep, const char **where)
{
    static const char *vars[] = { "TEMP", "TMP" };
    const char *dir;
    FILE *fp;
    int i;

    etemp_state = ETEMP_SEED;
    for (i = 0; i < 2; i++) {
	dir = getenv(vars[i]);
	if (dir == 0 || *dir == '\0')
	    continue;
	*where = dir;
	if ((fp = etemp_in(dir, namep)) != 0)
	    return fp;
    }
    *where = ".";
    return etemp_in("", namep);
}
