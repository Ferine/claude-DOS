; ===========================================================================
; claudeDOS PRN (Printer) Device Driver - Stub
; ===========================================================================

prn_device:
    dw      0xFFFF
    dw      0
    dw      DEV_ATTR_CHAR
    dw      prn_strategy
    dw      prn_interrupt
    db      'PRN     '

prn_req_ptr     dd  0

prn_strategy:
    mov     [cs:prn_req_ptr], bx
    mov     [cs:prn_req_ptr + 2], es
    retf

prn_interrupt:
    push    ds
    push    bx
    lds     bx, [cs:prn_req_ptr]
    mov     word [bx + 3], 0x0100
    pop     bx
    pop     ds
    retf
