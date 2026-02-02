; ===========================================================================
; claudeDOS RAM Disk Device Driver
; Provides a fast temporary storage drive using conventional memory
; ===========================================================================

; RAM disk configuration
RAMDISK_SECTORS     equ     720         ; 360KB (720 * 512 bytes)
RAMDISK_SEC_SIZE    equ     512         ; Bytes per sector
RAMDISK_SEC_CLUSTER equ     1           ; Sectors per cluster
RAMDISK_FAT_SECTORS equ     2           ; FAT size in sectors
RAMDISK_ROOT_ENTRIES equ    112         ; Root directory entries
RAMDISK_ROOT_SECTORS equ    7           ; Root directory sectors

; ---------------------------------------------------------------------------
; RAM Disk Device Header (Block Device)
; ---------------------------------------------------------------------------
ramdisk_device:
    dw      0xFFFF                      ; Next driver offset (updated by init)
    dw      0                           ; Next driver segment
    dw      0x0000                      ; Attribute: block device
    dw      ramdisk_strategy
    dw      ramdisk_interrupt
    db      1, 0, 0, 0, 0, 0, 0, 0      ; 1 unit, name field unused for block

; RAM disk state
ramdisk_req_ptr     dd  0               ; Request packet pointer
ramdisk_buffer_seg  dw  0               ; Segment of RAM disk buffer
ramdisk_initialized db  0               ; 1 if initialized

; ---------------------------------------------------------------------------
; ramdisk_strategy - Store request packet pointer
; Input: ES:BX = request packet
; ---------------------------------------------------------------------------
ramdisk_strategy:
    mov     [cs:ramdisk_req_ptr], bx
    mov     [cs:ramdisk_req_ptr + 2], es
    retf

; ---------------------------------------------------------------------------
; ramdisk_interrupt - Process device request
; ---------------------------------------------------------------------------
ramdisk_interrupt:
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di
    push    ds
    push    es

    ; Load request packet pointer
    lds     bx, [cs:ramdisk_req_ptr]

    ; Get command code
    mov     al, [bx + 2]                ; Command code at offset 2

    ; Dispatch based on command
    cmp     al, 0                       ; Init
    je      .cmd_init
    cmp     al, 1                       ; Media check
    je      .cmd_media_check
    cmp     al, 2                       ; Build BPB
    je      .cmd_build_bpb
    cmp     al, 4                       ; Input (read)
    je      .cmd_read
    cmp     al, 8                       ; Output (write)
    je      .cmd_write
    cmp     al, 9                       ; Output with verify
    je      .cmd_write

    ; Unknown command - return error
    mov     word [bx + 3], 0x8103       ; Error + unknown command
    jmp     .done

.cmd_init:
    ; Initialize RAM disk
    call    ramdisk_init
    jmp     .done

.cmd_media_check:
    ; Media check - RAM disk never changes
    mov     byte [bx + 14], 1           ; Media not changed
    mov     word [bx + 3], 0x0100       ; Done, no error
    jmp     .done

.cmd_build_bpb:
    ; Build BPB - return pointer to our BPB
    mov     word [bx + 18], ramdisk_bpb
    mov     [bx + 20], cs
    mov     word [bx + 3], 0x0100       ; Done, no error
    jmp     .done

.cmd_read:
    ; Read sectors from RAM disk
    call    ramdisk_read
    jmp     .done

.cmd_write:
    ; Write sectors to RAM disk
    call    ramdisk_write
    jmp     .done

.done:
    pop     es
    pop     ds
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    retf

; ---------------------------------------------------------------------------
; ramdisk_init - Initialize the RAM disk
; Allocates memory and formats with empty FAT12 filesystem
; ---------------------------------------------------------------------------
ramdisk_init:
    push    ds
    push    es

    ; Check if already initialized
    cmp     byte [cs:ramdisk_initialized], 1
    je      .init_done

    ; Calculate memory needed: RAMDISK_SECTORS * 512 / 16 = paragraphs
    ; 720 * 512 = 368640 bytes = 23040 paragraphs (0x5A00)
    mov     bx, (RAMDISK_SECTORS * RAMDISK_SEC_SIZE) / 16

    ; Allocate memory via MCB
    push    cs
    pop     ds
    call    mcb_alloc
    jc      .init_error

    ; AX = allocated segment
    mov     [cs:ramdisk_buffer_seg], ax

    ; Format the RAM disk with empty FAT12 filesystem
    call    ramdisk_format

    ; Mark as initialized
    mov     byte [cs:ramdisk_initialized], 1

.init_done:
    ; Set status: done, no error
    lds     bx, [cs:ramdisk_req_ptr]
    mov     word [bx + 3], 0x0100
    ; Set number of units
    mov     byte [bx + 13], 1
    ; Set end address (not used for RAM disk since we alloc separately)
    mov     word [bx + 14], ramdisk_bpb
    mov     [bx + 16], cs
    ; Set BPB array pointer
    mov     word [bx + 18], ramdisk_bpb_ptr
    mov     [bx + 20], cs

    pop     es
    pop     ds
    ret

.init_error:
    ; Failed to allocate memory
    lds     bx, [cs:ramdisk_req_ptr]
    mov     word [bx + 3], 0x810C       ; Error + general failure
    mov     byte [bx + 13], 0           ; No units

    pop     es
    pop     ds
    ret

; ---------------------------------------------------------------------------
; ramdisk_format - Format RAM disk with empty FAT12 filesystem
; ---------------------------------------------------------------------------
ramdisk_format:
    push    ax
    push    bx
    push    cx
    push    di
    push    es

    ; First, zero out the entire RAM disk
    ; 720 * 512 / 2 = 184320 words, need to do in segments
    mov     es, [cs:ramdisk_buffer_seg]
    mov     dx, RAMDISK_SECTORS         ; Number of sectors
.zero_loop:
    xor     di, di
    mov     cx, 256                     ; 256 words = 512 bytes = 1 sector
    xor     ax, ax
    rep     stosw
    ; Advance ES by 32 paragraphs (512 bytes)
    mov     ax, es
    add     ax, 32
    mov     es, ax
    dec     dx
    jnz     .zero_loop
    ; Reset ES to buffer start
    mov     es, [cs:ramdisk_buffer_seg]

    ; Write boot sector with BPB at sector 0
    mov     es, [cs:ramdisk_buffer_seg]
    xor     di, di

    ; Jump instruction
    mov     byte [es:di], 0xEB          ; JMP short
    mov     byte [es:di + 1], 0x3C      ; +60 bytes
    mov     byte [es:di + 2], 0x90      ; NOP

    ; OEM name
    mov     si, ramdisk_oem_name
    add     di, 3
    mov     cx, 8
.copy_oem:
    mov     al, [cs:si]
    mov     [es:di], al
    inc     si
    inc     di
    loop    .copy_oem

    ; BPB at offset 11
    mov     di, 11
    mov     word [es:di], 512           ; Bytes per sector
    mov     byte [es:di + 2], 1         ; Sectors per cluster
    mov     word [es:di + 3], 1         ; Reserved sectors
    mov     byte [es:di + 5], 2         ; Number of FATs
    mov     word [es:di + 6], 112       ; Root entries
    mov     word [es:di + 8], RAMDISK_SECTORS ; Total sectors
    mov     byte [es:di + 10], 0xF8     ; Media descriptor (fixed disk)
    mov     word [es:di + 11], RAMDISK_FAT_SECTORS ; Sectors per FAT
    mov     word [es:di + 13], 9        ; Sectors per track (fake)
    mov     word [es:di + 15], 2        ; Number of heads (fake)
    mov     word [es:di + 17], 0        ; Hidden sectors (low word)
    mov     word [es:di + 19], 0        ; Hidden sectors (high word)

    ; Boot sector signature
    mov     word [es:510], 0xAA55

    ; Initialize FAT at sector 1
    ; FAT entry 0 = media byte, FAT entry 1 = 0xFFF
    mov     di, RAMDISK_SEC_SIZE        ; Offset to FAT1
    mov     byte [es:di], 0xF8          ; Media descriptor
    mov     byte [es:di + 1], 0xFF
    mov     byte [es:di + 2], 0xFF

    ; Copy FAT to FAT2
    mov     di, RAMDISK_SEC_SIZE + (RAMDISK_FAT_SECTORS * RAMDISK_SEC_SIZE)
    mov     byte [es:di], 0xF8
    mov     byte [es:di + 1], 0xFF
    mov     byte [es:di + 2], 0xFF

    pop     es
    pop     di
    pop     cx
    pop     bx
    pop     ax
    ret

; ---------------------------------------------------------------------------
; ramdisk_read - Read sectors from RAM disk to transfer buffer
; Request packet: [bx+14]=xfer addr (dword), [bx+18]=sector count, [bx+20]=start sector
; ---------------------------------------------------------------------------
ramdisk_read:
    push    ds
    push    es

    ; Get request packet
    lds     bx, [cs:ramdisk_req_ptr]

    ; Get parameters
    mov     cx, [bx + 18]               ; Sector count
    mov     ax, [bx + 20]               ; Start sector
    les     di, [bx + 14]               ; Transfer address (ES:DI)

    ; Check if initialized
    cmp     byte [cs:ramdisk_initialized], 0
    je      .read_error

    ; Validate sector range
    cmp     ax, RAMDISK_SECTORS
    jae     .read_error
    mov     dx, ax
    add     dx, cx
    cmp     dx, RAMDISK_SECTORS
    ja      .read_error

    ; Calculate source address: ramdisk_buffer_seg + (sector * 512 / 16)
    ; sector * 512 / 16 = sector * 32
    push    ds
    mov     dx, ax                      ; Start sector
    shl     dx, 5                       ; * 32 paragraphs per sector
    mov     ax, [cs:ramdisk_buffer_seg]
    add     ax, dx
    mov     ds, ax
    xor     si, si

    ; Copy cx sectors (cx * 512 bytes)
    shl     cx, 8                       ; * 256 words per sector
    rep     movsw

    pop     ds

    ; Set status: done
    lds     bx, [cs:ramdisk_req_ptr]
    mov     word [bx + 3], 0x0100
    pop     es
    pop     ds
    ret

.read_error:
    lds     bx, [cs:ramdisk_req_ptr]
    mov     word [bx + 3], 0x810B       ; Error + read fault
    pop     es
    pop     ds
    ret

; ---------------------------------------------------------------------------
; ramdisk_write - Write sectors to RAM disk from transfer buffer
; Request packet: [bx+14]=xfer addr (dword), [bx+18]=sector count, [bx+20]=start sector
; ---------------------------------------------------------------------------
ramdisk_write:
    push    ds
    push    es

    ; Get request packet
    lds     bx, [cs:ramdisk_req_ptr]

    ; Get parameters
    mov     cx, [bx + 18]               ; Sector count
    mov     ax, [bx + 20]               ; Start sector

    ; Get transfer address (DS:SI for source)
    push    word [bx + 14]              ; Offset
    push    word [bx + 16]              ; Segment

    ; Check if initialized
    cmp     byte [cs:ramdisk_initialized], 0
    je      .write_error_cleanup

    ; Validate sector range
    cmp     ax, RAMDISK_SECTORS
    jae     .write_error_cleanup
    mov     dx, ax
    add     dx, cx
    cmp     dx, RAMDISK_SECTORS
    ja      .write_error_cleanup

    ; Calculate dest address: ramdisk_buffer_seg + (sector * 32)
    mov     dx, ax
    shl     dx, 5
    mov     ax, [cs:ramdisk_buffer_seg]
    add     ax, dx
    mov     es, ax
    xor     di, di

    ; Set source
    pop     ds                          ; Source segment
    pop     si                          ; Source offset

    ; Copy cx sectors
    shl     cx, 8                       ; * 256 words
    rep     movsw

    ; Set status: done
    push    cs
    pop     ds
    lds     bx, [cs:ramdisk_req_ptr]
    mov     word [bx + 3], 0x0100
    pop     es
    pop     ds
    ret

.write_error_cleanup:
    pop     ax                          ; Clean up stack
    pop     ax
    push    cs
    pop     ds
    lds     bx, [cs:ramdisk_req_ptr]
    mov     word [bx + 3], 0x810A       ; Error + write fault
    pop     es
    pop     ds
    ret

; ---------------------------------------------------------------------------
; RAM Disk BPB (BIOS Parameter Block)
; ---------------------------------------------------------------------------
ramdisk_bpb:
    dw      512                         ; Bytes per sector
    db      1                           ; Sectors per cluster
    dw      1                           ; Reserved sectors (boot sector)
    db      2                           ; Number of FATs
    dw      112                         ; Root directory entries
    dw      RAMDISK_SECTORS             ; Total sectors
    db      0xF8                        ; Media descriptor (fixed disk)
    dw      RAMDISK_FAT_SECTORS         ; Sectors per FAT

ramdisk_bpb_ptr:
    dw      ramdisk_bpb                 ; Pointer to BPB (for init)

ramdisk_oem_name:
    db      'CLAUDDOS'                  ; OEM name for boot sector
