; ===========================================================================
; claudeDOS XMS 2.0 Driver
; Provides Extended Memory Specification support for DOS extenders
; ===========================================================================

; ---------------------------------------------------------------------------
; XMS Entry Point
; Called via far call with AH = function number
; ---------------------------------------------------------------------------
xms_entry:
    jmp     short xms_dispatch
    nop
    nop
    nop                             ; 5-byte entry (XMS spec requirement)

xms_dispatch:
    ; Debug: print XMS function number to serial (COM1)
    push    ax
    push    dx
    push    bx
    mov     bl, ah                  ; Save function number
    mov     dx, 0x3F8
    mov     al, '['
    out     dx, al
    mov     al, bl                  ; Get function number
    push    ax
    shr     al, 4                   ; High nibble
    add     al, '0'
    cmp     al, '9'
    jbe     .d1
    add     al, 7                   ; A-F
.d1:
    out     dx, al
    pop     ax
    and     al, 0x0F                ; Low nibble
    add     al, '0'
    cmp     al, '9'
    jbe     .d2
    add     al, 7
.d2:
    out     dx, al
    mov     al, ']'
    out     dx, al
    pop     bx
    pop     dx
    pop     ax

    cmp     ah, 00h
    je      xms_get_version
    cmp     ah, 03h
    je      xms_enable_a20
    cmp     ah, 04h
    je      xms_disable_a20
    cmp     ah, 05h
    je      xms_local_enable_a20
    cmp     ah, 06h
    je      xms_local_disable_a20
    cmp     ah, 07h
    je      xms_query_a20
    cmp     ah, 08h
    je      xms_query_free
    cmp     ah, 09h
    je      xms_alloc_emb
    cmp     ah, 0Ah
    je      xms_free_emb
    cmp     ah, 0Bh
    je      xms_move_emb
    cmp     ah, 0Ch
    je      xms_lock_emb
    cmp     ah, 0Dh
    je      xms_unlock_emb
    cmp     ah, 0Eh
    je      xms_get_emb_info
    cmp     ah, 0Fh
    je      xms_realloc_emb
    ; XMS 3.0 functions (32-bit versions)
    cmp     ah, 88h
    je      xms_query_free_32
    cmp     ah, 89h
    je      xms_alloc_emb_32
    cmp     ah, 8Eh
    je      xms_get_emb_info_32
    cmp     ah, 8Fh
    je      xms_realloc_emb_32

    ; Unknown function - return error
    xor     ax, ax                  ; AX = 0 = failure
    mov     bl, 80h                 ; BL = 80h = not implemented
    retf

; ---------------------------------------------------------------------------
; Function 00h: Get XMS Version
; Returns: AX = XMS version (BCD), BX = internal revision, DX = HMA exists
; ---------------------------------------------------------------------------
xms_get_version:
    mov     ax, 0x0300              ; XMS version 3.0
    mov     bx, 0x0000              ; Internal revision 0
    mov     dx, 0x0001              ; HMA exists (required by some extenders)
    retf

; ---------------------------------------------------------------------------
; Function 03h: Global Enable A20
; Function 05h: Local Enable A20
; Returns: AX = 1 success, BL = 0
; ---------------------------------------------------------------------------
xms_enable_a20:
xms_local_enable_a20:
    ; A20 is typically already enabled in QEMU
    ; For real hardware, we'd use port 0x92 or keyboard controller
    mov     ax, 1                   ; Success
    xor     bl, bl                  ; No error
    retf

; ---------------------------------------------------------------------------
; Function 04h: Global Disable A20
; Function 06h: Local Disable A20
; Returns: AX = 1 success, BL = 0
; ---------------------------------------------------------------------------
xms_disable_a20:
xms_local_disable_a20:
    ; Stub - A20 stays enabled
    mov     ax, 1                   ; Success
    xor     bl, bl                  ; No error
    retf

; ---------------------------------------------------------------------------
; Function 07h: Query A20 State
; Returns: AX = 1 if A20 enabled, 0 if disabled
; ---------------------------------------------------------------------------
xms_query_a20:
    mov     ax, 1                   ; A20 is enabled
    xor     bl, bl
    retf

; ---------------------------------------------------------------------------
; Function 08h: Query Free Extended Memory
; Returns: AX = largest free block in KB, DX = total free KB
; ---------------------------------------------------------------------------
xms_query_free:
    mov     ax, [cs:xms_free_kb]
    mov     dx, ax                  ; DX = total free extended memory
    xor     bl, bl                  ; No error
    retf

; ---------------------------------------------------------------------------
; Function 09h: Allocate Extended Memory Block
; Input: DX = size in KB
; Returns: AX = 1 success, DX = handle; AX = 0 failure, BL = error
; ---------------------------------------------------------------------------
xms_alloc_emb:
    push    cx
    push    si
    push    di

    ; Check if requested size is available
    cmp     dx, [cs:xms_free_kb]
    ja      .no_memory

    ; Find a free handle
    mov     si, xms_handles
    mov     cx, XMS_MAX_HANDLES
    xor     di, di                  ; DI = handle number (1-based)

.find_handle:
    inc     di
    cmp     word [cs:si], 0         ; 0 = free handle
    je      .found_handle
    add     si, XMS_HANDLE_SIZE
    loop    .find_handle

    ; No free handles
    mov     ax, 0
    mov     bl, 0A1h                ; All handles in use
    jmp     .done

.found_handle:
    ; SI points to free handle entry, DI = handle number
    ; Store the size in the handle
    mov     [cs:si], dx             ; Handle.size = requested KB

    ; Calculate linear address for this block
    ; Start from 1MB (0x100000) and allocate sequentially
    ; For simplicity: address = 0x100000 + (total_kb - free_kb) * 1024
    push    dx
    mov     ax, [cs:xms_total_kb]
    sub     ax, [cs:xms_free_kb]
    ; AX = KB already allocated
    ; Convert to 32-bit address: multiply by 1024
    ; Store as high:low in handle
    xor     dx, dx
    mov     cx, 1024
    mul     cx                      ; DX:AX = offset from 1MB
    add     ax, 0x0000              ; Add 1MB base (low word)
    adc     dx, 0x0010              ; Add 1MB base (high word = 0x10)
    mov     [cs:si + 2], ax         ; Handle.addr_lo
    mov     [cs:si + 4], dx         ; Handle.addr_hi
    pop     dx

    ; Subtract from free memory
    sub     [cs:xms_free_kb], dx

    ; Return success
    mov     ax, 1
    mov     dx, di                  ; DX = handle number
    xor     bl, bl

.done:
    pop     di
    pop     si
    pop     cx
    retf

.no_memory:
    mov     ax, 0
    mov     bl, 0A0h                ; All extended memory allocated
    jmp     .done

; ---------------------------------------------------------------------------
; Function 0Ah: Free Extended Memory Block
; Input: DX = handle
; Returns: AX = 1 success, AX = 0 failure
; ---------------------------------------------------------------------------
xms_free_emb:
    push    si

    ; Validate handle
    cmp     dx, 0
    je      .invalid
    cmp     dx, XMS_MAX_HANDLES
    ja      .invalid

    ; Get handle entry
    mov     si, xms_handles
    push    dx
    dec     dx                      ; Convert to 0-based
    mov     ax, XMS_HANDLE_SIZE
    mul     dx
    add     si, ax
    pop     dx

    ; Check if handle is in use
    cmp     word [cs:si], 0
    je      .invalid

    ; Add size back to free pool
    mov     ax, [cs:si]
    add     [cs:xms_free_kb], ax

    ; Mark handle as free
    mov     word [cs:si], 0
    mov     word [cs:si + 2], 0
    mov     word [cs:si + 4], 0

    mov     ax, 1
    xor     bl, bl
    pop     si
    retf

.invalid:
    mov     ax, 0
    mov     bl, 0A2h                ; Invalid handle
    pop     si
    retf

; ---------------------------------------------------------------------------
; Function 0Bh: Move Extended Memory Block
; Input: DS:SI = pointer to move structure
; Returns: AX = 1 success, AX = 0 failure
;
; Move structure:
;   +00h  DWORD  Length in bytes (must be even)
;   +04h  WORD   Source handle (0 = conventional memory)
;   +06h  DWORD  Source offset (seg:off if handle=0, else linear offset)
;   +0Ah  WORD   Dest handle (0 = conventional memory)
;   +0Ch  DWORD  Dest offset (seg:off if handle=0, else linear offset)
;
; Uses INT 15h AH=87h (BIOS block move) to copy memory.
; ---------------------------------------------------------------------------
xms_move_emb:
    push    bp
    mov     bp, sp
    push    es
    push    di
    push    cx
    push    bx
    push    dx

    ; Debug: print 'M' when move is called (to serial)
    push    ax
    push    dx
    mov     dx, 0x3F8
    mov     al, 'M'
    out     dx, al
    pop     dx
    pop     ax

    ; Save pointer to move structure
    mov     [cs:xms_move_struct_off], si
    mov     [cs:xms_move_struct_seg], ds

    ; Get length - must be even; copied in 64KB chunks via INT 15h
    mov     ax, [si]                ; Low word of length
    mov     dx, [si + 2]            ; High word of length

    ; Check for zero length
    or      ax, dx
    jz      .success

    ; Check if length is even (required by INT 15h)
    test    byte [si], 1
    jnz     .invalid_length

    ; Store remaining byte count for chunked copy loop
    mov     ax, [si]                ; Reload low word (AX was modified by OR)
    mov     [cs:xms_move_remain_lo], ax
    mov     [cs:xms_move_remain_hi], dx

    ; Calculate source linear address
    mov     bx, [si + 4]            ; Source handle
    test    bx, bx
    jz      .src_conventional

    ; Source is extended memory - look up handle
    call    xms_handle_to_linear    ; BX = handle, returns DX:AX = linear
    jc      .invalid_handle
    ; Add offset from move structure
    push    ds
    mov     ds, [cs:xms_move_struct_seg]
    mov     si, [cs:xms_move_struct_off]
    add     ax, [si + 6]            ; Add low word of offset
    adc     dx, [si + 8]            ; Add high word of offset
    pop     ds
    jmp     .src_done

.src_conventional:
    ; Source is conventional memory - seg:off format
    ; Linear = segment * 16 + offset
    mov     ax, [si + 8]            ; Segment (high word of "offset" field)
    mov     dx, ax
    shr     dx, 12                  ; DX = high nibble of segment
    shl     ax, 4                   ; AX = segment * 16 (low 16 bits)
    add     ax, [si + 6]            ; Add offset
    adc     dx, 0                   ; Carry into high word

.src_done:
    ; Store source linear address (32-bit)
    mov     [cs:xms_move_src_lo], ax
    mov     [cs:xms_move_src_hi], dx

    ; Reload structure pointer
    mov     ds, [cs:xms_move_struct_seg]
    mov     si, [cs:xms_move_struct_off]

    ; Calculate dest linear address
    mov     bx, [si + 0Ah]          ; Dest handle
    test    bx, bx
    jz      .dst_conventional

    ; Dest is extended memory - look up handle
    call    xms_handle_to_linear    ; BX = handle, returns DX:AX = linear
    jc      .invalid_handle
    ; Add offset from move structure
    push    ds
    mov     ds, [cs:xms_move_struct_seg]
    mov     si, [cs:xms_move_struct_off]
    add     ax, [si + 0Ch]          ; Add low word of offset
    adc     dx, [si + 0Eh]          ; Add high word of offset
    pop     ds
    jmp     .dst_done

.dst_conventional:
    ; Dest is conventional memory - seg:off format
    mov     ax, [si + 0Eh]          ; Segment (high word of "offset" field)
    mov     dx, ax
    shr     dx, 12
    shl     ax, 4
    add     ax, [si + 0Ch]          ; Add offset
    adc     dx, 0

.dst_done:
    ; Store dest linear address (32-bit)
    mov     [cs:xms_move_dst_lo], ax
    mov     [cs:xms_move_dst_hi], dx

    ; === Chunked move loop: up to 64KB per INT 15h AH=87h call ===
.move_loop:
    ; Check if remaining bytes is zero
    mov     ax, [cs:xms_move_remain_lo]
    or      ax, [cs:xms_move_remain_hi]
    jz      .success

    ; Determine chunk size: min(remaining, 64KB)
    ; CX = word count for this chunk
    cmp     word [cs:xms_move_remain_hi], 0
    jne     .full_chunk             ; remaining > 64KB, use full 64KB chunk
    ; Partial (last) chunk: remaining fits in 16 bits
    mov     cx, [cs:xms_move_remain_lo]
    shr     cx, 1                   ; Bytes to words
    jmp     .do_chunk

.full_chunk:
    mov     cx, 0x8000              ; 64KB = 0x8000 words

