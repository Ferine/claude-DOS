; ===========================================================================
; claudeDOS PS/2 Mouse Driver
; Provides INT 33h (Microsoft Mouse Driver) compatible interface
; ===========================================================================

; ---------------------------------------------------------------------------
; mouse_init - Initialize PS/2 mouse hardware and driver
; Returns: CF set if no mouse found, clear if mouse initialized
; ---------------------------------------------------------------------------
mouse_init:
    pusha
    push    es

    ; Print initialization message
    mov     si, msg_mouse_init
    call    bios_print_string

    ; Disable interrupts during hardware setup
    cli

    ; Enable auxiliary PS/2 port (mouse port)
    call    ps2_wait_input
    mov     al, PS2_CMD_ENABLE_PORT2
    out     PS2_COMMAND_PORT, al

    ; Read current configuration byte
    call    ps2_wait_input
    mov     al, PS2_CMD_READ_CONFIG
    out     PS2_COMMAND_PORT, al
    call    ps2_wait_output
    in      al, PS2_DATA_PORT
    mov     bl, al                      ; Save config in BL

    ; Enable mouse interrupt (IRQ12) and mouse clock
    or      bl, PS2_CFG_PORT2_INT       ; Enable IRQ12
    and     bl, ~PS2_CFG_PORT2_CLK      ; Enable mouse clock (clear disable bit)

    ; Write modified configuration
    call    ps2_wait_input
    mov     al, PS2_CMD_WRITE_CONFIG
    out     PS2_COMMAND_PORT, al
    call    ps2_wait_input
    mov     al, bl
    out     PS2_DATA_PORT, al

    ; Reset the mouse
    call    mouse_send_cmd
    db      MOUSE_CMD_RESET
    jc      .no_mouse

    ; Wait for reset response: 0xAA (self-test passed), then 0x00 (mouse ID)
    ; Note: ACK (0xFA) was already consumed by mouse_send_cmd
    call    ps2_wait_output_long
    jc      .no_mouse
    in      al, PS2_DATA_PORT
    cmp     al, MOUSE_RESET_OK          ; Expect 0xAA (self-test passed)
    jne     .no_mouse

    call    ps2_wait_output_long
    jc      .no_mouse
    in      al, PS2_DATA_PORT           ; Mouse ID (0x00 for standard mouse)

    ; Set sample rate to 100 samples/second
    call    mouse_send_cmd
    db      MOUSE_CMD_SET_SAMPLE
    jc      .no_mouse
    call    mouse_send_cmd
    db      100                         ; 100 samples/sec
    jc      .no_mouse

    ; Set resolution to 4 counts/mm
    call    mouse_send_cmd
    db      MOUSE_CMD_SET_RES
    jc      .no_mouse
    call    mouse_send_cmd
    db      2                           ; 4 counts/mm
    jc      .no_mouse

    ; Set 1:1 scaling
    call    mouse_send_cmd
    db      MOUSE_CMD_SET_SCALE
    jc      .no_mouse

    ; Enable data reporting
    call    mouse_send_cmd
    db      MOUSE_CMD_ENABLE
    jc      .no_mouse

    ; Install IRQ 12 handler (INT 74h)
    xor     ax, ax
    mov     es, ax

    ; Save old vector
    mov     ax, [es:0x01D0]             ; INT 74h = 74h * 4 = 0x1D0
    mov     [int74_old_vector], ax
    mov     ax, [es:0x01D2]
    mov     [int74_old_vector + 2], ax

    ; Install our handler
    mov     word [es:0x01D0], int74_handler
    mov     [es:0x01D2], cs

    ; Unmask IRQ 12 in slave PIC (IRQ 12 is bit 4 on slave)
    in      al, PIC2_DATA
    and     al, ~0x10                   ; Clear bit 4
    out     PIC2_DATA, al

    ; Also ensure IRQ 2 (cascade) is unmasked on master PIC
    in      al, PIC1_DATA
    and     al, ~0x04                   ; Clear bit 2
    out     PIC1_DATA, al

    ; Mark mouse as present
    mov     byte [mouse_present], 1

    ; Initialize position to center
    mov     word [mouse_x], 320
    mov     word [mouse_y], 100

    sti

    mov     si, msg_mouse_found
    call    bios_print_string

    pop     es
    popa
    clc
    ret

.no_mouse:
    sti
    mov     si, msg_mouse_not_found
    call    bios_print_string
    pop     es
    popa
    stc
    ret

; ---------------------------------------------------------------------------
; mouse_send_cmd - Send a command byte to the mouse
; Command byte follows the CALL instruction
; Returns: CF set on timeout/error
; ---------------------------------------------------------------------------
mouse_send_cmd:
    push    bp
    mov     bp, sp
    push    ax
    push    bx

    ; Get command byte from after the call
    mov     bx, [bp + 2]                ; Return address
    mov     al, [cs:bx]                 ; Get command byte
    inc     word [bp + 2]               ; Skip past command byte

    ; Tell controller next byte goes to mouse
    call    ps2_wait_input
    jc      .timeout
    push    ax
    mov     al, PS2_CMD_WRITE_PORT2
    out     PS2_COMMAND_PORT, al
    pop     ax

    ; Send the command
    call    ps2_wait_input
    jc      .timeout
    out     PS2_DATA_PORT, al

    ; Wait for ACK
    call    ps2_wait_output
    jc      .timeout
    in      al, PS2_DATA_PORT
    cmp     al, MOUSE_ACK
    jne     .timeout

    pop     bx
    pop     ax
    pop     bp
    clc
    ret

.timeout:
    pop     bx
    pop     ax
    pop     bp
    stc
    ret

; ---------------------------------------------------------------------------
; ps2_wait_input - Wait for PS/2 input buffer to be empty (ready to write)
; Returns: CF set on timeout
; ---------------------------------------------------------------------------
ps2_wait_input:
    push    ax
    push    cx
    mov     cx, 0xFFFF
.wait:
    in      al, PS2_STATUS_PORT
    test    al, PS2_STATUS_INPUT
    jz      .ready
    loop    .wait
    pop     cx
    pop     ax
    stc
    ret
.ready:
    pop     cx
    pop     ax
    clc
    ret

; ---------------------------------------------------------------------------
; ps2_wait_output - Wait for PS/2 output buffer to have data (ready to read)
; Returns: CF set on timeout
; ---------------------------------------------------------------------------
ps2_wait_output:
    push    ax
    push    cx
    mov     cx, 0xFFFF
.wait:
    in      al, PS2_STATUS_PORT
    test    al, PS2_STATUS_OUTPUT
    jnz     .ready
    loop    .wait
    pop     cx
    pop     ax
    stc
    ret
.ready:
    pop     cx
    pop     ax
    clc
    ret

; ---------------------------------------------------------------------------
; ps2_wait_output_long - Wait longer for output (used during reset)
; Returns: CF set on timeout
; ---------------------------------------------------------------------------
ps2_wait_output_long:
    push    ax
    push    cx
    push    dx
    mov     dx, 0x0010                  ; Outer loop count
.outer:
    mov     cx, 0xFFFF
.wait:
    in      al, PS2_STATUS_PORT
    test    al, PS2_STATUS_OUTPUT
    jnz     .ready
    loop    .wait
    dec     dx
    jnz     .outer
    pop     dx
    pop     cx
    pop     ax
    stc
    ret
.ready:
    pop     dx
    pop     cx
    pop     ax
    clc
    ret

; ---------------------------------------------------------------------------
; int74_handler - IRQ 12 (Mouse) interrupt handler
; Assembles 3-byte packets and updates mouse state
; ---------------------------------------------------------------------------
int74_handler:
    push    ax
    push    bx
    push    cx
    push    dx
    push    ds

    mov     ax, cs
    mov     ds, ax

    ; Read the data byte
    in      al, PS2_DATA_PORT

    ; Get current packet index
    xor     bh, bh
    mov     bl, [mouse_packet_byte]

    ; For byte 0, verify bit 3 is set (always 1 in valid packets)
    cmp     bl, 0
    jne     .store_byte
    test    al, 0x08
    jz      .bad_sync                   ; Resync if bit 3 not set

