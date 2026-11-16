/*
 * Run Perl on a stack segment of its own (SS != DS): an experiment for
 * issue #5 (docs/M1-REPORT.md, section 5.5), not part of the default build.
 *
 * perly.c is compiled with -Dmain=perl_main and every module with -zu (do
 * not assume SS == DGROUP). This main() allocates a 64 KB segment from
 * DOS, moves SS:SP to its top, calls perl_main(), and moves back. Only
 * static variables are used between the switches, since the frame of
 * main() is on the old stack.
 *
 * __STACKLOW is set to 0 while Perl runs, so the stack check in
 * msdos/stk16.asm (which does not compare SS, unlike Open Watcom's own)
 * guards the new segment. If the segment cannot be allocated, Perl runs
 * on the normal stack.
 */

#include <dos.h>

extern int perl_main(int, char **, char **);
extern unsigned _STACKLOW;

static int s_argc;
static char **s_argv;
static char **s_env;
static int s_ret;
static int s_switched;
static unsigned s_seg;
static unsigned s_old_ss;
static unsigned s_old_sp;
static unsigned s_old_low;

int
main(int argc, char **argv, char **env)
{
    s_argc = argc;
    s_argv = argv;
    s_env = env;
    if (_dos_allocmem(0x1000, &s_seg) != 0)
	return perl_main(argc, argv, env);
    s_old_low = _STACKLOW;
    _asm {
	mov	s_old_ss, ss
	mov	s_old_sp, sp
	mov	ax, s_seg
	cli
	mov	ss, ax
	mov	sp, 0FFFEh
	sti
    }
    _STACKLOW = 0;
    s_switched = 1;
    s_ret = perl_main(s_argc, s_argv, s_env);
    s_switched = 0;
    _STACKLOW = s_old_low;
    _asm {
	cli
	mov	ss, s_old_ss
	mov	sp, s_old_sp
	sti
    }
    return s_ret;
}

/*
 * Open Watcom's DOS process functions assume SS == DGROUP: ___dospawn
 * starts with "mov ax,ss; mov ds,ax", takes near pointers relative to SS
 * and saves SS:SP through that DS, then restores them from the real
 * DGROUP after INT 21h/4Bh, so a child started from the separate stack
 * returns to a garbage stack. Perl's calls to them are renamed to these
 * wrappers (-Dspawnvp=ss_spawnvp and so on), which run the library
 * function on the original stack in DGROUP, below the frame of main().
 * Arguments and results pass through statics; the wrappers are not
 * reentrant, which DOS, having no concurrent processes, does not need.
 */

#include <process.h>
#include <stdarg.h>
#include <stdlib.h>

static unsigned s_cur_ss;
static unsigned s_cur_sp;
static int (*s_fn)(void);
static int s_res;
static int s_mode;
static const char *s_path;
static const char * const *s_av;
static const char *s_cmd;
static const char *s_args[20];

static void
on_dgroup(void)
{
    if (!s_switched) {
	s_res = s_fn();
	return;
    }
    _asm {
	mov	s_cur_ss, ss
	mov	s_cur_sp, sp
	cli
	mov	ss, s_old_ss
	mov	sp, s_old_sp
	sub	sp, 16
	sti
    }
    _STACKLOW = s_old_low;
    s_res = s_fn();
    _STACKLOW = 0;
    _asm {
	cli
	mov	ss, s_cur_ss
	mov	sp, s_cur_sp
	sti
    }
}

static int t_spawnvp(void) { return spawnvp(s_mode, s_path, s_av); }
static int t_spawnv(void)  { return spawnv(s_mode, s_path, s_av); }
static int t_execvp(void)  { return execvp(s_path, (char * const *)s_av); }
static int t_execv(void)   { return execv(s_path, (char * const *)s_av); }
static int t_system(void)  { return system(s_cmd); }

static int
collect(const char *path, va_list ap)
{
    int i = 0;
    s_path = path;
    while (i < 19 && (s_args[i] = va_arg(ap, const char *)) != 0)
	i++;
    s_args[i] = 0;
    s_av = s_args;
    return i;
}

int
ss_spawnvp(int mode, const char *path, const char * const *av)
{
    s_mode = mode; s_path = path; s_av = av; s_fn = t_spawnvp;
    on_dgroup();
    return s_res;
}

int
ss_spawnv(int mode, const char *path, const char * const *av)
{
    s_mode = mode; s_path = path; s_av = av; s_fn = t_spawnv;
    on_dgroup();
    return s_res;
}

int
ss_spawnl(int mode, const char *path, ...)
{
    va_list ap;
    va_start(ap, path);
    collect(path, ap);
    va_end(ap);
    s_mode = mode; s_fn = t_spawnv;
    on_dgroup();
    return s_res;
}

int
ss_execvp(const char *path, const char * const *av)
{
    s_path = path; s_av = av; s_fn = t_execvp;
    on_dgroup();
    return s_res;
}

int
ss_execv(const char *path, const char * const *av)
{
    s_path = path; s_av = av; s_fn = t_execv;
    on_dgroup();
    return s_res;
}

int
ss_execl(const char *path, ...)
{
    va_list ap;
    va_start(ap, path);
    collect(path, ap);
    va_end(ap);
    s_fn = t_execv;
    on_dgroup();
    return s_res;
}

int
ss_system(const char *cmd)
{
    s_cmd = cmd; s_fn = t_system;
    on_dgroup();
    return s_res;
}
