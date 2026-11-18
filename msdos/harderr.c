/*
 * perl16: the critical-error (INT 24h) handler of the runtime build
 * (#17; docs/M3-RUNTIME-AUDIT.md, section 10).
 *
 * DOS raises INT 24h when a device fails: a drive not ready or
 * write-protected, a printer out of paper. Its own handler asks
 * "Abort, Retry, Fail?" on the console. perl16 never prompts: libc16's
 * init table calls perl16_harderr_init() before main (p16init.asm),
 * which installs handler() with _harderr. The handler records which
 * drive or device failed and why, and returns Fail, so the DOS call
 * fails with error 83, which libc16 maps to EACCES, and Perl reports it
 * like any failed open or print.
 *
 * p16_strerror(), which msdos/p16rt.h makes Perl's strerror() and so
 * $!'s text, adds what was recorded to "Permission denied" when the
 * last DOS error (INT 21h function 59h) is 83: "Permission denied
 * (drive A: not ready)". Another EACCES later replaces DOS's last error,
 * so it doesn't get a stale explanation.
 */

#include <dos.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include "harderr.h"

#undef strerror

#define DOS_FAIL_ON_INT24 83

static int seen;		/* a critical error has been recorded */
static unsigned dev_error;	/* AX: the drive in AL, or bit 15 */
static unsigned err_code;	/* DI's low byte */
static int char_device;		/* the device header says so */
static char dev_name[9];	/* a character device's, trimmed */

/* DOS's critical-error codes, from DI */
static const char *const reason[] = {
    "write-protected",			/* 00h */
    "unknown unit",			/* 01h */
    "not ready",			/* 02h */
    "unknown command",			/* 03h */
    "data error (CRC)",			/* 04h */
    "bad request structure length",	/* 05h */
    "seek error",			/* 06h */
    "unknown media type",		/* 07h */
    "sector not found",			/* 08h */
    "out of paper",			/* 09h */
    "write fault",			/* 0Ah */
    "read fault",			/* 0Bh */
    "general failure",			/* 0Ch */
    "sharing violation",		/* 0Dh */
    "lock violation",			/* 0Eh */
    "invalid disk change",		/* 0Fh */
};

/*
 * Runs on _harderr's own 512-byte stack, not Perl's, so with no stack
 * check (stk16.asm would see SP below the stack and report overflow).
 * DOS allows no file functions here, and this calls none: it only reads
 * the device header and stores words.
 */
#pragma off (check_stack)
static int __cdecl __far
handler(unsigned deverror, unsigned errcode, unsigned __far *devhdr)
{
    seen = 1;
    dev_error = deverror;
    err_code = errcode & 0xFF;
    /* the header's attribute word, bit 15: a character device, whose
     * name follows at offset 10 */
    char_device = (devhdr[2] & 0x8000) != 0;
    if (char_device) {
	const char __far *name = (const char __far *)devhdr + 10;
	int i;

	for (i = 0; i < 8 && name[i] != ' ' && name[i] != '\0'; i++)
	    dev_name[i] = name[i];
	dev_name[i] = '\0';
    }
    return _HARDERR_FAIL;
}
#pragma on (check_stack)

void
perl16_harderr_init(void)
{
    _harderr(handler);
}

/*
 * The last critical error, as "drive A: not ready" or "PRN: out of
 * paper", into buf; 0 if there has been none.
 */
int
perl16_harderr_describe(char *buf, unsigned size)
{
    char what[16];
    const char *why;

    if (!seen)
	return 0;
    if (char_device)
	sprintf(what, "%s:", dev_name);
    else
	sprintf(what, "drive %c:", 'A' + (dev_error & 0xFF));
    if (err_code < sizeof reason / sizeof reason[0])
	why = reason[err_code];
    else
	why = "critical error";
    snprintf(buf, size, "%s %s", what, why);
    return 1;
}

/* DOS's last error code (INT 21h function 59h, BX = 0) */
static unsigned
last_dos_error(void)
{
    union REGS r;

    r.h.ah = 0x59;
    r.x.bx = 0;
    int86(0x21, &r, &r);
    return r.x.ax;
}

char *
p16_strerror(int errnum)
{
    static char buf[80];
    char why[40];
    char *msg = strerror(errnum);

    if (errnum != EACCES || !perl16_harderr_describe(why, sizeof why)
	|| last_dos_error() != DOS_FAIL_ON_INT24)
	return msg;
    snprintf(buf, sizeof buf, "%s (%s)", msg, why);
    return buf;
}
