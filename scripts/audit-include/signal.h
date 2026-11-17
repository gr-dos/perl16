/* Audit-only (see README): C89 7.7. */
#ifndef AUDIT_SIGNAL_H
#define AUDIT_SIGNAL_H
typedef int sig_atomic_t;
#define SIG_DFL ((void (*)(int))0)
#define SIG_ERR ((void (*)(int))-1)
#define SIG_IGN ((void (*)(int))1)
#define SIGINT  2
#define SIGILL  4
#define SIGFPE  8
#define SIGSEGV 11
#define SIGTERM 15
#define SIGABRT 22
void (*signal(int, void (*)(int)))(int);
int raise(int);
#endif
