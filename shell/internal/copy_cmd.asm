; ===========================================================================
; COPY command - Copy files
; ===========================================================================

cmd_copy:
    pusha

    ; Parse source filename
    cmp     byte [si], 0
    je      .syntax_err

    mov     dx, copy_stub_msg
    mov     ah, 0x09
    int     0x21

    popa
    ret

.syntax_err:
    mov     dx, copy_syntax_msg
    mov     ah, 0x09
    int     0x21
    popa
    ret

copy_stub_msg   db  'COPY: not yet implemented', 0x0D, 0x0A, '$'
copy_syntax_msg db  'Required parameter missing', 0x0D, 0x0A, '$'
