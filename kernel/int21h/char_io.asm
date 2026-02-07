; ===========================================================================
; claudeDOS INT 21h Character I/O Functions (AH=00h-0Ch, 19h, 1Ah, 2Fh)
; ===========================================================================

; ---------------------------------------------------------------------------
; INT 21h AH=00h - Terminate Program
; ---------------------------------------------------------------------------
int21_00:
    ; Simple terminate - return to parent
    ; Full implementation in process.asm (Phase 5)
    mov     si, msg_terminate
    call    bios_print_string
    ; For now, just halt
    cli
    hlt
    ret

; ---------------------------------------------------------------------------
; Redirection helpers - check if stdout/stdin is redirected to a file
; These call handle_to_sft and check bit 15 of SFT flags.
; Bit 15 set = character device, bit 15 clear = disk file (redirected)
; Output: CF set = redirected to file, CF clear = device
; Preserves: all registers except flags
; ---------------------------------------------------------------------------
check_stdout_redirected:
    push    ax
    push    bx
    push    di
    mov     bx, STDOUT
    call    handle_to_sft
    jc      .stdout_is_device       ; Invalid handle - treat as device
    test    word [di + SFT_ENTRY.flags], 0x8000
    jnz     .stdout_is_device       ; Bit 15 set = device
    ; Bit 15 clear = file (redirected)
    pop     di
    pop     bx
    pop     ax
    stc
    ret
.stdout_is_device:
    pop     di
    pop     bx
    pop     ax
    clc
    ret

check_stdin_redirected:
    push    ax
    push    bx
    push    di
    mov     bx, STDIN
    call    handle_to_sft
    jc      .stdin_is_device        ; Invalid handle - treat as device
    test    word [di + SFT_ENTRY.flags], 0x8000
    jnz     .stdin_is_device        ; Bit 15 set = device
    ; Bit 15 clear = file (redirected)
    pop     di
    pop     bx
    pop     ax
    stc
    ret
.stdin_is_device:
    pop     di
    pop     bx
    pop     ax
    clc
    ret

; ---------------------------------------------------------------------------
; char_write_to_handle - Write 1 byte to STDOUT via int21_40
; Input: AL = byte to write
; Preserves all save_* values except save_ax (set to bytes written)
; ---------------------------------------------------------------------------
char_write_to_handle:
    push    ax
    ; Save caller's save_* values
    push    word [save_bx]
    push    word [save_cx]
    push    word [save_dx]
    push    word [save_ds]

    ; Store the byte in a temp buffer
    mov     [.cw_byte], al

    ; Set up for int21_40: BX=STDOUT, CX=1, DS:DX=.cw_byte
    mov     word [save_bx], STDOUT
    mov     word [save_cx], 1
    mov     word [save_dx], .cw_byte
    mov     word [save_ds], cs
    call    int21_40

    ; Restore caller's save_* values
    pop     word [save_ds]
    pop     word [save_dx]
    pop     word [save_cx]
    pop     word [save_bx]
    pop     ax
    ret

.cw_byte    db  0

; ---------------------------------------------------------------------------
; char_read_from_handle - Read 1 byte from STDIN via int21_3F
; Output: AL = byte read, CF set if 0 bytes read (EOF)
; ---------------------------------------------------------------------------
char_read_from_handle:
    ; Save caller's save_* values
    push    word [save_bx]
    push    word [save_cx]
    push    word [save_dx]
    push    word [save_ds]

    ; Set up for int21_3F: BX=STDIN, CX=1, DS:DX=.cr_byte
    mov     word [save_bx], STDIN
    mov     word [save_cx], 1
    mov     word [save_dx], .cr_byte
    mov     word [save_ds], cs
    call    int21_3F

    ; Restore caller's save_* values
    pop     word [save_ds]
    pop     word [save_dx]
    pop     word [save_cx]
    pop     word [save_bx]

    ; Check if we got 0 bytes (EOF)
    cmp     word [save_ax], 0
    je      .cr_eof
    mov     al, [.cr_byte]
    clc
    ret
.cr_eof:
    xor     al, al
    stc
    ret

.cr_byte    db  0

; ---------------------------------------------------------------------------
; INT 21h AH=01h - Character Input with Echo
; Returns: AL = character
; ---------------------------------------------------------------------------
int21_01:
    call    check_stdin_redirected
    jc      .redir_input

    ; Device: Wait for keypress via BIOS INT 16h
    xor     ah, ah
    int     0x16                ; AH=scancode, AL=ASCII
    ; Echo to screen
    push    ax
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    pop     ax
    ; Return character in AL (via save area)
    mov     byte [save_ax], al
    call    dos_clear_error
    ret

.redir_input:
    ; Redirected: read 1 byte from handle, no echo (standard DOS behavior)
    call    char_read_from_handle
    jc      .redir_eof
    mov     byte [save_ax], al
    call    dos_clear_error
    ret
.redir_eof:
    ; Return Ctrl+Z (0x1A) on EOF
    mov     byte [save_ax], 0x1A
    call    dos_clear_error
    ret

; ---------------------------------------------------------------------------
; INT 21h AH=02h - Character Output
; Input: DL = character to output
; ---------------------------------------------------------------------------
int21_02:
    call    check_stdout_redirected
    jc      .redir_output

    ; Device: output via BIOS
    mov     al, [save_dx]       ; DL from caller
    cmp     al, BEL_CHAR        ; Check for bell character
    jne     .normal_output
    call    speaker_beep        ; Sound the beeper
    jmp     .done
.normal_output:
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
.done:
    ; Return character in AL
    mov     al, [save_dx]
    mov     byte [save_ax], al
    call    dos_clear_error
    ret

.redir_output:
    ; Redirected: write 1 byte via int21_40
    mov     al, [save_dx]
    call    char_write_to_handle
    mov     al, [save_dx]
    mov     byte [save_ax], al
    call    dos_clear_error
    ret

; ---------------------------------------------------------------------------
; INT 21h AH=03h - Auxiliary Input (stub)
; ---------------------------------------------------------------------------
int21_03:
    mov     byte [save_ax], 0
    ret

; ---------------------------------------------------------------------------
; INT 21h AH=04h - Auxiliary Output (stub)
; ---------------------------------------------------------------------------
int21_04:
    ret

; ---------------------------------------------------------------------------
; INT 21h AH=05h - Printer Output (stub)
; ---------------------------------------------------------------------------
int21_05:
    ret

; ---------------------------------------------------------------------------
; INT 21h AH=06h - Direct Console I/O
; Input: DL = character (if DL != 0xFF) or request input (DL = 0xFF)
; Output: AL = character (if input), ZF set if no char available
; ---------------------------------------------------------------------------
int21_06:
    mov     al, [save_dx]       ; DL
    cmp     al, 0xFF
    je      .input

    ; Output mode
    call    check_stdout_redirected
    jc      .output_redir

    ; Device output - check for bell
    mov     al, [save_dx]       ; Reload AL (clobbered by check)
    cmp     al, BEL_CHAR
    jne     .output_char
    call    speaker_beep
    jmp     .output_done
.output_char:
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
.output_done:
    mov     al, [save_dx]
    mov     byte [save_ax], al
    ret

.output_redir:
    ; Redirected output
    mov     al, [save_dx]
    call    char_write_to_handle
    mov     al, [save_dx]
    mov     byte [save_ax], al
    ret

.input:
    call    check_stdin_redirected
    jc      .input_redir

    ; Device input: Check if key available
    mov     ah, 0x01
    int     0x16
    jz      .no_key

    ; Key available - read it
    xor     ah, ah
    int     0x16
    mov     byte [save_ax], al
    ; Clear ZF to indicate character available (set via flags)
    call    dos_clear_error
    ret

.no_key:
    mov     byte [save_ax], 0
    ; ZF is already set from the INT 16h check
    call    dos_clear_error
    ret

