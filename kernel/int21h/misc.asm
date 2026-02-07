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

    ; Calculate day of week using Sakamoto's algorithm
    ; dow = (year + year/4 - year/100 + year/400 + t[month-1] + day) % 7
    ; For Jan/Feb, use previous year
    ; t[] = {0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4}

    ; Use temp storage to simplify
    mov     ax, [save_cx]           ; AX = year
    mov     [.dow_year], ax
    xor     ah, ah
    mov     al, [save_dx + 1]       ; AL = month
    mov     [.dow_month], al
    mov     al, [save_dx]           ; AL = day
    mov     [.dow_day], al

    ; If month < 3, decrement year
    cmp     byte [.dow_month], 3
    jae     .dow_no_adj
    dec     word [.dow_year]
.dow_no_adj:

    ; Start sum with day
    xor     ax, ax
    mov     al, [.dow_day]
    mov     [.dow_sum], ax

    ; Add year
    mov     ax, [.dow_year]
    add     [.dow_sum], ax

    ; Add year/4
    mov     ax, [.dow_year]
    shr     ax, 2
    add     [.dow_sum], ax

    ; Subtract year/100
    mov     ax, [.dow_year]
    xor     dx, dx
    mov     bx, 100
    div     bx
    sub     [.dow_sum], ax

    ; Add year/400
    mov     ax, [.dow_year]
    xor     dx, dx
    mov     bx, 400
    div     bx
    add     [.dow_sum], ax

    ; Add t[month-1]
    xor     bx, bx
    mov     bl, [.dow_month]
    dec     bl
    mov     al, [.dow_table + bx]
    xor     ah, ah
    add     [.dow_sum], ax

    ; sum mod 7
    mov     ax, [.dow_sum]
    xor     dx, dx
    mov     bx, 7
    div     bx
    mov     [save_ax], dl           ; DL = day of week (0=Sunday)

    pop     si
    pop     bx
    call    dos_clear_error
    ret

.dow_year   dw  0
.dow_month  db  0
.dow_day    db  0
.dow_sum    dw  0
.dow_table  db  0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4

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

; AH=2Bh - Set date
; Input: CX = year (1980-2099), DH = month (1-12), DL = day (1-31)
; Output: AL = 0 on success, 0xFF on invalid input
int21_2B:
    ; Validate year
    mov     cx, [save_cx]
    cmp     cx, 1980
    jb      .setdate_invalid
    cmp     cx, 2099
    ja      .setdate_invalid

    ; Validate month
    mov     al, [save_dx + 1]       ; DH = month
    test    al, al
    jz      .setdate_invalid
    cmp     al, 12
    ja      .setdate_invalid

    ; Validate day
    mov     al, [save_dx]           ; DL = day
    test    al, al
    jz      .setdate_invalid
    cmp     al, 31
    ja      .setdate_invalid

    ; Convert year to century + year
    mov     ax, [save_cx]           ; AX = full year
    xor     dx, dx
    mov     bx, 100
    div     bx                      ; AX = century, DX = year within century

    ; Convert century to BCD
    push    dx
    call    bin_to_bcd
    mov     ch, al                  ; CH = century (BCD)
    pop     ax                      ; AL = year within century

    ; Convert year to BCD
    call    bin_to_bcd
    mov     cl, al                  ; CL = year (BCD)

    ; Convert month to BCD
    mov     al, [save_dx + 1]
    call    bin_to_bcd
    mov     dh, al                  ; DH = month (BCD)

    ; Convert day to BCD
    mov     al, [save_dx]
    call    bin_to_bcd
    mov     dl, al                  ; DL = day (BCD)

    ; Call INT 1Ah AH=05h - Set RTC Date
    mov     ah, 0x05
    int     0x1A

    mov     byte [save_ax], 0       ; AL = 0 = success
    call    dos_clear_error
    ret

.setdate_invalid:
    mov     byte [save_ax], 0xFF    ; AL = 0xFF = invalid
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

