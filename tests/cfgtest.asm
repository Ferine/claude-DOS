; ===========================================================================
; CFGTEST.COM - Display CONFIG.SYS parsed values
; Queries DOS for values that CONFIG.SYS directives affect
; ===========================================================================
bits 16
org 0x100

    ; Print header
    mov     dx, msg_header
    mov     ah, 09h
    int     21h

    ; --- LASTDRIVE: INT 21h AH=0Eh returns number of drives in AL ---
    mov     ah, 19h             ; Get current drive first
    int     21h
    push    ax                  ; Save current drive
    mov     dl, al              ; Re-select same drive
    mov     ah, 0Eh             ; Set default drive (returns drive count)
    int     21h
    ; AL = number of logical drives (i.e., LASTDRIVE value)
    mov     [num_drives], al
    pop     ax
    mov     dl, al
    mov     ah, 0Eh             ; Restore current drive
    int     21h

    ; Print LASTDRIVE
    mov     dx, msg_lastdrive
    mov     ah, 09h
    int     21h
    mov     al, [num_drives]
    call    print_dec
    mov     dx, msg_drives_parens
    mov     ah, 09h
    int     21h
    ; Print the actual letter
    mov     al, [num_drives]
    add     al, 'A' - 1        ; Convert 5 -> 'E'
    mov     dl, al
    mov     ah, 02h
    int     21h
    mov     dx, msg_rparen_crlf
    mov     ah, 09h
    int     21h

    ; --- FILES: Try to open multiple handles to probe limit ---
    ; Open NUL device repeatedly to count available handles
    xor     cx, cx              ; Count of opened handles
    mov     [handle_count], cx
.open_loop:
    mov     dx, nul_name
    mov     ax, 3D00h           ; Open for reading
    int     21h
    jc      .open_done          ; Can't open more
    ; Save handle for closing later
    mov     bx, [handle_count]
    cmp     bx, 128             ; Safety limit
    jae     .open_done
    shl     bx, 1
    mov     [handle_buf + bx], ax
    inc     word [handle_count]
    jmp     .open_loop

.open_done:
    ; Close all opened handles
    mov     cx, [handle_count]
    xor     si, si
.close_loop:
    test    cx, cx
    jz      .close_done
    mov     bx, [handle_buf + si]
    mov     ah, 3Eh
    int     21h
    add     si, 2
    dec     cx
    jmp     .close_loop
.close_done:

    ; Print FILES (handles opened + 5 for stdin/stdout/stderr/stdaux/stdprn)
    mov     dx, msg_files
    mov     ah, 09h
    int     21h
    mov     ax, [handle_count]
    add     ax, 5               ; Add standard handles
    call    print_dec
    mov     dx, msg_crlf
    mov     ah, 09h
    int     21h

    ; --- DOS version ---
    mov     dx, msg_dosver
    mov     ah, 09h
    int     21h
    mov     ah, 30h
    int     21h
    push    ax
    ; AL = major version
    call    print_dec
    mov     dl, '.'
    mov     ah, 02h
    int     21h
    pop     ax
    mov     al, ah              ; AH = minor version
    xor     ah, ah
    call    print_dec
    mov     dx, msg_crlf
    mov     ah, 09h
    int     21h

    ; --- Current drive ---
    mov     dx, msg_curdrive
    mov     ah, 09h
    int     21h
    mov     ah, 19h
    int     21h
    add     al, 'A'
    mov     dl, al
    mov     ah, 02h
    int     21h
    mov     dl, ':'
    mov     ah, 02h
    int     21h
    mov     dx, msg_crlf
    mov     ah, 09h
    int     21h

    ; --- COMSPEC from environment ---
    mov     dx, msg_comspec
    mov     ah, 09h
    int     21h
    ; Get environment segment from PSP
    mov     ax, [002Ch]         ; PSP offset 2Ch = environment segment
    test    ax, ax
    jz      .no_env
    mov     es, ax
    xor     di, di
    ; Search for COMSPEC=
.env_search:
    cmp     byte [es:di], 0     ; End of environment?
    je      .no_comspec
    ; Check if this var starts with "COMSPEC="
    push    di
    mov     si, comspec_str
    mov     cx, 8               ; Length of "COMSPEC="
.env_cmp:
    mov     al, [es:di]
    cmp     al, [si]
    jne     .env_next
    inc     di
    inc     si
    loop    .env_cmp
    ; Match! Print the value
    pop     di                  ; Discard saved DI
    add     di, 8               ; Skip "COMSPEC="
.print_comspec:
    mov     al, [es:di]
    test    al, al
    jz      .comspec_done
    mov     dl, al
    mov     ah, 02h
    int     21h
    inc     di
    jmp     .print_comspec
.comspec_done:
    mov     dx, msg_crlf
    mov     ah, 09h
    int     21h
    jmp     .env_done

.env_next:
    pop     di
    ; Skip to next env var (find NUL)
.env_skip:
    cmp     byte [es:di], 0
    je      .env_skip_done
    inc     di
    jmp     .env_skip
.env_skip_done:
    inc     di                  ; Skip the NUL
    jmp     .env_search

.no_comspec:
    mov     dx, msg_notset
    mov     ah, 09h
    int     21h
    jmp     .env_done
.no_env:
    mov     dx, msg_noenv
    mov     ah, 09h
    int     21h
.env_done:

    ; Done
    mov     dx, msg_done
    mov     ah, 09h
    int     21h

    mov     ax, 4C00h
    int     21h

; ---------------------------------------------------------------------------
; print_dec - Print AL as decimal number via DOS
; ---------------------------------------------------------------------------
print_dec:
    push    ax
    push    bx
    push    cx
    push    dx
    xor     ah, ah
    mov     bx, 10
    xor     cx, cx              ; Digit count
.pd_div:
    xor     dx, dx
    div     bx
    push    dx                  ; Save remainder (digit)
    inc     cx
    test    ax, ax
    jnz     .pd_div
.pd_print:
    pop     dx
    add     dl, '0'
    mov     ah, 02h
    int     21h
    loop    .pd_print
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

; ---------------------------------------------------------------------------
; Data
; ---------------------------------------------------------------------------
msg_header      db  '=== CONFIG.SYS Test ===$'
msg_crlf        db  0x0D, 0x0A, '$'
msg_lastdrive   db  'LASTDRIVE: $'
msg_drives_parens db ' (drive $'
msg_rparen_crlf db  ')', 0x0D, 0x0A, '$'
msg_files       db  'FILES:     $'
msg_dosver      db  'DOS ver:   $'
msg_curdrive    db  'Drive:     $'
msg_comspec     db  'COMSPEC:   $'
msg_notset      db  '(not set)', 0x0D, 0x0A, '$'
msg_noenv       db  '(no env)', 0x0D, 0x0A, '$'
msg_done        db  0x0D, 0x0A, 'Config test complete.', 0x0D, 0x0A, '$'
comspec_str     db  'COMSPEC='
nul_name        db  'NUL', 0

num_drives      db  0
handle_count    dw  0
handle_buf      times 128 dw 0
