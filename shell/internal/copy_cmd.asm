; ===========================================================================
; COPY command - Copy files
; Usage: COPY source destination
; ===========================================================================

COPY_BUFFER_SIZE    equ     512

cmd_copy:
    pusha
    push    es

    ; Check for arguments
    cmp     byte [si], 0
    je      .syntax_err

    ; Parse source filename
    call    parse_filename          ; DX = source, SI advanced
    mov     [copy_src], dx

    ; Skip spaces to second argument
    call    skip_spaces
    cmp     byte [si], 0
    je      .syntax_err

    ; Parse destination filename
    call    parse_filename
    mov     [copy_dst], dx

    ; Open source file (read-only)
    mov     dx, [copy_src]
    mov     ax, 0x3D00              ; Open for reading
    int     0x21
    jc      .src_not_found
    mov     [copy_src_handle], ax

    ; Create destination file
    mov     dx, [copy_dst]
    xor     cx, cx                  ; Normal attributes
    mov     ah, 0x3C                ; Create file
    int     0x21
    jc      .dst_error
    mov     [copy_dst_handle], ax

    ; Initialize byte counter
    mov     word [copy_bytes_lo], 0
    mov     word [copy_bytes_hi], 0

    ; Copy loop
.copy_loop:
    ; Read from source
    mov     bx, [copy_src_handle]
    mov     cx, COPY_BUFFER_SIZE
    mov     dx, copy_buffer
    mov     ah, 0x3F
    int     0x21
    jc      .read_error

    ; Check for EOF
    test    ax, ax
    jz      .copy_done

    ; Track bytes
    add     [copy_bytes_lo], ax
    adc     word [copy_bytes_hi], 0

    ; Write to destination
    mov     cx, ax                  ; Bytes to write
    mov     bx, [copy_dst_handle]
    mov     dx, copy_buffer
    mov     ah, 0x40
    int     0x21
    jc      .write_error

    ; Check if write was complete
    cmp     ax, cx
    jne     .disk_full

    jmp     .copy_loop

.copy_done:
    ; Close both files
    mov     bx, [copy_src_handle]
    mov     ah, 0x3E
    int     0x21

    mov     bx, [copy_dst_handle]
    mov     ah, 0x3E
    int     0x21

    ; Print success message
    mov     dx, copy_msg_copied
    mov     ah, 0x09
    int     0x21

    ; Print byte count
    mov     dx, [copy_bytes_hi]
    mov     ax, [copy_bytes_lo]
    call    print_dec32

    mov     dx, copy_msg_bytes
    mov     ah, 0x09
    int     0x21

    pop     es
    popa
    ret

.syntax_err:
    mov     dx, copy_syntax_msg
    mov     ah, 0x09
    int     0x21
    pop     es
    popa
    ret

.src_not_found:
    mov     dx, copy_src_err_msg
    mov     ah, 0x09
    int     0x21
    pop     es
    popa
    ret

.dst_error:
    ; Close source
    mov     bx, [copy_src_handle]
    mov     ah, 0x3E
    int     0x21

    mov     dx, copy_dst_err_msg
    mov     ah, 0x09
    int     0x21
    pop     es
    popa
    ret

.read_error:
    call    .close_both
    mov     dx, copy_read_err_msg
    mov     ah, 0x09
    int     0x21
    pop     es
    popa
    ret

.write_error:
    call    .close_both
    mov     dx, copy_write_err_msg
    mov     ah, 0x09
    int     0x21
    pop     es
    popa
    ret

.disk_full:
    call    .close_both
    mov     dx, copy_full_msg
    mov     ah, 0x09
    int     0x21
    pop     es
    popa
    ret

.close_both:
    mov     bx, [copy_src_handle]
    mov     ah, 0x3E
    int     0x21
    mov     bx, [copy_dst_handle]
    mov     ah, 0x3E
    int     0x21
    ret

; Data
copy_src            dw  0
copy_dst            dw  0
copy_src_handle     dw  0
copy_dst_handle     dw  0
copy_bytes_lo       dw  0
copy_bytes_hi       dw  0

copy_syntax_msg     db  'Syntax: COPY source destination', 0x0D, 0x0A, '$'
copy_src_err_msg    db  'File not found', 0x0D, 0x0A, '$'
copy_dst_err_msg    db  'Cannot create destination file', 0x0D, 0x0A, '$'
copy_read_err_msg   db  'Error reading source file', 0x0D, 0x0A, '$'
copy_write_err_msg  db  'Error writing destination file', 0x0D, 0x0A, '$'
copy_full_msg       db  'Insufficient disk space', 0x0D, 0x0A, '$'
copy_msg_copied     db  '        1 file(s) copied (', '$'
copy_msg_bytes      db  ' bytes)', 0x0D, 0x0A, '$'

copy_buffer         times COPY_BUFFER_SIZE db 0
