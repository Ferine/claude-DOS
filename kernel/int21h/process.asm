; ===========================================================================
; claudeDOS INT 21h Process Functions
; ===========================================================================

; AH=26h - Create New PSP
; Input: DX = segment for new PSP
; Copies current PSP to target segment and initializes it
int21_26:
    push    es
    push    si
    push    bx
    push    dx

    ; Get target segment from caller's DX
    mov     ax, [save_dx]
    mov     es, ax                  ; ES = target segment for new PSP

    ; Set up parameters for build_psp:
    ; DS:SI = pointer to empty command tail (just a 0 byte)
    mov     si, .empty_tail_26

    ; BX = environment segment from current PSP
    push    es
    mov     es, [current_psp]
    mov     bx, [es:0x2C]          ; Environment segment from current PSP
    pop     es

    ; DX = parent PSP segment (current PSP)
    mov     dx, [current_psp]

    ; ES already set to target segment
    call    build_psp

    pop     dx
    pop     bx
    pop     si
    pop     es
    ret

.empty_tail_26  db  0

; AH=4Bh - EXEC (Load and Execute Program / Load Overlay)
; Input: AL = subfunction (00h = load+exec, 03h = load overlay)
;        DS:DX = ASCIIZ program name, ES:BX = parameter block
int21_4B:
    ; Check subfunction
    mov     al, [save_ax]
    cmp     al, 0x03
    je      int21_4B_overlay
    cmp     al, 0x00
    jne     .bad_subfunc
    jmp     .do_exec

.bad_subfunc:
    mov     ax, ERR_INVALID_FUNC
    jmp     dos_set_error

.do_exec:
    ; Save previous exec parent state for nested EXEC support
    ; (e.g. shell execs quake, quake execs cwsdpmi as TSR)
    push    es
    push    si
    push    di
    push    cx
    push    cs
    pop     es
    mov     ax, [exec_parent_ss]
    mov     [exec_parent_ss_prev], ax
    mov     ax, [exec_parent_sp]
    mov     [exec_parent_sp_prev], ax
    mov     ax, [exec_parent_psp]
    mov     [exec_parent_psp_prev], ax
    mov     si, exec_save_area
    mov     di, exec_save_area_prev
    mov     cx, 9
    rep     movsw
    pop     cx
    pop     di
    pop     si
    pop     es

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

    ; Resolve path (handles drive letters, subdirectories, and FCB conversion)
    mov     si, exec_filename
    call    resolve_path            ; AX=dir cluster, fcb_name_buffer=filename
    jc      .exec_not_found

    ; Save directory cluster for later reuse (EXE header read)
    mov     [exec_dir_cluster], ax

    ; Copy resolved FCB name to exec_fcb_name
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

    ; Find the file in the resolved directory
    mov     si, exec_fcb_name
    mov     ax, [exec_dir_cluster]
    call    fat_find_in_directory
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

    ; .COM: allocate ALL available memory (standard DOS behavior)
    ; Programs can shrink their allocation with INT 21h/4Ah if needed
    mov     bx, 0xFFFF              ; Request maximum
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
    mov     ax, [exec_dir_cluster]
    call    fat_find_in_directory   ; Get start cluster (using saved dir)
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
    ; Request maximum memory - mcb_alloc will return largest available in BX if it fails
    mov     bx, 0xFFFF              ; Request max paragraphs
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
    jnc     .env_ok
    jmp     .env_alloc_fail_early
.env_ok:

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
    ; If request fails, mcb_alloc returns largest available in BX - retry with that
    call    mcb_alloc
    jnc     .alloc_ok
    ; First attempt failed - BX now has largest available, retry
    test    bx, bx
    jz      .exec_no_mem_free_env   ; No memory at all
    call    mcb_alloc
    jc      .exec_no_mem_free_env
.alloc_ok:
    ; AX = child segment (after MCB header)
    ; Fix MCB owner: mcb_alloc set owner to current_psp (parent/shell),
    ; but int21_4C frees by child PSP. Update MCB owner to child segment.
    push    es
    push    ax
    dec     ax                      ; AX = MCB segment (one para before block)
    mov     es, ax
    pop     ax                      ; AX = child segment again
    mov     [es:1], ax              ; Set MCB owner to child PSP segment
    pop     es

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

    ; Set PSP memory top (offset 0x02) to top of allocated block
    ; Real DOS sets this to child_seg + MCB block size (first segment past allocation)
    push    ax
    push    dx
    mov     ax, [exec_child_seg]
    dec     ax                      ; AX = MCB segment
    push    es
    mov     es, ax
    mov     dx, [es:3]             ; DX = block size in paragraphs
    pop     es
    mov     ax, [exec_child_seg]
    add     ax, dx                  ; AX = first segment past allocated block
    mov     [es:0x02], ax           ; Set PSP memory top
    pop     dx
    pop     ax

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


; ---------------------------------------------------------------------------
; int21_4B_overlay - EXEC subfunction AL=03h: Load Overlay
; Input: DS:DX = ASCIIZ filename (caller's DS:DX)
;        ES:BX = parameter block:
;          +00h word: load segment
;          +02h word: relocation factor (ignored for raw overlays)
; Output: CF=0 success, CF=1 error (AX=error code)
; ---------------------------------------------------------------------------
int21_4B_overlay:
    push    si
    push    di
    push    bp

    ; Copy filename from caller's DS:DX to exec_filename
    push    es
    mov     ds, [cs:save_ds]
    mov     si, [cs:save_dx]
    push    cs
    pop     es
    mov     di, exec_filename
    mov     cx, 127
.ovl_copy_fn:
    lodsb
    stosb
    test    al, al
    jz      .ovl_fn_done
    loop    .ovl_copy_fn
    mov     byte [es:di], 0
.ovl_fn_done:
    pop     es

    push    cs
    pop     ds                      ; DS = kernel

    ; Read load_segment from caller's param block
    push    es
    mov     es, [save_es]
    mov     bx, [save_bx]
    mov     ax, [es:bx + 0]        ; Load segment
    mov     [.ovl_load_seg], ax
    mov     ax, [es:bx + 2]        ; Relocation factor (saved but unused for raw)
    mov     [.ovl_reloc_factor], ax
    pop     es

    ; Resolve path to find the file
    mov     si, exec_filename
    call    resolve_path
    jc      .ovl_not_found

    ; AX = directory cluster, fcb_name_buffer = filename
    ; Search for the file in that directory
    mov     si, fcb_name_buffer
    call    fat_find_in_directory
    jc      .ovl_not_found

    ; DI = directory entry in disk_buffer
    ; Get starting cluster and file size
    mov     ax, [di + 26]           ; Start cluster
    mov     [.ovl_start_cluster], ax
    mov     ax, [di + 28]           ; File size low
    mov     [.ovl_file_size], ax

    ; Load file cluster by cluster into load_segment:0000
    mov     ax, [.ovl_start_cluster]
    mov     es, [.ovl_load_seg]
    xor     bx, bx                  ; Start at offset 0

.ovl_load_loop:
    cmp     ax, 2
    jb      .ovl_load_done
    cmp     ax, [fat_eoc_min]
    jae     .ovl_load_done

    push    ax
    call    fat_cluster_to_lba
    call    fat_read_sector
    pop     ax
    jc      .ovl_read_error

    add     bx, 512
    jnc     .ovl_no_seg_wrap
    ; BX wrapped around, advance ES by 0x1000 (64KB / 16)
    mov     cx, es
    add     cx, 0x1000
    mov     es, cx
.ovl_no_seg_wrap:

    ; Get next cluster
    call    fat_get_next_cluster
    jmp     .ovl_load_loop

.ovl_load_done:
    ; Check if loaded file is an MZ EXE (needs relocation + header stripping)
    push    ds
    mov     ds, [cs:.ovl_load_seg]
    mov     ax, [0]                 ; First word of loaded file
    pop     ds
    cmp     ax, 0x5A4D              ; 'MZ'
    je      .ovl_is_exe
    cmp     ax, 0x4D5A              ; 'ZM'
    je      .ovl_is_exe
    jmp     .ovl_success            ; Not an EXE, raw load is fine

.ovl_is_exe:
    ; File is MZ EXE - apply relocations and strip header
    ; Read MZ header fields from loaded image at load_seg:0000
    push    ds
    mov     ds, [cs:.ovl_load_seg]

    mov     ax, [0x06]              ; Relocation count
    mov     [cs:.ovl_reloc_count], ax
    mov     ax, [0x08]              ; Header size in paragraphs
    mov     [cs:.ovl_header_paras], ax
    mov     ax, [0x18]              ; Relocation table offset
    mov     [cs:.ovl_reloc_off], ax

    ; Calculate load image size = file_size - (header_paras * 16)
    mov     ax, [cs:.ovl_header_paras]
    mov     cl, 4
    shl     ax, cl                  ; AX = header bytes
    mov     [cs:.ovl_header_bytes], ax

    pop     ds                      ; DS = kernel

    ; Apply relocations
    mov     cx, [.ovl_reloc_count]
    test    cx, cx
    jz      .ovl_no_relocs

    ; Walk relocation table (which is in the loaded image at load_seg:reloc_off)
    push    ds
    mov     ds, [cs:.ovl_load_seg]
    mov     si, [cs:.ovl_reloc_off] ; DS:SI = relocation table in loaded image

.ovl_reloc_loop:
    ; Read relocation entry: offset (word), segment (word)
    lodsw
    mov     di, ax                  ; DI = offset
    lodsw                           ; AX = segment (relative to load module start)

    ; The relocation target is at [load_seg + header_paras + entry_seg : entry_off]
    ; But we'll strip the header later, so the actual fixup target in memory is:
    ; [load_seg + header_paras + entry_seg : entry_off]
    push    ds
    mov     bx, [cs:.ovl_load_seg]
    add     bx, [cs:.ovl_header_paras] ; Skip header to reach load module
    add     ax, bx                  ; AX = absolute segment of fixup target
    mov     ds, ax
    mov     bx, [cs:.ovl_reloc_factor]
    add     [di], bx                ; Apply relocation factor
    pop     ds

    loop    .ovl_reloc_loop

    pop     ds                      ; DS = kernel

.ovl_no_relocs:
    ; Strip MZ header: move load module from load_seg+header_paras to load_seg
    ; Source = load_seg + header_paras : 0
    ; Dest = load_seg : 0
    ; Size = file_size - header_bytes

    mov     ax, [.ovl_file_size]
    sub     ax, [.ovl_header_bytes] ; AX = load module size in bytes
    mov     [.ovl_module_size], ax

    ; Set up source and destination segments
    push    ds
    push    es

    mov     ax, [.ovl_load_seg]
    add     ax, [.ovl_header_paras]
    mov     ds, ax                  ; DS = source (after header)
    mov     es, [cs:.ovl_load_seg]  ; ES = destination (load segment)
    xor     si, si
    xor     di, di
    mov     cx, [cs:.ovl_module_size]
    cld
    rep     movsb                   ; Move load module over header

    pop     es
    pop     ds

.ovl_success:
    ; Restore ES = kernel
    push    cs
    pop     es
    call    dos_clear_error
    pop     bp
    pop     di
    pop     si
    ret

.ovl_not_found:
    push    cs
    pop     es
    mov     ax, ERR_FILE_NOT_FOUND
    jmp     .ovl_error_ret

.ovl_read_error:
    push    cs
    pop     es
    mov     ax, ERR_READ_FAULT

.ovl_error_ret:
    call    dos_set_error
    pop     bp
    pop     di
    pop     si
    ret

; Local data for overlay loading
.ovl_load_seg       dw  0
.ovl_reloc_factor   dw  0
.ovl_start_cluster  dw  0
.ovl_file_size      dw  0
.ovl_reloc_count    dw  0
.ovl_header_paras   dw  0
.ovl_reloc_off      dw  0
.ovl_header_bytes   dw  0
.ovl_module_size    dw  0

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

    ; Close all open file handles owned by the child process
    ; Walk the child's handle table and decrement SFT ref counts
    ; This prevents SFT exhaustion when programs exit with open files
    push    bx                      ; Save parent PSP
    push    ax                      ; Save child PSP

    ; ES = child PSP from above
    ; Get handle count
    mov     cx, [es:0x32]
    test    cx, cx
    jnz     .cleanup_have_count
    mov     cx, MAX_HANDLES
.cleanup_have_count:
    ; Get handle table pointer from PSP
    mov     di, [es:0x34]           ; Handle table offset
    mov     dx, [es:0x36]           ; Handle table segment
    test    dx, dx
    jnz     .cleanup_have_ptr
    mov     dx, es                  ; Default: PSP segment
    mov     di, 0x18                ; Default: offset 0x18
.cleanup_have_ptr:
    push    es
    mov     es, dx                  ; ES:DI = handle table base

    xor     bx, bx                  ; Handle index
.cleanup_loop:
    cmp     bx, cx
    jae     .cleanup_done

    mov     al, [es:di + bx]       ; SFT index for this handle
    cmp     al, 0xFF
    je      .cleanup_next           ; Unused handle slot

    ; Decrement SFT ref count (for all handles, including inherited ones)
    push    ax
    push    di
    push    cx
    push    bx
    xor     ah, ah
    call    sft_dealloc             ; Decrements ref_count, frees SFT if 0
    pop     bx
    pop     cx
    pop     di
    pop     ax

.cleanup_next:
    inc     bx
    jmp     .cleanup_loop

.cleanup_done:
    pop     es                      ; Restore ES = child PSP

    pop     ax                      ; Restore child PSP
    pop     bx                      ; Restore parent PSP

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
    jmp     terminate_common

.halt_system:
    mov     si, msg_prog_exit
    call    bios_print_string
    cli
    hlt
    ret

; ---------------------------------------------------------------------------
; terminate_common - Shared tail for AH=4Ch and AH=31h
; Input: BX = parent PSP segment
; Restores IVT vectors, parent stack, parent register save area
; ---------------------------------------------------------------------------
terminate_common:
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

    ; Restore previous exec parent state (for nested EXEC support)
    ; This ensures the next termination will return to the grandparent
    mov     ax, [exec_parent_ss_prev]
    mov     [exec_parent_ss], ax
    mov     ax, [exec_parent_sp_prev]
    mov     [exec_parent_sp], ax
    mov     ax, [exec_parent_psp_prev]
    mov     [exec_parent_psp], ax
    mov     si, exec_save_area_prev
    mov     di, exec_save_area
    mov     cx, 9
    rep     movsw

    ; Return success to parent (the EXEC call succeeded)
    mov     word [save_ax], 0
    call    dos_clear_error
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
; Input: AL = return code, DX = paragraphs to keep resident
int21_31:
    ; Save return code with TSR termination type
    mov     al, [save_ax]
    mov     ah, 3                   ; AH=3 = Terminate and Stay Resident
    mov     [return_code], ax

    ; Get current PSP and parent PSP
    mov     ax, [current_psp]
    mov     es, ax
    mov     bx, [es:0x16]          ; Parent PSP segment

    ; If parent == current (shell trying to TSR), halt
    cmp     bx, ax
    je      .tsr_halt

    ; DX = paragraphs to keep resident (from caller)
    mov     dx, [save_dx]

    ; Resize the program's MCB to DX paragraphs
    ; ES = current_psp (the block to resize)
    push    bx                      ; Save parent PSP
    mov     bx, dx                  ; BX = new size in paragraphs
    call    mcb_resize
    ; Ignore resize failure - still terminate

    ; Walk MCB chain and free all blocks owned by child PSP
    ; EXCEPT the program's own MCB (the one we just resized)
    mov     dx, [current_psp]       ; DX = child PSP (owner to free)
    mov     ax, [mcb_chain_start]
.tsr_free_loop:
    mov     es, ax

    ; Check signature
    cmp     byte [es:0], 'M'
    je      .tsr_check_owner
    cmp     byte [es:0], 'Z'
    je      .tsr_check_owner_last
    jmp     .tsr_free_done          ; Invalid MCB, stop

.tsr_check_owner:
    cmp     [es:1], dx              ; Owned by child?
    jne     .tsr_next_mcb
    ; Check if this is the program's own block (segment after MCB == child PSP)
    mov     cx, ax
    inc     cx                      ; CX = block segment (after MCB)
    cmp     cx, dx                  ; Is it the program's own block?
    je      .tsr_next_mcb           ; Yes, keep it resident
    mov     word [es:1], 0          ; Free it (environment, etc.)
.tsr_next_mcb:
    mov     cx, [es:3]
    inc     cx
    add     ax, cx                  ; Next MCB = current + 1 + size
    jmp     .tsr_free_loop

.tsr_check_owner_last:
    cmp     [es:1], dx
    jne     .tsr_free_done
    mov     cx, ax
    inc     cx
    cmp     cx, dx
    je      .tsr_free_done          ; Program's own block, keep it
    mov     word [es:1], 0          ; Free it
.tsr_free_done:
    pop     bx                      ; BX = parent PSP
    jmp     terminate_common

.tsr_halt:
    mov     si, msg_prog_exit
    call    bios_print_string
    cli
    hlt
    ret

msg_prog_exit   db  'Program exit.', 0x0D, 0x0A, 0
