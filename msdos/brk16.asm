; __brk_ and sbrk_ for the SS != DS experiment (msdos/sswitch.c).
;
; Open Watcom's own __brk_ (clibl.lib(sbrk)) grows the near heap by
; resizing the program's DOS memory block to (SS - PSP) + the new break
; in paragraphs, which is right only while SS is DGROUP. This copy is the
; same routine with DGROUP in place of SS.
;
; Assemble with: wasm -q -ml -0 brk16.asm

.8086

DGROUP group _DATA

_DATA segment word public 'DATA'
        extrn   __STACKTOP:word
        extrn   __osmode:byte
        extrn   __psp:word
        extrn   __curbrk:word
        extrn   _errno:word
_DATA ends

BRK16_TEXT segment byte public 'CODE'
        assume  cs:BRK16_TEXT, ds:DGROUP

        public  __brk_
__brk_  proc    far
        push    bx
        push    cx
        push    dx
        mov     dx, ax
        mov     ax, DGROUP
        mov     ds, ax
        cmp     dx, __STACKTOP
        jb      fail
        mov     bx, dx
        mov     cl, 4
        add     bx, 15
        shr     bx, cl
        test    bx, bx
        jne     sized
        mov     bx, 1000h
sized:
        cmp     __osmode, 0
        jne     resize
        mov     ax, DGROUP
        sub     ax, __psp
        add     bx, ax
        mov     ax, __psp
resize:
        mov     es, ax
        mov     ah, 4Ah
        int     21h
        mov     ax, DGROUP
        mov     ds, ax
        jc      fail
        mov     ax, __curbrk
        mov     __curbrk, dx
        jmp     done
fail:
        mov     ax, 0FFFFh
        mov     _errno, 5
done:
        pop     dx
        pop     cx
        pop     bx
        ret
__brk_  endp

        public  sbrk_
sbrk_   proc    far
        push    dx
        mov     dx, DGROUP
        mov     ds, dx
        add     ax, __curbrk
        call    __brk_
        pop     dx
        ret
sbrk_   endp

BRK16_TEXT ends

        end
