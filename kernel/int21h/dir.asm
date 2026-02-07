; ===========================================================================
; claudeDOS INT 21h Directory Functions - Stubs (Phase 3/7)
; ===========================================================================

; ---------------------------------------------------------------------------
; CDS Helper Functions - Per-drive current directory management
; ---------------------------------------------------------------------------

; cds_get_entry - Get CDS entry pointer for a drive
; Input: AL = drive number (0=A:, 2=C:, etc.)
; Output: DI = pointer to CDS entry, CF=0 valid / CF=1 invalid
cds_get_entry:
    push    ax
    push    dx
    cmp     al, LASTDRIVE
    jae     .cds_invalid
    xor     ah, ah
    mov     dx, CDS_SIZE
    mul     dx                      ; AX = drive * CDS_SIZE
    mov     di, cds_table
    add     di, ax
    test    word [di + CDS.flags], CDS_VALID
    jz      .cds_invalid
    pop     dx
    pop     ax
    clc
    ret
.cds_invalid:
    pop     dx
    pop     ax
    stc
    ret

; cds_save_current - Save current_dir_cluster/path to current drive's CDS
cds_save_current:
    push    ax
    push    cx
    push    si
    push    di
    mov     al, [current_drive]
    call    cds_get_entry
    jc      .csave_done
    ; Save start_cluster
    mov     ax, [current_dir_cluster]
    mov     [di + CDS.start_cluster], ax
    ; Update CDS path after "X:\" (offset 3)
    push    di
    add     di, 3
    mov     si, current_dir_path
    mov     cx, 63
.csave_path:
    lodsb
    mov     [di], al
    inc     di
    test    al, al
    jz      .csave_path_done
    loop    .csave_path
    mov     byte [di], 0
.csave_path_done:
    pop     di
.csave_done:
    pop     di
    pop     si
    pop     cx
    pop     ax
    ret

; cds_load_drive_current - Load CWD from current drive's CDS into globals
cds_load_drive_current:
    push    ax
    push    cx
    push    si
    push    di
    mov     al, [current_drive]
    call    cds_get_entry
    jc      .cload_root
    ; Load start_cluster
    mov     ax, [di + CDS.start_cluster]
    mov     [current_dir_cluster], ax
    ; Load path: CDS.path[3:] -> current_dir_path
    mov     si, di
    add     si, 3
    mov     di, current_dir_path
    mov     cx, 63
.cload_path:
    lodsb
    stosb
    test    al, al
    jz      .cload_done
    loop    .cload_path
    mov     byte [di], 0
    jmp     .cload_done
.cload_root:
    mov     word [current_dir_cluster], 0
    mov     byte [current_dir_path], 0
.cload_done:
    pop     di
    pop     si
    pop     cx
    pop     ax
    ret

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

    ; Parent is root directory - scan from DPB
    call    fat_get_root_params ; AX = root_start, CX = root_sectors
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
    mov     [.mkdir_sub_sector], ax
    jc      .mkdir_read_error
    push    bx
    mov     bx, [active_dpb]
    xor     ah, ah
    mov     al, [bx + DPB_SEC_PER_CLUS]
    inc     ax
    mov     [.mkdir_sub_secs], ax
    pop     bx

.mkdir_sub_next_sec:
    cmp     word [.mkdir_sub_secs], 0
    jbe     .mkdir_next_subdir_cluster

    mov     ax, [.mkdir_sub_sector]
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_read_sector
    jc      .mkdir_read_error

    mov     di, disk_buffer
    xor     cx, cx
.mkdir_subdir_entry:
    cmp     cx, 16
    jae     .mkdir_sub_try_next
    cmp     byte [di], 0x00
    je      .mkdir_found_subdir_slot
    cmp     byte [di], 0xE5
    je      .mkdir_found_subdir_slot
    add     di, 32
    inc     cx
    jmp     .mkdir_subdir_entry

.mkdir_sub_try_next:
    dec     word [.mkdir_sub_secs]
    inc     word [.mkdir_sub_sector]
    jmp     .mkdir_sub_next_sec

.mkdir_next_subdir_cluster:
    mov     ax, dx
    call    fat_get_next_cluster
    mov     dx, ax
    cmp     dx, [fat_eoc_min]
    jb      .mkdir_subdir_loop
    jmp     .mkdir_dir_full

.mkdir_found_subdir_slot:
    mov     ax, [.mkdir_sub_sector]
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
    ; Get first LBA and sector count for the new cluster
    mov     ax, [.mkdir_new_cluster]
    call    fat_cluster_to_lba
    jc      .mkdir_write_error
    mov     [.mkdir_sub_sector], ax
    push    bx
    mov     bx, [active_dpb]
    xor     ah, ah
    mov     al, [bx + DPB_SEC_PER_CLUS]
    inc     ax
    mov     [.mkdir_sub_secs], ax
    pop     bx

    ; Zero out the buffer
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

    ; Write first sector (with . and .. entries)
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [.mkdir_sub_sector]
    call    fat_write_sector
    jc      .mkdir_write_error

    ; Write remaining sectors as zeroed
    dec     word [.mkdir_sub_secs]
    jz      .mkdir_init_done
    ; Re-zero disk_buffer (. and .. entries only in first sector)
    mov     di, disk_buffer
    mov     cx, 256
    xor     ax, ax
    rep     stosw
.mkdir_zero_loop:
    inc     word [.mkdir_sub_sector]
    mov     ax, [.mkdir_sub_sector]
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_write_sector
    jc      .mkdir_write_error
    dec     word [.mkdir_sub_secs]
    jnz     .mkdir_zero_loop
.mkdir_init_done:

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
.mkdir_sub_sector       dw  0
.mkdir_sub_secs         dw  0

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

    ; Walk the directory's cluster chain checking for non-empty entries
    mov     byte [.rmdir_first_sec], 1  ; Flag: first sector has . and ..

.rmdir_check_cluster:
    mov     ax, [.rmdir_dir_cluster]
    call    fat_cluster_to_lba
    jc      .rmdir_access_denied
    mov     [.rmdir_cur_sector], ax
    push    bx
    mov     bx, [active_dpb]
    xor     ah, ah
    mov     al, [bx + DPB_SEC_PER_CLUS]
    inc     ax
    mov     [.rmdir_secs_left], ax
    pop     bx

.rmdir_check_next_sec:
    cmp     word [.rmdir_secs_left], 0
    jbe     .rmdir_next_dir_cluster

    mov     ax, [.rmdir_cur_sector]
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_read_sector
    jc      .rmdir_read_error

    mov     di, disk_buffer
    mov     cx, 16                  ; Entries per sector

    ; Skip . and .. on first sector
    cmp     byte [.rmdir_first_sec], 1
    jne     .rmdir_check_empty
    mov     byte [.rmdir_first_sec], 0
    ; Skip first 2 entries (. and ..)
    add     di, 64
    sub     cx, 2

.rmdir_check_empty:
    cmp     byte [di], 0x00
    je      .rmdir_is_empty         ; End of directory - it's empty
    cmp     byte [di], 0xE5
    jne     .rmdir_not_empty
    add     di, 32
    loop    .rmdir_check_empty

    ; All entries in this sector are deleted - try next sector
    dec     word [.rmdir_secs_left]
    inc     word [.rmdir_cur_sector]
    jmp     .rmdir_check_next_sec

.rmdir_next_dir_cluster:
    mov     ax, [.rmdir_dir_cluster]
    call    fat_get_next_cluster
    cmp     ax, [fat_eoc_min]
    jae     .rmdir_is_empty         ; No more clusters - directory is empty
    mov     [.rmdir_dir_cluster], ax
    jmp     .rmdir_check_cluster

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
.rmdir_cur_sector       dw  0
.rmdir_secs_left        dw  0
.rmdir_first_sec        db  0

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

    ; Determine target drive
    mov     si, path_buffer
    cmp     byte [si + 1], ':'
    jne     .cd_use_cur_drive
    mov     al, [si]
    cmp     al, 'a'
    jb      .cd_drv_upper
    cmp     al, 'z'
    ja      .cd_drv_upper
    sub     al, 0x20
.cd_drv_upper:
    sub     al, 'A'
    mov     [.cd_target_drive], al
    add     si, 2
    jmp     .cd_check_root

.cd_use_cur_drive:
    mov     al, [current_drive]
    mov     [.cd_target_drive], al

.cd_check_root:
    ; Check if it's just "\" (root)
    cmp     byte [si], '\'
    jne     .cd_not_root
    cmp     byte [si + 1], 0
    jne     .cd_not_root
    ; Change to root directory
    xor     ax, ax                  ; Cluster 0 = root
    jmp     .cd_update_state

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

.cd_update_state:
    ; AX = target directory cluster
    ; Check if updating current drive or a different drive
    mov     bl, [.cd_target_drive]
    cmp     bl, [current_drive]
    jne     .cd_other_drive

    ; Same drive - update globals
    mov     [current_dir_cluster], ax

    ; Update current_dir_path (strip drive letter and leading \)
    mov     si, path_buffer
    cmp     byte [si + 1], ':'
    jne     .cd_strip
    add     si, 2
.cd_strip:
    cmp     byte [si], '\'
    jne     .cd_copy_path
    inc     si
.cd_copy_path:
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
    ; Also sync to CDS
    call    cds_save_current
    jmp     .cd_success

.cd_other_drive:
    ; Different drive - update only that drive's CDS
    mov     al, bl
    call    cds_get_entry
    jc      .cd_not_found
    ; DI = CDS entry pointer
    mov     [di + CDS.start_cluster], ax
    ; Update CDS path after "X:\" (offset 3)
    push    di
    add     di, 3
    mov     si, path_buffer
    cmp     byte [si + 1], ':'
    jne     .cd_o_strip
    add     si, 2
.cd_o_strip:
    cmp     byte [si], '\'
    jne     .cd_o_copy
    inc     si
.cd_o_copy:
    mov     cx, 63
