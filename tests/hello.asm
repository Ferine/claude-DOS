; HELLO.COM - Minimal test program for EXEC functionality
    CPU     186
    ORG     0x0100

    mov     dx, msg
    mov     ah, 0x09
    int     0x21

    mov     ax, 0x4C00
    int     0x21

msg db  'Hello from HELLO.COM!', 0x0D, 0x0A, '$'
