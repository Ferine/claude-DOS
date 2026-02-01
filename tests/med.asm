; MED - Medium EXE test (~20KB)
bits 16

header:
    dw 0x5A4D           ; 00: MZ signature
    dw 0                ; 02: Bytes on last page (will be overwritten)
    dw 40               ; 04: Pages in file (~20KB)
    dw 0                ; 06: Relocations
    dw 2                ; 08: Header size in paragraphs
    dw 0x100            ; 0A: Min extra paragraphs
    dw 0xFFFF           ; 0C: Max extra paragraphs
    dw 0                ; 0E: Initial SS
    dw 0x200            ; 10: Initial SP
    dw 0                ; 12: Checksum
    dw 0                ; 14: Initial IP
    dw 0                ; 16: Initial CS
    dw 0                ; 18: Relocation table offset
    dw 0                ; 1A: Overlay number
    times 32-($-header) db 0

code_start:
    mov     ah, 0x0E
    xor     bx, bx
    mov     al, 'M'
    int     0x10
    mov     al, 'E'
    int     0x10
    mov     al, 'D'
    int     0x10
    mov     al, '!'
    int     0x10
    mov     al, 0x0D
    int     0x10
    mov     al, 0x0A
    int     0x10
    mov     ax, 0x4C00
    int     0x21

padding:
    times 20000 db 0xCC
