; ===========================================================================
; MEM.COM - Display memory usage
; ===========================================================================
    CPU     186
    ORG     0x0100

    ; Get total conventional memory
    int     0x12                ; AX = KB
    push    ax

    mov     dx, msg_header
    mov     ah, 0x09
    int     0x21

    ; Total conventional memory
    mov     dx, msg_conv
    mov     ah, 0x09
    int     0x21

    pop     ax
    call    print_dec
    mov     dx, msg_kb
    mov     ah, 0x09
    int     0x21

    ; Get DOS version
    mov     ah, 0x30
    int     0x21
    push    ax

    mov     dx, msg_dosver
    mov     ah, 0x09
    int     0x21

    pop     ax
    xor     ah, ah
    call    print_dec
    mov     dl, '.'
    mov     ah, 0x02
    int     0x21

    mov     ah, 0x30
    int     0x21
    mov     al, ah
    xor     ah, ah
    call    print_dec

    mov     dx, msg_crlf
    mov     ah, 0x09
    int     0x21

    mov     ax, 0x4C00
    int     0x21

print_dec:
    xor     cx, cx
    mov     bx, 10
.div:
    xor     dx, dx
    div     bx
    push    dx
    inc     cx
    test    ax, ax
    jnz     .div
.out:
    pop     dx
    add     dl, '0'
    mov     ah, 0x02
    int     0x21
    loop    .out
    ret

msg_header  db  0x0D, 0x0A, 'Memory Type        Total', 0x0D, 0x0A
            db  '----------------  ------', 0x0D, 0x0A, '$'
msg_conv    db  'Conventional       $'
msg_kb      db  'K', 0x0D, 0x0A, '$'
msg_dosver  db  0x0D, 0x0A, 'DOS Version: $'
msg_crlf    db  0x0D, 0x0A, '$'