.input_redir:
    ; Redirected input: read 1 byte
    call    char_read_from_handle
    jc      .input_redir_eof
    mov     byte [save_ax], al
    call    dos_clear_error
    ret
.input_redir_eof:
    mov     byte [save_ax], 0
    ; Set ZF to indicate no character
    call    dos_clear_error
    ret

; ---------------------------------------------------------------------------
; INT 21h AH=07h - Direct Input Without Echo
; Returns: AL = character
; ---------------------------------------------------------------------------
int21_07:
    call    check_stdin_redirected
    jc      .redir

    xor     ah, ah
    int     0x16
    mov     byte [save_ax], al
    ret

.redir:
    call    char_read_from_handle
    jc      .redir_eof
    mov     byte [save_ax], al
    ret
.redir_eof:
    mov     byte [save_ax], 0x1A    ; Ctrl+Z on EOF
    ret

; ---------------------------------------------------------------------------
; INT 21h AH=08h - Input Without Echo (checks Ctrl+C)
; Returns: AL = character
; ---------------------------------------------------------------------------
int21_08:
    call    check_stdin_redirected
    jc      .redir

    xor     ah, ah
    int     0x16
    cmp     al, 0x03            ; Ctrl+C?
    je      .ctrl_c
    mov     byte [save_ax], al
    ret
.ctrl_c:
    ; INT 23h - Ctrl+C handler
    int     0x23
    jmp     int21_08            ; Retry

.redir:
    call    char_read_from_handle
    jc      .redir_eof
    cmp     al, 0x03            ; Ctrl+C in redirected input?
    je      .redir_ctrl_c
    mov     byte [save_ax], al
    ret
.redir_ctrl_c:
    int     0x23
    jmp     .redir              ; Retry read
.redir_eof:
    mov     byte [save_ax], 0x1A    ; Ctrl+Z on EOF
    ret

