/*
 * HARDTST: a unit test of msdos/harderr.c, the runtime build's INT 24h
 * handler (#17). DOSBox-X never raises INT 24h, so this raises it itself,
 * with the registers DOS would pass, as tico16's test build does.
 *
 * Linked like PERL.EXE's start-up (p16init.obj puts perl16_harderr_init
 * in libc16's init table), so it also shows that the handler is
 * installed before main. For each case it prints the action the handler
 * returned (3, Fail) and its description of the error; then that
 * p16_strerror(EACCES) adds nothing when DOS's last error isn't 83.
 * Built against libc16 (Makefile, HARDTST.EXE); never distributed.
 */

#include <dos.h>
#include <errno.h>
#include <stdio.h>
#include "harderr.h"

/* INT 24h as DOS raises it: AX the drive and flags, DI the error code,
 * BP:SI the device header. Returns AL, the action. */
unsigned raise24(unsigned ax, unsigned di, unsigned si, unsigned bpseg);
#pragma aux raise24 = \
    "push bp" \
    "mov bp, bx" \
    "int 24h" \
    "pop bp" \
    "xor ah, ah" \
    parm [ax] [di] [si] [bx] \
    value [ax] \
    modify [cx dx es];

/* A device header: next, attribute, strategy, interrupt, name */
struct devhdr {
    unsigned long next;
    unsigned attr;
    unsigned strategy, intr;
    char name[8];
};

static struct devhdr disk = { 0xFFFFFFFFUL, 0x0000, 0, 0, "\1       " };
static struct devhdr prn = { 0xFFFFFFFFUL, 0x8000, 0, 0, "PRN     " };

static void
check(const char *what, unsigned ax, unsigned di, struct devhdr *h)
{
    struct devhdr __far *fh = (struct devhdr __far *)h;
    char buf[40];
    unsigned action;

    action = raise24(ax, di, FP_OFF(fh), FP_SEG(fh));
    if (!perl16_harderr_describe(buf, sizeof buf))
	sprintf(buf, "(nothing recorded)");
    printf("%s: action %u, %s\n", what, action, buf);
}

int
main(void)
{
    char buf[40];

    printf("before: %s\n",
	   perl16_harderr_describe(buf, sizeof buf) ? buf : "nothing");
    /* AH 39h: a write, Fail, Retry and Ignore allowed; AL 0: drive A */
    check("A: not ready", 0x3900, 0x0002, &disk);
    check("B: write-protected", 0x3901, 0x0000, &disk);
    check("C: unknown code", 0x3802, 0x0042, &disk);
    /* bit 15 of AX: not a disk; the header names the device */
    check("PRN out of paper", 0xB900, 0x0009, &prn);
    printf("strerror(EACCES): %s\n", p16_strerror(EACCES));
    printf("strerror(ENOENT): %s\n", p16_strerror(ENOENT));
    return 0;
}
