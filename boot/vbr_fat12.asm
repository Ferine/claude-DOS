; ===========================================================================
; claudeDOS Volume Boot Record - FAT12 1.44MB Floppy
; Loaded at 0000:7C00 by BIOS
; Loads STAGE2.BIN from root directory into 0000:0600
; Then jumps to stage2
; ===========================================================================

    CPU     186
    ORG     0x7C00

; ---------------------------------------------------------------------------
; FAT12 BIOS Parameter Block (BPB) - 1.44MB 3.5" floppy
; ---------------------------------------------------------------------------
    jmp     short _start
    nop

bsOemName       db  'CLDOS5.0'      ; OEM identifier
bpbBytesPerSec  dw  512             ; Bytes per sector
bpbSecPerClus   db  1               ; Sectors per cluster
bpbRsvdSecCnt   dw  1               ; Reserved sectors (boot sector)
bpbNumFATs      db  2               ; Number of FATs
bpbRootEntCnt   dw  224             ; Root directory entries
bpbTotSec16     dw  2880            ; Total sectors (1.44MB)
bpbMediaType    db  0xF0            ; Media descriptor (1.44MB floppy)
bpbFATSz16      dw  9               ; Sectors per FAT
bpbSecPerTrk    dw  18              ; Sectors per track
bpbNumHeads     dw  2               ; Number of heads
bpbHiddSec      dd  0               ; Hidden sectors
bpbTotSec32     dd  0               ; Total sectors (32-bit, unused)

; Extended boot record
bsDrvNum        db  0x00            ; Drive number (floppy)
bsReserved1     db  0               ; Reserved
bsBootSig       db  0x29            ; Extended boot signature
bsVolID         dd  0x434C444F      ; Volume serial number
bsVolLabel      db  'CLAUDEDOS  '   ; Volume label (11 bytes)
bsFileSysType   db  'FAT12   '     ; File system type (8 bytes)

; ---------------------------------------------------------------------------
; Boot code entry point
; ---------------------------------------------------------------------------
_start:
    cli
    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    mov     ss, ax
    mov     sp, 0x7C00
    sti

    mov     [bsDrvNum], dl      ; Save boot drive

    mov     si, msg_boot
    call    print_string

    ; Root dir start = ReservedSectors + NumFATs * FATSize = 1 + 2*9 = 19
    mov     ax, [bpbFATSz16]    ; AX = 9
    xor     cx, cx
    mov     cl, [bpbNumFATs]    ; CX = 2
    mul     cx                  ; AX = 18
    add     ax, [bpbRsvdSecCnt] ; AX = 19
    mov     [root_start], ax

    ; Root dir sectors = (224 * 32 + 511) / 512 = 14
    push    ax
    mov     ax, [bpbRootEntCnt]
    mov     cx, 32
    mul     cx                  ; AX = 7168
    add     ax, [bpbBytesPerSec]
    dec     ax                  ; AX = 7679
    xor     dx, dx
    div     word [bpbBytesPerSec] ; AX = 14
    mov     [root_sectors], ax
    mov     cx, ax              ; CX = root dir sectors

    ; Data start = root_start + root_sectors
    pop     ax
    add     ax, [root_sectors]
    mov     [data_start], ax

    ; Load root directory at 0000:0800
    mov     ax, [root_start]
    mov     cx, [root_sectors]
    mov     bx, 0x0800
    call    read_sectors

    ; Search root directory for STAGE2  BIN
    mov     di, 0x0800
    mov     cx, [bpbRootEntCnt]
.search:
    push    cx
    push    di
    mov     si, stage2_name
    mov     cx, 11
    repe    cmpsb
    pop     di
    pop     cx
    je      .found

    add     di, 32
    loop    .search

    mov     si, msg_no_stage2
    call    print_string
    jmp     halt

