; ===========================================================================
; PATH command - Display/set search path
; ===========================================================================

cmd_path:
    pusha

    mov     dx, path_stub_msg
    mov     ah, 0x09
    int     0x21

    popa
    ret

path_stub_msg   db  'PATH=A:\', 0x0D, 0x0A, '$'
