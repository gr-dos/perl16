/*
 * perl16: <ctype.h>'s classification as table macros, for the runtime
 * build (#17; docs/M3-RUNTIME-AUDIT.md, section 7.1).
 *
 * libc16's <ctype.h> has functions only, by design: each test is a far
 * __cdecl call. Perl's tokenizer and regex engine test characters in
 * tight loops, so msdos/p16rt.h includes this after <ctype.h> and the
 * tests become a lookup in ctype16[] (ctype16.c), 256 bytes. The classes
 * are libc16's (its docs/spec/ctype.md: the "C" locale, nothing at 80h
 * and above or for EOF), and each macro evaluates its argument once.
 * tolower and toupper stay libc16's functions.
 */

#ifndef PERL16_CTYPE16_H
#define PERL16_CTYPE16_H

#define C16_UPPER  0x01
#define C16_LOWER  0x02
#define C16_DIGIT  0x04
#define C16_SPACE  0x08		/* space, \t \n \v \f \r */
#define C16_PUNCT  0x10
#define C16_CNTRL  0x20
#define C16_XDIGIT 0x40
#define C16_BLANK  0x80		/* the space character, for isprint */

extern const unsigned char ctype16[256];

#define C16_IS(c, m) (ctype16[(unsigned char)(c)] & (m))

#undef isalnum
#undef isalpha
#undef isascii
#undef iscntrl
#undef isdigit
#undef isgraph
#undef islower
#undef isprint
#undef ispunct
#undef isspace
#undef isupper
#undef isxdigit

#define isalnum(c)  C16_IS(c, C16_UPPER | C16_LOWER | C16_DIGIT)
#define isalpha(c)  C16_IS(c, C16_UPPER | C16_LOWER)
#define isascii(c)  ((unsigned)(c) < 0x80)
#define iscntrl(c)  C16_IS(c, C16_CNTRL)
#define isdigit(c)  C16_IS(c, C16_DIGIT)
#define isgraph(c)  C16_IS(c, C16_UPPER | C16_LOWER | C16_DIGIT | C16_PUNCT)
#define islower(c)  C16_IS(c, C16_LOWER)
#define isprint(c)  C16_IS(c, C16_UPPER | C16_LOWER | C16_DIGIT | C16_PUNCT \
			      | C16_BLANK)
#define ispunct(c)  C16_IS(c, C16_PUNCT)
#define isspace(c)  C16_IS(c, C16_SPACE)
#define isupper(c)  C16_IS(c, C16_UPPER)
#define isxdigit(c) C16_IS(c, C16_XDIGIT)

#endif
