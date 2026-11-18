/*
 * TAILTST: print the command tail DOS gave it (PSP offset 81h, the
 * length at 80h) byte for byte, as tail[...], then each environment
 * string as env[...], and exit with the value of P16EXIT (0 if unset).
 *
 * Run as COMSPEC, it shows exactly what a program's system() passed to
 * the command processor, and with what environment; run by COMMAND.COM,
 * what the shell passed on. tests/smoke-rt uses it (#22). A test tool,
 * linked with Open Watcom's runtime like ERR2OUT.EXE; it is never
 * distributed.
 */

#include <dos.h>
#include <stdio.h>
#include <stdlib.h>

int
main(void)
{
    unsigned char __far *psp = (unsigned char __far *)MK_FP(_psp, 0);
    unsigned seg = *(unsigned __far *)MK_FP(_psp, 0x2c);
    const char __far *env;
    int i, n = psp[0x80];
    const char *code;

    printf("tail[");
    for (i = 0; i < n && psp[0x81 + i] != '\r'; i++)
	putchar(psp[0x81 + i]);
    printf("]\n");
    if (seg != 0)
	for (env = (const char __far *)MK_FP(seg, 0); *env; env++) {
	    printf("env[");
	    for (; *env; env++)
		putchar(*env);
	    printf("]\n");
	}
    code = getenv("P16EXIT");
    return code ? atoi(code) : 0;
}
