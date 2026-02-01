; ===========================================================================
; claudeDOS CON (Console) Device Driver
; Keyboard input via INT 16h, display output via INT 10h
; ===========================================================================

con_device:
    dw      0xFFFF
    dw      0
    dw      DEV_ATTR_CHAR | DEV_ATTR_STDOUT | DEV_ATTR_STDIN
    dw      con_strategy
    dw      con_interrupt
    db      'CON     '

con_req_ptr     dd  0

con_strategy:
    mov     [cs:con_req_ptr], bx
    mov     [cs:con_req_ptr + 2], es
    retf

con_interrupt:
    push    ds
    push    bx
    push    cx
    push    dx
    push    si
    push    di
    push    es
    push    ax

    lds     bx, [cs:con_req_ptr]
    mov     al, [bx + 2]       ; Command code

    cmp     al, 0               ; Init
    je      .cmd_init
    cmp     al, 4               ; Input (read)
    je      .cmd_read
    cmp     al, 8               ; Output (write)
    je      .cmd_write
    cmp     al, 6               ; Input status
    je      .cmd_input_status
    cmp     al, 10              ; Output status
    je      .cmd_output_status

    ; Unknown command - set done + error
    mov     word [bx + 3], 0x8103
    jmp     .done

.cmd_init:
    mov     word [bx + 3], 0x0100
    jmp     .done

.cmd_read:
    ; Read CX bytes from keyboard to ES:DI buffer
    mov     cx, [bx + 18]       ; Transfer count
    les     di, [bx + 14]       ; Buffer address
    xor     dx, dx              ; Bytes read

.read_loop:
    test    cx, cx
    jz      .read_done
    xor     ah, ah
    int     0x16                ; Wait for key
    stosb
    dec     cx
    inc     dx
    jmp     .read_loop

.read_done:
    lds     bx, [cs:con_req_ptr]
    mov     [bx + 18], dx       ; Actual bytes read
    mov     word [bx + 3], 0x0100
    jmp     .done

.cmd_write:
    ; Write CX bytes from DS:SI buffer to screen
    mov     cx, [bx + 18]       ; Transfer count
    push    ds
    lds     si, [bx + 14]       ; Buffer address

    mov     ah, 0x0E
    xor     bx, bx
.write_loop:
    test    cx, cx
    jz      .write_done
    lodsb
    int     0x10
    dec     cx
    jmp     .write_loop

.write_done:
    pop     ds
    lds     bx, [cs:con_req_ptr]
    mov     word [bx + 3], 0x0100
    jmp     .done

.cmd_input_status:
    ; Check if key available
    mov     ah, 0x01
    int     0x16
    mov     word [bx + 3], 0x0100
    jnz     .done
    or      word [bx + 3], 0x0200   ; Set busy bit if no key
    jmp     .done

.cmd_output_status:
    ; Console is always ready for output
    mov     word [bx + 3], 0x0100
    jmp     .done

.done:
    pop     ax
    pop     es
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ds
    retf
