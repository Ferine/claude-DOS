; ===========================================================================
; claudeDOS FAT Common - Sector I/O, cluster/LBA conversion, path resolution
; ===========================================================================

; ---------------------------------------------------------------------------
; fat_read_sector - Read one sector from disk with retry
; Input: AX = LBA sector number, ES:BX = buffer
; Uses boot_drive from kernel data
; ---------------------------------------------------------------------------
DISK_RETRY_COUNT    equ     3           ; Number of retries for disk I/O

fat_read_sector:
    pusha
    mov     [.read_lba], ax             ; Save LBA for retries
    mov     byte [.read_retries], DISK_RETRY_COUNT

.read_retry:
    mov     ax, [.read_lba]
    ; LBA to CHS
    xor     dx, dx
    div     word [fat_spt]      ; AX = LBA/SPT, DX = LBA%SPT
    inc     dl
    mov     cl, dl              ; CL = sector (1-based)

    xor     dx, dx
    div     word [fat_heads]    ; AX = cylinder, DX = head
    mov     ch, al              ; CH = cylinder
    mov     dh, dl              ; DH = head

    mov     dl, [boot_drive]
    mov     ax, 0x0201          ; Read 1 sector
    int     0x13
    jnc     .read_ok

    ; Error - reset disk and retry
    xor     ax, ax
    int     0x13                ; Reset disk
    dec     byte [.read_retries]
    jnz     .read_retry

    ; All retries failed
    popa
    stc
    ret

.read_ok:
    popa
    clc
    ret

.read_lba       dw  0
.read_retries   db  0

; ---------------------------------------------------------------------------
; fat_write_sector - Write one sector to disk with retry
; Input: AX = LBA sector number, ES:BX = buffer
; ---------------------------------------------------------------------------
fat_write_sector:
    pusha
    mov     [.write_lba], ax            ; Save LBA for retries
    mov     byte [.write_retries], DISK_RETRY_COUNT

.write_retry:
    mov     ax, [.write_lba]
    ; LBA to CHS
    xor     dx, dx
    div     word [fat_spt]
    inc     dl
    mov     cl, dl

    xor     dx, dx
    div     word [fat_heads]
    mov     ch, al
    mov     dh, dl

    mov     dl, [boot_drive]
    mov     ax, 0x0301          ; Write 1 sector
    int     0x13
    jnc     .write_ok

    ; Error - reset disk and retry
    xor     ax, ax
    int     0x13                ; Reset disk
    dec     byte [.write_retries]
    jnz     .write_retry

    ; All retries failed
    popa
    stc
    ret

.write_ok:
    popa
    clc
    ret

.write_lba      dw  0
.write_retries  db  0

; ---------------------------------------------------------------------------
; fat_cluster_to_lba - Convert cluster number to LBA
; Input: AX = cluster number
; Output: AX = LBA sector number, CF set on invalid cluster
; ---------------------------------------------------------------------------
fat_cluster_to_lba:
    ; Validate cluster number
    cmp     ax, 2                   ; Clusters 0 and 1 are reserved
    jb      .invalid
    cmp     ax, [dpb_a.max_cluster] ; Check against maximum
    jae     .check_special

    ; Valid data cluster - convert to LBA
    sub     ax, 2
    add     ax, [dpb_a.data_start]  ; Use DPB data_start instead of hardcoded 33
    clc
    ret

.check_special:
    ; Check for end-of-chain markers (0xFF8-0xFFF for FAT12, 0xFFF8-0xFFFF for FAT16)
    cmp     ax, 0x0FF8
    jae     .end_of_chain
    ; Check for bad cluster marker (0xFF7 for FAT12, 0xFFF7 for FAT16)
    cmp     ax, 0x0FF7
    je      .bad_cluster
    cmp     ax, 0xFFF7
    je      .bad_cluster

.invalid:
.bad_cluster:
    stc                             ; Set carry flag for invalid cluster
    ret

.end_of_chain:
    ; End of chain is not really invalid, but can't be converted to LBA
    stc
    ret