; AH=2Dh - Set time
; Input: CH = hour (0-23), CL = minute (0-59), DH = second (0-59), DL = centisecond
; Output: AL = 0 on success, 0xFF on invalid input
int21_2D:
    ; Validate hour
    mov     al, [save_cx + 1]       ; CH = hour
    cmp     al, 23
    ja      .settime_invalid

    ; Validate minute
    mov     al, [save_cx]           ; CL = minute
    cmp     al, 59
    ja      .settime_invalid

    ; Validate second
    mov     al, [save_dx + 1]       ; DH = second
    cmp     al, 59
    ja      .settime_invalid

    ; Convert hour to BCD
    mov     al, [save_cx + 1]
    call    bin_to_bcd
    mov     ch, al                  ; CH = hour (BCD)

    ; Convert minute to BCD
    mov     al, [save_cx]
    call    bin_to_bcd
    mov     cl, al                  ; CL = minute (BCD)

    ; Convert second to BCD
    mov     al, [save_dx + 1]
    call    bin_to_bcd
    mov     dh, al                  ; DH = second (BCD)

    ; DL = 0 (no DST info)
    xor     dl, dl

    ; Call INT 1Ah AH=03h - Set RTC Time
    mov     ah, 0x03
    int     0x1A

    mov     byte [save_ax], 0       ; AL = 0 = success
    call    dos_clear_error
    ret

.settime_invalid:
    mov     byte [save_ax], 0xFF    ; AL = 0xFF = invalid
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

; AH=52h - Get List of Lists (SysVars pointer)
; Output: ES:BX = pointer to DOS internal variable table
; Note: [ES:BX-2] = first MCB segment (used by MEM utility)
int21_52:
    ; Return pointer to sysvars structure
    ; The first MCB segment is stored at [sysvars - 2]
    mov     word [save_es], cs
    mov     word [save_bx], sysvars
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

; ===========================================================================
; AH=59h - Get Extended Error Information
; Input: BX = version (0000h for DOS 3.0+)
; Output: AX = extended error code, BH = class, BL = action, CH = locus
; ===========================================================================
int21_59:
    mov     ax, [last_error]
    mov     [save_ax], ax
    mov     al, [last_error_class]
    mov     [save_bx + 1], al       ; BH = error class
    mov     al, [last_error_action]
    mov     [save_bx], al           ; BL = suggested action
    mov     al, [last_error_locus]
    mov     [save_cx + 1], al       ; CH = error locus
    mov     byte [save_cx], 0       ; CL = 0
    call    dos_clear_error
    ret

; ===========================================================================
; AH=60h - Truename (Canonicalize filename)
; Input: DS:SI = source ASCIIZ path, ES:DI = 128-byte destination buffer
; Output: ES:DI buffer filled with canonical path, CF clear
;         CF set, AX = error code on failure
; ===========================================================================
int21_60:
    push    si
    push    di
    push    bx
    push    cx
    push    dx

    ; Copy source path from caller's DS:SI to path_buffer
    push    ds
    push    es
    mov     ds, [cs:save_ds]
    mov     si, [cs:save_si]
    push    cs
    pop     es
    mov     di, path_buffer
    mov     cx, 127
.tn_copy_src:
    lodsb
    stosb
    test    al, al
    jz      .tn_src_copied
    loop    .tn_copy_src
    mov     byte [es:di], 0
.tn_src_copied:
    pop     es
    pop     ds                      ; DS = kernel segment

    ; Use .tn_out_buf as our working output buffer
    mov     di, .tn_out_buf
    mov     si, path_buffer

    ; Parse drive letter
    cmp     byte [si + 1], ':'
    jne     .tn_no_drive

    ; Drive letter present
    mov     al, [si]
    ; Convert to uppercase
    cmp     al, 'a'
    jb      .tn_drive_ok
    cmp     al, 'z'
    ja      .tn_drive_ok
    sub     al, 0x20
.tn_drive_ok:
    mov     [di], al
    mov     byte [di + 1], ':'
    mov     byte [di + 2], '\'
    add     di, 3
    add     si, 2                   ; Skip drive letter and colon
    jmp     .tn_check_abs

.tn_no_drive:
    ; No drive letter - use current drive
    mov     al, [current_drive]
    add     al, 'A'
    mov     [di], al
    mov     byte [di + 1], ':'
    mov     byte [di + 2], '\'
    add     di, 3

.tn_check_abs:
    ; Check if path is absolute (starts with \ or /)
    cmp     byte [si], '\'
    je      .tn_abs
    cmp     byte [si], '/'
    je      .tn_abs

    ; Relative path - prepend current_dir_path
    cmp     byte [current_dir_path], 0
    je      .tn_process_components  ; Empty = root, nothing to prepend

    ; Copy current_dir_path components
    push    si
    mov     si, current_dir_path