; ---------------------------------------------------------------------------
; INT 21h AH=09h - Print String
; Input: DS:DX = pointer to '$'-terminated string
; (Caller's DS:DX)
; ---------------------------------------------------------------------------
int21_09:
    call    check_stdout_redirected
    jc      .redir_print

    ; Device: output via BIOS
    push    es
    push    si

    mov     es, [save_ds]       ; Get caller's DS
    mov     si, [save_dx]       ; Get caller's DX

    xor     bx, bx
.print_loop:
    mov     al, [es:si]
    cmp     al, '$'
    je      .print_done
    cmp     al, BEL_CHAR        ; Check for bell character
    jne     .print_char
    call    speaker_beep        ; Sound the beeper
    jmp     .print_next
.print_char:
    mov     ah, 0x0E
    int     0x10
.print_next:
    inc     si
    jmp     .print_loop
.print_done:
    pop     si
    pop     es
    call    dos_clear_error
    ret

.redir_print:
    ; Redirected: count chars to '$', then write via int21_40
    push    es
    push    si
    push    cx

    mov     es, [save_ds]
    mov     si, [save_dx]

    ; Count characters up to '$'
    xor     cx, cx
.count_loop:
    mov     al, [es:si]
    cmp     al, '$'
    je      .count_done
    inc     si
    inc     cx
    jmp     .count_loop
.count_done:
    ; CX = number of bytes to write
    test    cx, cx
    jz      .redir_print_done

    ; Save and set up for int21_40
    push    word [save_bx]
    push    word [save_cx]
    ; save_ds and save_dx already point to the string

    mov     word [save_bx], STDOUT
    mov     [save_cx], cx
    call    int21_40

    pop     word [save_cx]
    pop     word [save_bx]

.redir_print_done:
    pop     cx
    pop     si
    pop     es
    call    dos_clear_error
    ret

; ---------------------------------------------------------------------------
; INT 21h AH=0Ah - Buffered Input with Line Editing
; Input: DS:DX = pointer to input buffer
;   Buffer[0] = max chars, Buffer[1] = filled by DOS with count
;   Buffer[2..] = input string
;
; Supports: Backspace, Delete, Left/Right arrows, Home, End, Escape
; ---------------------------------------------------------------------------
int21_0A:
    push    es
    push    di
    push    bp

    mov     es, [save_ds]
    mov     di, [save_dx]

    xor     cl, cl              ; CL = total length of text in buffer
    xor     dl, dl              ; DL = cursor position (offset within buffer)
    mov     ch, [es:di]         ; CH = max characters

.input_loop:
    ; Get a keystroke via BIOS
    xor     ah, ah
    int     0x16
    ; AL = ASCII code (0 if extended key), AH = scan code

    ; Check for Enter
    cmp     al, 0x0D
    je      .input_done

    ; Check for Escape
    cmp     al, 0x1B
    je      .escape

    ; Check for Backspace
    cmp     al, 0x08
    je      .backspace

    ; Check for extended key (AL=0 means scan code in AH)
    test    al, al
    jz      .extended_key

    ; Printable character (AL >= 32)
    cmp     al, 32
    jb      .input_loop         ; Ignore other control chars

    ; --- Insert printable character at cursor position ---
    cmp     cl, ch              ; Buffer full?
    jae     .input_loop         ; Ignore if full

    ; Shift buffer right from cursor to end to make room
    push    ax                  ; Save the character to insert
    push    cx

    ; Move bytes from position [cursor..length-1] one position right
    ; Start from the end and work backwards
    mov     bp, cx              ; BP = current length (loop counter source)
    and     bp, 0x00FF          ; Clear high byte
    xor     dh, dh
    mov     bx, dx              ; BL = cursor pos
    and     bx, 0x00FF
.shift_right:
    cmp     bp, bx              ; Reached cursor position?
    jbe     .shift_right_done
    ; Move byte at [bp-1] to [bp]
    push    bx
    mov     bx, bp
    add     bx, 2               ; Account for buffer header
    mov     al, [es:di + bx - 1]
    mov     [es:di + bx], al
    pop     bx
    dec     bp
    jmp     .shift_right
.shift_right_done:
    pop     cx
    pop     ax                  ; Restore character

    ; Store character at cursor position
    push    bx
    xor     bh, bh
    mov     bl, dl              ; Cursor position
    add     bl, 2
    mov     [es:di + bx], al
    pop     bx

    inc     cl                  ; Increment length
    inc     dl                  ; Advance cursor

    ; If appending at end (cursor == length), just echo the character
    cmp     dl, cl
    jne     .insert_middle
    ; Simple append - echo char directly
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    jmp     .input_loop
.insert_middle:
    ; Redraw from cursor-1 position to end, then reposition cursor
    call    .redraw_from_cursor_minus1
    jmp     .input_loop

.backspace:
    ; Delete character before cursor
    test    dl, dl
    jz      .input_loop         ; At start - nothing to delete

    dec     dl                  ; Move buffer cursor left
    ; Move visual cursor left
    push    ax
    push    bx
    mov     ah, 0x0E
    xor     bx, bx
    mov     al, 0x08
    int     0x10
    pop     bx
    pop     ax
    ; Fall through to delete-at-cursor logic

.delete_at_cursor:
    ; Delete the character at current cursor position
    ; Shift buffer left from cursor+1..length to cursor..length-1
    cmp     dl, cl
    jae     .input_loop         ; Cursor at or past end - nothing to delete

    push    cx
    xor     dh, dh
    mov     bp, dx              ; BP = cursor position
    and     bp, 0x00FF
    mov     bx, cx
    and     bx, 0x00FF          ; BX = length
.shift_left:
    inc     bp
    cmp     bp, bx              ; Past end?
    jae     .shift_left_done
    ; Move byte at [bp] to [bp-1]
    push    bx
    mov     bx, bp
    add     bx, 2
    mov     al, [es:di + bx]
    mov     [es:di + bx - 1], al
    pop     bx
    jmp     .shift_left
.shift_left_done:
    pop     cx
    dec     cl                  ; Decrement length

    ; If cursor is now at end (deleted last char), simple erase
    cmp     dl, cl
    jne     .delete_middle
    ; Erase: print space then backspace
    push    bx
    mov     ah, 0x0E
    xor     bx, bx
    mov     al, ' '
    int     0x10
    mov     al, 0x08
    int     0x10
    pop     bx
    jmp     .input_loop
.delete_middle:
    ; Redraw the line from cursor position onward
    call    .redraw_from_cursor
    jmp     .input_loop

.escape:
    ; Clear the entire line
    ; First move cursor to start visually
    call    .visual_move_to_start
    ; Print spaces to erase the entire line
    push    cx
    xor     bh, bh
    mov     al, ' '
    mov     ah, 0x0E
    xor     ch, ch
    mov     bp, cx              ; BP = length
    and     bp, 0x00FF
.erase_loop:
    test    bp, bp
    jz      .erase_done
    int     0x10
    dec     bp
    jmp     .erase_loop
.erase_done:
    pop     cx
    ; Move cursor back to start
    push    cx
    xor     ch, ch
    mov     bp, cx
    and     bp, 0x00FF
    mov     al, 0x08
    mov     ah, 0x0E
    xor     bx, bx
.back_loop:
    test    bp, bp
    jz      .back_done
    int     0x10
    dec     bp
    jmp     .back_loop
.back_done:
    pop     cx
    ; Reset length and cursor
    xor     cl, cl
    xor     dl, dl
    jmp     .input_loop

.extended_key:
    ; AH has the scan code
    cmp     ah, 0x4B            ; Left arrow
    je      .left_arrow
    cmp     ah, 0x4D            ; Right arrow
    je      .right_arrow
    cmp     ah, 0x47            ; Home
    je      .home
    cmp     ah, 0x4F            ; End
    je      .end_key
    cmp     ah, 0x53            ; Delete
    je      .delete_key
    jmp     .input_loop         ; Ignore other extended keys

.left_arrow:
    test    dl, dl
    jz      .input_loop         ; Already at start
    dec     dl
    ; Move cursor left visually
    mov     ah, 0x0E
    xor     bx, bx
    mov     al, 0x08
    int     0x10
    jmp     .input_loop

.right_arrow:
    cmp     dl, cl              ; At end of text?
    jae     .input_loop         ; Can't go past end
    ; Move cursor right visually - print the character under cursor
    push    bx
    xor     bh, bh
    mov     bl, dl
    add     bl, 2
    mov     al, [es:di + bx]
    pop     bx
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    inc     dl
    jmp     .input_loop

.home:
    call    .visual_move_to_start
    xor     dl, dl
    jmp     .input_loop

.end_key:
    ; Print characters from cursor to end to move cursor right
    push    cx
    xor     dh, dh
    mov     bp, dx
    and     bp, 0x00FF          ; BP = current cursor pos
    mov     bx, cx
    and     bx, 0x00FF          ; BX = length
.end_loop:
    cmp     bp, bx
    jae     .end_done
    push    bx
    mov     bx, bp
    add     bx, 2
    mov     al, [es:di + bx]
    pop     bx
    push    bx
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    pop     bx
    inc     bp
    jmp     .end_loop
.end_done:
    pop     cx
    mov     dl, cl              ; Cursor at end
    jmp     .input_loop

.delete_key:
    jmp     .delete_at_cursor

.input_done:
    ; Store count
    mov     [es:di + 1], cl

    ; Add CR to buffer
    push    bx
    xor     bh, bh
    mov     bl, cl
    add     bl, 2
    mov     byte [es:di + bx], 0x0D
    pop     bx

    pop     bp
    pop     di
    pop     es
    call    dos_clear_error
    ret

; --- Helper: move visual cursor to start of input ---
.visual_move_to_start:
    push    cx
    push    dx
    xor     dh, dh
    mov     bp, dx
    and     bp, 0x00FF
    mov     ah, 0x0E
    xor     bx, bx
    mov     al, 0x08
.vms_loop:
    test    bp, bp
    jz      .vms_done
    int     0x10
    dec     bp
    jmp     .vms_loop
.vms_done:
    pop     dx
    pop     cx
    ret

; --- Helper: redraw from (cursor-1) position to end, reposition cursor ---
; Used after inserting a character (cursor already advanced)
.redraw_from_cursor_minus1:
    push    cx
    push    dx
    ; Move visual cursor back one position
    mov     ah, 0x0E
    xor     bx, bx
    mov     al, 0x08
    int     0x10
    ; Print from cursor-1 to end of buffer
    xor     dh, dh
    mov     bp, dx
    and     bp, 0x00FF
    dec     bp                  ; Start from cursor-1
    mov     bx, cx
    and     bx, 0x00FF          ; BX = length
.rfcm1_print:
    cmp     bp, bx
    jae     .rfcm1_trail
    push    bx
    mov     bx, bp
    add     bx, 2
    mov     al, [es:di + bx]
    pop     bx
    push    bx
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    pop     bx
    inc     bp
    jmp     .rfcm1_print
.rfcm1_trail:
    ; Print one space to erase any leftover character
    push    bx
    mov     ah, 0x0E
    xor     bx, bx
    mov     al, ' '
    int     0x10
    pop     bx
    ; Now move cursor back to correct position
    ; Current visual pos is at (length + 1), need to be at cursor (dl)
    ; Move back (length + 1 - cursor) positions
    mov     bp, cx
    and     bp, 0x00FF
    inc     bp                  ; +1 for the trailing space
    xor     dh, dh
    push    dx
    mov     bx, dx
    and     bx, 0x00FF
    sub     bp, bx              ; BP = distance to move back
    mov     ah, 0x0E
    xor     bx, bx
    mov     al, 0x08
.rfcm1_back:
    test    bp, bp
    jz      .rfcm1_done
    int     0x10
    dec     bp
    jmp     .rfcm1_back
.rfcm1_done:
    pop     dx
    pop     dx
    pop     cx
    ret

; --- Helper: redraw from cursor position to end, reposition cursor ---
; Used after deleting a character
.redraw_from_cursor:
    push    cx
    push    dx
    ; Print from cursor to end of buffer
    xor     dh, dh
    mov     bp, dx
    and     bp, 0x00FF
    mov     bx, cx
    and     bx, 0x00FF          ; BX = new length
.rfc_print:
    cmp     bp, bx
    jae     .rfc_trail
    push    bx
    mov     bx, bp
    add     bx, 2
    mov     al, [es:di + bx]
    pop     bx
    push    bx
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    pop     bx
    inc     bp
    jmp     .rfc_print
.rfc_trail:
    ; Print one space to erase the old last character
    push    bx
    mov     ah, 0x0E
    xor     bx, bx
    mov     al, ' '
    int     0x10
    pop     bx
    ; Move cursor back to correct position
    ; Visual pos is at (length + 1), need cursor at dl
    mov     bp, cx
    and     bp, 0x00FF
    inc     bp
    xor     dh, dh
    push    dx
    mov     bx, dx
    and     bx, 0x00FF
    sub     bp, bx
    mov     ah, 0x0E
    xor     bx, bx
    mov     al, 0x08
.rfc_back:
    test    bp, bp
    jz      .rfc_done
    int     0x10
    dec     bp
    jmp     .rfc_back
.rfc_done:
    pop     dx
    pop     dx
    pop     cx
    ret

; ---------------------------------------------------------------------------
; INT 21h AH=0Bh - Check Input Status
; Returns: AL = 0xFF if character available, 0x00 if not
; ---------------------------------------------------------------------------
int21_0B:
    call    check_stdin_redirected
    jc      .redir

    mov     ah, 0x01
    int     0x16
    jz      .no_char
    mov     byte [save_ax], 0xFF
    ret
.no_char:
    mov     byte [save_ax], 0x00
    ret

.redir:
    ; Redirected stdin: always return 0xFF (ready)
    ; Caller handles EOF when read returns 0 bytes
    mov     byte [save_ax], 0xFF
    ret

; ---------------------------------------------------------------------------
; INT 21h AH=0Ch - Flush Buffer and Input
; Input: AL = input function to call (01h, 06h, 07h, 08h, 0Ah)
; ---------------------------------------------------------------------------
int21_0C:
    ; Flush keyboard buffer
    mov     ax, 0x0C00          ; INT 21h AH=0Ch, AL=00 flush
    ; Actually, flush by reading all available keys
.flush_loop:
    mov     ah, 0x01
    int     0x16
    jz      .flush_done
    xor     ah, ah
    int     0x16                ; Consume the key
    jmp     .flush_loop
.flush_done:
    ; Now call the specified input function
    mov     al, [save_ax]       ; AL = subfunciton
    cmp     al, 0x01
    je      int21_01
    cmp     al, 0x06
    je      int21_06
    cmp     al, 0x07
    je      int21_07
    cmp     al, 0x08
    je      int21_08
    cmp     al, 0x0A
    je      int21_0A
    ret

; ---------------------------------------------------------------------------
; INT 21h AH=19h - Get Current Default Drive
; Returns: AL = drive number (0=A:, 1=B:, etc)
; ---------------------------------------------------------------------------
int21_19:
    mov     al, [current_drive]
    mov     byte [save_ax], al
    call    dos_clear_error
    ret

; ---------------------------------------------------------------------------
; INT 21h AH=1Ah - Set DTA Address
; Input: DS:DX = new DTA address
; ---------------------------------------------------------------------------
int21_1A:
    mov     ax, [save_ds]
    mov     [current_dta_seg], ax
    mov     ax, [save_dx]
    mov     [current_dta_off], ax
    call    dos_clear_error
    ret

; ---------------------------------------------------------------------------
; INT 21h AH=2Fh - Get DTA Address
; Returns: ES:BX = current DTA address
; ---------------------------------------------------------------------------
int21_2F:
    mov     ax, [current_dta_seg]
    mov     [save_es], ax
    mov     ax, [current_dta_off]
    mov     [save_bx], ax
    call    dos_clear_error
    ret

; ---------------------------------------------------------------------------
; speaker_beep - Sound the PC speaker with a short beep
; Preserves all registers
; ---------------------------------------------------------------------------
speaker_beep:
    push    ax
    push    bx
    push    cx

    ; Program PIT timer channel 2 for square wave
    mov     al, 0xB6                ; Channel 2, lobyte/hibyte, mode 3
    out     0x43, al

    ; Set frequency to 880 Hz (divisor = 1193182/880 = 1355 = 0x054B)
    mov     al, 0x4B                ; Low byte
    out     0x42, al
    mov     al, 0x05                ; High byte
    out     0x42, al

    ; Read current port 61h state, enable speaker
    in      al, 0x61
    mov     ah, al                  ; Save original in AH
    or      al, 0x03                ; Set bits 0,1: timer gate + speaker enable
    out     0x61, al

    ; Delay using timer ticks (read port 0x40 for timing)
    mov     bx, 5                   ; Number of 55ms ticks (~275ms total)
.wait_tick:
    ; Wait for timer channel 0 to wrap (reads decrement)
    mov     cx, 0xFFFF
.inner_delay:
    in      al, 0x40                ; Read timer - adds delay
    loop    .inner_delay
    dec     bx
    jnz     .wait_tick

    ; Restore port 61h (disable speaker)
    mov     al, ah
    out     0x61, al

    pop     cx
    pop     bx
    pop     ax
    ret

; ---------------------------------------------------------------------------
msg_terminate   db  'Program terminated.', 0x0D, 0x0A, 0
