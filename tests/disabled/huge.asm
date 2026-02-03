; HUGE - Very large EXE test (~80KB)
; Tests loading of EXE files similar to Oregon Trail size
bits 16

; MZ EXE Header (32 bytes)
; File will be ~80KB: 32 bytes header + ~50 bytes code + 80000 bytes padding
; Total ~80082 bytes = 157 pages (512 bytes each)
header:
    dw 0x5A4D           ; 00: MZ signature
    dw 80082 % 512      ; 02: Bytes on last page
    dw 157              ; 04: Pages in file
    dw 0                ; 06: Relocations (0)
    dw 2                ; 08: Header size in paragraphs (32 bytes)
    dw 0x1000           ; 0A: Min extra paragraphs (64KB)
    dw 0xFFFF           ; 0C: Max extra paragraphs
    dw 0                ; 0E: Initial SS (relative)
    dw 0x400            ; 10: Initial SP (1024)
    dw 0                ; 12: Checksum
    dw 0                ; 14: Initial IP
    dw 0                ; 16: Initial CS (relative)
    dw 0                ; 18: Relocation table offset
    dw 0                ; 1A: Overlay number
    times 32-($-header) db 0

; Code section
code_start:
    ; Print "HUGE!" using BIOS INT 10h
    mov     ah, 0x0E
    xor     bx, bx

    mov     al, 'H'
    int     0x10
    mov     al, 'U'
    int     0x10
    mov     al, 'G'
    int     0x10
    mov     al, 'E'
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

; Pad to make file ~80KB
padding:
    times 80000 db 0xCC

exe_end:
