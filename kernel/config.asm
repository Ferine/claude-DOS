; ===========================================================================
; claudeDOS CONFIG.SYS Parser
; ===========================================================================

; ---------------------------------------------------------------------------
; parse_config_sys - Parse CONFIG.SYS at boot time
; Called during kernel init with DS=CS=kernel segment
; ---------------------------------------------------------------------------
parse_config_sys:
    push    es
    push    si
    push    di
    push    ax
    push    bx
    push    cx
    push    dx

    ; Search root directory for CONFIG.SYS
    mov     si, .config_filename
    call    fat_find_in_root
    jc      .config_done            ; Not found - return silently

    ; DI = pointer to dir entry in disk_buffer, AX = sector
    ; Get first cluster from directory entry
    mov     ax, [di + 26]           ; First cluster
    test    ax, ax
    jz      .config_done            ; Empty file

    ; Get file size
    mov     dx, [di + 28]           ; File size low word
    mov     [.config_file_size], dx
    mov     dx, [di + 30]           ; File size high word (ignore, CONFIG.SYS is small)

    ; Read file sector by sector following cluster chain
    mov     word [.config_bytes_left], 0
    mov     word [.config_buf_pos], 0
    mov     word [.config_cur_cluster], ax
    mov     word [config_line_len], 0

.config_read_loop:
    ; Check if we still have file data to process
    mov     ax, [.config_file_size]
    test    ax, ax
    jz      .config_flush_line      ; No more data, flush last line

    ; Read current cluster
    mov     ax, [.config_cur_cluster]
    cmp     ax, [fat_eoc_min]
    jae     .config_flush_line      ; End of chain

    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_cluster_to_lba
    call    fat_read_sector
    jc      .config_done            ; Read error

    ; Process bytes in this sector
    mov     si, disk_buffer
    mov     cx, 512
    ; Clamp to remaining file size
    cmp     cx, [.config_file_size]
    jbe     .config_have_count
    mov     cx, [.config_file_size]
.config_have_count:
    sub     [.config_file_size], cx

.config_byte_loop:
    test    cx, cx
    jz      .config_next_cluster

    lodsb
    dec     cx

    ; Check for CR or LF
    cmp     al, 0x0D                ; CR
    je      .config_end_line
    cmp     al, 0x0A                ; LF
    je      .config_end_line

    ; Accumulate character in line buffer
    mov     bx, [config_line_len]
    cmp     bx, 79                  ; Max line length
    jae     .config_byte_loop       ; Skip if line too long
    mov     [config_line_buf + bx], al
    inc     word [config_line_len]
    jmp     .config_byte_loop

.config_end_line:
    ; Process the line if it has content
    push    cx
    push    si
    call    .config_process_line
    pop     si
    pop     cx
    ; Reset line buffer
    mov     word [config_line_len], 0
    jmp     .config_byte_loop

.config_next_cluster:
    ; Get next cluster
    mov     ax, [.config_cur_cluster]
    call    fat_get_next_cluster
    mov     [.config_cur_cluster], ax
    jmp     .config_read_loop

.config_flush_line:
    ; Process any remaining line in buffer
    cmp     word [config_line_len], 0
    je      .config_done
    call    .config_process_line

.config_done:
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    pop     di
    pop     si
    pop     es
    ret

; ---------------------------------------------------------------------------
; .config_process_line - Process one CONFIG.SYS line
; Uses config_line_buf / config_line_len
; ---------------------------------------------------------------------------
.config_process_line:
    push    si
    push    di
    push    ax
    push    bx
    push    cx

    mov     si, config_line_buf
    mov     cx, [config_line_len]

    ; Skip leading whitespace
.skip_ws:
    test    cx, cx
    jz      .line_done
    lodsb
    dec     cx
    cmp     al, ' '
    je      .skip_ws
    cmp     al, 0x09                ; TAB
    je      .skip_ws
    ; Back up to first non-whitespace
    dec     si
    inc     cx

    ; Check for comment (';' at start)
    cmp     byte [si], ';'
    je      .line_done

    ; Check for empty line
    test    cx, cx
    jz      .line_done

    ; Try to match known directives (case-insensitive)
    ; Check for "REM"
    mov     di, .str_rem
    mov     bx, 3
    call    .config_match_keyword
    jc      .try_files
    jmp     .line_done              ; REM = comment, skip

.try_files:
    mov     di, .str_files
    mov     bx, 6                   ; "FILES="
    call    .config_match_keyword
    jc      .try_buffers
    ; Parse decimal number
    call    .config_parse_decimal
    mov     [config_files], ax
    jmp     .line_done

.try_buffers:
    mov     di, .str_buffers
    mov     bx, 8                   ; "BUFFERS="
    call    .config_match_keyword
    jc      .try_lastdrive
    call    .config_parse_decimal
    mov     [config_buffers], ax
    jmp     .line_done

.try_lastdrive:
    mov     di, .str_lastdrive
    mov     bx, 10                  ; "LASTDRIVE="
    call    .config_match_keyword
    jc      .try_shell
    ; Parse drive letter
    lodsb
    ; Convert to uppercase
    cmp     al, 'a'
    jb      .ld_upper
    cmp     al, 'z'
    ja      .ld_upper
    sub     al, 0x20
.ld_upper:
    sub     al, 'A'
    inc     al                      ; A=1, B=2, ...
    mov     [config_lastdrive], al
    jmp     .line_done

.try_shell:
    mov     di, .str_shell
    mov     bx, 6                   ; "SHELL="
    call    .config_match_keyword
    jc      .try_dos
    ; Copy rest of line to config_shell
    mov     di, config_shell
    ; cx = remaining chars after keyword match
.copy_shell:
    test    cx, cx
    jz      .shell_null
    lodsb
    cmp     al, 0x0D
    je      .shell_null
    cmp     al, 0x0A
    je      .shell_null
    mov     [di], al
    inc     di
    dec     cx
    jmp     .copy_shell
.shell_null:
    mov     byte [di], 0           ; Null-terminate
    jmp     .line_done

.try_dos:
    mov     di, .str_dos
    mov     bx, 4                   ; "DOS="
    call    .config_match_keyword
    jc      .line_done              ; Unknown directive, skip

    ; Parse DOS= value: check for HIGH and UMB
.dos_parse_loop:
    test    cx, cx
    jz      .line_done
    ; Skip whitespace and commas
    lodsb
    dec     cx
    cmp     al, ' '
    je      .dos_parse_loop
    cmp     al, ','
    je      .dos_parse_loop
    cmp     al, 0x09
    je      .dos_parse_loop
    ; Back up
    dec     si
    inc     cx

    ; Try "HIGH"
    push    si
    push    cx
    mov     di, .str_high
    mov     bx, 4
    call    .config_match_keyword
    jc      .dos_not_high
    ; Matched HIGH
    add     sp, 4                   ; Discard saved si/cx
    mov     byte [config_dos_high], 1
    jmp     .dos_parse_loop
.dos_not_high:
    pop     cx
    pop     si

    ; Try "UMB"
    push    si
    push    cx
    mov     di, .str_umb
    mov     bx, 3
    call    .config_match_keyword
    jc      .dos_not_umb
    add     sp, 4
    mov     byte [config_dos_umb], 1
    jmp     .dos_parse_loop
.dos_not_umb:
    pop     cx
    pop     si
    ; Skip unknown character
    inc     si
    dec     cx
    jmp     .dos_parse_loop

.line_done:
    pop     cx
    pop     bx
    pop     ax
    pop     di
    pop     si
    ret

; ---------------------------------------------------------------------------
; .config_match_keyword - Case-insensitive match of keyword at DS:SI
; Input: DS:SI = line buffer position, CX = remaining chars
;        DS:DI = keyword string (uppercase), BX = keyword length
; Output: CF=0 if matched (SI/CX advanced past keyword)
;         CF=1 if no match (SI/CX unchanged)
; ---------------------------------------------------------------------------
.config_match_keyword:
    push    ax
    push    dx
    push    si
    push    cx
    push    di
    push    bx

    ; Check if enough characters remain
    cmp     cx, bx
    jb      .kw_no_match

    mov     dx, bx                  ; DX = chars to compare
.kw_cmp_loop:
    test    dx, dx
    jz      .kw_matched
    lodsb
    ; Convert to uppercase
    cmp     al, 'a'
    jb      .kw_upper
    cmp     al, 'z'
    ja      .kw_upper
    sub     al, 0x20
.kw_upper:
    cmp     al, [di]
    jne     .kw_no_match
    inc     di
    dec     dx
    dec     cx
    jmp     .kw_cmp_loop

.kw_matched:
    ; Success - discard saved SI/CX and return updated values
    pop     bx
    pop     di
    add     sp, 4                   ; Discard saved CX, SI
    pop     dx
    pop     ax
    clc
    ret

.kw_no_match:
    pop     bx
    pop     di
    pop     cx                      ; Restore original CX
    pop     si                      ; Restore original SI
    pop     dx
    pop     ax
    stc
    ret

; ---------------------------------------------------------------------------
; .config_parse_decimal - Parse decimal number from DS:SI
; Input: DS:SI = string, CX = remaining chars
; Output: AX = parsed number, SI/CX updated
; ---------------------------------------------------------------------------
.config_parse_decimal:
    push    bx
    push    dx
    xor     ax, ax                  ; Result = 0
.dec_loop:
    test    cx, cx
    jz      .dec_done
    mov     bl, [si]
    cmp     bl, '0'
    jb      .dec_done
    cmp     bl, '9'
    ja      .dec_done
    ; result = result * 10 + digit
    mov     dx, 10
    mul     dx                      ; AX = AX * 10 (ignore DX overflow for small numbers)
    sub     bl, '0'
    xor     bh, bh
    add     ax, bx
    inc     si
    dec     cx
    jmp     .dec_loop
.dec_done:
    pop     dx
    pop     bx
    ret

; Local data
.config_filename    db  'CONFIG  SYS'
.config_file_size   dw  0
.config_cur_cluster dw  0
.config_bytes_left  dw  0
.config_buf_pos     dw  0

; Keyword strings (uppercase)
.str_rem        db  'REM'
.str_files      db  'FILES='
.str_buffers    db  'BUFFERS='
.str_lastdrive  db  'LASTDRIVE='
.str_shell      db  'SHELL='
.str_dos        db  'DOS='
.str_high       db  'HIGH'
.str_umb        db  'UMB'

; CONFIG.SYS settings (defaults)
config_files    dw  8           ; FILES= (default 8)
config_buffers  dw  15          ; BUFFERS= (default 15)
config_lastdrive db 5           ; LASTDRIVE= (default E)
config_shell    times 64 db 0   ; SHELL= path
config_dos_high db  0           ; DOS=HIGH
config_dos_umb  db  0           ; DOS=UMB

; Line buffer
config_line_buf times 80 db 0
config_line_len dw  0
