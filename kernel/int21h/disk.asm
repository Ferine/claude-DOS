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
int21_36:
    ; Return values for 1.44MB floppy
    mov     word [save_ax], 1       ; 1 sector per cluster
    mov     word [save_bx], 1000    ; ~1000 free clusters (fake)
    mov     word [save_cx], 512     ; 512 bytes per sector
    mov     word [save_dx], 2847    ; Total clusters (2880-33)
    call    dos_clear_error
    ret
