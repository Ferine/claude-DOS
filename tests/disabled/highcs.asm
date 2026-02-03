; HIGHCS - Test EXE with high CS value (like LZEXE compressed files)
; Code is at the end of the file, entry point uses high CS
bits 16

; MZ EXE Header (32 bytes)
header:
    dw 0x5A4D           ; 00: MZ signature
    dw 0                ; 02: Bytes on last page
    dw 160              ; 04: Pages in file (~80KB)
    dw 0                ; 06: Relocations
    dw 2                ; 08: Header size in paragraphs
    dw 0x1000           ; 0A: Min extra paragraphs
    dw 0xFFFF           ; 0C: Max extra paragraphs
    dw 0                ; 0E: Initial SS (relative to load_seg)
    dw 0x200            ; 10: Initial SP
    dw 0                ; 12: Checksum
    dw 0                ; 14: Initial IP (0)
    dw (code_start - header - 32) / 16  ; 16: Initial CS (relative to load_seg)
    dw 0                ; 18: Relocation table offset
    dw 0                ; 1A: Overlay number
    times 32-($-header) db 0

; Padding to put code at ~75KB offset (simulating LZEXE structure)
padding:
    times 75000 db 0xCC

; Code at high offset (like LZEXE decompressor)
code_start:
    ; Print "HI!" using BIOS INT 10h
    mov     ah, 0x0E
    xor     bx, bx

    mov     al, 'H'
    int     0x10
    mov     al, 'I'
    int     0x10
    mov     al, 'C'
    int     0x10
    mov     al, 'S'
    int     0x10
    mov     al, '!'
    int     0x10
    mov     al, 0x0D
    int     0x10
    mov     al, 0x0A
    int     0x10

    ; Exit
    mov     ax, 0x4C00
    int     0x21

exe_end:
