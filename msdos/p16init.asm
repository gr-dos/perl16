; perl16's entries in libc16's init table (M3.4, #17): far pointers to
; perl16_environ_init (environ.c) and perl16_harderr_init (harderr.c),
; which libc16's startup calls before main. libc16's docs/ABI.md and
; docs/spec/startup.md ("Init table"): the pointers go in LIBC16_INIT,
; and a module adding them declares LIBC16_INIT_BEGIN, LIBC16_INIT and
; LIBC16_INIT_END, in that order, in DGROUP. Large model only (far
; pointers).
;
; Assemble with: wasm -q -ml -0 p16init.asm

.8086

DGROUP group LIBC16_INIT_BEGIN, LIBC16_INIT, LIBC16_INIT_END

        extrn   perl16_environ_init_:far
        extrn   perl16_harderr_init_:far

LIBC16_INIT_BEGIN segment word public 'DATA'
LIBC16_INIT_BEGIN ends

LIBC16_INIT segment word public 'DATA'
        dd      perl16_environ_init_
        dd      perl16_harderr_init_
LIBC16_INIT ends

LIBC16_INIT_END segment word public 'DATA'
LIBC16_INIT_END ends

        end
