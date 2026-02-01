; ===========================================================================
; claudeDOS Second-Stage Loader
; Loaded at 0000:0600 by VBR
; Finds and loads IO.SYS from FAT12 root directory into KERNEL_SEG:0000
; Then jumps to the kernel entry point
; ===========================================================================

    CPU     186
    ORG     0x0600

%include "constants.inc"

FAT_BUF         equ     0x3000      ; FAT loaded at 0000:3000
ROOTDIR_BUF     equ     0x4000      ; Root dir loaded at 0000:4000

; BPB values (hardcoded for 1.44MB floppy - must match VBR)
BYTES_PER_SEC   equ     512
SEC_PER_CLUS    equ     1
RSVD_SEC        equ     1
NUM_FATS        equ     2
ROOT_ENTRIES    equ     224
FAT_SIZE        equ     9
SEC_PER_TRACK   equ     18
NUM_HEADS       equ     2
ROOT_DIR_START  equ     19          ; 1 + 2*9
ROOT_DIR_SECS   equ     14          ; (224*32+511)/512
DATA_START      equ     33          ; 19 + 14

start:
    mov     [boot_drive], dl

    mov     si, msg_stage2
    call    print_string

    ; Load FAT
    xor     ax, ax
    mov     es, ax
    mov     ax, RSVD_SEC
    mov     cx, FAT_SIZE
    mov     bx, FAT_BUF
    call    read_sectors

    ; Load root directory
    mov     ax, ROOT_DIR_START
    mov     cx, ROOT_DIR_SECS
    mov     bx, ROOTDIR_BUF
    call    read_sectors

    ; Search for IO.SYS
    mov     di, ROOTDIR_BUF
    mov     cx, ROOT_ENTRIES
.search:
    push    cx
    push    di
    mov     si, iosys_name
    mov     cx, 11
    repe    cmpsb
    pop     di
    pop     cx
    je      .found

    add     di, 32
    loop    .search

    mov     si, msg_no_io
    call    print_string
    jmp     halt

.found:
    mov     ax, [di + 26]       ; Starting cluster

    ; Load IO.SYS at KERNEL_SEG:0000
    mov     bx, KERNEL_SEG
    mov     es, bx
    xor     bx, bx

.load_loop:
    push    ax

    ; Cluster to LBA
    sub     ax, 2
    add     ax, DATA_START

    ; Read one sector to ES:BX
    push    bx
    call    read_one_sector
    pop     bx
    add     bx, BYTES_PER_SEC

    ; Handle 64K segment wrap
    test    bx, bx
    jnz     .no_wrap
    mov     cx, es
    add     cx, 0x1000
    mov     es, cx
.no_wrap:

    pop     ax
    call    fat12_next
    cmp     ax, 0x0FF8
    jb      .load_loop

    ; Jump to kernel, pass boot drive in DL
    mov     dl, [boot_drive]
    jmp     KERNEL_SEG:KERNEL_OFF

; ---------------------------------------------------------------------------
; fat12_next - Get next cluster from FAT12
; Input:  AX = current cluster
; Output: AX = next cluster
; ---------------------------------------------------------------------------
fat12_next:
    push    bx
    push    cx
    push    si
    push    ds

    xor     cx, cx
    mov     ds, cx              ; DS = 0

    mov     bx, ax
    mov     cx, ax
    shr     cx, 1
    add     cx, ax

    mov     si, FAT_BUF
    add     si, cx
    mov     ax, [si]

    test    bx, 1
    jz      .even
    shr     ax, 4
    jmp     short .done
.even:
    and     ax, 0x0FFF
.done:
    pop     ds
    pop     si
    pop     cx
    pop     bx
    ret

; ---------------------------------------------------------------------------
; read_one_sector - Read 1 sector at LBA AX to ES:BX
; ---------------------------------------------------------------------------
read_one_sector:
    pusha

    ; LBA to CHS
    ; LBA in AX
    xor     dx, dx
    div     word [num_heads_val + 2] ; div by SEC_PER_TRACK (18)
    ; AX = track, DX = sector-within-track
    inc     dl                  ; Sectors are 1-based
    mov     cl, dl              ; CL = sector number

    xor     dx, dx
    div     word [num_heads_val] ; div by NUM_HEADS (2)
    ; AX = cylinder, DX = head
    mov     dh, dl              ; DH = head
    mov     ch, al              ; CH = cylinder

    mov     dl, [boot_drive]
    mov     ax, 0x0201          ; AH=02 read, AL=01 sector
    int     0x13
    jc      .disk_err

    popa
    ret

.disk_err:
    mov     si, msg_disk_err
    call    print_string
    jmp     halt

; ---------------------------------------------------------------------------
; read_sectors - Read CX sectors from LBA AX to ES:BX
; ---------------------------------------------------------------------------
read_sectors:
    push    ax
    push    cx
.loop:
    call    read_one_sector
    inc     ax
    add     bx, BYTES_PER_SEC
    loop    .loop
    pop     cx
    pop     ax
    ret

; ---------------------------------------------------------------------------
; print_string - Print null-terminated string via BIOS
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

halt:
    cli
    hlt
    jmp     halt

; ---------------------------------------------------------------------------
; Data
; ---------------------------------------------------------------------------
msg_stage2      db  'Stage2 loaded', 0x0D, 0x0A, 0
msg_no_io       db  'IO.SYS not found', 0x0D, 0x0A, 0
msg_disk_err    db  'Disk error', 0x0D, 0x0A, 0
iosys_name      db  'IO      SYS'
boot_drive      db  0
num_heads_val   dw  NUM_HEADS       ; 2
                dw  SEC_PER_TRACK   ; 18 (at num_heads_val+2)
