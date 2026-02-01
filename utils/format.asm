; ===========================================================================
; FORMAT.COM - Format disk
; ===========================================================================
    CPU     186
    ORG     0x0100

    mov     dx, format_msg
    mov     ah, 0x09
    int     0x21

    mov     ax, 0x4C00
    int     0x21

format_msg  db  'FORMAT: Disk formatting utility', 0x0D, 0x0A
            db  'Usage: FORMAT A:', 0x0D, 0x0A
            db  'WARNING: This will erase all data on the disk.', 0x0D, 0x0A, '$'
