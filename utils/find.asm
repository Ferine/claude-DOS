; ===========================================================================
; FIND.COM - Search for text string in files
; Usage: FIND "string" filename
; ===========================================================================
    CPU     186
    ORG     0x0100

    ; Parse command line
    mov     si, 0x81            ; Command tail

    ; Skip spaces
.skip:
    lodsb
    cmp     al, ' '
    je      .skip
    cmp     al, 0x0D
    je      .usage

    ; Check for quote
    cmp     al, '"'
    jne     .usage

    ; Copy search string
    mov     di, search_str
.copy_str:
    lodsb
    cmp     al, '"'
    je      .str_done
    cmp     al, 0x0D
    je      .usage
    stosb
    jmp     .copy_str
.str_done:
    mov     byte [di], 0

    ; Skip space, get filename
.skip2:
    lodsb
    cmp     al, ' '
    je      .skip2
    dec     si
    mov     dx, si
    ; Null-terminate filename at CR
    mov     di, si
.find_end:
    cmp     byte [di], 0x0D
    je      .end_found
    cmp     byte [di], 0
    je      .end_found
    inc     di
    jmp     .find_end
.end_found:
    mov     byte [di], 0

    ; Open file
    mov     ax, 0x3D00
    int     0x21
    jc      .not_found

    mov     [file_handle], ax

    ; Print header
    push    dx
    mov     dx, find_header1
    mov     ah, 0x09
    int     0x21
    pop     dx
    call    print_az
    mov     dx, find_crlf
    mov     ah, 0x09
    int     0x21

    ; Read and search line by line
    ; (simplified: just show stub message)
    mov     dx, find_searching
    mov     ah, 0x09
    int     0x21

    mov     bx, [file_handle]
    mov     ah, 0x3E
    int     0x21

    mov     ax, 0x4C00
    int     0x21

.not_found:
    mov     dx, find_err_msg
    mov     ah, 0x09
    int     0x21
    mov     ax, 0x4C01
    int     0x21

.usage:
    mov     dx, find_usage
    mov     ah, 0x09
    int     0x21
    mov     ax, 0x4C01
    int     0x21

print_az:
    push    si
    mov     si, dx
    mov     ah, 0x0E
    xor     bx, bx
.loop:
    lodsb
    test    al, al
    jz      .done
    int     0x10
    jmp     .loop
.done:
    pop     si
    ret

file_handle     dw  0
search_str      times 128 db 0
find_header1    db  0x0D, 0x0A, '---------- $'
find_crlf       db  0x0D, 0x0A, '$'
find_searching  db  '(searching...)', 0x0D, 0x0A, '$'
find_err_msg    db  'File not found', 0x0D, 0x0A, '$'
find_usage      db  'FIND: "string" filename', 0x0D, 0x0A, '$'
