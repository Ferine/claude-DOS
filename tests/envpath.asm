; ENVPATH.COM - Test environment program path (CPAV format)
; Reads PSP:2C to get environment segment, then dumps the program path
    CPU     186
    ORG     0x0100

start:
    ; Get PSP segment (already in DS/ES)
    mov     ax, ds              ; AX = PSP segment

    ; Get environment segment from PSP:2C
    mov     es, ax
    mov     ax, [es:0x2C]       ; Environment segment
    test    ax, ax
    jz      .no_env

    ; Print "Env seg: "
    mov     dx, msg_env
    mov     ah, 0x09
    int     0x21

    ; Print env segment as hex
    mov     ax, [es:0x2C]
    call    print_hex
    call    print_crlf

    ; Now scan through environment to find the program path
    ; Format: VAR=VALUE\0 ... \0 (double NUL) \x01\x00 PATH\0
    mov     es, [es:0x2C]       ; ES = environment segment (reload from PSP)
    xor     di, di              ; Start at offset 0

.scan_env:
    ; Check for double-NUL (end of environment)
    cmp     byte [es:di], 0
    jne     .next_var

    ; Found a NUL, check next byte
    inc     di
    cmp     byte [es:di], 0
    jne     .scan_env           ; Not double-NUL, continue

    ; Found double-NUL! Now check for count word
    inc     di                  ; Skip second NUL

    ; Read count word
    mov     ax, [es:di]
    cmp     ax, 0               ; If count is 0, no program path
    je      .no_path

    add     di, 2               ; Skip count word

    ; Print "Path: "
    push    es
    push    di
    mov     dx, msg_path
    mov     ah, 0x09
    int     0x21
    pop     di
    pop     es

    ; Print the program path character by character
.print_path:
    mov     al, [es:di]
    test    al, al
    jz      .done
    mov     dl, al
    mov     ah, 0x02
    int     0x21
    inc     di
    jmp     .print_path

.next_var:
    ; Skip to next NUL
    cmp     byte [es:di], 0
    je      .scan_env
    inc     di
    jmp     .next_var

.no_env:
    mov     dx, msg_no_env
    mov     ah, 0x09
    int     0x21
    jmp     .done

.no_path:
    mov     dx, msg_no_path
    mov     ah, 0x09
    int     0x21

.done:
    call    print_crlf
    mov     ax, 0x4C00
    int     0x21

; Print AX as 4-digit hex
print_hex:
    push    ax
    push    bx
    push    cx
    push    dx

    mov     cx, 4               ; 4 hex digits
    mov     bx, ax
.hex_loop:
    rol     bx, 4               ; Get high nibble
    mov     al, bl
    and     al, 0x0F
    add     al, '0'
    cmp     al, '9'
    jbe     .not_letter
    add     al, 7               ; Convert A-F
.not_letter:
    mov     dl, al
    mov     ah, 0x02
    int     0x21
    loop    .hex_loop

    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

print_crlf:
    mov     dx, crlf
    mov     ah, 0x09
    int     0x21
    ret

msg_env     db  'Env seg: $'
msg_path    db  'Path: $'
msg_no_env  db  'No environment!$'
msg_no_path db  'No program path!$'
crlf        db  0x0D, 0x0A, '$'
