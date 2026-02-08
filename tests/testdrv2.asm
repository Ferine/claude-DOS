; ===========================================================================
; TESTDRV2.SYS - Second test character device driver
; Verifies that multiple DEVICE= lines work
; ===========================================================================
bits 16
org 0

; Device header
dev_header:
    dw      0xFFFF
    dw      0xFFFF
    dw      0x8000              ; Character device
    dw      strategy
    dw      interrupt
    db      'TSTWO   '          ; Device name

req_hdr_off dw  0
req_hdr_seg dw  0

strategy:
    mov     [cs:req_hdr_off], bx
    mov     [cs:req_hdr_seg], es
    retf

interrupt:
    push    ax
    push    bx
    push    si
    push    ds
    push    es

    lds     bx, [cs:req_hdr_off]
    mov     al, [bx + 2]
    test    al, al
    jz      .do_init

    mov     word [bx + 3], 0x0100
    jmp     .done

.do_init:
    push    cs
    pop     ds
    mov     si, msg
    call    print_string

    les     bx, [cs:req_hdr_off]
    mov     word [es:bx + 14], resident_end
    mov     [es:bx + 16], cs
    mov     word [es:bx + 3], 0x0100

.done:
    pop     es
    pop     ds
    pop     si
    pop     bx
    pop     ax
    retf

print_string:
    pusha
    mov     ah, 0x0E
    xor     bx, bx
.loop:
    lodsb
    test    al, al
    jz      .end
    int     0x10
    jmp     .loop
.end:
    popa
    ret

msg db  '[TESTDRV2] Second driver OK!', 0x0D, 0x0A, 0

resident_end:
