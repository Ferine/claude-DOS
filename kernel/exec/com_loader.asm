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

    ; Find file in root directory
    call    fat_find_in_root
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
    call    fat_cluster_to_lba
    call    fat_read_sector         ; Read to ES:BX
    pop     ax
    jc      .read_error

    add     bx, 512

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
