; ===========================================================================
; claudeDOS PSP (Program Segment Prefix) Builder
; ===========================================================================

; ---------------------------------------------------------------------------
; build_psp - Create a PSP at the given segment
; Input: ES = segment for PSP
;        DS:SI = command tail string (ASCIIZ)
;        BX = environment segment
;        DX = parent PSP segment
; ---------------------------------------------------------------------------
build_psp:
    pusha
    
    ; Clear PSP area
    push    di
    xor     di, di
    mov     cx, 128             ; 256 bytes / 2 words
    xor     ax, ax
    rep     stosw
    pop     di
    
    ; INT 20h instruction at PSP:0000
    mov     word [es:0x00], 0x20CD  ; CD 20 = INT 20h
    
    ; Memory top - set to top of allocated block
    ; (Caller should set this properly)
    mov     word [es:0x02], 0xA000  ; Default: 640K boundary
    
    ; Far call to DOS at PSP:0005
    mov     byte [es:0x05], 0x9A    ; CALL FAR opcode
    push    ds
    xor     ax, ax
    mov     ds, ax                  ; DS = 0 (IVT segment)
    mov     ax, [ds:0x0084]         ; INT 21h offset from IVT
    mov     [es:0x06], ax
    mov     ax, [ds:0x0086]         ; INT 21h segment from IVT
    mov     [es:0x08], ax
    pop     ds

    ; Save parent's terminate, Ctrl-C, and critical error vectors
    push    ds
    xor     ax, ax
    mov     ds, ax
    ; INT 22h (terminate address) at IVT 0x88
    mov     ax, [ds:0x0088]
    mov     [es:0x0A], ax
    mov     ax, [ds:0x008A]
    mov     [es:0x0C], ax
    ; INT 23h (Ctrl-C) at IVT 0x8C
    mov     ax, [ds:0x008C]
    mov     [es:0x0E], ax
    mov     ax, [ds:0x008E]
    mov     [es:0x10], ax
    ; INT 24h (Critical error) at IVT 0x90
    mov     ax, [ds:0x0090]
    mov     [es:0x12], ax
    mov     ax, [ds:0x0092]
    mov     [es:0x14], ax
    pop     ds

    ; Parent PSP segment
    mov     [es:0x16], dx

    ; Environment segment
    mov     [es:0x2C], bx

    ; Fill handle table with 0xFF (unused)
    mov     cx, 20
    mov     di, 0x18
    mov     al, 0xFF
    rep     stosb

    ; Handle inheritance - copy from parent or set defaults
    ; DX = parent PSP segment (0 = no parent)
    test    dx, dx
    jz      .no_parent_handles

    ; Copy parent's handle table into child
    push    ds
    push    si
    mov     ds, dx              ; DS = parent PSP
    mov     si, 0x18            ; Parent handle table offset
    mov     di, 0x18            ; Child handle table offset
    mov     cx, 20              ; MAX_HANDLES
    rep     movsb               ; Copy parent handles to child

    ; Copy handle count from parent
    mov     ax, [ds:0x32]
    mov     [es:0x32], ax
    ; Point handle table pointer to child's own table
    mov     word [es:0x34], 0x18
    mov     [es:0x36], es
    pop     si
    pop     ds

    ; Increment SFT ref counts for inherited handles
    push    ds
    push    si
    push    bx
    mov     ax, cs
    mov     ds, ax              ; DS = kernel data segment
    mov     cx, 20              ; MAX_HANDLES
    xor     bx, bx              ; Handle index
.inc_ref_loop:
    mov     al, [es:0x18 + bx]
    cmp     al, 0xFF
    je      .skip_ref_inc
    ; AL = SFT index, compute SFT entry address
    push    cx
    push    dx
    xor     ah, ah
    mov     dx, SFT_ENTRY_SIZE
    mul     dx                  ; AX = SFT index * entry size
    mov     si, sft_table
    add     si, ax
    inc     word [si + SFT_ENTRY.ref_count]
    pop     dx
    pop     cx
.skip_ref_inc:
    inc     bx
    loop    .inc_ref_loop
    pop     bx
    pop     si
    pop     ds
    jmp     .handles_done

.no_parent_handles:
    ; First process - set up standard handles
    mov     byte [es:0x18], 0   ; STDIN -> SFT 0
    mov     byte [es:0x19], 1   ; STDOUT -> SFT 1
    mov     byte [es:0x1A], 2   ; STDERR -> SFT 2
    mov     byte [es:0x1B], 3   ; STDAUX -> SFT 3
    mov     byte [es:0x1C], 4   ; STDPRN -> SFT 4
    mov     word [es:0x32], 20  ; Handle count
    mov     word [es:0x34], 0x18
    mov     [es:0x36], es

.handles_done:
    
    ; INT 21h / RETF at PSP:0050
    mov     byte [es:0x50], 0xCD    ; INT
    mov     byte [es:0x51], 0x21    ; 21h
    mov     byte [es:0x52], 0xCB    ; RETF
    
    ; Copy command tail
    ; DS:SI = source, format is ASCIIZ string
    mov     di, 0x81
    xor     cl, cl              ; Count
.copy_tail:
    lodsb
    test    al, al
    jz      .tail_done
    stosb
    inc     cl
    cmp     cl, 126             ; Max tail length
    jae     .tail_done
    jmp     .copy_tail
    
.tail_done:
    mov     byte [es:di], 0x0D ; Terminate with CR
    mov     [es:0x80], cl       ; Store length

    ; Parse command tail to fill FCB1 (PSP:5Ch) and FCB2 (PSP:6Ch)
    ; DS:SI = command tail source (pointing past what we copied)
    ; Need to re-point SI at PSP:0081 (the copy we just wrote)
    push    ds
    push    es
    pop     ds                  ; DS = PSP segment (same as ES)
    mov     si, 0x0081          ; DS:SI = command tail in PSP

    ; Parse first argument into FCB1 at ES:005Ch
    mov     di, 0x005C
    mov     al, 0x01            ; Skip leading separators
    call    parse_filename_core

    ; Parse second argument into FCB2 at ES:006Ch
    mov     di, 0x006C
    mov     al, 0x01            ; Skip leading separators
    call    parse_filename_core

    pop     ds                  ; Restore original DS

    popa
    ret
