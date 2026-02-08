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

    call    fat_cluster_to_lba
    jc      .config_done            ; Error
    mov     [.config_cur_lba], ax

    ; Get sectors per cluster from DPB
    mov     bx, [active_dpb]
    xor     ah, ah
    mov     al, [bx + DPB_SEC_PER_CLUS]
    inc     ax                      ; Stored as N-1
    mov     [.config_secs_in_clus], ax

.config_read_sector:
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [.config_cur_lba]
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
    jz      .config_next_sector

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
    ; Re-read the current CONFIG.SYS sector into disk_buffer.
    ; DEVICE= loading clobbers disk_buffer via resolve_path/fat_read_sector.
    ; SI (restored below) still points into disk_buffer at the correct offset.
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [.config_cur_lba]
    call    fat_read_sector
    pop     si
    pop     cx
    ; Reset line buffer
    mov     word [config_line_len], 0
    jmp     .config_byte_loop

.config_next_sector:
    ; Check if more file data remains
    cmp     word [.config_file_size], 0
    je      .config_flush_line

    ; More sectors in this cluster?
    inc     word [.config_cur_lba]
    dec     word [.config_secs_in_clus]
    jnz     .config_read_sector

    ; All sectors in cluster read, get next cluster
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
    jc      .try_device
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

.try_device:
    mov     di, .str_device
    mov     bx, 7                   ; "DEVICE="
    call    .config_match_keyword
    jc      .try_dos
    call    config_load_device
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
.config_cur_lba     dw  0
.config_secs_in_clus dw 0
.config_bytes_left  dw  0
.config_buf_pos     dw  0

; Keyword strings (uppercase)
.str_rem        db  'REM'
.str_files      db  'FILES='
.str_buffers    db  'BUFFERS='
.str_lastdrive  db  'LASTDRIVE='
.str_shell      db  'SHELL='
.str_device     db  'DEVICE='
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

; DEVICE= workspace
dev_filename    times 80 db 0       ; ASCIIZ path buffer
dev_params      dw  0               ; Offset of params string in config_line_buf
dev_params_len  dw  0               ; Length of params remaining
dev_file_size   dw  0               ; File size (low word)
dev_start_clus  dw  0               ; Starting cluster
dev_load_seg    dw  0               ; Segment where driver loaded
dev_req_hdr     times 24 db 0       ; Init request header
dev_call_ptr    dd  0               ; Far pointer for strategy/interrupt calls

; DEVICE= messages
dev_msg_prefix  db  'DEVICE=', 0
dev_msg_crlf    db  0x0D, 0x0A, 0
dev_msg_ok      db  '  loaded', 0x0D, 0x0A, 0
dev_msg_fail    db  '  init failed', 0x0D, 0x0A, 0
dev_msg_nomem   db  '  out of memory', 0x0D, 0x0A, 0
dev_msg_nf      db  '  not found', 0x0D, 0x0A, 0

; ---------------------------------------------------------------------------
; config_load_device - Load and initialize a device driver from DEVICE= line
; Input: DS:SI = pointer past "DEVICE=" in config_line_buf
;        CX = remaining character count
; ---------------------------------------------------------------------------
config_load_device:
    push    es
    push    si
    push    di
    push    ax
    push    bx
    push    cx
    push    dx

    ; Save active drive state (resolve_path may switch drives)
    mov     al, [active_drive_num]
    mov     [.dev_saved_drive], al
    mov     ax, [active_dpb]
    mov     [.dev_saved_dpb], ax
    mov     ax, [fat_eoc_min]
    mov     [.dev_saved_eoc_min], ax
    mov     ax, [fat_eoc_mark]
    mov     [.dev_saved_eoc_mark], ax

    ; --- Step 1: Copy filename from line buffer into dev_filename ---
    ; Default: no params (point at a NUL)
    mov     word [dev_params], dev_filename  ; Will be overwritten if params exist
    mov     di, dev_filename
.dev_copy_name:
    test    cx, cx
    jz      .dev_name_done
    lodsb
    cmp     al, ' '
    je      .dev_name_params
    cmp     al, 0x09                ; TAB
    je      .dev_name_params
    cmp     al, 0x0D
    je      .dev_name_done
    cmp     al, 0x0A
    je      .dev_name_done
    mov     [di], al
    inc     di
    dec     cx
    jmp     .dev_copy_name
.dev_name_params:
    ; Rest of line is params for driver init
    mov     [dev_params], si        ; Save params pointer
    mov     [dev_params_len], cx
