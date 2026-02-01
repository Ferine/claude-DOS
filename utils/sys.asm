; ===========================================================================
; SYS.COM - Transfer system files to disk
; ===========================================================================
    CPU     186
    ORG     0x0100

    mov     dx, sys_msg
    mov     ah, 0x09
    int     0x21

    mov     ax, 0x4C00
    int     0x21

sys_msg db  'SYS: Transfer system files', 0x0D, 0x0A
        db  'Usage: SYS A:', 0x0D, 0x0A, '$'
