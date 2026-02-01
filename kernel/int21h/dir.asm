; ===========================================================================
; claudeDOS INT 21h Directory Functions - Stubs (Phase 3/7)
; ===========================================================================

; AH=39h - Create directory
int21_39:
    mov     ax, ERR_ACCESS_DENIED
    jmp     dos_set_error

; AH=3Ah - Remove directory
int21_3A:
    mov     ax, ERR_ACCESS_DENIED
    jmp     dos_set_error

; AH=3Bh - Change directory
int21_3B:
    ; Accept the path but just succeed for now
    call    dos_clear_error
    ret

; AH=47h - Get current directory
int21_47:
    ; Return root directory "\" in DS:SI buffer
    push    es
    push    di
    
    mov     es, [save_ds]
    mov     di, [save_si]
    mov     byte [es:di], 0      ; Empty string = root
    
    pop     di
    pop     es
    call    dos_clear_error
    ret

; AH=4Eh - Find first matching file
; Input: DS:DX = ASCIIZ filespec with wildcards, CX = attribute mask
int21_4E:
    push    es
    push    si
    push    di
    push    bx

    ; Save search attribute
    mov     ax, [save_cx]
    mov     [search_attr], al

    ; Copy filespec from caller's DS:DX to path_buffer
    push    ds
    mov     ds, [cs:save_ds]
    mov     si, [cs:save_dx]
    push    cs
    pop     es
    mov     di, path_buffer
    mov     cx, 127
.ff_copy:
    lodsb
    stosb
    test    al, al
    jz      .ff_copied
    loop    .ff_copy
    mov     byte [es:di], 0
.ff_copied:
    pop     ds                      ; DS = kernel seg

    ; Convert to FCB-format wildcard pattern in search_name
    mov     si, path_buffer
    call    ff_name_to_pattern

    ; Initialize search state: start at root directory sector 19, entry 0
    mov     word [search_dir_sector], 19
    mov     word [search_dir_index], 0

    ; Fall through to FindNext logic
    jmp     ff_search_loop

; AH=4Fh - Find next matching file
int21_4F:
    push    es
    push    si
    push    di
    push    bx

    ; Continue searching from saved state in DTA

ff_search_loop:
    ; Check if we've exhausted root directory (14 sectors, starting at 19)
    mov     ax, [search_dir_sector]
    cmp     ax, 33                  ; 19 + 14 = 33
    jae     .ff_no_more

    ; Read current directory sector
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_read_sector
    jc      .ff_error

    ; Calculate entry pointer from index
    mov     ax, [search_dir_index]
    shl     ax, 5                   ; * 32 bytes per entry
    mov     di, disk_buffer
    add     di, ax

.ff_check_entry:
    ; Check if past end of sector (16 entries per sector)
    mov     ax, di
    sub     ax, disk_buffer
    cmp     ax, 512
    jae     .ff_next_sector

    ; Check if end of directory
    cmp     byte [di], 0x00
    je      .ff_no_more

    ; Check if deleted entry
    cmp     byte [di], 0xE5
    je      .ff_skip_entry

    ; Check if volume label (skip unless searching for volume)
    test    byte [di + 11], ATTR_VOLUME_LABEL
    jz      .ff_check_attr
    test    byte [search_attr], ATTR_VOLUME_LABEL
    jz      .ff_skip_entry

.ff_check_attr:
    ; Check attribute mask: entry attr AND (search_attr OR 0x21) must match
    ; Actually DOS behavior: hidden/system files only returned if requested
    mov     al, [di + 11]           ; Entry attribute
    test    al, ATTR_HIDDEN | ATTR_SYSTEM
    jz      .ff_match_name          ; No special attrs, always match
    ; Has hidden or system - check if we want them
    mov     ah, [search_attr]
    and     ah, ATTR_HIDDEN | ATTR_SYSTEM
    and     al, ATTR_HIDDEN | ATTR_SYSTEM
    test    al, ah                  ; Are requested attrs present?
    jz      .ff_skip_entry

.ff_match_name:
    ; Match 11-byte FCB name against search_name pattern (with wildcards)
    push    di
    mov     si, search_name
    mov     cx, 11
.ff_cmp_loop:
    mov     al, [si]
    cmp     al, '?'                 ; ? matches any char
    je      .ff_cmp_next
    cmp     al, [di]
    jne     .ff_cmp_fail
.ff_cmp_next:
    inc     si
    inc     di
    loop    .ff_cmp_loop
    pop     di
    jmp     .ff_found               ; Match!

.ff_cmp_fail:
    pop     di

.ff_skip_entry:
    add     di, 32
    inc     word [search_dir_index]
    jmp     .ff_check_entry

.ff_next_sector:
    inc     word [search_dir_sector]
    mov     word [search_dir_index], 0
    jmp     ff_search_loop

.ff_found:
    ; Found a match! Populate DTA
    ; Get DTA address
    push    ds
    mov     es, [current_dta_seg]
    mov     bx, [current_dta_off]

    ; Store search state in reserved area of DTA (first 21 bytes)
    ; Bytes 0-10: search pattern, 11: search attr, 12-13: dir sector, 14-15: dir index
    push    di
    push    cs
    pop     ds
    mov     si, search_name
    mov     di, bx
    mov     cx, 11
    rep     movsb
    mov     al, [search_attr]
    stosb
    mov     ax, [search_dir_sector]
    stosw
    mov     ax, [search_dir_index]
    stosw
    ; Fill remaining reserved bytes
    mov     cx, 6
    xor     al, al
    rep     stosb
    pop     di
    pop     ds                      ; DS = kernel seg

    ; Copy file info to DTA
    ; DTA+21: attribute
    mov     al, [di + 11]
    mov     [es:bx + 21], al

    ; DTA+22-23: time
    mov     ax, [di + 22]
    mov     [es:bx + 22], ax

    ; DTA+24-25: date
    mov     ax, [di + 24]
    mov     [es:bx + 24], ax

    ; DTA+26-29: file size
    mov     ax, [di + 28]
    mov     [es:bx + 26], ax
    mov     ax, [di + 30]
    mov     [es:bx + 28], ax

    ; DTA+30-42: filename as ASCIIZ
    push    di
    lea     si, [di]                ; SI = dir entry name (11 bytes)
    lea     di, [bx + 30]           ; ES:DI = DTA filename field
    call    ff_fcb_to_asciiz
    pop     di

    ; Advance index for next FindNext call
    inc     word [search_dir_index]

    ; Success
    pop     bx
    pop     di
    pop     si
    pop     es
    call    dos_clear_error
    ret

.ff_no_more:
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_NO_MORE_FILES
    jmp     dos_set_error

.ff_error:
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_READ_FAULT
    jmp     dos_set_error

; ---------------------------------------------------------------------------
; ff_name_to_pattern - Convert ASCIIZ filespec to FCB pattern with wildcards
; Input: DS:SI = ASCIIZ path (possibly with wildcards)
; Output: search_name filled with 11-byte pattern
; ---------------------------------------------------------------------------
ff_name_to_pattern:
    pusha

    ; Find the filename part (after last \ or :)
    mov     di, si
.ff_scan:
    lodsb
    test    al, al
    jz      .ff_found_start
    cmp     al, '\'
    je      .ff_update_start
    cmp     al, ':'
    jne     .ff_scan
.ff_update_start:
    mov     di, si                  ; DI = start of name after \ or :
    jmp     .ff_scan
.ff_found_start:
    mov     si, di                  ; SI = filename portion

    ; Fill search_name with spaces
    mov     di, search_name
    push    di
    mov     cx, 11
    mov     al, ' '
    rep     stosb
    pop     di

    ; Copy name part (up to 8 chars or until . or end)
    mov     cx, 8
.ff_name_loop:
    lodsb
    test    al, al
    jz      .ff_done
    cmp     al, '.'
    je      .ff_do_ext
    cmp     al, '*'
    je      .ff_star_name
    ; Convert to uppercase
    cmp     al, 'a'
    jb      .ff_store_name
    cmp     al, 'z'
    ja      .ff_store_name
    sub     al, 0x20
.ff_store_name:
    stosb
    loop    .ff_name_loop
    ; Skip remaining name chars until . or end
.ff_skip_name:
    lodsb
    test    al, al
    jz      .ff_done
    cmp     al, '.'
    jne     .ff_skip_name

.ff_do_ext:
    ; Copy extension
    mov     di, search_name + 8
    mov     cx, 3
.ff_ext_loop:
    lodsb
    test    al, al
    jz      .ff_done
    cmp     al, '*'
    je      .ff_star_ext
    cmp     al, 'a'
    jb      .ff_store_ext
    cmp     al, 'z'
    ja      .ff_store_ext
    sub     al, 0x20
.ff_store_ext:
    stosb
    loop    .ff_ext_loop
    jmp     .ff_done

.ff_star_name:
    ; Fill remaining name with ?
    mov     al, '?'
    rep     stosb
    ; Check for extension
.ff_star_skip:
    lodsb
    test    al, al
    jz      .ff_done
    cmp     al, '.'
    jne     .ff_star_skip
    jmp     .ff_do_ext

.ff_star_ext:
    ; Fill remaining extension with ?
    mov     al, '?'
    rep     stosb

.ff_done:
    popa
    ret

; ---------------------------------------------------------------------------
; ff_fcb_to_asciiz - Convert 11-byte FCB name to ASCIIZ
; Input: DS:SI = 11-byte FCB name, ES:DI = output buffer (13 bytes)
; ---------------------------------------------------------------------------
ff_fcb_to_asciiz:
    push    ax
    push    cx
    push    si
    push    di

    ; Copy name (8 chars, strip trailing spaces)
    mov     cx, 8
.fcb_name:
    lodsb
    cmp     al, ' '
    je      .fcb_name_done
    stosb
    loop    .fcb_name
    jmp     .fcb_check_ext

.fcb_name_done:
    ; Skip remaining name spaces
    add     si, cx
    dec     si                      ; SI now points to extension

.fcb_check_ext:
    ; Check if extension is all spaces
    cmp     byte [si], ' '
    je      .fcb_null_term

    ; Add dot and extension
    mov     al, '.'
    stosb
    mov     cx, 3
.fcb_ext:
    lodsb
    cmp     al, ' '
    je      .fcb_null_term
    stosb
    loop    .fcb_ext

.fcb_null_term:
    xor     al, al
    stosb

    pop     di
    pop     si
    pop     cx
    pop     ax
    ret
