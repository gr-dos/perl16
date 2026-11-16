/*
 * mktemp() for perl16. Neither Open Watcom's runtime nor libc16 has one;
 * Perl 3 uses it only for the -e script file (perly.c, TMPPATH).
 *
 * Replaces the trailing X's of template with digits, giving the first
 * name that does not exist, and returns template. If every name exists,
 * or there are no X's, template is returned unchanged.
 */

#include <io.h>
#include <string.h>

char *
mktemp(char *template)
{
    char *x = template + strlen(template);
    char *p;
    unsigned long n, k;
    int count = 0;

    while (x > template && x[-1] == 'X') {
	x--;
	count++;
    }
    if (count == 0)
	return template;
    for (n = 0; n < 100000L; n++) {
	k = n;
	for (p = x + count; p > x; ) {
	    *--p = (char)('0' + (int)(k % 10));
	    k /= 10;
	}
	if (access(template, 0) != 0)
	    return template;
    }
    for (p = x; p < x + count; p++)
	*p = 'X';
    return template;
}