.store_byte:
    mov     [mouse_packet + bx], al
    inc     bl

    ; Check if packet complete
    cmp     bl, 3
    jb      .not_complete

    ; Packet complete - process it
    mov     byte [mouse_packet_byte], 0

    ; Extract button state from byte 0
    mov     al, [mouse_packet]
    and     al, 0x07                    ; Bits 0-2 are buttons
    mov     bl, [mouse_buttons]         ; Old button state
    mov     [mouse_buttons], al

    ; Track button press/release events
    call    mouse_track_buttons

    ; Extract X movement (signed byte in packet[1])
    ; Sign extension done via byte 0 sign bits from PS/2 protocol
    mov     al, [mouse_packet + 1]
    xor     ah, ah
    test    byte [mouse_packet], 0x10   ; X sign bit in byte 0
    jz      .x_positive
    mov     ah, 0xFF                    ; Sign extend negative
.x_positive:

    ; Add to motion counter
    add     [mouse_delta_x], ax

    ; Scale and add to position
    ; position += movement * 8 / mickey_ratio
    mov     cx, [mouse_mickey_x]
    test    cx, cx
    jz      .skip_x
    imul    ax, 8
    cwd
    idiv    cx
    add     [mouse_x], ax

    ; Clamp X to bounds
    mov     ax, [mouse_x]
    cmp     ax, [mouse_min_x]
    jge     .x_not_low
    mov     ax, [mouse_min_x]
.x_not_low:
    cmp     ax, [mouse_max_x]
    jle     .x_not_high
    mov     ax, [mouse_max_x]
.x_not_high:
    mov     [mouse_x], ax
.skip_x:

    ; Extract Y movement (signed byte in packet[2])
    ; Sign extension done via byte 0 sign bits from PS/2 protocol
    mov     al, [mouse_packet + 2]
    xor     ah, ah
    test    byte [mouse_packet], 0x20   ; Y sign bit in byte 0
    jz      .y_positive
    mov     ah, 0xFF                    ; Sign extend negative
.y_positive:

    ; Add to motion counter
    add     [mouse_delta_y], ax

    ; Scale and add to position (Y is inverted for screen coordinates)
    mov     cx, [mouse_mickey_y]
    test    cx, cx
    jz      .skip_y
    imul    ax, 8
    cwd
    idiv    cx
    sub     [mouse_y], ax               ; Subtract because mouse Y is inverted

    ; Clamp Y to bounds
    mov     ax, [mouse_y]
    cmp     ax, [mouse_min_y]
    jge     .y_not_low
    mov     ax, [mouse_min_y]
.y_not_low:
    cmp     ax, [mouse_max_y]
    jle     .y_not_high
    mov     ax, [mouse_max_y]
.y_not_high:
    mov     [mouse_y], ax
.skip_y:

    ; Update cursor if visible
    cmp     word [mouse_visible], 0
    je      .no_cursor_update
    call    mouse_update_cursor
.no_cursor_update:

    ; Call user event handler if set
    call    mouse_call_user_handler

    jmp     .done

.bad_sync:
    ; Bad sync - reset packet assembly
    mov     byte [mouse_packet_byte], 0
    jmp     .done

.not_complete:
    mov     [mouse_packet_byte], bl

.done:
    ; Send EOI to slave PIC, then master PIC
    mov     al, PIC_EOI
    out     PIC2_COMMAND, al
    out     PIC1_COMMAND, al

    pop     ds
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    iret

; ---------------------------------------------------------------------------
; mouse_track_buttons - Track button press/release events
; Input: AL = new button state, BL = old button state
; ---------------------------------------------------------------------------
mouse_track_buttons:
    push    ax
    push    bx
    push    cx
    push    dx

    mov     cl, al                      ; CL = new state
    mov     ch, bl                      ; CH = old state

    ; Check left button (bit 0)
    mov     al, cl
    and     al, MOUSE_BTN_LEFT
    mov     bl, ch
    and     bl, MOUSE_BTN_LEFT
    cmp     al, bl
    je      .check_right

    test    al, al
    jz      .left_released
    ; Left pressed
    inc     word [mouse_left_press]
    mov     ax, [mouse_x]
    mov     [mouse_left_press_x], ax
    mov     ax, [mouse_y]
    mov     [mouse_left_press_y], ax
    jmp     .check_right
.left_released:
    inc     word [mouse_left_rel]
    mov     ax, [mouse_x]
    mov     [mouse_left_rel_x], ax
    mov     ax, [mouse_y]
    mov     [mouse_left_rel_y], ax

.check_right:
    ; Check right button (bit 1)
    mov     al, cl
    and     al, MOUSE_BTN_RIGHT
    mov     bl, ch
    and     bl, MOUSE_BTN_RIGHT
    cmp     al, bl
    je      .done

    test    al, al
    jz      .right_released
    ; Right pressed
    inc     word [mouse_right_press]
    mov     ax, [mouse_x]
    mov     [mouse_right_press_x], ax
    mov     ax, [mouse_y]
    mov     [mouse_right_press_y], ax
    jmp     .done
.right_released:
    inc     word [mouse_right_rel]
    mov     ax, [mouse_x]
    mov     [mouse_right_rel_x], ax
    mov     ax, [mouse_y]
    mov     [mouse_right_rel_y], ax

.done:
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

; ---------------------------------------------------------------------------
; mouse_call_user_handler - Call user event handler if conditions met
; ---------------------------------------------------------------------------
mouse_call_user_handler:
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di

    ; Check if handler is set
    mov     ax, [mouse_handler_seg]
    test    ax, ax
    jz      .no_handler
    mov     ax, [mouse_handler_off]
    test    ax, ax
    jz      .no_handler

    ; Build event mask (simplified - always call on motion/button)
    ; Bit 0: motion, bits 1-4: button press/release
    mov     ax, 0x001F                  ; All events

    ; Check against user mask
    test    ax, [mouse_handler_mask]
    jz      .no_handler

    ; Set up registers for handler call
    mov     ax, 0x001F                  ; Event mask
    mov     bx, [mouse_buttons]
    mov     cx, [mouse_x]
    mov     dx, [mouse_y]
    mov     si, [mouse_delta_x]
    mov     di, [mouse_delta_y]

    ; Far call to user handler (push return addr, then far jump)
    push    cs
    push    word .handler_return
    push    word [mouse_handler_seg]
    push    word [mouse_handler_off]
    retf
.handler_return:

.no_handler:
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

; ---------------------------------------------------------------------------
; mouse_update_cursor - Update text mode cursor position
; ---------------------------------------------------------------------------
mouse_update_cursor:
    pusha
    push    es

    ; Calculate new character position
    mov     ax, [mouse_x]
    shr     ax, 3                       ; Divide by 8 to get character column
    mov     bx, [mouse_y]
    shr     bx, 3                       ; Divide by 8 to get character row

    ; Check if position changed
    cmp     ax, [mouse_cursor_x]
    jne     .position_changed
    cmp     bx, [mouse_cursor_y]
    je      .no_change

.position_changed:
    ; Erase old cursor (restore saved character)
    call    mouse_erase_cursor

    ; Save new position
    mov     [mouse_cursor_x], ax
    mov     [mouse_cursor_y], bx

    ; Draw new cursor
    call    mouse_draw_cursor

.no_change:
    pop     es
    popa
    ret

; ---------------------------------------------------------------------------
; mouse_draw_cursor - Draw cursor at current position (invert attribute)
; ---------------------------------------------------------------------------
mouse_draw_cursor:
    pusha
    push    es

    ; Calculate video memory offset
    ; offset = (row * 80 + column) * 2
    mov     ax, [mouse_cursor_y]
    mov     bx, SCREEN_WIDTH
    mul     bx
    add     ax, [mouse_cursor_x]
    shl     ax, 1                       ; * 2 for char+attr

    ; Point to video memory
    mov     bx, 0xB800
    mov     es, bx
    mov     bx, ax

    ; Save current character and attribute
    mov     ax, [es:bx]
    mov     [mouse_saved_char], ax

    ; Invert the attribute (XOR with 0x7F)
    xor     ah, 0x7F
    mov     [es:bx], ax

    pop     es
    popa
    ret

; ---------------------------------------------------------------------------
; mouse_erase_cursor - Erase cursor (restore saved character)
; ---------------------------------------------------------------------------
mouse_erase_cursor:
    pusha
    push    es

    ; Check if we have a saved character
    mov     ax, [mouse_saved_char]
    test    ax, ax
    jz      .done

    ; Calculate video memory offset
    mov     ax, [mouse_cursor_y]
    mov     bx, SCREEN_WIDTH
    mul     bx
    add     ax, [mouse_cursor_x]
    shl     ax, 1

    ; Restore character
    mov     bx, 0xB800
    mov     es, bx
    mov     bx, ax
    mov     ax, [mouse_saved_char]
    mov     [es:bx], ax

    ; Clear saved char
    mov     word [mouse_saved_char], 0

.done:
    pop     es
    popa
    ret

