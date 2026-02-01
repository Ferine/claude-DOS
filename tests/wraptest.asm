; WRAPTEST - Test segment wrap during loading
; Verifies data at 64KB boundary is correct
bits 16

; MZ EXE Header (32 bytes)
header:
    dw 0x5A4D           ; MZ signature
    dw 0                ; Bytes on last page
    dw 137              ; Pages in file (~70KB)
    dw 0                ; Relocations
    dw 2                ; Header paragraphs (32 bytes)
    dw 0x100            ; Min extra paragraphs
    dw 0xFFFF           ; Max extra
    dw 0                ; Initial SS
    dw 0x200            ; Initial SP
    dw 0                ; Checksum
    dw 0                ; Initial IP
    dw 0                ; Initial CS
    dw 0                ; Reloc offset
    dw 0                ; Overlay
    times 32-($-header) db 0

; Code at start of loaded image
code_start:
    ; DS = ES = PSP, but we need DS = CS to access our data
    push    cs
    pop     ds

    ; Check byte at offset 65504 (just before 64KB boundary)
    ; Should be 0x55 (marker we placed there)
    mov     si, 65504
    lodsb
    cmp     al, 0x55
    jne     .fail1

    ; Check byte at offset 65536 (first byte after 64KB boundary)
    ; This requires segment adjustment
    mov     ax, cs
    add     ax, 0x1000          ; Advance by 64KB
    mov     ds, ax
    xor     si, si              ; Offset 0 in new segment = offset 65536 from code_start
    lodsb
    cmp     al, 0xAA
    jne     .fail2

    ; Check marker at ~68KB to verify more data loaded correctly
    mov     si, 3000            ; ~65536 + 3000 = ~68.5KB offset
    lodsb
    cmp     al, 0xBB
    jne     .fail3

    ; Success - print "OK!"
    mov     ah, 0x0E
    xor     bx, bx
    mov     al, 'O'
    int     0x10
    mov     al, 'K'
    int     0x10
    mov     al, '!'
    int     0x10
    jmp     .exit

.fail1:
    mov     ah, 0x0E
    xor     bx, bx
    mov     al, 'F'
    int     0x10
    mov     al, '1'
    int     0x10
    jmp     .exit

.fail2:
    mov     ah, 0x0E
    xor     bx, bx
    mov     al, 'F'
    int     0x10
    mov     al, '2'
    int     0x10
    jmp     .exit

.fail3:
    mov     ah, 0x0E
    xor     bx, bx
    mov     al, 'F'
    int     0x10
    mov     al, '3'
    int     0x10

.exit:
    mov     al, 0x0D
    int     0x10
    mov     al, 0x0A
    int     0x10
    mov     ax, 0x4C00
    int     0x21

; Padding to reach specific offsets
; Offset 65504 from code_start (where we check for 0x55)
times (65504 - ($ - code_start)) db 0xCC
marker1: db 0x55                ; Byte just before 64KB boundary

; Padding to next segment (offset 65536)
times (65536 - ($ - code_start)) db 0xCC
marker2: db 0xAA                ; First byte in second 64KB

; More padding
times (68536 - ($ - code_start)) db 0xCC
marker3: db 0xBB                ; Marker at ~68.5KB

; Pad to file size
times (70000 - 32 - ($ - code_start)) db 0xCC
