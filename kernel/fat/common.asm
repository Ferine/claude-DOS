; ===========================================================================
; claudeDOS FAT Common - Sector I/O, cluster/LBA conversion, path resolution
; ===========================================================================

; ---------------------------------------------------------------------------
; fat_read_sector - Read one sector from disk
; Input: AX = LBA sector number, ES:BX = buffer
; Uses boot_drive from kernel data
; ---------------------------------------------------------------------------
fat_read_sector:
    pusha

    ; LBA to CHS for 1.44MB floppy
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
    jc      .read_err

    popa
    ret

.read_err:
    popa
    stc
    ret

; ---------------------------------------------------------------------------
; fat_write_sector - Write one sector to disk
; Input: AX = LBA sector number, ES:BX = buffer
; ---------------------------------------------------------------------------
fat_write_sector:
    pusha

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
    jc      .write_err

    popa
    ret

.write_err:
    popa
    stc
    ret

; ---------------------------------------------------------------------------
; fat_cluster_to_lba - Convert cluster number to LBA
; Input: AX = cluster number
; Output: AX = LBA sector number
; ---------------------------------------------------------------------------
fat_cluster_to_lba:
    sub     ax, 2
    ; For 1.44MB floppy: data_start = 33, sec_per_cluster = 1
    add     ax, 33
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
    call    fat12_get_next_cluster
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
    call    fat12_get_next_cluster
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
