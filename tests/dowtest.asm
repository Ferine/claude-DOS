; ===========================================================================
; DOWTEST.COM - Debug day-of-week calculation
; ===========================================================================

    CPU     186
    ORG     0x0100

start:
    mov     dx, msg_header
    mov     ah, 0x09
    int     0x21

    ; Call INT 21h/2Ah to get date
    mov     ah, 0x2A
    int     0x21

    ; AL = day of week, CX = year, DH = month, DL = day
    ; Save them all
    mov     [dow_result], al
    mov     [year_result], cx
    mov     [month_result], dh
    mov     [day_result], dl

    ; Print year
    mov     dx, msg_year
    mov     ah, 0x09
    int     0x21
    mov     ax, [year_result]
    call    print_dec16
    call    print_crlf

    ; Print month
    mov     dx, msg_month
    mov     ah, 0x09
    int     0x21
    xor     ah, ah
    mov     al, [month_result]
    call    print_dec16
    call    print_crlf

    ; Print day
    mov     dx, msg_day
    mov     ah, 0x09
    int     0x21
    xor     ah, ah
    mov     al, [day_result]
    call    print_dec16
    call    print_crlf

    ; Print day of week (numeric)
    mov     dx, msg_dow_num
    mov     ah, 0x09
    int     0x21
    xor     ah, ah
    mov     al, [dow_result]
    call    print_dec16
    call    print_crlf

    ; Print day of week (name)
    mov     dx, msg_dow_name
    mov     ah, 0x09
    int     0x21
    xor     bh, bh
    mov     bl, [dow_result]
    cmp     bl, 7
    jae     .bad_dow
    shl     bx, 1               ; *2 for word table offset
    add     bx, dow_table
    mov     dx, [bx]
    mov     ah, 0x09
    int     0x21
    jmp     .done

.bad_dow:
    mov     dx, msg_invalid
    mov     ah, 0x09
    int     0x21

.done:
    call    print_crlf

    ; Now manually compute what it should be
    mov     dx, msg_expected
    mov     ah, 0x09
    int     0x21

    ; Sakamoto algorithm:
    ; For Feb 4, 2026:
    ; y = 2026, m = 2, d = 4
    ; Since m < 3, y = 2025
    ; dow = (y + y/4 - y/100 + y/400 + t[m-1] + d) % 7
    ; dow = (2025 + 506 - 20 + 5 + 3 + 4) % 7
    ; dow = 2523 % 7 = 3 (Wednesday)

    mov     ax, [year_result]
    mov     [calc_year], ax

    ; If month < 3, decrement year
    cmp     byte [month_result], 3
    jae     .no_dec
    dec     word [calc_year]
.no_dec:

    ; sum = day
    xor     ah, ah
    mov     al, [day_result]
    mov     [calc_sum], ax

    ; sum += year
    mov     ax, [calc_year]
    add     [calc_sum], ax

    ; sum += year/4
    mov     ax, [calc_year]
    shr     ax, 2
    add     [calc_sum], ax

    ; sum -= year/100
    mov     ax, [calc_year]
    xor     dx, dx
    mov     bx, 100
    div     bx
    sub     [calc_sum], ax

    ; sum += year/400
    mov     ax, [calc_year]
    xor     dx, dx
    mov     bx, 400
    div     bx
    add     [calc_sum], ax

    ; sum += t[month-1]
    xor     bh, bh
    mov     bl, [month_result]
    dec     bl
    mov     al, [t_table + bx]
    xor     ah, ah
    add     [calc_sum], ax

    ; Print intermediate sum
    mov     dx, msg_sum
    mov     ah, 0x09
    int     0x21
    mov     ax, [calc_sum]
    call    print_dec16
    call    print_crlf

    ; sum % 7
    mov     ax, [calc_sum]
    xor     dx, dx
    mov     bx, 7
    div     bx
    ; DX = remainder = day of week

    ; Print result
    mov     dx, msg_result
    mov     ah, 0x09
    int     0x21
    mov     ax, dx          ; Remainder
    call    print_dec16
    mov     dx, msg_paren
    mov     ah, 0x09
    int     0x21

    ; Print name
    cmp     al, 7
    jae     .bad2
    xor     ah, ah
    shl     ax, 1
    shl     ax, 1
    add     ax, dow_table
    mov     bx, ax
    mov     dx, [bx]
    mov     ah, 0x09
    int     0x21

.bad2:
    mov     dx, msg_close
    mov     ah, 0x09
    int     0x21

    ; Exit
    mov     ax, 0x4C00
    int     0x21

; ---------------------------------------------------------------------------
print_dec16:
    push    ax
    push    bx
    push    cx
    push    dx
    xor     cx, cx
    mov     bx, 10
.div_loop:
    xor     dx, dx
    div     bx
    push    dx
    inc     cx
    test    ax, ax
    jnz     .div_loop
.print_loop:
    pop     dx
    add     dl, '0'
    mov     ah, 0x02
    int     0x21
    loop    .print_loop
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

print_crlf:
    push    ax
    push    dx
    mov     dl, 0x0D
    mov     ah, 0x02
    int     0x21
    mov     dl, 0x0A
    int     0x21
    pop     dx
    pop     ax
    ret

; ---------------------------------------------------------------------------
msg_header      db  '=== Day of Week Debug ===', 0x0D, 0x0A, 0x0D, 0x0A, '$'
msg_year        db  'Year:          $'
msg_month       db  'Month:         $'
msg_day         db  'Day:           $'
msg_dow_num     db  'DOW (kernel):  $'
msg_dow_name    db  'DOW name:      $'
msg_expected    db  0x0D, 0x0A, 'Manual calculation:', 0x0D, 0x0A, '$'
msg_sum         db  'Sum:           $'
msg_result      db  'DOW (calc):    $'
msg_paren       db  ' ($'
msg_close       db  ')', 0x0D, 0x0A, '$'
msg_invalid     db  'INVALID$'

dow_table:
    dw      dow_sun, dow_mon, dow_tue, dow_wed
    dw      dow_thu, dow_fri, dow_sat

dow_sun     db  'Sunday$'
dow_mon     db  'Monday$'
dow_tue     db  'Tuesday$'
dow_wed     db  'Wednesday$'
dow_thu     db  'Thursday$'
dow_fri     db  'Friday$'
dow_sat     db  'Saturday$'

t_table     db  0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4

dow_result      db  0
year_result     dw  0
month_result    db  0
day_result      db  0
calc_year       dw  0
calc_sum        dw  0
