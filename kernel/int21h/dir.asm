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
; Input: DS:DX = ASCIIZ path
int21_3B:
    push    es
    push    si
    push    di
    push    bx

    ; Copy path from caller's DS:DX to path_buffer
    push    ds
    mov     ds, [cs:save_ds]
    mov     si, [cs:save_dx]
    push    cs
    pop     es
    mov     di, path_buffer
    mov     cx, 127
.cd_copy:
    lodsb
    stosb
    test    al, al
    jz      .cd_copied
    loop    .cd_copy
    mov     byte [es:di], 0
.cd_copied:
    pop     ds                      ; DS = kernel seg

    ; Check for root directory special case
    mov     si, path_buffer
    ; Skip drive letter if present
    cmp     byte [si + 1], ':'
    jne     .cd_no_drive
    add     si, 2
.cd_no_drive:
    ; Check if it's just "\" (root)
    cmp     byte [si], '\'
    jne     .cd_not_root
    cmp     byte [si + 1], 0
    jne     .cd_not_root
    ; Change to root directory
    mov     word [current_dir_cluster], 0
    mov     byte [current_dir_path], 0
    jmp     .cd_success
.cd_not_root:

    ; Resolve the path to find the target directory
    mov     si, path_buffer
    call    resolve_path
    jc      .cd_not_found

    ; AX = parent directory cluster, fcb_name_buffer = directory name
    ; Search for the directory in its parent
    push    ax                      ; Save parent cluster
    mov     si, fcb_name_buffer
    call    fat_find_in_directory
    pop     bx                      ; BX = parent cluster (not needed)
    jc      .cd_not_found

    ; DI = directory entry pointer
    ; Check if it's a directory
    test    byte [di + 11], ATTR_DIRECTORY
    jz      .cd_not_found           ; Not a directory

    ; Get the directory's cluster
    mov     ax, [di + 26]           ; First cluster

    ; Update current directory state
    mov     [current_dir_cluster], ax

    ; Update current_dir_path
    ; For simplicity, just copy the path (stripping drive letter)
    mov     si, path_buffer
    cmp     byte [si + 1], ':'
    jne     .cd_copy_path
    add     si, 2
.cd_copy_path:
    ; Skip leading backslash
    cmp     byte [si], '\'
    jne     .cd_copy_path2
    inc     si
.cd_copy_path2:
    mov     di, current_dir_path
    mov     cx, 63
.cd_path_loop:
    lodsb
    stosb
    test    al, al
    jz      .cd_path_done
    loop    .cd_path_loop
    mov     byte [di], 0
.cd_path_done:

.cd_success:
    pop     bx
    pop     di
    pop     si
    pop     es
    call    dos_clear_error
    ret

.cd_not_found:
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_PATH_NOT_FOUND
    jmp     dos_set_error

; AH=47h - Get current directory
; Input: DL = drive (0=default), DS:SI = 64-byte buffer
; Output: DS:SI = ASCIIZ path (without leading backslash)
int21_47:
    push    es
    push    di
    push    si

    ; Copy current_dir_path to caller's buffer
    mov     es, [save_ds]
    mov     di, [save_si]
    mov     si, current_dir_path
    mov     cx, 63
.getcwd_loop:
    lodsb
    stosb
    test    al, al
    jz      .getcwd_done
    loop    .getcwd_loop
    mov     byte [es:di], 0
.getcwd_done:

    pop     si
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

    ; Resolve path to get directory cluster
    mov     si, path_buffer
    call    resolve_path
    jc      .ff_use_current         ; If path doesn't resolve, try as pattern in current dir

    ; AX = directory cluster to search
    mov     [search_dir_cluster], ax
    jmp     .ff_setup_search

.ff_use_current:
    ; Use current directory
    mov     ax, [current_dir_cluster]
    mov     [search_dir_cluster], ax
    ; fcb_name_buffer might be wrong, re-convert from path_buffer
    mov     si, path_buffer
    call    ff_name_to_pattern
    jmp     .ff_do_search

.ff_setup_search:
    ; Convert final component (already in fcb_name_buffer) to search pattern
    ; We need to re-parse for wildcards since resolve_path doesn't handle them
    mov     si, path_buffer
    call    ff_name_to_pattern

.ff_do_search:
    ; Initialize search state based on directory type
    mov     ax, [search_dir_cluster]
    test    ax, ax
    jnz     .ff_subdir_search

    ; Root directory: start at sector 19, entry 0
    mov     word [search_dir_sector], 19
    mov     word [search_dir_index], 0
    mov     word [search_dir_cluster], 0
    jmp     ff_search_loop

.ff_subdir_search:
    ; Subdirectory: search_dir_cluster already set
    ; search_dir_sector will be computed from cluster
    ; search_dir_index = 0
    mov     word [search_dir_index], 0
    ; Fall through to search loop
    jmp     ff_search_loop

; AH=4Fh - Find next matching file
int21_4F:
    push    es
    push    si
    push    di
    push    bx

    ; Continue searching from saved state in DTA
    ; Restore search state from DTA
    push    ds
    mov     ds, [cs:current_dta_seg]
    mov     si, [cs:current_dta_off]
    ; Copy search pattern from DTA
    push    cs
    pop     es
    mov     di, search_name
    mov     cx, 11
    rep     movsb
    ; Get search_attr
    lodsb
    mov     [cs:search_attr], al
    ; Get search_dir_sector
    lodsw
    mov     [cs:search_dir_sector], ax
    ; Get search_dir_index
    lodsw
    mov     [cs:search_dir_index], ax
    ; Get search_dir_cluster
    lodsw
    mov     [cs:search_dir_cluster], ax
    pop     ds                      ; DS = kernel seg

ff_search_loop:
    ; Check if searching root or subdirectory
    mov     ax, [search_dir_cluster]
    test    ax, ax
    jnz     .ff_subdir_loop

    ; Root directory: check if exhausted (14 sectors, starting at 19)
    mov     ax, [search_dir_sector]
    cmp     ax, 33                  ; 19 + 14 = 33
    jae     .ff_no_more

    ; Read current root directory sector
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_read_sector
    jc      .ff_error
    jmp     .ff_process_sector

.ff_subdir_loop:
    ; Subdirectory: read cluster and search
    mov     ax, [search_dir_cluster]
    cmp     ax, 0x0FF8              ; End of chain?
    jae     .ff_no_more

    ; Convert cluster to sector and read
    call    fat_cluster_to_lba
    mov     [search_dir_sector], ax ; Save sector for DTA
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_read_sector
    jc      .ff_error

.ff_process_sector:
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
    ; Check if root or subdirectory
    mov     ax, [search_dir_cluster]
    test    ax, ax
    jnz     .ff_next_cluster

    ; Root directory: advance to next sector
    inc     word [search_dir_sector]
    mov     word [search_dir_index], 0
    jmp     ff_search_loop

.ff_next_cluster:
    ; Subdirectory: advance to next cluster in chain
    mov     ax, [search_dir_cluster]
    call    fat12_get_next_cluster
    mov     [search_dir_cluster], ax
    mov     word [search_dir_index], 0
    jmp     ff_search_loop

.ff_found:
    ; Found a match! Populate DTA
    ; Advance index FIRST for next FindNext call
    inc     word [search_dir_index]

    ; Get DTA address
    push    ds
    mov     es, [current_dta_seg]
    mov     bx, [current_dta_off]

    ; Store search state in reserved area of DTA (first 21 bytes)
    ; Bytes 0-10: search pattern, 11: search attr, 12-13: dir sector,
    ; 14-15: dir index (already incremented), 16-17: dir cluster, 18-20: reserved
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
    mov     ax, [search_dir_cluster]
    stosw
    ; Fill remaining reserved bytes
    mov     cx, 4
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

    ; Success (index already incremented at start of .ff_found)
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