.dev_name_done:
    mov     byte [di], 0            ; Null-terminate filename

    ; Print "DEVICE=<filename>\r\n"
    push    si
    mov     si, dev_msg_prefix
    call    bios_print_string
    mov     si, dev_filename
    call    bios_print_string
    mov     si, dev_msg_crlf
    call    bios_print_string
    pop     si

    ; --- Step 2: Resolve the path ---
    mov     si, dev_filename
    call    resolve_path
    jc      .dev_not_found

    ; AX = directory cluster, fcb_name_buffer = FCB name

    ; --- Step 3: Find the file ---
    mov     si, fcb_name_buffer
    call    fat_find_in_directory
    jc      .dev_not_found

    ; DI = directory entry in disk_buffer
    mov     ax, [di + 28]           ; File size low word
    test    ax, ax
    jz      .dev_not_found          ; Empty file
    mov     [dev_file_size], ax
    mov     ax, [di + 26]           ; Starting cluster
    mov     [dev_start_clus], ax

    ; --- Step 4: Allocate memory ---
    ; Must allocate enough for full sector reads (512-byte aligned),
    ; since the loader reads complete sectors from disk.
    ; BX = ceil(file_size / 512) * 32 paragraphs
    mov     ax, [dev_file_size]
    add     ax, 511             ; Round up to next sector
    mov     cl, 9
    shr     ax, cl              ; AX = number of sectors
    mov     cl, 5
    shl     ax, cl              ; AX = paragraphs (32 per sector)
    mov     bx, ax
    call    mcb_alloc
    jc      .dev_no_mem

    ; AX = usable segment; mark MCB owner as MCB_SYSTEM
    mov     [dev_load_seg], ax
    mov     bx, ax
    dec     bx
    mov     es, bx                  ; ES = MCB paragraph
    mov     word [es:1], MCB_SYSTEM ; Set owner to system

    ; --- Step 5: Load file cluster chain ---
    mov     es, [dev_load_seg]
    xor     bx, bx                  ; ES:BX = load_seg:0000
    mov     ax, [dev_start_clus]

.dev_load_loop:
    push    ax                      ; Save cluster number
    call    fat_cluster_to_lba      ; AX = first LBA of cluster
    jc      .dev_read_err_pop

    ; Read all sectors in this cluster
    push    cx
    push    bx                      ; Save buffer pointer
    mov     bx, [active_dpb]
    xor     ch, ch
    mov     cl, [bx + DPB_SEC_PER_CLUS]
    inc     cx                      ; CX = actual sectors per cluster
    pop     bx                      ; Restore buffer pointer
.dev_load_sector:
    call    fat_read_sector         ; Read to ES:BX
    jc      .dev_read_err_pop3
    add     bx, 512
    inc     ax                      ; Next sector LBA
    loop    .dev_load_sector
    pop     cx
    pop     ax                      ; Restore cluster number

    ; Get next cluster
    call    fat_get_next_cluster
    cmp     ax, [fat_eoc_min]
    jb      .dev_load_loop

    ; --- Step 6: Validate driver header ---
    mov     es, [dev_load_seg]
    mov     ax, [es:6]             ; Strategy entry point
    or      ax, [es:8]             ; Interrupt entry point
    test    ax, ax
    jz      .dev_init_fail         ; Both zero = invalid

    ; --- Step 7: Build Init request header (22 bytes) ---
    push    cs
    pop     es
    mov     di, dev_req_hdr
    ; Zero out the request header
    push    cx
    mov     cx, 22
    xor     al, al
    rep     stosb
    pop     cx

    mov     byte [dev_req_hdr + 0], 22     ; Length
    mov     byte [dev_req_hdr + 2], 0      ; Command = INIT
    ; Word at offset 3 = status (already 0)
    ; Dword at offset 18 = far pointer to config line (params after filename)
    mov     ax, [dev_params]
    mov     [dev_req_hdr + 18], ax          ; Offset of params
    mov     [dev_req_hdr + 20], cs          ; Segment (kernel DS)

    ; --- Step 8: Call driver strategy + interrupt ---
    ; ES:BX -> request header
    push    cs
    pop     es
    mov     bx, dev_req_hdr

    ; Call strategy routine
    mov     ax, [dev_load_seg]
    mov     word [dev_call_ptr + 2], ax     ; Segment
    push    es
    mov     es, ax
    mov     ax, [es:6]                     ; Strategy offset
    pop     es
    mov     word [dev_call_ptr], ax
    call    far [dev_call_ptr]

    ; Call interrupt routine
    mov     ax, [dev_load_seg]
    push    es
    mov     es, ax
    mov     ax, [es:8]                     ; Interrupt offset
    pop     es
    mov     word [dev_call_ptr], ax
    ; dev_call_ptr+2 still has load_seg
    ; Restore ES:BX for interrupt call
    push    cs
    pop     es
    mov     bx, dev_req_hdr
    call    far [dev_call_ptr]

    ; --- Step 9: Check result ---
    mov     ax, [dev_req_hdr + 3]           ; Status word
    test    ax, 0x8000                      ; Bit 15 = error
    jnz     .dev_init_fail_free

    ; --- Step 10: Shrink allocation to break address ---
    ; Break address at offset 14 (offset) and 16 (segment)
    mov     ax, [dev_req_hdr + 16]          ; Break segment
    mov     bx, [dev_req_hdr + 14]          ; Break offset
    ; If break address is 0:0, driver wants no resident memory
    or      ax, bx
    jz      .dev_init_fail_free

    ; Calculate resident paragraphs: (break_seg - load_seg) + (break_off + 15) / 16
    mov     ax, [dev_req_hdr + 16]          ; Break segment
    sub     ax, [dev_load_seg]              ; Segments above load
    mov     bx, [dev_req_hdr + 14]          ; Break offset
    add     bx, 15
    shr     bx, 1
    shr     bx, 1
    shr     bx, 1
    shr     bx, 1
    add     bx, ax                          ; BX = total resident paragraphs
    test    bx, bx
    jz      .dev_init_fail_free             ; Zero size = error

    mov     es, [dev_load_seg]
    call    mcb_resize                      ; ES=segment, BX=new size
    ; Ignore resize errors - driver still loaded

    ; --- Step 11: Link into device chain ---
    ; Walk chain from dev_chain_head to find the last device.
    ; dev_chain_head is a dword (off:seg) pointing to first device.
    ; Each device header starts with next_off (word), next_seg (word).
    ; Last device has next_off == 0xFFFF.

    ; Start: load first device pointer from dev_chain_head
    mov     bx, [dev_chain_head]            ; First device offset
    mov     dx, [dev_chain_head + 2]        ; First device segment
    cmp     bx, 0xFFFF
    je      .dev_chain_empty                ; No devices at all

