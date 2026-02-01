; ===========================================================================
; RD/RMDIR command - Remove directory
; ===========================================================================

cmd_rd:
    pusha

    cmp     byte [si], 0
    je      .syntax_err

    mov     dx, si
    mov     ah, 0x3A
    int     0x21
    jc      .error

    popa
    ret

.error:
    mov     dx, rd_err_msg
    mov     ah, 0x09
    int     0x21
    popa
    ret

.syntax_err:
    mov     dx, rd_syntax_msg
    mov     ah, 0x09
    int     0x21
    popa
    ret

rd_err_msg      db  'Unable to remove directory', 0x0D, 0x0A, '$'
rd_syntax_msg   db  'Required parameter missing', 0x0D, 0x0A, '$'
