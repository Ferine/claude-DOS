; EXEINFO.COM - Display detailed EXE file information
; Usage: EXEINFO filename.exe
    CPU     186
    ORG     0x0100

start:
    ; Parse command line for filename
    mov     si, 0x81            ; Command line at PSP:81h
    call    skip_spaces
    cmp     byte [si], 0x0D     ; No argument?
    je      .no_arg

    ; Copy filename to buffer
    mov     di, filename
.copy_name:
    lodsb
    cmp     al, 0x0D
    je      .name_done
    cmp     al, ' '
    je      .name_done
    stosb
    jmp     .copy_name
.name_done:
    mov     byte [di], 0

    ; Open file
    mov     dx, filename
    mov     ax, 0x3D00          ; Open for reading
    int     0x21
    jc      .open_error
    mov     [handle], ax

    ; Read MZ header (28 bytes minimum)
    mov     bx, ax
    mov     cx, 64              ; Read 64 bytes
    mov     dx, mz_buffer
    mov     ah, 0x3F
    int     0x21
    jc      .read_error

    ; Verify MZ signature
    cmp     word [mz_buffer], 0x5A4D
    jne     .not_exe

    ; Print header info
    mov     dx, msg_header
    mov     ah, 0x09
    int     0x21

    ; Last page bytes
    mov     dx, msg_lastpage
    mov     ah, 0x09
    int     0x21
    mov     ax, [mz_buffer + 2]
    call    print_dec16
    call    print_crlf

    ; Page count
    mov     dx, msg_pages
    mov     ah, 0x09
    int     0x21
    mov     ax, [mz_buffer + 4]
    call    print_dec16
    call    print_crlf

    ; Reloc count
    mov     dx, msg_relocs
    mov     ah, 0x09
    int     0x21
    mov     ax, [mz_buffer + 6]
    call    print_dec16
    call    print_crlf

    ; Header paragraphs
    mov     dx, msg_hdrparas
    mov     ah, 0x09
    int     0x21
    mov     ax, [mz_buffer + 8]
    call    print_dec16
    call    print_crlf

    ; Min alloc
    mov     dx, msg_minalloc
    mov     ah, 0x09
    int     0x21
    mov     ax, [mz_buffer + 10]
    call    print_dec16
    call    print_crlf

    ; Max alloc
    mov     dx, msg_maxalloc
    mov     ah, 0x09
    int     0x21
    mov     ax, [mz_buffer + 12]
    call    print_dec16
    call    print_crlf

    ; Init SS
    mov     dx, msg_initss
    mov     ah, 0x09
    int     0x21
    mov     ax, [mz_buffer + 14]
    call    print_hex16
    call    print_crlf

    ; Init SP
    mov     dx, msg_initsp
    mov     ah, 0x09
    int     0x21
    mov     ax, [mz_buffer + 16]
    call    print_hex16
    call    print_crlf

    ; Init IP
    mov     dx, msg_initip
    mov     ah, 0x09
    int     0x21
    mov     ax, [mz_buffer + 20]
    call    print_hex16
    call    print_crlf

    ; Init CS
    mov     dx, msg_initcs
    mov     ah, 0x09
    int     0x21
    mov     ax, [mz_buffer + 22]
    call    print_hex16
    call    print_crlf

    ; Reloc offset
    mov     dx, msg_relocoff
    mov     ah, 0x09
    int     0x21
    mov     ax, [mz_buffer + 24]
    call    print_dec16
    call    print_crlf

    ; Calculate file size from header: (pages-1)*512 + lastpage
    ; (if lastpage=0, it's a full last page)
    mov     dx, msg_calcsize
    mov     ah, 0x09
    int     0x21
    mov     ax, [mz_buffer + 4]     ; pages
    dec     ax
    mov     dx, 512
    mul     dx                      ; DX:AX = (pages-1)*512
    mov     cx, ax
    mov     bx, dx                  ; BX:CX = partial result
    mov     ax, [mz_buffer + 2]     ; lastpage
    test    ax, ax
    jnz     .has_lastpage
    mov     ax, 512
.has_lastpage:
    add     cx, ax
    adc     bx, 0
    ; BX:CX = file size
    mov     ax, cx
    mov     dx, bx
    call    print_dec32
    call    print_crlf

    ; Now read entire file and count bytes
    mov     dx, msg_reading
    mov     ah, 0x09
    int     0x21

    ; Seek to start
    mov     bx, [handle]
    mov     ax, 0x4200          ; Seek from start
    xor     cx, cx
    xor     dx, dx
    int     0x21

    ; Read loop
    xor     si, si              ; Total low
    xor     di, di              ; Total high

.read_loop:
    mov     bx, [handle]
    mov     cx, 512
    mov     dx, read_buffer
    mov     ah, 0x3F
    int     0x21
    jc      .read_error2

    test    ax, ax
    jz      .read_done

    add     si, ax
    adc     di, 0

    ; Print dot every 16KB
    inc     word [dot_count]
    test    word [dot_count], 0x1F
    jnz     .read_loop
    mov     dl, '.'
    mov     ah, 0x02
    int     0x21
    jmp     .read_loop

.read_done:
    call    print_crlf

    ; Print total read
    mov     dx, msg_totalread
    mov     ah, 0x09
    int     0x21
    mov     ax, si
    mov     dx, di
    call    print_dec32
    mov     dx, msg_bytes
    mov     ah, 0x09
    int     0x21

    ; Close
    mov     bx, [handle]
    mov     ah, 0x3E
    int     0x21

    mov     ax, 0x4C00
    int     0x21

.no_arg:
    mov     dx, msg_usage
    mov     ah, 0x09
    int     0x21
    mov     ax, 0x4C01
    int     0x21

.open_error:
    mov     dx, msg_openerr
    mov     ah, 0x09
    int     0x21
    mov     ax, 0x4C02
    int     0x21

.read_error:
    mov     dx, msg_readerr
    mov     ah, 0x09
    int     0x21
    mov     ax, 0x4C03
    int     0x21

.not_exe:
    mov     dx, msg_notexe
    mov     ah, 0x09
    int     0x21
    mov     ax, 0x4C04
    int     0x21

.read_error2:
    mov     dx, msg_readerr2
    mov     ah, 0x09
    int     0x21
    mov     ax, 0x4C05
    int     0x21

; Skip spaces
skip_spaces:
    lodsb
    cmp     al, ' '
    je      skip_spaces
    dec     si
    ret

; Print 16-bit decimal
print_dec16:
    push    ax
    push    bx
    push    cx
    push    dx
    mov     bx, 10
    xor     cx, cx
.div_loop:
    xor     dx, dx
    div     bx
    push    dx
    inc     cx
    test    ax, ax
    jnz     .div_loop
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

; Print 16-bit hex
print_hex16:
    push    ax
    push    cx
    push    dx
    mov     cx, 4
.hex_loop:
    rol     ax, 4
    mov     dl, al
    and     dl, 0x0F
    add     dl, '0'
    cmp     dl, '9'
    jbe     .not_letter
    add     dl, 7
.not_letter:
    push    ax
    mov     ah, 0x02
    int     0x21
    pop     ax
    loop    .hex_loop
    pop     dx
    pop     cx
    pop     ax
    ret

; Print 32-bit decimal (DX:AX)
print_dec32:
    push    ax
    push    bx
    push    cx
    push    dx
    mov     [.num_lo], ax
    mov     [.num_hi], dx
    or      ax, dx
    jnz     .not_zero
    mov     dl, '0'
    mov     ah, 0x02
    int     0x21
    jmp     .done
.not_zero:
    xor     cx, cx
.conv_loop:
    mov     ax, [.num_hi]
    xor     dx, dx
    mov     bx, 10
    div     bx
    mov     [.num_hi], ax
    mov     ax, [.num_lo]
    div     bx
    mov     [.num_lo], ax
    add     dl, '0'
    push    dx
    inc     cx
    mov     ax, [.num_lo]
    or      ax, [.num_hi]
    jnz     .conv_loop
.print_dig:
    pop     dx
    mov     ah, 0x02
    int     0x21
    loop    .print_dig
.done:
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
.num_lo dw 0
.num_hi dw 0

print_crlf:
    push    ax
    push    dx
    mov     dx, crlf
    mov     ah, 0x09
    int     0x21
    pop     dx
    pop     ax
    ret

; Data
msg_usage   db 'Usage: EXEINFO filename.exe', 0x0D, 0x0A, '$'
msg_openerr db 'Cannot open file', 0x0D, 0x0A, '$'
msg_readerr db 'Read error', 0x0D, 0x0A, '$'
msg_notexe  db 'Not a valid EXE file', 0x0D, 0x0A, '$'
msg_readerr2 db 'Read error during scan', 0x0D, 0x0A, '$'
msg_header  db '=== MZ Header ===', 0x0D, 0x0A, '$'
msg_lastpage db 'Last page bytes: $'
msg_pages   db 'Page count:      $'
msg_relocs  db 'Reloc count:     $'
msg_hdrparas db 'Header paras:    $'
msg_minalloc db 'Min alloc:       $'
msg_maxalloc db 'Max alloc:       $'
msg_initss  db 'Init SS:         $'
msg_initsp  db 'Init SP:         $'
msg_initip  db 'Init IP:         $'
msg_initcs  db 'Init CS:         $'
msg_relocoff db 'Reloc offset:    $'
msg_calcsize db 'Calc file size:  $'
msg_reading db 'Reading file', 0x0D, 0x0A, '$'
msg_totalread db 'Total bytes read: $'
msg_bytes   db ' bytes', 0x0D, 0x0A, '$'
crlf        db 0x0D, 0x0A, '$'
handle      dw 0
dot_count   dw 0
filename    times 64 db 0
mz_buffer   times 64 db 0
read_buffer times 512 db 0
