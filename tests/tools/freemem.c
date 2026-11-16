/*
 * FREEMEM: print the conventional memory, in bytes, that DOS has free for
 * a program at load time: the size of this program's own memory block
 * (from its MCB) plus the largest block DOS can still allocate. Used by
 * scripts/mem-probe. A test tool, linked with Open Watcom's runtime; it
 * is never distributed.
 */

#include <dos.h>
#include <stdio.h>

extern unsigned _psp;

int
main(void)
{
    unsigned seg;
    unsigned largest = 0;
    unsigned own = *(unsigned __far *)MK_FP(_psp - 1, 3);

    if (_dos_allocmem(0xFFFF, &seg) != 0)
	largest = seg;		/* on failure, the largest size available */
    printf("%lu\n", ((unsigned long)own + largest) * 16UL);
    return 0;
}
