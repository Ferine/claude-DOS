; ===========================================================================
; MOUSETEST.COM - PS/2 Mouse Test Program for ClaudeDOS
; Tests INT 33h mouse driver functionality
; ===========================================================================

    CPU     186
    ORG     0x0100

start:
    ; Print banner
    mov     dx, msg_banner
    mov     ah, 0x09
    int     0x21

    ; Function 00h: Reset and detect mouse
    xor     ax, ax
    int     0x33

    ; Check if mouse present (AX = FFFFh means yes)
    cmp     ax, 0xFFFF
    je      .mouse_found

    ; No mouse - print error and exit
    mov     dx, msg_no_mouse
    mov     ah, 0x09
    int     0x21
    mov     ax, 0x4C01
    int     0x21

.mouse_found:
    ; Print mouse found message with button count
    push    bx
    mov     dx, msg_found
    mov     ah, 0x09
    int     0x21
    pop     ax
    call    print_decimal
    mov     dx, msg_buttons
    mov     ah, 0x09
    int     0x21

    ; Function 01h: Show cursor
    mov     ax, 0x0001
    int     0x33

    mov     dx, msg_instructions
    mov     ah, 0x09
    int     0x21

main_loop:
    ; Function 03h: Get position and button status
    mov     ax, 0x0003
    int     0x33

    ; Save values
    push    bx                      ; Buttons
    push    cx                      ; X
    push    dx                      ; Y

    ; Position cursor at row 10, column 0 for status display
    mov     ah, 0x02
    mov     bh, 0
    mov     dh, 10                  ; Row
    mov     dl, 0                   ; Column
    int     0x10

    ; Print X position
    mov     dx, msg_x
    mov     ah, 0x09
    int     0x21

    pop     ax                      ; Saved Y
    push    ax
    pop     ax
    push    ax
    ; Get X from stack
    mov     bp, sp
    mov     ax, [bp + 2]            ; CX (X) is second from top
    call    print_decimal_padded

    ; Print Y position
    mov     dx, msg_y
    mov     ah, 0x09
    int     0x21

    mov     bp, sp
    mov     ax, [bp]                ; DX (Y) is on top
    call    print_decimal_padded

    ; Print button status
    mov     dx, msg_btn
    mov     ah, 0x09
    int     0x21

    mov     bp, sp
    mov     ax, [bp + 4]            ; BX (buttons) is third

    ; Print left button
    test    al, 0x01
    jz      .left_up
    mov     dl, 'L'
    jmp     .print_left
.left_up:
    mov     dl, '-'
.print_left:
    mov     ah, 0x02
    int     0x21

    ; Print right button
    mov     bp, sp
    mov     ax, [bp + 4]
    test    al, 0x02
    jz      .right_up
    mov     dl, 'R'
    jmp     .print_right
.right_up:
    mov     dl, '-'
.print_right:
    mov     ah, 0x02
    int     0x21

    ; Print middle button
    mov     bp, sp
    mov     ax, [bp + 4]
    test    al, 0x04
    jz      .middle_up
    mov     dl, 'M'
    jmp     .print_middle
.middle_up:
    mov     dl, '-'
.print_middle:
    mov     ah, 0x02
    int     0x21

    ; Clean up stack
    add     sp, 6

    ; Check for keypress (ESC to exit)
    mov     ah, 0x01
    int     0x16
    jz      main_loop               ; No key - continue loop

    ; Get the key
    mov     ah, 0x00
    int     0x16
    cmp     al, 27                  ; ESC?
    jne     main_loop

    ; Function 02h: Hide cursor before exit
    mov     ax, 0x0002
    int     0x33

    ; Print goodbye message
    mov     dx, msg_exit
    mov     ah, 0x09
    int     0x21

    ; Exit
    mov     ax, 0x4C00
    int     0x21

; ---------------------------------------------------------------------------
; print_decimal - Print AX as decimal number
; ---------------------------------------------------------------------------
print_decimal:
    push    ax
    push    bx
    push    cx
    push    dx

    mov     bx, 10
    xor     cx, cx                  ; Digit counter

.divide_loop:
    xor     dx, dx
    div     bx                      ; AX = AX / 10, DX = remainder
    push    dx                      ; Save digit
    inc     cx
    test    ax, ax
    jnz     .divide_loop

.print_loop:
    pop     dx
    add     dl, '0'
    mov     ah, 0x02
    int     0x21
    loop    .print_loop

    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

; ---------------------------------------------------------------------------
; print_decimal_padded - Print AX as 5-digit decimal with leading spaces
; ---------------------------------------------------------------------------
print_decimal_padded:
    push    ax
    push    bx
    push    cx
    push    dx
    push    si

    mov     si, 5                   ; Field width
    mov     bx, 10
    xor     cx, cx                  ; Digit counter

.divide_loop:
    xor     dx, dx
    div     bx
    push    dx
    inc     cx
    test    ax, ax
    jnz     .divide_loop

    ; Print leading spaces
    mov     ax, si
    sub     ax, cx                  ; Spaces needed
    jz      .print_digits
    push    cx
    mov     cx, ax
.space_loop:
    mov     dl, ' '
    mov     ah, 0x02
    int     0x21
    loop    .space_loop
    pop     cx

.print_digits:
    pop     dx
    add     dl, '0'
    mov     ah, 0x02
    int     0x21
    loop    .print_digits

    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

; ---------------------------------------------------------------------------
; Data
; ---------------------------------------------------------------------------
msg_banner      db  'ClaudeDOS Mouse Test', 0x0D, 0x0A
                db  '====================', 0x0D, 0x0A, 0x0D, 0x0A, '$'
msg_no_mouse    db  'ERROR: No mouse detected!', 0x0D, 0x0A
                db  'INT 33h returned AX=0', 0x0D, 0x0A, '$'
msg_found       db  'Mouse detected with $'
msg_buttons     db  ' button(s)', 0x0D, 0x0A, '$'
msg_instructions db 0x0D, 0x0A
                db  'Move the mouse and click buttons.', 0x0D, 0x0A
                db  'Press ESC to exit.', 0x0D, 0x0A, 0x0D, 0x0A, '$'
msg_x           db  'X: $'
msg_y           db  '  Y: $'
msg_btn         db  '  Buttons: $'
msg_exit        db  0x0D, 0x0A, 0x0D, 0x0A, 'Mouse test complete.', 0x0D, 0x0A, '$'
