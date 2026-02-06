; ===========================================================================
; claudeDOS Kernel Initialization
; ===========================================================================

kernel_init:
    ; Print init message
    mov     si, msg_init
    call    bios_print_string

    ; Initialize device driver chain
    call    init_devices

    ; Initialize kernel data areas (SDA, DTA, SFT, CDS)
    call    init_data_areas

    ; Set up memory control blocks
    call    init_memory

    ; Install INT 21h handler
    call    install_int21

    ; Install INT 20h (program terminate)
    call    install_int20

    ; Install INT 33h (mouse driver stub)
    call    install_int33

    ; Install INT 2Fh (multiplex interrupt for XMS)
    call    install_int2f

    ; Install INT 15h (extended memory services)
    call    install_int15

    ; Install INT 31h (DPMI stub for debugging)
    call    install_int31

    ; Install INT 67h (EMS/VCPI stub)
    call    install_int67

    ; Install INT 08h/1Ch (timer interrupts)
    call    install_int08

    ; Install default CPU exception handlers (for debugging)
    call    install_exception_handlers

    ; Install INT 23h (Ctrl-C handler) and INT 24h (Critical Error handler)
    call    install_int23
    call    install_int24

    ; Probe for hard disk (C: drive)
    call    init_hard_disk

    ; Parse CONFIG.SYS (if present)
    call    parse_config_sys

    ; Mark shell as available (COMMAND.COM should be on disk)
    mov     byte [shell_available], 1

    mov     si, msg_init_done
    call    bios_print_string

    ; INT 21h debug tracing (0=off, 1=on)
    mov     byte [debug_trace], 0

    ret

; ---------------------------------------------------------------------------
; install_int21 - Install INT 21h DOS services handler
; ---------------------------------------------------------------------------
install_int21:
    push    es
    push    ax
    push    bx

    xor     ax, ax
    mov     es, ax

    ; INT 21h vector is at 0000:0084 (21h * 4)
    mov     word [es:0x0084], int21_handler
    mov     [es:0x0086], cs

    pop     bx
    pop     ax
    pop     es
    ret

; ---------------------------------------------------------------------------
; install_int20 - Install INT 20h (terminate program)
; ---------------------------------------------------------------------------
install_int20:
    push    es
    push    ax

    xor     ax, ax
    mov     es, ax

    ; INT 20h vector at 0000:0080
    mov     word [es:0x0080], int20_handler
    mov     [es:0x0082], cs

    pop     ax
    pop     es
    ret

; ---------------------------------------------------------------------------
; INT 20h handler - Program Terminate
; ---------------------------------------------------------------------------
int20_handler:
    mov     ah, 0x00
    int     0x21
    iret

; ---------------------------------------------------------------------------
; install_int33 - Install INT 33h (mouse driver)
; ---------------------------------------------------------------------------
install_int33:
    push    es
    push    ax

    ; Initialize PS/2 mouse hardware
    call    mouse_init

    xor     ax, ax
    mov     es, ax

    ; INT 33h vector at 0000:00CC - point to full driver
    mov     word [es:0x00CC], int33_handler_main
    mov     [es:0x00CE], cs

    pop     ax
    pop     es
    ret

; ---------------------------------------------------------------------------
; install_int2f - Install INT 2Fh (multiplex interrupt for XMS detection)
; ---------------------------------------------------------------------------
install_int2f:
    push    es
    push    ax

    xor     ax, ax
    mov     es, ax

    ; INT 2Fh vector at 0000:00BC (2Fh * 4 = 0xBC)
    mov     word [es:0x00BC], int2f_handler
    mov     [es:0x00BE], cs

    pop     ax
    pop     es
    ret

; ---------------------------------------------------------------------------
; install_int15 - Install INT 15h (extended memory services)
; ---------------------------------------------------------------------------
install_int15:
    push    es
    push    ax
    push    bx

    xor     ax, ax
    mov     es, ax

    ; Save old INT 15h vector (at 0000:0054 = 15h * 4)
    mov     ax, [es:0x0054]
    mov     [int15_old_vector], ax
    mov     ax, [es:0x0056]
    mov     [int15_old_vector + 2], ax

    ; Install our handler
    mov     word [es:0x0054], int15_handler
    mov     [es:0x0056], cs

    pop     bx
    pop     ax
    pop     es
    ret

; ---------------------------------------------------------------------------
; install_int31 - Install INT 31h (DPMI stub)
; ---------------------------------------------------------------------------
install_int31:
    push    es
    push    ax

    xor     ax, ax
    mov     es, ax

    ; INT 31h vector at 0000:00C4 (31h * 4)
    mov     word [es:0x00C4], int31_handler
    mov     [es:0x00C6], cs

    pop     ax
    pop     es
    ret

; ---------------------------------------------------------------------------
; install_int67 - Install INT 67h (EMS/VCPI stub)
; ---------------------------------------------------------------------------
install_int67:
    push    es
    push    ax

    xor     ax, ax
    mov     es, ax

    ; INT 67h vector at 0000:019C (67h * 4)
    mov     word [es:0x019C], int67_handler
    mov     [es:0x019E], cs

    pop     ax
    pop     es
    ret

; ---------------------------------------------------------------------------
; install_int08 - Install INT 08h (timer) and INT 1Ch (user timer) handlers
; ---------------------------------------------------------------------------
install_int08:
    push    es
    push    ax
    xor     ax, ax
    mov     es, ax

    ; Save old INT 08h (at 0x0020)
    mov     ax, [es:0x0020]
    mov     [int08_old_vector], ax
    mov     ax, [es:0x0022]
    mov     [int08_old_vector + 2], ax

    ; Install INT 08h
    cli
    mov     word [es:0x0020], int08_handler
    mov     [es:0x0022], cs
    sti

    ; Save old INT 1Ch (at 0x0070)
    mov     ax, [es:0x0070]
    mov     [int1c_old_vector], ax
    mov     ax, [es:0x0072]
    mov     [int1c_old_vector + 2], ax

    ; Install INT 1Ch
    cli
    mov     word [es:0x0070], int1c_handler
    mov     [es:0x0072], cs
    sti

    pop     ax
    pop     es
    ret

; ---------------------------------------------------------------------------
; INT 08h handler - Timer tick (18.2 Hz)
; ---------------------------------------------------------------------------
int08_handler:
    push    ax
    push    ds
    mov     ax, cs
    mov     ds, ax
    add     word [ticks_count], 1
    adc     word [ticks_count + 2], 0
    pop     ds
    pop     ax
    int     0x1C
    jmp     far [cs:int08_old_vector]

; ---------------------------------------------------------------------------
; INT 1Ch handler - User timer tick
; ---------------------------------------------------------------------------
int1c_handler:
    jmp     far [cs:int1c_old_vector]

; ---------------------------------------------------------------------------
; install_exception_handlers - Install default CPU exception handlers
; ---------------------------------------------------------------------------
install_exception_handlers:
    push    es
    push    ax

    xor     ax, ax
    mov     es, ax

    ; INT 00h vector at 0000:0000 (divide error)
    mov     word [es:0x0000], int00_handler
    mov     [es:0x0002], cs

    ; INT 04h vector at 0000:0010 (overflow)
    mov     word [es:0x0010], int04_handler
    mov     [es:0x0012], cs

    ; INT 05h vector at 0000:0014 (bound range exceeded)
    mov     word [es:0x0014], int05_handler
    mov     [es:0x0016], cs

    ; INT 06h vector at 0000:0018 (invalid opcode)
    mov     word [es:0x0018], int06_handler
    mov     [es:0x001A], cs

    ; INT 0Dh vector at 0000:0034 (general protection fault)
    mov     word [es:0x0034], int0d_handler
    mov     [es:0x0036], cs

    pop     ax
    pop     es
    ret

; ---------------------------------------------------------------------------
; install_int23 - Install INT 23h (Ctrl-C/Break handler)
; ---------------------------------------------------------------------------
install_int23:
    push    es
    push    ax

    xor     ax, ax
    mov     es, ax

    ; INT 23h vector at 0000:008C (23h * 4)
    mov     word [es:0x008C], int23_handler
    mov     [es:0x008E], cs

    pop     ax
    pop     es
    ret

; ---------------------------------------------------------------------------
; install_int24 - Install INT 24h (Critical Error handler)
; ---------------------------------------------------------------------------
install_int24:
    push    es
    push    ax

    xor     ax, ax
    mov     es, ax

    ; INT 24h vector at 0000:0090 (24h * 4)
    mov     word [es:0x0090], int24_handler
    mov     [es:0x0092], cs

    pop     ax
    pop     es
    ret

; ---------------------------------------------------------------------------
; INT 23h handler - Ctrl-C/Break (default: do nothing)
; ---------------------------------------------------------------------------
int23_handler:
    iret

; ---------------------------------------------------------------------------
; INT 24h handler - Critical Error (default: fail the operation)
; ---------------------------------------------------------------------------
int24_handler:
    mov     al, 3               ; Action: FAIL
    iret

; ---------------------------------------------------------------------------
; INT 00h handler - Divide Error (always prints for debugging)
; ---------------------------------------------------------------------------
int00_handler:
    push    ax
    push    bx
    mov     al, '#'
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    mov     al, '0'
    int     0x10
    mov     al, '0'
    int     0x10
    mov     al, '#'
    int     0x10
    pop     bx
    pop     ax
    ; Default behavior: just IRET (program will re-execute faulting instruction)
    ; Programs should install their own handler to skip the faulting instruction
    iret

; ---------------------------------------------------------------------------
; INT 04h handler - Overflow (INTO instruction) - always prints
; ---------------------------------------------------------------------------
int04_handler:
    push    ax
    push    bx
    mov     al, '#'
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    mov     al, '0'
    int     0x10
    mov     al, '4'
    int     0x10
    mov     al, '#'
    int     0x10
    pop     bx
    pop     ax
    iret

; ---------------------------------------------------------------------------
; INT 05h handler - Bound Range Exceeded - always prints
; ---------------------------------------------------------------------------
int05_handler:
    push    ax
    push    bx
    mov     al, '#'
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    mov     al, '0'
    int     0x10
    mov     al, '5'
    int     0x10
    mov     al, '#'
    int     0x10
    pop     bx
    pop     ax
    iret

; ---------------------------------------------------------------------------
; INT 06h handler - Invalid Opcode - prints faulting CS:IP and halts
; Stack frame on entry: [SP+0]=IP, [SP+2]=CS, [SP+4]=FLAGS
; ---------------------------------------------------------------------------
int06_handler:
    push    bp
    mov     bp, sp
    push    ax
    push    bx
    push    cx
    push    dx

    ; Print "#UD@"
    mov     ah, 0x0E
    xor     bx, bx
    mov     al, '#'
    int     0x10
    mov     al, 'U'
    int     0x10
    mov     al, 'D'
    int     0x10
    mov     al, '@'
    int     0x10

    ; Print CS (at [bp+4])
    mov     ax, [bp+4]
    call    .print_hex_word
    mov     al, ':'
    mov     ah, 0x0E
    int     0x10

    ; Print IP (at [bp+2])
    mov     ax, [bp+2]
    call    .print_hex_word

    ; Print newline
    mov     al, 0x0D
    int     0x10
    mov     al, 0x0A
    int     0x10

    ; Halt the system - can't continue from invalid opcode
    cli
    hlt

.print_hex_word:
    ; Print AX as 4 hex digits
    push    ax
    push    cx
    mov     cx, 4
.hex_loop:
    rol     ax, 4
    push    ax
    and     al, 0x0F
    add     al, '0'
    cmp     al, '9'
    jbe     .hex_digit
    add     al, 7       ; 'A'-'9'-1
.hex_digit:
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    pop     ax
    loop    .hex_loop
    pop     cx
    pop     ax
    ret

