/*
 * Unit test of msdos/etemp.c under DOS: collisions. With a fixed seed,
 * every call tries the same names in the same order, so each call has
 * to step past the files the earlier calls left; an existing file must
 * be neither opened nor truncated; and when a directory's ETEMP_TRIES
 * names are all taken, the next directory is used. tests/run-install
 * runs it with TEMP=C:\T1, no TMP, and C:\WORK\SUB current, and compares
 * its output.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ETEMP_SEED 12345UL
#include "../../msdos/etemp.c"

int
main(void)
{
    char *names[ETEMP_TRIES + 1];
    const char *where;
    char line[32];
    FILE *fp;
    int i, distinct = 1, failed = 0;

    for (i = 0; i <= ETEMP_TRIES; i++) {
	fp = perl16_etemp(&names[i], &where);
	if (fp == 0) {
	    printf("call %d failed in %s\n", i + 1, where);
	    return 1;
	}
	fprintf(fp, "file %d\n", i + 1);
	fclose(fp);
    }
    for (i = 1; i <= ETEMP_TRIES; i++)
	if (strcmp(names[i], names[i - 1]) == 0)
	    distinct = 0;
    printf("names distinct: %s\n", distinct ? "yes" : "no");
    printf("first in: %.6s\n", names[0]);
    printf("last in TEMP: %.6s\n", names[ETEMP_TRIES - 1]);
    printf("next in: %s\n", strchr(names[ETEMP_TRIES], '\\') ? "TEMP" : "current directory");

    /* every file still holds what its own call wrote */
    for (i = 0; i <= ETEMP_TRIES; i++) {
	fp = fopen(names[i], "r");
	if (fp == 0 || fgets(line, sizeof(line), fp) == 0
	 || atoi(line + 5) != i + 1)
	    failed++;
	if (fp)
	    fclose(fp);
	remove(names[i]);
    }
    printf("contents kept: %s\n", failed ? "no" : "yes");
    return failed != 0 || !distinct;
}
