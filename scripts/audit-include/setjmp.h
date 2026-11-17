/* Audit-only (see README): C89 7.6. The size is arbitrary. */
#ifndef AUDIT_SETJMP_H
#define AUDIT_SETJMP_H
typedef int jmp_buf[16];
int setjmp(jmp_buf);
void longjmp(jmp_buf, int);
#endif
