; ===========================================================================
; REN/RENAME command - Rename files
; ===========================================================================

cmd_ren:
    pusha

    mov     dx, ren_stub_msg
    mov     ah, 0x09
    int     0x21

    popa
    ret

ren_stub_msg    db  'REN: not yet implemented', 0x0D, 0x0A, '$'
