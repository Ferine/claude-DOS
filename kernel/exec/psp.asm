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
    mov     byte [es:0x05], 0x9A    ; CALL FAR
    ; Target: INT 21h dispatcher (retf trick)
    ; Actually, DOS puts a special entry here. For now use INT 21h vector.
    mov     word [es:0x06], 0x0000
    mov     word [es:0x08], 0x0000
    
    ; Parent PSP segment
    mov     [es:0x16], dx
    
    ; Environment segment
    mov     [es:0x2C], bx
    
    ; Handle table (default: inherit 5 standard handles)
    mov     cx, 20
    mov     di, 0x18
    mov     al, 0xFF            ; FF = unused handle
    rep     stosb
    ; Set standard handles
    mov     byte [es:0x18], 0   ; STDIN -> SFT 0
    mov     byte [es:0x19], 1   ; STDOUT -> SFT 1
    mov     byte [es:0x1A], 2   ; STDERR -> SFT 2
    mov     byte [es:0x1B], 3   ; STDAUX -> SFT 3
    mov     byte [es:0x1C], 4   ; STDPRN -> SFT 4
    
    ; Handle table size and pointer
    mov     word [es:0x32], 20
    mov     word [es:0x34], 0x18
    mov     [es:0x36], es
    
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
