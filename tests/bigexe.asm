; BIGEXE - Large EXE test (not compressed)
; Tests loading of larger EXE files with multiple sectors
bits 16

; MZ EXE Header (32 bytes minimum)
; File will be ~10KB: 32 bytes header + ~50 bytes code + 10000 bytes padding
; Total ~10082 bytes = 20 pages (512 bytes each), last page has 10082 % 512 = 418 bytes
header:
    dw 0x5A4D           ; 00: MZ signature
    dw 418              ; 02: Bytes on last page (10082 % 512)
    dw 20               ; 04: Pages in file (10082 / 512 rounded up)
    dw 0                ; 06: Relocations (0)
    dw 2                ; 08: Header size in paragraphs (32 bytes)
    dw 0x100            ; 0A: Min extra paragraphs (4KB)
    dw 0xFFFF           ; 0C: Max extra paragraphs
    dw 0                ; 0E: Initial SS (relative)
    dw 0x200            ; 10: Initial SP (512)
    dw 0                ; 12: Checksum
    dw 0                ; 14: Initial IP (0 = start of loaded code)
    dw 0                ; 16: Initial CS (relative)
    dw 0                ; 18: Relocation table offset
    dw 0                ; 1A: Overlay number
    times 32-($-header) db 0

; Code section
code_start:
    ; Print "BIG!" using BIOS INT 10h
    mov     ah, 0x0E
    xor     bx, bx

    mov     al, 'B'
    int     0x10
    mov     al, 'I'
    int     0x10
    mov     al, 'G'
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

; Pad to make file larger (10KB of data)
padding:
    times 10000 db 0xCC

exe_end:
