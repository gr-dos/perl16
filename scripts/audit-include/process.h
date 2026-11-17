/* Audit-only (see README): the Microsoft C process interface. */
#ifndef AUDIT_PROCESS_H
#define AUDIT_PROCESS_H
#define P_WAIT 0
int spawnl(int, const char *, const char *, ...);
int spawnvp(int, const char *, char **);
int execl(const char *, const char *, ...);
int execv(const char *, char **);
int execvp(const char *, char **);
int getpid(void);
int system(const char *);
#endif
