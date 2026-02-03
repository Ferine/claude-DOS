; ORMOCK - Mock Oregon Trail header values
; Tests if our loader handles LZEXE-style headers correctly
bits 16

; MZ EXE Header matching OREGON.EXE structure
header:
    dw 0x5A4D           ; 00: MZ signature
    dw 0x01DA           ; 02: Bytes on last page (474) - doesn't matter for test
    dw 155              ; 04: Pages in file (79KB)
    dw 0                ; 06: Relocations (0 - LZEXE handles internally)
    dw 2                ; 08: Header size in paragraphs (32 bytes)
    dw 0x120E           ; 0A: Min extra paragraphs (~74KB like OREGON.EXE)
    dw 0x2949           ; 0C: Max extra paragraphs (~165KB like OREGON.EXE)
    dw 0x2472           ; 0E: Initial SS (9330 paragraphs - EXACTLY like OREGON.EXE)
    dw 0x0080           ; 10: Initial SP (128 - EXACTLY like OREGON.EXE)
    dw 0                ; 12: Checksum
    dw 0x000E           ; 14: Initial IP (14 - EXACTLY like OREGON.EXE)
    dw 0x126D           ; 16: Initial CS (4717 paragraphs - EXACTLY like OREGON.EXE)
    dw 0x001C           ; 18: Relocation table offset (28)
    dw 0                ; 1A: Overlay number
    times 32-($-header) db 0

; Padding to reach the code entry point (Initial CS = 0x126D paragraphs = 0x126D0 bytes)
; We need to put code at offset 0x126D0 from load start
; Load start is at file offset 32 (after header)
; So code should be at file offset 32 + 0x126D0 = 32 + 75472 = 75504
; Padding needed: 75472 bytes (0x126D0)
padding:
    times 0x126D0 db 0xCC

; Code at the expected entry point (IP = 0x000E offset from CS)
; So we need 14 bytes before the actual code
pre_code:
    times 14 db 0x90    ; NOPs before entry point

; Entry point (CS:IP = 0x126D:0x000E relative to load_seg)
code_start:
    ; Print "OR!" using BIOS INT 10h
    mov     ah, 0x0E
    xor     bx, bx

    mov     al, 'O'
    int     0x10
    mov     al, 'R'
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

; Pad to approximately match file size
end_padding:
    times (79322 - 32 - ($ - header)) db 0xCC
