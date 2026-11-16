/*
 * perl16: the directory PERL.EXE was loaded from (exepath.c).
 */

#ifndef PERL16_EXEPATH_H
#define PERL16_EXEPATH_H

/* Room for a DOS pathname: "X:\" + 64 bytes of directory + a name. */
#define EXEPATH_MAX 144

int exepath_from_env(const char far *env, unsigned size, char *out,
  unsigned outsize);
int exepath_absolute(const char *name, char *out, unsigned outsize);
int exepath_libdir(char *path, unsigned outsize);
char *perl16_libdir(const char *argv0);

#endif