; ---------------------------------------------------------------------------
; INT 0Dh handler - General Protection Fault - always prints
; ---------------------------------------------------------------------------
int0d_handler:
    push    ax
    push    bx
    mov     al, '#'
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    mov     al, '0'
    int     0x10
    mov     al, 'D'
    int     0x10
    mov     al, '#'
    int     0x10
    pop     bx
    pop     ax
    iret

; ---------------------------------------------------------------------------
; INT 33h handler - Mouse driver stub
; Returns "no mouse" for detection, basic stubs for other functions
; ---------------------------------------------------------------------------
int33_handler:
    cmp     ax, 0x0000              ; Function 0: Reset/detect
    je      .reset
    cmp     ax, 0x0021              ; Function 21h: Software reset
    je      .reset
    cmp     ax, 0x0003              ; Function 3: Get position
    je      .get_pos
    cmp     ax, 0x0005              ; Function 5: Get button press
    je      .get_button
    cmp     ax, 0x0006              ; Function 6: Get button release
    je      .get_button
    cmp     ax, 0x000B              ; Function Bh: Get motion counters
    je      .get_motion
    ; All other functions: return with no change
    iret

.reset:
    ; Return AX=0 (no mouse), BX=0 (no buttons)
    xor     ax, ax
    xor     bx, bx
    iret

.get_pos:
    ; Return BX=0 (no buttons), CX=0 (x), DX=0 (y)
    xor     bx, bx
    xor     cx, cx
    xor     dx, dx
    iret

.get_button:
    ; Return AX=0 (no presses), BX=0, CX=0, DX=0
    xor     ax, ax
    xor     bx, bx
    xor     cx, cx
    xor     dx, dx
    iret

.get_motion:
    ; Return CX=0, DX=0 (no motion)
    xor     cx, cx
    xor     dx, dx
    iret

; ---------------------------------------------------------------------------
; init_data_areas - Initialize kernel data structures
; ---------------------------------------------------------------------------
init_data_areas:
    push    es
    push    ax
    push    cx
    push    di

    ; Clear the SFT area
    mov     ax, cs
    mov     es, ax
    mov     di, sft_table
    mov     cx, SFT_ENTRY_SIZE * SFT_SIZE
    xor     al, al
    rep     stosb

    ; Initialize SFT entries 0-4 for standard handles (STDIN/OUT/ERR/AUX/PRN)
    ; Set ref_count = 1 so sft_alloc won't reuse them
    push    ds
    push    cs
    pop     ds                                  ; DS = kernel segment
    mov     di, sft_table
    mov     ax, 1                               ; ref_count = 1
    mov     cx, 5                               ; 5 standard handles
.init_std_sft:
    mov     word [di + SFT_ENTRY.ref_count], ax
    mov     word [di + SFT_ENTRY.flags], 0x80D3 ; Device: STDIN=0x80D3 (CON device flags)
    add     di, SFT_ENTRY_SIZE
    loop    .init_std_sft
    pop     ds

    ; Initialize CDS for drive A:
    mov     di, cds_table
    mov     byte [di + CDS.path], 'A'
    mov     byte [di + CDS.path + 1], ':'
    mov     byte [di + CDS.path + 2], '\'
    mov     byte [di + CDS.path + 3], 0
    mov     word [di + CDS.flags], CDS_VALID | CDS_PHYSICAL
    mov     word [di + CDS.backslash_off], 2

    ; Initialize CDS for RAM disk drive D: (index 3)
    mov     di, cds_table + (CDS_SIZE * 3)
    mov     byte [di + CDS.path], 'D'
    mov     byte [di + CDS.path + 1], ':'
    mov     byte [di + CDS.path + 2], '\'
    mov     byte [di + CDS.path + 3], 0
    mov     word [di + CDS.flags], CDS_VALID | CDS_PHYSICAL
    mov     word [di + CDS.backslash_off], 2
    ; Link CDS to RAM disk DPB
    mov     word [di + CDS.dpb_ptr], dpb_ramdisk
    mov     [di + CDS.dpb_ptr + 2], cs

    ; Set default DTA to PSP:0080h (no PSP yet, use kernel area)
    mov     word [current_dta_off], default_dta
    mov     [current_dta_seg], cs

    ; Set current drive to A: (0)
    mov     byte [current_drive], 0

    ; Set verify flag off
    mov     byte [verify_flag], 0

    ; Set break check off
    mov     byte [break_flag], 0

    pop     di
    pop     cx
    pop     ax
    pop     es
    ret

; ---------------------------------------------------------------------------
; load_shell - Load and execute COMMAND.COM
; Allocates memory via MCB, builds PSP, loads file, jumps to it.
; ---------------------------------------------------------------------------
load_shell:
    push    es

    mov     si, shell_filename
    call    bios_print_string

    ; Find COMMAND.COM in root directory
    mov     si, shell_fcb_name
    call    fat_find_in_root
    jc      .not_found

    ; DI = offset of directory entry in disk_buffer
    ; Get starting cluster and file size
    mov     ax, [di + 26]       ; Starting cluster
    mov     [shell_start_cluster], ax
    mov     ax, [di + 28]       ; File size (low word)
    mov     [shell_file_size], ax

    ; Allocate memory for shell via MCB system
    ; Need: (file_size + 256 (PSP) + 15) / 16 paragraphs
    ; But for .COM, allocate as much as possible (up to 64K)
    mov     bx, 0x1000              ; Request 64K (4096 paragraphs)
    call    mcb_alloc
    jc      .not_found              ; Can't allocate? Treat as not found

    ; AX = allocated segment (PSP segment)
    mov     [shell_psp_seg], ax

    ; Fix MCB owner: mcb_alloc set owner to current_psp which was 0
    ; Set it to the shell's PSP so it's not seen as "free"
    push    es
    mov     bx, ax
    dec     bx                      ; BX = MCB segment (PSP - 1)
    mov     es, bx
    mov     [es:1], ax              ; Set owner = shell PSP
    pop     es

    ; Create environment block for shell
    push    ax                      ; Save PSP segment
    xor     si, si                  ; No source env (use default)
    push    cs
    pop     es
    mov     di, shell_fcb_name_path ; Program path
    call    env_create_with_path
    mov     [shell_env_seg], ax     ; Save environment segment
    pop     ax                      ; Restore PSP segment

    ; Fix environment MCB ownership
    push    es
    push    ax                      ; Save PSP again
    mov     bx, [shell_env_seg]
    dec     bx                      ; MCB segment
    mov     es, bx
    mov     [es:1], ax              ; Owner = shell PSP
    pop     ax
    pop     es

    ; Build PSP using build_psp
    mov     es, ax
    mov     si, shell_empty_tail    ; Point to empty string
    mov     bx, [cs:shell_env_seg]  ; Environment segment
    xor     dx, dx                  ; No parent PSP (shell is the first process)
    call    build_psp

    ; Set memory top in PSP
    mov     ax, [shell_psp_seg]
    mov     es, ax
    ; Memory top = PSP seg + allocated block size + 1
    ; The MCB is at PSP-1, its size field tells us the block size
    push    es
    dec     ax
    mov     es, ax                  ; ES = MCB
    mov     ax, [es:3]              ; Block size in paragraphs
    pop     es
    add     ax, [shell_psp_seg]
    inc     ax                      ; +1 for MCB header
    mov     [es:0x02], ax           ; Set memory top

    ; Set current PSP
    mov     ax, [shell_psp_seg]
    mov     [current_psp], ax

    ; Load COMMAND.COM at PSP:0100h
    mov     es, ax
    mov     bx, 0x0100          ; Offset within segment
    mov     ax, [shell_start_cluster]

.load_cluster:
    push    ax
    call    fat_cluster_to_lba
    call    fat_read_sector     ; Read to ES:BX
    pop     ax
    add     bx, 512

    ; Get next cluster
    call    fat_get_next_cluster
    cmp     ax, [fat_eoc_min]
    jb      .load_cluster

    ; Jump to COMMAND.COM
    mov     si, msg_loading_shell
    call    bios_print_string

    ; Set up segments for .COM program: DS=ES=SS=PSP, SP=FFFEh
    mov     ax, [shell_psp_seg]
    cli
    mov     ds, ax
    mov     es, ax
    mov     ss, ax
    mov     sp, 0xFFFE
    sti

    ; Far jump to shell
    push    ax                  ; Segment
    push    word 0x0100         ; Offset
    retf

.not_found:
    mov     si, msg_no_shell
    call    bios_print_string
    pop     es
    ret

; ---------------------------------------------------------------------------
; init_hard_disk - Probe for hard disk and initialize C: drive
; Probes BIOS for drive 0x80, reads BPB, populates dpb_c and CDS entry
; ---------------------------------------------------------------------------
init_hard_disk:
    pusha
    push    es

    ; Step 1: Probe INT 13h AH=08h to check if drive 0x80 exists
    mov     ah, 0x08
    mov     dl, 0x80
    xor     di, di
    mov     es, di          ; ES:DI = 0000:0000 (required by some BIOSes)
    int     0x13
    jc      .no_hd          ; CF set = no hard disk
    test    dl, dl
    jz      .no_hd          ; DL=0 means no hard disks

    ; Step 2: Read sector 0 (boot sector/BPB) from drive 0x80
    ; We need to temporarily use INT 13h directly since fat_read_sector
    ; uses the active drive which is still A:
    push    cs
    pop     es
    mov     bx, disk_buffer ; Read into disk_buffer

    ; Reset drive first
    xor     ax, ax
    mov     dl, 0x80
    int     0x13

    ; Read sector 0 (CHS 0/0/1)
    mov     ax, 0x0201      ; AH=02 (read), AL=01 (1 sector)
    mov     cx, 0x0001      ; CH=0 (cylinder 0), CL=1 (sector 1)
    mov     dh, 0           ; Head 0
    mov     dl, 0x80        ; First hard disk
    int     0x13
    jc      .no_hd          ; Read failed

    ; Step 3: Validate this is a FAT16 filesystem
    ; Check for boot signature 0x55AA
    cmp     byte [disk_buffer + 510], 0x55
    jne     .no_hd
    cmp     byte [disk_buffer + 511], 0xAA
    jne     .no_hd

    ; Check FS type label at offset 54 ("FAT16   ")
    cmp     byte [disk_buffer + 54], 'F'
    jne     .no_hd
    cmp     byte [disk_buffer + 55], 'A'
    jne     .no_hd
    cmp     byte [disk_buffer + 56], 'T'
    jne     .no_hd
    cmp     byte [disk_buffer + 57], '1'
    jne     .no_hd
    cmp     byte [disk_buffer + 58], '6'
    jne     .no_hd

    ; Step 4: Populate dpb_c from BPB fields
    ; BPB starts at offset 11 in the boot sector
    ; Offset 11: bytes per sector (2 bytes)
    mov     ax, [disk_buffer + 11]
    mov     [dpb_c.bytes_per_sec], ax

    ; Offset 13: sectors per cluster (1 byte)
    mov     al, [disk_buffer + 13]
    dec     al                      ; DPB stores sec_per_clus - 1
    mov     [dpb_c.sec_per_clus], al
    inc     al

    ; Compute cluster shift (log2 of sectors per cluster)
    xor     cl, cl
.shift_loop:
    shr     al, 1
    jz      .shift_done
    inc     cl
    jmp     .shift_loop
.shift_done:
    mov     [dpb_c.clus_shift], cl

    ; Offset 14: reserved sectors (2 bytes)
    mov     ax, [disk_buffer + 14]
    mov     [dpb_c.rsvd_sectors], ax

    ; Offset 16: number of FATs (1 byte)
    mov     al, [disk_buffer + 16]
    mov     [dpb_c.num_fats], al

    ; Offset 17: root entry count (2 bytes)
    mov     ax, [disk_buffer + 17]
    mov     [dpb_c.root_entries], ax

    ; Offset 22: FAT size in sectors (2 bytes)
    mov     ax, [disk_buffer + 22]
    mov     [dpb_c.fat_size], ax

    ; Offset 21: media descriptor byte
    mov     al, [disk_buffer + 21]
    mov     [dpb_c.media_byte], al

    ; Compute root_start = reserved_sectors + num_fats * fat_size
    mov     ax, [dpb_c.rsvd_sectors]
    xor     cx, cx
    mov     cl, [dpb_c.num_fats]
    mov     dx, [dpb_c.fat_size]
.add_fat:
    add     ax, dx
    loop    .add_fat
    mov     [dpb_c.root_start], ax

    ; Compute root_dir_sectors = (root_entries * 32 + 511) / 512
    push    ax                      ; Save root_start
    mov     ax, [dpb_c.root_entries]
    mov     cl, 5                   ; * 32
    shl     ax, cl
    add     ax, 511
    mov     cl, 9                   ; / 512
    shr     ax, cl
    mov     bx, ax                  ; BX = root dir sectors
    pop     ax                      ; AX = root_start

    ; data_start = root_start + root_dir_sectors
    add     ax, bx
    mov     [dpb_c.data_start], ax

    ; Compute max_cluster (total data clusters + 2)
    ; total_sectors: use 32-bit field at offset 32 if 16-bit field at offset 19 is 0
    mov     ax, [disk_buffer + 19]  ; total_sectors_16
    test    ax, ax
    jnz     .have_total
    mov     ax, [disk_buffer + 32]  ; total_sectors_32 (low word only, enough for 32MB)
.have_total:
    sub     ax, [dpb_c.data_start]  ; Data sectors
    ; Divide by sectors per cluster
    xor     cx, cx
    mov     cl, [dpb_c.sec_per_clus]
    inc     cl                      ; sec_per_clus stored as N-1
    xor     dx, dx
    div     cx                      ; AX = number of clusters
    add     ax, 2                   ; Clusters are numbered from 2
    mov     [dpb_c.max_cluster], ax

    ; Compute free cluster count (scan FAT - too slow at boot, mark as unknown)
    mov     word [dpb_c.free_count], 0xFFFF
    mov     word [dpb_c.first_free], 2

    ; Step 5: Initialize CDS entry for C: (index 2)
    mov     di, cds_table + (CDS_SIZE * 2)
    mov     byte [di + CDS.path], 'C'
    mov     byte [di + CDS.path + 1], ':'
    mov     byte [di + CDS.path + 2], '\'
    mov     byte [di + CDS.path + 3], 0
    mov     word [di + CDS.flags], CDS_VALID | CDS_PHYSICAL
    mov     word [di + CDS.backslash_off], 2
    ; Link CDS to dpb_c
    mov     word [di + CDS.dpb_ptr], dpb_c
    mov     [di + CDS.dpb_ptr + 2], cs

    ; Step 6: Link DPB chain: dpb_a.next_dpb -> dpb_c
    mov     word [dpb_a.next_dpb], dpb_c
    mov     [dpb_a.next_dpb + 2], cs

    ; Print success message
    mov     si, msg_hd_detected
    call    bios_print_string

    pop     es
    popa
    ret

.no_hd:
    ; No hard disk or not FAT16 - dpb_c.max_cluster stays 0
    pop     es
    popa
    ret

msg_hd_detected     db  'Hard disk C: detected (FAT16)', 0x0D, 0x0A, 0

; Shell loading data
shell_filename      db  'Loading COMMAND.COM...', 0x0D, 0x0A, 0
shell_fcb_name      db  'COMMAND COM'
msg_loading_shell   db  'Starting command interpreter', 0x0D, 0x0A, 0
msg_no_shell        db  'COMMAND.COM not found', 0x0D, 0x0A, 0
shell_start_cluster dw  0
shell_file_size     dw  0
shell_psp_seg       dw  0
shell_env_seg       dw  0
shell_empty_tail    db  0           ; Empty ASCIIZ string for command tail
shell_fcb_name_path db  'COMMAND.COM', 0  ; Program path for environment

; ---------------------------------------------------------------------------
; Init messages
; ---------------------------------------------------------------------------
msg_init        db  'Initializing kernel...', 0x0D, 0x0A, 0
msg_init_done   db  'Kernel ready.', 0x0D, 0x0A, 0
