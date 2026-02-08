; ===========================================================================
; claudeDOS .COM Program Loader
; ===========================================================================

; ---------------------------------------------------------------------------
; load_com - Load a .COM program into memory
; Input: DS:SI = 11-byte FCB filename
;        AX = load segment (PSP segment)
; Output: CF clear on success, AX = file size
;         CF set on error, AX = error code
; ---------------------------------------------------------------------------
load_com:
    push    bx
    push    cx
    push    dx
    push    es
    push    di

    mov     [.load_seg], ax

    ; Find file in resolved directory (exec_dir_cluster set by caller)
    mov     ax, [exec_dir_cluster]
    call    fat_find_in_directory
    jc      .not_found

    ; DI = directory entry in disk_buffer
    ; Get file size (must be <= 0xFEFF for .COM)
    mov     ax, [di + 28]           ; File size low word
    mov     dx, [di + 30]           ; File size high word
    test    dx, dx
    jnz     .too_large
    cmp     ax, 0xFEFF
    ja      .too_large

    mov     [.file_size], ax

    ; Get starting cluster
    mov     ax, [di + 26]

    ; Load cluster chain at load_seg:0100h
    mov     es, [.load_seg]
    mov     bx, COM_LOAD_OFFSET     ; 0x0100

.load_loop:
    push    ax
    call    fat_cluster_to_lba      ; AX = first LBA of cluster
    jc      .read_error_pop

    ; Read all sectors in this cluster
    push    cx
    push    bx                      ; Save buffer pointer
    mov     bx, [active_dpb]
    xor     ch, ch
    mov     cl, [bx + DPB_SEC_PER_CLUS]
    inc     cx                      ; CX = actual sectors per cluster
    pop     bx                      ; Restore buffer pointer
.load_sector:
    call    fat_read_sector         ; Read to ES:BX
    jc      .read_error_pop3
    add     bx, 512
    inc     ax                      ; Next sector
    loop    .load_sector
    pop     cx
    pop     ax                      ; Restore cluster number

    ; Get next cluster
    call    fat_get_next_cluster
    cmp     ax, [fat_eoc_min]
    jb      .load_loop

    ; Success
    mov     ax, [.file_size]
    clc

    pop     di
    pop     es
    pop     dx
    pop     cx
    pop     bx
    ret

.not_found:
    mov     ax, ERR_FILE_NOT_FOUND
    stc
    pop     di
    pop     es
    pop     dx
    pop     cx
    pop     bx
    ret

.too_large:
    mov     ax, ERR_INVALID_FORMAT
    stc
    pop     di
    pop     es
    pop     dx
    pop     cx
    pop     bx
    ret

.read_error_pop3:
    pop     cx
.read_error_pop:
    pop     ax
.read_error:
    mov     ax, ERR_READ_FAULT
    stc
    pop     di
    pop     es
    pop     dx
    pop     cx
    pop     bx
    ret

.load_seg    dw  0
.file_size   dw  0
