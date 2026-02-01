; TESTEXE4 - Use BIOS INT 10h directly (not direct video memory)
bits 16

; MZ EXE Header (32 bytes)
header:
    dw 0x5A4D           ; 00: MZ signature
    dw exe_end - header ; 02: Bytes on last page
    dw 1                ; 04: Pages in file
    dw 0                ; 06: Relocations (0)
    dw 2                ; 08: Header size in paragraphs
    dw 16               ; 0A: Min extra paragraphs
    dw 0xFFFF           ; 0C: Max extra paragraphs
    dw 0                ; 0E: Initial SS
    dw 0x100            ; 10: Initial SP
    dw 0                ; 12: Checksum
    dw 0                ; 14: Initial IP
    dw 0                ; 16: Initial CS
    dw 0                ; 18: Relocation table offset
    dw 0                ; 1A: Overlay number
    times 32-($-header) db 0

; Code
code_start:
    ; Print "BIOS" using INT 10h teletype
    mov     ah, 0x0E        ; Teletype function
    xor     bx, bx          ; Page 0, color 0

    mov     al, 'B'
    int     0x10
    mov     al, 'I'
    int     0x10
    mov     al, 'O'
    int     0x10
    mov     al, 'S'
    int     0x10
    mov     al, '!'
    int     0x10
    mov     al, 0x0D
    int     0x10
    mov     al, 0x0A
    int     0x10

    ; Exit via INT 21h 4Ch
    mov     ax, 0x4C00
    int     0x21

exe_end:
