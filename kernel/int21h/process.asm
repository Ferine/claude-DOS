; ===========================================================================
; claudeDOS INT 21h Process Functions
; ===========================================================================

; AH=4Bh - EXEC (Load and Execute Program)
; Input: DS:DX = ASCIIZ program name, ES:BX = parameter block
int21_4B:
    ; Save parent context
    mov     [exec_parent_ss], ss
    mov     [exec_parent_sp], sp
    mov     ax, [current_psp]
    mov     [exec_parent_psp], ax

    ; Save the parent's register save area (so 4Ch can restore it)
    push    es
    push    si
    push    di
    push    cx
    push    cs
    pop     es                      ; ES = kernel segment (required for rep movsw)
    mov     si, save_ax
    mov     di, exec_save_area
    mov     cx, 9                   ; 9 words (ax,bx,cx,dx,si,di,bp,ds,es)
    rep     movsw
    pop     cx
    pop     di
    pop     si
    pop     es

    ; Copy filename from caller's DS:DX to exec_filename
    push    es
    push    si
    push    di

    mov     ds, [cs:save_ds]
    mov     si, [cs:save_dx]
    push    cs
    pop     es
    mov     di, exec_filename
    mov     cx, 127
.copy_fn:
    lodsb
    stosb
    test    al, al
    jz      .fn_done
    loop    .copy_fn
    mov     byte [es:di], 0
.fn_done:
    push    cs
    pop     ds                      ; Restore DS = kernel

    pop     di
    pop     si
    pop     es

    ; Convert filename to FCB name
    mov     si, exec_filename
    call    fat_name_to_fcb
    ; Copy to exec_fcb_name (need ES=kernel for rep movsb)
    push    si
    push    di
    push    cx
    push    es
    push    ds
    pop     es                      ; ES = kernel segment
    mov     si, fcb_name_buffer
    mov     di, exec_fcb_name
    mov     cx, 11
    rep     movsb
    pop     es
    pop     cx
    pop     di
    pop     si

    ; Find the file to get its size
    mov     si, exec_fcb_name
    call    fat_find_in_root
    jc      .exec_not_found

    ; DI = dir entry in disk_buffer
    mov     ax, [di + 28]           ; File size low
    mov     dx, [di + 30]           ; File size high
    ; For file_size: we'll use just low word for paragraph calc
    ; (files > 64K need high word too)

    ; Determine if .EXE by checking first two bytes of file
    ; The extension in FCB name can also help
    ; Check extension: bytes 8-10 of exec_fcb_name
    cmp     byte [exec_fcb_name + 8], 'E'
    jne     .is_com
    cmp     byte [exec_fcb_name + 9], 'X'
    jne     .is_com
    cmp     byte [exec_fcb_name + 10], 'E'
    jne     .is_com
    mov     byte [exec_is_exe], 1
    jmp     .calc_size

.is_com:
    mov     byte [exec_is_exe], 0

.calc_size:
    ; Calculate paragraphs needed: (file_size + 15) / 16 + 16 (PSP) + 16 (stack margin)
    ; For .COM files, allocate enough for 64K (standard)
    ; For .EXE files, read header to get memory requirements

    cmp     byte [exec_is_exe], 1
    je      .exe_size

    ; .COM: allocate 0x1000 paragraphs (64K) if available, or max available
    mov     bx, 0x1000              ; 64K in paragraphs
    jmp     .do_alloc

.exe_size:
    ; .EXE: Need to read MZ header to get memory requirements
    ; The load size comes from the MZ header (page count), NOT file size!
    ; This is important for EXEs with overlays or DOS extender code.

    ; Read first sector of EXE file to get header
    push    es
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     si, exec_fcb_name
    call    fat_find_in_root        ; Get start cluster
    jc      .exe_size_error
    mov     ax, [di + 26]           ; Start cluster
    mov     [exec_start_cluster], ax
    call    fat_cluster_to_lba
    call    fat_read_sector
    pop     es
    jc      .exe_size_error_nostack

    ; Verify MZ signature
    cmp     word [disk_buffer], 0x5A4D
    jne     .exe_size_error_nostack

    ; Read header fields
    mov     ax, [disk_buffer + 0x02]    ; e_cblp: bytes on last page
    mov     [.exe_last_page], ax
    mov     ax, [disk_buffer + 0x04]    ; e_cp: page count (512-byte pages)
    mov     [.exe_page_count], ax
    mov     cx, [disk_buffer + 0x08]    ; e_cparhdr: header paragraphs
    mov     bx, [disk_buffer + 0x0A]    ; e_minalloc: min extra paragraphs
    mov     [exec_min_alloc], bx
    mov     bx, [disk_buffer + 0x0C]    ; e_maxalloc: max extra paragraphs
    mov     [exec_max_alloc], bx

    ; Calculate load size from MZ header (not file size!)
    ; if e_cblp == 0: load_size = e_cp * 512
    ; else: load_size = (e_cp - 1) * 512 + e_cblp
    mov     ax, [.exe_page_count]
    cmp     word [.exe_last_page], 0
    je      .full_pages
    dec     ax                          ; (e_cp - 1)
.full_pages:
    ; AX = number of full 512-byte pages
    ; Multiply by 512: shift left 9 bits (AX * 512 -> DX:AX)
    xor     dx, dx
    mov     cl, 9
    shl     ax, cl                      ; AX = (pages * 512) low word
    ; For our purposes, DX stays 0 (load < 64KB for this calculation)

    ; Add last page bytes if non-zero
    cmp     word [.exe_last_page], 0
    je      .no_last_page
    add     ax, [.exe_last_page]
.no_last_page:
    ; AX = total load image size in bytes

    ; Subtract header size (header_paras * 16)
    push    cx
    mov     cx, [disk_buffer + 0x08]    ; Header paragraphs
    shl     cx, 4                       ; * 16 = header bytes
    sub     ax, cx
    pop     cx
    ; AX = load module size in bytes (excluding header)

    ; Convert to paragraphs: (size + 15) / 16
    add     ax, 15
    shr     ax, 4                       ; AX = load paragraphs
    mov     [exec_load_paras], ax

    ; DOS behavior: allocate MAX_ALLOC if possible, else largest available
    ; Total memory = PSP (16) + load_paras + max_alloc
    add     ax, 0x10                ; + PSP
    mov     bx, [exec_max_alloc]
    cmp     bx, 0xFFFF              ; 0xFFFF means "all available memory"
    je      .use_max_mem
    ; Use specified max_alloc
    add     ax, bx                  ; + max_alloc extra
    mov     bx, ax
    jmp     .do_alloc

.use_max_mem:
    ; Request a large amount (0x1000 = 64K paragraphs = 1MB) to get all available
    ; mcb_alloc will give us the largest available block
    mov     bx, 0x1000              ; Request 64K paragraphs (1MB)
    jmp     .do_alloc

.exe_size_error:
    pop     es
.exe_size_error_nostack:
    mov     ax, ERR_READ_FAULT
    jmp     dos_set_error

; Local variables for EXE size calculation
.exe_page_count dw  0
.exe_last_page  dw  0

.do_alloc:
    ; IMPORTANT: Allocate environment FIRST, then child memory
    ; This ensures environment is at a lower segment and won't be
    ; overwritten when the program is loaded into child memory.

    ; Save child size request for later
    mov     [cs:.child_size_req], bx

    ; =========== STEP 1: Parse param block to get source environment ===========
    push    ds
    mov     ds, [cs:save_es]
    mov     si, [cs:save_bx]        ; DS:SI = param block

    ; Get environment segment from param block
    mov     ax, [si + 0]            ; Environment segment (or 0)
    mov     [cs:.tmp_env], ax

    ; Get command tail pointer
    mov     ax, [si + 4]            ; Command tail segment
    mov     [cs:.tmp_tail_seg], ax
    mov     ax, [si + 2]            ; Command tail offset
    mov     [cs:.tmp_tail_off], ax

    pop     ds                      ; DS = kernel

    ; Determine source environment segment
    mov     bx, [cs:.tmp_env]
    test    bx, bx
    jnz     .has_src_env
    ; No env specified - inherit from parent
    push    es
    mov     es, [cs:exec_parent_psp]
    mov     bx, [es:0x2C]           ; Inherit parent's env
    pop     es
.has_src_env:
    ; BX = source environment segment
    mov     [cs:.src_env_seg], bx

    ; =========== STEP 2: Allocate environment block FIRST ===========
    ; This ensures it's at a lower segment than the child

    mov     si, bx                  ; SI = source environment segment
    push    cs
    pop     es
    mov     di, exec_filename       ; ES:DI = program filename
    call    env_create_with_path
    jc      .env_alloc_fail_early

    ; AX = new environment segment
    mov     [exec_child_env], ax

    ; =========== STEP 3: Allocate child memory ===========
    mov     bx, [cs:.child_size_req]

    ; DEBUG: print requested allocation size
    cmp     byte [cs:debug_trace], 0
    je      .skip_alloc_debug
    push    ax
    push    bx
    mov     al, 'A'
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    pop     bx
    push    bx
    mov     ax, bx
    call    .print_hex_ax
    mov     al, ' '
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    pop     bx
    pop     ax
.skip_alloc_debug:

    ; Allocate memory for child
    call    mcb_alloc
    jc      .exec_no_mem_free_env

    ; DEBUG: print returned segment
    cmp     byte [cs:debug_trace], 0
    je      .skip_ret_seg_debug
    push    ax
    push    bx
    mov     bx, ax              ; Save returned segment
    mov     al, '*'
    mov     ah, 0x0E
    push    bx
    xor     bx, bx
    int     0x10
    pop     ax                  ; AX = returned segment
    call    .print_hex_ax
    mov     al, ' '
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    pop     bx
    pop     ax