.found:
    ; DI -> directory entry. Get starting cluster and file size.
    mov     ax, [di + 26]       ; Starting cluster
    mov     [cur_cluster], ax

    ; Load FAT at 0000:1000
    push    ax
    mov     ax, [bpbRsvdSecCnt] ; FAT starts at sector 1
    mov     cx, [bpbFATSz16]
    mov     bx, 0x1000
    call    read_sectors
    pop     ax

    ; Load stage2 following cluster chain at 0000:0600
    mov     bx, 0x0600

.load_loop:
    ; Convert cluster to LBA: data_start + (cluster - 2) * SecPerClus
    push    ax
    sub     ax, 2
    xor     ch, ch
    mov     cl, [bpbSecPerClus]
    mul     cx
    add     ax, [data_start]

    mov     cx, 1
    call    read_sectors
    add     bx, 512

    ; Get next cluster from FAT12
    pop     ax                  ; AX = current cluster
    call    fat12_next
    cmp     ax, 0x0FF8
    jb      .load_loop

    ; Jump to stage2, pass drive number in DL
    mov     dl, [bsDrvNum]
    jmp     0x0000:0x0600

; ---------------------------------------------------------------------------
; fat12_next - Get next cluster from FAT12 table
; Input:  AX = current cluster number
; Output: AX = next cluster (>= 0xFF8 means end of chain)
; ---------------------------------------------------------------------------
fat12_next:
    push    bx
    push    cx
    push    si

    mov     bx, ax              ; BX = cluster number
    ; Byte offset = cluster * 3 / 2 = cluster + cluster/2
    mov     cx, ax
    shr     cx, 1               ; CX = cluster / 2
    add     cx, ax              ; CX = byte offset

    mov     si, 0x1000          ; FAT buffer base
    add     si, cx
    mov     ax, [si]            ; Read 16-bit word

    test    bx, 1               ; Original cluster odd?
    jz      .even
    shr     ax, 4               ; Odd: high 12 bits
    jmp     short .done
.even:
    and     ax, 0x0FFF          ; Even: low 12 bits
.done:
    pop     si
    pop     cx
    pop     bx
    ret

; ---------------------------------------------------------------------------
; read_sectors - Read CX sectors from LBA in AX to ES:BX
; ---------------------------------------------------------------------------
read_sectors:
    pusha
.loop:
    push    cx
    push    ax
    push    bx

    ; LBA to CHS conversion
    xor     dx, dx
    div     word [bpbSecPerTrk] ; AX = track, DX = sector-within-track
    inc     dl                  ; Sectors are 1-based
    mov     cl, dl              ; CL = sector
    xor     dx, dx
    div     word [bpbNumHeads]  ; AX = cylinder, DX = head
    mov     dh, dl              ; DH = head
    mov     ch, al              ; CH = cylinder

    mov     dl, [bsDrvNum]
    pop     bx                  ; ES:BX = buffer
    mov     ax, 0x0201          ; AH=02 read, AL=01 sector
    int     0x13
    jc      .disk_err

    pop     ax
    pop     cx
    inc     ax
    add     bx, 512
    loop    .loop

    popa
    ret

.disk_err:
    mov     si, msg_disk_err
    call    print_string
    jmp     halt

; ---------------------------------------------------------------------------
; print_string - Print null-terminated string at DS:SI via BIOS
; ---------------------------------------------------------------------------
print_string:
    pusha
    mov     ah, 0x0E
    xor     bx, bx
.loop:
    lodsb
    test    al, al
    jz      .done
    int     0x10
    jmp     .loop
.done:
    popa
    ret

; ---------------------------------------------------------------------------
halt:
    cli
    hlt
    jmp     halt

; ---------------------------------------------------------------------------
; Data
; ---------------------------------------------------------------------------
msg_boot        db  'claudeDOS booting...', 0x0D, 0x0A, 0
msg_no_stage2   db  'No STAGE2.BIN', 0x0D, 0x0A, 0
msg_disk_err    db  'Disk error', 0x0D, 0x0A, 0
stage2_name     db  'STAGE2  BIN'

; Variables
root_start      dw  0
root_sectors    dw  0
data_start      dw  0
cur_cluster     dw  0

; Pad to 510 bytes + boot signature
    times   510 - ($ - $$) db 0
    dw      0xAA55
