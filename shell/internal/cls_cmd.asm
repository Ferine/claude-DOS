; ===========================================================================
; CLS command - Clear screen
; ===========================================================================

cmd_cls:
    pusha

    ; Use BIOS INT 10h to clear screen
    ; Scroll entire window up (clear)
    mov     ax, 0x0600          ; AH=06 scroll up, AL=00 clear
    mov     bh, 0x07            ; Normal white on black
    xor     cx, cx              ; Upper-left: row 0, col 0
    mov     dh, 24              ; Lower-right row
    mov     dl, 79              ; Lower-right col
    int     0x10

    ; Move cursor to 0,0
    mov     ah, 0x02
    xor     bh, bh
    xor     dx, dx
    int     0x10

    popa
    ret
