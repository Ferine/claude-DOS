; BIGREAD.COM - Test reading large files (ALLCANM1 = 185KB)
    CPU     186
    ORG     0x0100

start:
    ; Open ALLCANM1
    mov     dx, filename
    mov     ax, 0x3D00          ; Open for reading
    int     0x21
    jc      .open_error
    mov     [handle], ax

    ; Print "Reading..."
    mov     dx, msg_reading
    mov     ah, 0x09
    int     0x21

    ; Read loop - read 512 bytes at a time, count total
    xor     si, si              ; SI = total bytes low
    xor     di, di              ; DI = total bytes high

.read_loop:
    mov     bx, [handle]
    mov     cx, 512             ; Read 512 bytes
    mov     dx, buffer
    mov     ah, 0x3F
    int     0x21
    jc      .read_error

    ; AX = bytes actually read
    test    ax, ax
    jz      .read_done          ; EOF

    ; Add to total (32-bit)
    add     si, ax
    adc     di, 0

    ; Print a dot every 16KB (32 reads)
    inc     word [read_count]
    test    word [read_count], 0x001F
    jnz     .read_loop
    mov     dl, '.'
    mov     ah, 0x02
    int     0x21
    jmp     .read_loop

.read_done:
    ; Close file
    mov     bx, [handle]
    mov     ah, 0x3E
    int     0x21

    ; Print newline
    mov     dx, crlf
    mov     ah, 0x09
    int     0x21

    ; Print total bytes
    mov     dx, msg_total
    mov     ah, 0x09
    int     0x21

    ; Print 32-bit number (DI:SI where DI=high, SI=low)
    ; print_dec32 expects DX:AX (DX=high, AX=low)
    mov     ax, si              ; AX = low word
    mov     dx, di              ; DX = high word
    call    print_dec32

    ; Print " bytes"
    mov     dx, msg_bytes
    mov     ah, 0x09
    int     0x21

    ; Exit
    mov     ax, 0x4C00
    int     0x21

.open_error:
    mov     dx, msg_open_err
    mov     ah, 0x09
    int     0x21
    mov     ax, 0x4C01
    int     0x21

.read_error:
    mov     dx, msg_read_err
    mov     ah, 0x09
    int     0x21
    mov     ax, 0x4C02
    int     0x21

; Print 32-bit number in DX:AX as decimal
; Uses recursive division
print_dec32:
    push    ax
    push    bx
    push    cx
    push    dx

    ; Save number
    mov     [.num_lo], ax
    mov     [.num_hi], dx

    ; If number is 0, just print "0"
    or      ax, dx
    jnz     .not_zero
    mov     dl, '0'
    mov     ah, 0x02
    int     0x21
    jmp     .print_done

.not_zero:
    ; Convert to decimal digits (right to left)
    mov     cx, 0               ; Digit count

.convert_loop:
    ; Divide 32-bit number by 10
    ; DX:AX / 10 -> quotient in DX:AX, remainder in somewhere
    mov     ax, [.num_hi]
    xor     dx, dx
    mov     bx, 10
    div     bx                  ; AX = high/10, DX = high%10
    mov     [.num_hi], ax
    mov     ax, [.num_lo]
    div     bx                  ; AX = ((high%10)*65536+low)/10, DX = remainder
    mov     [.num_lo], ax

    ; Push digit
    add     dl, '0'
    push    dx
    inc     cx

    ; Continue if number != 0
    mov     ax, [.num_lo]
    or      ax, [.num_hi]
    jnz     .convert_loop

    ; Print digits
.print_digits:
    pop     dx
    mov     ah, 0x02
    int     0x21
    loop    .print_digits

.print_done:
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

.num_lo     dw  0
.num_hi     dw  0

filename    db  'ALLCANM1', 0
msg_reading db  'Reading ALLCANM1: $'
msg_total   db  'Total: $'
msg_bytes   db  ' bytes', 0x0D, 0x0A, '$'
msg_open_err db 'Cannot open ALLCANM1', 0x0D, 0x0A, '$'
msg_read_err db 'Read error!', 0x0D, 0x0A, '$'
crlf        db  0x0D, 0x0A, '$'
handle      dw  0
read_count  dw  0
buffer      times 512 db 0
