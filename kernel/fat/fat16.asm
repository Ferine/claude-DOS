; ===========================================================================
; claudeDOS FAT16 Driver
; For hard disk images (>= 4085 clusters)
; ===========================================================================

; ---------------------------------------------------------------------------
; fat16_get_next_cluster - Get next cluster from FAT16
; Input: AX = current cluster
; Output: AX = next cluster (>= 0xFFF8 = end of chain)
;         CF set on error
; ---------------------------------------------------------------------------
fat16_get_next_cluster:
    push    bx
    push    cx
    push    si
    push    es

    ; FAT16: each entry is 2 bytes, byte offset = cluster * 2
    mov     bx, ax
    shl     ax, 1               ; AX = byte offset

    ; Which FAT sector?
    mov     cx, ax
    shr     cx, 9               ; sector index
    add     cx, 1               ; FAT starts after reserved

    cmp     cx, [fat_buffer_sector]
    je      .cached

    mov     [fat_buffer_sector], cx
    push    ax
    mov     ax, cx
    push    cs
    pop     es
    push    bx
    mov     bx, fat_buffer
    call    fat_read_sector
    pop     bx
    pop     ax

.cached:
    and     ax, 0x01FF
    mov     si, fat_buffer
    add     si, ax
    mov     ax, [si]            ; Read 16-bit entry

    clc
    pop     es
    pop     si
    pop     cx
    pop     bx
    ret

; ---------------------------------------------------------------------------
; fat16_alloc_cluster - Allocate a free FAT16 cluster
; Output: AX = cluster, CF set if disk full
; ---------------------------------------------------------------------------
fat16_alloc_cluster:
    push    bx
    push    cx
    push    dx

    mov     ax, [dpb_a.first_free]

.scan:
    cmp     ax, [dpb_a.max_cluster]
    jae     .full

    push    ax
    call    fat16_get_next_cluster
    test    ax, ax
    pop     ax
    jz      .found
    inc     ax
    jmp     .scan

.found:
    push    ax
    mov     dx, 0xFFFF
    call    fat16_set_cluster
    pop     ax
    mov     bx, ax
    inc     bx
    mov     [dpb_a.first_free], bx
    clc
    pop     dx
    pop     cx
    pop     bx
    ret

.full:
    stc
    pop     dx
    pop     cx
    pop     bx
    ret

; ---------------------------------------------------------------------------
; fat16_set_cluster - Set FAT16 entry value
; Input: AX = cluster, DX = value
; ---------------------------------------------------------------------------
fat16_set_cluster:
    push    bx
    push    cx
    push    si
    push    es

    mov     bx, ax
    shl     bx, 1
    mov     cx, bx
    shr     cx, 9
    add     cx, 1

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
    and     bx, 0x01FF
    mov     si, fat_buffer
    add     si, bx
    mov     [si], dx

    push    ax
    push    dx
    mov     ax, [fat_buffer_sector]
    push    cs
    pop     es
    mov     bx, fat_buffer
    call    fat_write_sector
    pop     dx
    pop     ax

    pop     es
    pop     si
    pop     cx
    pop     bx
    ret

; ---------------------------------------------------------------------------
; fat16_free_chain - Free cluster chain
; Input: AX = first cluster
; ---------------------------------------------------------------------------
fat16_free_chain:
    push    bx
    push    dx

.free_loop:
    cmp     ax, 0xFFF8
    jae     .done

    push    ax
    call    fat16_get_next_cluster
    mov     bx, ax
    pop     ax

    xor     dx, dx
    call    fat16_set_cluster
    mov     ax, bx
    jmp     .free_loop

.done:
    pop     dx
    pop     bx
    ret