; ---------------------------------------------------------------------------
; INT 33h handler - Microsoft Mouse Driver API
; ---------------------------------------------------------------------------
int33_handler_main:
    cmp     ah, 0
    jne     .not_fn0
    ; Function dispatch based on AL for functions 00h-21h
    cmp     al, 0x00
    je      mouse_fn00_reset
    cmp     al, 0x01
    je      mouse_fn01_show
    cmp     al, 0x02
    je      mouse_fn02_hide
    cmp     al, 0x03
    je      mouse_fn03_get_pos
    cmp     al, 0x04
    je      mouse_fn04_set_pos
    cmp     al, 0x05
    je      mouse_fn05_get_press
    cmp     al, 0x06
    je      mouse_fn06_get_release
    cmp     al, 0x07
    je      mouse_fn07_set_horiz
    cmp     al, 0x08
    je      mouse_fn08_set_vert
    cmp     al, 0x0B
    je      mouse_fn0B_get_motion
    cmp     al, 0x0C
    je      mouse_fn0C_set_handler
    cmp     al, 0x0F
    je      mouse_fn0F_set_ratio
    cmp     al, 0x21
    je      mouse_fn00_reset            ; Software reset
    jmp     .unhandled
.not_fn0:
    ; AX-based function numbers
    cmp     ax, 0x0000
    je      mouse_fn00_reset
    cmp     ax, 0x0021
    je      mouse_fn00_reset
.unhandled:
    iret

; ---------------------------------------------------------------------------
; Function 00h/21h: Reset driver and read status
; Returns: AX = FFFFh if mouse, 0 if not; BX = number of buttons
; ---------------------------------------------------------------------------
mouse_fn00_reset:
    cmp     byte [cs:mouse_present], 0
    je      .no_mouse

    ; Reset driver state
    mov     word [cs:mouse_visible], 0
    mov     word [cs:mouse_x], 320
    mov     word [cs:mouse_y], 100
    mov     word [cs:mouse_min_x], 0
    mov     word [cs:mouse_max_x], 639
    mov     word [cs:mouse_min_y], 0
    mov     word [cs:mouse_max_y], 199
    mov     word [cs:mouse_delta_x], 0
    mov     word [cs:mouse_delta_y], 0
    mov     word [cs:mouse_mickey_x], 8
    mov     word [cs:mouse_mickey_y], 16
    mov     word [cs:mouse_handler_mask], 0
    mov     word [cs:mouse_handler_off], 0
    mov     word [cs:mouse_handler_seg], 0

    ; Clear button counters
    mov     word [cs:mouse_left_press], 0
    mov     word [cs:mouse_right_press], 0
    mov     word [cs:mouse_left_rel], 0
    mov     word [cs:mouse_right_rel], 0

    ; Erase any visible cursor
    call    mouse_erase_cursor

    ; Return mouse present
    mov     ax, 0xFFFF
    mov     bx, 2                       ; 2 buttons
    iret

.no_mouse:
    xor     ax, ax
    xor     bx, bx
    iret

; ---------------------------------------------------------------------------
; Function 01h: Show mouse cursor
; ---------------------------------------------------------------------------
mouse_fn01_show:
    inc     word [cs:mouse_visible]
    cmp     word [cs:mouse_visible], 1
    jne     .done
    ; Just became visible - draw cursor
    push    ds
    push    cs
    pop     ds
    call    mouse_draw_cursor
    pop     ds
.done:
    iret

; ---------------------------------------------------------------------------
; Function 02h: Hide mouse cursor
; ---------------------------------------------------------------------------
mouse_fn02_hide:
    cmp     word [cs:mouse_visible], 0
    je      .done
    dec     word [cs:mouse_visible]
    cmp     word [cs:mouse_visible], 0
    jne     .done
    ; Just became hidden - erase cursor
    push    ds
    push    cs
    pop     ds
    call    mouse_erase_cursor
    pop     ds
.done:
    iret

; ---------------------------------------------------------------------------
; Function 03h: Get mouse position and button status
; Returns: BX = button status, CX = X, DX = Y
; ---------------------------------------------------------------------------
mouse_fn03_get_pos:
    xor     bh, bh
    mov     bl, [cs:mouse_buttons]
    mov     cx, [cs:mouse_x]
    mov     dx, [cs:mouse_y]
    iret

