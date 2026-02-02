; ===========================================================================
; REN/RENAME command - Rename files
; Usage: REN oldname newname
; ===========================================================================

cmd_ren:
    pusha
    push    es

    ; Check for arguments
    cmp     byte [si], 0
    je      .syntax_err

    ; Parse source filename (first argument)
    call    parse_filename          ; DX = source, SI advanced
    mov     [ren_src], dx

    ; Skip spaces to second argument
    call    skip_spaces
    cmp     byte [si], 0
    je      .syntax_err

    ; Parse destination filename
    call    parse_filename          ; DX = dest, SI advanced
    mov     [ren_dst], dx

    ; Set up for INT 21h/56h (Rename File)
    ; DS:DX = old name, ES:DI = new name
    push    cs
    pop     es
    mov     dx, [ren_src]
    mov     di, [ren_dst]

    mov     ah, 0x56
    int     0x21
    jc      .error

    ; Success - print confirmation
    mov     dx, ren_ok_msg
    mov     ah, 0x09
    int     0x21

    pop     es
    popa
    ret

.syntax_err:
    mov     dx, ren_syntax_msg
    mov     ah, 0x09
    int     0x21
    pop     es
    popa
    ret

.error:
    ; Check error code in AX
    cmp     ax, 2
    je      .not_found
    cmp     ax, 3
    je      .not_found
    cmp     ax, 5
    je      .access_denied
    cmp     ax, 17
    je      .diff_drive

    ; Generic error
    mov     dx, ren_err_msg
    mov     ah, 0x09
    int     0x21
    pop     es
    popa
    ret

.not_found:
    mov     dx, ren_not_found_msg
    mov     ah, 0x09
    int     0x21
    pop     es
    popa
    ret

.access_denied:
    mov     dx, ren_access_msg
    mov     ah, 0x09
    int     0x21
    pop     es
    popa
    ret

.diff_drive:
    mov     dx, ren_drive_msg
    mov     ah, 0x09
    int     0x21
    pop     es
    popa
    ret

; Data
ren_src             dw  0
ren_dst             dw  0
ren_ok_msg          db  '1 file(s) renamed', 0x0D, 0x0A, '$'
ren_syntax_msg      db  'Syntax: REN oldname newname', 0x0D, 0x0A, '$'
ren_err_msg         db  'Error renaming file', 0x0D, 0x0A, '$'
ren_not_found_msg   db  'File not found', 0x0D, 0x0A, '$'
ren_access_msg      db  'Access denied', 0x0D, 0x0A, '$'
ren_drive_msg       db  'Cannot rename across drives', 0x0D, 0x0A, '$'
