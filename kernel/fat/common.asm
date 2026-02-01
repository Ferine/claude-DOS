; ===========================================================================
; claudeDOS FAT Common - Sector I/O, cluster/LBA conversion
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
    ; Skip leading backslash if present
    cmp     byte [si], '\'
    jne     .no_slash
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
