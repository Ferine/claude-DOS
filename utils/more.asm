; ===========================================================================
; MORE.COM - Paging filter
; Reads from STDIN, displays one screenful at a time
; ===========================================================================
    CPU     186
    ORG     0x0100

    xor     cx, cx              ; Line counter
    mov     byte [lines_per_page], 24

read_loop:
    mov     ah, 0x3F            ; Read from STDIN
    mov     bx, 0               ; Handle 0 = STDIN
    mov     cx, 1
    mov     dx, char_buf
    int     0x21
    jc      done
    test    ax, ax
    jz      done

    ; Write character to STDOUT
    mov     ah, 0x40
    mov     bx, 1
    mov     cx, 1
    mov     dx, char_buf
    int     0x21

    ; Check for newline
    cmp     byte [char_buf], 0x0A
    jne     read_loop

    inc     byte [line_count]
    mov     al, [line_count]
    cmp     al, [lines_per_page]
    jb      read_loop

    ; Show prompt
    mov     dx, more_msg
    mov     ah, 0x09
    int     0x21

    ; Wait for key
    xor     ah, ah
    int     0x16

    ; Clear the prompt line
    mov     dx, clear_msg
    mov     ah, 0x09
    int     0x21

    mov     byte [line_count], 0
    jmp     read_loop

done:
    mov     ax, 0x4C00
    int     0x21

lines_per_page  db  24
line_count      db  0
char_buf        db  0
more_msg        db  '-- More --$'
clear_msg       db  0x0D, '           ', 0x0D, '$'
