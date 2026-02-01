; Test file create/write functionality
org 0x100

section .text
start:
    ; Print header
    mov     dx, msg_header
    mov     ah, 0x09
    int     0x21

    ; Create file TEST.TXT
    mov     dx, filename
    mov     cx, 0x00            ; Normal file
    mov     ah, 0x3C
    int     0x21
    jc      .create_error

    mov     [handle], ax        ; Save handle

    ; Print success
    mov     dx, msg_created
    mov     ah, 0x09
    int     0x21

    ; Write some data
    mov     bx, [handle]
    mov     dx, test_data
    mov     cx, test_data_len
    mov     ah, 0x40
    int     0x21
    jc      .write_error

    ; Print bytes written
    push    ax
    mov     dx, msg_wrote
    mov     ah, 0x09
    int     0x21
    pop     ax
    call    print_decimal

    mov     dx, msg_bytes
    mov     ah, 0x09
    int     0x21

    ; Close file
    mov     bx, [handle]
    mov     ah, 0x3E
    int     0x21

    ; Now verify - open and read back
    mov     dx, filename
    mov     al, 0               ; Open for reading
    mov     ah, 0x3D
    int     0x21
    jc      .open_error

    mov     [handle], ax

    ; Read data back
    mov     bx, [handle]
    mov     dx, read_buffer
    mov     cx, 100
    mov     ah, 0x3F
    int     0x21
    jc      .read_error

    ; Print what we read
    mov     dx, msg_read
    mov     ah, 0x09
    int     0x21

    ; Print the buffer contents
    mov     cx, ax              ; Bytes read
    mov     si, read_buffer
.print_loop:
    test    cx, cx
    jz      .print_done
    lodsb
    mov     dl, al
    mov     ah, 0x02
    int     0x21
    dec     cx
    jmp     .print_loop

.print_done:
    mov     dx, crlf
    mov     ah, 0x09
    int     0x21

    ; Close file
    mov     bx, [handle]
    mov     ah, 0x3E
    int     0x21

    ; Delete the test file
    mov     dx, filename
    mov     ah, 0x41
    int     0x21
    jc      .delete_error

    mov     dx, msg_deleted
    mov     ah, 0x09
    int     0x21

    ; Success
    mov     dx, msg_done
    mov     ah, 0x09
    int     0x21
    mov     ax, 0x4C00
    int     0x21

.create_error:
    mov     dx, msg_create_err
    jmp     .error_exit

.write_error:
    mov     dx, msg_write_err
    jmp     .error_exit

.open_error:
    mov     dx, msg_open_err
    jmp     .error_exit

.read_error:
    mov     dx, msg_read_err
    jmp     .error_exit

.delete_error:
    mov     dx, msg_delete_err
    jmp     .error_exit

.error_exit:
    mov     ah, 0x09
    int     0x21
    mov     ax, 0x4C01
    int     0x21

; Print AX as decimal
print_decimal:
    push    bx
    push    cx
    push    dx

    mov     bx, 10
    xor     cx, cx

.div_loop:
    xor     dx, dx
    div     bx
    push    dx
    inc     cx
    test    ax, ax
    jnz     .div_loop

.print_digits:
    pop     dx
    add     dl, '0'
    mov     ah, 0x02
    int     0x21
    loop    .print_digits

    pop     dx
    pop     cx
    pop     bx
    ret

section .data
msg_header      db 'File create/write test:', 13, 10, '$'
msg_created     db 'Created TEST.TXT', 13, 10, '$'
msg_wrote       db 'Wrote $'
msg_bytes       db ' bytes', 13, 10, '$'
msg_read        db 'Read back: $'
msg_deleted     db 'Deleted TEST.TXT', 13, 10, '$'
msg_done        db 'All tests passed!', 13, 10, '$'
msg_create_err  db 'ERROR: Could not create file!', 13, 10, '$'
msg_write_err   db 'ERROR: Could not write to file!', 13, 10, '$'
msg_open_err    db 'ERROR: Could not open file!', 13, 10, '$'
msg_read_err    db 'ERROR: Could not read file!', 13, 10, '$'
msg_delete_err  db 'ERROR: Could not delete file!', 13, 10, '$'
crlf            db 13, 10, '$'
filename        db 'TEST.TXT', 0
test_data       db 'Hello from claudeDOS!'
test_data_len   equ $ - test_data

section .bss
handle          resw 1
read_buffer     resb 128
