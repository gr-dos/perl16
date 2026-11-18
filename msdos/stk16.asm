; __STK for perl16: Open Watcom's stack check, with a guard margin.
;
; Open Watcom calls __STK at the entry of every function compiled without
; -s, with the size of the new frame in AX (a far call in the large
; model). Its own __STK fails only when SP - AX would reach __STACKLOW,
; the bottom of the stack, but library and emulator code is not checked
; and runs below that line unnoticed, over the copies of the command line
; and then over BSS (docs/M1-REPORT.md, section 5.2). This one fails when
; SP - AX would come within STK16_MARGIN bytes of __STACKLOW, so the
; unchecked code that runs after the last check has that much room.
;
; On failure it writes "Stack overflow" to standard error with DOS (the
; C runtime cannot be trusted with what is left of the stack) and exits
; with status 255, as an uncaught Perl die usually does.
;
; Linking this object before the C library replaces the library's __STK.
;
; With -dP16_RT, for the runtime build (#17): libc16 has no __STK (its
; consumers usually build with -s) and no __STACKLOW. The stack starts
; at wlink's _end, the end of _BSS, where libc16's STACK segment begins
; (libc16's docs/ABI.md, "Memory layout"; docs/M3-RUNTIME-AUDIT.md,
; section 6.2).
;
; Assemble with: wasm -q -ml -0 [-dSTK16_MARGIN=N] [-dP16_RT] stk16.asm

.8086

ifndef STK16_MARGIN
STK16_MARGIN equ 2048
endif

DGROUP group _DATA

_DATA segment word public 'DATA'
ifdef P16_RT
        extrn   _end:byte
else
        extrn   __STACKLOW:word
endif
_DATA ends

STK16_TEXT segment word public 'CODE'
        assume  cs:STK16_TEXT, ds:DGROUP

        public  __STK
__STK   proc    far
        cmp     ax, sp
        jae     overflow                ; the frame is bigger than SP
        push    bx
        push    ds
        mov     bx, sp
        sub     bx, ax                  ; SP after the new frame
        push    ax
        mov     ax, DGROUP
        mov     ds, ax
ifdef P16_RT
        mov     ax, offset DGROUP:_end
else
        mov     ax, __STACKLOW
endif
        add     ax, STK16_MARGIN
        jc      pop_overflow
        cmp     bx, ax
        pop     ax
        pop     ds
        pop     bx
        jbe     overflow
        ret
pop_overflow:
        pop     ax
        pop     ds
        pop     bx
overflow:
        push    cs
        pop     ds
        mov     dx, offset message
        mov     cx, message_len
        mov     bx, 2
        mov     ah, 40h
        int     21h
        mov     ax, 4CFFh
        int     21h
__STK   endp

message db      'Stack overflow', 13, 10
message_len equ $ - message

STK16_TEXT ends

        end
