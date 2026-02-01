; ===========================================================================
; MD/MKDIR command - Create directory
; ===========================================================================

cmd_md:
    pusha

    cmp     byte [si], 0
    je      .syntax_err

    mov     dx, si
    mov     ah, 0x39
    int     0x21
    jc      .error

    popa
    ret

.error:
    mov     dx, md_err_msg
    mov     ah, 0x09
    int     0x21
    popa
    ret

.syntax_err:
    mov     dx, md_syntax_msg
    mov     ah, 0x09
    int     0x21
    popa
    ret

md_err_msg      db  'Unable to create directory', 0x0D, 0x0A, '$'
md_syntax_msg   db  'Required parameter missing', 0x0D, 0x0A, '$'
