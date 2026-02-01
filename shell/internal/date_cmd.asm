; ===========================================================================
; DATE command - Display/set date
; ===========================================================================

cmd_date:
    pusha

    ; Get current date
    mov     ah, 0x2A
    int     0x21
    ; CX=year, DH=month, DL=day

    ; Print "Current date is M-DD-YYYY"
    push    cx
    push    dx
    mov     dx, date_msg
    mov     ah, 0x09
    int     0x21
    pop     dx
    pop     cx

    ; Month
    xor     ah, ah
    mov     al, dh
    call    print_dec16
    mov     dl, '-'
    mov     ah, 0x02
    int     0x21

    ; Day
    push    cx
    xor     ah, ah
    mov     al, [esp + 2]       ; Hmm, this is getting tricky with the stack
    pop     cx
    ; Just use saved values - simpler approach
    mov     ax, [save_date_day]
    call    print_dec16
    mov     dl, '-'
    mov     ah, 0x02
    int     0x21

    ; Year
    mov     ax, [save_date_year]
    call    print_dec16

    call    print_crlf

    popa
    ret

save_date_day   dw  0
save_date_year  dw  0
date_msg        db  'Current date is $'
