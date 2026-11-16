/*
 * Filename globbing for perl16: <*.c> and the like (docs/M2-REPORT.md,
 * section 7).
 *
 * Perl 3 globs by reading the output of a command through a pipe. On
 * MS-DOS that command is "perlglob PATTERNS" (evalargs.xc), and the
 * historical port shipped a helper, glob.exe, that printed its arguments
 * as the C startup code had expanded them, NUL-separated. The names
 * didn't match (perlglob vs glob.exe), and running a helper means a
 * child process, with COMMAND.COM and enough free memory for both.
 *
 * perl16 has no helper: msdos/popen.c recognises "perlglob" and calls
 * perl16_glob() to write the same output to the temporary file it reads
 * from. For each word of PATTERNS, separated by blanks:
 *
 *   - a word with no * or ? is written as it is;
 *   - otherwise its last component is matched by DOS (INT 21h find
 *     first/next) with DOS's wildcard rules, so "*.*" also matches names
 *     with no extension, and "*" only those. Files and directories match;
 *     hidden and system files, ".", and ".." don't. The matches are
 *     sorted, lower-cased like readdir()'s (msdos/directory.c) and
 *     written after the word's directory part as given. A word that
 *     matches nothing gives nothing.
 *
 * Wildcards in a directory part ("*\*.c") are not expanded; DOS reports
 * them as an invalid path, so they match nothing.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <dos.h>
#include "dosglob.h"

#define GLOB_PATH_MAX 128

struct dta {
    char reserved[21];
    unsigned char attr;
    unsigned short time;
    unsigned short date;
    unsigned long size;
    char name[13];
};

#define A_HIDDEN 0x02
#define A_SYSTEM 0x04
#define A_DIR 0x10

static int
cmp_names(const void *a, const void *b)
{
    return strcmp((const char *)a, (const char *)b);
}

/* The DTA's address, to restore it afterwards. */
static void far *
get_dta(void)
{
    union REGS r;
    struct SREGS s;

    segread(&s);
    r.h.ah = 0x2f;
    intdosx(&r, &r, &s);
    return (void far *)(((unsigned long)s.es << 16) | r.x.bx);
}

static void
set_dta(void far *dta)
{
    union REGS r;
    struct SREGS s;

    segread(&s);
    r.h.ah = 0x1a;
    s.ds = FP_SEG(dta);
    r.x.dx = FP_OFF(dta);
    intdosx(&r, &r, &s);
}

/*
 * Expand one word with wildcards, writing each match to out. Returns 0,
 * or -1 if memory ran out.
 */
static int
glob_word(const char *word, FILE *out)
{
    struct dta dta;
    union REGS r;
    struct SREGS s;
    char *names = 0, *more;
    unsigned count = 0, room = 0, i, dirlen;
    const char *p;
    int dot;
    void far *old_dta;

    /* the directory part, kept as given */
    for (p = word + strlen(word); p > word; p--)
	if (p[-1] == '\\' || p[-1] == '/' || p[-1] == ':')
	    break;
    dirlen = p - word;
    dot = *p == '.';

    old_dta = get_dta();
    set_dta((void far *)&dta);
    segread(&s);
    r.h.ah = 0x4e;
    r.x.cx = A_DIR;		/* and normal and read-only files */
    s.ds = FP_SEG(word);
    r.x.dx = FP_OFF(word);
    for (intdosx(&r, &r, &s); !r.x.cflag; intdosx(&r, &r, &s)) {
	r.h.ah = 0x4f;
	if (dta.attr & (A_HIDDEN | A_SYSTEM))
	    continue;
	if (!dot && dta.name[0] == '.')
	    continue;		/* "." and ".." */
	if (count == room) {
	    room = room ? room * 2 : 16;
	    if ((more = realloc(names, room * 13)) == 0) {
		free(names);
		set_dta(old_dta);
		return -1;
	    }
	    names = more;
	}
	dta.name[12] = '\0';
	strcpy(names + count * 13, strlwr(dta.name));
	count++;
    }
    set_dta(old_dta);

    qsort(names, count, 13, cmp_names);
    for (i = 0; i < count; i++) {
	fwrite(word, 1, dirlen, out);
	fputs(names + i * 13, out);
	putc('\0', out);
    }
    free(names);
    return 0;
}

/*
 * Expand the blank-separated words of patterns, writing each result
 * followed by a NUL to out. Returns 0, or -1 if a word is too long or
 * memory ran out.
 */
int
perl16_glob(const char *patterns, FILE *out)
{
    char word[GLOB_PATH_MAX];
    const char *p = patterns;
    size_t n;

    for (;;) {
	while (*p == ' ' || *p == '\t')
	    p++;
	if (*p == '\0')
	    break;
	for (n = 0; p[n] != '\0' && p[n] != ' ' && p[n] != '\t'; n++)
	    ;
	if (n >= sizeof(word))
	    return -1;
	memcpy(word, p, n);
	word[n] = '\0';
	p += n;
	if (strpbrk(word, "*?") == 0) {
	    fputs(word, out);
	    putc('\0', out);
	}
	else if (glob_word(word, out) != 0)
	    return -1;
    }
    return ferror(out) ? -1 : 0;
}
