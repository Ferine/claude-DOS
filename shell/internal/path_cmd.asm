; ===========================================================================
; PATH command - Display/set search path
; Usage: PATH                - displays current path
;        PATH path1;path2    - sets new path
;        PATH ;              - clears path
; ===========================================================================

cmd_path:
    pusha

    ; Check if argument provided
    cmp     byte [si], 0
    je      .show_path

    ; Check for ";" (clear path)
    cmp     byte [si], ';'
    jne     .set_path
    cmp     byte [si+1], 0
    je      .clear_path
    cmp     byte [si+1], ' '
    je      .clear_path

.set_path:
    ; Copy argument to path_value
    mov     di, path_value
.copy_path:
    lodsb
    cmp     al, 0x0D
    je      .set_done
    test    al, al
    jz      .set_done
    stosb
    jmp     .copy_path
.set_done:
    mov     byte [di], 0
    popa
    ret

.clear_path:
    mov     byte [path_value], 0
    popa
    ret

.show_path:
    ; Print "PATH="
    mov     dx, path_prefix
    mov     ah, 0x09
    int     0x21

    ; Check if path is empty
    cmp     byte [path_value], 0
    je      .show_empty

    ; Print path value
    mov     dx, path_value
    call    print_asciiz
    call    print_crlf
    popa
    ret

.show_empty:
    mov     dx, path_none_msg
    mov     ah, 0x09
    int     0x21
    popa
    ret

; Default path value - can be modified by PATH command
path_value      db  'A:\', 0
                times 124 db 0          ; Room for longer paths

path_prefix     db  'PATH=', '$'
path_none_msg   db  '(no path set)', 0x0D, 0x0A, '$'
