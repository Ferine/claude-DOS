; Test reading ALLCANM1 file
org 0x100

section .text
start:
    ; Print opening message
    mov     ah, 0x09
    mov     dx, msg_opening
    int     0x21

    ; Open ALLCANM1
    mov     ah, 0x3D        ; Open file
    mov     al, 0x00        ; Read-only
    mov     dx, filename
    int     0x21
    jc      .open_fail

    mov     [handle], ax

    ; Print success
    mov     ah, 0x09
    mov     dx, msg_opened
    int     0x21

    ; Read first 16 bytes
    mov     ah, 0x3F        ; Read
    mov     bx, [handle]
    mov     cx, 16
    mov     dx, buffer
    int     0x21
    jc      .read_fail

    ; Print bytes read
    mov     ah, 0x09
    mov     dx, msg_read
    int     0x21

    ; Print first 8 bytes as hex
    mov     si, buffer
    mov     cx, 8
.print_loop:
    lodsb
    call    print_hex
    mov     ah, 0x02
    mov     dl, ' '
    int     0x21
    loop    .print_loop

    ; Close file
    mov     ah, 0x3E
    mov     bx, [handle]
    int     0x21

    ; Print done
    mov     ah, 0x09
    mov     dx, msg_done
    int     0x21

    ; Exit
    mov     ax, 0x4C00
    int     0x21

.open_fail:
    mov     ah, 0x09
    mov     dx, msg_open_err
    int     0x21
    mov     ax, 0x4C01
    int     0x21

.read_fail:
    mov     ah, 0x09
    mov     dx, msg_read_err
    int     0x21
    mov     ax, 0x4C02
    int     0x21

; Print AL as hex
print_hex:
    push    ax
    push    dx
    mov     ah, al
    shr     al, 4
    call    .nibble
    mov     al, ah
    and     al, 0x0F
    call    .nibble
    pop     dx
    pop     ax
    ret
.nibble:
    add     al, '0'
    cmp     al, '9'
    jbe     .out
    add     al, 7
.out:
    mov     dl, al
    mov     ah, 0x02
    int     0x21
    ret

section .data
filename    db 'ALLCANM1', 0
msg_opening db 'Opening ALLCANM1...', 0x0D, 0x0A, '$'
msg_opened  db 'File opened OK', 0x0D, 0x0A, '$'
msg_read    db 'First 8 bytes: ', '$'
msg_done    db 0x0D, 0x0A, 'Done!', 0x0D, 0x0A, '$'
msg_open_err db 'OPEN FAILED!', 0x0D, 0x0A, '$'
msg_read_err db 'READ FAILED!', 0x0D, 0x0A, '$'

section .bss
handle      resw 1
buffer      resb 16
