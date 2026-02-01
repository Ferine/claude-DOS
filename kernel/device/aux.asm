; ===========================================================================
; claudeDOS AUX (Serial) Device Driver - Stub
; ===========================================================================

aux_device:
    dw      0xFFFF
    dw      0
    dw      DEV_ATTR_CHAR
    dw      aux_strategy
    dw      aux_interrupt
    db      'AUX     '

aux_req_ptr     dd  0

aux_strategy:
    mov     [cs:aux_req_ptr], bx
    mov     [cs:aux_req_ptr + 2], es
    retf

aux_interrupt:
    push    ds
    push    bx
    lds     bx, [cs:aux_req_ptr]
    mov     word [bx + 3], 0x0100   ; Done, no error
    pop     bx
    pop     ds
    retf
