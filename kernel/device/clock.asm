; ===========================================================================
; claudeDOS CLOCK$ Device Driver
; Reads/writes system date and time via BIOS RTC (INT 1Ah)
;
; DOS CLOCK$ transfer format (6 bytes):
;   Offset 0: word - days since 1980-01-01
;   Offset 2: byte - minutes
;   Offset 3: byte - hours
;   Offset 4: byte - hundredths of second
;   Offset 5: byte - seconds
; ===========================================================================

clock_device:
    dw      0xFFFF
    dw      0
    dw      DEV_ATTR_CHAR | DEV_ATTR_ISCLK
    dw      clock_strategy
    dw      clock_interrupt
    db      'CLOCK$  '

clock_req_ptr   dd  0

clock_strategy:
    mov     [cs:clock_req_ptr], bx
    mov     [cs:clock_req_ptr + 2], es
    retf

clock_interrupt:
    push    ds
    push    es
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di

    lds     bx, [cs:clock_req_ptr]
    mov     al, [bx + 2]           ; Command code

    cmp     al, 0                   ; Init
    je      .cmd_init
    cmp     al, 4                   ; Read
    je      .cmd_read
    cmp     al, 8                   ; Write
    je      .cmd_write

    ; Unknown command - return done
    mov     word [bx + 3], 0x0100
    jmp     .done

; ---------------------------------------------------------------------------
; Init - just return success
; ---------------------------------------------------------------------------
.cmd_init:
    mov     word [bx + 3], 0x0100
    jmp     .done

; ---------------------------------------------------------------------------
; Read - return current date/time in 6-byte DOS CLOCK$ format
; ---------------------------------------------------------------------------
.cmd_read:
    ; Get transfer address
    les     di, [bx + 14]

    ; Read RTC date: INT 1Ah AH=04h
    ; Returns: CH=century(BCD), CL=year(BCD), DH=month(BCD), DL=day(BCD)
    push    bx
    push    ds
    mov     ah, 0x04
    int     0x1A
    jc      .read_no_rtc

    ; Convert BCD date to days since 1980-01-01
    ; First convert BCD to binary
    mov     al, ch                  ; Century BCD
    call    .bcd_to_bin
    mov     ah, al                  ; AH = century
    mov     al, cl                  ; Year BCD
    call    .bcd_to_bin             ; AL = year
    ; Full year = century * 100 + year
    push    dx
    push    ax
    mov     al, ah
    xor     ah, ah
    mov     cx, 100
    mul     cx                      ; AX = century * 100
    pop     dx                      ; DL = year (was in AL)
    xor     dh, dh
    and     dx, 0x00FF
    add     ax, dx                  ; AX = full year
    mov     [cs:.clock_year], ax
    pop     dx

    mov     al, dh                  ; Month BCD
    call    .bcd_to_bin
    mov     [cs:.clock_month], al

    mov     al, dl                  ; Day BCD
    call    .bcd_to_bin
    mov     [cs:.clock_day], al

    ; Calculate days since 1980-01-01
    call    .calc_days
    ; AX = days since epoch
    mov     [es:di], ax             ; Store days

    ; Read RTC time: INT 1Ah AH=02h
    ; Returns: CH=hours(BCD), CL=minutes(BCD), DH=seconds(BCD)
    mov     ah, 0x02
    int     0x1A
    jc      .read_no_rtc_time

    mov     al, cl                  ; Minutes BCD
    call    .bcd_to_bin
    mov     [es:di + 2], al

    mov     al, ch                  ; Hours BCD
    call    .bcd_to_bin
    mov     [es:di + 3], al

    mov     byte [es:di + 4], 0    ; Hundredths (RTC doesn't provide)

    mov     al, dh                  ; Seconds BCD
    call    .bcd_to_bin
    mov     [es:di + 5], al

    pop     ds
    pop     bx
    mov     word [bx + 18], 6      ; Bytes transferred
    mov     word [bx + 3], 0x0100  ; Done, no error
    jmp     .done

.read_no_rtc:
    pop     ds
    pop     bx
.read_no_rtc_time:
    ; Zero fill on RTC failure
    xor     ax, ax
    mov     [es:di], ax
    mov     [es:di + 2], ax
    mov     [es:di + 4], ax
    lds     bx, [cs:clock_req_ptr]
    mov     word [bx + 18], 6
    mov     word [bx + 3], 0x0100
    jmp     .done

; ---------------------------------------------------------------------------
; Write - set system date/time from 6-byte DOS CLOCK$ format
; ---------------------------------------------------------------------------
.cmd_write:
    push    bx
    push    ds
    lds     si, [bx + 14]

    ; Read the 6-byte structure
    mov     ax, [si]                ; Days since 1980-01-01
    mov     [cs:.clock_days], ax
    mov     al, [si + 2]           ; Minutes
    mov     [cs:.clock_min], al
    mov     al, [si + 3]           ; Hours
    mov     [cs:.clock_hr], al
    mov     al, [si + 5]           ; Seconds
    mov     [cs:.clock_sec], al

    ; Convert days back to year/month/day
    call    .days_to_date

    ; Set RTC date: INT 1Ah AH=05h
    ; CH=century(BCD), CL=year(BCD), DH=month(BCD), DL=day(BCD)
    mov     ax, [cs:.clock_year]
    xor     dx, dx
    mov     cx, 100
    div     cx                      ; AX = century, DX = year in century
    call    .bin_to_bcd
    mov     ch, al                  ; CH = century BCD
    mov     al, dl
    call    .bin_to_bcd
    mov     cl, al                  ; CL = year BCD
    mov     al, [cs:.clock_month]
    call    .bin_to_bcd
    mov     dh, al                  ; DH = month BCD
    mov     al, [cs:.clock_day]
    call    .bin_to_bcd
    mov     dl, al                  ; DL = day BCD
    mov     ah, 0x05
    int     0x1A

    ; Set RTC time: INT 1Ah AH=03h
    ; CH=hours(BCD), CL=minutes(BCD), DH=seconds(BCD), DL=DST(0)
    mov     al, [cs:.clock_hr]
    call    .bin_to_bcd
    mov     ch, al
    mov     al, [cs:.clock_min]
    call    .bin_to_bcd
    mov     cl, al
    mov     al, [cs:.clock_sec]
    call    .bin_to_bcd
    mov     dh, al
    xor     dl, dl                  ; No DST
    mov     ah, 0x03
    int     0x1A

    pop     ds
    pop     bx
    mov     word [bx + 18], 6
    mov     word [bx + 3], 0x0100
    jmp     .done

.done:
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    pop     es
    pop     ds
    retf

; ---------------------------------------------------------------------------
; BCD to binary: AL(BCD) -> AL(binary)
; ---------------------------------------------------------------------------
.bcd_to_bin:
    push    cx
    mov     cl, al
    shr     al, 4               ; High nibble (tens)
    and     cl, 0x0F            ; Low nibble (ones)
    mov     ch, 10
    mul     ch
    add     al, cl
    pop     cx
    ret

; ---------------------------------------------------------------------------
; Binary to BCD: AL(binary) -> AL(BCD)
; ---------------------------------------------------------------------------
.bin_to_bcd:
    push    cx
    xor     ah, ah
    mov     cl, 10
    div     cl                  ; AL = tens, AH = ones
    shl     al, 4
    or      al, ah
    xor     ah, ah
    pop     cx
    ret

; ---------------------------------------------------------------------------
; calc_days - Calculate days since 1980-01-01
; Input: .clock_year, .clock_month, .clock_day
; Output: AX = days
; ---------------------------------------------------------------------------
.calc_days:
    push    bx
    push    cx
    push    dx

    ; Days = (year - 1980) * 365 + leap_days + month_days + day - 1
    mov     ax, [cs:.clock_year]
    sub     ax, 1980
    mov     cx, ax              ; CX = years since 1980
    mov     bx, 365
    mul     bx                  ; DX:AX = years * 365
    push    ax                  ; Save low word

    ; Count leap days from 1980 to year-1
    mov     ax, [cs:.clock_year]
    dec     ax                  ; year - 1
    push    ax
    ; Leap days = y/4 - y/100 + y/400
    xor     dx, dx
    mov     bx, 4
    div     bx
    mov     cx, ax              ; CX = y/4
    pop     ax
    push    ax
    xor     dx, dx
    mov     bx, 100
    div     bx
    sub     cx, ax              ; CX -= y/100
    pop     ax
    xor     dx, dx
    mov     bx, 400
    div     bx
    add     cx, ax              ; CX += y/400

    ; Subtract leap days for 1979 (base)
    ; 1979/4=494, 1979/100=19, 1979/400=4 → 494-19+4 = 479
    sub     cx, 479

    pop     ax                  ; Restore years * 365
    add     ax, cx              ; Add leap days

    ; Add days for completed months
    xor     ch, ch
    mov     cl, [cs:.clock_month]
    dec     cl                  ; Months completed (0-11)
    jz      .add_day
    mov     si, .month_days
.month_loop:
    xor     bh, bh
    mov     bl, [cs:si]
    add     ax, bx
    inc     si
    loop    .month_loop

    ; Check if leap year and month > 2, add 1
    cmp     byte [cs:.clock_month], 3
    jb      .add_day
    call    .is_leap_year
    jnc     .add_day
    inc     ax

.add_day:
    ; Add day of month (1-based)
    xor     bh, bh
    mov     bl, [cs:.clock_day]
    add     ax, bx
    dec     ax                  ; 0-based

    pop     dx
    pop     cx
    pop     bx
    ret

; ---------------------------------------------------------------------------
; days_to_date - Convert days since 1980-01-01 to year/month/day
; Input: .clock_days
; Output: .clock_year, .clock_month, .clock_day
; ---------------------------------------------------------------------------
.days_to_date:
    push    ax
    push    bx
    push    cx
    push    dx

    mov     ax, [cs:.clock_days]
    inc     ax                  ; 1-based
    mov     cx, 1980            ; Starting year
.year_loop:
    ; Days in this year
    mov     [cs:.clock_year], cx
    call    .is_leap_year
    mov     bx, 365
    jnc     .not_leap_yr
    inc     bx                  ; 366
.not_leap_yr:
    cmp     ax, bx
    jbe     .found_year
    sub     ax, bx
    inc     cx
    jmp     .year_loop
.found_year:
    ; AX = day-of-year (1-based)
    mov     si, .month_days
    mov     cl, 1               ; Month counter
.month_scan:
    xor     bh, bh
    mov     bl, [cs:si]
    ; Check for Feb leap day
    cmp     cl, 2
    jne     .no_feb_adj
    push    ax
    call    .is_leap_year
    pop     ax
    jnc     .no_feb_adj
    inc     bx
.no_feb_adj:
    cmp     ax, bx
    jbe     .found_month
    sub     ax, bx
    inc     cl
    inc     si
    jmp     .month_scan
.found_month:
    mov     [cs:.clock_month], cl
    mov     [cs:.clock_day], al

    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

; ---------------------------------------------------------------------------
; is_leap_year - Check if .clock_year is a leap year
; Output: CF=1 if leap
; ---------------------------------------------------------------------------
.is_leap_year:
    push    ax
    push    bx
    push    dx
    mov     ax, [cs:.clock_year]
    xor     dx, dx
    mov     bx, 4
    div     bx
    test    dx, dx
    jnz     .not_leap           ; Not divisible by 4
    mov     ax, [cs:.clock_year]
    xor     dx, dx
    mov     bx, 100
    div     bx
    test    dx, dx
    jnz     .is_leap            ; Divisible by 4 but not 100
    mov     ax, [cs:.clock_year]
    xor     dx, dx
    mov     bx, 400
    div     bx
    test    dx, dx
    jnz     .not_leap           ; Divisible by 100 but not 400
.is_leap:
    pop     dx
    pop     bx
    pop     ax
    stc
    ret
.not_leap:
    pop     dx
    pop     bx
    pop     ax
    clc
    ret

; Days per month (non-leap)
.month_days db  31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31

; Working variables
.clock_year     dw  0
.clock_month    db  0
.clock_day      db  0
.clock_days     dw  0
.clock_hr       db  0
.clock_min      db  0
.clock_sec      db  0
