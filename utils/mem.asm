; ===========================================================================
; MEM.COM - Display comprehensive memory information
; ===========================================================================
; Shows:
;   - Conventional memory (total, used, free)
;   - Memory Control Block (MCB) chain
;   - Extended memory (XMS) if available
;   - Largest executable program size
; ===========================================================================
    CPU     186
    ORG     0x0100

start:
    ; Print header
    mov     dx, msg_header
    call    print_string

    ; === CONVENTIONAL MEMORY ===
    mov     dx, msg_conv_header
    call    print_string

    ; Get total conventional memory from BIOS
    int     0x12                    ; AX = KB
    mov     [total_conv_kb], ax
    push    ax

    ; Total conventional
    mov     dx, msg_total
    call    print_string
    pop     ax
    call    print_dec_kb

    ; Walk MCB chain to calculate used/free
    call    walk_mcb_chain

    ; Used conventional
    mov     dx, msg_used
    call    print_string
    mov     ax, [used_conv_kb]
    call    print_dec_kb

    ; Free conventional
    mov     dx, msg_free
    call    print_string
    mov     ax, [free_conv_kb]
    call    print_dec_kb

    ; Largest free block
    mov     dx, msg_largest
    call    print_string
    mov     ax, [largest_free_kb]
    call    print_dec_kb

    ; === EXTENDED MEMORY (XMS) ===
    call    check_xms
    test    ax, ax
    jz      .no_xms

    mov     dx, msg_xms_header
    call    print_string

    ; Get XMS version
    mov     ah, 0x00
    call    far [xms_entry]
    push    ax                      ; Save version

    ; XMS version
    mov     dx, msg_xms_ver
    call    print_string
    pop     ax
    push    ax
    mov     al, ah                  ; Major version
    xor     ah, ah
    call    print_dec
    mov     dl, '.'
    mov     ah, 0x02
    int     0x21
    pop     ax
    xor     ah, ah                  ; Minor version
    call    print_dec
    mov     dx, msg_crlf
    call    print_string

    ; Query free XMS memory
    mov     ah, 0x08
    call    far [xms_entry]
    ; AX = largest free block in KB, DX = total free KB
    mov     [xms_largest_kb], ax
    mov     [xms_free_kb], dx

    ; Total XMS
    mov     dx, msg_xms_total
    call    print_string
    mov     ax, [xms_free_kb]
    call    print_dec_kb

    ; Largest XMS block
    mov     dx, msg_xms_largest
    call    print_string
    mov     ax, [xms_largest_kb]
    call    print_dec_kb

    jmp     .show_mcb_detail

.no_xms:
    mov     dx, msg_no_xms
    call    print_string

.show_mcb_detail:
    ; === MCB CHAIN DETAIL ===
    mov     dx, msg_mcb_header
    call    print_string
    call    print_mcb_chain

    ; === DOS VERSION ===
    mov     dx, msg_dosver
    call    print_string
    mov     ah, 0x30
    int     0x21
    push    ax
    xor     ah, ah
    call    print_dec
    mov     dl, '.'
    mov     ah, 0x02
    int     0x21
    pop     ax
    mov     al, ah
    xor     ah, ah
    call    print_dec
    mov     dx, msg_crlf
    call    print_string

    ; Exit
    mov     ax, 0x4C00
    int     0x21

; ---------------------------------------------------------------------------
; walk_mcb_chain - Walk MCB chain and calculate memory usage
; Sets: used_conv_kb, free_conv_kb, largest_free_kb
; ---------------------------------------------------------------------------
walk_mcb_chain:
    push    ax
    push    bx
    push    cx
    push    dx
    push    es

    ; Get first MCB segment via undocumented INT 21h AH=52h
    mov     ah, 0x52
    int     0x21                    ; ES:BX = DOS List of Lists
    mov     ax, [es:bx-2]           ; First MCB segment
    mov     [first_mcb], ax

    xor     cx, cx                  ; CX = total used paragraphs
    xor     dx, dx                  ; DX = total free paragraphs
    xor     si, si                  ; SI = largest free block

