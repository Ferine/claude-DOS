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
    ; Copy argument to path_value (local cache for search_path_for_cmd)
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

    ; Sync to DOS environment block
    call    .sync_path_to_env
    popa
    ret

.clear_path:
    mov     byte [path_value], 0

    ; Remove PATH from DOS environment
    push    si
    push    di
    mov     si, .path_name
    mov     di, set_name_buf
.cp_name:
    lodsb
    stosb
    test    al, al
    jnz     .cp_name
    call    env_unset
    pop     di
    pop     si

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

; ---------------------------------------------------------------------------
; .sync_path_to_env - Copy path_value to DOS environment as PATH=<value>
; ---------------------------------------------------------------------------
.sync_path_to_env:
    push    si
    push    di

    ; Copy "PATH" to set_name_buf
    mov     si, .path_name
    mov     di, set_name_buf
.spe_name:
    lodsb
    stosb
    test    al, al
    jnz     .spe_name

    ; Copy path_value to set_value_buf
    mov     si, path_value
    mov     di, set_value_buf
.spe_val:
    lodsb
    stosb
    test    al, al
    jnz     .spe_val

    call    env_set

    pop     di
    pop     si
    ret

.path_name      db  'PATH', 0

; Default path value - can be modified by PATH command
; Kept as a fast local cache for search_path_for_cmd
path_value      db  'A:\', 0
                times 124 db 0          ; Room for longer paths

path_prefix     db  'PATH=', '$'
path_none_msg   db  '(no path set)', 0x0D, 0x0A, '$'