; ---------------------------------------------------------------------------
; Function 04h: Set mouse cursor position
; Input: CX = X, DX = Y
; ---------------------------------------------------------------------------
mouse_fn04_set_pos:
    push    ds
    push    cs
    pop     ds

    ; Clamp and set X
    cmp     cx, [mouse_min_x]
    jge     .x_ok_low
    mov     cx, [mouse_min_x]
.x_ok_low:
    cmp     cx, [mouse_max_x]
    jle     .x_ok_high
    mov     cx, [mouse_max_x]
.x_ok_high:
    mov     [mouse_x], cx

    ; Clamp and set Y
    cmp     dx, [mouse_min_y]
    jge     .y_ok_low
    mov     dx, [mouse_min_y]
.y_ok_low:
    cmp     dx, [mouse_max_y]
    jle     .y_ok_high
    mov     dx, [mouse_max_y]
.y_ok_high:
    mov     [mouse_y], dx

    ; Update cursor if visible
    cmp     word [mouse_visible], 0
    je      .done
    call    mouse_update_cursor
.done:
    pop     ds
    iret

; ---------------------------------------------------------------------------
; Function 05h: Get button press information
; Input: BX = button (0=left, 1=right)
; Returns: AX = button status, BX = press count, CX = X at last press, DX = Y
; ---------------------------------------------------------------------------
mouse_fn05_get_press:
    push    ds
    push    cs
    pop     ds

    xor     ah, ah
    mov     al, [mouse_buttons]

    cmp     bx, 0
    jne     .right_button

    ; Left button
    mov     bx, [mouse_left_press]
    mov     word [mouse_left_press], 0  ; Clear counter
    mov     cx, [mouse_left_press_x]
    mov     dx, [mouse_left_press_y]
    jmp     .done

.right_button:
    mov     bx, [mouse_right_press]
    mov     word [mouse_right_press], 0
    mov     cx, [mouse_right_press_x]
    mov     dx, [mouse_right_press_y]

.done:
    pop     ds
    iret

; ---------------------------------------------------------------------------
; Function 06h: Get button release information
; Input: BX = button (0=left, 1=right)
; Returns: AX = button status, BX = release count, CX = X at last release, DX = Y
; ---------------------------------------------------------------------------
mouse_fn06_get_release:
    push    ds
    push    cs
    pop     ds

    xor     ah, ah
    mov     al, [mouse_buttons]

    cmp     bx, 0
    jne     .right_button

    ; Left button
    mov     bx, [mouse_left_rel]
    mov     word [mouse_left_rel], 0
    mov     cx, [mouse_left_rel_x]
    mov     dx, [mouse_left_rel_y]
    jmp     .done

.right_button:
    mov     bx, [mouse_right_rel]
    mov     word [mouse_right_rel], 0
    mov     cx, [mouse_right_rel_x]
    mov     dx, [mouse_right_rel_y]

.done:
    pop     ds
    iret

; ---------------------------------------------------------------------------
; Function 07h: Set horizontal cursor range
; Input: CX = minimum X, DX = maximum X
; ---------------------------------------------------------------------------
mouse_fn07_set_horiz:
    ; Ensure min <= max
    cmp     cx, dx
    jle     .order_ok
    xchg    cx, dx
.order_ok:
    mov     [cs:mouse_min_x], cx
    mov     [cs:mouse_max_x], dx

    ; Clamp current position if needed
    mov     ax, [cs:mouse_x]
    cmp     ax, cx
    jge     .x_ok_low
    mov     [cs:mouse_x], cx
.x_ok_low:
    cmp     ax, dx
    jle     .x_ok_high
    mov     [cs:mouse_x], dx
.x_ok_high:
    iret

; ---------------------------------------------------------------------------
; Function 08h: Set vertical cursor range
; Input: CX = minimum Y, DX = maximum Y
; ---------------------------------------------------------------------------
mouse_fn08_set_vert:
    ; Ensure min <= max
    cmp     cx, dx
    jle     .order_ok
    xchg    cx, dx
.order_ok:
    mov     [cs:mouse_min_y], cx
    mov     [cs:mouse_max_y], dx

    ; Clamp current position if needed
    mov     ax, [cs:mouse_y]
    cmp     ax, cx
    jge     .y_ok_low
    mov     [cs:mouse_y], cx