.walk_loop:
    mov     es, ax

    ; Check signature
    mov     bl, [es:0]
    cmp     bl, 'M'
    je      .valid_mcb
    cmp     bl, 'Z'
    je      .valid_mcb
    jmp     .walk_done              ; Invalid MCB, stop

.valid_mcb:
    mov     bx, [es:3]              ; BX = block size in paragraphs

    ; Check if free or used
    cmp     word [es:1], 0
    je      .is_free

    ; Used block
    add     cx, bx
    inc     cx                      ; +1 for MCB header
    jmp     .next_mcb

.is_free:
    ; Free block
    add     dx, bx
    inc     dx                      ; +1 for MCB header
    cmp     bx, si
    jbe     .next_mcb
    mov     si, bx                  ; New largest free

.next_mcb:
    cmp     byte [es:0], 'Z'
    je      .walk_done

    ; Next MCB = current + 1 + size
    mov     bx, [es:3]
    inc     bx
    add     ax, bx
    jmp     .walk_loop

.walk_done:
    ; Convert paragraphs to KB (paragraphs / 64)
    mov     ax, cx
    shr     ax, 6
    mov     [used_conv_kb], ax

    mov     ax, dx
    shr     ax, 6
    mov     [free_conv_kb], ax

    mov     ax, si
    shr     ax, 6
    mov     [largest_free_kb], ax

    pop     es
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

; ---------------------------------------------------------------------------
; print_mcb_chain - Print detailed MCB chain information
; ---------------------------------------------------------------------------
print_mcb_chain:
    push    ax
    push    bx
    push    cx
    push    dx
    push    es

    mov     ax, [first_mcb]

.print_loop:
    mov     es, ax

    ; Check signature
    mov     bl, [es:0]
    cmp     bl, 'M'
    je      .print_valid
    cmp     bl, 'Z'
    je      .print_valid
    jmp     .print_done

.print_valid:
    ; Print segment address
    mov     dx, msg_mcb_seg
    call    print_string
    call    print_hex_word          ; AX = segment

    ; Print owner
    mov     dx, msg_mcb_owner
    call    print_string
    mov     ax, [es:1]
    test    ax, ax
    jnz     .has_owner
    mov     dx, msg_free_block
    call    print_string
    jmp     .print_size

.has_owner:
    call    print_hex_word

    ; Try to print owner name (at MCB offset 8, 8 bytes)
    mov     dx, msg_space
    call    print_string

    ; Check if name field has valid characters
    mov     cl, [es:8]
    cmp     cl, ' '
    jb      .print_size
    cmp     cl, 'z'
    ja      .print_size

    ; Print name (up to 8 chars, stop at null)
    mov     cx, 8
    mov     bx, 8
.print_name:
    mov     dl, [es:bx]
    test    dl, dl
    jz      .print_size
    cmp     dl, ' '
    jb      .print_size
    mov     ah, 0x02
    int     0x21
    inc     bx
    loop    .print_name

.print_size:
    ; Print size
    mov     dx, msg_mcb_size
    call    print_string
    mov     ax, [es:3]              ; Size in paragraphs
    ; Convert to bytes for display (paragraphs * 16)
    mov     cx, ax
    shr     cx, 6                   ; KB
    mov     ax, cx
    call    print_dec
    mov     dx, msg_kb_suffix
    call    print_string

    mov     dx, msg_crlf
    call    print_string

    ; Check if last block
    cmp     byte [es:0], 'Z'
    je      .print_done

    ; Next MCB
    mov     ax, es
    mov     bx, [es:3]
    inc     bx
    add     ax, bx
    jmp     .print_loop

.print_done:
    pop     es
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

