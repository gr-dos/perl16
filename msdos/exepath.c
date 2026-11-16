/*
 * The directory PERL.EXE was loaded from, for perl16's default @INC
 * (docs/DESIGN.md, section 5.1; docs/M2-REPORT.md, section 5).
 *
 * DOS 3.0 and later put the pathname of the program it loaded after the
 * environment strings: the strings, an empty string, a word holding a
 * count of further strings (1), and the pathname. COMMAND.COM passes
 * EXEC the name it found, which is usually fully qualified but need not
 * be: a drive-relative name like X:PERL.EXE keeps its DOS meaning (the
 * current directory of X:), and other loaders may pass a relative name.
 * So the name is made absolute with the current drive and directories,
 * which are still the ones the loader used, since Perl hasn't changed
 * them yet. No other normalisation is done: DOS itself resolves "." and
 * ".." in the result.
 *
 * If the environment block is missing or not in that form (DOS 2.x, or
 * a loader that built it oddly), argv[0] is used instead, if it names a
 * directory. Otherwise there is no default library directory.
 */

#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <dos.h>
#include "exepath.h"

#ifndef MK_FP
#define MK_FP(seg, off) ((void far *)(((unsigned long)(seg) << 16) | (unsigned)(off)))
#endif

#define ENV_MAX 32768U		/* DOS limits an environment to 32 KB */

static int
is_sep(int c)
{
    return c == '\\' || c == '/';
}

/*
 * Find the program's pathname in a DOS 3.x environment block of at most
 * size bytes, and copy it to out (outsize bytes). Returns 0, or -1 if
 * the block isn't in the expected form: no end to the strings within
 * size, a count of 0, or a pathname that is empty, too long, unterminated
 * or has control characters in it.
 */
int
exepath_from_env(const char far *env, unsigned size, char *out,
  unsigned outsize)
{
    unsigned i = 0, n;

    if (env == 0 || size < 4 || outsize == 0)
	return -1;
    /* the strings end with an empty one; with none, that is all there is */
    if (env[0] != '\0') {
	for (i = 1; i < size && !(env[i] == '\0' && env[i - 1] == '\0'); i++)
	    ;
	if (i >= size)
	    return -1;
    }
    i++;
    if (i + 2 >= size)
	return -1;
    if (((unsigned char)env[i] | ((unsigned char)env[i + 1] << 8)) == 0)
	return -1;		/* no strings follow */
    i += 2;
    for (n = 0; i + n < size && env[i + n] != '\0'; n++) {
	if ((unsigned char)env[i + n] < ' ')
	    return -1;
	if (n + 1 >= outsize)
	    return -1;
	out[n] = env[i + n];
    }
    if (i + n >= size || n == 0)
	return -1;
    out[n] = '\0';
    return 0;
}

/* The current drive, 1 for A:. */
static int
current_drive(void)
{
    union REGS r;

    r.h.ah = 0x19;
    intdos(&r, &r);
    return r.h.al + 1;
}

/*
 * The current directory of drive (1 for A:), without drive or leading
 * backslash, into buf (at least 64 bytes). Returns 0 or -1.
 */
static int
current_dir(int drive, char *buf)
{
    union REGS r;
    struct SREGS s;

    segread(&s);
    r.h.ah = 0x47;
    r.h.dl = (unsigned char)drive;
    s.ds = FP_SEG(buf);
    r.x.si = FP_OFF(buf);
    intdosx(&r, &r, &s);
    return r.x.cflag ? -1 : 0;
}

/*
 * Make a DOS pathname absolute, as "X:\DIR\NAME", into out (outsize
 * bytes): "X:\..." is kept, "\..." gets the current drive, "X:NAME" the
 * current directory of X:, and "NAME" the current drive and directory.
 * Returns 0, or -1 if a drive is invalid or the result is too long.
 */
int
exepath_absolute(const char *name, char *out, unsigned outsize)
{
    char cwd[68];
    int drive;
    const char *rest = name;
    unsigned len;

    if (isalpha((unsigned char)name[0]) && name[1] == ':') {
	drive = toupper((unsigned char)name[0]) - 'A' + 1;
	rest = name + 2;
    }
    else
	drive = current_drive();
    if (is_sep(*rest))
	cwd[0] = '\0';
    else if (current_dir(drive, cwd) != 0)
	return -1;
    len = 3 + strlen(cwd) + 1 + strlen(rest) + 1;
    if (len > outsize)
	return -1;
    out[0] = (char)('A' + drive - 1);
    out[1] = ':';
    out[2] = '\\';
    strcpy(out + 3, cwd);
    if (cwd[0] != '\0' && !is_sep(*rest))
	strcat(out, "\\");
    strcat(out, is_sep(*rest) ? rest + 1 : rest);
    return 0;
}

/*
 * Replace the last component of an absolute pathname with "LIB", in
 * place (path has room for outsize bytes). Returns 0, or -1 if there is
 * no directory or the result is too long.
 */
int
exepath_libdir(char *path, unsigned outsize)
{
    char *p = path + strlen(path);

    while (p > path && !is_sep(p[-1]) && p[-1] != ':')
	p--;
    if (p == path || *p == '\0')
	return -1;		/* no directory, or no file name */
    if ((unsigned)(p - path) + 4 > outsize)
	return -1;
    strcpy(p, "LIB");
    return 0;
}

/*
 * How far the environment block at segment seg may be read: to the end
 * of its DOS memory block, if the arena header before it looks like
 * one ("M", or "Z" for the last), and at most 32 KB.
 */
static unsigned
env_size(unsigned seg)
{
    const unsigned char far *mcb = (const unsigned char far *)MK_FP(seg - 1, 0);
    unsigned paras;

    if (mcb[0] == 'M' || mcb[0] == 'Z') {
	paras = mcb[3] | (mcb[4] << 8);
	if (paras < ENV_MAX / 16)
	    return paras * 16;
    }
    return ENV_MAX;
}

/* Does name have a directory part (a drive or a separator)? */
static int
has_dir(const char *name)
{
    if (isalpha((unsigned char)name[0]) && name[1] == ':')
	return 1;
    for (; *name; name++)
	if (is_sep(*name))
	    return 1;
    return 0;
}

/*
 * The default library directory, "<directory of PERL.EXE>\LIB", in a
 * malloc'd string, or a null pointer if it can't be found. argv0 is
 * main()'s argv[0], the fallback.
 */
char *
perl16_libdir(const char *argv0)
{
    char name[EXEPATH_MAX], path[EXEPATH_MAX];
    union REGS r;
    unsigned psp, envseg;
    int found = 0;

    r.x.ax = 0x3000;		/* DOS version: AL major, AH minor */
    intdos(&r, &r);
    if (r.h.al >= 3) {
	r.h.ah = 0x62;		/* the PSP's segment, DOS 3.0+ */
	intdos(&r, &r);
	psp = r.x.bx;
	envseg = *(unsigned far *)MK_FP(psp, 0x2c);
	if (envseg != 0)
	    found = exepath_from_env((const char far *)MK_FP(envseg, 0),
		env_size(envseg), name, sizeof(name)) == 0;
    }
    if (!found && argv0 != 0 && has_dir(argv0)
     && strlen(argv0) < sizeof(name)) {
	strcpy(name, argv0);
	found = 1;
    }
    if (!found || exepath_absolute(name, path, sizeof(path)) != 0
     || exepath_libdir(path, sizeof(path)) != 0)
	return 0;
    return strdup(path);
}
