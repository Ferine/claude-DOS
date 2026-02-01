; ===========================================================================
; claudeDOS Command Line Parser
; ===========================================================================

; ---------------------------------------------------------------------------
; parse_filename - Extract filename from command arguments
; Input: DS:SI = argument string
; Output: DS:DX = ASCIIZ filename, SI advanced past filename
; ---------------------------------------------------------------------------
parse_filename:
    mov     dx, si              ; DX points to start of filename
    ; Advance SI to next space or end
.scan:
    lodsb
    cmp     al, ' '
    je      .done
    cmp     al, 0
    je      .end
    cmp     al, 0x0D
    je      .end
    jmp     .scan
.done:
    mov     byte [si - 1], 0    ; Null-terminate filename
    ret
.end:
    dec     si                  ; Back up to the null/CR
    ret

; ---------------------------------------------------------------------------
; print_string_azn - Print ASCIIZ string at DS:DX
; ---------------------------------------------------------------------------
print_asciiz:
    pusha
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
    popa
    ret

; ---------------------------------------------------------------------------
; print_crlf - Print CR+LF
; ---------------------------------------------------------------------------
print_crlf:
    push    ax
    push    dx
    mov     ah, 0x02
    mov     dl, 0x0D
    int     0x21
    mov     dl, 0x0A
    int     0x21
    pop     dx
    pop     ax
    ret

; ---------------------------------------------------------------------------
; print_dec16 - Print 16-bit unsigned decimal number
; Input: AX = number
; ---------------------------------------------------------------------------
print_dec16:
    pusha
    xor     cx, cx              ; Digit count
    mov     bx, 10
.divide:
    xor     dx, dx
    div     bx
    push    dx                  ; Save remainder
    inc     cx
    test    ax, ax
    jnz     .divide
.output:
    pop     dx
    add     dl, '0'
    mov     ah, 0x02
    int     0x21
    loop    .output
    popa
    ret

; ---------------------------------------------------------------------------
; print_dec32 - Print 32-bit unsigned decimal number
; Input: DX:AX = number (DX=high, AX=low)
; ---------------------------------------------------------------------------
print_dec32:
    pusha
    mov     [.num_lo], ax
    mov     [.num_hi], dx

    ; Check for zero
    or      ax, dx
    jnz     .not_zero
    mov     dl, '0'
    mov     ah, 0x02
    int     0x21
    jmp     .done

.not_zero:
    xor     cx, cx              ; Digit count

.convert_loop:
    ; Divide 32-bit number by 10
    mov     ax, [.num_hi]
    xor     dx, dx
    mov     bx, 10
    div     bx                  ; AX = high/10, DX = high%10
    mov     [.num_hi], ax
    mov     ax, [.num_lo]
    div     bx                  ; AX = result low, DX = remainder
    mov     [.num_lo], ax

    add     dl, '0'
    push    dx
    inc     cx

    ; Continue if number != 0
    mov     ax, [.num_lo]
    or      ax, [.num_hi]
    jnz     .convert_loop

    ; Print digits (in reverse order)
.print_digits:
    pop     dx
    mov     ah, 0x02
    int     0x21
    loop    .print_digits

.done:
    popa
    ret

.num_lo dw 0
.num_hi dw 0

; ---------------------------------------------------------------------------
; str_upper - Convert string at DS:SI to uppercase (in place)
; ---------------------------------------------------------------------------
str_upper:
    push    si
    push    ax
.loop:
    lodsb
    test    al, al
    jz      .done
    cmp     al, 'a'
    jb      .loop
    cmp     al, 'z'
    ja      .loop
    sub     byte [si - 1], 0x20
    jmp     .loop
.done:
    pop     ax
    pop     si
    ret
