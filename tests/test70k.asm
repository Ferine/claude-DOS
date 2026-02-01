; TEST70K - 70KB EXE test
bits 16
header:
    dw 0x5A4D, 0, 137, 0, 2, 0x100, 0xFFFF, 0, 0x200, 0, 0, 0, 0, 0
    times 32-($-header) db 0
code_start:
    mov ah, 0x0E
    xor bx, bx
    mov al, '7'
    int 0x10
    mov al, '0'
    int 0x10
    mov al, 'K'
    int 0x10
    mov al, '!'
    int 0x10
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    mov ax, 0x4C00
    int 0x21
padding:
    times 70000 db 0xCC
