; ===========================================================================
; claudeDOS CLOCK$ Device Driver - Stub
; ===========================================================================

clock_device:
    dw      0xFFFF
    dw      0
    dw      DEV_ATTR_CHAR | DEV_ATTR_ISCLK
    dw      clock_strategy
    dw      clock_interrupt
    db      'CLOCK$  '

clock_req_ptr   dd  0

clock_strategy:
    mov     [cs:clock_req_ptr], bx
    mov     [cs:clock_req_ptr + 2], es
    retf

clock_interrupt:
    push    ds
    push    bx
    lds     bx, [cs:clock_req_ptr]
    mov     word [bx + 3], 0x0100
    pop     bx
    pop     ds
    retf
