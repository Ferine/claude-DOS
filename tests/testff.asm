; Test FindFirst/FindNext functionality
org 0x100

section .text
start:
    ; Print header
    mov     dx, msg_header
    mov     ah, 0x09
    int     0x21

    ; Set DTA to our buffer
    mov     dx, dta_buffer
    mov     ah, 0x1A
    int     0x21

    ; FindFirst - search for *.COM
    mov     dx, pattern
    mov     cx, 0x00            ; Normal files only
    mov     ah, 0x4E
    int     0x21
    jc      .no_files

.print_file:
    ; Print the filename from DTA (offset 0x1E)
    mov     si, dta_buffer + 0x1E
    call    print_string

    ; Print newline
    mov     dx, crlf
    mov     ah, 0x09
    int     0x21

    ; FindNext
    mov     ah, 0x4F
    int     0x21
    jnc     .print_file

    ; Done
    mov     dx, msg_done
    mov     ah, 0x09
    int     0x21

    ; Exit
    mov     ax, 0x4C00
    int     0x21

.no_files:
    mov     dx, msg_nofiles
    mov     ah, 0x09
    int     0x21
    mov     ax, 0x4C01
    int     0x21

; Print ASCIIZ string at DS:SI
print_string:
    lodsb
    test    al, al
    jz      .done
    mov     dl, al
    mov     ah, 0x02
    int     0x21
    jmp     print_string
.done:
    ret

section .data
msg_header  db 'FindFirst/FindNext test - listing *.COM files:', 13, 10, '$'
msg_done    db 'Done!', 13, 10, '$'
msg_nofiles db 'No files found!', 13, 10, '$'
pattern     db '*.COM', 0
crlf        db 13, 10, '$'

section .bss
dta_buffer  resb 128
