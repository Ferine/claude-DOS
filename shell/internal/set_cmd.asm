; ===========================================================================
; SET command - Display/set environment variables
; Usage: SET           - display all variables
;        SET VAR       - display specific variable
;        SET VAR=value - set variable
;
; Operates directly on the DOS environment block (PSP:2Ch) so that
; child processes inherit SET changes. No private env_table.
; ===========================================================================

ENV_MAX_SIZE    equ     512         ; Maximum environment block size

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
    ; Display all environment variables from DOS env block
    push    es
    push    ds

    ; Get environment segment from shell's PSP
    mov     es, [cs:shell_psp]
    mov     es, [es:0x2C]           ; ES = environment segment

    xor     di, di                  ; DI = offset into env block

.show_env_loop:
    ; Check for double-NUL (end of environment)
    cmp     byte [es:di], 0
    je      .show_env_done

    ; Print this string using ES:DI as source
    ; Copy to a local buffer and print
    push    di
    push    es
    pop     ds                      ; DS = env segment
    mov     si, di
    push    cs
    pop     es
    mov     di, set_value_buf       ; Reuse as temp print buffer
.show_copy:
    lodsb
    mov     [es:di], al
    inc     di
    test    al, al
    jnz     .show_copy

    ; Print it
    push    cs
    pop     ds
    mov     dx, set_value_buf
    call    print_asciiz
    call    print_crlf

    ; Restore ES to env segment
    mov     es, [cs:shell_psp]
    mov     es, [es:0x2C]
    pop     di

    ; Advance DI past this string (find the NUL)
.show_advance:
    cmp     byte [es:di], 0
    je      .show_next_str
    inc     di
    jmp     .show_advance
.show_next_str:
    inc     di                      ; Skip past NUL
    jmp     .show_env_loop

.show_env_done:
    pop     ds
    pop     es
    popa
    ret

; ---------------------------------------------------------------------------
; env_get_seg - Helper: get environment segment into ES
; Output: ES = environment segment
; Clobbers: nothing (uses stack)
; ---------------------------------------------------------------------------
env_get_seg:
    push    ax
    mov     ax, [cs:shell_psp]
    mov     es, ax
    mov     es, [es:0x2C]
    pop     ax
    ret

; ---------------------------------------------------------------------------
; env_find - Find environment variable in DOS env block
; Input: set_name_buf = variable name to find (NUL-terminated, uppercase)
; Output: ES:DI = start of matching "NAME=VALUE" entry
;         CX = length of entire entry (including NUL)
;         CF=0 found, CF=1 not found
; Clobbers: AX
; ---------------------------------------------------------------------------
env_find:
    push    si
    push    bx

    call    env_get_seg             ; ES = env segment

    xor     di, di                  ; DI = offset into env

.find_loop:
    ; Check for double-NUL (end of environment)
    cmp     byte [es:di], 0
    je      .find_not_found

    ; Compare name: set_name_buf vs ES:DI up to '='
    push    di                      ; Save start of this entry
    mov     si, set_name_buf
.cmp_name:
    lodsb                           ; AL = next char from search name
    test    al, al
    jz      .cmp_check_eq           ; End of search name

    ; Get char from env entry and uppercase it
    mov     ah, [es:di]
    cmp     ah, 'a'
    jb      .cmp_no_upper
    cmp     ah, 'z'
    ja      .cmp_no_upper
    sub     ah, 0x20
.cmp_no_upper:
    inc     di
    cmp     al, ah
    jne     .find_no_match
    jmp     .cmp_name

.cmp_check_eq:
    ; End of search name - env char should be '='
    cmp     byte [es:di], '='
    je      .find_match

.find_no_match:
    pop     di                      ; Restore entry start

    ; Skip to next entry (find NUL)
.skip_entry:
    cmp     byte [es:di], 0
    je      .skip_entry_done
    inc     di
    jmp     .skip_entry
.skip_entry_done:
    inc     di                      ; Skip past NUL
    jmp     .find_loop

.find_not_found:
    stc
    pop     bx
    pop     si
    ret

.find_match:
    pop     di                      ; DI = start of matching entry

    ; Calculate entry length (including NUL terminator)
    push    di
    xor     cx, cx
.measure_entry:
    cmp     byte [es:di], 0
    je      .measured
    inc     di
    inc     cx
    jmp     .measure_entry
.measured:
    inc     cx                      ; Include the NUL
    pop     di                      ; Restore DI to entry start

    clc
    pop     bx
    pop     si
    ret

; ---------------------------------------------------------------------------
; env_get - Get environment variable value
; Input: set_name_buf = variable name
; Output: set_value_buf = value, CF set if not found
; ---------------------------------------------------------------------------
env_get:
    push    si
    push    di
    push    es

    call    env_find
    jc      .get_not_found

    ; ES:DI points to NAME=VALUE, find the '='
.find_value:
    cmp     byte [es:di], '='
    je      .found_value
    inc     di
    jmp     .find_value
.found_value:
    inc     di                      ; Skip '='

    ; Copy value to set_value_buf
    push    di
    mov     si, di
    mov     di, set_value_buf
.copy_get_value:
    mov     al, [es:si]
    mov     [cs:di], al
    inc     si
    inc     di
    test    al, al
    jnz     .copy_get_value
    pop     di

    clc
    pop     es
    pop     di
    pop     si
    ret

.get_not_found:
    stc
    pop     es
    pop     di
    pop     si
    ret

