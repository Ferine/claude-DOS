; ===========================================================================
; claudeDOS INT 21h Memory Functions
; ===========================================================================

; AH=48h - Allocate memory
; Input: BX = paragraphs to allocate
; Output: AX = segment of allocated block, CF on error
int21_48:
    mov     bx, [save_bx]
    call    mcb_alloc
    jc      .alloc_fail
    mov     [save_ax], ax
    call    dos_clear_error
    ret
.alloc_fail:
    mov     [save_bx], bx       ; Largest available
    mov     ax, ERR_INSUFFICIENT_MEM
    jmp     dos_set_error

; AH=49h - Free memory
; Input: ES = segment to free
int21_49:
    push    es
    mov     es, [save_es]
    call    mcb_free
    pop     es
    jc      .free_fail
    call    dos_clear_error
    ret
.free_fail:
    mov     ax, ERR_INVALID_MCB
    jmp     dos_set_error

; AH=4Ah - Resize memory block
; Input: ES = segment, BX = new size in paragraphs
int21_4A:
    ; Debug: print resize attempt
    cmp     byte [cs:debug_trace], 0
    je      .skip_4A_trace
    push    ax
    push    bx
    mov     al, '<'
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    mov     al, '4'
    int     0x10
    mov     al, 'A'
    int     0x10
    mov     al, ':'
    int     0x10
    ; Print ES (segment being resized)
    mov     ax, [cs:save_es]
    call    .print_hex_word
    mov     al, ','
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    ; Print BX (requested size)
    mov     ax, [cs:save_bx]
    call    .print_hex_word
    mov     al, '>'
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    pop     bx
    pop     ax
.skip_4A_trace:

    push    es
    mov     es, [save_es]
    mov     bx, [save_bx]
    call    mcb_resize
    pop     es
    jc      .resize_fail

    ; Debug: print resize success
    cmp     byte [cs:debug_trace], 0
    je      .skip_4A_ok
    push    ax
    push    bx
    mov     al, '='
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    mov     al, 'O'
    int     0x10
    mov     al, 'K'
    int     0x10
    pop     bx
    pop     ax
.skip_4A_ok:

    call    dos_clear_error
    ret
.resize_fail:
    ; Debug: print resize failure
    cmp     byte [cs:debug_trace], 0
    je      .skip_4A_fail
    push    ax
    push    bx
    mov     al, '='
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    mov     al, 'F'
    int     0x10
    mov     al, 'A'
    int     0x10
    mov     al, 'I'
    int     0x10
    mov     al, 'L'
    int     0x10
    pop     bx
    pop     ax
.skip_4A_fail:
    mov     [save_bx], bx           ; Max available
    mov     ax, ERR_INSUFFICIENT_MEM
    jmp     dos_set_error

; Helper to print AX as hex word
.print_hex_word:
    push    ax
    push    bx
    push    cx
    mov     cx, 4           ; 4 hex digits
.phw_loop:
    rol     ax, 4           ; Rotate high nibble to low
    push    ax
    and     al, 0x0F
    add     al, '0'
    cmp     al, '9'
    jbe     .phw_print
    add     al, 7
.phw_print:
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    pop     ax
    loop    .phw_loop
    pop     cx
    pop     bx
    pop     ax
    ret

; AH=58h - Get/Set allocation strategy
int21_58:
    mov     al, [save_ax]        ; AL = subfunction
    test    al, al
    jz      .get_strategy
    cmp     al, 1
    je      .set_strategy
    
    mov     ax, ERR_INVALID_FUNC
    jmp     dos_set_error

.get_strategy:
    xor     ah, ah
    mov     al, [alloc_strategy]
    mov     [save_ax], ax
    call    dos_clear_error
    ret

.set_strategy:
    mov     al, [save_bx]
    mov     [alloc_strategy], al
    call    dos_clear_error
    ret
