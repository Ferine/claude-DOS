; ===========================================================================
; claudeDOS NUL Device Driver
; Discards all output, returns EOF on input
; ===========================================================================

nul_device:
    dw      0xFFFF              ; Next driver (filled by init)
    dw      0                   ; Next segment
    dw      DEV_ATTR_CHAR | DEV_ATTR_ISNUL
    dw      nul_strategy
    dw      nul_interrupt
    db      'NUL     '          ; Device name

nul_req_ptr     dd  0

nul_strategy:
    mov     [cs:nul_req_ptr], bx
    mov     [cs:nul_req_ptr + 2], es
    retf

nul_interrupt:
    push    ds
    push    bx

    lds     bx, [cs:nul_req_ptr]
    ; Set status = done + no error
    mov     word [bx + 3], 0x0100

    pop     bx
    pop     ds
    retf