; ---------------------------------------------------------------------------
; env_set - Set environment variable in DOS env block
; Input: set_name_buf = variable name, set_value_buf = value
; ---------------------------------------------------------------------------
env_set:
    pusha
    push    es

    ; Step 1: Measure current environment size
    call    env_get_seg             ; ES = env segment
    xor     di, di
    xor     cx, cx                  ; CX = total size
.measure_env:
    cmp     byte [es:di], 0
    je      .env_size_done
    ; Skip to next NUL
.me_skip:
    inc     di
    inc     cx
    cmp     byte [es:di], 0
    jnz     .me_skip
    inc     di                      ; Skip past NUL
    inc     cx
    jmp     .measure_env
.env_size_done:
    ; CX = bytes used (not counting final NUL)
    ; DI = offset of terminating NUL
    mov     [.env_used], cx
    mov     [.env_end], di

    ; Step 2: If variable already exists, remove it first
    call    env_find
    jc      .no_old_entry

    ; Found: ES:DI = entry start, CX = entry length (incl NUL)
    ; Remove by shifting everything after this entry backward
    mov     si, di
    add     si, cx                  ; SI = start of data after old entry

    ; Calculate bytes to move: from SI to double-NUL
    push    di
    mov     di, si
    xor     bx, bx                  ; BX = bytes after old entry
.count_after:
    cmp     byte [es:di], 0
    je      .count_after_done
.ca_inner:
    inc     di
    inc     bx
    cmp     byte [es:di], 0
    jnz     .ca_inner
    inc     di                      ; Skip NUL between strings
    inc     bx
    jmp     .count_after
.count_after_done:
    inc     bx                      ; Include final NUL
    pop     di                      ; DI = where to copy to

    ; Move bytes: from ES:SI to ES:DI, count BX
    push    cx
    mov     cx, bx
    push    ds
    push    es
    pop     ds                      ; DS = ES = env segment
.shift_bytes:
    mov     al, [ds:si]
    mov     [es:di], al
    inc     si
    inc     di
    dec     cx
    jnz     .shift_bytes
    pop     ds
    pop     cx

    ; Recalculate environment size after removal
    sub     word [.env_used], cx

    ; Recalculate end position
    call    env_get_seg
    xor     di, di
.re_measure:
    cmp     byte [es:di], 0
    je      .re_measured
.rm_skip:
    inc     di
    cmp     byte [es:di], 0
    jnz     .rm_skip
    inc     di
    jmp     .re_measure
.re_measured:
    mov     [.env_end], di

.no_old_entry:
    ; Step 3: Build new entry "NAME=VALUE\0" and calculate its size
    push    cs
    pop     ds
    mov     si, set_name_buf
    xor     cx, cx
.calc_name_len:
    cmp     byte [si], 0
    je      .name_len_done
    inc     si
    inc     cx
    jmp     .calc_name_len
.name_len_done:
    inc     cx                      ; For '='

    mov     si, set_value_buf
.calc_val_len:
    cmp     byte [si], 0
    je      .val_len_done
    inc     si
    inc     cx
    jmp     .calc_val_len
.val_len_done:
    inc     cx                      ; For NUL terminator
    ; CX = total new entry length

    ; Step 4: Check if it fits
    mov     ax, [.env_used]
    add     ax, cx
    inc     ax                      ; For the double-NUL terminator
    cmp     ax, ENV_MAX_SIZE
    ja      .env_full

    ; Step 5: Append new entry at .env_end
    call    env_get_seg             ; ES = env segment
    mov     di, [.env_end]

    mov     si, set_name_buf
.append_name:
    lodsb
    test    al, al
    jz      .append_eq
    mov     [es:di], al
    inc     di
    jmp     .append_name
.append_eq:
    mov     byte [es:di], '='
    inc     di

    mov     si, set_value_buf
.append_value:
    lodsb
    mov     [es:di], al
    inc     di
    test    al, al
    jnz     .append_value

    ; Write double-NUL terminator
    mov     byte [es:di], 0

    pop     es
    popa
    ret

.env_full:
    ; Print error message
    push    cs
    pop     ds
    mov     dx, env_full_msg
    mov     ah, 0x09
    int     0x21
    pop     es
    popa
    ret

; Local data for env_set
.env_used       dw  0
.env_end        dw  0

; ---------------------------------------------------------------------------
; env_unset - Remove environment variable from DOS env block
; Input: set_name_buf = variable name
; ---------------------------------------------------------------------------
env_unset:
    pusha
    push    es

    call    env_find
    jc      .unset_done

    ; Found: ES:DI = entry start, CX = entry length (incl NUL)
    ; Remove by shifting everything after this entry backward
    mov     si, di
    add     si, cx                  ; SI = start of data after old entry

    ; Calculate bytes to move: from SI to double-NUL
    push    di
    mov     di, si
    xor     bx, bx
.us_count:
    cmp     byte [es:di], 0
    je      .us_count_done
.us_inner:
    inc     di
    inc     bx
    cmp     byte [es:di], 0
    jnz     .us_inner
    inc     di
    inc     bx
    jmp     .us_count
.us_count_done:
    inc     bx                      ; Include final NUL
    pop     di

    ; Shift bytes forward
    push    cx
    mov     cx, bx
    push    ds
    push    es
    pop     ds
.us_shift:
    mov     al, [ds:si]
    mov     [es:di], al
    inc     si
    inc     di
    dec     cx
    jnz     .us_shift
    pop     ds
    pop     cx

.unset_done:
    pop     es
    popa
    ret

; Data
set_name_buf    times 32 db 0
set_value_buf   times 128 db 0
set_not_found_msg db 'Environment variable not found', 0x0D, 0x0A, '$'
env_full_msg    db  'Out of environment space', 0x0D, 0x0A, '$'