.y_ok_low:
    cmp     ax, dx
    jle     .y_ok_high
    mov     [cs:mouse_y], dx
.y_ok_high:
    iret

; ---------------------------------------------------------------------------
; Function 0Bh: Read motion counters
; Returns: CX = horizontal count (mickeys), DX = vertical count
; ---------------------------------------------------------------------------
mouse_fn0B_get_motion:
    mov     cx, [cs:mouse_delta_x]
    mov     dx, [cs:mouse_delta_y]
    mov     word [cs:mouse_delta_x], 0
    mov     word [cs:mouse_delta_y], 0
    iret

; ---------------------------------------------------------------------------
; Function 0Ch: Set user-defined event handler
; Input: CX = event mask, ES:DX = handler address
; ---------------------------------------------------------------------------
mouse_fn0C_set_handler:
    mov     [cs:mouse_handler_mask], cx
    mov     [cs:mouse_handler_off], dx
    mov     [cs:mouse_handler_seg], es
    iret

; ---------------------------------------------------------------------------
; Function 0Fh: Set mickey-to-pixel ratio
; Input: CX = horizontal mickeys per 8 pixels, DX = vertical mickeys per 8 pixels
; ---------------------------------------------------------------------------
mouse_fn0F_set_ratio:
    test    cx, cx
    jz      .done                       ; Don't allow 0
    test    dx, dx
    jz      .done
    mov     [cs:mouse_mickey_x], cx
    mov     [cs:mouse_mickey_y], dx
.done:
    iret

; ---------------------------------------------------------------------------
; Messages
; ---------------------------------------------------------------------------
msg_mouse_init      db  'Initializing PS/2 mouse...', 0x0D, 0x0A, 0
msg_mouse_found     db  'PS/2 mouse detected', 0x0D, 0x0A, 0
msg_mouse_not_found db  'No PS/2 mouse found', 0x0D, 0x0A, 0

; ---------------------------------------------------------------------------
; Mouse state variables (must be at end of file, not in code path)
; ---------------------------------------------------------------------------
mouse_present       db  0           ; 1 if mouse detected and enabled
mouse_buttons       db  0           ; Current button state (bit 0=left, 1=right, 2=middle)
mouse_x             dw  320         ; Current X position (0-639 virtual pixels)
mouse_y             dw  100         ; Current Y position (0-199 virtual pixels)
mouse_min_x         dw  0           ; Horizontal minimum
mouse_max_x         dw  639         ; Horizontal maximum
mouse_min_y         dw  0           ; Vertical minimum
mouse_max_y         dw  199         ; Vertical maximum
mouse_visible       dw  0           ; Visibility counter (visible when > 0)
mouse_delta_x       dw  0           ; Motion counter X (mickeys)
mouse_delta_y       dw  0           ; Motion counter Y (mickeys)
mouse_mickey_x      dw  8           ; Mickeys per 8 pixels horizontal
mouse_mickey_y      dw  16          ; Mickeys per 8 pixels vertical

; Button press/release tracking
mouse_left_press    dw  0           ; Left button press count
mouse_left_press_x  dw  0           ; X at last left press
mouse_left_press_y  dw  0           ; Y at last left press
mouse_right_press   dw  0           ; Right button press count
mouse_right_press_x dw  0           ; X at last right press
mouse_right_press_y dw  0           ; Y at last right press
mouse_left_rel      dw  0           ; Left button release count
mouse_left_rel_x    dw  0           ; X at last left release
mouse_left_rel_y    dw  0           ; Y at last left release
mouse_right_rel     dw  0           ; Right button release count
mouse_right_rel_x   dw  0           ; X at last right release
mouse_right_rel_y   dw  0           ; Y at last right release

; Packet assembly
mouse_packet_byte   db  0           ; Current byte index (0-2)
mouse_packet        db  0, 0, 0     ; 3-byte packet buffer

; Cursor state for text mode
mouse_cursor_x      dw  0           ; Cursor character X (0-79)
mouse_cursor_y      dw  0           ; Cursor character Y (0-24)
mouse_saved_char    dw  0           ; Saved char+attr at cursor position

; User event handler
mouse_handler_mask  dw  0           ; Event mask for user handler
mouse_handler_off   dw  0           ; User handler offset
mouse_handler_seg   dw  0           ; User handler segment

; Old IRQ 12 vector
int74_old_vector    dd  0
