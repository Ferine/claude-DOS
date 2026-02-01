; ===========================================================================
; TYPE command - Display file contents
; ===========================================================================

cmd_type:
    pusha

    ; SI points to filename argument
    cmp     byte [si], 0
    je      .no_file

    ; Open file for reading
    mov     dx, si
    mov     ax, 0x3D00          ; Open, read-only
    int     0x21
    jc      .not_found

    mov     bx, ax              ; File handle

    ; Read and display loop
.read_loop:
    mov     ah, 0x3F
    mov     cx, 512
    mov     dx, type_buf
    int     0x21
    jc      .close
    test    ax, ax              ; EOF?
    jz      .close

    ; Write to stdout
    mov     cx, ax              ; Bytes read
    mov     bx, 1               ; STDOUT
    mov     ah, 0x40
    mov     dx, type_buf
    int     0x21
    jmp     .read_loop

.close:
    mov     ah, 0x3E
    int     0x21
    jmp     .done

.not_found:
    mov     dx, type_err_msg
    mov     ah, 0x09
    int     0x21
    jmp     .done

.no_file:
    mov     dx, type_syntax_msg
    mov     ah, 0x09
    int     0x21

.done:
    popa
    ret

type_err_msg    db  'File not found', 0x0D, 0x0A, '$'
type_syntax_msg db  'Required parameter missing', 0x0D, 0x0A, '$'
type_buf        times 512 db 0
