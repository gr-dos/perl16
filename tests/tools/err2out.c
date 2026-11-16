/*
 * ERR2OUT PROGRAM ARGUMENTS: run PROGRAM with its standard error going
 * wherever standard output goes, and exit with its exit status. DOS
 * can't redirect standard error, so tests/run-install uses this to see
 * Perl's error messages. ARGUMENTS are passed on exactly as typed,
 * quotes and all. Small model, so a PERL.EXE still fits beside it.
 */

#include <stdio.h>
#include <string.h>
#include <process.h>
#include <io.h>

int
main(void)
{
    static char line[130];
    char *prog, *args;
    int rc;

    getcmd(line);
    for (prog = line; *prog == ' ' || *prog == '\t'; prog++)
	;
    if (*prog == '\0') {
	fputs("usage: ERR2OUT PROGRAM ARGUMENTS\n", stderr);
	return 255;
    }
    for (args = prog; *args != '\0' && *args != ' ' && *args != '\t'; args++)
	;
    if (*args != '\0')
	*args++ = '\0';
    dup2(1, 2);
    rc = spawnl(P_WAIT, prog, prog, args, (char *)0);
    if (rc < 0) {
	perror(prog);
	return 255;
    }
    return rc;
}