.dev_walk_chain:
    ; ES:BX = current device header
    mov     es, dx
    ; Check if this device's next pointer is 0xFFFF (last in chain)
    cmp     word [es:bx], 0xFFFF
    je      .dev_found_last
    ; Follow to next device
    mov     dx, [es:bx + 2]                ; next_seg (read before overwriting BX)
    mov     bx, [es:bx]                    ; next_off
    jmp     .dev_walk_chain

.dev_chain_empty:
    ; No devices yet - set dev_chain_head to point to new driver
    mov     ax, [dev_load_seg]
    mov     word [dev_chain_head], 0        ; offset 0
    mov     [dev_chain_head + 2], ax        ; segment = load_seg
    jmp     .dev_set_new_next

.dev_found_last:
    ; ES:BX = last device header in chain
    ; Set its next pointer to new driver at dev_load_seg:0000
    mov     ax, [dev_load_seg]
    mov     word [es:bx], 0                 ; next_off = 0
    mov     [es:bx + 2], ax                 ; next_seg = dev_load_seg

.dev_set_new_next:
    ; Set new driver's next pointer to FFFF:FFFF
    mov     es, [dev_load_seg]
    mov     word [es:0], 0xFFFF             ; next_off
    mov     word [es:2], 0xFFFF             ; next_seg

    ; --- Step 12: Print success ---
    ; Print device name from header (offset 0Ah, 8 bytes)
    ; Check if character device
    test    word [es:4], DEV_ATTR_CHAR
    jz      .dev_block_msg

    ; Print character device name
    push    cx
    mov     cx, 8
    mov     di, dev_filename                ; Reuse as temp buffer
    push    ds
    push    es
    pop     ds
    mov     si, 0x0A                        ; Device name at offset 0Ah
    push    cs
    pop     es
    mov     di, dev_filename
.dev_copy_devname:
    lodsb
    mov     [es:di], al
    inc     di
    loop    .dev_copy_devname
    pop     ds
    mov     byte [dev_filename + 8], 0      ; Null-terminate
    pop     cx

.dev_block_msg:
    mov     si, dev_msg_ok
    call    bios_print_string
    jmp     .dev_done

    ; --- Error paths ---
.dev_read_err_pop3:
    pop     cx
.dev_read_err_pop:
    pop     ax
    ; Fall through to init fail - free memory
.dev_init_fail_free:
    mov     es, [dev_load_seg]
    call    mcb_free
    mov     si, dev_msg_fail
    call    bios_print_string
    jmp     .dev_done

.dev_init_fail:
    mov     es, [dev_load_seg]
    call    mcb_free
    mov     si, dev_msg_fail
    call    bios_print_string
    jmp     .dev_done

.dev_not_found:
    mov     si, dev_msg_nf
    call    bios_print_string
    jmp     .dev_done

.dev_no_mem:
    mov     si, dev_msg_nomem
    call    bios_print_string

.dev_done:
    ; Restore active drive state for CONFIG.SYS reading to continue
    mov     al, [.dev_saved_drive]
    mov     [active_drive_num], al
    mov     ax, [.dev_saved_dpb]
    mov     [active_dpb], ax
    mov     ax, [.dev_saved_eoc_min]
    mov     [fat_eoc_min], ax
    mov     ax, [.dev_saved_eoc_mark]
    mov     [fat_eoc_mark], ax

    pop     dx
    pop     cx
    pop     bx
    pop     ax
    pop     di
    pop     si
    pop     es
    ret

; Saved drive state
.dev_saved_drive    db  0
.dev_saved_dpb      dw  0
.dev_saved_eoc_min  dw  0
.dev_saved_eoc_mark dw  0

