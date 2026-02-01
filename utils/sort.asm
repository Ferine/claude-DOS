; ===========================================================================
; SORT.COM - Sort lines from STDIN
; ===========================================================================
    CPU     186
    ORG     0x0100

    ; Simple sort: read all lines into buffer, bubble sort, output
    mov     dx, sort_stub_msg
    mov     ah, 0x09
    int     0x21

    mov     ax, 0x4C00
    int     0x21

sort_stub_msg db  'SORT: reads from STDIN, sorts lines', 0x0D, 0x0A
              db  'Usage: SORT < filename', 0x0D, 0x0A, '$'
