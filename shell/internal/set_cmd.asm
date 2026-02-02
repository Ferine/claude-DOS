; ===========================================================================
; SET command - Display/set environment variables
; Usage: SET           - display all variables
;        SET VAR       - display specific variable
;        SET VAR=value - set variable
; ===========================================================================

ENV_MAX_VARS    equ     16
ENV_VAR_SIZE    equ     64          ; Max size per variable (NAME=VALUE)

cmd_set:
    pusha

    ; Check if argument provided
    cmp     byte [si], 0
    je      .show_all

    ; Check for '=' in argument (SET VAR=value)
    push    si
    mov     di, si
.find_eq:
    mov     al, [di]
    test    al, al
    jz      .no_eq
    cmp     al, 0x0D
    je      .no_eq
    cmp     al, '='
    je      .found_eq
    inc     di
    jmp     .find_eq

.found_eq:
    ; Setting a variable
    pop     si                      ; Restore start of argument

    ; Copy name to temp buffer (uppercase)
    mov     di, set_name_buf
.copy_name:
    lodsb
    cmp     al, '='
    je      .name_done
    ; Uppercase
    cmp     al, 'a'
    jb      .store_name
    cmp     al, 'z'
    ja      .store_name
    sub     al, 0x20
.store_name:
    stosb
    jmp     .copy_name
.name_done:
    mov     byte [di], 0

    ; SI now points to value (after '=')
    ; Copy value to temp buffer
    mov     di, set_value_buf
.copy_value:
    lodsb
    cmp     al, 0x0D
    je      .value_done
    test    al, al
    jz      .value_done
    stosb
    jmp     .copy_value
.value_done:
    mov     byte [di], 0

    ; Check if value is empty (unset variable)
    cmp     byte [set_value_buf], 0
    je      .unset_var

    ; Set the variable
    call    env_set
    popa
    ret

.unset_var:
    ; Remove the variable
    call    env_unset
    popa
    ret

.no_eq:
    ; Display specific variable
    pop     si

    ; Copy name to buffer (uppercase)
    mov     di, set_name_buf
.copy_show_name:
    lodsb
    cmp     al, 0x0D
    je      .show_name_done
    cmp     al, ' '
    je      .show_name_done
    test    al, al
    jz      .show_name_done
    ; Uppercase
    cmp     al, 'a'
    jb      .store_show_name
    cmp     al, 'z'
    ja      .store_show_name
    sub     al, 0x20
.store_show_name:
    stosb
    jmp     .copy_show_name
.show_name_done:
    mov     byte [di], 0

    ; Find and display the variable
    call    env_get
    jc      .var_not_found

    ; Print NAME=VALUE
    mov     dx, set_name_buf
    call    print_asciiz
    mov     dl, '='
    mov     ah, 0x02
    int     0x21
    mov     dx, set_value_buf
    call    print_asciiz
    call    print_crlf

    popa
    ret

.var_not_found:
    mov     dx, set_not_found_msg
    mov     ah, 0x09
    int     0x21
    popa
    ret

.show_all:
    ; Display all environment variables
    mov     cx, ENV_MAX_VARS
    mov     bx, env_table
.show_loop:
    cmp     byte [bx], 0
    je      .show_next

    ; Print this variable
    mov     dx, bx
    call    print_asciiz
    call    print_crlf

.show_next:
    add     bx, ENV_VAR_SIZE
    loop    .show_loop

    popa
    ret

; ---------------------------------------------------------------------------
; env_set - Set environment variable
; Input: set_name_buf = variable name, set_value_buf = value
; ---------------------------------------------------------------------------
env_set:
    pusha

    ; First check if variable exists
    call    env_find
    jnc     .update_existing

    ; Find empty slot
    mov     cx, ENV_MAX_VARS
    mov     di, env_table
.find_slot:
    cmp     byte [di], 0
    je      .found_slot
    add     di, ENV_VAR_SIZE
    loop    .find_slot

    ; No room
    jmp     .set_done

.found_slot:
.update_existing:
    ; DI points to slot, build NAME=VALUE
    mov     si, set_name_buf
.copy_env_name:
    lodsb
    test    al, al
    jz      .add_eq
    stosb
    jmp     .copy_env_name
.add_eq:
    mov     al, '='
    stosb
    mov     si, set_value_buf
.copy_env_value:
    lodsb
    stosb
    test    al, al
    jnz     .copy_env_value

.set_done:
    popa
    ret

; ---------------------------------------------------------------------------
; env_unset - Remove environment variable
; Input: set_name_buf = variable name
; ---------------------------------------------------------------------------
env_unset:
    pusha
    call    env_find
    jc      .unset_done
    ; Clear the slot
    mov     byte [di], 0
.unset_done:
    popa
    ret

; ---------------------------------------------------------------------------
; env_get - Get environment variable value
; Input: set_name_buf = variable name
; Output: set_value_buf = value, CF set if not found
; ---------------------------------------------------------------------------
env_get:
    push    si
    push    di

    call    env_find
    jc      .get_not_found

    ; DI points to NAME=VALUE, find the '='
.find_value:
    mov     al, [di]
    inc     di
    cmp     al, '='
    jne     .find_value

    ; Copy value
    mov     si, di
    mov     di, set_value_buf
.copy_get_value:
    lodsb
    stosb
    test    al, al
    jnz     .copy_get_value

    clc
    pop     di
    pop     si
    ret

.get_not_found:
    stc
    pop     di
    pop     si
    ret

; ---------------------------------------------------------------------------
; env_find - Find environment variable
; Input: set_name_buf = variable name to find
; Output: DI = pointer to entry, CF set if not found
; ---------------------------------------------------------------------------
env_find:
    push    cx
    push    si

    mov     cx, ENV_MAX_VARS
    mov     di, env_table
.find_loop:
    cmp     byte [di], 0
    je      .find_next

    ; Compare name
    push    di
    mov     si, set_name_buf
.cmp_name:
    lodsb
    mov     ah, [di]
    inc     di

    ; Check for end of search name
    test    al, al
    jz      .check_eq

    ; Compare chars
    cmp     al, ah
    jne     .find_no_match
    jmp     .cmp_name

.check_eq:
    ; End of search name - next char in table should be '='
    cmp     byte [di - 1], '='
    je      .find_match

.find_no_match:
    pop     di
.find_next:
    add     di, ENV_VAR_SIZE
    loop    .find_loop

    ; Not found
    stc
    pop     si
    pop     cx
    ret

.find_match:
    pop     di                  ; Restore start of entry
    clc
    pop     si
    pop     cx
    ret

; Data
set_name_buf    times 32 db 0
set_value_buf   times 128 db 0
set_not_found_msg db 'Environment variable not found', 0x0D, 0x0A, '$'

; Environment variable table
env_table:
    db      'PATH=A:\', 0
    times   (ENV_VAR_SIZE - 9) db 0
    db      'COMSPEC=A:\COMMAND.COM', 0
    times   (ENV_VAR_SIZE - 23) db 0
    db      'PROMPT=$P$G', 0
    times   (ENV_VAR_SIZE - 12) db 0
    times   (ENV_MAX_VARS - 3) * ENV_VAR_SIZE db 0
