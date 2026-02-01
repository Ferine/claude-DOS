; TESTEXE3 - Write directly to video memory (bypass INT 21h)
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
    ; Write "EXE!" directly to video memory at line 15
    mov     ax, 0xB800      ; VGA text mode segment
    mov     es, ax
    mov     di, 15*160      ; Line 15, column 0 (160 bytes per line in text mode)

    mov     ax, 0x0F45      ; 'E' with white on black attribute
    stosw
    mov     ax, 0x0F58      ; 'X'
    stosw
    mov     ax, 0x0F45      ; 'E'
    stosw
    mov     ax, 0x0F21      ; '!'
    stosw

    ; Exit via INT 21h 4Ch
    mov     ax, 0x4C00
    int     0x21

exe_end:
