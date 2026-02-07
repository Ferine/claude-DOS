; ===========================================================================
; claudeDOS INT 31h DPMI Handler
; Implements real-mode-safe DPMI functions; returns proper errors for the rest
; ===========================================================================

; ---------------------------------------------------------------------------
; INT 31h Handler - DPMI Services
; ---------------------------------------------------------------------------
int31_handler:
    ; Debug: print DPMI function code to serial as {XXXX}
    push    ax
    push    dx
    push    bx
    mov     bx, ax                  ; Save AX
    mov     dx, 0x3F8
    mov     al, '{'
    out     dx, al
    ; Print AH (high byte, saved in BH)
    mov     al, bh
    call    dpmi_serial_hex_byte
    ; Print AL (low byte, saved in BL)
    mov     al, bl
    call    dpmi_serial_hex_byte
    mov     dx, 0x3F8
    mov     al, '}'
    out     dx, al
    pop     bx
    pop     dx
    pop     ax

    ; Dispatch by AH (function group)
    cmp     ah, 0x00
    je      .group_00
    cmp     ah, 0x01
    je      .group_01
    cmp     ah, 0x02
    je      .group_02
    cmp     ah, 0x03
    je      .group_03
    cmp     ah, 0x04
    je      .group_04
    cmp     ah, 0x05
    je      .group_05
    cmp     ah, 0x06
    je      .group_06
    cmp     ah, 0x08
    je      .group_08
    cmp     ah, 0x09
    je      .group_09
    cmp     ah, 0x0A
    je      .group_0a

    ; Unknown group — unsupported
    mov     ax, DPMI_ERR_UNSUPPORTED
    jmp     dpmi_return_error

; ---------------------------------------------------------------------------
; Group 00h — Descriptor management
; Only AX=0003h (Get Selector Increment) is meaningful in real mode
; ---------------------------------------------------------------------------
.group_00:
    cmp     ax, 0x0003
    je      .fn_0003
    ; All other group 00h → descriptor unavailable
    mov     ax, DPMI_ERR_NO_DESCRIPTORS
    jmp     dpmi_return_error

.fn_0003:
    ; Get Selector Increment Value → AX=8
    mov     ax, 8
    jmp     dpmi_return_success

; ---------------------------------------------------------------------------
; Group 01h — DOS memory management (requires protected mode)
; ---------------------------------------------------------------------------
.group_01:
    mov     ax, DPMI_ERR_NO_LINEAR_MEM
    jmp     dpmi_return_error

; ---------------------------------------------------------------------------
; Group 02h — Real mode interrupt vectors
; AX=0200h  Get Real Mode Interrupt Vector
; AX=0201h  Set Real Mode Interrupt Vector
; ---------------------------------------------------------------------------
.group_02:
    cmp     ax, 0x0200
    je      .fn_0200
    cmp     ax, 0x0201
    je      .fn_0201
    mov     ax, DPMI_ERR_INVALID_VALUE
    jmp     dpmi_return_error

.fn_0200:
    ; Get Real Mode Interrupt Vector (BL = interrupt number)
    ; Returns: CX:DX = segment:offset
    push    bx
    push    ds
    xor     bh, bh                  ; BX = interrupt number
    shl     bx, 1
    shl     bx, 1                   ; BX = BL * 4 (IVT offset)
    xor     cx, cx
    mov     ds, cx                  ; DS = 0000 (IVT segment)
    mov     dx, [bx]               ; DX = offset from IVT
    mov     cx, [bx + 2]           ; CX = segment from IVT
    pop     ds
    pop     bx
    jmp     dpmi_return_success

.fn_0201:
    ; Set Real Mode Interrupt Vector (BL = int#, CX:DX = seg:off)
    push    bx
    push    ds
    xor     bh, bh
    shl     bx, 1
    shl     bx, 1                   ; BX = BL * 4
    push    cx
    xor     cx, cx
    mov     ds, cx                  ; DS = 0000
    pop     cx
    cli
    mov     [bx], dx               ; Store offset
    mov     [bx + 2], cx           ; Store segment
    sti
    pop     ds
    pop     bx
    jmp     dpmi_return_success

; ---------------------------------------------------------------------------
; Group 03h — Callbacks (not possible in real mode)
; ---------------------------------------------------------------------------
.group_03:
    mov     ax, DPMI_ERR_UNSUPPORTED
    jmp     dpmi_return_error

; ---------------------------------------------------------------------------
; Group 04h — DPMI version info
; AX=0400h only
; ---------------------------------------------------------------------------
.group_04:
    cmp     ax, 0x0400
    jne     .group_04_err
    ; Get DPMI Version
    ; AH=major (0), AL=minor (9) → DPMI 0.9
    ; BX=flags: bit 1 set = 32-bit programs not supported → 0002h
    ; CL=processor type: 3 = 386
    ; DH=current PIC master base: 08h
    ; DL=current PIC slave base: 70h
    mov     ax, 0x0009              ; Version 0.9
    mov     bx, 0x0002              ; 16-bit only
    mov     cl, 3                   ; 386 processor
    mov     dh, 0x08                ; Master PIC base
    mov     dl, 0x70                ; Slave PIC base
    jmp     dpmi_return_success
.group_04_err:
    mov     ax, DPMI_ERR_UNSUPPORTED
    jmp     dpmi_return_error

; ---------------------------------------------------------------------------
; Group 05h — Memory management
; AX=0500h  Get Free Memory Information
; ---------------------------------------------------------------------------
.group_05:
    cmp     ax, 0x0500
    je      .fn_0500
    mov     ax, DPMI_ERR_NO_LINEAR_MEM
    jmp     dpmi_return_error

.fn_0500:
    ; Get Free Memory Information
    ; ES:DI → 48-byte buffer, fill with FFFFFFFFh (info unavailable)
    push    cx
    push    di
    mov     cx, 24                  ; 48 bytes / 2 = 24 words
    mov     ax, 0xFFFF
    rep     stosw
    pop     di
    pop     cx
    xor     ax, ax                  ; Clear AX (no error code for this)
    jmp     dpmi_return_success

; ---------------------------------------------------------------------------
; Group 06h — Page management
; AX=0604h  Get Page Size
; ---------------------------------------------------------------------------
.group_06:
    cmp     ax, 0x0604
    je      .fn_0604
    mov     ax, DPMI_ERR_INVALID_LINEAR
    jmp     dpmi_return_error

.fn_0604:
    ; Get Page Size → BX:CX = 0000:1000h (4096 bytes)
    xor     bx, bx
    mov     cx, 0x1000
    jmp     dpmi_return_success

; ---------------------------------------------------------------------------
; Group 08h — Physical address mapping (not possible in real mode)
; ---------------------------------------------------------------------------
.group_08:
    mov     ax, DPMI_ERR_INVALID_VALUE
    jmp     dpmi_return_error

; ---------------------------------------------------------------------------
; Group 09h — Virtual interrupt state
; AX=0900h  Get & Disable Virtual Interrupt State
; AX=0901h  Get & Enable Virtual Interrupt State
; AX=0902h  Get Virtual Interrupt State
; ---------------------------------------------------------------------------
.group_09:
    cmp     ax, 0x0900
    je      .fn_0900
    cmp     ax, 0x0901
    je      .fn_0901
    cmp     ax, 0x0902
    je      .fn_0902
    mov     ax, DPMI_ERR_UNSUPPORTED
    jmp     dpmi_return_error

.fn_0900:
    ; Get & Disable Virtual Interrupt State
    ; Return AL = previous IF state (1=enabled, 0=disabled)
    push    bp
    mov     bp, sp
    mov     ax, [bp + 6]           ; Stacked FLAGS
    and     ax, 0x0200              ; Isolate IF bit (bit 9)
    mov     cl, 9
    shr     ax, cl                  ; AL = 0 or 1
    and     word [bp + 6], ~0x0200  ; Clear IF in stacked FLAGS
    pop     bp
    jmp     dpmi_return_success

.fn_0901:
    ; Get & Enable Virtual Interrupt State
    ; Return AL = previous IF state
    push    bp
    mov     bp, sp
    mov     ax, [bp + 6]           ; Stacked FLAGS
    and     ax, 0x0200
    mov     cl, 9
    shr     ax, cl                  ; AL = 0 or 1
    or      word [bp + 6], 0x0200   ; Set IF in stacked FLAGS
    pop     bp
    jmp     dpmi_return_success

.fn_0902:
    ; Get Virtual Interrupt State
    ; Return AL = caller's IF state (from stacked FLAGS)
    push    bp
    mov     bp, sp
    mov     ax, [bp + 6]           ; Stacked FLAGS
    and     ax, 0x0200
    mov     cl, 9
    shr     ax, cl                  ; AL = 0 or 1
    pop     bp
    jmp     dpmi_return_success

; ---------------------------------------------------------------------------
; Group 0Ah — Vendor API (not supported)
; ---------------------------------------------------------------------------
.group_0a:
    mov     ax, DPMI_ERR_UNSUPPORTED
    jmp     dpmi_return_error

; ---------------------------------------------------------------------------
; dpmi_return_success — Clear CF in stacked FLAGS, iret
; ---------------------------------------------------------------------------
dpmi_return_success:
    push    bp
    mov     bp, sp
    and     word [bp + 6], 0xFFFE   ; Clear CF in stacked FLAGS
    pop     bp
    iret

; ---------------------------------------------------------------------------
; dpmi_return_error — Set CF in stacked FLAGS, iret
; Expects: AX = DPMI error code
; ---------------------------------------------------------------------------
dpmi_return_error:
    push    bp
    mov     bp, sp
    or      word [bp + 6], 0x0001   ; Set CF in stacked FLAGS
    pop     bp
    iret

; ---------------------------------------------------------------------------
; dpmi_serial_hex_byte — Print AL as 2 hex digits to COM1 (0x3F8)
; Preserves all registers except DX
; ---------------------------------------------------------------------------
dpmi_serial_hex_byte:
    push    ax
    mov     dx, 0x3F8
    ; High nibble
    shr     al, 4
    add     al, '0'
    cmp     al, '9'
    jbe     .dshb1
    add     al, 7
.dshb1:
    out     dx, al
    ; Low nibble
    pop     ax
    push    ax
    and     al, 0x0F
    add     al, '0'
    cmp     al, '9'
    jbe     .dshb2
    add     al, 7
.dshb2:
    out     dx, al
    pop     ax
    ret
