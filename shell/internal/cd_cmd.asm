; ===========================================================================
; CD/CHDIR command - Change directory
; ===========================================================================

cmd_cd:
    pusha

    cmp     byte [si], 0
    je      .show_dir

    ; Change directory
    mov     dx, si
    mov     ah, 0x3B
    int     0x21
    jc      .error

    popa
    ret

.show_dir:
    ; Show current directory
    mov     dl, 0               ; Default drive
    mov     si, cd_buf
    mov     ah, 0x47
    int     0x21

    ; Print drive letter
    mov     ah, 0x19
    int     0x21
    add     al, 'A'
    mov     dl, al
    mov     ah, 0x02
    int     0x21
    mov     dl, ':'
    int     0x21
    mov     dl, '\'
    int     0x21

    ; Print path
    mov     dx, cd_buf
    call    print_asciiz
    call    print_crlf

    popa
    ret

.error:
    mov     dx, cd_err_msg
    mov     ah, 0x09
    int     0x21
    popa
    ret

cd_err_msg      db  'Invalid directory', 0x0D, 0x0A, '$'
cd_buf          times 68 db 0
