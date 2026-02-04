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
; INT 21h AH=01h - Character Input with Echo
; Returns: AL = character
; ---------------------------------------------------------------------------
int21_01:
    ; Wait for keypress via BIOS INT 16h
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

; ---------------------------------------------------------------------------
; INT 21h AH=02h - Character Output
; Input: DL = character to output
; ---------------------------------------------------------------------------
int21_02:
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

    ; Output character - check for bell
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

.input:
    ; Check if key available
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

; ---------------------------------------------------------------------------
; INT 21h AH=07h - Direct Input Without Echo
; Returns: AL = character
; ---------------------------------------------------------------------------
int21_07:
    xor     ah, ah
    int     0x16
    mov     byte [save_ax], al
    ret

; ---------------------------------------------------------------------------
; INT 21h AH=08h - Input Without Echo (checks Ctrl+C)
; Returns: AL = character
; ---------------------------------------------------------------------------
int21_08:
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

; ---------------------------------------------------------------------------
; INT 21h AH=09h - Print String
; Input: DS:DX = pointer to '$'-terminated string
; (Caller's DS:DX)
; ---------------------------------------------------------------------------
int21_09:
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

; ---------------------------------------------------------------------------
; INT 21h AH=0Ah - Buffered Input
; Input: DS:DX = pointer to input buffer
;   Buffer[0] = max chars, Buffer[1] = filled by DOS with count
;   Buffer[2..] = input string
; ---------------------------------------------------------------------------
int21_0A:
    push    es
    push    di

    mov     es, [save_ds]
    mov     di, [save_dx]

    xor     cl, cl              ; Character count
    mov     ch, [es:di]         ; Max characters

.input_loop:
    ; Get a keystroke
    xor     ah, ah
    int     0x16

    cmp     al, 0x0D            ; Enter?
    je      .input_done

    cmp     al, 0x08            ; Backspace?
    je      .backspace

    ; Regular character
    cmp     cl, ch              ; Buffer full?
    jae     .input_loop         ; Ignore if full

    ; Store and echo
    push    bx
    xor     bh, bh
    mov     bl, cl
    add     bl, 2               ; Skip max + count bytes
    mov     [es:di + bx], al
    pop     bx
    inc     cl

    ; Echo
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    jmp     .input_loop

.backspace:
    test    cl, cl
    jz      .input_loop         ; Nothing to delete

    dec     cl
    ; Echo backspace + space + backspace
    mov     ah, 0x0E
    xor     bx, bx
    mov     al, 0x08
    int     0x10
    mov     al, ' '
    int     0x10
    mov     al, 0x08
    int     0x10
    jmp     .input_loop

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

    ; Echo CR+LF
    mov     ah, 0x0E
    xor     bx, bx
    mov     al, 0x0D
    int     0x10
    mov     al, 0x0A
    int     0x10

    pop     di
    pop     es
    call    dos_clear_error
    ret

; ---------------------------------------------------------------------------
; INT 21h AH=0Bh - Check Input Status
; Returns: AL = 0xFF if character available, 0x00 if not
; ---------------------------------------------------------------------------
int21_0B:
    mov     ah, 0x01
    int     0x16
    jz      .no_char
    mov     byte [save_ax], 0xFF
    ret
.no_char:
    mov     byte [save_ax], 0x00
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
