; ===========================================================================
; DATE command - Display/set date
; ===========================================================================

cmd_date:
    pusha

    ; Get current date
    mov     ah, 0x2A
    int     0x21
    ; CX=year, DH=month, DL=day, AL=day of week

    ; Save values
    mov     [date_year], cx
    mov     [date_month], dh
    mov     [date_day], dl
    mov     [date_dow], al

    ; Print "Current date is DayOfWeek MM-DD-YYYY"
    push    dx
    mov     dx, date_msg
    mov     ah, 0x09
    int     0x21
    pop     dx

    ; Print day of week
    mov     al, [date_dow]
    cmp     al, 7
    jae     .skip_dow
    xor     ah, ah
    mov     bx, ax
    shl     bx, 1
    shl     bx, 1               ; *4 for string table offset
    add     bx, date_dow_table
    mov     dx, [bx]
    mov     ah, 0x09
    int     0x21
.skip_dow:

    ; Month (with leading zero if < 10)
    xor     ah, ah
    mov     al, [date_month]
    call    print_dec2

    mov     dl, '-'
    mov     ah, 0x02
    int     0x21

    ; Day (with leading zero)
    xor     ah, ah
    mov     al, [date_day]
    call    print_dec2

    mov     dl, '-'
    mov     ah, 0x02
    int     0x21

    ; Year
    mov     ax, [date_year]
    call    print_dec16

    call    print_crlf

    ; Check if argument provided (to set date)
    cmp     byte [si], 0
    je      .done

    ; TODO: Parse and set date from argument
    mov     dx, date_set_msg
    mov     ah, 0x09
    int     0x21

.done:
    popa
    ret

; Print 2-digit decimal with leading zero
print_dec2:
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

date_year       dw  0
date_month      db  0
date_day        db  0
date_dow        db  0

date_msg        db  'Current date is $'
date_set_msg    db  'Date setting not yet implemented', 0x0D, 0x0A, '$'

date_dow_table:
    dw      date_sun, date_mon, date_tue, date_wed
    dw      date_thu, date_fri, date_sat

date_sun    db  'Sun $'
date_mon    db  'Mon $'
date_tue    db  'Tue $'
date_wed    db  'Wed $'
date_thu    db  'Thu $'
date_fri    db  'Fri $'
date_sat    db  'Sat $'
