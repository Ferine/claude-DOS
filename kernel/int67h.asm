; ===========================================================================
; claudeDOS INT 67h EMS/VCPI Handler
; Returns "no EMS" for EMS calls, handles VCPI detection
; ===========================================================================

; ---------------------------------------------------------------------------
; INT 67h Handler - EMS/VCPI Services (stub)
; ---------------------------------------------------------------------------
int67_handler:
    ; Debug: print INT 67h function to serial (COM1)
    push    ax
    push    dx
    push    bx
    mov     bx, ax                  ; Save AX
    mov     dx, 0x3F8
    mov     al, '|'
    out     dx, al
    ; Print AH (saved in BH)
    mov     al, bh
    push    ax
    shr     al, 4
    add     al, '0'
    cmp     al, '9'
    jbe     .e1
    add     al, 7
.e1:
    out     dx, al
    pop     ax
    and     al, 0x0F
    add     al, '0'
    cmp     al, '9'
    jbe     .e2
    add     al, 7
.e2:
    out     dx, al
    mov     al, '|'
    out     dx, al
    pop     bx
    pop     dx
    pop     ax

    ; Check for VCPI detection (AX=DE00h)
    cmp     ax, 0DE00h
    je      .vcpi_detect

    ; Check for EMS status (AH=40h)
    cmp     ah, 40h
    je      .ems_status

    ; Check for EMS version (AH=46h)
    cmp     ah, 46h
    je      .ems_status

    ; All other EMS functions: return error
    mov     ah, 84h                 ; EMS error: function not supported
    iret

.vcpi_detect:
    ; VCPI not available - return error in AH
    mov     ah, 84h                 ; Error: function not supported (no VCPI)
    iret

.ems_status:
    ; EMS not installed - return error
    mov     ah, 84h                 ; Error: EMS not installed
    iret
