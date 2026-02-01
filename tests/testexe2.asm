; TESTEXE2 - Simpler EXE test using single character output
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
    ; Print 'X' using INT 21h AH=02h (single char, uses DL)
    mov     ah, 0x02
    mov     dl, 'X'
    int     0x21

    ; Print newline
    mov     dl, 0x0D
    int     0x21
    mov     dl, 0x0A
    int     0x21

    ; Exit
    mov     ax, 0x4C00
    int     0x21

exe_end:
