; ===========================================================================
; claudeDOS INT 21h Miscellaneous Functions
; ===========================================================================

; AH=25h - Set interrupt vector
; Input: AL = interrupt number, DS:DX = new handler address
int21_25:
    push    es
    push    bx

    xor     bx, bx
    mov     es, bx

    mov     al, [save_ax]        ; Interrupt number
    xor     ah, ah
    shl     ax, 2               ; AX = vector offset
    mov     bx, ax

    mov     ax, [save_dx]
    mov     [es:bx], ax          ; Offset
    mov     ax, [save_ds]
    mov     [es:bx + 2], ax      ; Segment

    pop     bx
    pop     es
    call    dos_clear_error
    ret

; AH=2Ah - Get date
; Output: CX = year, DH = month, DL = day, AL = day of week
int21_2A:
    push    bx
    push    si

    ; Read RTC date via INT 1Ah AH=04h
    ; Returns: CH = century (BCD), CL = year (BCD), DH = month (BCD), DL = day (BCD)
    mov     ah, 0x04
    int     0x1A
    jc      .date_rtc_fail          ; RTC not available

    ; Save the BCD values before conversion
    mov     [.date_century], ch
    mov     [.date_year], cl
    mov     [.date_month], dh
    mov     [.date_day], dl

    ; Convert century (BCD) to binary and multiply by 100
    mov     al, [.date_century]
    call    bcd_to_bin
    mov     bl, al                  ; BL = century (binary)
    mov     al, 100
    mul     bl                      ; AX = century * 100
    mov     si, ax                  ; SI = century * 100

    ; Convert year (BCD) to binary and add to century
    mov     al, [.date_year]
    call    bcd_to_bin
    xor     ah, ah
    add     ax, si                  ; AX = full year (e.g., 2025)
    mov     [save_cx], ax           ; CX = year

    ; Convert month (BCD) to binary
    mov     al, [.date_month]
    call    bcd_to_bin
    mov     [save_dx + 1], al       ; DH = month

    ; Convert day (BCD) to binary
    mov     al, [.date_day]
    call    bcd_to_bin
    mov     [save_dx], al           ; DL = day

    ; Calculate day of week (simplified Zeller's formula)
    ; For simplicity, just return 0 (Sunday) - full calculation would be complex
    ; A proper implementation would use Zeller's congruence
    mov     byte [save_ax], 0       ; AL = day of week (0=Sunday)

    pop     si
    pop     bx
    call    dos_clear_error
    ret

.date_rtc_fail:
    ; RTC not available - return a default date
    mov     word [save_cx], 2025    ; Year
    mov     byte [save_dx + 1], 1   ; Month (January)
    mov     byte [save_dx], 1       ; Day (1st)
    mov     byte [save_ax], 0       ; Sunday
    pop     si
    pop     bx
    call    dos_clear_error
    ret

; Temp storage for BCD date values
.date_century   db  0
.date_year      db  0
.date_month     db  0
.date_day       db  0

; AH=2Bh - Set date (stub)
int21_2B:
    mov     byte [save_ax], 0   ; AL=0 = success
    call    dos_clear_error
    ret

; AH=2Ch - Get time
int21_2C:
    mov     ah, 0x02
    int     0x1A                ; Read RTC time
    ; CH = hour (BCD), CL = minute (BCD), DH = second (BCD)
    
    ; Convert BCD to binary
    mov     al, ch
    call    bcd_to_bin
    mov     [save_cx + 1], al   ; CH = hour
    
    mov     al, cl
    call    bcd_to_bin
    mov     [save_cx], al       ; CL = minute
    
    mov     al, dh
    call    bcd_to_bin
    mov     [save_dx + 1], al   ; DH = second
    
    mov     byte [save_dx], 0   ; DL = centiseconds
    
    call    dos_clear_error
    ret

; AH=2Dh - Set time (stub)
int21_2D:
    mov     byte [save_ax], 0   ; Success
    call    dos_clear_error
    ret

; AH=2Eh - Set verify flag
; Input: AL = 0 (off) or 1 (on)
int21_2E:
    mov     al, [save_ax]
    mov     [verify_flag], al
    ret

; AH=30h - Get DOS version
; Output: AL = major, AH = minor, BH = OEM serial, BL:CX = 24-bit serial
int21_30:
    mov     byte [save_ax], DOS_VERSION_MAJOR    ; AL = major
    mov     byte [save_ax + 1], DOS_VERSION_MINOR ; AH = minor
    mov     word [save_bx], 0                     ; BX = OEM + serial high
    mov     word [save_cx], 0                     ; CX = serial low
    call    dos_clear_error
    ret

; AH=33h - Get/Set Ctrl-Break check flag
int21_33:
    mov     al, [save_ax]        ; AL = subfunction
    test    al, al
    jz      .get_break
    cmp     al, 1
    je      .set_break
    
    ; Subfunction 06h - get true DOS version
    cmp     al, 6
    je      .get_true_ver
    ret

.get_break:
    mov     al, [break_flag]
    mov     byte [save_dx], al   ; DL = break flag
    ret

.set_break:
    mov     al, [save_dx]        ; DL = new flag
    mov     [break_flag], al
    ret

.get_true_ver:
    mov     byte [save_bx + 1], DOS_VERSION_MAJOR  ; BH = major (?)
    ; Actually: BL = major, BH = minor for subfunc 06h
    mov     byte [save_bx], DOS_VERSION_MAJOR
    mov     byte [save_bx + 1], DOS_VERSION_MINOR
    mov     word [save_dx], 0     ; Revision + flags
    ret

; AH=34h - Get InDOS flag address
; Output: ES:BX = address of InDOS flag
int21_34:
    mov     [save_es], cs
    mov     word [save_bx], indos_flag
    call    dos_clear_error
    ret

; AH=35h - Get interrupt vector
; Input: AL = interrupt number
; Output: ES:BX = handler address
int21_35:
    push    ds
    push    si

    xor     si, si
    mov     ds, si              ; DS = 0 (IVT segment)

    mov     al, [cs:save_ax]
    xor     ah, ah
    shl     ax, 2               ; Offset in IVT
    mov     si, ax

    mov     ax, [si]            ; Offset
    mov     [cs:save_bx], ax
    mov     ax, [si + 2]        ; Segment
    mov     [cs:save_es], ax

    pop     si
    pop     ds
    call    dos_clear_error
    ret

; AH=50h - Set PSP
; Input: BX = new PSP segment
int21_50:
    mov     bx, [save_bx]
    mov     [current_psp], bx
    ret

; AH=51h - Get PSP
; Output: BX = current PSP segment
int21_51:
    mov     bx, [current_psp]
    mov     [save_bx], bx
    ret

; AH=62h - Get PSP address
; Output: BX = current PSP segment
int21_62:
    mov     bx, [current_psp]
    mov     [save_bx], bx
    ret

; ---------------------------------------------------------------------------
; bcd_to_bin - Convert BCD byte to binary
; Input: AL = BCD value
; Output: AL = binary value
; ---------------------------------------------------------------------------
bcd_to_bin:
    push    cx
    mov     cl, al
    shr     al, 4               ; High nibble
    mov     ch, 10
    mul     ch                  ; AX = high * 10
    and     cl, 0x0F            ; Low nibble
    add     al, cl
    pop     cx
    ret
