; ===========================================================================
; TIME command - Display/set time
; ===========================================================================

cmd_time:
    pusha

    ; Get current time
    mov     ah, 0x2C
    int     0x21
    ; CH=hour, CL=minute, DH=second

    mov     dx, time_msg
    mov     ah, 0x09
    int     0x21

    ; Hour
    xor     ah, ah
    mov     al, ch
    push    cx
    push    dx
    call    print_dec16
    mov     dl, ':'
    mov     ah, 0x02
    int     0x21
    pop     dx
    pop     cx

    ; Minute
    xor     ah, ah
    mov     al, cl
    push    dx
    call    print_dec16
    mov     dl, ':'
    mov     ah, 0x02
    int     0x21
    pop     dx

    ; Second
    xor     ah, ah
    mov     al, dh
    call    print_dec16

    call    print_crlf

    popa
    ret

time_msg        db  'Current time is $'