; ---------------------------------------------------------------------------
; fat_read_cluster - Read one cluster into buffer
; Input: AX = cluster number, ES:BX = buffer
; ---------------------------------------------------------------------------
fat_read_cluster:
    push    ax
    call    fat_cluster_to_lba
    call    fat_read_sector
    pop     ax
    ret

; ---------------------------------------------------------------------------
; fat_name_to_fcb - Convert ASCIIZ filename to FCB 8.3 format
; Input: DS:SI = ASCIIZ filename (e.g. "FILE.TXT", "A:FILE.TXT", "A:\FILE.TXT")
; Output: fcb_name_buffer filled with 11-byte FCB name
; ---------------------------------------------------------------------------
fat_name_to_fcb:
    pusha
    push    es

    ; Set ES = DS (kernel segment) for stosb instructions
    push    ds
    pop     es

    ; Skip drive letter if present (e.g., "A:" or "A:\")
    cmp     byte [si + 1], ':'
    jne     .no_drive
    add     si, 2                   ; Skip "X:"
.no_drive:
    ; Skip leading slash if present (\ or /)
    cmp     byte [si], '\'
    je      .skip_slash
    cmp     byte [si], '/'
    jne     .no_slash
.skip_slash:
    inc     si
.no_slash:

    mov     di, fcb_name_buffer
    ; Fill with spaces
    push    di
    mov     cx, 11
    mov     al, ' '
    rep     stosb
    pop     di

    ; Copy name part (up to 8 chars)
    mov     cx, 8
.name_loop:
    lodsb
    test    al, al
    jz      .done
    cmp     al, '.'
    je      .do_ext
    ; Convert to uppercase
    cmp     al, 'a'
    jb      .store_name
    cmp     al, 'z'
    ja      .store_name
    sub     al, 0x20
.store_name:
    stosb
    loop    .name_loop
    ; Skip remaining name chars until dot or end
.skip_name:
    lodsb
    test    al, al
    jz      .done
    cmp     al, '.'
    jne     .skip_name
    
.do_ext:
    ; Copy extension (up to 3 chars)
    mov     di, fcb_name_buffer + 8
    mov     cx, 3
.ext_loop:
    lodsb
    test    al, al
    jz      .done
    cmp     al, 'a'
    jb      .store_ext
    cmp     al, 'z'
    ja      .store_ext
    sub     al, 0x20
.store_ext:
    stosb
    loop    .ext_loop
    
.done:
    pop     es
    popa
    ret

; ---------------------------------------------------------------------------
; fat_find_in_root - Search root directory for a file
; Input: DS:SI = FCB-format 11-byte name to find
; Output: CF=0 found (DI = offset into disk_buffer of entry,
;         dir entry sector in AX), CF=1 not found
; ---------------------------------------------------------------------------
fat_find_in_root:
    push    bx
    push    cx
    push    dx
    push    es

    ; Set ES = DS = kernel segment for cmpsb comparison
    push    ds
    pop     es

    ; Root directory starts at sector 19, 14 sectors
    mov     ax, 19              ; Root dir start
    mov     cx, 14              ; Root dir sectors

.next_sector:
    push    cx
    push    ax

    ; Read sector into disk_buffer
    mov     bx, disk_buffer
    call    fat_read_sector

    ; Search 16 entries per sector
    mov     di, disk_buffer
    mov     cx, 16

.check_entry:
    push    cx
    push    si
    push    di

    ; Check if entry is empty
    cmp     byte [di], 0x00     ; End of directory
    je      .not_found_pop
    cmp     byte [di], 0xE5     ; Deleted entry
    je      .next_entry_pop

    ; Compare 11 bytes (DS:SI vs ES:DI, both in kernel segment)
    mov     cx, 11
    repe    cmpsb
    pop     di
    pop     si
    pop     cx
    je      .found

    add     di, 32
    loop    .check_entry
    jmp     .next_sector_continue

.next_entry_pop:
    pop     di
    pop     si
    pop     cx
    add     di, 32
    loop    .check_entry

.next_sector_continue:
    pop     ax
    pop     cx
    inc     ax
    loop    .next_sector

    ; Not found
    stc
    pop     es
    pop     dx
    pop     cx
    pop     bx
    ret

.not_found_pop:
    pop     di
    pop     si
    pop     cx
    pop     ax
    pop     cx
    stc
    pop     es
    pop     dx
    pop     cx
    pop     bx
    ret

.found:
    pop     ax                  ; Sector number
    pop     cx
    clc
    pop     es
    pop     dx
    pop     cx
    pop     bx
    ret

; ---------------------------------------------------------------------------
; fat_find_in_directory - Search any directory (root or subdirectory) for a file
; Input: DS:SI = FCB-format 11-byte name to find
;        AX = starting cluster (0 = root directory)
; Output: CF=0 found (DI = offset into disk_buffer of entry,
;         AX = sector number), CF=1 not found
; ---------------------------------------------------------------------------
fat_find_in_directory:
    push    bx
    push    cx
    push    dx
    push    es

    ; Set ES = DS = kernel segment for cmpsb comparison
    push    ds
    pop     es

    ; Check if root directory or subdirectory
    test    ax, ax
    jz      .search_root

    ; Subdirectory: search cluster chain
    mov     dx, ax              ; DX = current cluster
.next_cluster:
    ; Read this cluster's sector
    push    dx
    mov     ax, dx
    call    fat_cluster_to_lba
    mov     bx, disk_buffer
    call    fat_read_sector
    pop     dx
    jc      .not_found

    ; Search 16 entries in this sector
    mov     di, disk_buffer
    mov     cx, 16

.check_subdir_entry:
    push    cx
    push    si
    push    di

    ; Check if entry is empty
    cmp     byte [di], 0x00     ; End of directory
    je      .not_found_pop_subdir
    cmp     byte [di], 0xE5     ; Deleted entry
    je      .next_subdir_entry_pop

    ; Compare 11 bytes
    mov     cx, 11
    repe    cmpsb
    pop     di
    pop     si
    pop     cx
    je      .found_subdir

    add     di, 32
    loop    .check_subdir_entry

    ; Move to next cluster in chain
    push    si
    mov     ax, dx
    call    fat_get_next_cluster
    mov     dx, ax
    pop     si
    cmp     dx, 0x0FF8
    jb      .next_cluster

    ; End of chain, not found
    jmp     .not_found

.next_subdir_entry_pop:
    pop     di
    pop     si
    pop     cx
    add     di, 32
    loop    .check_subdir_entry
    ; Continue to next cluster
    push    si
    mov     ax, dx
    call    fat_get_next_cluster
    mov     dx, ax
    pop     si
    cmp     dx, 0x0FF8
    jb      .next_cluster
    jmp     .not_found

.not_found_pop_subdir:
    pop     di
    pop     si
    pop     cx
    jmp     .not_found

.found_subdir:
    ; DI = entry pointer, need to get sector number
    mov     ax, dx
    call    fat_cluster_to_lba  ; AX = sector number
    clc
    pop     es
    pop     dx
    pop     cx
    pop     bx
    ret

.search_root:
    ; Root directory: use existing fat_find_in_root logic
    ; Root directory starts at sector 19, 14 sectors
    mov     ax, 19
    mov     cx, 14

.next_root_sector:
    push    cx
    push    ax

    ; Read sector into disk_buffer
    mov     bx, disk_buffer
    call    fat_read_sector

    ; Search 16 entries per sector
    mov     di, disk_buffer
    mov     cx, 16

.check_root_entry:
    push    cx
    push    si
    push    di

    ; Check if entry is empty
    cmp     byte [di], 0x00
    je      .not_found_pop_root
    cmp     byte [di], 0xE5
    je      .next_root_entry_pop

    ; Compare 11 bytes
    mov     cx, 11
    repe    cmpsb
    pop     di
    pop     si
    pop     cx
    je      .found_root

    add     di, 32
    loop    .check_root_entry
    jmp     .next_root_sector_continue

.next_root_entry_pop:
    pop     di
    pop     si
    pop     cx
    add     di, 32
    loop    .check_root_entry

.next_root_sector_continue:
    pop     ax
    pop     cx
    inc     ax
    loop    .next_root_sector

    ; Not found
.not_found:
    stc
    pop     es
    pop     dx
    pop     cx
    pop     bx
    ret

.not_found_pop_root:
    pop     di
    pop     si
    pop     cx
    pop     ax
    pop     cx
    stc
    pop     es
    pop     dx
    pop     cx
    pop     bx
    ret

.found_root:
    pop     ax                  ; Sector number
    pop     cx
    clc
    pop     es
    pop     dx
    pop     cx
    pop     bx
    ret

; ---------------------------------------------------------------------------
; parse_path_component - Extract next path component from ASCIIZ path
; Input: DS:SI = ASCIIZ path (e.g., "DATOS\FILE.FLI" or "\DATOS\FILE.FLI")
; Output: fcb_name_buffer = 11-byte FCB name of first component
;         SI advanced past component (points to char after \ or to NUL)
;         CF=0 success, CF=1 if empty component or error
; ---------------------------------------------------------------------------
parse_path_component:
    push    ax
    push    bx
    push    cx
    push    dx
    push    di
    push    es

    ; Set ES = DS for stosb
    push    ds
    pop     es

    ; Fill fcb_name_buffer with spaces
    mov     di, fcb_name_buffer
    push    di
    mov     cx, 11
    mov     al, ' '
    rep     stosb
    pop     di

    ; Copy name part (up to 8 chars or until . or \ or / or NUL)
    mov     cx, 8
.name_loop:
    lodsb
    test    al, al
    jz      .done_name
    cmp     al, '\'
    je      .done_name
    cmp     al, '/'
    je      .done_name
    cmp     al, '.'
    je      .do_ext
    ; Convert to uppercase
    cmp     al, 'a'
    jb      .store_name
    cmp     al, 'z'
    ja      .store_name
    sub     al, 0x20
.store_name:
    stosb
    loop    .name_loop
    ; Skip remaining name chars until . or \ or / or NUL
.skip_name:
    lodsb
    test    al, al
    jz      .done_name
    cmp     al, '\'
    je      .done_name
    cmp     al, '/'
    je      .done_name
    cmp     al, '.'
    jne     .skip_name

.do_ext:
    ; Copy extension (up to 3 chars or until \ or / or NUL)
    mov     di, fcb_name_buffer + 8
    mov     cx, 3
.ext_loop:
    lodsb
    test    al, al
    jz      .done_ext
    cmp     al, '\'
    je      .done_ext
    cmp     al, '/'
    je      .done_ext
    cmp     al, 'a'
    jb      .store_ext
    cmp     al, 'z'
    ja      .store_ext
    sub     al, 0x20
.store_ext:
    stosb
    loop    .ext_loop
    ; Skip remaining ext chars until \ or / or NUL
.skip_ext:
    lodsb
    test    al, al
    jz      .done_ext
    cmp     al, '\'
    je      .done_ext
    cmp     al, '/'
    jne     .skip_ext

.done_ext:
    ; SI now points to char after \ or to NUL
    ; Back up SI by 1 if we stopped on NUL (so caller sees NUL)
    test    al, al
    jnz     .check_empty
    dec     si
    jmp     .check_empty

.done_name:
    ; SI points to char after \ or to NUL
    test    al, al
    jnz     .check_empty
    dec     si

.check_empty:
    ; Check if component was empty
    mov     di, fcb_name_buffer
    cmp     byte [di], ' '
    je      .empty_component

    pop     es
    pop     di
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    clc
    ret

.empty_component:
    pop     es
    pop     di
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    stc
    ret

; ---------------------------------------------------------------------------
; resolve_path - Resolve full path to directory cluster + filename
; Input: DS:SI = ASCIIZ path (e.g., "A:\DATOS\FILE.FLI" or "DATOS\FILE.FLI")
; Output: AX = directory cluster (0=root)
;         fcb_name_buffer = final filename in FCB format
;         CF=0 success, CF=1 path not found
; Note: Clobbers path_buffer
; ---------------------------------------------------------------------------
resolve_path:
    push    bx
    push    cx
    push    dx
    push    di

    ; Copy path to path_buffer for manipulation
    push    si
    mov     di, path_buffer
.copy_path:
    lodsb
    mov     [di], al
    inc     di
    test    al, al
    jnz     .copy_path
    pop     si

    ; Point SI at path_buffer
    mov     si, path_buffer

    ; Skip drive letter if present (e.g., "A:" or "A:\")
    cmp     byte [si + 1], ':'
    jne     .no_drive
    add     si, 2
.no_drive:

    ; Skip leading slash if present (absolute path)
    cmp     byte [si], '\'
    je      .is_absolute
    cmp     byte [si], '/'
    jne     .start_resolve
.is_absolute:
    inc     si
    ; If path starts with \ or /, start from root
    xor     ax, ax
    jmp     .start_resolve_abs

.start_resolve:
    ; Relative path - start from current directory
    mov     ax, [current_dir_cluster]

.start_resolve_abs:
    ; AX = current directory cluster (0 = root)
    ; SI = remaining path

    ; Count path components to find the last one (which is the filename)
    push    si
    xor     cx, cx              ; Component count
    mov     di, si
.count_loop:
    lodsb
    test    al, al
    jz      .count_done
    cmp     al, '\'
    je      .found_sep
    cmp     al, '/'
    jne     .count_loop
.found_sep:
    inc     cx
    mov     di, si              ; DI = start of last component
    jmp     .count_loop
.count_done:
    pop     si

    ; If no backslashes, entire path is the filename
    test    cx, cx
    jz      .just_filename

    ; Process each directory component (not the last one)
.process_component:
    ; Check if we've reached the last component
    cmp     si, di
    jae     .last_component

    ; Skip any leading slash (\ or /)
    cmp     byte [si], '\'
    je      .do_skip_slash
    cmp     byte [si], '/'
    jne     .no_skip_slash
.do_skip_slash:
    inc     si
.no_skip_slash:

    ; Parse the next component
    call    parse_path_component
    jc      .path_not_found

    ; Check for special "." component (current directory - stay here)
    cmp     byte [fcb_name_buffer], '.'
    jne     .not_dot
    cmp     byte [fcb_name_buffer + 1], ' '
    jne     .check_dotdot
    ; Component is "." - stay in current directory
    jmp     .process_component

.check_dotdot:
    ; Check for ".." component (parent directory)
    cmp     byte [fcb_name_buffer + 1], '.'
    jne     .not_dot
    cmp     byte [fcb_name_buffer + 2], ' '
    jne     .not_dot
    ; Component is ".." - navigate to parent
    ; If we're at root (AX=0), stay at root
    test    ax, ax
    jz      .process_component      ; Already at root, ".." stays at root

    ; Find ".." entry in current directory to get parent cluster
    push    di                      ; Save path end marker
    push    si                      ; Save current position
    mov     si, .dotdot_name        ; FCB name for ".."
    call    fat_find_in_directory
    mov     bx, di                  ; Save entry pointer
    pop     si
    pop     di
    jc      .path_not_found         ; ".." not found (shouldn't happen)

    ; Get parent cluster from ".." entry
    mov     ax, [bx + 26]           ; First cluster of parent (0 = root)
    jmp     .process_component

.not_dot:
    ; Search for this component in current directory
    ; Save DI (path marker) and SI (current position)
    push    di                      ; Save path end marker
    push    si                      ; Save current position in path
    mov     si, fcb_name_buffer
    call    fat_find_in_directory
    ; DI now points to found entry (or undefined if not found)
    mov     bx, di                  ; Save entry pointer in BX
    pop     si                      ; Restore path position
    pop     di                      ; Restore path end marker
    jc      .path_not_found

    ; Check if it's a directory (attribute at offset 11)
    ; BX points to the directory entry
    test    byte [bx + 11], ATTR_DIRECTORY
    jz      .path_not_found     ; Not a directory

    ; Get its cluster
    mov     ax, [bx + 26]       ; First cluster of subdirectory
    jmp     .process_component

; FCB-format name for ".." entry
.dotdot_name    db  '..         '

.last_component:
    ; Skip leading slash if present
    cmp     byte [si], '\'
    je      .skip_last_slash
    cmp     byte [si], '/'
    jne     .parse_final
.skip_last_slash:
    inc     si
.parse_final:
    ; Parse the final component (filename)
    push    ax                  ; Save directory cluster
    call    parse_path_component
    pop     ax
    jc      .path_not_found

    ; Check if final component is "." (refers to current directory itself)
    cmp     byte [fcb_name_buffer], '.'
    jne     .final_not_dot
    cmp     byte [fcb_name_buffer + 1], ' '
    jne     .check_final_dotdot
    ; Final component is "." - AX already has current directory cluster
    ; fcb_name_buffer contains "." which is valid (refers to dir itself)
    jmp     .resolve_done

.check_final_dotdot:
    ; Check if final component is ".."
    cmp     byte [fcb_name_buffer + 1], '.'
    jne     .final_not_dot
    cmp     byte [fcb_name_buffer + 2], ' '
    jne     .final_not_dot
    ; Final component is ".." - navigate to parent
    test    ax, ax
    jz      .resolve_done           ; At root, ".." stays at root

    ; Find ".." entry in current directory
    push    si
    mov     si, .dotdot_name
    call    fat_find_in_directory
    mov     bx, di
    pop     si
    jc      .path_not_found

    ; Get parent cluster
    mov     ax, [bx + 26]
    ; fcb_name_buffer still contains ".." which is valid
    jmp     .resolve_done

.final_not_dot:
.resolve_done:
    ; AX = directory cluster, fcb_name_buffer = filename
    pop     di
    pop     dx
    pop     cx
    pop     bx
    clc
    ret

.just_filename:
    ; Path is just a filename - parse it and use current directory
    call    parse_path_component
    jc      .path_not_found
    ; AX already = current directory cluster
    pop     di
    pop     dx
    pop     cx
    pop     bx
    clc
    ret

.path_not_found:
    pop     di
    pop     dx
    pop     cx
    pop     bx
    stc
    ret

; ===========================================================================
; FAT Type Dispatch Wrappers
; These dispatch to FAT12 or FAT16 functions based on dpb_a.fat_type
; ===========================================================================

; ---------------------------------------------------------------------------
; fat_get_next_cluster - Dispatch to FAT12 or FAT16 get_next_cluster
; Input: AX = current cluster
; Output: AX = next cluster (>= 0xFF8/0xFFF8 = end of chain)
; ---------------------------------------------------------------------------
fat_get_next_cluster:
    cmp     byte [dpb_a.fat_type], 16
    je      fat16_get_next_cluster
    jmp     fat12_get_next_cluster

; ---------------------------------------------------------------------------
; fat_alloc_cluster - Dispatch to FAT12 or FAT16 alloc_cluster
; Output: AX = allocated cluster, CF set if disk full
; ---------------------------------------------------------------------------
fat_alloc_cluster:
    cmp     byte [dpb_a.fat_type], 16
    je      fat16_alloc_cluster
    jmp     fat12_alloc_cluster

; ---------------------------------------------------------------------------
; fat_set_cluster - Dispatch to FAT12 or FAT16 set_cluster
; Input: AX = cluster number, DX = value to set
; ---------------------------------------------------------------------------
fat_set_cluster:
    cmp     byte [dpb_a.fat_type], 16
    je      fat16_set_cluster
    jmp     fat12_set_cluster

; ---------------------------------------------------------------------------
; fat_free_chain - Dispatch to FAT12 or FAT16 free_chain
; Input: AX = first cluster of chain to free
; ---------------------------------------------------------------------------
fat_free_chain:
    cmp     byte [dpb_a.fat_type], 16
    je      fat16_free_chain
    jmp     fat12_free_chain