; ---------------------------------------------------------------------------
; check_xms - Check if XMS is available
; Returns: AX = 1 if XMS available, 0 if not
; Sets: xms_entry if available
; ---------------------------------------------------------------------------
check_xms:
    push    bx
    push    es

    ; Check for XMS driver via INT 2Fh AX=4300h
    mov     ax, 0x4300
    int     0x2F
    cmp     al, 0x80
    jne     .no_xms

    ; Get XMS entry point via INT 2Fh AX=4310h
    mov     ax, 0x4310
    int     0x2F
    mov     [xms_entry], bx
    mov     [xms_entry+2], es

    mov     ax, 1
    jmp     .done

.no_xms:
    xor     ax, ax

.done:
    pop     es
    pop     bx
    ret

; ---------------------------------------------------------------------------
; print_string - Print $-terminated string
; Input: DX = string pointer
; ---------------------------------------------------------------------------
print_string:
    push    ax
    mov     ah, 0x09
    int     0x21
    pop     ax
    ret

; ---------------------------------------------------------------------------
; print_dec - Print AX as decimal number
; ---------------------------------------------------------------------------
print_dec:
    push    ax
    push    bx
    push    cx
    push    dx

    xor     cx, cx
    mov     bx, 10
.div:
    xor     dx, dx
    div     bx
    push    dx
    inc     cx
    test    ax, ax
    jnz     .div
.out:
    pop     dx
    add     dl, '0'
    mov     ah, 0x02
    int     0x21
    loop    .out

    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

; ---------------------------------------------------------------------------
; print_dec_kb - Print AX as decimal with "KB" suffix and newline
; ---------------------------------------------------------------------------
print_dec_kb:
    call    print_dec
    mov     dx, msg_kb_line
    call    print_string
    ret

; ---------------------------------------------------------------------------
; print_hex_word - Print AX as 4-digit hex
; ---------------------------------------------------------------------------
print_hex_word:
    push    ax
    push    bx
    push    cx
    push    dx

    mov     cx, 4
.hex_loop:
    rol     ax, 4
    push    ax
    and     al, 0x0F
    add     al, '0'
    cmp     al, '9'
    jbe     .hex_print
    add     al, 7               ; A-F
.hex_print:
    mov     dl, al
    mov     ah, 0x02
    int     0x21
    pop     ax
    loop    .hex_loop

    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

; ===========================================================================
; Data Section
; ===========================================================================

msg_header      db  0x0D, 0x0A
                db  'Memory Information', 0x0D, 0x0A
                db  '==================', 0x0D, 0x0A, 0x0D, 0x0A, '$'

msg_conv_header db  'Conventional Memory:', 0x0D, 0x0A
                db  '--------------------', 0x0D, 0x0A, '$'

msg_total       db  '  Total:           $'
msg_used        db  '  Used:            $'
msg_free        db  '  Free:            $'
msg_largest     db  '  Largest block:   $'
msg_kb_line     db  ' KB', 0x0D, 0x0A, '$'
msg_kb_suffix   db  'KB$'

msg_xms_header  db  0x0D, 0x0A, 'Extended Memory (XMS):', 0x0D, 0x0A
                db  '----------------------', 0x0D, 0x0A, '$'
msg_xms_ver     db  '  XMS Version:     $'
msg_xms_total   db  '  Total free:      $'
msg_xms_largest db  '  Largest block:   $'
msg_no_xms      db  0x0D, 0x0A, 'Extended Memory: Not available', 0x0D, 0x0A, '$'

msg_mcb_header  db  0x0D, 0x0A, 'Memory Block Chain:', 0x0D, 0x0A
                db  '-------------------', 0x0D, 0x0A
                db  '  Segment  Owner     Size', 0x0D, 0x0A, '$'

msg_mcb_seg     db  '  $'
msg_mcb_owner   db  '     $'
msg_mcb_size    db  '     $'
msg_free_block  db  '----$'
msg_space       db  ' $'

msg_dosver      db  0x0D, 0x0A, 'DOS Version: $'
msg_crlf        db  0x0D, 0x0A, '$'

; Variables
total_conv_kb   dw  0
used_conv_kb    dw  0
free_conv_kb    dw  0
largest_free_kb dw  0
xms_free_kb     dw  0
xms_largest_kb  dw  0
first_mcb       dw  0
xms_entry       dd  0
