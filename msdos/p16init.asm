; perl16's entry in libc16's init table (M3.4, #17): a far pointer to
; perl16_environ_init (environ.c), which libc16's startup calls before
; main. libc16's docs/ABI.md and docs/spec/startup.md ("Init table"):
; the pointer goes in LIBC16_INIT, and a module adding one declares
; LIBC16_INIT_BEGIN, LIBC16_INIT and LIBC16_INIT_END, in that order, in
; DGROUP. Large model only (a far pointer).
;
; Assemble with: wasm -q -ml -0 p16init.asm

.8086

DGROUP group LIBC16_INIT_BEGIN, LIBC16_INIT, LIBC16_INIT_END

        extrn   perl16_environ_init_:far

LIBC16_INIT_BEGIN segment word public 'DATA'
LIBC16_INIT_BEGIN ends

LIBC16_INIT segment word public 'DATA'
        dd      perl16_environ_init_
LIBC16_INIT ends

LIBC16_INIT_END segment word public 'DATA'
LIBC16_INIT_END ends

        end
