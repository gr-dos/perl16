/*
 * perl16: the critical-error (INT 24h) handler of the runtime build
 * (harderr.c; #17, docs/M3-RUNTIME-AUDIT.md, section 10).
 */

#ifndef PERL16_HARDERR_H
#define PERL16_HARDERR_H

void perl16_harderr_init(void);
int perl16_harderr_describe(char *buf, unsigned size);
char *p16_strerror(int errnum);

#endif
