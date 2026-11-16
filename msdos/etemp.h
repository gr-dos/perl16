/*
 * perl16: the temporary file for perl -e (etemp.c).
 */

#ifndef PERL16_ETEMP_H
#define PERL16_ETEMP_H

#include <stdio.h>

/* The longest pathname of a temporary file, with its NUL. */
#define ETEMP_PATH_MAX 128

FILE *perl16_etemp(char **namep, const char **where);

#endif