.skip_ret_seg_debug:

    ; AX = child segment (after MCB)
    mov     [exec_child_seg], ax

    ; =========== STEP 4: Build PSP ===========
    push    es
    mov     es, ax                  ; ES = child PSP segment

    ; Fix environment MCB ownership: set owner to child PSP
    push    es
    push    ax
    mov     ax, [exec_child_env]
    dec     ax                      ; AX = env MCB segment
    mov     es, ax
    mov     ax, [exec_child_seg]
    mov     [es:1], ax              ; Set owner to child PSP
    pop     ax
    pop     es

    ; Build PSP with new environment
    ; ES = child PSP segment
    ; DS:SI = command tail

    push    ds
    mov     ds, [cs:.tmp_tail_seg]
    mov     si, [cs:.tmp_tail_off]
    inc     si                      ; Skip length byte
    mov     bx, [cs:exec_child_env] ; Environment segment
    mov     dx, [cs:exec_parent_psp] ; Parent PSP
    call    build_psp
    pop     ds                      ; DS = kernel

    ; Set PSP memory top (offset 0x02) to end of allocated block
    ; MCB is at (exec_child_seg - 1), size is at MCB offset 3

    push    ds
    mov     ax, [cs:exec_child_seg]
    dec     ax                      ; AX = MCB segment
    mov     ds, ax
    mov     ax, [ds:3]              ; MCB size
    pop     ds
    add     ax, [cs:exec_child_seg] ; AX = end of block (segment after last paragraph)
    mov     [es:0x02], ax           ; Set PSP memory top

    ; Save parent's INT 22h/23h/24h vectors into child PSP
    push    es
    xor     ax, ax
    mov     ds, ax                  ; DS = IVT segment

    ; INT 22h vector (offset 0x88, 0x8A)
    mov     ax, [ds:0x88]           ; INT 22h offset
    mov     [es:0x0A], ax
    mov     ax, [ds:0x8A]           ; INT 22h segment
    mov     [es:0x0C], ax

    ; INT 23h vector (offset 0x8C, 0x8E)
    mov     ax, [ds:0x8C]
    mov     [es:0x0E], ax
    mov     ax, [ds:0x8E]
    mov     [es:0x10], ax

    ; INT 24h vector (offset 0x90, 0x92)
    mov     ax, [ds:0x90]
    mov     [es:0x12], ax
    mov     ax, [ds:0x92]
    mov     [es:0x14], ax

    pop     es
    push    cs
    pop     ds                      ; DS = kernel again

    ; Load program
    mov     si, exec_fcb_name

    cmp     byte [exec_is_exe], 1
    je      .load_exe_prog

    ; --- Load .COM ---
    mov     ax, [exec_child_seg]
    call    load_com
    jc      .exec_load_fail

    ; Set current_psp to child
    mov     ax, [exec_child_seg]
    mov     [current_psp], ax

    ; Transfer control to .COM program
    ; CLI, set SS:SP, push return address, STI, set segments, far jump
    cli
    mov     ax, [exec_child_seg]
    mov     ss, ax
    mov     sp, 0xFFFE
    push    word 0x0000             ; Return addr -> PSP:0000 = INT 20h
    sti

    mov     ds, ax
    mov     es, ax

    ; Set up registers as per DOS convention (FreeDOS compatible)
    ; AX = BX = FCB validity (0=both valid for now)
    xor     ax, ax
    xor     bx, bx

    ; CX = 0x00FF (DOS convention)
    mov     cx, 0x00FF

    ; SI = entry point offset
    mov     si, COM_LOAD_OFFSET     ; 0x0100

    ; DI = stack pointer
    mov     di, 0xFFFE

    ; BP = 0x091E (high byte 0x09 - some programs check this!)
    mov     bp, 0x091E

    ; Far jump to child_seg:0100h
    ; We use a retf trick: push seg, push offset, retf
    ; IMPORTANT: Use cs: prefix since DS is now the child segment!
    push    word [cs:exec_child_seg]   ; Segment
    push    word COM_LOAD_OFFSET       ; Offset (0x0100)
    retf

.load_exe_prog:
    ; --- Load .EXE ---
    mov     ax, [exec_child_seg]
    add     ax, 0x10                ; Load segment = PSP + 10h (256 bytes)
    call    load_exe
    jc      .exec_load_fail

    ; Set current_psp to child
    mov     ax, [exec_child_seg]
    mov     [current_psp], ax

    ; Transfer control to .EXE program
    ; exec_init_cs/ss already have load_seg added by load_exe

    ; DEBUG: print EXE entry point and stack info
    cmp     byte [cs:debug_trace], 0
    je      .skip_exe_entry_debug
    push    ax
    push    bx
    ; Print CS:IP
    mov     al, 'E'
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    mov     al, 'X'
    int     0x10
    mov     al, 'E'
    int     0x10
    mov     al, ' '
    int     0x10
    mov     ax, [cs:exec_init_cs]
    call    .print_hex_ax
    mov     al, ':'
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    mov     ax, [cs:exec_init_ip]
    call    .print_hex_ax
    mov     al, ' '
    mov     ah, 0x0E
    int     0x10
    mov     al, 'S'
    int     0x10
    mov     al, 'S'
    int     0x10
    mov     al, ':'
    int     0x10
    mov     ax, [cs:exec_init_ss]
    call    .print_hex_ax
    mov     al, ':'
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    mov     ax, [cs:exec_init_sp]
    call    .print_hex_ax
    mov     al, ' '
    mov     ah, 0x0E
    int     0x10
    ; Print memory top from PSP
    mov     al, 'M'
    int     0x10
    mov     al, 'T'
    int     0x10
    mov     al, ':'
    int     0x10
    push    es
    mov     es, [cs:exec_child_seg]
    mov     ax, [es:0x02]
    pop     es
    call    .print_hex_ax
    mov     al, 0x0D
    mov     ah, 0x0E
    int     0x10
    mov     al, 0x0A
    int     0x10
    pop     bx
    pop     ax
.skip_exe_entry_debug:

    cli

    ; SS:SP from exec_init values (already absolute)
    mov     ss, [exec_init_ss]
    mov     sp, [exec_init_sp]
    sti

    ; Set up registers as per DOS convention (FreeDOS compatible)
    ; DS = ES = PSP segment
    mov     ax, [exec_child_seg]
    mov     ds, ax
    mov     es, ax

    ; AX = BX = FCB validity (0=both valid for now)
    xor     ax, ax
    xor     bx, bx

    ; CX = 0x00FF (DOS convention)
    mov     cx, 0x00FF

    ; SI = entry point offset
    mov     si, [cs:exec_init_ip]

    ; DI = stack pointer
    mov     di, [cs:exec_init_sp]

    ; BP = 0x091E (high byte 0x09 - some programs check this!)
    mov     bp, 0x091E

    ; Far jump to exec_init_cs : exec_init_ip (CS already absolute)
    push    word [cs:exec_init_cs]
    push    word [cs:exec_init_ip]
    retf

.env_alloc_fail_early:
    ; Environment allocation failed before child was allocated
    ; Nothing to clean up, just return error
    jmp     .exec_no_mem

.exec_no_mem_free_env:
    ; Child allocation failed after environment was allocated
    ; Free the environment block
    push    es
    mov     es, [exec_child_env]
    call    mcb_free
    pop     es
    jmp     .exec_no_mem

.env_alloc_fail:
    ; Environment allocation failed - free child memory and return error
    ; (This is for the OLD code path - now unused but kept for safety)
    push    es
    mov     es, [exec_child_seg]
    call    mcb_free
    pop     es
    jmp     .exec_no_mem

.exec_not_found:
    ; Restore parent context
    mov     ss, [exec_parent_ss]
    mov     sp, [exec_parent_sp]
    mov     ax, [exec_parent_psp]
    mov     [current_psp], ax
    mov     ax, ERR_FILE_NOT_FOUND
    jmp     dos_set_error

.exec_no_mem:
    mov     ss, [exec_parent_ss]
    mov     sp, [exec_parent_sp]
    mov     ax, [exec_parent_psp]
    mov     [current_psp], ax
    mov     ax, ERR_INSUFFICIENT_MEM
    jmp     dos_set_error

.exec_load_fail:
    ; Free child memory and environment
    push    ax                      ; Save error code
    push    es

    ; Free environment block if it was allocated
    mov     ax, [exec_child_env]
    test    ax, ax
    jz      .skip_env_free
    mov     es, ax
    call    mcb_free
    mov     word [exec_child_env], 0
.skip_env_free:

    ; Free child PSP/program block
    mov     es, [exec_child_seg]
    call    mcb_free
    pop     es
    pop     ax

    mov     ss, [exec_parent_ss]
    mov     sp, [exec_parent_sp]
    mov     bx, [exec_parent_psp]
    mov     [current_psp], bx
    jmp     dos_set_error

; Temporary storage for param block parsing
.tmp_env        dw  0
.tmp_tail_seg   dw  0
.tmp_tail_off   dw  0
.child_size_req dw  0
.src_env_seg    dw  0

; Debug helper: print AX as 4-digit hex
.print_hex_ax:
    push    ax
    push    bx
    push    cx
    mov     cx, 4
.pha_loop:
    rol     ax, 4
    push    ax
    and     al, 0x0F
    add     al, '0'
    cmp     al, '9'
    jbe     .pha_print
    add     al, 7
