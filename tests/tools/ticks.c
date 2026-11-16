/*
 * TICKS: print the BIOS timer tick count (0040:006C, 18.2 a second), for
 * timing a program in emulated time from a batch file (scripts/bench). A
 * test tool, linked with Open Watcom's runtime; it is never distributed.
 */

#include <dos.h>
#include <stdio.h>

int
main(void)
{
    unsigned long t = *(unsigned long __far *)MK_FP(0x40, 0x6C);

    printf("%lu\n", t);
    return 0;
}
