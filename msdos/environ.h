/*
 * perl16: environ for the runtime build (environ.c) and the exec family
 * (exec16.c), which libc16 doesn't have.
 */

#ifndef PERL16_ENVIRON_H
#define PERL16_ENVIRON_H

extern char **environ;

void perl16_environ_init(void);

int execl(const char *path, const char *arg0, ...);
int execv(const char *path, char * const *argv);
int execvp(const char *file, char * const *argv);

#endif
