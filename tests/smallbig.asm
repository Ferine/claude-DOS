; SMALLBIG - Small code but large min_alloc (like compressed EXEs)
bits 16
header:
    dw 0x5A4D           ; MZ
    dw 0                ; Bytes on last page
    dw 1                ; Pages (512 bytes)
    dw 0                ; Relocations
    dw 2                ; Header paragraphs
    dw 0x1000           ; Min extra paragraphs = 64KB (like decompressors need)
    dw 0xFFFF           ; Max extra
    dw 0                ; Initial SS
    dw 0x200            ; Initial SP
    dw 0                ; Checksum
    dw 0                ; Initial IP
    dw 0                ; Initial CS
    dw 0                ; Reloc offset
    dw 0                ; Overlay
    times 32-($-header) db 0

code_start:
    mov ah, 0x0E
    xor bx, bx
    mov al, 'S'
    int 0x10
    mov al, 'B'
    int 0x10
    mov al, '!'
    int 0x10
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    mov ax, 0x4C00
    int 0x21