.pha_print:
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    pop     ax
    loop    .pha_loop
    pop     cx
    pop     bx
    pop     ax
    ret

; AH=4Ch - Terminate with Return Code
; Input: AL = return code
int21_4C:
    ; Save return code
    mov     al, [save_ax]
    xor     ah, ah
    mov     [return_code], ax

    ; Get current PSP and parent PSP
    mov     ax, [current_psp]
    mov     es, ax
    mov     bx, [es:0x16]          ; Parent PSP segment

    ; If parent == current (shell trying to exit), halt
    cmp     bx, ax
    je      .halt_system

    ; Free child memory: walk MCB chain, free all blocks owned by current
    push    bx                      ; Save parent PSP
    mov     dx, ax                  ; DX = child PSP (owner to free)

    mov     ax, [mcb_chain_start]
.free_loop:
    mov     es, ax

    ; Check signature
    cmp     byte [es:0], 'M'
    je      .check_owner
    cmp     byte [es:0], 'Z'
    je      .check_owner_last
    jmp     .free_done              ; Invalid MCB, stop

.check_owner:
    cmp     [es:1], dx              ; Owned by child?
    jne     .next_mcb
    mov     word [es:1], 0          ; Free it
.next_mcb:
    mov     cx, [es:3]
    inc     cx
    add     ax, cx                  ; Next MCB = current + 1 + size
    jmp     .free_loop

.check_owner_last:
    cmp     [es:1], dx
    jne     .free_done
    mov     word [es:1], 0          ; Free it
.free_done:
    pop     bx                      ; BX = parent PSP

    ; Restore INT 22h/23h/24h from child PSP back to IVT
    mov     es, [current_psp]       ; Child PSP
    push    ds
    xor     ax, ax
    mov     ds, ax                  ; DS = IVT

    ; INT 22h
    mov     ax, [es:0x0A]
    mov     [ds:0x88], ax
    mov     ax, [es:0x0C]
    mov     [ds:0x8A], ax

    ; INT 23h
    mov     ax, [es:0x0E]
    mov     [ds:0x8C], ax
    mov     ax, [es:0x10]
    mov     [ds:0x8E], ax

    ; INT 24h
    mov     ax, [es:0x12]
    mov     [ds:0x90], ax
    mov     ax, [es:0x14]
    mov     [ds:0x92], ax

    pop     ds

    ; Set current PSP to parent
    mov     [current_psp], bx

    ; Restore parent's SS:SP
    cli
    mov     ss, [exec_parent_ss]
    mov     sp, [exec_parent_sp]
    sti

    ; We're now back on the parent's stack, which was saved when EXEC
    ; was called. The parent entered INT 21h, which saved registers.
    ; We need to restore the parent's saved register area and set up
    ; a success return through the normal INT 21h return path.
    push    cs
    pop     ds                      ; DS = kernel
    push    cs
    pop     es                      ; ES = kernel (required for rep movsw)

    ; Restore parent's register save area
    mov     si, exec_save_area
    mov     di, save_ax
    mov     cx, 9
    rep     movsw

    ; Return success to parent (the EXEC call succeeded)
    mov     word [save_ax], 0
    call    dos_clear_error
    ret

.halt_system:
    mov     si, msg_prog_exit
    call    bios_print_string
    cli
    hlt
    ret

; AH=4Dh - Get Return Code
; Output: AX = return code (AL=code, AH=termination type)
int21_4D:
    mov     ax, [return_code]
    mov     [save_ax], ax
    mov     word [return_code], 0  ; Clear after reading
    call    dos_clear_error
    ret

; AH=31h - Terminate and Stay Resident (TSR)
; Input: AL = return code, DX = paragraphs to keep
int21_31:
    ; Stub
    mov     al, [save_ax]
    xor     ah, ah
    mov     [return_code], ax
    cli
    hlt
    ret

msg_prog_exit   db  'Program exit.', 0x0D, 0x0A, 0
