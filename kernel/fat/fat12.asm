; ===========================================================================
; claudeDOS FAT12 Driver
; ===========================================================================

; ---------------------------------------------------------------------------
; fat12_get_next_cluster - Get next cluster in chain from FAT12
; Input: AX = current cluster
; Output: AX = next cluster (>= 0xFF8 = end of chain)
;         CF set on error
; ---------------------------------------------------------------------------
fat12_get_next_cluster:
    push    bx
    push    cx
    push    si
    push    es
    
    ; Calculate which FAT sector contains this entry
    ; Byte offset = cluster * 3 / 2
    mov     bx, ax              ; Save cluster number
    mov     cx, ax
    shr     cx, 1
    add     cx, ax              ; CX = byte offset into FAT
    
    ; Which sector of FAT? (offset / 512)
    push    cx
    shr     cx, 9               ; CX = sector index into FAT
    push    bx
    mov     bx, [active_dpb]
    add     cx, [bx + DPB_RSVD_SECTORS]
    pop     bx
    
    ; Read FAT sector if not cached
    cmp     cx, [fat_buffer_sector]
    je      .cached
    
    mov     [fat_buffer_sector], cx
    mov     ax, cx
    push    cs
    pop     es
    push    bx
    mov     bx, fat_buffer
    call    fat_read_sector
    pop     bx
    
.cached:
    pop     cx                  ; Restore byte offset
    and     cx, 0x01FF          ; Offset within sector (mod 512)
    
    mov     si, fat_buffer
    add     si, cx
    
    ; Handle boundary case: if offset is 511, entry spans two sectors
    cmp     cx, 511
    je      .boundary
    
    mov     ax, [si]            ; Read 16-bit word
    jmp     .apply_mask

.boundary:
    ; Entry spans sector boundary - read low byte from this sector,
    ; high byte from next sector
    mov     al, [si]            ; Low byte
    ; Read next FAT sector
    push    ax
    mov     ax, [fat_buffer_sector]
    inc     ax
    mov     [fat_buffer_sector], ax
    push    cs
    pop     es
    push    bx
    mov     bx, fat_buffer
    call    fat_read_sector
    pop     bx
    jc      .boundary_err
    pop     ax
    mov     ah, [fat_buffer]    ; High byte from start of next sector

.apply_mask:
    test    bx, 1               ; Was original cluster odd?
    jz      .even
    shr     ax, 4               ; Odd: high 12 bits
    jmp     short .done
.even:
    and     ax, 0x0FFF          ; Even: low 12 bits
.done:
    clc
    pop     es
    pop     si
    pop     cx
    pop     bx
    ret

.boundary_err:
    pop     ax                  ; Clean up saved low byte
    stc
    pop     es
    pop     si
    pop     cx
    pop     bx
    ret

; ---------------------------------------------------------------------------
; fat12_alloc_cluster - Allocate a free FAT12 cluster
; Output: AX = allocated cluster, CF set if disk full
; ---------------------------------------------------------------------------
fat12_alloc_cluster:
    push    bx
    push    cx

    mov     bx, [active_dpb]
    mov     ax, [bx + DPB_FIRST_FREE]

.scan:
    mov     bx, [active_dpb]
    cmp     ax, [bx + DPB_MAX_CLUSTER]
    jae     .full

    push    ax
    call    fat12_get_next_cluster
    test    ax, ax              ; 0 = free
    pop     ax
    jz      .found
    inc     ax
    jmp     .scan

.found:
    push    ax
    mov     dx, 0x0FFF          ; End of chain
    call    fat12_set_cluster
    pop     ax
    mov     bx, [active_dpb]
    push    ax
    inc     ax
    mov     [bx + DPB_FIRST_FREE], ax
    pop     ax
    clc
    pop     cx
    pop     bx
    ret

.full:
    stc
    pop     cx
    pop     bx
    ret

; ---------------------------------------------------------------------------
; fat12_set_cluster - Set FAT12 entry value
; Input: AX = cluster number, DX = 12-bit value
; ---------------------------------------------------------------------------
fat12_set_cluster:
    push    bx
    push    cx
    push    si
    push    es

    mov     bx, ax              ; BX = cluster number
    mov     cx, ax
    shr     cx, 1
    add     cx, ax              ; CX = byte offset

    ; Which FAT sector?
    push    cx
    shr     cx, 9
    push    bx
    mov     bx, [active_dpb]
    add     cx, [bx + DPB_RSVD_SECTORS]
    pop     bx

    cmp     cx, [fat_buffer_sector]
    je      .cached
    mov     [fat_buffer_sector], cx
    push    ax
    push    dx
    mov     ax, cx
    push    cs
    pop     es
    push    bx
    mov     bx, fat_buffer
    call    fat_read_sector
    pop     bx
    pop     dx
    pop     ax

