; ===========================================================================
; DEL/ERASE command - Delete files
; ===========================================================================

cmd_del:
    pusha

    cmp     byte [si], 0
    je      .syntax_err

    ; Delete file
    mov     dx, si
    mov     ah, 0x41
    int     0x21
    jc      .not_found

    popa
    ret

.not_found:
    mov     dx, del_err_msg
    mov     ah, 0x09
    int     0x21
    popa
    ret

.syntax_err:
    mov     dx, del_syntax_msg
    mov     ah, 0x09
    int     0x21
    popa
    ret

del_err_msg     db  'File not found', 0x0D, 0x0A, '$'
del_syntax_msg  db  'Required parameter missing', 0x0D, 0x0A, '$'
