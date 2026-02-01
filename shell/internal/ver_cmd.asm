; ===========================================================================
; VER command - Display DOS version
; ===========================================================================

cmd_ver:
    pusha

    mov     dx, ver_msg
    mov     ah, 0x09
    int     0x21

    popa
    ret

ver_msg db  0x0D, 0x0A
        db  'claudeDOS version 5.00', 0x0D, 0x0A, '$'
