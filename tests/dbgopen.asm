; DBGOPEN.COM - Debug file open - shows SFT entry contents
    CPU     186
    ORG     0x0100

start:
    ; Open ALLCANM1
    mov     dx, filename
    mov     ax, 0x3D00          ; Open for reading
    int     0x21
    jc      .open_error
    mov     [handle], ax

    ; Print handle
    mov     dx, msg_handle
    mov     ah, 0x09
    int     0x21
    mov     ax, [handle]
    call    print_hex4
    call    print_crlf

    ; Use INT 21h 44h/00 IOCTL to get device info
    ; This helps verify the handle is valid
    mov     bx, [handle]
    mov     ax, 0x4400          ; IOCTL Get Device Info
    int     0x21
    jc      .ioctl_error

    ; Print device info
    mov     dx, msg_devinfo
    mov     ah, 0x09
    int     0x21
    ; DX has device info word
    mov     ax, dx
    call    print_hex4
    call    print_crlf

    ; Try to read first 16 bytes
    mov     dx, msg_reading
    mov     ah, 0x09
    int     0x21

    mov     bx, [handle]
    mov     cx, 16
    mov     dx, buffer
    mov     ah, 0x3F
    int     0x21
    jc      .read_error

    ; Print bytes read
    mov     dx, msg_got
    mov     ah, 0x09
    int     0x21
    call    print_hex4
    mov     dx, msg_bytes
    mov     ah, 0x09
    int     0x21

    ; If we got bytes, print first few as hex
    test    ax, ax
    jz      .no_data
    mov     cx, ax
    cmp     cx, 16
    jbe     .print_data
    mov     cx, 16
.print_data:
    mov     si, buffer
.print_loop:
    lodsb
    call    print_hex2
    mov     dl, ' '
    mov     ah, 0x02
    int     0x21
    loop    .print_loop
    call    print_crlf
    jmp     .close

.no_data:
    mov     dx, msg_nodata
    mov     ah, 0x09
    int     0x21

.close:
    mov     bx, [handle]
    mov     ah, 0x3E
    int     0x21

    mov     ax, 0x4C00
    int     0x21

.open_error:
    mov     dx, msg_openerr
    jmp     .print_error

.ioctl_error:
    mov     dx, msg_ioctlerr
    jmp     .print_error

.read_error:
    mov     dx, msg_readerr
.print_error:
    mov     ah, 0x09
    int     0x21
    mov     ax, 0x4C01
    int     0x21

; Print AL as 2 hex digits
print_hex2:
    push    ax
    push    cx
    mov     ah, al
    shr     al, 4
    call    .hex_digit
    mov     al, ah
    and     al, 0x0F
    call    .hex_digit
    pop     cx
    pop     ax
    ret
.hex_digit:
    add     al, '0'
    cmp     al, '9'
    jbe     .print_it
    add     al, 7
.print_it:
    mov     dl, al
    mov     ah, 0x02
    int     0x21
    ret

; Print AX as 4 hex digits
print_hex4:
    push    ax
    mov     al, ah
    call    print_hex2
    pop     ax
    call    print_hex2
    ret

print_crlf:
    mov     dx, crlf
    mov     ah, 0x09
    int     0x21
    ret

filename    db  'ALLCANM1', 0
msg_handle  db  'Handle: $'
msg_devinfo db  'DevInfo: $'
msg_reading db  'Read 16 bytes...$'
msg_got     db  'Got $'
msg_bytes   db  ' bytes: $'
msg_nodata  db  '(no data)', 0x0D, 0x0A, '$'
msg_openerr db  'Open error!', 0x0D, 0x0A, '$'
msg_ioctlerr db 'IOCTL error!', 0x0D, 0x0A, '$'
msg_readerr db  'Read error!', 0x0D, 0x0A, '$'
crlf        db  0x0D, 0x0A, '$'
handle      dw  0
buffer      times 512 db 0