.do_chunk:
    ; Save word count (INT 15h may clobber CX)
    mov     [cs:xms_move_chunk_words], cx

    ; Build GDT for INT 15h AH=87h (48 bytes)
    push    cs
    pop     es
    mov     di, xms_gdt

    ; Clear entire GDT (48 bytes = 24 words)
    push    di
    push    cx
    mov     cx, 24
    xor     ax, ax
    rep     stosw
    pop     cx
    pop     di

    ; Source descriptor at GDT+10h (8-byte segment descriptor)
    mov     word [es:di + 10h], 0xFFFF    ; Limit = 64KB
    mov     ax, [cs:xms_move_src_lo]
    mov     [es:di + 12h], ax             ; Base bits 0-15
    mov     ax, [cs:xms_move_src_hi]
    mov     [es:di + 14h], al             ; Base bits 16-23
    mov     byte [es:di + 15h], 93h       ; Access: present, data, writable
    mov     [es:di + 17h], ah             ; Base bits 24-31

    ; Dest descriptor at GDT+18h (8-byte segment descriptor)
    mov     word [es:di + 18h], 0xFFFF    ; Limit = 64KB
    mov     ax, [cs:xms_move_dst_lo]
    mov     [es:di + 1Ah], ax             ; Base bits 0-15
    mov     ax, [cs:xms_move_dst_hi]
    mov     [es:di + 1Ch], al             ; Base bits 16-23
    mov     byte [es:di + 1Dh], 93h       ; Access: present, data, writable
    mov     [es:di + 1Fh], ah             ; Base bits 24-31

    ; Call INT 15h AH=87h: ES:SI = GDT, CX = word count
    mov     si, xms_gdt
    mov     cx, [cs:xms_move_chunk_words]
    mov     ah, 87h
    pushf
    call    far [cs:int15_old_vector]
    jc      .bios_error

    ; Advance addresses and subtract from remaining
    ; Reload word count (INT 15h may have clobbered CX)
    mov     cx, [cs:xms_move_chunk_words]
    shl     cx, 1                   ; Words back to bytes (CF=1 if 64KB overflow)
    jz      .advance_64k            ; 0x8000 words << 1 = 0x10000, overflows to 0

    ; Partial chunk: advance by CX bytes
    add     [cs:xms_move_src_lo], cx
    adc     word [cs:xms_move_src_hi], 0
    add     [cs:xms_move_dst_lo], cx
    adc     word [cs:xms_move_dst_hi], 0
    sub     [cs:xms_move_remain_lo], cx
    sbb     word [cs:xms_move_remain_hi], 0
    jmp     .move_loop

.advance_64k:
    ; Full 64KB chunk: advance addresses by 0x10000
    inc     word [cs:xms_move_src_hi]
    inc     word [cs:xms_move_dst_hi]
    sub     word [cs:xms_move_remain_lo], 0
    sbb     word [cs:xms_move_remain_hi], 1
    jmp     .move_loop

.success:
    ; Debug: print 'K' on success (to serial)
    push    ax
    push    dx
    mov     dx, 0x3F8
    mov     al, 'K'
    out     dx, al
    pop     dx
    pop     ax

    mov     ax, 1
    xor     bl, bl
    jmp     .done

.invalid_length:
    mov     ax, 0
    mov     bl, 0A7h                ; Invalid length (odd)
    jmp     .done

.invalid_handle:
    mov     ax, 0
    mov     bl, 0A2h                ; Invalid handle
    jmp     .done

.bios_error:
    ; Debug: print 'E' on BIOS error (to serial)
    push    ax
    push    dx
    mov     dx, 0x3F8
    mov     al, 'E'
    out     dx, al
    pop     dx
    pop     ax
    mov     ax, 0
    mov     bl, 0A3h                ; A20 error (generic move error)

.done:
    pop     dx
    pop     bx
    pop     cx
    pop     di
    pop     es
    pop     bp
    retf

; ---------------------------------------------------------------------------
; xms_handle_to_linear - Convert XMS handle to linear address
; Input: BX = handle number
; Output: DX:AX = linear address, CF set on error
; ---------------------------------------------------------------------------
xms_handle_to_linear:
    push    si

    ; Validate handle
    cmp     bx, 0
    je      .htl_invalid
    cmp     bx, XMS_MAX_HANDLES
    ja      .htl_invalid

    ; Get handle entry
    mov     si, xms_handles
    push    bx
    dec     bx                      ; Convert to 0-based
    mov     ax, XMS_HANDLE_SIZE
    mul     bx
    add     si, ax
    pop     bx

    ; Check if handle is in use
    cmp     word [cs:si], 0
    je      .htl_invalid

    ; Return linear address
    mov     ax, [cs:si + 2]         ; Low word
    mov     dx, [cs:si + 4]         ; High word
    clc
    pop     si
    ret

.htl_invalid:
    stc
    pop     si
    ret

; ---------------------------------------------------------------------------
; Function 0Ch: Lock Extended Memory Block
; Input: DX = handle
; Returns: AX = 1, DX:BX = 32-bit linear address
; ---------------------------------------------------------------------------
xms_lock_emb:
    push    si

    ; Validate handle
    cmp     dx, 0
    je      .invalid_lock
    cmp     dx, XMS_MAX_HANDLES
    ja      .invalid_lock

    ; Get handle entry
    mov     si, xms_handles
    push    dx
    dec     dx
    mov     ax, XMS_HANDLE_SIZE
    mul     dx
    add     si, ax
    pop     dx

    ; Check if handle is in use
    cmp     word [cs:si], 0
    je      .invalid_lock

    ; Return the linear address
    mov     bx, [cs:si + 2]         ; Low word of address
    mov     dx, [cs:si + 4]         ; High word of address
    mov     ax, 1                   ; Success (BL not used on success)
    pop     si
    retf

.invalid_lock:
    mov     ax, 0
    mov     bl, 0A2h
    pop     si
    retf

; ---------------------------------------------------------------------------
; Function 0Dh: Unlock Extended Memory Block
; Input: DX = handle
; Returns: AX = 1 success
; ---------------------------------------------------------------------------
xms_unlock_emb:
    ; For our simple implementation, unlock is always successful
    mov     ax, 1
    xor     bl, bl
    retf

; ---------------------------------------------------------------------------
; Function 0Eh: Get EMB Handle Information
; Input: DX = handle
; Returns: AX = 1, BH = lock count, BL = free handles, DX = size in KB
; ---------------------------------------------------------------------------
xms_get_emb_info:
    push    si
    push    cx

    ; Validate handle
    cmp     dx, 0
    je      .invalid_info
    cmp     dx, XMS_MAX_HANDLES
    ja      .invalid_info

    ; Get handle entry
    mov     si, xms_handles
    push    dx
    dec     dx
    mov     ax, XMS_HANDLE_SIZE
    mul     dx
    add     si, ax
    pop     dx

    ; Check if handle is in use
    cmp     word [cs:si], 0
    je      .invalid_info

    ; Count free handles
    push    si
    mov     si, xms_handles
    mov     cx, XMS_MAX_HANDLES
    xor     bx, bx                  ; BL = free handle count
.count_free:
    cmp     word [cs:si], 0
    jne     .not_free
    inc     bl
.not_free:
    add     si, XMS_HANDLE_SIZE
    loop    .count_free
    pop     si

    ; BH = lock count (always 0 for our impl)
    ; BL = free handles (counted above)
    ; DX = block size in KB
    mov     dx, [cs:si]
    xor     bh, bh
    mov     ax, 1

    pop     cx
    pop     si
    retf

.invalid_info:
    mov     ax, 0
    mov     bl, 0A2h
    pop     cx
    pop     si
    retf

; ---------------------------------------------------------------------------
; Function 0Fh: Reallocate Extended Memory Block
; Input: DX = handle, BX = new size in KB
; Returns: AX = 1 success
; ---------------------------------------------------------------------------
xms_realloc_emb:
    push    si

    ; Validate handle
    cmp     dx, 0
    je      .invalid_realloc
    cmp     dx, XMS_MAX_HANDLES
    ja      .invalid_realloc

    ; Get handle entry
    mov     si, xms_handles
    push    dx
    dec     dx
    mov     ax, XMS_HANDLE_SIZE
    mul     dx
    add     si, ax
    pop     dx

    ; Check if handle is in use
    mov     ax, [cs:si]             ; AX = old size
    test    ax, ax
    jz      .invalid_realloc

    ; Realloc: check BEFORE modifying free memory
    ; AX = old size, BX = new size
    cmp     bx, ax
    je      .realloc_same
    ja      .realloc_grow

    ; Shrinking: delta = old - new, add to free
    push    ax
    sub     ax, bx
    add     [cs:xms_free_kb], ax
    pop     ax
    jmp     .realloc_update

.realloc_grow:
    ; Growing: delta = new - old, check availability
    push    bx
    sub     bx, ax
    cmp     bx, [cs:xms_free_kb]
    ja      .realloc_fail_pop
    sub     [cs:xms_free_kb], bx
    pop     bx
    jmp     .realloc_update

.realloc_fail_pop:
    pop     bx
    jmp     .invalid_realloc_mem    ; Return error

.realloc_update:
    mov     [cs:si], bx
.realloc_same:
    mov     ax, 1
    xor     bl, bl
    pop     si
    retf

.invalid_realloc_mem:
    mov     ax, 0
    mov     bl, 0A0h                ; Out of memory
    pop     si
    retf

.invalid_realloc:
    mov     ax, 0
    mov     bl, 0A2h
    pop     si
    retf

; ---------------------------------------------------------------------------
; XMS 3.0 Function 88h: Query Free Extended Memory (32-bit)
; Returns: EAX = largest free block in KB, EDX = total free KB
;          ECX = highest ending address of any memory block
; For 186: we use AX/DX and set high words to 0
; ---------------------------------------------------------------------------
xms_query_free_32:
    mov     ax, [cs:xms_free_kb]
    mov     dx, ax                  ; DX = total free (low word)
    xor     bl, bl                  ; No error
    retf

; ---------------------------------------------------------------------------
; XMS 3.0 Function 89h: Allocate Extended Memory Block (32-bit)
; Input: EDX = size in KB (we only use DX, the low 16 bits)
; Returns: AX = 1 success, DX = handle; AX = 0 failure, BL = error
; ---------------------------------------------------------------------------
xms_alloc_emb_32:
    ; Just call the 16-bit version - DX already has size (low word)
    jmp     xms_alloc_emb

; ---------------------------------------------------------------------------
; XMS 3.0 Function 8Eh: Get EMB Handle Information (32-bit)
; Input: DX = handle
; Returns: AX = 1, BH = lock count, CX = free handles, EDX = size in KB
; ---------------------------------------------------------------------------
xms_get_emb_info_32:
    push    si

    ; Validate handle
    cmp     dx, 0
    je      .invalid_info32
    cmp     dx, XMS_MAX_HANDLES
    ja      .invalid_info32

    ; Get handle entry
    mov     si, xms_handles
    push    dx
    dec     dx
    mov     ax, XMS_HANDLE_SIZE
    mul     dx
    add     si, ax
    pop     dx

    ; Check if handle is in use
    cmp     word [cs:si], 0
    je      .invalid_info32

    ; Count free handles
    push    si
    mov     si, xms_handles
    mov     cx, XMS_MAX_HANDLES
    xor     bx, bx
.count_free32:
    cmp     word [cs:si], 0
    jne     .not_free32
    inc     bx
.not_free32:
    add     si, XMS_HANDLE_SIZE
    loop    .count_free32
    mov     cx, bx                  ; CX = free handle count
    pop     si

    ; BH = lock count (always 0)
    ; CX = free handles (set above)
    ; DX = block size in KB (low word, high word = 0 for our impl)
    mov     dx, [cs:si]
    xor     bh, bh
    mov     ax, 1

    pop     si
    retf

.invalid_info32:
    mov     ax, 0
    mov     bl, 0A2h
    pop     si
    retf

; ---------------------------------------------------------------------------
; XMS 3.0 Function 8Fh: Reallocate Extended Memory Block (32-bit)
; Input: DX = handle, EBX = new size in KB (we use BX)
; Returns: AX = 1 success
; ---------------------------------------------------------------------------
xms_realloc_emb_32:
    ; Just call the 16-bit version - BX has new size
    jmp     xms_realloc_emb

; ---------------------------------------------------------------------------
; XMS Handle Structure
; ---------------------------------------------------------------------------
XMS_MAX_HANDLES     equ     16
XMS_HANDLE_SIZE     equ     6       ; 2 bytes size + 4 bytes address

; ---------------------------------------------------------------------------
; XMS Move EMB temporary storage
; ---------------------------------------------------------------------------
xms_move_struct_off dw  0           ; Saved pointer to move structure
xms_move_struct_seg dw  0
xms_move_src_lo     dw  0           ; Source linear address (bits 0-15)
xms_move_src_hi     dw  0           ; Source linear address (bits 16-31)
xms_move_dst_lo     dw  0           ; Dest linear address (bits 0-15)
xms_move_dst_hi     dw  0           ; Dest linear address (bits 16-31)
xms_move_remain_lo  dw  0           ; Remaining bytes to copy (low word)
xms_move_remain_hi  dw  0           ; Remaining bytes to copy (high word)
xms_move_chunk_words dw 0           ; Word count for current chunk

; GDT for INT 15h AH=87h (48 bytes)
; Structure: dummy(8) + GDT(8) + source(8) + dest(8) + BIOS_CS(8) + BIOS_SS(8)
xms_gdt             times 48 db 0