.tn_copy_cwd:
    lodsb
    test    al, al
    jz      .tn_cwd_done
    ; Convert forward slash to backslash
    cmp     al, '/'
    jne     .tn_cwd_not_slash
    mov     al, '\'
.tn_cwd_not_slash:
    ; Convert to uppercase
    cmp     al, 'a'
    jb      .tn_cwd_store
    cmp     al, 'z'
    ja      .tn_cwd_store
    sub     al, 0x20
.tn_cwd_store:
    mov     [di], al
    inc     di
    jmp     .tn_copy_cwd
.tn_cwd_done:
    ; Add trailing backslash after CWD if not already there
    cmp     byte [di - 1], '\'
    je      .tn_cwd_has_sep
    mov     byte [di], '\'
    inc     di
.tn_cwd_has_sep:
    pop     si
    jmp     .tn_process_components

.tn_abs:
    inc     si                      ; Skip the leading \ or /

.tn_process_components:
    ; Process path components from SI, building result at DI
    ; DI points after "X:\" (and possibly CWD)
.tn_next_component:
    cmp     byte [si], 0
    je      .tn_done

    ; Skip consecutive separators
    cmp     byte [si], '\'
    je      .tn_skip_sep
    cmp     byte [si], '/'
    je      .tn_skip_sep

    ; Check for "." component
    cmp     byte [si], '.'
    jne     .tn_regular

    ; Check for ".."
    cmp     byte [si + 1], '.'
    jne     .tn_check_single_dot

    ; ".." - check that next char is separator or null
    mov     al, [si + 2]
    test    al, al
    jz      .tn_dotdot
    cmp     al, '\'
    je      .tn_dotdot
    cmp     al, '/'
    je      .tn_dotdot
    ; Not really ".." - treat as regular name
    jmp     .tn_regular

