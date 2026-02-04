; ===========================================================================
; TIME command - Display/set time
; ===========================================================================

cmd_time:
    pusha

    ; Get current time
    mov     ah, 0x2C
    int     0x21
    ; CH=hour, CL=minute, DH=second

    ; Save values before any calls that might clobber registers
    mov     [time_hour], ch
    mov     [time_minute], cl
    mov     [time_second], dh

    mov     dx, time_msg
    mov     ah, 0x09
    int     0x21

    ; Hour
    xor     ah, ah
    mov     al, [time_hour]
    call    print_dec2_time

    mov     dl, ':'
    mov     ah, 0x02
    int     0x21

    ; Minute
    xor     ah, ah
    mov     al, [time_minute]
    call    print_dec2_time

    mov     dl, ':'
    mov     ah, 0x02
    int     0x21

    ; Second
    xor     ah, ah
    mov     al, [time_second]
    call    print_dec2_time

    call    print_crlf

    popa
    ret

; Print 2-digit time value with leading zero
print_dec2_time:
    cmp     al, 10
    jae     .no_lead
    push    ax
    mov     dl, '0'
    mov     ah, 0x02
    int     0x21
    pop     ax
.no_lead:
    call    print_dec16
    ret

time_hour       db  0
time_minute     db  0
time_second     db  0
time_msg        db  'Current time is $'
