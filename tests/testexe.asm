; TESTEXE - Minimal EXE test program
; Build with: nasm -f bin -o testexe.exe testexe.asm

bits 16

; MZ EXE Header (32 bytes)
header:
    dw 0x5A4D           ; 00: MZ signature
    dw exe_end - header ; 02: Bytes on last page (file size mod 512)
    dw 1                ; 04: Pages in file (ceil(file_size / 512))
    dw 0                ; 06: Relocations (0)
    dw 2                ; 08: Header size in paragraphs (32 bytes = 2 paras)
    dw 16               ; 0A: Min extra paragraphs (256 bytes for stack)
    dw 0xFFFF           ; 0C: Max extra paragraphs
    dw 0                ; 0E: Initial SS (relative to load segment)
    dw 0x100            ; 10: Initial SP
    dw 0                ; 12: Checksum
    dw 0                ; 14: Initial IP
    dw 0                ; 16: Initial CS (relative to load segment)
    dw 0                ; 18: Relocation table offset
    dw 0                ; 1A: Overlay number
    times 32-($-header) db 0 ; Pad to 32 bytes

; Code segment starts here (offset 32 = paragraph 2)
code_start:
    ; DS = PSP segment, but we need DS = CS for the message
    push    cs
    pop     ds

    ; Print message
    mov     ah, 0x09
    mov     dx, msg - code_start  ; Offset from start of code segment
    int     0x21

    ; Exit
    mov     ax, 0x4C00
    int     0x21

msg:
    db 'Hello from EXE!', 0x0D, 0x0A, '$'

exe_end:
