; ===========================================================================
; claudeDOS Batch File (.BAT) Interpreter
; Line-by-line reader with flow control
; ===========================================================================

; ---------------------------------------------------------------------------
; batch_execute - Execute a batch file
; Input: DS:SI = ASCIIZ path to .BAT file
;        DS:DI = command tail (parameters %1-%9)
; ---------------------------------------------------------------------------
batch_execute:
    pusha

    ; Save batch filename
    push    di
    mov     di, batch_file
    call    .copy_str
    pop     di

    ; Save parameters
    push    si
    mov     si, di
    mov     di, batch_params
    call    .copy_str
    pop     si

    ; Open the batch file
    mov     dx, batch_file
    mov     ax, 0x3D00          ; Open, read-only
    int     0x21
    jc      .open_err

    mov     [batch_handle], ax
    mov     byte [batch_active], 1
    mov     word [batch_line], 0

    ; Process lines
.next_line:
    cmp     byte [batch_active], 0
    je      .done

    ; Read one line from batch file
    call    batch_read_line
    jc      .eof                ; EOF or error

    inc     word [batch_line]

    ; Check for @ prefix (suppress echo)
    mov     si, batch_line_buf
    cmp     byte [si], '@'
    jne     .check_echo
    inc     si                  ; Skip @
    jmp     .process_line

.check_echo:
    ; Echo the line if echo is on
    cmp     byte [echo_on], 1
    jne     .process_line
    mov     dx, batch_line_buf
    call    print_asciiz
    call    print_crlf

.process_line:
    call    skip_spaces

    ; Check for empty line
    cmp     byte [si], 0
    je      .next_line

    ; Perform %parameter% substitution
    call    batch_substitute

    ; Check batch-specific commands
    push    si
    call    batch_check_cmd
    pop     si
    test    al, al
    jnz     .next_line

    ; Otherwise, execute as regular command
    ; Copy to cmd_buffer+2 and process through normal command handler
    mov     di, cmd_buffer + 2
    push    si
.copy_to_cmd:
    lodsb
    stosb
    test    al, al
    jnz     .copy_to_cmd
    pop     si

    ; Calculate length
    mov     si, cmd_buffer + 2
    xor     cl, cl
.count_len:
    cmp     byte [si], 0
    je      .len_done
    inc     si
    inc     cl
    jmp     .count_len
.len_done:
    mov     [cmd_buffer + 1], cl

    ; Process command
    mov     si, cmd_buffer + 2
    call    skip_spaces
    cmp     byte [si], 0
    je      .next_line

    call    try_internal_cmd
    test    al, al
    jnz     .next_line

    call    try_external_cmd
    jmp     .next_line

.eof:
    ; Close batch file
    mov     bx, [batch_handle]
    mov     ah, 0x3E
    int     0x21

    ; Check if returning from CALL
    cmp     byte [batch_call_depth], 0
    je      .eof_end_batch

    ; Restore parent batch state
    call    batch_call_restore
    jmp     .next_line          ; Continue parent batch

.eof_end_batch:
    mov     byte [batch_active], 0
    mov     word [batch_handle], 0xFFFF

.done:
    popa
    ret

.open_err:
    mov     dx, batch_err_open
    mov     ah, 0x09
    int     0x21
    popa
    ret

; Copy ASCIIZ string from DS:SI to ES:DI
.copy_str:
    lodsb
    stosb
    test    al, al
    jnz     .copy_str
    ret

; ---------------------------------------------------------------------------
; batch_read_line - Read one line from batch file into batch_line_buf
; Output: CF set on EOF/error
; ---------------------------------------------------------------------------
batch_read_line:
    push    bx
    push    cx
    push    dx
    push    di

    mov     di, batch_line_buf
    mov     cx, 255             ; Max line length

.read_char:
    push    cx
    mov     bx, [batch_handle]
    mov     ah, 0x3F
    mov     cx, 1
    mov     dx, batch_char_buf
    int     0x21
    pop     cx
    jc      .read_err

    test    ax, ax              ; EOF?
    jz      .read_eof

    mov     al, [batch_char_buf]

    cmp     al, 0x0A            ; LF = end of line
    je      .line_done
    cmp     al, 0x0D            ; CR = skip
    je      .read_char

    stosb
    loop    .read_char

.line_done:
    mov     byte [di], 0       ; Null-terminate
    clc
    pop     di
    pop     dx
    pop     cx
    pop     bx
    ret

.read_eof:
    ; Check if we have partial line
    cmp     di, batch_line_buf
    je      .read_err           ; Nothing read = true EOF
    jmp     .line_done          ; Return partial line

.read_err:
    mov     byte [di], 0
    stc
    pop     di
    pop     dx
    pop     cx
    pop     bx
    ret

; ---------------------------------------------------------------------------
; batch_check_cmd - Check for batch-specific commands
; Input: DS:SI = line (after @ stripped)
; Output: AL = 1 if handled
; ---------------------------------------------------------------------------
batch_check_cmd:
    push    si

    ; Extract first word (uppercase)
    mov     di, batch_cmd_word
    xor     cx, cx
.extract:
    lodsb
    cmp     al, ' '
    je      .extract_done
    cmp     al, 0
    je      .extract_done
    ; Uppercase
    cmp     al, 'a'
    jb      .store
    cmp     al, 'z'
    ja      .store
    sub     al, 0x20
.store:
    stosb
    inc     cx
    cmp     cx, 10
    jb      .extract
.extract_done:
    mov     byte [di], 0
    mov     [batch_cmd_args], si

    ; Check REM
    mov     si, batch_cmd_word
    mov     di, .str_rem
    call    str_equal
    je      .is_rem

    ; Check PAUSE
    mov     si, batch_cmd_word
    mov     di, .str_pause
    call    str_equal
    je      .is_pause

    ; Check GOTO
    mov     si, batch_cmd_word
    mov     di, .str_goto
    call    str_equal
    je      .is_goto

    ; Check IF
    mov     si, batch_cmd_word
    mov     di, .str_if
    call    str_equal
    je      .is_if

    ; Check CALL
    mov     si, batch_cmd_word
    mov     di, .str_call
    call    str_equal
    je      .is_call

    ; Check SHIFT
    mov     si, batch_cmd_word
    mov     di, .str_shift
    call    str_equal
    je      .is_shift

    ; Not a batch command
    pop     si
    xor     al, al
    ret

.is_rem:
    ; REM: ignore rest of line
    pop     si
    mov     al, 1
    ret

.is_pause:
    ; Print "Press any key to continue . . ."
    push    dx
    mov     dx, batch_pause_msg
    mov     ah, 0x09
    int     0x21
    ; Wait for keypress
    xor     ah, ah
    int     0x16
    call    print_crlf
    pop     dx
    pop     si
    mov     al, 1
    ret

.is_goto:
    ; Find label in batch file
    mov     si, [batch_cmd_args]
    call    skip_spaces
    call    batch_goto
    pop     si
    mov     al, 1
    ret

.is_if:
    mov     si, [batch_cmd_args]
    call    skip_spaces
    call    batch_if
    pop     si
    mov     al, 1
    ret

.is_call:
    ; CALL: execute another batch file, then return
    mov     si, [batch_cmd_args]
    call    skip_spaces

    ; Check if already in a CALL (only 1 level supported)
    cmp     byte [batch_call_depth], 0
    jne     .call_nested_err

    ; Save current batch state
    mov     byte [batch_call_depth], 1

    ; Save current file handle
    mov     ax, [batch_handle]
    mov     [batch_save_handle], ax

    ; Save current file position
    mov     bx, [batch_handle]
    mov     ax, 0x4201          ; Seek from current, offset 0
    xor     cx, cx
    xor     dx, dx
    int     0x21
    mov     word [batch_save_pos], ax
    mov     word [batch_save_pos + 2], dx

    ; Save current batch filename
    push    si
    mov     si, batch_file
    mov     di, batch_save_file
.call_save_file:
    lodsb
    stosb
    test    al, al
    jnz     .call_save_file

    ; Save current parameters
    mov     si, batch_params
    mov     di, batch_save_params
.call_save_params:
    lodsb
    stosb
    test    al, al
    jnz     .call_save_params
    pop     si

    ; Parse new batch filename (SI points to it)
    mov     di, batch_file
.call_copy_file:
    lodsb
    cmp     al, ' '
    je      .call_file_done
    test    al, al
    jz      .call_file_done
    stosb
    jmp     .call_copy_file
.call_file_done:
    mov     byte [di], 0

    ; Copy remaining as new parameters
    call    skip_spaces
    mov     di, batch_params
.call_copy_params:
    lodsb
    stosb
    test    al, al
    jnz     .call_copy_params

    ; Open new batch file
    mov     dx, batch_file
    mov     ax, 0x3D00
    int     0x21
    jc      .call_open_err
    mov     [batch_handle], ax
    mov     word [batch_line], 0

    pop     si
    mov     al, 1
    ret

.call_nested_err:
    mov     dx, batch_call_nested
    mov     ah, 0x09
    int     0x21
    pop     si
    mov     al, 1
    ret

.call_open_err:
    ; Restore state on error
    call    batch_call_restore
    mov     dx, batch_err_open
    mov     ah, 0x09
    int     0x21
    pop     si
    mov     al, 1
    ret

.is_shift:
    ; SHIFT: shift parameters left (remove first parameter)
    push    di
    mov     si, batch_params
    ; Skip leading spaces
.shift_skip_sp:
    cmp     byte [si], ' '
    jne     .shift_find_end
    inc     si
    jmp     .shift_skip_sp
.shift_find_end:
    ; Skip first parameter (until space or end)
    cmp     byte [si], 0
    je      .shift_done
    cmp     byte [si], ' '
    je      .shift_copy
    inc     si
    jmp     .shift_find_end
.shift_copy:
    ; Skip spaces after first param
    cmp     byte [si], ' '
    jne     .shift_do_copy
    inc     si
    jmp     .shift_copy
.shift_do_copy:
    ; Copy remaining parameters to start
    mov     di, batch_params
.shift_copy_loop:
    lodsb
    stosb
    test    al, al
    jnz     .shift_copy_loop
.shift_done:
    pop     di
    pop     si
    mov     al, 1
    ret

.str_rem    db  'REM', 0
.str_pause  db  'PAUSE', 0
.str_goto   db  'GOTO', 0
.str_if     db  'IF', 0
.str_call   db  'CALL', 0
.str_shift  db  'SHIFT', 0

; ---------------------------------------------------------------------------
; batch_goto - Seek to label in batch file
; Input: DS:SI = label name (without colon)
; ---------------------------------------------------------------------------
batch_goto:
    pusha

    ; Save target label
    mov     di, batch_goto_target
    push    si
.copy_label:
    lodsb
    cmp     al, ' '
    je      .label_done
    cmp     al, 0
    je      .label_done
    ; Uppercase
    cmp     al, 'a'
    jb      .store_lbl
    cmp     al, 'z'
    ja      .store_lbl
    sub     al, 0x20
.store_lbl:
    stosb
    jmp     .copy_label
.label_done:
    mov     byte [di], 0
    pop     si

    ; Rewind batch file to beginning
    mov     bx, [batch_handle]
    mov     ax, 0x4200          ; Seek from beginning
    xor     cx, cx
    xor     dx, dx
    int     0x21

    ; Scan for :label
.scan_label:
    call    batch_read_line
    jc      .label_not_found

    mov     si, batch_line_buf
    call    skip_spaces
    cmp     byte [si], ':'
    jne     .scan_label

    ; Compare label (skip colon)
    inc     si
    mov     di, batch_goto_target
.cmp_label:
    lodsb
    ; Uppercase
    cmp     al, 'a'
    jb      .no_up
    cmp     al, 'z'
    ja      .no_up
    sub     al, 0x20
.no_up:
    mov     ah, [di]
    inc     di
    cmp     al, ah
    jne     .scan_label
    test    al, al
    jz      .found_label
    cmp     al, ' '
    jne     .cmp_label
    cmp     ah, 0
    je      .found_label
    jmp     .scan_label

.found_label:
    popa
    ret

.label_not_found:
    ; Label not found - print error
    push    dx
    mov     dx, batch_label_err
    mov     ah, 0x09
    int     0x21
    pop     dx
    mov     byte [batch_active], 0
    popa
    ret

; ---------------------------------------------------------------------------
; batch_call_restore - Restore parent batch state after CALL returns
; ---------------------------------------------------------------------------
batch_call_restore:
    pusha

    mov     byte [batch_call_depth], 0

    ; Restore handle
    mov     ax, [batch_save_handle]
    mov     [batch_handle], ax

    ; Restore file position
    mov     bx, ax
    mov     ax, 0x4200          ; Seek from beginning
    mov     dx, word [batch_save_pos]
    mov     cx, word [batch_save_pos + 2]
    int     0x21

    ; Restore filename
    mov     si, batch_save_file
    mov     di, batch_file
.restore_file:
    lodsb
    stosb
    test    al, al
    jnz     .restore_file

    ; Restore parameters
    mov     si, batch_save_params
    mov     di, batch_params
.restore_params:
    lodsb
    stosb
    test    al, al
    jnz     .restore_params

    popa
    ret

; ---------------------------------------------------------------------------
; batch_if - Process IF command
; Supports: IF EXIST file, IF ERRORLEVEL n, IF string1==string2
; Also: IF NOT ...
; ---------------------------------------------------------------------------
batch_if:
    pusha

    ; Check for NOT
    push    si
    mov     di, .str_not
    mov     cx, 4
    repe    cmpsb
    pop     si
    jne     .no_not
    add     si, 4               ; Skip "NOT "
    call    skip_spaces
    mov     byte [batch_if_negate], 1
    jmp     .check_condition
.no_not:
    mov     byte [batch_if_negate], 0

.check_condition:
    ; Check EXIST
    push    si
    mov     di, .str_exist
    mov     cx, 6
    repe    cmpsb
    pop     si
    jne     .check_errorlevel
    add     si, 6
    call    skip_spaces

    ; Get filename
    mov     dx, si
    ; Try to open file
    mov     ax, 0x3D00
    int     0x21
    jc      .exist_false
    ; File exists - close it
    mov     bx, ax
    mov     ah, 0x3E
    int     0x21
    mov     al, 1               ; Condition true
    jmp     .apply_condition

.exist_false:
    xor     al, al              ; Condition false
    jmp     .apply_condition

.check_errorlevel:
    ; Check ERRORLEVEL
    push    si
    mov     di, .str_errorlevel
    mov     cx, 10
    repe    cmpsb
    pop     si
    jne     .check_string
    add     si, 10
    call    skip_spaces

    ; Parse number
    call    .parse_number       ; AX = number
    cmp     [last_errorlevel], ax
    jae     .el_true
    xor     al, al
    jmp     .apply_condition
.el_true:
    mov     al, 1
    jmp     .apply_condition

.check_string:
    ; String comparison: string1==string2 or "string1"=="string2"
    ; SI points to start of comparison

    ; Parse first string into batch_str1
    mov     di, batch_str1
    call    .parse_if_string

    ; Check for ==
    cmp     byte [si], '='
    jne     .str_no_match
    inc     si
    cmp     byte [si], '='
    jne     .str_no_match
    inc     si

    ; Parse second string into batch_str2
    mov     di, batch_str2
    call    .parse_if_string

    ; Compare strings
    push    si
    mov     si, batch_str1
    mov     di, batch_str2
.str_cmp_loop:
    lodsb
    mov     ah, [di]
    inc     di
    cmp     al, ah
    jne     .str_not_equal
    test    al, al
    jnz     .str_cmp_loop
    ; Strings equal
    pop     si
    mov     al, 1
    jmp     .apply_condition

.str_not_equal:
    pop     si
.str_no_match:
    xor     al, al
    jmp     .apply_condition

; Parse string for IF comparison (handles quotes)
; Input: SI = source, DI = destination buffer
; Output: SI advanced past string, DI buffer filled
.parse_if_string:
    cmp     byte [si], '"'
    je      .parse_quoted
    ; Unquoted: read until space or = or end
.parse_unquoted:
    lodsb
    cmp     al, ' '
    je      .parse_str_done
    cmp     al, '='
    je      .parse_str_backup
    test    al, al
    jz      .parse_str_backup
    stosb
    jmp     .parse_unquoted
.parse_str_backup:
    dec     si
.parse_str_done:
    mov     byte [di], 0
    ret
.parse_quoted:
    inc     si              ; Skip opening quote
.parse_q_loop:
    lodsb
    cmp     al, '"'
    je      .parse_str_done
    test    al, al
    jz      .parse_str_done
    stosb
    jmp     .parse_q_loop

.apply_condition:
    ; Apply NOT if needed
    test    byte [batch_if_negate], 1
    jz      .no_negate
    xor     al, 1
.no_negate:

    test    al, al
    jz      .condition_false

    ; Condition true: find and execute the command after the condition
    ; Skip to the command part (after filename/number/string)
.skip_to_cmd:
    lodsb
    cmp     al, 0
    je      .condition_false
    cmp     al, ' '
    jne     .skip_to_cmd
    call    skip_spaces

    ; Execute the rest as a command
    mov     di, cmd_buffer + 2
.copy_cmd:
    lodsb
    stosb
    test    al, al
    jnz     .copy_cmd

    mov     si, cmd_buffer + 2
    call    skip_spaces
    call    try_internal_cmd
    test    al, al
    jnz     .if_done
    call    try_external_cmd

.if_done:
.condition_false:
    popa
    ret

.parse_number:
    xor     ax, ax
    xor     cx, cx
.pn_loop:
    mov     cl, [si]
    cmp     cl, '0'
    jb      .pn_done
    cmp     cl, '9'
    ja      .pn_done
    sub     cl, '0'
    push    cx
    mov     cx, 10
    mul     cx
    pop     cx
    add     ax, cx
    inc     si
    jmp     .pn_loop
.pn_done:
    ret

.str_not        db  'NOT '
.str_exist      db  'EXIST '
.str_errorlevel db  'ERRORLEVEL'

; ---------------------------------------------------------------------------
; batch_substitute - Perform %N parameter substitution
; Input: DS:SI = line buffer (modified in place)
; Substitutes %0 with batch filename, %1-%9 with parameters
; ---------------------------------------------------------------------------
batch_substitute:
    pusha

    ; Copy line to temp buffer while substituting
    mov     si, batch_line_buf
    mov     di, batch_subst_buf

.subst_loop:
    lodsb
    test    al, al
    jz      .subst_done

    cmp     al, '%'
    jne     .store_char

    ; Found %, check next char
    mov     al, [si]
    cmp     al, '0'
    jb      .not_param
    cmp     al, '9'
    ja      .not_param

    ; It's %0-%9 - substitute parameter
    sub     al, '0'                 ; AL = parameter number (0-9)
    inc     si                      ; Skip the digit

    ; Get the parameter
    push    si
    push    di
    xor     bh, bh
    mov     bl, al                  ; BX = param number
    call    batch_get_param         ; SI = pointer to param string
    pop     di

    ; Copy parameter value to output
.copy_param:
    lodsb
    test    al, al
    jz      .param_done
    stosb
    jmp     .copy_param

.param_done:
    pop     si
    jmp     .subst_loop

.not_param:
    ; Just a % followed by something else, store the %
    mov     al, '%'

.store_char:
    stosb
    jmp     .subst_loop

.subst_done:
    stosb                           ; Store null terminator

    ; Copy result back to original buffer
    mov     si, batch_subst_buf
    mov     di, batch_line_buf
.copy_back:
    lodsb
    stosb
    test    al, al
    jnz     .copy_back

    popa
    ret

; ---------------------------------------------------------------------------
; batch_get_param - Get pointer to Nth parameter
; Input: BX = parameter number (0-9)
; Output: SI = pointer to ASCIIZ parameter (or empty string)
; ---------------------------------------------------------------------------
batch_get_param:
    ; %0 = batch filename
    test    bx, bx
    jz      .return_filename

    ; %1-%9 = parameters from batch_params
    mov     si, batch_params
    mov     cx, bx                  ; Number of params to skip

    ; Skip leading spaces
    call    .skip_sp

.skip_params:
    dec     cx
    jz      .found_param

    ; Skip current parameter (until space or end)
.skip_word:
    lodsb
    test    al, al
    jz      .empty_param            ; Ran out of parameters
    cmp     al, ' '
    jne     .skip_word

    ; Skip spaces between params
    call    .skip_sp
    cmp     byte [si], 0
    je      .empty_param
    jmp     .skip_params

.found_param:
    ; SI points to start of parameter
    ; Need to null-terminate it in a temp buffer
    mov     di, batch_param_temp
.copy_p:
    lodsb
    test    al, al
    jz      .end_p
    cmp     al, ' '
    je      .end_p
    stosb
    jmp     .copy_p
.end_p:
    mov     byte [di], 0
    mov     si, batch_param_temp
    ret

.empty_param:
    mov     si, batch_empty_str
    ret

.return_filename:
    mov     si, batch_file
    ret

.skip_sp:
    cmp     byte [si], ' '
    jne     .skip_sp_done
    inc     si
    jmp     .skip_sp
.skip_sp_done:
    ret

; ---------------------------------------------------------------------------
; Batch data
; ---------------------------------------------------------------------------
batch_subst_buf     times 256 db 0  ; Temp buffer for substitution
batch_param_temp    times 128 db 0  ; Temp buffer for single parameter
batch_empty_str     db  0           ; Empty string
batch_line_buf  times 256 db 0
batch_char_buf  db  0
batch_cmd_word  times 12 db 0
batch_cmd_args  dw  0
batch_goto_target times 32 db 0
batch_if_negate db  0
batch_str1      times 64 db 0   ; IF string comparison buffer 1
batch_str2      times 64 db 0   ; IF string comparison buffer 2
batch_err_open  db  'Batch file not found', 0x0D, 0x0A, '$'
batch_pause_msg db  'Press any key to continue . . . $'
batch_label_err db  'Label not found', 0x0D, 0x0A, '$'
batch_call_nested db 'Nested CALL not supported', 0x0D, 0x0A, '$'