.cd_o_loop:
    lodsb
    mov     [di], al
    inc     di
    test    al, al
    jz      .cd_o_done
    loop    .cd_o_loop
    mov     byte [di], 0
.cd_o_done:
    pop     di

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

; Local variable
.cd_target_drive    db  0

; AH=47h - Get current directory
; Input: DL = drive (0=default), DS:SI = 64-byte buffer
; Output: DS:SI = ASCIIZ path (without leading backslash)
int21_47:
    push    es
    push    di
    push    si

    ; Determine target drive
    mov     al, [save_dx]           ; DL
    test    al, al
    jz      .getcwd_use_default
    dec     al                      ; Convert 1-based to 0-based
    jmp     .getcwd_have_drive
.getcwd_use_default:
    mov     al, [current_drive]
.getcwd_have_drive:
    ; AL = drive number (0-based)
    cmp     al, [current_drive]
    jne     .getcwd_from_cds

    ; Current drive - copy from globals
    mov     es, [save_ds]
    mov     di, [save_si]
    mov     si, current_dir_path
    mov     cx, 63
.getcwd_loop:
    lodsb
    mov     [es:di], al
    inc     di
    test    al, al
    jz      .getcwd_ok
    loop    .getcwd_loop
    mov     byte [es:di], 0
    jmp     .getcwd_ok

.getcwd_from_cds:
    ; Different drive - read from CDS
    call    cds_get_entry
    jc      .getcwd_invalid
    ; DI = CDS entry pointer; read path after "X:\" (offset 3)
    mov     si, di
    add     si, 3
    mov     es, [save_ds]
    mov     di, [save_si]
    mov     cx, 63
.getcwd_cds_loop:
    lodsb
    mov     [es:di], al
    inc     di
    test    al, al
    jz      .getcwd_ok
    loop    .getcwd_cds_loop
    mov     byte [es:di], 0

.getcwd_ok:
    pop     si
    pop     di
    pop     es
    call    dos_clear_error
    ret

.getcwd_invalid:
    pop     si
    pop     di
    pop     es
    mov     ax, ERR_INVALID_DRIVE
    jmp     dos_set_error

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
    ; Save which drive this search is on
    mov     bl, [active_drive_num]
    mov     [search_drive], bl
    jmp     .ff_setup_search

.ff_use_current:
    ; Use current directory
    mov     ax, [current_dir_cluster]
    mov     [search_dir_cluster], ax
    ; Save current drive for search
    mov     bl, [active_drive_num]
    mov     [search_drive], bl
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

    ; Root directory: start at root_start, entry 0
    push    cx
    call    fat_get_root_params     ; AX = root_start, CX = root_sectors
    mov     [search_dir_sector], ax
    add     ax, cx                  ; AX = root_start + root_sectors = end sector
    mov     [ff_root_end], ax
    pop     cx
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
    ; Get search drive (BIOS drive number, byte 18)
    lodsb
    mov     [cs:search_drive], al
    pop     ds                      ; DS = kernel seg

    ; Switch to the correct drive for this search
    ; Convert BIOS drive number to logical: 0->0(A:), 0x80->2(C:)
    mov     al, [search_drive]
    cmp     al, 0x80
    jne     .fn_not_hd
    mov     al, 2                   ; C:
    jmp     .fn_set_drive
.fn_not_hd:
    ; AL already = 0 for A:, 3 for D: etc.
.fn_set_drive:
    call    fat_set_active_drive

ff_search_loop:
    ; Check if searching root or subdirectory
    mov     ax, [search_dir_cluster]
    test    ax, ax
    jnz     .ff_subdir_loop

    ; Root directory: check if exhausted
    mov     ax, [search_dir_sector]
    cmp     ax, [ff_root_end]
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
    cmp     ax, [fat_eoc_min]       ; End of chain?
    jae     .ff_no_more

    ; Convert cluster to first sector
    call    fat_cluster_to_lba
    jc      .ff_error
    mov     [search_dir_sector], ax ; Save first LBA of cluster
    ; Get sectors per cluster
    push    bx
    mov     bx, [active_dpb]
    xor     ah, ah
    mov     al, [bx + DPB_SEC_PER_CLUS]
    inc     ax
    mov     [ff_sub_secs], ax
    pop     bx

.ff_sub_next_sec:
    cmp     word [ff_sub_secs], 0
    jbe     .ff_next_cluster
    mov     ax, [search_dir_sector]
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
    ; Subdirectory: try next sector within cluster first
    dec     word [ff_sub_secs]
    jz      .ff_advance_cluster
    inc     word [search_dir_sector]
    mov     word [search_dir_index], 0
    jmp     .ff_sub_next_sec

.ff_advance_cluster:
    ; All sectors in cluster done - advance to next cluster in chain
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
    ; Byte 18: search drive (BIOS drive number)
    mov     al, [search_drive]
    stosb
    ; Fill remaining reserved bytes
    mov     cx, 3
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

; Local variables for FindFirst/FindNext
ff_root_end     dw  33              ; Default: 19 + 14 = 33 for FAT12 floppy
ff_sub_secs     dw  0              ; Sectors remaining in current cluster

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
