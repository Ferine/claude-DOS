; ===========================================================================
; claudeDOS INT 21h File I/O Functions (AH=3Ch-46h, 56h-57h, 5Bh, 6Ch)
; ===========================================================================

; ===========================================================================
; SFT Helper Routines
; ===========================================================================

; ---------------------------------------------------------------------------
; sft_alloc - Allocate a free SFT entry
; Output: DI = pointer to SFT entry, AX = SFT index, CF clear
;         CF set if all entries in use
; ---------------------------------------------------------------------------
sft_alloc:
    push    cx
    push    bx

    mov     di, sft_table
    xor     ax, ax                  ; SFT index

.scan:
    cmp     ax, SFT_SIZE
    jae     .full

    cmp     word [di + SFT_ENTRY.ref_count], 0
    je      .found

    add     di, SFT_ENTRY_SIZE
    inc     ax
    jmp     .scan

.found:
    mov     word [di + SFT_ENTRY.ref_count], 1
    clc
    pop     bx
    pop     cx
    ret

.full:
    stc
    pop     bx
    pop     cx
    ret

; ---------------------------------------------------------------------------
; sft_dealloc - Deallocate an SFT entry
; Input: AX = SFT index
; ---------------------------------------------------------------------------
sft_dealloc:
    push    di
    push    cx
    push    es

    call    sft_get
    jc      .done

    dec     word [di + SFT_ENTRY.ref_count]
    jnz     .done

    ; Zero the entry
    push    ax
    push    cs
    pop     es                      ; ES = kernel segment for stosb
    mov     cx, SFT_ENTRY_SIZE
    xor     al, al
    rep     stosb
    pop     ax

.done:
    pop     es
    pop     cx
    pop     di
    ret

; ---------------------------------------------------------------------------
; sft_get - Get pointer to SFT entry by index
; Input: AX = SFT index
; Output: DI = pointer to SFT entry, CF clear
;         CF set if index out of range
; ---------------------------------------------------------------------------
sft_get:
    cmp     ax, SFT_SIZE
    jae     .bad

    push    dx
    push    ax
    mov     dx, SFT_ENTRY_SIZE
    mul     dx                      ; AX = index * entry_size
    mov     di, sft_table
    add     di, ax
    pop     ax
    pop     dx
    clc
    ret

.bad:
    stc
    ret

; ===========================================================================
; PSP Handle Helpers
; ===========================================================================

; ---------------------------------------------------------------------------
; handle_alloc - Allocate a handle in current PSP's handle table
; Input: CL = SFT index to store
; Output: AX = handle number, CF clear
;         CF set if handle table full
; Uses PSP:0x32 for handle count, PSP:0x34 for handle table pointer
; ---------------------------------------------------------------------------
handle_alloc:
    push    es
    push    di
    push    cx
    push    bx

    mov     es, [current_psp]

    ; Get handle count from PSP:0x32
    mov     bx, [es:0x32]
    test    bx, bx
    jnz     .have_count
    mov     bx, MAX_HANDLES         ; Default if not set
.have_count:

    ; Get handle table pointer from PSP:0x34
    mov     di, [es:0x34]           ; Offset
    mov     ax, [es:0x36]           ; Segment
    test    ax, ax
    jnz     .have_ptr
    ; Not set - use default PSP:0x18
    mov     ax, es
    mov     di, 0x18
.have_ptr:
    mov     es, ax                  ; ES:DI = handle table
    xor     ax, ax                  ; Handle number

.scan:
    cmp     ax, bx
    jae     .full

    cmp     byte [es:di], 0xFF
    je      .found

    inc     di
    inc     ax
    jmp     .scan

.found:
    mov     [es:di], cl             ; Store SFT index
    clc
    pop     bx
    pop     cx
    pop     di
    pop     es
    ret

.full:
    stc
    pop     bx
    pop     cx
    pop     di
    pop     es
    ret

; ---------------------------------------------------------------------------
; handle_to_sft - Convert handle to SFT entry pointer
; Input: BX = handle number
; Output: DI = pointer to SFT entry, AL = SFT index, CF clear
;         CF set if invalid handle
; Uses PSP:0x32 for handle count, PSP:0x34 for handle table pointer
; ---------------------------------------------------------------------------
handle_to_sft:
    push    es
    push    dx

    mov     es, [current_psp]

    ; Get handle count from PSP:0x32
    mov     dx, [es:0x32]
    test    dx, dx
    jnz     .have_count
    mov     dx, MAX_HANDLES         ; Default if not set
.have_count:
    cmp     bx, dx
    jae     .bad

    ; Get handle table pointer from PSP:0x34
    mov     di, [es:0x34]           ; Offset
    mov     ax, [es:0x36]           ; Segment
    test    ax, ax
    jnz     .have_ptr
    ; Not set - use default PSP:0x18
    mov     ax, es
    mov     di, 0x18
.have_ptr:
    mov     es, ax                  ; ES:DI = handle table base
    mov     al, [es:di + bx]       ; Get SFT index from handle table

    cmp     al, 0xFF
    je      .bad

    push    ax
    xor     ah, ah
    call    sft_get
    pop     ax
    jc      .bad

    pop     dx
    pop     es
    clc
    ret

.bad:
    pop     dx
    pop     es
    stc
    ret

; ===========================================================================
; INT 21h File I/O Functions
; ===========================================================================

; AH=3Ch - Create file
; Input: DS:DX = ASCIIZ filename, CX = attribute
int21_3C:
    mov     byte [cs:create_exclusive], 0   ; Normal create - truncate if exists
    jmp     short int21_3C_common

; AH=5Bh - Create new file (exclusive - fail if exists)
; Input: DS:DX = ASCIIZ filename, CX = attribute
; Output: CF clear, AX = handle on success
;         CF set, AX = error code on failure
int21_5B_impl:
    mov     byte [cs:create_exclusive], 1   ; Exclusive create - fail if exists

int21_3C_common:
    push    es
    push    si
    push    di
    push    bx
    push    cx
    push    dx

    ; Copy filename from caller's DS:DX to path_buffer
    push    ds
    mov     ds, [cs:save_ds]
    mov     si, [cs:save_dx]
    push    cs
    pop     es
    mov     di, path_buffer
    mov     cx, 127
.cr_copy:
    lodsb
    stosb
    test    al, al
    jz      .cr_copied
    loop    .cr_copy
    mov     byte [es:di], 0
.cr_copied:
    pop     ds                      ; DS = kernel seg

    ; Resolve path to get directory cluster and filename
    mov     si, path_buffer
    call    resolve_path
    jc      .cr_path_not_found

    ; AX = directory cluster, fcb_name_buffer = filename
    ; Save target directory cluster for later use
    mov     [create_dir_cluster], ax

    ; Check if file already exists
    mov     si, fcb_name_buffer
    call    fat_find_in_directory
    jnc     .cr_truncate            ; File exists - truncate it

    ; File doesn't exist - create new directory entry
    ; Check if creating in root or subdirectory
    mov     ax, [create_dir_cluster]
    test    ax, ax
    jnz     .cr_scan_subdir

    ; Root directory: scan from DPB
    call    fat_get_root_params     ; AX = root_start, CX = root_sectors

.cr_scan_sector:
    push    cx
    push    ax

    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_read_sector
    jc      .cr_read_error

    ; Search for empty entry (0x00 or 0xE5)
    mov     di, disk_buffer
    xor     cx, cx                  ; Entry index within sector

.cr_scan_entry:
    cmp     cx, 16
    jae     .cr_next_sector

    cmp     byte [di], 0x00         ; End of dir
    je      .cr_found_slot
    cmp     byte [di], 0xE5         ; Deleted entry
    je      .cr_found_slot

    add     di, 32
    inc     cx
    jmp     .cr_scan_entry

.cr_next_sector:
    pop     ax
    pop     cx
    inc     ax
    loop    .cr_scan_sector

    ; No space in directory
    jmp     .cr_dir_full

.cr_found_slot:
    ; AX (on stack) = sector number, CX = entry index, DI = entry pointer
    pop     ax                      ; Sector number
    mov     [search_dir_sector], ax
    mov     [search_dir_index], cx
    pop     cx                      ; Restore outer CX
    jmp     .cr_init_entry

.cr_scan_subdir:
    ; Subdirectory: walk cluster chain looking for empty slot
    mov     dx, ax                  ; DX = current cluster
.cr_subdir_loop:
    mov     ax, dx
    call    fat_cluster_to_lba
    push    dx                      ; Save current cluster
    push    ax                      ; Save sector number
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_read_sector
    pop     ax                      ; Restore sector number
    pop     dx                      ; Restore current cluster
    jc      .cr_read_error_nostack

    ; Search 16 entries per sector
    mov     di, disk_buffer
    xor     cx, cx
.cr_subdir_entry:
    cmp     cx, 16
    jae     .cr_subdir_next_cluster
    cmp     byte [di], 0x00         ; Empty
    je      .cr_found_subdir_slot
    cmp     byte [di], 0xE5         ; Deleted
    je      .cr_found_subdir_slot
    add     di, 32
    inc     cx
    jmp     .cr_subdir_entry

.cr_subdir_next_cluster:
    ; Move to next cluster in chain
    mov     ax, dx
    call    fat_get_next_cluster
    mov     dx, ax
    cmp     dx, [fat_eoc_min]
    jb      .cr_subdir_loop
    jmp     .cr_dir_full            ; Directory full, no empty slots

.cr_found_subdir_slot:
    ; Found empty slot: DX = cluster, CX = entry index, DI = entry pointer
    mov     ax, dx
    call    fat_cluster_to_lba
    mov     [search_dir_sector], ax
    mov     [search_dir_index], cx

.cr_init_entry:

    ; Initialize directory entry
    ; Copy FCB name
    push    di
    mov     si, fcb_name_buffer
    mov     cx, 11
    rep     movsb
    pop     di

    ; Set attribute (from saved CX)
    mov     ax, [save_cx]
    mov     [di + 11], al

    ; Zero out reserved bytes and other fields
    xor     ax, ax
    mov     [di + 12], ax           ; Reserved
    mov     [di + 14], ax           ; Reserved
    mov     [di + 16], ax           ; Reserved
    mov     [di + 18], ax           ; Reserved
    mov     [di + 20], ax           ; Reserved

    ; Set time/date from RTC
    push    di
    call    get_dos_datetime        ; CX = packed time, DX = packed date
    pop     di
    mov     [di + 22], cx           ; Time
    mov     [di + 24], dx           ; Date

    ; First cluster = 0 (no data yet)
    xor     ax, ax
    mov     [di + 26], ax

    ; File size = 0
    mov     [di + 28], ax
    mov     [di + 30], ax

    ; Write directory sector back
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [search_dir_sector]
    call    fat_write_sector
    jc      .cr_write_error

    jmp     .cr_open_file

.cr_truncate:
    ; Check if exclusive create - if so, fail because file exists
    cmp     byte [cs:create_exclusive], 1
    jne     .cr_truncate_ok
    ; Exclusive create and file exists - return error
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_FILE_EXISTS
    jmp     dos_set_error

.cr_truncate_ok:
    ; Check if file is read-only - deny truncation
    test    byte [di + 11], ATTR_READ_ONLY
    jnz     .cr_access_denied

    ; File exists at DI, sector in AX
    ; Save location
    mov     [search_dir_sector], ax
    push    ax
    mov     ax, di
    sub     ax, disk_buffer
    shr     ax, 5                   ; / 32 = entry index
    mov     [search_dir_index], ax
    pop     ax

    ; Free existing cluster chain if any
    mov     ax, [di + 26]           ; First cluster
    test    ax, ax
    jz      .cr_no_chain
    cmp     ax, 2
    jb      .cr_no_chain
    call    fat_free_chain

.cr_no_chain:
    ; Reset file to empty
    xor     ax, ax
    mov     [di + 26], ax           ; First cluster = 0
    mov     [di + 28], ax           ; Size low = 0
    mov     [di + 30], ax           ; Size high = 0

    ; Update timestamp on truncate
    push    di
    call    get_dos_datetime        ; CX = packed time, DX = packed date
    pop     di
    mov     [di + 22], cx           ; Time
    mov     [di + 24], dx           ; Date

    ; Write directory sector back
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [search_dir_sector]
    call    fat_write_sector
    jc      .cr_write_error

.cr_open_file:
    ; Allocate SFT entry
    call    sft_alloc
    jc      .cr_too_many

    ; AX = SFT index, DI = pointer to SFT entry
    mov     bx, ax                  ; Save SFT index

    ; Fill SFT entry
    mov     word [di + SFT_ENTRY.ref_count], 1
    mov     word [di + SFT_ENTRY.open_mode], OPEN_READWRITE
    ; Store BIOS drive number in flags field
    push    ax
    xor     ax, ax
    mov     al, [active_drive_num]
    mov     [di + SFT_ENTRY.flags], ax
    pop     ax
    mov     byte [di + SFT_ENTRY.attr], 0
    mov     word [di + SFT_ENTRY.first_cluster], 0
    mov     word [di + SFT_ENTRY.cur_cluster], 0

    ; Set SFT time/date from RTC
    push    di
    call    get_dos_datetime        ; CX = packed time, DX = packed date
    pop     di
    mov     [di + SFT_ENTRY.time], cx
    mov     [di + SFT_ENTRY.date], dx
    mov     word [di + SFT_ENTRY.file_size], 0
    mov     word [di + SFT_ENTRY.file_size + 2], 0
    mov     word [di + SFT_ENTRY.file_pos], 0
    mov     word [di + SFT_ENTRY.file_pos + 2], 0
    mov     word [di + SFT_ENTRY.rel_cluster], 0

    ; Store dir sector/index
    mov     ax, [search_dir_sector]
    mov     [di + SFT_ENTRY.dir_sector], ax
    mov     ax, [search_dir_index]
    mov     [di + SFT_ENTRY.dir_index], al

    ; Copy FCB name
    push    si
    push    di
    push    cx
    mov     si, fcb_name_buffer
    add     di, SFT_ENTRY.name
    mov     cx, 11
    rep     movsb
    pop     cx
    pop     di
    pop     si

    ; Allocate handle in PSP
    mov     cl, bl                  ; SFT index
    call    handle_alloc
    jc      .cr_too_many_dealloc

    ; Success: return handle in AX
    mov     [save_ax], ax

    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    call    dos_clear_error
    ret

.cr_too_many_dealloc:
    mov     ax, bx                  ; SFT index
    call    sft_dealloc

.cr_too_many:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_TOO_MANY_FILES
    jmp     dos_set_error

.cr_access_denied:
    ; Also used when file is read-only
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_ACCESS_DENIED
    jmp     dos_set_error

.cr_read_error:
    pop     ax
    pop     cx
.cr_write_error:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_ACCESS_DENIED
    jmp     dos_set_error

.cr_read_error_nostack:
    ; Read error with no extra values on stack (subdirectory case)
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_ACCESS_DENIED
    jmp     dos_set_error

.cr_dir_full:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_CANNOT_MAKE
    jmp     dos_set_error

.cr_path_not_found:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_PATH_NOT_FOUND
    jmp     dos_set_error

; AH=3Dh - Open file
; Input: DS:DX = ASCIIZ filename (caller's), AL = access mode
int21_3D:
    push    es
    push    si
    push    di
    push    bx
    push    cx
    push    dx

    ; Copy filename from caller's DS:DX to path_buffer
    push    ds
    mov     ds, [cs:save_ds]
    mov     si, [cs:save_dx]
    push    cs
    pop     es
    mov     di, path_buffer
    mov     cx, 127
.copy_filename:
    lodsb
    stosb
    test    al, al
    jz      .filename_copied
    loop    .copy_filename
    mov     byte [es:di], 0
.filename_copied:
    pop     ds                      ; DS = kernel seg again

    ; Debug: output filename to serial
    cmp     byte [debug_trace], 0
    je      .skip_fname_trace
    push    si
    push    dx
    mov     dx, 0x3F8
    mov     al, '{'
    out     dx, al
    mov     si, path_buffer
.fname_loop:
    lodsb
    test    al, al
    jz      .fname_done
    out     dx, al
    jmp     .fname_loop
.fname_done:
    mov     al, '}'
    out     dx, al
    pop     dx
    pop     si
.skip_fname_trace:

    ; Resolve path to get directory cluster and filename
    mov     si, path_buffer
    call    resolve_path
    jc      .open_not_found

    ; AX = directory cluster, fcb_name_buffer = filename
    ; Search directory for the file
    push    ax                      ; Save dir cluster for later
    mov     si, fcb_name_buffer
    call    fat_find_in_directory
    pop     cx                      ; CX = dir cluster (for reference)
    jc      .open_not_found

    ; DI = pointer to dir entry in disk_buffer, AX = sector number
    ; Reject opening a read-only file for write or read-write
    test    byte [di + 11], ATTR_READ_ONLY
    jz      .open_attr_ok
    mov     cl, [save_ax]
    and     cl, 0x07                ; Access mode bits
    cmp     cl, OPEN_WRITE
    je      .open_access_denied
    cmp     cl, OPEN_READWRITE
    je      .open_access_denied
.open_attr_ok:

    ; Save directory entry info before sft_alloc (which might use DI)
    mov     [search_dir_sector], ax
    ; Calculate dir_index from DI offset
    push    ax
    mov     ax, di
    sub     ax, disk_buffer
    shr     ax, 5                   ; / 32 = entry index
    mov     [search_dir_index], ax
    pop     ax

    ; Save dir entry fields we need
    push    word [di + 26]          ; Starting cluster
    push    word [di + 28]          ; File size low
    push    word [di + 30]          ; File size high
    push    word [di + 22]          ; Time
    push    word [di + 24]          ; Date
    push    word [di + 11]          ; Attribute (byte, but push word)

    ; Allocate SFT entry
    call    sft_alloc
    jc      .open_too_many_pop6

    ; AX = SFT index, DI = pointer to SFT entry
    mov     bx, ax                  ; Save SFT index in BX

    ; Fill SFT entry from saved dir entry fields
    pop     ax                      ; Attribute
    mov     [di + SFT_ENTRY.attr], al
    pop     ax                      ; Date
    mov     [di + SFT_ENTRY.date], ax
    pop     ax                      ; Time
    mov     [di + SFT_ENTRY.time], ax
    pop     ax                      ; File size high
    mov     word [di + SFT_ENTRY.file_size + 2], ax
    pop     ax                      ; File size low
    mov     word [di + SFT_ENTRY.file_size], ax
    pop     ax                      ; Starting cluster
    mov     [di + SFT_ENTRY.first_cluster], ax
    mov     [di + SFT_ENTRY.cur_cluster], ax

    ; Zero out position and relative cluster
    mov     word [di + SFT_ENTRY.file_pos], 0
    mov     word [di + SFT_ENTRY.file_pos + 2], 0
    mov     word [di + SFT_ENTRY.rel_cluster], 0

    ; Store open mode
    mov     ax, [save_ax]
    and     ax, 0x00FF              ; AL only
    mov     [di + SFT_ENTRY.open_mode], ax

    ; Store BIOS drive number in flags field (low byte = drive for disk files)
    xor     ax, ax
    mov     al, [active_drive_num]  ; BIOS drive (0=A:, 0x80=C:)
    mov     [di + SFT_ENTRY.flags], ax

    ; Store dir sector/index
    mov     ax, [search_dir_sector]
    mov     [di + SFT_ENTRY.dir_sector], ax
    mov     ax, [search_dir_index]
    mov     [di + SFT_ENTRY.dir_index], al

    ; Copy FCB name
    push    si
    push    di
    push    cx
    mov     si, fcb_name_buffer
    add     di, SFT_ENTRY.name
    mov     cx, 11
    rep     movsb
    pop     cx
    pop     di
    pop     si

    ; Allocate handle in PSP
    mov     cl, bl                  ; SFT index
    call    handle_alloc
    jc      .open_too_many_dealloc

    ; Success: return handle in AX
    mov     [save_ax], ax

    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    call    dos_clear_error
    ret

.open_too_many_dealloc:
    mov     ax, bx                  ; SFT index
    call    sft_dealloc
    jmp     .open_too_many

.open_too_many_pop6:
    ; Clean up 6 pushed words from dir entry
    add     sp, 12
.open_too_many:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_TOO_MANY_FILES
    jmp     dos_set_error

.open_access_denied:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_ACCESS_DENIED
    jmp     dos_set_error

.open_not_found:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_FILE_NOT_FOUND
    jmp     dos_set_error

; AH=3Eh - Close file
int21_3E:
    mov     bx, [save_bx]
    cmp     bx, 5
    jb      .close_device

    ; Get SFT index from handle table
    call    handle_to_sft
    jc      .close_bad

    ; Mark handle entry as free using dynamic handle table
    push    es
    push    di
    mov     es, [current_psp]
    mov     di, [es:0x34]           ; Handle table offset
    mov     ax, [es:0x36]           ; Handle table segment
    test    ax, ax
    jnz     .close_have_ptr
    mov     ax, es
    mov     di, 0x18
.close_have_ptr:
    mov     es, ax
    mov     byte [es:di + bx], 0xFF
    pop     di
    pop     es

    ; Dealloc SFT
    xor     ah, ah                  ; AL already has SFT index
    call    sft_dealloc

.close_device:
    call    dos_clear_error
    ret

.close_bad:
    mov     ax, ERR_INVALID_HANDLE
    jmp     dos_set_error

; AH=3Fh - Read file/device
int21_3F:
    ; Check if handle is a device (0-4 are standard handles)
    mov     bx, [save_bx]       ; File handle
    cmp     bx, STDIN
    je      .read_stdin
    cmp     bx, 4
    jbe     .read_device

    ; Disk file read
    jmp     .read_disk_file

.read_stdin:
    ; Read from keyboard
    push    es
    push    di

    mov     es, [save_ds]
    mov     di, [save_dx]        ; Buffer
    mov     cx, [save_cx]        ; Count
    xor     dx, dx               ; Bytes read

.stdin_loop:
    test    cx, cx
    jz      .stdin_done

    xor     ah, ah
    int     0x16

    cmp     al, 0x0D             ; Enter?
    je      .stdin_enter

    mov     [es:di], al
    inc     di
    inc     dx
    dec     cx

    ; Echo
    push    bx
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    pop     bx
    jmp     .stdin_loop

.stdin_enter:
    ; Store CR+LF
    cmp     cx, 2
    jb      .stdin_done
    mov     byte [es:di], 0x0D
    inc     di
    inc     dx
    dec     cx
    test    cx, cx
    jz      .stdin_done
    mov     byte [es:di], 0x0A
    inc     dx

    ; Echo CR+LF
    push    bx
    mov     ah, 0x0E
    xor     bx, bx
    mov     al, 0x0D
    int     0x10
    mov     al, 0x0A
    int     0x10
    pop     bx

.stdin_done:
    mov     [save_ax], dx        ; Return bytes read
    pop     di
    pop     es
    call    dos_clear_error
    ret

.read_device:
    ; Other device reads - return 0 bytes
    mov     word [save_ax], 0
    call    dos_clear_error
    ret

; ---------------------------------------------------------------------------
; Disk file read - read from an open file via SFT
; ---------------------------------------------------------------------------
.read_disk_file:
    push    es
    push    si
    push    di
    push    bp

    call    handle_to_sft
    jc      .read_bad_handle

    ; DI = SFT entry pointer
    mov     bp, di                  ; BP = SFT entry pointer

    ; Switch to the drive this file was opened on
    mov     al, [cs:bp + SFT_ENTRY.flags]  ; BIOS drive number
    cmp     al, 0x80
    jne     .read_not_hd
    mov     al, 2                   ; C:
    jmp     .read_set_drive
.read_not_hd:
    ; AL already = logical drive (0=A:, 3=D:)
.read_set_drive:
    call    fat_set_active_drive

    ; Validate read permission: check open mode
    mov     ax, [cs:bp + SFT_ENTRY.open_mode]
    cmp     al, OPEN_WRITE
    je      .read_access_denied     ; Opened write-only

    ; Calculate remaining bytes = file_size - file_pos (32-bit)
    ; NOTE: BP-relative addressing defaults to SS segment, but SFT is in CS
    ; Must use cs: segment override for all [bp + ...] accesses
    mov     ax, [cs:bp + SFT_ENTRY.file_size]
    mov     dx, [cs:bp + SFT_ENTRY.file_size + 2]
    sub     ax, [cs:bp + SFT_ENTRY.file_pos]
    sbb     dx, [cs:bp + SFT_ENTRY.file_pos + 2]

    ; If remaining <= 0, return 0
    test    dx, dx
    js      .read_zero
    jnz     .clamp_count            ; remaining > 64K, don't clamp
    test    ax, ax
    jz      .read_zero

.clamp_count:
    ; Clamp requested count to remaining
    mov     cx, [save_cx]           ; Requested count
    test    dx, dx
    jnz     .count_ok               ; remaining > 64K, cx is fine
    cmp     cx, ax
    jbe     .count_ok
    mov     cx, ax                  ; Clamp to remaining
.count_ok:
    test    cx, cx
    jz      .read_zero

    ; Set up destination: ES:SI = caller's buffer
    mov     es, [save_ds]
    mov     si, [save_dx]           ; Using SI as dest pointer (with ES)

    ; Read loop
    xor     dx, dx                  ; Total bytes read

.read_loop:
    test    cx, cx
    jz      .read_done

    ; Calculate offset within current sector: file_pos mod 512
    mov     ax, [cs:bp + SFT_ENTRY.file_pos]
    and     ax, 0x01FF              ; offset_in_sector

    ; Read current cluster's sector into disk_buffer
    push    cx
    push    dx
    push    es
    push    si

    mov     ax, [cs:bp + SFT_ENTRY.cur_cluster]
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_cluster_to_lba
    call    fat_read_sector

    pop     si
    pop     es
    pop     dx
    pop     cx
    jc      .read_error

    ; Calculate bytes to copy: min(512 - offset, bytes_left)
    mov     ax, [cs:bp + SFT_ENTRY.file_pos]
    and     ax, 0x01FF              ; offset_in_sector
    mov     bx, 512
    sub     bx, ax                  ; bytes available in this sector
    cmp     bx, cx
    jbe     .use_bx
    mov     bx, cx                  ; Use remaining count if less
.use_bx:
    ; Copy BX bytes from disk_buffer+offset to ES:SI
    push    cx
    push    si
    push    di
    push    ds

    mov     di, si                  ; DI = dest (in ES)
    push    cs
    pop     ds
    mov     si, disk_buffer
    mov     cx, [cs:bp + SFT_ENTRY.file_pos]
    and     cx, 0x01FF
    add     si, cx                  ; SI = disk_buffer + offset

    mov     cx, bx                  ; Count to copy
    rep     movsb

    pop     ds
    mov     si, di                  ; Update dest pointer
    pop     di
    pop     ax                      ; Was pushed SI (don't need)
    pop     cx

    ; Advance file_pos by bx bytes
    add     [cs:bp + SFT_ENTRY.file_pos], bx
    adc     word [cs:bp + SFT_ENTRY.file_pos + 2], 0

    add     dx, bx                  ; Total bytes read
    sub     cx, bx                  ; Bytes remaining

    ; Check if we crossed a sector/cluster boundary
    ; (1 sector per cluster on 1.44MB floppy)
    mov     ax, [cs:bp + SFT_ENTRY.file_pos]
    test    ax, 0x01FF              ; If low 9 bits are 0, we crossed a sector
    jnz     .read_loop

    ; Crossed sector boundary - advance to next cluster
    push    cx
    push    dx
    mov     ax, [cs:bp + SFT_ENTRY.cur_cluster]
    call    fat_get_next_cluster
    cmp     ax, [fat_eoc_min]
    jae     .chain_end
    mov     [cs:bp + SFT_ENTRY.cur_cluster], ax
    inc     word [cs:bp + SFT_ENTRY.rel_cluster]
.chain_end:
    pop     dx
    pop     cx
    jmp     .read_loop

.read_done:
    mov     [save_ax], dx           ; Return bytes read
    pop     bp
    pop     di
    pop     si
    pop     es
    call    dos_clear_error
    ret

.read_zero:
    mov     word [save_ax], 0
    pop     bp
    pop     di
    pop     si
    pop     es
    call    dos_clear_error
    ret

.read_error:
    mov     word [save_ax], 0
    pop     bp
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_READ_FAULT
    jmp     dos_set_error

.read_access_denied:
    pop     bp
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_ACCESS_DENIED
    jmp     dos_set_error

.read_bad_handle:
    pop     bp
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_INVALID_HANDLE
    jmp     dos_set_error

; AH=40h - Write file/device
int21_40:
    mov     bx, [save_bx]
    cmp     bx, STDOUT
    je      .write_stdout
    cmp     bx, STDERR
    je      .write_stdout
    cmp     bx, 4
    jbe     .write_device

    ; Disk file write
    jmp     .write_disk_file

.write_stdout:
    push    es
    push    si

    mov     es, [save_ds]
    mov     si, [save_dx]
    mov     cx, [save_cx]

    mov     ah, 0x0E
    xor     bx, bx
.stdout_loop:
    test    cx, cx
    jz      .stdout_done
    mov     al, [es:si]
    int     0x10
    inc     si
    dec     cx
    jmp     .stdout_loop

.stdout_done:
    mov     ax, [save_cx]        ; Return bytes written = requested
    mov     [save_ax], ax
    pop     si
    pop     es
    call    dos_clear_error
    ret

.write_device:
    mov     ax, [save_cx]
    mov     [save_ax], ax
    call    dos_clear_error
    ret

; ---------------------------------------------------------------------------
; Disk file write - write to an open file via SFT
; ---------------------------------------------------------------------------
.write_disk_file:
    push    es
    push    si
    push    di
    push    bp

    call    handle_to_sft
    jc      .write_bad_handle

    ; DI = SFT entry pointer
    mov     bp, di                  ; BP = SFT entry pointer

    ; Switch to the drive this file was opened on
    mov     al, [cs:bp + SFT_ENTRY.flags]  ; BIOS drive number
    cmp     al, 0x80
    jne     .write_not_hd
    mov     al, 2                   ; C:
    jmp     .write_set_drive
.write_not_hd:
.write_set_drive:
    call    fat_set_active_drive

    ; Validate write permission: check open mode
    mov     ax, [cs:bp + SFT_ENTRY.open_mode]
    cmp     al, OPEN_READ
    je      .write_access_denied    ; Opened read-only

    ; Validate file attribute: check not read-only
    test    byte [cs:bp + SFT_ENTRY.attr], ATTR_READ_ONLY
    jnz     .write_access_denied    ; File is read-only

    mov     cx, [save_cx]           ; Bytes to write
    test    cx, cx
    jz      .write_zero

    ; Set up source: DS:SI (in caller space)
    push    ds
    mov     ds, [cs:save_ds]
    mov     si, [cs:save_dx]

    xor     dx, dx                  ; Total bytes written

.write_loop:
    test    cx, cx
    jz      .write_done

    ; Calculate offset within current sector: file_pos mod 512
    mov     ax, [cs:bp + SFT_ENTRY.file_pos]
    and     ax, 0x01FF              ; offset_in_sector

    ; Check if we need to allocate a new cluster
    push    ax                      ; Save offset
    mov     ax, [cs:bp + SFT_ENTRY.cur_cluster]
    ; Valid data clusters are 2 to max_cluster-1
    ; 0 and 1 are reserved (no cluster allocated yet)
    ; >= 0xFF8 (FAT12) or 0xFFF8 (FAT16) means end of chain
    cmp     ax, 2
    jb      .write_need_cluster     ; Clusters 0,1 = need to allocate
    cmp     ax, [cs:fat_eoc_min]
    jb      .write_have_cluster     ; Valid cluster in range
    ; Fall through to allocate (end of chain or invalid)

.write_need_cluster:
    ; Allocate a new cluster
    push    cx
    push    dx
    push    ds
    push    cs
    pop     ds                      ; DS = kernel for fat_alloc_cluster
    call    fat_alloc_cluster
    pop     ds
    pop     dx
    pop     cx
    jc      .write_disk_full_pop

    ; Link new cluster
    push    ax                      ; New cluster
    mov     bx, ax
    mov     ax, [cs:bp + SFT_ENTRY.cur_cluster]
    ; Check if this is the first cluster for this file
    ; Clusters 0 and 1 are reserved, so if cur_cluster < 2, it's a new file
    cmp     ax, 2
    jb      .write_first_cluster
    cmp     ax, [cs:fat_eoc_min]
    jae     .write_first_cluster
    ; Not first - link previous cluster to new one
    push    cx
    push    dx
    push    ds
    push    cs
    pop     ds
    mov     dx, bx                  ; New cluster as value
    call    fat_set_cluster       ; Set AX's next to DX
    pop     ds
    pop     dx
    pop     cx
    pop     ax                      ; New cluster
    jmp     .write_set_cur_cluster

.write_first_cluster:
    pop     ax                      ; New cluster
    mov     [cs:bp + SFT_ENTRY.first_cluster], ax

.write_set_cur_cluster:
    mov     [cs:bp + SFT_ENTRY.cur_cluster], ax

.write_have_cluster:
    pop     ax                      ; Restore offset_in_sector

    ; Read current sector into disk_buffer (for partial writes)
    push    cx
    push    dx
    push    ds
    push    si

    push    cs
    pop     ds
    mov     ax, [cs:bp + SFT_ENTRY.cur_cluster]

    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_cluster_to_lba
    push    ax                      ; Save LBA for write-back
    call    fat_read_sector
    ; Ignore read error for new/empty sectors

    pop     ax                      ; LBA
    mov     [.write_lba], ax

    pop     si
    pop     ds                      ; Restore caller's DS:SI
    pop     dx
    pop     cx

    ; Calculate bytes to copy: min(512 - offset, bytes_remaining)
    mov     ax, [cs:bp + SFT_ENTRY.file_pos]
    and     ax, 0x01FF              ; offset_in_sector
    mov     bx, 512
    sub     bx, ax                  ; bytes available in this sector
    cmp     bx, cx
    jbe     .write_use_bx
    mov     bx, cx                  ; Use remaining count if less
.write_use_bx:

    ; Copy BX bytes from DS:SI to disk_buffer+offset
    push    cx
    push    si
    push    di
    push    es

    mov     di, ax                  ; offset_in_sector
    add     di, disk_buffer
    push    cs
    pop     es                      ; ES:DI = disk_buffer + offset

    mov     cx, bx
    rep     movsb                   ; Copy from DS:SI to ES:DI

    pop     es
    mov     si, di                  ; Update source pointer (in DS)
    sub     si, disk_buffer         ; Adjust - SI should advance by BX
    pop     di
    pop     ax                      ; Was SI before copy
    add     ax, bx
    mov     si, ax                  ; SI = original SI + bytes copied
    pop     cx

    ; Write sector back to disk
    ; BX = bytes copied this iteration, must preserve it!
    push    bx                      ; Save byte count
    push    cx
    push    dx
    push    si
    push    ds

    push    cs
    pop     ds
    push    cs
    pop     es
    mov     ax, [.write_lba]
    mov     bx, disk_buffer
    call    fat_write_sector

    pop     ds
    pop     si
    pop     dx
    pop     cx
    pop     bx                      ; Restore byte count
    jc      .write_error

    ; Advance file_pos by bx bytes
    add     [cs:bp + SFT_ENTRY.file_pos], bx
    adc     word [cs:bp + SFT_ENTRY.file_pos + 2], 0

    add     dx, bx                  ; Total bytes written
    sub     cx, bx                  ; Bytes remaining

    ; Update file_size if we extended the file
    mov     ax, [cs:bp + SFT_ENTRY.file_pos]
    mov     bx, [cs:bp + SFT_ENTRY.file_pos + 2]
    cmp     bx, [cs:bp + SFT_ENTRY.file_size + 2]
    ja      .write_extend_size
    jb      .write_check_boundary
    cmp     ax, [cs:bp + SFT_ENTRY.file_size]
    jbe     .write_check_boundary

.write_extend_size:
    mov     [cs:bp + SFT_ENTRY.file_size], ax
    mov     [cs:bp + SFT_ENTRY.file_size + 2], bx

.write_check_boundary:
    ; Check if we crossed a sector boundary
    mov     ax, [cs:bp + SFT_ENTRY.file_pos]
    test    ax, 0x01FF              ; If low 9 bits are 0, crossed sector
    jnz     .write_loop

    ; Crossed sector - advance to next cluster
    push    cx
    push    dx
    push    ds
    push    cs
    pop     ds
    mov     ax, [cs:bp + SFT_ENTRY.cur_cluster]
    call    fat_get_next_cluster
    mov     [cs:bp + SFT_ENTRY.cur_cluster], ax
    inc     word [cs:bp + SFT_ENTRY.rel_cluster]
    pop     ds
    pop     dx
    pop     cx
    jmp     .write_loop

.write_done:
    pop     ds                      ; Restore kernel DS

    ; Update directory entry with new file size
    call    .write_update_dir_entry

    mov     [save_ax], dx           ; Return bytes written
    pop     bp
    pop     di
    pop     si
    pop     es
    call    dos_clear_error
    ret

.write_zero:
    mov     word [save_ax], 0
    pop     bp
    pop     di
    pop     si
    pop     es
    call    dos_clear_error
    ret

.write_disk_full_pop:
    pop     ax                      ; Clean up stack (offset)
    pop     ds
    mov     [save_ax], dx           ; Return bytes written so far
    pop     bp
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_DISK_FULL       ; Disk full error (not memory error)
    jmp     dos_set_error

.write_error:
    pop     ds
    mov     [save_ax], dx           ; Return bytes written so far
    pop     bp
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_WRITE_FAULT
    jmp     dos_set_error

.write_access_denied:
    pop     bp
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_ACCESS_DENIED
    jmp     dos_set_error

.write_bad_handle:
    pop     bp
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_INVALID_HANDLE
    jmp     dos_set_error

; Local variable for write
.write_lba  dw  0

; ---------------------------------------------------------------------------
; .write_update_dir_entry - Update directory entry with current file size
; Uses BP = SFT entry pointer
; ---------------------------------------------------------------------------
.write_update_dir_entry:
    push    es
    push    bx
    push    ax

    ; Read directory sector
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [cs:bp + SFT_ENTRY.dir_sector]
    call    fat_read_sector
    jc      .write_dir_done

    ; Calculate offset to entry
    xor     ah, ah
    mov     al, [cs:bp + SFT_ENTRY.dir_index]
    shl     ax, 5                   ; * 32
    mov     bx, ax
    add     bx, disk_buffer

    ; Update first cluster
    mov     ax, [cs:bp + SFT_ENTRY.first_cluster]
    mov     [bx + 26], ax

    ; Update file size
    mov     ax, [cs:bp + SFT_ENTRY.file_size]
    mov     [bx + 28], ax
    mov     ax, [cs:bp + SFT_ENTRY.file_size + 2]
    mov     [bx + 30], ax

    ; Update modification timestamp from RTC
    push    bx
    call    get_dos_datetime        ; CX = packed time, DX = packed date
    pop     bx
    mov     [bx + 22], cx           ; Time
    mov     [bx + 24], dx           ; Date
    ; Also update SFT entry
    mov     [cs:bp + SFT_ENTRY.time], cx
    mov     [cs:bp + SFT_ENTRY.date], dx

    ; Write sector back
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [cs:bp + SFT_ENTRY.dir_sector]
    call    fat_write_sector

.write_dir_done:
    pop     ax
    pop     bx
    pop     es
    ret

; AH=41h - Delete file
; Input: DS:DX = ASCIIZ filename
int21_41:
    push    es
    push    si
    push    di
    push    bx

    ; Copy filename from caller's DS:DX to path_buffer
    push    ds
    mov     ds, [cs:save_ds]
    mov     si, [cs:save_dx]
    push    cs
    pop     es
    mov     di, path_buffer
    mov     cx, 127
.del_copy:
    lodsb
    stosb
    test    al, al
    jz      .del_copied
    loop    .del_copy
    mov     byte [es:di], 0
.del_copied:
    pop     ds                      ; DS = kernel seg

    ; Resolve path to get directory cluster and filename
    mov     si, path_buffer
    call    resolve_path
    jc      .del_not_found

    ; AX = directory cluster, fcb_name_buffer = filename
    ; fat_find_in_directory handles both root (cluster 0) and subdirectories

    ; Find file in directory
    mov     si, fcb_name_buffer
    call    fat_find_in_directory
    jc      .del_not_found

    ; DI = dir entry in disk_buffer, AX = sector number
    mov     [search_dir_sector], ax

    ; Check if read-only
    test    byte [di + 11], ATTR_READ_ONLY
    jnz     .del_access_denied

    ; Check if directory
    test    byte [di + 11], ATTR_DIRECTORY
    jnz     .del_access_denied

    ; Get first cluster
    mov     ax, [di + 26]
    push    ax                      ; Save for freeing

    ; Mark entry as deleted (0xE5)
    mov     byte [di], 0xE5

    ; Write directory sector back
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [search_dir_sector]
    call    fat_write_sector
    pop     ax                      ; First cluster
    jc      .del_write_error

    ; Free cluster chain
    test    ax, ax
    jz      .del_done
    cmp     ax, 2
    jb      .del_done
    call    fat_free_chain

.del_done:
    pop     bx
    pop     di
    pop     si
    pop     es
    call    dos_clear_error
    ret

.del_not_found:
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_FILE_NOT_FOUND
    jmp     dos_set_error

.del_access_denied:
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_ACCESS_DENIED
    jmp     dos_set_error

.del_write_error:
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_WRITE_FAULT
    jmp     dos_set_error

; AH=42h - Seek file
; Input: BX = handle, AL = method (0=SET,1=CUR,2=END), CX:DX = offset
int21_42:
    push    si
    push    di
    push    bp

    mov     bx, [save_bx]
    cmp     bx, 5
    jb      .seek_device

    call    handle_to_sft
    jc      .seek_bad

    mov     bp, di                  ; BP = SFT entry

    ; Switch to the drive this file was opened on
    mov     al, [cs:bp + SFT_ENTRY.flags]  ; BIOS drive number
    cmp     al, 0x80
    jne     .seek_not_hd
    mov     al, 2                   ; C:
    jmp     .seek_set_drive
.seek_not_hd:
.seek_set_drive:
    call    fat_set_active_drive

    ; Get method from saved AL
    mov     al, [save_ax]

    ; Get offset CX:DX
    mov     cx, [save_cx]
    mov     dx, [save_dx]

    ; Compute new position based on method
    cmp     al, SEEK_SET
    je      .seek_set
    cmp     al, SEEK_CUR
    je      .seek_cur
    cmp     al, SEEK_END
    je      .seek_end
    jmp     .seek_bad

.seek_set:
    ; pos = CX:DX
    mov     [cs:bp + SFT_ENTRY.file_pos], dx
    mov     [cs:bp + SFT_ENTRY.file_pos + 2], cx
    jmp     .seek_walk

.seek_cur:
    ; pos = file_pos + CX:DX
    add     dx, [cs:bp + SFT_ENTRY.file_pos]
    adc     cx, [cs:bp + SFT_ENTRY.file_pos + 2]
    mov     [cs:bp + SFT_ENTRY.file_pos], dx
    mov     [cs:bp + SFT_ENTRY.file_pos + 2], cx
    jmp     .seek_walk

.seek_end:
    ; pos = file_size + CX:DX (signed offset)
    add     dx, [cs:bp + SFT_ENTRY.file_size]
    adc     cx, [cs:bp + SFT_ENTRY.file_size + 2]
    ; Validate result is not negative (high bit set = negative in signed)
    test    cx, 0x8000
    jnz     .seek_bad               ; Negative position is invalid
    mov     [cs:bp + SFT_ENTRY.file_pos], dx
    mov     [cs:bp + SFT_ENTRY.file_pos + 2], cx

.seek_walk:
    ; Walk cluster chain from first_cluster to find cluster for new position
    ; cluster_index = file_pos / (sectors_per_cluster * 512)
    ;               = (file_pos >> 9) / sectors_per_cluster
    push    bx
    mov     bx, [cs:active_dpb]        ; Get active DPB pointer
    xor     ch, ch
    mov     cl, [cs:bx + DPB_SEC_PER_CLUS] ; Sectors per cluster - 1 (0-based)
    inc     cx                          ; CX = sectors per cluster
    push    cx                          ; Save sectors_per_cluster

    mov     ax, [cs:bp + SFT_ENTRY.file_pos + 2]
    mov     dx, [cs:bp + SFT_ENTRY.file_pos]
    ; Shift right 9 to get sector index
    shr     ax, 1
    rcr     dx, 1
    mov     cx, 8
.shift_loop:
    shr     ax, 1
    rcr     dx, 1
    loop    .shift_loop
    ; DX = sector index from start of file

    ; Divide sector index by sectors_per_cluster to get cluster index
    pop     cx                          ; CX = sectors_per_cluster
    mov     ax, dx
    xor     dx, dx
    div     cx                          ; AX = cluster index
    mov     cx, ax                      ; CX = target cluster index
    pop     bx

    ; Walk chain
    mov     ax, [cs:bp + SFT_ENTRY.first_cluster]
    xor     bx, bx                  ; Current index
    test    cx, cx
    jz      .seek_found

.walk_loop:
    push    cx
    call    fat_get_next_cluster
    pop     cx
    cmp     ax, [fat_eoc_min]
    jae     .seek_found
    inc     bx
    cmp     bx, cx
    jb      .walk_loop

.seek_found:
    mov     [cs:bp + SFT_ENTRY.cur_cluster], ax
    mov     [cs:bp + SFT_ENTRY.rel_cluster], bx

    ; Return new position in DX:AX
    mov     ax, [cs:bp + SFT_ENTRY.file_pos]
    mov     [save_ax], ax
    mov     ax, [cs:bp + SFT_ENTRY.file_pos + 2]
    mov     [save_dx], ax

    pop     bp
    pop     di
    pop     si
    call    dos_clear_error
    ret

.seek_device:
    ; Device handles - return 0:0
    mov     word [save_ax], 0
    mov     word [save_dx], 0
    pop     bp
    pop     di
    pop     si
    call    dos_clear_error
    ret

.seek_bad:
    pop     bp
    pop     di
    pop     si
    mov     ax, ERR_INVALID_HANDLE
    jmp     dos_set_error

; AH=43h - Get/Set file attributes
; Input: AL = 0 get, 1 set; DS:DX = ASCIIZ filename; CX = attr (for set)
; Output: CX = attributes (for get)
int21_43:
    push    es
    push    si
    push    di
    push    bx

    ; Copy filename from caller's DS:DX to path_buffer
    push    ds
    mov     ds, [cs:save_ds]
    mov     si, [cs:save_dx]
    push    cs
    pop     es
    mov     di, path_buffer
    mov     cx, 127
.attr_copy:
    lodsb
    stosb
    test    al, al
    jz      .attr_copied
    loop    .attr_copy
    mov     byte [es:di], 0
.attr_copied:
    pop     ds                      ; DS = kernel seg

    ; Resolve path to get directory cluster and filename
    mov     si, path_buffer
    call    resolve_path
    jc      .attr_not_found

    ; AX = directory cluster, fcb_name_buffer = filename
    push    ax                      ; Save directory cluster

    ; Find file in directory
    mov     si, fcb_name_buffer
    call    fat_find_in_directory
    pop     cx                      ; Pop directory cluster (not needed anymore)
    jc      .attr_not_found

    ; DI = dir entry in disk_buffer, AX = sector number
    mov     [search_dir_sector], ax

    ; Check subfunction
    mov     al, [save_ax]
    test    al, al
    jnz     .attr_set

    ; Get attributes
    xor     ah, ah
    mov     al, [di + 11]
    mov     [save_cx], ax

    pop     bx
    pop     di
    pop     si
    pop     es
    call    dos_clear_error
    ret

.attr_set:
    ; Set attributes
    mov     ax, [save_cx]
    mov     [di + 11], al

    ; Write directory sector back
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [search_dir_sector]
    call    fat_write_sector
    jc      .attr_write_error

    pop     bx
    pop     di
    pop     si
    pop     es
    call    dos_clear_error
    ret

.attr_not_found:
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_FILE_NOT_FOUND
    jmp     dos_set_error

.attr_write_error:
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_ACCESS_DENIED
    jmp     dos_set_error

; AH=44h - IOCTL
int21_44:
    ; IOCTL - subfunction in AL
    mov     al, [save_ax]

    ; Debug: print IOCTL subfunction to serial if debug_trace enabled
    cmp     byte [debug_trace], 0
    je      .skip_ioctl_trace
    push    ax
    push    dx
    mov     dx, 0x3F8
    mov     al, '<'
    out     dx, al
    mov     al, [save_ax]
    push    ax
    shr     al, 4
    add     al, '0'
    cmp     al, '9'
    jbe     .iot1
    add     al, 7
.iot1:
    out     dx, al
    pop     ax
    and     al, 0x0F
    add     al, '0'
    cmp     al, '9'
    jbe     .iot2
    add     al, 7
.iot2:
    out     dx, al
    mov     al, '>'
    out     dx, al
    pop     dx
    pop     ax
    mov     al, [save_ax]
.skip_ioctl_trace:

    cmp     al, 0x00             ; Get device info
    je      .ioctl_get_info
    cmp     al, 0x01             ; Set device info
    je      .ioctl_set_info
    cmp     al, 0x02             ; Read from device
    je      .ioctl_stub_ok
    cmp     al, 0x03             ; Write to device
    je      .ioctl_stub_ok
    cmp     al, 0x04             ; Read from drive
    je      .ioctl_stub_ok
    cmp     al, 0x05             ; Write to drive
    je      .ioctl_stub_ok
    cmp     al, 0x06             ; Check input status
    je      .ioctl_input_status
    cmp     al, 0x07             ; Check output status
    je      .ioctl_output_status
    cmp     al, 0x08             ; Check if removable
    je      .ioctl_removable
    cmp     al, 0x09             ; Check if remote
    je      .ioctl_not_remote
    cmp     al, 0x0A             ; Check if handle is remote
    je      .ioctl_not_remote
    cmp     al, 0x0B             ; Set sharing retry count
    je      .ioctl_stub_ok
    cmp     al, 0x0D             ; Generic IOCTL for block devices
    je      .ioctl_generic_block
    cmp     al, 0x0E             ; Get logical drive
    je      .ioctl_get_drive

    ; Unimplemented - return error
    mov     ax, ERR_INVALID_FUNC
    jmp     dos_set_error

.ioctl_stub_ok:
    ; Return success with 0 bytes transferred
    mov     word [save_ax], 0
    call    dos_clear_error
    ret

.ioctl_not_remote:
    ; Return DX=0 (not remote/network)
    mov     word [save_dx], 0
    call    dos_clear_error
    ret

.ioctl_generic_block:
    ; Generic IOCTL - just return success for now
    call    dos_clear_error
    ret

.ioctl_get_drive:
    ; Get logical drive map - return 0 (only one drive mapping)
    mov     byte [save_ax], 0
    call    dos_clear_error
    ret

.ioctl_get_info:
    ; Return device info word in DX
    mov     bx, [save_bx]
    cmp     bx, 4
    ja      .ioctl_file
    ; Standard device handle
    mov     word [save_dx], 0x80D3  ; Character device, STDIN/STDOUT
    call    dos_clear_error
    ret
.ioctl_file:
    mov     word [save_dx], 0x0000  ; File on drive A:
    call    dos_clear_error
    ret

.ioctl_set_info:
    ; Set device info - just accept and ignore
    call    dos_clear_error
    ret

.ioctl_input_status:
    ; Check if input ready - return AL=0xFF if ready, 0 if not
    ; For CON device, always say ready
    mov     bx, [save_bx]
    cmp     bx, 4
    ja      .ioctl_input_file
    mov     byte [save_ax], 0xFF    ; Ready
    call    dos_clear_error
    ret
.ioctl_input_file:
    mov     byte [save_ax], 0xFF    ; Files always ready
    call    dos_clear_error
    ret

.ioctl_output_status:
    ; Check if output ready - always say ready
    mov     byte [save_ax], 0xFF    ; Ready
    call    dos_clear_error
    ret

.ioctl_removable:
    ; Check if device is removable
    ; AL=0 removable, AL=1 not removable
    mov     byte [save_ax], 0       ; Floppy is removable
    call    dos_clear_error
    ret

; AH=45h - Duplicate handle
; Input: BX = handle to duplicate
; Output: AX = new handle
int21_45:
    push    di
    push    bx

    mov     bx, [save_bx]

    ; Get SFT entry for the handle
    call    handle_to_sft
    jc      .dup_bad_handle

    ; AL = SFT index, DI = SFT entry
    ; Increment reference count
    inc     word [di + SFT_ENTRY.ref_count]

    ; Allocate new handle in PSP pointing to same SFT
    mov     cl, al                  ; SFT index
    call    handle_alloc
    jc      .dup_no_handles

    ; Success - return new handle in AX
    mov     [save_ax], ax

    pop     bx
    pop     di
    call    dos_clear_error
    ret

.dup_no_handles:
    ; Undo the ref count increment
    dec     word [di + SFT_ENTRY.ref_count]
    pop     bx
    pop     di
    mov     ax, ERR_TOO_MANY_FILES
    jmp     dos_set_error

.dup_bad_handle:
    pop     bx
    pop     di
    mov     ax, ERR_INVALID_HANDLE
    jmp     dos_set_error

; AH=46h - Force duplicate handle
; Input: BX = existing handle, CX = new handle number
; Output: CX now refers to same file as BX
int21_46:
    push    di
    push    si
    push    bx
    push    cx

    ; Get the SFT index for the source handle (BX)
    mov     bx, [save_bx]
    call    handle_to_sft
    jc      .force_bad_handle

    ; AL = SFT index of source, DI = SFT entry
    mov     si, di                  ; SI = source SFT entry
    push    ax                      ; Save source SFT index

    ; Close the destination handle (CX) if it's open
    mov     bx, [save_cx]

    ; Validate handle range using dynamic count
    push    es
    mov     es, [current_psp]
    mov     dx, [es:0x32]           ; Handle count
    test    dx, dx
    jnz     .force_have_count
    mov     dx, MAX_HANDLES
.force_have_count:
    cmp     bx, dx
    pop     es
    jae     .force_dest_invalid

    ; Get handle table pointer
    push    es
    mov     es, [current_psp]
    mov     di, [es:0x34]           ; Handle table offset
    mov     dx, [es:0x36]           ; Handle table segment
    test    dx, dx
    jnz     .force_have_ptr
    mov     dx, es
    mov     di, 0x18
.force_have_ptr:
    mov     es, dx                  ; ES:DI = handle table
    mov     al, [es:di + bx]       ; Get SFT index at dest handle

    ; If handle is in use (not 0xFF), close it first
    cmp     al, 0xFF
    je      .force_dest_free

    ; Decrement ref count of old SFT entry
    push    di
    push    bx
    xor     ah, ah
    mov     bx, ax
    mov     di, sft_table
    mov     ax, SFT_ENTRY_SIZE
    mul     bx
    add     di, ax
    dec     word [di + SFT_ENTRY.ref_count]
    pop     bx
    pop     di

.force_dest_free:
    ; Now set dest handle to point to same SFT as source
    pop     es                      ; ES = handle table segment (from push above)

    pop     ax                      ; AL = source SFT index

    ; Get handle table pointer again for the write
    push    es
    mov     es, [current_psp]
    mov     di, [es:0x34]
    mov     dx, [es:0x36]
    test    dx, dx
    jnz     .force_have_ptr2
    mov     dx, es
    mov     di, 0x18
.force_have_ptr2:
    mov     es, dx
    mov     bx, [save_cx]           ; BX = dest handle
    mov     [es:di + bx], al       ; Point dest to source SFT
    pop     es

    ; Increment ref count of source SFT
    inc     word [si + SFT_ENTRY.ref_count]

    pop     cx
    pop     bx
    pop     si
    pop     di
    call    dos_clear_error
    ret

.force_dest_invalid:
    pop     ax                      ; Clean up saved source SFT index
.force_bad_handle:
    pop     cx
    pop     bx
    pop     si
    pop     di
    mov     ax, ERR_INVALID_HANDLE
    jmp     dos_set_error

; AH=56h - Rename file (supports cross-directory move on same drive)
; Input: DS:DX = old ASCIIZ name, ES:DI = new ASCIIZ name
int21_56:
    push    es
    push    si
    push    di
    push    bx
    push    cx
    push    dx

    ; Copy old filename from caller's DS:DX to path_buffer
    push    ds
    mov     ds, [cs:save_ds]
    mov     si, [cs:save_dx]
    push    cs
    pop     es
    mov     di, path_buffer
    mov     cx, 127
.ren_copy_old:
    lodsb
    stosb
    test    al, al
    jz      .ren_copied_old
    loop    .ren_copy_old
    mov     byte [es:di], 0
.ren_copied_old:
    pop     ds                      ; DS = kernel seg

    ; Resolve old path to find the file
    mov     si, path_buffer
    call    resolve_path
    jc      .ren_not_found

    ; AX = directory cluster, fcb_name_buffer = filename
    mov     [.ren_dir_cluster], ax

    ; Save the source drive number for cross-drive check
    mov     al, [active_drive_num]
    mov     [.ren_src_drive], al

    ; Find file in source directory
    mov     si, fcb_name_buffer
    call    fat_find_in_directory
    jc      .ren_not_found

    ; DI = directory entry in disk_buffer, AX = sector number
    mov     [.ren_entry_sector], ax

    ; Calculate entry index
    push    ax
    mov     ax, di
    sub     ax, disk_buffer
    shr     ax, 5                   ; / 32 = entry index
    mov     [.ren_entry_index], ax
    pop     ax

    ; Check if read-only
    test    byte [di + 11], ATTR_READ_ONLY
    jnz     .ren_access_denied

    ; Check if directory - do not allow moving directories
    test    byte [di + 11], ATTR_DIRECTORY
    jnz     .ren_access_denied

    ; Save the full 32-byte source directory entry
    mov     si, di
    mov     di, .ren_saved_entry
    mov     cx, 32
    rep     movsb

    ; Copy new filename from caller's ES:DI to path_buffer
    push    ds
    mov     ds, [cs:save_es]
    mov     si, [cs:save_di]
    push    cs
    pop     es
    mov     di, path_buffer
    mov     cx, 127
.ren_copy_new:
    lodsb
    stosb
    test    al, al
    jz      .ren_copied_new
    loop    .ren_copy_new
    mov     byte [es:di], 0
.ren_copied_new:
    pop     ds                      ; DS = kernel seg

    ; Resolve new path
    mov     si, path_buffer
    call    resolve_path
    jc      .ren_path_error

    ; AX = new directory cluster, fcb_name_buffer = new filename
    mov     [.ren_new_dir_cluster], ax

    ; Check drives match (both must be on same active_drive_num)
    mov     al, [active_drive_num]
    cmp     al, [.ren_src_drive]
    jne     .ren_not_same_dev

    ; Check if new name already exists in target directory
    push    ax
    mov     ax, [.ren_new_dir_cluster]
    mov     si, fcb_name_buffer
    call    fat_find_in_directory
    pop     ax
    jnc     .ren_exists             ; New name already exists

    ; Save new FCB name
    mov     si, fcb_name_buffer
    mov     di, .ren_new_name
    mov     cx, 11
    rep     movsb

    ; Check if same directory (simple rename) or cross-directory (move)
    mov     ax, [.ren_new_dir_cluster]
    cmp     ax, [.ren_dir_cluster]
    jne     .ren_cross_dir

    ; --- Same directory: simple rename in place ---
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [.ren_entry_sector]
    call    fat_read_sector
    jc      .ren_read_error

    ; Calculate entry pointer
    mov     ax, [.ren_entry_index]
    shl     ax, 5                   ; * 32
    mov     di, disk_buffer
    add     di, ax

    ; Copy new name to entry (first 11 bytes)
    mov     si, .ren_new_name
    mov     cx, 11
    rep     movsb

    ; Write directory sector back
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [.ren_entry_sector]
    call    fat_write_sector
    jc      .ren_write_error

    jmp     .ren_success

.ren_cross_dir:
    ; --- Cross-directory move ---
    ; Step 1: Find empty slot in target directory
    mov     ax, [.ren_new_dir_cluster]
    test    ax, ax
    jnz     .ren_target_subdir

    ; Target is root directory: scan from DPB
    call    fat_get_root_params     ; AX = root_start, CX = root_sectors

.ren_target_root_scan:
    push    cx
    push    ax
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_read_sector
    jc      .ren_target_read_err_pop2

    mov     di, disk_buffer
    xor     cx, cx
.ren_target_root_entry:
    cmp     cx, 16
    jae     .ren_target_root_next
    cmp     byte [di], 0x00         ; End of dir
    je      .ren_target_found_slot
    cmp     byte [di], 0xE5         ; Deleted entry
    je      .ren_target_found_slot
    add     di, 32
    inc     cx
    jmp     .ren_target_root_entry

.ren_target_root_next:
    pop     ax
    pop     cx
    inc     ax
    loop    .ren_target_root_scan
    jmp     .ren_dir_full

.ren_target_found_slot:
    ; DI = empty slot, sector on stack
    pop     ax                      ; Sector number
    mov     [.ren_target_sector], ax
    pop     cx                      ; Restore outer loop CX
    jmp     .ren_do_move

.ren_target_subdir:
    ; Target is subdirectory: walk cluster chain
    mov     dx, ax                  ; DX = current cluster
.ren_target_sub_loop:
    mov     ax, dx
    call    fat_cluster_to_lba
    push    dx
    push    ax
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_read_sector
    pop     ax
    pop     dx
    jc      .ren_read_error

    mov     di, disk_buffer
    xor     cx, cx
.ren_target_sub_entry:
    cmp     cx, 16
    jae     .ren_target_sub_next
    cmp     byte [di], 0x00
    je      .ren_target_sub_found
    cmp     byte [di], 0xE5
    je      .ren_target_sub_found
    add     di, 32
    inc     cx
    jmp     .ren_target_sub_entry

.ren_target_sub_next:
    mov     ax, dx
    call    fat_get_next_cluster
    mov     dx, ax
    cmp     dx, [fat_eoc_min]
    jb      .ren_target_sub_loop
    jmp     .ren_dir_full

.ren_target_sub_found:
    ; DI = empty slot in disk_buffer, DX = cluster
    mov     ax, dx
    call    fat_cluster_to_lba
    mov     [.ren_target_sector], ax

.ren_do_move:
    ; Step 2: Copy saved 32-byte dir entry to new slot, overwrite name
    ; DI = pointer to empty slot in disk_buffer (already positioned)
    mov     si, .ren_saved_entry
    push    di
    mov     cx, 32
    rep     movsb                   ; Copy full 32-byte entry
    pop     di

    ; Overwrite first 11 bytes with new FCB name
    mov     si, .ren_new_name
    mov     cx, 11
    rep     movsb

    ; Step 3: Write target directory sector
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [.ren_target_sector]
    call    fat_write_sector
    jc      .ren_write_error

    ; Step 4: Re-read source directory sector, mark entry as deleted (0xE5)
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [.ren_entry_sector]
    call    fat_read_sector
    jc      .ren_read_error

    mov     ax, [.ren_entry_index]
    shl     ax, 5                   ; * 32
    mov     di, disk_buffer
    add     di, ax
    mov     byte [di], 0xE5         ; Mark as deleted

    ; Step 5: Write source directory sector back
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [.ren_entry_sector]
    call    fat_write_sector
    jc      .ren_write_error

    ; Do NOT free the cluster chain - data now belongs to new entry

.ren_success:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    call    dos_clear_error
    ret

.ren_not_found:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_FILE_NOT_FOUND
    jmp     dos_set_error

.ren_path_error:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_PATH_NOT_FOUND
    jmp     dos_set_error

.ren_access_denied:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_ACCESS_DENIED
    jmp     dos_set_error

.ren_not_same_dev:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_NOT_SAME_DEV
    jmp     dos_set_error

.ren_exists:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_FILE_EXISTS
    jmp     dos_set_error

.ren_dir_full:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_CANNOT_MAKE
    jmp     dos_set_error

.ren_target_read_err_pop2:
    pop     ax
    pop     cx
.ren_read_error:
.ren_write_error:
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_ACCESS_DENIED
    jmp     dos_set_error

; Local variables for rename
.ren_dir_cluster    dw  0
.ren_new_dir_cluster dw 0
.ren_entry_sector   dw  0
.ren_entry_index    dw  0
.ren_target_sector  dw  0
.ren_src_drive      db  0
.ren_new_name       times 11 db 0
.ren_saved_entry    times 32 db 0

; AH=57h - Get/Set file date/time
; Input: AL = 0 (get) or 1 (set)
;        BX = file handle
;        CX = time (if AL=1)
;        DX = date (if AL=1)
; Output: CX = time, DX = date (if AL=0)
;         CF set on error
int21_57:
    push    es
    push    di
    push    si
    push    bp

    ; Get file handle from saved BX
    mov     bx, [save_bx]
    call    handle_to_sft
    jc      .dt_bad_handle

    mov     bp, di                  ; BP = SFT entry pointer

    ; Check subfunction in saved AL
    mov     al, [save_ax]           ; Get AL (subfunction)
    test    al, al
    jz      .dt_get
    cmp     al, 1
    je      .dt_set
    ; Unknown subfunction
    jmp     .dt_invalid

.dt_get:
    ; AL=0: Get file date/time from SFT
    mov     ax, [cs:bp + SFT_ENTRY.time]
    mov     [save_cx], ax           ; Return time in CX
    mov     ax, [cs:bp + SFT_ENTRY.date]
    mov     [save_dx], ax           ; Return date in DX
    jmp     .dt_success

.dt_set:
    ; AL=1: Set file date/time
    ; Update SFT entry
    mov     ax, [save_cx]
    mov     [cs:bp + SFT_ENTRY.time], ax
    mov     ax, [save_dx]
    mov     [cs:bp + SFT_ENTRY.date], ax

    ; Also update directory entry on disk
    ; Read the directory sector
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [cs:bp + SFT_ENTRY.dir_sector]
    call    fat_read_sector
    jc      .dt_read_error

    ; Calculate offset to directory entry
    xor     ah, ah
    mov     al, [cs:bp + SFT_ENTRY.dir_index]
    mov     cl, 5
    shl     ax, cl                  ; AX = index * 32
    mov     di, disk_buffer
    add     di, ax                  ; DI = directory entry

    ; Update time (offset 22) and date (offset 24)
    mov     ax, [save_cx]
    mov     [di + 22], ax           ; Write time
    mov     ax, [save_dx]
    mov     [di + 24], ax           ; Write date

    ; Write directory sector back
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [cs:bp + SFT_ENTRY.dir_sector]
    call    fat_write_sector
    jc      .dt_write_error

.dt_success:
    pop     bp
    pop     si
    pop     di
    pop     es
    call    dos_clear_error
    ret

.dt_bad_handle:
    pop     bp
    pop     si
    pop     di
    pop     es
    mov     ax, ERR_INVALID_HANDLE
    jmp     dos_set_error

.dt_invalid:
    pop     bp
    pop     si
    pop     di
    pop     es
    mov     ax, ERR_INVALID_FUNC
    jmp     dos_set_error

.dt_read_error:
.dt_write_error:
    pop     bp
    pop     si
    pop     di
    pop     es
    mov     ax, ERR_READ_FAULT
    jmp     dos_set_error

; AH=5Ah - Create temporary file
; Input: DS:DX = ASCIIZ path (directory, ending with '\'), CX = attribute
; Output: CF clear, AX = handle, DS:DX buffer has unique filename appended
;         CF set, AX = error code on failure
int21_5A:
    push    es
    push    si
    push    di
    push    bx

    ; Copy path from caller's DS:DX to a local temp area
    push    ds
    mov     ds, [cs:save_ds]
    mov     si, [cs:save_dx]
    push    cs
    pop     es
    mov     di, .tmp_path_buf
    xor     cx, cx                  ; Count bytes copied
.tmp_copy_path:
    cmp     cx, 115                 ; Leave room for 8-char name + null
    jae     .tmp_copy_done
    lodsb
    stosb
    test    al, al
    jz      .tmp_found_end
    inc     cx
    jmp     .tmp_copy_path
.tmp_found_end:
    dec     di                      ; Back up over null terminator
.tmp_copy_done:
    pop     ds                      ; DS = kernel seg

    ; DI now points to end of path string in .tmp_path_buf
    ; Generate 8-char hex filename from ticks_count

.tmp_retry:
    push    di                      ; Save path end position for retry
    mov     ax, [ticks_count + 2]   ; High word
    mov     dx, [ticks_count]       ; Low word

    ; Convert high word (AX) to 4 hex chars
    push    dx                      ; Save low word
    call    .tmp_word_to_hex        ; Writes 4 chars at ES:DI, advances DI
    pop     ax                      ; Low word into AX
    call    .tmp_word_to_hex        ; Writes 4 more chars

    ; Null terminate
    mov     byte [es:di], 0

    ; Copy the complete path+name to the caller's buffer
    push    ds
    push    cs
    pop     ds                      ; DS = kernel seg
    mov     si, .tmp_path_buf
    mov     es, [cs:save_ds]
    mov     di, [cs:save_dx]
.tmp_copy_back:
    lodsb
    mov     [es:di], al
    inc     di
    test    al, al
    jnz     .tmp_copy_back
    pop     ds                      ; DS = kernel seg

    ; Set up for int21_3C_common: save_ds:save_dx already point to caller's buffer
    ; Set create_exclusive = 1 so we fail if file already exists
    mov     byte [create_exclusive], 1

    ; Restore ES to kernel segment before calling create
    push    cs
    pop     es

    pop     di                      ; Restore DI (path end) - consumed by retry

    ; Call int21_3C_common to create the file
    ; save_ds/save_dx already contain the caller's buffer pointer
    ; save_cx already has the attribute from the caller
    call    int21_3C_common

    ; Check if create succeeded (save_flags_cf == 0)
    cmp     byte [save_flags_cf], 0
    je      .tmp_success

    ; Check if failed because file exists - retry with incremented tick
    cmp     word [save_ax], ERR_FILE_EXISTS
    jne     .tmp_fail               ; Some other error, propagate it

    ; Increment ticks_count and retry
    add     word [ticks_count], 1
    adc     word [ticks_count + 2], 0
    ; Need to re-setup DI to path end for retry
    push    cs
    pop     es
    mov     di, .tmp_path_buf
.tmp_find_end:
    cmp     byte [di], 0
    je      .tmp_find_end_done
    inc     di
    jmp     .tmp_find_end
.tmp_find_end_done:
    ; Back up 8 chars (over the generated name)
    sub     di, 8
    jmp     .tmp_retry

.tmp_success:
    ; Handle already in save_ax, carry already clear
    pop     bx
    pop     di
    pop     si
    pop     es
    ret

.tmp_fail:
    ; Error code already in save_ax, carry already set
    pop     bx
    pop     di
    pop     si
    pop     es
    ret

; ---------------------------------------------------------------------------
; .tmp_word_to_hex - Convert AX to 4 uppercase hex chars at ES:DI
; Advances DI by 4
; ---------------------------------------------------------------------------
.tmp_word_to_hex:
    push    cx
    mov     cx, 4
.tmp_hex_loop:
    rol     ax, 4                   ; Rotate high nibble into low
    push    ax
    and     al, 0x0F
    cmp     al, 10
    jb      .tmp_hex_digit
    add     al, 'A' - 10
    jmp     .tmp_hex_store
.tmp_hex_digit:
    add     al, '0'
.tmp_hex_store:
    stosb
    pop     ax
    loop    .tmp_hex_loop
    pop     cx
    ret

; Local buffer for temp file path
.tmp_path_buf   times 128 db 0

; AH=5Bh - Create new file (exclusive)
; Implemented above as int21_5B_impl
int21_5B:
    jmp     int21_5B_impl

; AH=6Ch - Extended open/create
; AH=6Ch - Extended open/create
; Input: AL = open mode (access mode)
;        BL = action flags:
;            Bits 0-3: if file exists (0=fail, 1=open, 2=replace/truncate)
;            Bits 4-7: if file doesn't exist (0=fail, 1=create)
;        CX = file attributes (if creating)
;        DS:DX = ASCIIZ filename
; Output: AX = handle
;         CX = action taken (1=opened, 2=created, 3=replaced)
;         CF set on error
int21_6C:
    push    es
    push    si
    push    di
    push    bx
    push    dx
    push    bp

    ; Save action flags from BL (save_bx low byte)
    mov     ax, [save_bx]
    mov     [.ext_action], al           ; Save action flags

    ; Copy filename from caller's DS:DX to path_buffer
    push    ds
    mov     ds, [cs:save_ds]
    mov     si, [cs:save_dx]
    push    cs
    pop     es
    mov     di, path_buffer
    mov     cx, 127
.ext_copy:
    lodsb
    stosb
    test    al, al
    jz      .ext_copied
    loop    .ext_copy
    mov     byte [es:di], 0
.ext_copied:
    pop     ds

    ; Resolve path to get directory cluster and filename
    mov     si, path_buffer
    call    resolve_path
    jc      .ext_path_not_found

    ; AX = directory cluster, fcb_name_buffer = filename
    mov     [.ext_dir_cluster], ax

    ; Search directory for the file
    mov     si, fcb_name_buffer
    call    fat_find_in_directory
    jc      .ext_not_found

    ; File EXISTS - check action flags bits 0-3
    mov     al, [.ext_action]
    and     al, 0x0F                    ; Bits 0-3: action if exists
    jz      .ext_exists_fail            ; 0 = fail
    cmp     al, 1
    je      .ext_exists_open            ; 1 = open
    cmp     al, 2
    je      .ext_exists_replace         ; 2 = replace/truncate
    jmp     .ext_exists_fail            ; Unknown = fail

.ext_exists_open:
    ; Reject opening a read-only file for write or read-write
    test    byte [di + 11], ATTR_READ_ONLY
    jz      .ext_open_attr_ok
    mov     cl, [save_ax]
    and     cl, 0x07                    ; Access mode bits
    cmp     cl, OPEN_WRITE
    je      .ext_access_denied
    cmp     cl, OPEN_READWRITE
    je      .ext_access_denied
.ext_open_attr_ok:

    ; Open existing file (same as 3Dh open path)
    ; DI = dir entry, AX = sector
    mov     [search_dir_sector], ax
    push    ax
    mov     ax, di
    sub     ax, disk_buffer
    shr     ax, 5
    mov     [search_dir_index], ax
    pop     ax

    ; Save dir entry fields
    push    word [di + 26]              ; Starting cluster
    push    word [di + 28]              ; File size low
    push    word [di + 30]              ; File size high
    push    word [di + 22]              ; Time
    push    word [di + 24]              ; Date
    push    word [di + 11]              ; Attribute

    ; Allocate SFT entry
    call    sft_alloc
    jc      .ext_too_many_pop6

    mov     bx, ax                      ; Save SFT index

    ; Fill SFT entry
    pop     ax
    mov     [di + SFT_ENTRY.attr], al
    pop     ax
    mov     [di + SFT_ENTRY.date], ax
    pop     ax
    mov     [di + SFT_ENTRY.time], ax
    pop     ax
    mov     word [di + SFT_ENTRY.file_size + 2], ax
    pop     ax
    mov     word [di + SFT_ENTRY.file_size], ax
    pop     ax
    mov     [di + SFT_ENTRY.first_cluster], ax
    mov     [di + SFT_ENTRY.cur_cluster], ax

    mov     word [di + SFT_ENTRY.file_pos], 0
    mov     word [di + SFT_ENTRY.file_pos + 2], 0
    mov     word [di + SFT_ENTRY.rel_cluster], 0

    mov     ax, [save_ax]
    and     ax, 0x00FF
    mov     [di + SFT_ENTRY.open_mode], ax

    ; Store BIOS drive number in flags field
    push    ax
    xor     ax, ax
    mov     al, [active_drive_num]
    mov     [di + SFT_ENTRY.flags], ax
    pop     ax

    mov     ax, [search_dir_sector]
    mov     [di + SFT_ENTRY.dir_sector], ax
    mov     ax, [search_dir_index]
    mov     [di + SFT_ENTRY.dir_index], al

    ; Copy FCB name
    push    di
    mov     si, fcb_name_buffer
    add     di, SFT_ENTRY.name
    mov     cx, 11
    rep     movsb
    pop     di

    ; Allocate handle
    mov     cl, bl
    call    handle_alloc
    jc      .ext_too_many_dealloc

    mov     [save_ax], ax               ; Return handle
    mov     word [save_cx], 1           ; Action = opened existing
    jmp     .ext_success

.ext_exists_replace:
    ; Reject replacing a read-only file
    test    byte [di + 11], ATTR_READ_ONLY
    jnz     .ext_access_denied

    ; Replace/truncate existing file - first free its clusters
    mov     [search_dir_sector], ax
    push    ax
    mov     ax, di
    sub     ax, disk_buffer
    shr     ax, 5
    mov     [search_dir_index], ax
    pop     ax

    ; Free existing cluster chain if any
    mov     ax, [di + 26]               ; First cluster
    test    ax, ax
    jz      .ext_replace_no_chain
    cmp     ax, 2
    jb      .ext_replace_no_chain
    call    fat_free_chain

.ext_replace_no_chain:
    ; Reset file to empty
    xor     ax, ax
    mov     [di + 26], ax               ; First cluster = 0
    mov     [di + 28], ax               ; Size low = 0
    mov     [di + 30], ax               ; Size high = 0

    ; Write directory sector back
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [search_dir_sector]
    call    fat_write_sector
    jc      .ext_write_error

    ; Now open the truncated file
    mov     ax, [search_dir_sector]
    call    fat_read_sector             ; Re-read the sector
    jc      .ext_read_error

    ; Find entry again
    mov     ax, [search_dir_index]
    shl     ax, 5
    mov     di, disk_buffer
    add     di, ax

    ; Save fields and allocate SFT
    push    word [di + 26]              ; Starting cluster
    push    word [di + 28]              ; File size low
    push    word [di + 30]              ; File size high
    push    word [di + 22]              ; Time
    push    word [di + 24]              ; Date
    push    word [di + 11]              ; Attribute

    call    sft_alloc
    jc      .ext_too_many_pop6

    mov     bx, ax

    pop     ax
    mov     [di + SFT_ENTRY.attr], al
    pop     ax
    mov     [di + SFT_ENTRY.date], ax
    pop     ax
    mov     [di + SFT_ENTRY.time], ax
    pop     ax
    mov     word [di + SFT_ENTRY.file_size + 2], ax
    pop     ax
    mov     word [di + SFT_ENTRY.file_size], ax
    pop     ax
    mov     [di + SFT_ENTRY.first_cluster], ax
    mov     [di + SFT_ENTRY.cur_cluster], ax

    mov     word [di + SFT_ENTRY.file_pos], 0
    mov     word [di + SFT_ENTRY.file_pos + 2], 0
    mov     word [di + SFT_ENTRY.rel_cluster], 0

    mov     ax, [save_ax]
    and     ax, 0x00FF
    mov     [di + SFT_ENTRY.open_mode], ax

    ; Store BIOS drive number in flags field
    push    ax
    xor     ax, ax
    mov     al, [active_drive_num]
    mov     [di + SFT_ENTRY.flags], ax
    pop     ax

    mov     ax, [search_dir_sector]
    mov     [di + SFT_ENTRY.dir_sector], ax
    mov     ax, [search_dir_index]
    mov     [di + SFT_ENTRY.dir_index], al

    push    di
    mov     si, fcb_name_buffer
    add     di, SFT_ENTRY.name
    mov     cx, 11
    rep     movsb
    pop     di

    mov     cl, bl
    call    handle_alloc
    jc      .ext_too_many_dealloc

    mov     [save_ax], ax               ; Return handle
    mov     word [save_cx], 3           ; Action = replaced/truncated
    jmp     .ext_success

.ext_not_found:
    ; File does NOT exist - check action flags bits 4-7
    mov     al, [.ext_action]
    shr     al, 4                       ; Bits 4-7: action if not exists
    jz      .ext_not_found_fail         ; 0 = fail
    cmp     al, 1
    je      .ext_not_found_create       ; 1 = create
    jmp     .ext_not_found_fail         ; Unknown = fail

.ext_not_found_create:
    ; Create new file - use 3Ch create logic
    ; Set up for create: save_cx has attributes
    mov     byte [cs:create_exclusive], 0
    mov     ax, [.ext_dir_cluster]
    mov     [create_dir_cluster], ax

    ; Need to find empty slot and create entry
    ; Jump into the create code path after setup
    ; This is complex - for simplicity, call the create function indirectly
    ; by setting up state and using common create logic

    ; Find empty directory slot
    mov     ax, [.ext_dir_cluster]
    test    ax, ax
    jnz     .ext_create_subdir

    ; Root directory scan from DPB
    call    fat_get_root_params     ; AX = root_start, CX = root_sectors
.ext_scan_root:
    push    cx
    push    ax
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_read_sector
    jc      .ext_read_error_pop2

    mov     di, disk_buffer
    xor     cx, cx
.ext_scan_root_entry:
    cmp     cx, 16
    jae     .ext_next_root_sector
    cmp     byte [di], 0x00
    je      .ext_found_slot
    cmp     byte [di], 0xE5
    je      .ext_found_slot
    add     di, 32
    inc     cx
    jmp     .ext_scan_root_entry

.ext_next_root_sector:
    pop     ax
    pop     cx
    inc     ax
    loop    .ext_scan_root
    jmp     .ext_dir_full

.ext_found_slot:
    pop     ax
    mov     [search_dir_sector], ax
    mov     [search_dir_index], cx
    pop     cx
    jmp     .ext_init_entry

.ext_create_subdir:
    mov     dx, ax
.ext_subdir_loop:
    mov     ax, dx
    call    fat_cluster_to_lba
    push    dx
    push    ax
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_read_sector
    pop     ax
    pop     dx
    jc      .ext_read_error

    mov     di, disk_buffer
    xor     cx, cx
.ext_subdir_entry:
    cmp     cx, 16
    jae     .ext_subdir_next
    cmp     byte [di], 0x00
    je      .ext_found_subdir_slot
    cmp     byte [di], 0xE5
    je      .ext_found_subdir_slot
    add     di, 32
    inc     cx
    jmp     .ext_subdir_entry

.ext_subdir_next:
    mov     ax, dx
    call    fat_get_next_cluster
    mov     dx, ax
    cmp     dx, [fat_eoc_min]
    jb      .ext_subdir_loop
    jmp     .ext_dir_full

.ext_found_subdir_slot:
    mov     ax, dx
    call    fat_cluster_to_lba
    mov     [search_dir_sector], ax
    mov     [search_dir_index], cx

.ext_init_entry:
    ; Initialize directory entry
    push    di
    mov     si, fcb_name_buffer
    mov     cx, 11
    rep     movsb
    pop     di

    ; Set attribute from saved CX
    mov     ax, [save_cx]
    mov     [di + 11], al

    ; Zero out other fields
    xor     ax, ax
    mov     [di + 12], ax
    mov     [di + 14], ax
    mov     [di + 16], ax
    mov     [di + 18], ax
    mov     [di + 20], ax

    ; Set time/date from RTC
    push    di
    call    get_dos_datetime        ; CX = packed time, DX = packed date
    pop     di
    mov     [di + 22], cx           ; Time
    mov     [di + 24], dx           ; Date

    xor     ax, ax
    mov     [di + 26], ax
    mov     [di + 28], ax
    mov     [di + 30], ax

    ; Write directory sector
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [search_dir_sector]
    call    fat_write_sector
    jc      .ext_write_error

    ; Now open the newly created file
    push    word [di + 26]
    push    word [di + 28]
    push    word [di + 30]
    push    word [di + 22]
    push    word [di + 24]
    push    word [di + 11]

    call    sft_alloc
    jc      .ext_too_many_pop6

    mov     bx, ax

    pop     ax
    mov     [di + SFT_ENTRY.attr], al
    pop     ax
    mov     [di + SFT_ENTRY.date], ax
    pop     ax
    mov     [di + SFT_ENTRY.time], ax
    pop     ax
    mov     word [di + SFT_ENTRY.file_size + 2], ax
    pop     ax
    mov     word [di + SFT_ENTRY.file_size], ax
    pop     ax
    mov     [di + SFT_ENTRY.first_cluster], ax
    mov     [di + SFT_ENTRY.cur_cluster], ax

    mov     word [di + SFT_ENTRY.file_pos], 0
    mov     word [di + SFT_ENTRY.file_pos + 2], 0
    mov     word [di + SFT_ENTRY.rel_cluster], 0

    mov     ax, [save_ax]
    and     ax, 0x00FF
    mov     [di + SFT_ENTRY.open_mode], ax

    ; Store BIOS drive number in flags field
    push    ax
    xor     ax, ax
    mov     al, [active_drive_num]
    mov     [di + SFT_ENTRY.flags], ax
    pop     ax

    mov     ax, [search_dir_sector]
    mov     [di + SFT_ENTRY.dir_sector], ax
    mov     ax, [search_dir_index]
    mov     [di + SFT_ENTRY.dir_index], al

    push    di
    mov     si, fcb_name_buffer
    add     di, SFT_ENTRY.name
    mov     cx, 11
    rep     movsb
    pop     di

    mov     cl, bl
    call    handle_alloc
    jc      .ext_too_many_dealloc

    mov     [save_ax], ax               ; Return handle
    mov     word [save_cx], 2           ; Action = created new
    jmp     .ext_success

.ext_success:
    pop     bp
    pop     dx
    pop     bx
    pop     di
    pop     si
    pop     es
    call    dos_clear_error
    ret

.ext_too_many_dealloc:
    mov     ax, bx
    call    sft_dealloc
    jmp     .ext_too_many

.ext_too_many_pop6:
    add     sp, 12
.ext_too_many:
    pop     bp
    pop     dx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_TOO_MANY_FILES
    jmp     dos_set_error

.ext_read_error_pop2:
    add     sp, 4
.ext_read_error:
    pop     bp
    pop     dx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_READ_FAULT
    jmp     dos_set_error

.ext_write_error:
    pop     bp
    pop     dx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_WRITE_FAULT
    jmp     dos_set_error

.ext_access_denied:
    pop     bp
    pop     dx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_ACCESS_DENIED
    jmp     dos_set_error

.ext_exists_fail:
    pop     bp
    pop     dx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_FILE_EXISTS
    jmp     dos_set_error

.ext_not_found_fail:
.ext_path_not_found:
    pop     bp
    pop     dx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_FILE_NOT_FOUND
    jmp     dos_set_error

.ext_dir_full:
    pop     bp
    pop     dx
    pop     bx
    pop     di
    pop     si
    pop     es
    mov     ax, ERR_CANNOT_MAKE
    jmp     dos_set_error

; Local data for extended open
.ext_action     db  0
.ext_dir_cluster dw 0

; ---------------------------------------------------------------------------
; get_dos_datetime - Read RTC and return DOS-format packed time/date
; Output: CX = packed time (hours*2048 + minutes*32 + seconds/2)
;         DX = packed date ((year-1980)*512 + month*32 + day)
; Clobbers: AX
; ---------------------------------------------------------------------------
get_dos_datetime:
    push    bx

    ; Read RTC time: CH=hours(BCD), CL=minutes(BCD), DH=seconds(BCD)
    mov     ah, 0x02
    int     0x1A
    jc      .gdt_fallback

    ; Save BCD values
    mov     [cs:.gdt_hours], ch
    mov     [cs:.gdt_minutes], cl
    mov     [cs:.gdt_seconds], dh

    ; Read RTC date: CH=century(BCD), CL=year(BCD), DH=month(BCD), DL=day(BCD)
    mov     ah, 0x04
    int     0x1A
    jc      .gdt_fallback

    mov     [cs:.gdt_year], cl
    mov     [cs:.gdt_month], dh
    mov     [cs:.gdt_day], dl

    ; Convert hours BCD -> binary
    mov     al, [cs:.gdt_hours]
    call    bcd_to_bin
    xor     ah, ah
    mov     bx, ax                  ; BX = hours

    ; Pack time: hours*2048
    shl     bx, 11                  ; BX = hours << 11

    ; Convert minutes BCD -> binary
    mov     al, [cs:.gdt_minutes]
    call    bcd_to_bin
    xor     ah, ah
    shl     ax, 5                   ; AX = minutes << 5
    or      bx, ax                  ; BX |= minutes << 5

    ; Convert seconds BCD -> binary
    mov     al, [cs:.gdt_seconds]
    call    bcd_to_bin
    xor     ah, ah
    shr     ax, 1                   ; AX = seconds / 2
    or      bx, ax                  ; BX |= seconds / 2

    mov     cx, bx                  ; CX = packed time

    ; Convert year BCD -> binary (2-digit, assume 2000s: add 20 for DOS offset)
    mov     al, [cs:.gdt_year]
    call    bcd_to_bin
    xor     ah, ah
    add     ax, 20                  ; year_since_1980 = year_2digit + 20

    ; Pack date: (year-1980)*512
    shl     ax, 9                   ; AX = year_since_1980 << 9
    mov     dx, ax                  ; DX = year part

    ; Convert month BCD -> binary
    mov     al, [cs:.gdt_month]
    call    bcd_to_bin
    xor     ah, ah
    shl     ax, 5                   ; AX = month << 5
    or      dx, ax                  ; DX |= month << 5

    ; Convert day BCD -> binary
    mov     al, [cs:.gdt_day]
    call    bcd_to_bin
    xor     ah, ah
    or      dx, ax                  ; DX |= day

    pop     bx
    ret

.gdt_fallback:
    ; RTC not available - return a fixed date/time
    ; 2025-01-01 00:00:00 -> date=(45*512)+(1*32)+1=23073, time=0
    xor     cx, cx
    mov     dx, (45 << 9) | (1 << 5) | 1
    pop     bx
    ret

; Local storage for get_dos_datetime
.gdt_hours      db  0
.gdt_minutes    db  0
.gdt_seconds    db  0
.gdt_year       db  0
.gdt_month      db  0
.gdt_day        db  0

; ---------------------------------------------------------------------------
; File I/O local data
; ---------------------------------------------------------------------------
create_dir_cluster  dw  0           ; Target directory cluster for file creation
create_exclusive    db  0           ; 1 if exclusive create (5Bh), 0 for normal (3Ch)
