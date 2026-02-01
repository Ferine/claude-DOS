; SIMPLEEXE.EXE - Minimal MZ EXE file
; Build with: nasm -f bin -o simpleexe.exe simpleexe.asm
    CPU     186
    ORG     0

; ====== MZ Header (28 bytes) ======
mz_header:
    db      'M', 'Z'            ; +00: Signature
    dw      code_end - mz_header    ; +02: Bytes on last page (total since < 512)
    dw      1                   ; +04: Pages in file (1 page = 512 bytes)
    dw      0                   ; +06: Relocations count
    dw      2                   ; +08: Header size in paragraphs (32 bytes)
    dw      0x0010              ; +0A: Min extra paragraphs
    dw      0xFFFF              ; +0C: Max extra paragraphs
    dw      0                   ; +0E: Initial SS (relative)
    dw      0x0100              ; +10: Initial SP
    dw      0                   ; +12: Checksum
    dw      code_start - code_base  ; +14: Initial IP
    dw      0                   ; +16: Initial CS (relative)
    dw      0x1C                ; +18: Offset to relocation table
    dw      0                   ; +1A: Overlay number

; Pad to 32 bytes (2 paragraphs)
    times   (32 - ($ - mz_header)) db 0

; ====== Code Section ======
code_base:

code_start:
    ; DS and ES are set to PSP by DOS
    ; We need to set DS to code segment for string access
    push    cs
    pop     ds

    ; Print message
    mov     dx, hello_msg - code_base
    mov     ah, 0x09
    int     0x21

    ; Exit
    mov     ax, 0x4C00
    int     0x21

hello_msg:
    db      'Hello from SIMPLE.EXE!', 0x0D, 0x0A, '$'

code_end:
