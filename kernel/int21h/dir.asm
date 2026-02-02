; ===========================================================================
; claudeDOS INT 21h Directory Functions - Stubs (Phase 3/7)
; ===========================================================================

; AH=39h - Create directory
; Input: DS:DX = ASCIIZ directory name
int21_39:
    push    es
    push    si
    push    di
    push    bx
    push    cx
    push    dx

    ; Copy path from caller's DS:DX to path_buffer
    push    ds
    mov     ds, [cs:save_ds]
    mov     si, [cs:save_dx]
    push    cs
    pop     es
    mov     di, path_buffer
    mov     cx, 127
.mkdir_copy:
    lodsb
    stosb
    test    al, al
    jz      .mkdir_copied
    loop    .mkdir_copy
    mov     byte [es:di], 0
.mkdir_copied:
    pop     ds                      ; DS = kernel seg

    ; Resolve path to get parent directory cluster and directory name
    mov     si, path_buffer
    call    resolve_path
    jc      .mkdir_path_error

    ; AX = parent directory cluster, fcb_name_buffer = new dir name
    mov     [.mkdir_parent_cluster], ax

    ; Check if directory already exists
    push    ax
    mov     si, fcb_name_buffer
    call    fat_find_in_directory
    pop     ax
    jnc     .mkdir_exists           ; Already exists - error

    ; Find empty slot in parent directory
    mov     ax, [.mkdir_parent_cluster]
    test    ax, ax
    jnz     .mkdir_scan_subdir

    ; Parent is root directory - scan sectors 19-32
    mov     ax, 19
    mov     cx, 14
.mkdir_scan_root:
    push    cx
    push    ax
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_read_sector
    jc      .mkdir_read_error_pop2

    mov     di, disk_buffer
    xor     cx, cx
.mkdir_scan_root_entry:
    cmp     cx, 16
    jae     .mkdir_next_root_sector
    cmp     byte [di], 0x00
    je      .mkdir_found_root_slot
    cmp     byte [di], 0xE5
    je      .mkdir_found_root_slot
    add     di, 32
    inc     cx
    jmp     .mkdir_scan_root_entry

.mkdir_next_root_sector:
    pop     ax
    pop     cx
    inc     ax
    loop    .mkdir_scan_root
    jmp     .mkdir_dir_full

.mkdir_found_root_slot:
    pop     ax                      ; Sector number
    mov     [.mkdir_dir_sector], ax
    mov     [.mkdir_dir_index], cx
    pop     cx
    jmp     .mkdir_create_entry

.mkdir_scan_subdir:
    mov     dx, ax                  ; DX = current cluster
.mkdir_subdir_loop:
    mov     ax, dx
    call    fat_cluster_to_lba
    push    dx
    push    ax
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_read_sector
    pop     ax
    pop     dx
    jc      .mkdir_read_error

    mov     di, disk_buffer
    xor     cx, cx
.mkdir_subdir_entry:
    cmp     cx, 16
    jae     .mkdir_next_subdir_cluster
    cmp     byte [di], 0x00
    je      .mkdir_found_subdir_slot
    cmp     byte [di], 0xE5
    je      .mkdir_found_subdir_slot
    add     di, 32
    inc     cx
    jmp     .mkdir_subdir_entry

.mkdir_next_subdir_cluster:
    mov     ax, dx
    call    fat_get_next_cluster
    mov     dx, ax
    cmp     dx, 0x0FF8
    jb      .mkdir_subdir_loop
    jmp     .mkdir_dir_full

.mkdir_found_subdir_slot:
    mov     ax, dx
    call    fat_cluster_to_lba
    mov     [.mkdir_dir_sector], ax
    mov     [.mkdir_dir_index], cx

.mkdir_create_entry:
    ; Allocate a cluster for the new directory
    call    fat_alloc_cluster
    jc      .mkdir_disk_full
    mov     [.mkdir_new_cluster], ax

    ; Initialize the directory entry at DI
    ; Copy name
    push    di
    mov     si, fcb_name_buffer
    mov     cx, 11
    rep     movsb
    pop     di

    ; Set attribute = directory
    mov     byte [di + 11], ATTR_DIRECTORY

    ; Zero reserved fields
    xor     ax, ax
    mov     [di + 12], ax
    mov     [di + 14], ax
    mov     [di + 16], ax
    mov     [di + 18], ax
    mov     [di + 20], ax
    mov     [di + 22], ax           ; Time
    mov     [di + 24], ax           ; Date

    ; Set first cluster
    mov     ax, [.mkdir_new_cluster]
    mov     [di + 26], ax

    ; Directory size = 0 (by convention)
    xor     ax, ax
    mov     [di + 28], ax
    mov     [di + 30], ax

    ; Write parent directory sector back
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [.mkdir_dir_sector]
    call    fat_write_sector
    jc      .mkdir_write_error

    ; Initialize the new directory's cluster with . and .. entries
    ; First, zero out the cluster
    push    cs
    pop     es
    mov     di, disk_buffer
    mov     cx, 256
    xor     ax, ax
    rep     stosw

    ; Create "." entry (points to self)
    mov     di, disk_buffer
    mov     byte [di], '.'
    mov     cx, 10
    mov     al, ' '
    push    di
    inc     di
.mkdir_fill_dot:
    mov     [di], al
    inc     di
    loop    .mkdir_fill_dot
    pop     di
    mov     byte [di + 11], ATTR_DIRECTORY
    mov     ax, [.mkdir_new_cluster]
    mov     [di + 26], ax

    ; Create ".." entry (points to parent)
    mov     di, disk_buffer + 32
    mov     byte [di], '.'
    mov     byte [di + 1], '.'
    mov     cx, 9
    mov     al, ' '
    push    di
    add     di, 2
.mkdir_fill_dotdot:
    mov     [di], al
    inc     di
    loop    .mkdir_fill_dotdot
    pop     di
    mov     byte [di + 11], ATTR_DIRECTORY
    mov     ax, [.mkdir_parent_cluster]
    mov     [di + 26], ax

    ; Write the new directory's cluster
    mov     ax, [.mkdir_new_cluster]
    call    fat_cluster_to_lba
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_write_sector
    jc      .mkdir_write_error

    ; Success
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    call    dos_clear_error
    ret

.mkdir_exists:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_ACCESS_DENIED
    jmp     dos_set_error

.mkdir_path_error:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_PATH_NOT_FOUND
    jmp     dos_set_error

.mkdir_read_error_pop2:
    pop     ax
    pop     cx
.mkdir_read_error:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_ACCESS_DENIED
    jmp     dos_set_error

.mkdir_dir_full:
.mkdir_disk_full:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_CANNOT_MAKE
    jmp     dos_set_error

.mkdir_write_error:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_WRITE_FAULT
    jmp     dos_set_error

; Local variables for mkdir
.mkdir_parent_cluster   dw  0
.mkdir_new_cluster      dw  0
.mkdir_dir_sector       dw  0
.mkdir_dir_index        dw  0

; AH=3Ah - Remove directory
; Input: DS:DX = ASCIIZ directory name
int21_3A:
    push    es
    push    si
    push    di
    push    bx
    push    cx
    push    dx

    ; Copy path from caller's DS:DX to path_buffer
    push    ds
    mov     ds, [cs:save_ds]
    mov     si, [cs:save_dx]
    push    cs
    pop     es
    mov     di, path_buffer
    mov     cx, 127
.rmdir_copy:
    lodsb
    stosb
    test    al, al
    jz      .rmdir_copied
    loop    .rmdir_copy
    mov     byte [es:di], 0
.rmdir_copied:
    pop     ds                      ; DS = kernel seg

    ; Resolve path to get parent directory cluster and directory name
    mov     si, path_buffer
    call    resolve_path
    jc      .rmdir_path_error

    ; AX = parent directory cluster, fcb_name_buffer = directory name
    mov     [.rmdir_parent_cluster], ax

    ; Find the directory in parent
    mov     si, fcb_name_buffer
    call    fat_find_in_directory
    jc      .rmdir_not_found

    ; DI = directory entry, AX = sector number
    mov     [.rmdir_entry_sector], ax

    ; Check if it's a directory
    test    byte [di + 11], ATTR_DIRECTORY
    jz      .rmdir_not_dir

    ; Get directory's first cluster
    mov     ax, [di + 26]
    mov     [.rmdir_dir_cluster], ax

    ; Calculate entry index within sector
    push    ax
    mov     ax, di
    sub     ax, disk_buffer
    shr     ax, 5                   ; / 32 = entry index
    mov     [.rmdir_entry_index], ax
    pop     ax

    ; Check if directory is empty (only . and .. allowed)
    ; Read the directory's first sector
    mov     ax, [.rmdir_dir_cluster]
    test    ax, ax
    jz      .rmdir_access_denied    ; Can't remove root
    cmp     ax, 2
    jb      .rmdir_access_denied    ; Invalid cluster

    call    fat_cluster_to_lba
    jc      .rmdir_access_denied
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_read_sector
    jc      .rmdir_read_error

    ; Check entries - first two should be . and .., rest should be empty/deleted
    mov     di, disk_buffer
    mov     cx, 16                  ; Entries per sector

