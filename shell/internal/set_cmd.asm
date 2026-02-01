; ===========================================================================
; SET command - Display/set environment variables
; ===========================================================================

cmd_set:
    pusha

    ; For now, just print the default environment
    mov     dx, set_stub_msg
    mov     ah, 0x09
    int     0x21

    popa
    ret

set_stub_msg    db  'PATH=A:\', 0x0D, 0x0A
                db  'COMSPEC=A:\COMMAND.COM', 0x0D, 0x0A
                db  'PROMPT=$P$G', 0x0D, 0x0A, '$'
