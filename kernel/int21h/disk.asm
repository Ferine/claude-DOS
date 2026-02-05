; ===========================================================================
; claudeDOS INT 21h Disk Functions
; ===========================================================================

; AH=0Dh - Disk reset (flush all buffers)
int21_0D:
    call    dos_clear_error
    ret

; AH=0Eh - Set default drive
; Input: DL = drive number (0=A:)
; Output: AL = number of logical drives
int21_0E:
    mov     al, [save_dx]        ; DL
    cmp     al, LASTDRIVE
    jae     .bad_drive
    mov     [current_drive], al
.bad_drive:
    mov     byte [save_ax], LASTDRIVE
    call    dos_clear_error
    ret

; AH=36h - Get disk free space
; Input: DL = drive (0=default, 1=A:, etc)
; Output: AX = sectors/cluster, BX = free clusters,
;         CX = bytes/sector, DX = total clusters
;         AX = FFFFh if invalid drive
int21_36:
    push    si
    push    di

    ; TODO: Handle drive selection from DL (currently only supports default drive)

    ; Get values from DPB via active_dpb pointer
    push    bx
    mov     bx, [active_dpb]

    ; AX = sectors per cluster (sec_per_clus is stored as value-1)
    xor     ah, ah
    mov     al, [bx + DPB_SEC_PER_CLUS]
    inc     ax                          ; Convert from 0-based to actual count
    mov     [save_ax], ax

    ; CX = bytes per sector
    mov     ax, [bx + DPB_BYTES_PER_SEC]
    mov     [save_cx], ax

    ; DX = total data clusters = max_cluster - 2 (clusters 0,1 are reserved)
    mov     ax, [bx + DPB_MAX_CLUSTER]
    sub     ax, 2
    mov     [save_dx], ax

    ; BX = free clusters - need to count by walking FAT
    ; Check if we have a cached count
    mov     ax, [bx + DPB_FREE_COUNT]
    pop     bx
    cmp     ax, 0xFFFF
    jne     .use_cached                 ; Use cached count if valid

    ; Count free clusters by walking FAT
    xor     di, di                      ; DI = free cluster count
    mov     si, 2                       ; SI = current cluster (start at 2)

.count_loop:
    push    bx
    mov     bx, [active_dpb]
    cmp     si, [bx + DPB_MAX_CLUSTER]
    pop     bx
    jae     .count_done

    ; Get FAT entry for cluster SI
    mov     ax, si
    call    fat_get_next_cluster
    ; AX = FAT entry value (0 = free)
    test    ax, ax
    jnz     .not_free
    inc     di                          ; Found a free cluster

.not_free:
    inc     si
    jmp     .count_loop

.count_done:
    mov     ax, di                      ; AX = free count
    push    bx
    mov     bx, [active_dpb]
    mov     [bx + DPB_FREE_COUNT], ax   ; Cache the result
    pop     bx

.use_cached:
    mov     [save_bx], ax               ; BX = free clusters

    pop     di
    pop     si
    call    dos_clear_error
    ret