.rmdir_check_entry:
    ; First entry should be "."
    cmp     cx, 16
    jne     .rmdir_check_dotdot
    cmp     byte [di], '.'
    jne     .rmdir_not_empty
    jmp     .rmdir_next_check

.rmdir_check_dotdot:
    ; Second entry should be ".."
    cmp     cx, 15
    jne     .rmdir_check_empty
    cmp     byte [di], '.'
    jne     .rmdir_not_empty
    cmp     byte [di + 1], '.'
    jne     .rmdir_not_empty
    jmp     .rmdir_next_check

.rmdir_check_empty:
    ; All other entries must be empty (0x00) or deleted (0xE5)
    cmp     byte [di], 0x00
    je      .rmdir_is_empty         ; End of directory - it's empty
    cmp     byte [di], 0xE5
    jne     .rmdir_not_empty

.rmdir_next_check:
    add     di, 32
    dec     cx
    jnz     .rmdir_check_entry

    ; Need to check next cluster if exists
    mov     ax, [.rmdir_dir_cluster]
    call    fat_get_next_cluster
    cmp     ax, 0x0FF8
    jae     .rmdir_is_empty         ; No more clusters - directory is empty

    ; More clusters to check - they should all be empty
    mov     [.rmdir_dir_cluster], ax
    call    fat_cluster_to_lba
    jc      .rmdir_is_empty         ; Error reading - assume empty for now
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_read_sector
    jc      .rmdir_read_error

    mov     di, disk_buffer
    mov     cx, 16
.rmdir_check_more:
    cmp     byte [di], 0x00
    je      .rmdir_is_empty
    cmp     byte [di], 0xE5
    jne     .rmdir_not_empty
    add     di, 32
    loop    .rmdir_check_more
    ; If we get here, all entries were deleted - it's effectively empty
    ; (In a full implementation, we'd check all clusters in chain)

.rmdir_is_empty:
    ; Directory is empty - proceed with removal

    ; Re-read the parent directory sector to get the entry
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [.rmdir_entry_sector]
    call    fat_read_sector
    jc      .rmdir_read_error

    ; Calculate entry pointer
    mov     ax, [.rmdir_entry_index]
    shl     ax, 5                   ; * 32
    mov     di, disk_buffer
    add     di, ax

    ; Save first cluster for freeing
    mov     ax, [di + 26]
    push    ax

    ; Mark entry as deleted
    mov     byte [di], 0xE5

    ; Write parent directory sector back
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [.rmdir_entry_sector]
    call    fat_write_sector
    pop     ax                      ; First cluster
    jc      .rmdir_write_error

    ; Free the directory's cluster chain
    test    ax, ax
    jz      .rmdir_success
    cmp     ax, 2
    jb      .rmdir_success
    call    fat_free_chain

.rmdir_success:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    call    dos_clear_error
    ret

.rmdir_path_error:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_PATH_NOT_FOUND
    jmp     dos_set_error

.rmdir_not_found:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_PATH_NOT_FOUND
    jmp     dos_set_error

.rmdir_not_dir:
.rmdir_access_denied:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_ACCESS_DENIED
    jmp     dos_set_error

.rmdir_not_empty:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_DIR_NOT_EMPTY
    jmp     dos_set_error

.rmdir_read_error:
.rmdir_write_error:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_ACCESS_DENIED
    jmp     dos_set_error

; Local variables for rmdir
.rmdir_parent_cluster   dw  0
.rmdir_dir_cluster      dw  0
.rmdir_entry_sector     dw  0
.rmdir_entry_index      dw  0

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
    call    fat_get_next_cluster
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