.cached:
    pop     cx
    and     cx, 0x01FF          ; Offset within sector

    ; Handle boundary case: if offset is 511, entry spans two sectors
    cmp     cx, 511
    je      .set_boundary

    mov     si, fat_buffer
    add     si, cx
    mov     ax, [si]            ; Read existing word

    test    bx, 1               ; Odd cluster?
    jz      .set_even
    ; Odd: replace high 12 bits
    and     ax, 0x000F
    shl     dx, 4
    or      ax, dx
    jmp     .write_back
.set_even:
    ; Even: replace low 12 bits
    and     ax, 0xF000
    and     dx, 0x0FFF
    or      ax, dx

.write_back:
    mov     [si], ax

    ; Write FAT sector back (primary FAT)
    push    ax
    push    dx
    mov     ax, [fat_buffer_sector]
    push    cs
    pop     es
    mov     bx, fat_buffer
    call    fat_write_sector

    ; Write to backup FAT (FAT2) for mirroring
    mov     ax, [fat_buffer_sector]
    push    bx
    mov     bx, [active_dpb]
    add     ax, [bx + DPB_FAT_SIZE]
    pop     bx
    mov     bx, fat_buffer
    call    fat_write_sector

    pop     dx
    pop     ax

    pop     es
    pop     si
    pop     cx
    pop     bx
    ret

; --- Boundary case: FAT12 entry spans two sectors (offset 511) ---
; Low byte is at end of current sector, high byte at start of next sector
.set_boundary:
    ; Read low byte from current sector
    mov     al, [fat_buffer + 511]

    ; Read next FAT sector to get high byte
    push    dx                  ; Save new value
    push    ax                  ; Save low byte
    mov     ax, [fat_buffer_sector]
    inc     ax
    push    ax                  ; Save next sector number
    push    cs
    pop     es
    push    bx
    mov     bx, fat_buffer
    call    fat_read_sector
    pop     bx
    pop     cx                  ; CX = next sector number
    pop     ax                  ; AL = low byte from first sector
    jc      .set_boundary_err

    mov     ah, [fat_buffer]    ; AH = high byte from next sector
    pop     dx                  ; DX = new 12-bit value

    ; Merge new value with existing nibbles
    test    bx, 1               ; Odd cluster?
    jz      .set_boundary_even
    ; Odd: replace high 12 bits, keep low 4
    and     ax, 0x000F
    shl     dx, 4
    or      ax, dx
    jmp     .set_boundary_writeback
.set_boundary_even:
    ; Even: replace low 12 bits, keep high 4
    and     ax, 0xF000
    and     dx, 0x0FFF
    or      ax, dx

.set_boundary_writeback:
    ; Write high byte to next sector (currently in fat_buffer)
    mov     [fat_buffer], ah
    push    ax                  ; Save low byte
    push    dx
    mov     [fat_buffer_sector], cx ; Next sector is now cached
    mov     ax, cx
    push    cs
    pop     es
    push    bx
    mov     bx, fat_buffer
    call    fat_write_sector
    ; Write backup FAT copy of next sector
    push    bx
    mov     bx, [active_dpb]
    add     ax, [bx + DPB_FAT_SIZE]
    pop     bx
    mov     bx, fat_buffer
    call    fat_write_sector
    pop     dx
    pop     ax                  ; AL = low byte

    ; Now re-read first sector to write low byte back
    push    ax
    mov     ax, cx
    dec     ax                  ; First sector = next - 1
    mov     [fat_buffer_sector], ax
    push    cs
    pop     es
    push    bx
    mov     bx, fat_buffer
    call    fat_read_sector
    pop     bx
    pop     ax
    jc      .set_boundary_done  ; If read fails, can't write back

    mov     [fat_buffer + 511], al
    push    ax
    push    dx
    mov     ax, [fat_buffer_sector]
    push    cs
    pop     es
    push    bx
    mov     bx, fat_buffer
    call    fat_write_sector
    ; Write backup FAT copy of first sector
    push    bx
    mov     bx, [active_dpb]
    add     ax, [bx + DPB_FAT_SIZE]
    pop     bx
    mov     bx, fat_buffer
    call    fat_write_sector
    pop     dx
    pop     ax

.set_boundary_done:
    pop     es
    pop     si
    pop     cx
    pop     bx
    ret

.set_boundary_err:
    pop     dx                  ; Clean up saved new value
    pop     es
    pop     si
    pop     cx
    pop     bx
    ret

; ---------------------------------------------------------------------------
; fat12_free_chain - Free a cluster chain
; Input: AX = first cluster
; ---------------------------------------------------------------------------
fat12_free_chain:
    push    bx
    push    dx

.free_loop:
    cmp     ax, 0x0FF8
    jae     .done

    push    ax
    call    fat12_get_next_cluster
    mov     bx, ax              ; BX = next
    pop     ax

    xor     dx, dx              ; 0 = free
    call    fat12_set_cluster

    mov     ax, bx
    jmp     .free_loop

.done:
    pop     dx
    pop     bx
    ret