.tn_dotdot:
    ; Remove last component from output
    ; Back up DI to before last backslash (but not past "X:\")
    mov     bx, .tn_out_buf
    add     bx, 3                   ; BX = position right after "X:\"
.tn_backup:
    cmp     di, bx
    jbe     .tn_at_root             ; Already at root, can't go higher
    dec     di
    cmp     byte [di], '\'
    jne     .tn_backup
    ; DI now points at the backslash before last component
    ; Keep DI here (we'll add the next component after it, or add backslash)
    inc     di                      ; Point past the backslash
    jmp     .tn_skip_dotdot

.tn_at_root:
    mov     di, bx                  ; Reset to right after "X:\"

.tn_skip_dotdot:
    add     si, 2                   ; Skip ".."
    ; Skip trailing separator if present
    cmp     byte [si], '\'
    je      .tn_skip_dotdot_sep
    cmp     byte [si], '/'
    je      .tn_skip_dotdot_sep
    jmp     .tn_next_component
.tn_skip_dotdot_sep:
    inc     si
    jmp     .tn_next_component

.tn_check_single_dot:
    ; "." - check that next char is separator or null
    mov     al, [si + 1]
    test    al, al
    jz      .tn_singledot
    cmp     al, '\'
    je      .tn_singledot
    cmp     al, '/'
    je      .tn_singledot
    ; Not really "." - treat as regular name
    jmp     .tn_regular

.tn_singledot:
    ; Skip "." component
    inc     si
    ; Skip trailing separator if present
    cmp     byte [si], '\'
    je      .tn_skip_sep
    cmp     byte [si], '/'
    je      .tn_skip_sep
    jmp     .tn_next_component

.tn_skip_sep:
    inc     si
    jmp     .tn_next_component

.tn_regular:
    ; Copy regular component, uppercasing, until separator or null
.tn_copy_char:
    lodsb
    test    al, al
    jz      .tn_end_component
    cmp     al, '\'
    je      .tn_end_component_sep
    cmp     al, '/'
    je      .tn_end_component_sep
    ; Convert to uppercase
    cmp     al, 'a'
    jb      .tn_store_char
    cmp     al, 'z'
    ja      .tn_store_char
    sub     al, 0x20
.tn_store_char:
    mov     [di], al
    inc     di
    jmp     .tn_copy_char

.tn_end_component_sep:
    ; End of component with separator following
    mov     byte [di], '\'
    inc     di
    jmp     .tn_next_component

.tn_end_component:
    ; End of component at end of string - don't add trailing backslash
    jmp     .tn_done

.tn_done:
    ; Remove trailing backslash unless it's the root "X:\"
    mov     bx, .tn_out_buf
    add     bx, 3                   ; Position right after "X:\"
    cmp     di, bx
    jbe     .tn_finalize            ; At root "X:\" - keep it
    cmp     byte [di - 1], '\'
    jne     .tn_finalize
    dec     di                      ; Remove trailing backslash

.tn_finalize:
    ; Null-terminate
    mov     byte [di], 0

    ; Copy result to caller's ES:DI buffer
    push    ds
    push    es
    mov     es, [cs:save_es]
    mov     di, [cs:save_di]
    push    cs
    pop     ds
    mov     si, .tn_out_buf
.tn_copy_out:
    lodsb
    stosb
    test    al, al
    jnz     .tn_copy_out
    pop     es
    pop     ds

    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    call    dos_clear_error
    ret

; Working buffer for truename output
.tn_out_buf     times 128 db 0

; ===========================================================================
; AH=67h - Set Handle Count
; Input: BX = new handle table size
; Output: CF clear on success, CF set + AX = error on failure
; ===========================================================================
int21_67:
    push    es
    push    di
    push    si
    push    bx
    push    cx
    push    dx

    mov     bx, [save_bx]          ; BX = requested handle count

    ; If BX <= 20, just return success (default table already holds 20)
    cmp     bx, MAX_HANDLES
    jbe     .sh_success

    ; BX > 20: allocate memory for new handle table
    ; Calculate paragraphs needed: (BX + 15) / 16
    mov     ax, bx
    add     ax, 15
    shr     ax, 4                   ; AX = paragraphs needed
    push    bx                      ; Save requested count
    mov     bx, ax
    call    mcb_alloc               ; AX = segment of new block
    pop     bx                      ; Restore requested count
    jc      .sh_no_mem

    ; AX = segment of newly allocated block
    mov     dx, ax                  ; DX = new table segment

    ; Get current PSP
    mov     es, [current_psp]

    ; Fill new table with 0xFF (unused handles)
    push    es
    push    di
    mov     es, dx                  ; ES = new table segment
    xor     di, di                  ; Offset 0
    mov     cx, bx                  ; Count = requested size
    mov     al, 0xFF
    rep     stosb
    pop     di
    pop     es                      ; ES = PSP again

    ; Copy existing handle table entries to new block
    ; Check if PSP:0x34 already points to an external table
    ; Default: PSP:0x34 = offset 0x18, segment = PSP segment
    push    ds
    push    es                      ; Save PSP seg
    ; Load current handle table pointer from PSP:0x34
    mov     si, [es:0x34]           ; Offset of current handle table
    mov     ax, [es:0x36]           ; Segment of current handle table
    mov     ds, ax                  ; DS:SI = current handle table

    ; Get current handle count
    mov     es, [cs:current_psp]
    mov     cx, [es:0x32]           ; Current handle count
    test    cx, cx
    jnz     .sh_has_count
    mov     cx, MAX_HANDLES         ; Default if 0
.sh_has_count:
    ; Don't copy more than the new size
    cmp     cx, bx
    jbe     .sh_copy_count_ok
    mov     cx, bx
.sh_copy_count_ok:

    ; Copy CX bytes from DS:SI to new table at DX:0000
    push    es
    mov     es, dx                  ; ES:DI = new table
    xor     di, di
    rep     movsb
    pop     es

    ; Check if old table was external (not the default PSP:0x18)
    ; If old segment != PSP segment or old offset != 0x18, it's external
    mov     ax, ds                  ; Old table segment
    pop     es                      ; ES = PSP again (from earlier push)
    push    es
    mov     cx, es                  ; CX = PSP segment
    cmp     ax, cx
    jne     .sh_free_old
    cmp     si, 0x18 + MAX_HANDLES  ; SI was advanced past copy; original was 0x18 if default
    ; Actually SI was advanced, let's check differently
    ; The original offset was loaded before copy, but SI has been modified
    ; We need to save the original offset. Let's recalculate:
    ; Original SI = [es:0x34] but we already modified...
    ; Actually we haven't updated PSP:0x34 yet, so we can re-read it
    mov     si, [es:0x34]           ; Re-read original offset
    cmp     si, 0x18
    jne     .sh_free_old
    ; Default table at PSP:0x18, no need to free
    jmp     .sh_update_psp

.sh_free_old:
    ; Free old external handle table
    ; The segment to free is one less than the data segment (MCB header)
    ; Actually mcb_free expects the segment of the data block (after MCB)
    push    bx
    push    dx
    push    es
    mov     es, ax                  ; ES = old table segment
    call    mcb_free
    pop     es
    pop     dx
    pop     bx

.sh_update_psp:
    pop     es                      ; ES = PSP
    pop     ds                      ; DS = kernel segment

    ; Update PSP:0x32 = new handle count
    mov     [es:0x32], bx

    ; Update PSP:0x34 = far pointer to new table (offset:segment)
    mov     word [es:0x34], 0       ; Offset = 0 (start of new segment)
    mov     [es:0x36], dx           ; Segment = new block

.sh_success:
    pop     dx
    pop     cx
    pop     bx
    pop     si
    pop     di
    pop     es
    call    dos_clear_error
    ret

.sh_no_mem:
    pop     dx
    pop     cx
    pop     bx
    pop     si
    pop     di
    pop     es
    mov     ax, ERR_INSUFFICIENT_MEM
    jmp     dos_set_error

; ===========================================================================
; AH=68h - Commit (Flush) File
; Input: BX = file handle
; Output: CF clear on success, CF set + AX = error on failure
; ===========================================================================
int21_68:
    push    es
    push    di
    push    bx
    push    bp

    mov     bx, [save_bx]

    ; Device handles (0-4) don't need flushing
    cmp     bx, 4
    jbe     .cf_success

    ; Get SFT entry for the handle
    call    handle_to_sft
    jc      .cf_bad_handle

    ; DI = SFT entry pointer
    mov     bp, di

    ; Switch to the file's drive
    mov     al, [cs:bp + SFT_ENTRY.flags]
    cmp     al, 0x80
    jne     .cf_not_hd
    mov     al, 2                   ; C:
    jmp     .cf_set_drive
.cf_not_hd:
.cf_set_drive:
    call    fat_set_active_drive

    ; Read directory sector containing this file's entry
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [cs:bp + SFT_ENTRY.dir_sector]
    call    fat_read_sector
    jc      .cf_error

    ; Calculate offset to directory entry
    xor     ah, ah
    mov     al, [cs:bp + SFT_ENTRY.dir_index]
    shl     ax, 5                   ; * 32
    mov     bx, ax
    add     bx, disk_buffer

    ; Update directory entry fields from SFT
    mov     ax, [cs:bp + SFT_ENTRY.first_cluster]
    mov     [bx + 26], ax

    mov     ax, [cs:bp + SFT_ENTRY.file_size]
    mov     [bx + 28], ax
    mov     ax, [cs:bp + SFT_ENTRY.file_size + 2]
    mov     [bx + 30], ax

    mov     ax, [cs:bp + SFT_ENTRY.time]
    mov     [bx + 22], ax
    mov     ax, [cs:bp + SFT_ENTRY.date]
    mov     [bx + 24], ax

    ; Write directory sector back
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [cs:bp + SFT_ENTRY.dir_sector]
    call    fat_write_sector
    jc      .cf_error

.cf_success:
    pop     bp
    pop     bx
    pop     di
    pop     es
    call    dos_clear_error
    ret

.cf_bad_handle:
    pop     bp
    pop     bx
    pop     di
    pop     es
    mov     ax, ERR_INVALID_HANDLE
    jmp     dos_set_error

.cf_error:
    pop     bp
    pop     bx
    pop     di
    pop     es
    mov     ax, ERR_WRITE_FAULT
    jmp     dos_set_error

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

; ---------------------------------------------------------------------------
; bin_to_bcd - Convert binary byte to BCD
; Input: AL = binary value (0-99)
; Output: AL = BCD value
; ---------------------------------------------------------------------------
bin_to_bcd:
    push    cx
    xor     ah, ah
    mov     cl, 10
    div     cl                  ; AL = quotient (tens), AH = remainder (ones)
    shl     al, 4               ; High nibble = tens
    or      al, ah              ; Low nibble = ones
    pop     cx
    ret
