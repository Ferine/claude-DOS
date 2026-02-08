; ===========================================================================
; TESTDRV.SYS - Test character device driver for DEVICE= testing
; A minimal DOS device driver that prints a message on init
; ===========================================================================
bits 16
org 0

; ---------------------------------------------------------------------------
; Device header (must be at offset 0)
; ---------------------------------------------------------------------------
dev_header:
    dw      0xFFFF              ; Next driver offset (filled by OS)
    dw      0xFFFF              ; Next driver segment (filled by OS)
    dw      0x8000              ; Attribute: character device
    dw      strategy            ; Strategy routine offset
    dw      interrupt           ; Interrupt routine offset
    db      'TESTDRV '          ; Device name (8 bytes, space-padded)

; ---------------------------------------------------------------------------
; Request header pointer (saved by strategy routine)
; ---------------------------------------------------------------------------
req_hdr_off dw  0
req_hdr_seg dw  0

; ---------------------------------------------------------------------------
; Strategy routine - save pointer to request header
; Input: ES:BX = request header
; ---------------------------------------------------------------------------
strategy:
    mov     [cs:req_hdr_off], bx
    mov     [cs:req_hdr_seg], es
    retf

; ---------------------------------------------------------------------------
; Interrupt routine - process the request
; ---------------------------------------------------------------------------
interrupt:
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di
    push    ds
    push    es

    ; Load request header pointer
    lds     bx, [cs:req_hdr_off]    ; DS:BX = request header

    ; Get command code
    mov     al, [bx + 2]           ; Command byte
    test    al, al                 ; Command 0 = Init
    jz      .do_init

    ; Unknown command - return "done" status
    mov     word [bx + 3], 0x0100   ; Status: done, no error
    jmp     .done

.do_init:
    ; Print our banner via BIOS
    push    cs
    pop     ds
    mov     si, msg_banner
    call    print_string

    ; Set break address = end of resident code
    ; Request header offset 14 = break address (offset)
    ; Request header offset 16 = break address (segment)
    les     bx, [cs:req_hdr_off]    ; ES:BX = request header
    mov     word [es:bx + 14], resident_end
    mov     [es:bx + 16], cs

    ; Set status: done, no error
    mov     word [es:bx + 3], 0x0100

.done:
    pop     es
    pop     ds
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    retf

; ---------------------------------------------------------------------------
; print_string - Print ASCIIZ string at DS:SI via BIOS INT 10h
; ---------------------------------------------------------------------------
print_string:
    pusha
    mov     ah, 0x0E
    xor     bx, bx
.loop:
    lodsb
    test    al, al
    jz      .done
    int     0x10
    jmp     .loop
.done:
    popa
    ret

; ---------------------------------------------------------------------------
; Data
; ---------------------------------------------------------------------------
msg_banner  db  '[TESTDRV] Device driver initialized!', 0x0D, 0x0A, 0

; ---------------------------------------------------------------------------
; End of resident section
; ---------------------------------------------------------------------------
resident_end:
