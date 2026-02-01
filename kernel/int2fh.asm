; ===========================================================================
; claudeDOS INT 2Fh Multiplex Interrupt Handler
; Provides XMS detection and entry point services
; ===========================================================================

; ---------------------------------------------------------------------------
; INT 2Fh Handler - Multiplex Interrupt
; ---------------------------------------------------------------------------
int2f_handler:
    ; Debug: print INT 2Fh function to serial (COM1)
    push    ax
    push    bx
    push    dx
    mov     bx, ax                  ; Save AX
    mov     al, '<'
    mov     dx, 0x3F8
    out     dx, al
    ; Print high byte (AH)
    mov     al, bh
    push    ax
    shr     al, 4
    add     al, '0'
    cmp     al, '9'
    jbe     .p1
    add     al, 7
.p1:
    out     dx, al
    pop     ax
    and     al, 0x0F
    add     al, '0'
    cmp     al, '9'
    jbe     .p2
    add     al, 7
.p2:
    out     dx, al
    ; Print low byte (AL)
    mov     al, bl
    push    ax
    shr     al, 4
    add     al, '0'
    cmp     al, '9'
    jbe     .p3
    add     al, 7
.p3:
    out     dx, al
    pop     ax
    and     al, 0x0F
    add     al, '0'
    cmp     al, '9'
    jbe     .p4
    add     al, 7
.p4:
    out     dx, al
    mov     al, '>'
    out     dx, al
    pop     dx
    pop     bx
    pop     ax

    ; Check for XMS installation check
    cmp     ax, 4300h
    je      .xms_check

    ; Check for XMS entry point request
    cmp     ax, 4310h
    je      .xms_entry_point

    ; Check for DPMI detection
    cmp     ax, 1687h
    je      .dpmi_check

    ; Not our function - chain to previous handler or just return
    ; For simplicity, just return (no chaining)
    iret

.xms_check:
    ; XMS Installation Check
    ; Return AL = 80h to indicate XMS driver is installed
    mov     al, 80h
    iret

.xms_entry_point:
    ; Return XMS Driver Entry Point
    ; ES:BX = far pointer to XMS entry point
    push    cs
    pop     es                      ; ES = kernel code segment
    mov     bx, xms_entry           ; BX = offset of xms_entry
    iret

.dpmi_check:
    ; DPMI Installation Check (function 1687h)
    ; Return AX != 0 to indicate DPMI is not available
    ; This tells DOS extenders to use XMS/VCPI instead
    mov     ax, 1                   ; AX != 0 means no DPMI
    iret
