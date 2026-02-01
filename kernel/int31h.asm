; ===========================================================================
; claudeDOS INT 31h DPMI Stub
; Returns error for DPMI calls (not implemented)
; ===========================================================================

; ---------------------------------------------------------------------------
; INT 31h Handler - DPMI Services (stub)
; ---------------------------------------------------------------------------
int31_handler:
    ; Debug: print DPMI call to serial (COM1)
    push    ax
    push    dx
    mov     dx, 0x3F8
    mov     al, '{'
    out     dx, al
    mov     al, '3'
    out     dx, al
    mov     al, '1'
    out     dx, al
    mov     al, '}'
    out     dx, al
    pop     dx
    pop     ax
    ; Return error - DPMI not available
    stc
    iret
