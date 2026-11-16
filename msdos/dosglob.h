/*
 * perl16: filename globbing without a helper program (dosglob.c).
 */

#ifndef PERL16_DOSGLOB_H
#define PERL16_DOSGLOB_H

#include <stdio.h>

int perl16_glob(const char *patterns, FILE *out);

#endif
