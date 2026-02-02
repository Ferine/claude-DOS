; ===========================================================================
; claudeDOS COMMAND.COM - Command Interpreter
; Assembled as a flat .COM binary (loaded at PSP:0100h)
; ===========================================================================

    CPU     186
    ORG     0x0100

%include "constants.inc"

; ===========================================================================
; RESIDENT PORTION
; Stays in memory. Contains INT handlers and reload logic.
; ===========================================================================

resident_start:
    jmp     transient_start

; ---------------------------------------------------------------------------
; Resident data
; ---------------------------------------------------------------------------
shell_psp       dw  0           ; Our PSP segment
parent_psp      dw  0           ; Parent PSP (usually kernel)
env_segment     dw  0           ; Environment segment
comspec_path    db  'A:\COMMAND.COM', 0
                times 64 - ($ - comspec_path) db 0

; Saved interrupt vectors
old_int22       dd  0           ; Previous terminate vector
old_int23       dd  0           ; Previous Ctrl+C vector
old_int24       dd  0           ; Previous critical error vector

; Error level from last program
last_errorlevel dw  0

; Batch file state
batch_active    db  0           ; 1 = executing a batch file
batch_handle    dw  0xFFFF      ; File handle for current batch
batch_line      dw  0           ; Current line number
batch_file      times 128 db 0  ; Batch file path
batch_params    times 128 db 0  ; Batch file parameters (%0-%9)

; Batch CALL stack (single level)
batch_call_depth db  0          ; 0 = top level, 1 = in CALL
batch_save_handle dw 0xFFFF     ; Saved parent handle
batch_save_pos   dd  0          ; Saved file position
batch_save_file  times 128 db 0 ; Saved parent batch filename
batch_save_params times 128 db 0 ; Saved parent parameters

; Echo state
echo_on         db  1           ; 1 = echo is on

; ---------------------------------------------------------------------------
; INT 23h handler - Ctrl+C
; ---------------------------------------------------------------------------
int23_handler:
    ; If in batch mode, ask whether to terminate
    push    ds
    push    cs
    pop     ds
    cmp     byte [batch_active], 1
    pop     ds
    jne     .just_return

    ; Print "Terminate batch job (Y/N)?"
    push    ax
    push    dx
    mov     ah, 0x09
    push    cs
    pop     ds
    mov     dx, msg_ctrlc_batch
    int     0x21
    ; Get response
    mov     ah, 0x01
    int     0x21
    push    ax
    mov     ah, 0x02
    mov     dl, 0x0D
    int     0x21
    mov     dl, 0x0A
    int     0x21
    pop     ax
    or      al, 0x20            ; Lowercase
    cmp     al, 'y'
    pop     dx
    pop     ax
    jne     .just_return

    ; Terminate batch
    push    cs
    pop     ds
    mov     byte [batch_active], 0

.just_return:
    iret

; ---------------------------------------------------------------------------
; INT 24h handler - Critical Error
; ---------------------------------------------------------------------------
int24_handler:
    ; Simple handler: fail the operation
    mov     al, 3               ; Fail
    iret

; ---------------------------------------------------------------------------
; Ctrl+C batch message
; ---------------------------------------------------------------------------
msg_ctrlc_batch db  0x0D, 0x0A, 'Terminate batch job (Y/N)? $'

; ===========================================================================
; TRANSIENT PORTION
; Can be overwritten by programs. Reloaded if checksum fails.
; ===========================================================================

transient_start:
    ; Save our PSP
    mov     [shell_psp], cs

    ; Install our interrupt handlers
    mov     ax, 0x2523          ; Set INT 23h
    mov     dx, int23_handler
    push    cs
    pop     ds
    int     0x21

    mov     ax, 0x2524          ; Set INT 24h
    mov     dx, int24_handler
    int     0x21

    ; Check if AUTOEXEC.BAT exists and run it (Phase 8)
    ; For now, skip batch processing

    ; Fall through to main command loop

; ---------------------------------------------------------------------------
; Main command loop
; ---------------------------------------------------------------------------
cmd_loop:
    ; Reset to our own segments
    push    cs
    pop     ds
    push    cs
    pop     es

    ; Display prompt
    call    show_prompt

    ; Read command line
    mov     dx, cmd_buffer
    mov     byte [cmd_buffer], 126  ; Max length
    mov     ah, 0x0A            ; Buffered input
    int     0x21

    ; Print newline after input
    mov     ah, 0x02
    mov     dl, 0x0D
    int     0x21
    mov     dl, 0x0A
    int     0x21

    ; Check if empty input
    cmp     byte [cmd_buffer + 1], 0
    je      cmd_loop

    ; Null-terminate the command (replace CR with 0)
    xor     bh, bh
    mov     bl, [cmd_buffer + 1] ; Length
    mov     byte [cmd_buffer + 2 + bx], 0

    ; Parse redirection operators (>, >>, <)
    call    parse_redirection

    ; Parse and execute
    mov     si, cmd_buffer + 2   ; Point to command text
    call    skip_spaces

    ; Check for empty after spaces
    cmp     byte [si], 0
    je      cmd_loop

    ; Set up redirection before executing command
    call    setup_redirection
    jc      .redir_failed

    ; Try internal commands first
    call    try_internal_cmd
    test    al, al               ; AL=1 if handled
    jnz     .cmd_done

    ; Try to run as external command
    call    try_external_cmd

.cmd_done:
    ; Clean up redirection after command
    call    cleanup_redirection
    jmp     cmd_loop

.redir_failed:
    ; Redirection setup failed - already printed error
    jmp     cmd_loop

; ---------------------------------------------------------------------------
; show_prompt - Display the command prompt
; Interprets prompt_string with $X tokens
; ---------------------------------------------------------------------------
show_prompt:
    pusha

    mov     si, prompt_string
.prompt_loop:
    lodsb
    test    al, al
    jz      .prompt_done

    cmp     al, '$'
    jne     .print_char

    ; Handle token
    lodsb
    test    al, al
    jz      .prompt_done

    ; Uppercase the token
    cmp     al, 'a'
    jb      .check_token
    cmp     al, 'z'
    ja      .check_token
    sub     al, 0x20

.check_token:
    cmp     al, 'P'             ; $P = current path
    je      .token_path
    cmp     al, 'N'             ; $N = current drive
    je      .token_drive
    cmp     al, 'G'             ; $G = >
    je      .token_gt
    cmp     al, 'L'             ; $L = <
    je      .token_lt
    cmp     al, 'Q'             ; $Q = =
    je      .token_eq
    cmp     al, 'B'             ; $B = |
    je      .token_pipe
    cmp     al, '$'             ; $$ = $
    je      .token_dollar
    cmp     al, '_'             ; $_ = CRLF
    je      .token_crlf
    cmp     al, 'D'             ; $D = date
    je      .token_date
    cmp     al, 'T'             ; $T = time
    je      .token_time
    ; Unknown token - print literal
    mov     dl, '$'
    mov     ah, 0x02
    int     0x21
.print_char:
    mov     dl, al
    mov     ah, 0x02
    int     0x21
    jmp     .prompt_loop

.token_path:
    ; Print drive:\path
    push    si
    mov     ah, 0x19            ; Get current drive
    int     0x21
    push    ax                  ; Save drive number
    add     al, 'A'
    mov     dl, al
    mov     ah, 0x02
    int     0x21
    mov     dl, ':'
    int     0x21
    mov     dl, '\'
    int     0x21
    ; Get current directory via INT 21h/47h
    pop     ax                  ; Drive number
    inc     al                  ; 0=default, 1=A:, etc.
    mov     dl, al
    push    cs
    pop     ds
    mov     si, prompt_path_buf
    mov     ah, 0x47
    int     0x21
    ; Print the path
    mov     si, prompt_path_buf
.print_path:
    lodsb
    test    al, al
    jz      .path_done
    mov     dl, al
    mov     ah, 0x02
    int     0x21
    jmp     .print_path
.path_done:
    pop     si
    jmp     .prompt_loop

.token_drive:
    mov     ah, 0x19
    int     0x21
    add     al, 'A'
    mov     dl, al
    mov     ah, 0x02
    int     0x21
    jmp     .prompt_loop

.token_gt:
    mov     dl, '>'
    mov     ah, 0x02
    int     0x21
    jmp     .prompt_loop

.token_lt:
    mov     dl, '<'
    mov     ah, 0x02
    int     0x21
    jmp     .prompt_loop

.token_eq:
    mov     dl, '='
    mov     ah, 0x02
    int     0x21
    jmp     .prompt_loop

.token_pipe:
    mov     dl, '|'
    mov     ah, 0x02
    int     0x21
    jmp     .prompt_loop

.token_dollar:
    mov     dl, '$'
    mov     ah, 0x02
    int     0x21
    jmp     .prompt_loop

.token_crlf:
    mov     dl, 0x0D
    mov     ah, 0x02
    int     0x21
    mov     dl, 0x0A
    int     0x21
    jmp     .prompt_loop

.token_date:
    push    si
    mov     ah, 0x2A
    int     0x21
    ; Print MM-DD-YYYY
    mov     al, dh
    call    .print_2digit
    mov     dl, '-'
    mov     ah, 0x02
    int     0x21
    pop     si
    push    si
    mov     ah, 0x2A
    int     0x21
    mov     al, dl
    call    .print_2digit
    mov     dl, '-'
    mov     ah, 0x02
    int     0x21
    pop     si
    push    si
    mov     ah, 0x2A
    int     0x21
    mov     ax, cx
    call    print_dec16
    pop     si
    jmp     .prompt_loop

.token_time:
    push    si
    mov     ah, 0x2C
    int     0x21
    mov     al, ch
    call    .print_2digit
    mov     dl, ':'
    mov     ah, 0x02
    int     0x21
    pop     si
    push    si
    mov     ah, 0x2C
    int     0x21
    mov     al, cl
    call    .print_2digit
    pop     si
    jmp     .prompt_loop

.print_2digit:
    ; Print AL as 2 digits with leading zero
    cmp     al, 10
    jae     .p2d_no_lead
    push    ax
    mov     dl, '0'
    mov     ah, 0x02
    int     0x21
    pop     ax
.p2d_no_lead:
    xor     ah, ah
    call    print_dec16
    ret

.prompt_done:
    popa
    ret

; ---------------------------------------------------------------------------
; skip_spaces - Advance SI past spaces
; ---------------------------------------------------------------------------
skip_spaces:
    cmp     byte [si], ' '
    jne     .done
    inc     si
    jmp     skip_spaces
.done:
    ret

; ---------------------------------------------------------------------------
; try_internal_cmd - Check if command matches an internal command
; Input: DS:SI = command line (first word)
; Output: AL = 1 if handled, 0 if not
; ---------------------------------------------------------------------------
try_internal_cmd:
    push    si

    ; Copy first word to cmd_word (uppercase)
    mov     di, cmd_word
    xor     cx, cx
.copy_word:
    lodsb
    cmp     al, ' '
    je      .word_done
    cmp     al, 0
    je      .word_done
    cmp     al, 0x0D
    je      .word_done
    ; Uppercase
    cmp     al, 'a'
    jb      .store_w
    cmp     al, 'z'
    ja      .store_w
    sub     al, 0x20
.store_w:
    stosb
    inc     cx
    cmp     cx, 16              ; Max command length
    jb      .copy_word
.word_done:
    mov     byte [di], 0        ; Null terminate
    mov     [cmd_args], si       ; Save pointer to arguments

    ; Compare against internal command table
    mov     bx, internal_cmds
.check_cmd:
    mov     si, [bx]            ; Get command name pointer
    test    si, si
    jz      .not_internal       ; End of table

    ; Compare with cmd_word
    mov     di, cmd_word
    call    str_equal
    je      .found_cmd

    add     bx, 4               ; Next entry (name ptr + handler ptr)
    jmp     .check_cmd

.found_cmd:
    ; Call the handler
    mov     si, [cmd_args]       ; Pass args pointer in SI
    call    skip_spaces
    call    [bx + 2]            ; Call handler
    pop     si
    mov     al, 1               ; Handled
    ret

.not_internal:
    pop     si
    xor     al, al              ; Not handled
    ret

; ---------------------------------------------------------------------------
; str_equal - Compare two null-terminated strings
; Input: DS:SI, ES:DI
; Output: ZF set if equal
; ---------------------------------------------------------------------------
str_equal:
    push    si
    push    di
.cmp_loop:
    lodsb
    mov     ah, [di]
    inc     di
    cmp     al, ah
    jne     .not_eq
    test    al, al
    jz      .equal
    jmp     .cmp_loop
.not_eq:
    or      al, 1               ; Clear ZF
    pop     di
    pop     si
    ret
.equal:
    xor     al, al              ; Set ZF
    pop     di
    pop     si
    ret

; ---------------------------------------------------------------------------
; try_external_cmd - Try to run as external .COM/.EXE program
; Input: cmd_word has the command name, cmd_args has arguments
; ---------------------------------------------------------------------------
try_external_cmd:
    push    bx
    push    cx
    push    dx
    push    si
    push    di
    push    es
    push    ds

    ; Build filename: cmd_word + ".COM"
    mov     si, cmd_word
    mov     di, ext_filename
    ; Copy command word
.copy_cmd:
    lodsb
    test    al, al
    jz      .append_com
    stosb
    jmp     .copy_cmd

.append_com:
    ; Append ".COM\0"
    mov     byte [di], '.'
    mov     byte [di+1], 'C'
    mov     byte [di+2], 'O'
    mov     byte [di+3], 'M'
    mov     byte [di+4], 0

    ; Build EXEC parameter block
    ; Word: environment segment (0 = inherit)
    mov     word [exec_pblock], 0

    ; Build command tail at cmd_tail_buf in PSP:80h format
    ; First byte = length, then space + args, terminated with CR
    mov     si, [cmd_args]
    mov     di, cmd_tail_buf
    mov     byte [di], 0            ; Length (filled in later)
    inc     di
    xor     cl, cl                  ; Count
    ; Add leading space
    mov     byte [di], ' '
    inc     di
    inc     cl
.copy_args:
    lodsb
    test    al, al
    jz      .args_done
    cmp     al, 0x0D
    je      .args_done
    stosb
    inc     cl
    cmp     cl, 126
    jae     .args_done
    jmp     .copy_args
.args_done:
    mov     byte [di], 0x0D         ; CR terminator
    mov     [cmd_tail_buf], cl      ; Store length

    ; Set command tail pointer in param block
    mov     [exec_pblock + 2], word cmd_tail_buf
    mov     [exec_pblock + 4], cs

    ; Set FCB1 pointer (default FCB)
    mov     [exec_pblock + 6], word 0x005C
    mov     [exec_pblock + 8], cs

    ; Set FCB2 pointer (default FCB)
    mov     [exec_pblock + 10], word 0x006C
    mov     [exec_pblock + 12], cs

    ; Try .COM first
    push    cs
    pop     ds
    mov     dx, ext_filename
    push    cs
    pop     es
    mov     bx, exec_pblock
    mov     ax, 0x4B00              ; EXEC, load and execute
    int     0x21
    jnc     .exec_done              ; Success

    ; .COM failed, try .EXE
    ; Find the dot in ext_filename and change extension
    mov     di, ext_filename
.find_dot:
    cmp     byte [di], '.'
    je      .change_ext
    cmp     byte [di], 0
    je      .not_found              ; No dot found?
    inc     di
    jmp     .find_dot

.change_ext:
    mov     byte [di+1], 'E'
    mov     byte [di+2], 'X'
    mov     byte [di+3], 'E'

    push    cs
    pop     ds
    mov     dx, ext_filename
    push    cs
    pop     es
    mov     bx, exec_pblock
    mov     ax, 0x4B00
    int     0x21
    jnc     .exec_done

.not_found:
    ; Neither .COM nor .EXE found in current directory
    ; Try searching PATH
    call    search_path_for_cmd
    test    al, al
    jnz     .exec_done              ; Found and executed via PATH

    ; Not found anywhere
    push    cs
    pop     ds
    mov     dx, msg_bad_cmd
    mov     ah, 0x09
    int     0x21
    jmp     .ext_ret

.exec_done:
    ; Program ran and returned successfully
    ; Save errorlevel
    mov     ah, 0x4D
    int     0x21
    push    cs
    pop     ds
    mov     [last_errorlevel], ax

.ext_ret:
    ; Restore our segments (they may have been clobbered)
    pop     ds
    pop     es
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    push    cs
    pop     ds
    push    cs
    pop     es
    ret

; ---------------------------------------------------------------------------
; search_path_for_cmd - Search PATH directories for command
; Uses cmd_word for command name, exec_pblock already set up
; Output: AL = 1 if found and executed, 0 if not found
; ---------------------------------------------------------------------------
search_path_for_cmd:
    push    bx
    push    cx
    push    dx
    push    si
    push    di

    ; Check if PATH is empty
    cmp     byte [path_value], 0
    je      .path_not_found

    ; SI will walk through path_value
    mov     si, path_value

.try_next_dir:
    ; Check if end of PATH
    cmp     byte [si], 0
    je      .path_not_found

    ; Build: directory + "\" + cmd_word + ".COM"
    mov     di, ext_filename

    ; Copy directory until ; or end
.copy_dir:
    lodsb
    test    al, al
    jz      .dir_done
    cmp     al, ';'
    je      .dir_done
    stosb
    jmp     .copy_dir

.dir_done:
    ; Add backslash if not already there
    cmp     byte [di-1], '\'
    je      .has_slash
    mov     byte [di], '\'
    inc     di
.has_slash:

    ; Save SI position (might be at ; or NUL)
    push    si

    ; Copy command name
    push    di                      ; Save position for extension
    mov     si, cmd_word
.copy_cmd_path:
    lodsb
    test    al, al
    jz      .add_com
    stosb
    jmp     .copy_cmd_path

.add_com:
    ; Add ".COM"
    mov     byte [di], '.'
    mov     byte [di+1], 'C'
    mov     byte [di+2], 'O'
    mov     byte [di+3], 'M'
    mov     byte [di+4], 0
    pop     di                      ; DI = position where we'll change extension

    ; Try to execute
    push    cs
    pop     ds
    mov     dx, ext_filename
    push    cs
    pop     es
    mov     bx, exec_pblock
    mov     ax, 0x4B00
    int     0x21
    jnc     .path_found

    ; Try .EXE
    push    di
    mov     di, ext_filename
.find_dot_path:
    cmp     byte [di], '.'
    je      .change_to_exe
    cmp     byte [di], 0
    je      .try_next_path
    inc     di
    jmp     .find_dot_path

.change_to_exe:
    mov     byte [di+1], 'E'
    mov     byte [di+2], 'X'
    mov     byte [di+3], 'E'
    pop     di

    push    cs
    pop     ds
    mov     dx, ext_filename
    push    cs
    pop     es
    mov     bx, exec_pblock
    mov     ax, 0x4B00
    int     0x21
    jnc     .path_found

.try_next_path:
    pop     si                      ; Restore position in PATH
    ; If we stopped at NUL, we're done
    cmp     byte [si-1], 0
    je      .path_not_found
    ; Otherwise skip any extra separators
    jmp     .try_next_dir

.path_found:
    pop     si                      ; Clean up stack
    ; Get error level
    mov     ah, 0x4D
    int     0x21
    push    cs
    pop     ds
    mov     [last_errorlevel], ax
    mov     al, 1                   ; Return success
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    ret

.path_not_found:
    xor     al, al                  ; Return failure
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    ret

; External command data
ext_filename    times 80 db 0       ; Filename buffer (COMMAND.COM, etc)
exec_pblock:                         ; EXEC parameter block (14 bytes)
    dw      0                       ; Environment segment (0=inherit)
    dw      0, 0                    ; Command tail pointer (off, seg)
    dw      0, 0                    ; FCB1 pointer (off, seg)
    dw      0, 0                    ; FCB2 pointer (off, seg)
cmd_tail_buf    times 130 db 0      ; Command tail in PSP:80h format

; ---------------------------------------------------------------------------
; Internal command table
; Each entry: dw name_ptr, dw handler_ptr
; ---------------------------------------------------------------------------
internal_cmds:
    dw      cmd_name_dir,    cmd_dir
    dw      cmd_name_cls,    cmd_cls
    dw      cmd_name_ver,    cmd_ver
    dw      cmd_name_echo,   cmd_echo
    dw      cmd_name_type,   cmd_type
    dw      cmd_name_copy,   cmd_copy
    dw      cmd_name_del,    cmd_del
    dw      cmd_name_erase,  cmd_del       ; ERASE = DEL
    dw      cmd_name_ren,    cmd_ren
    dw      cmd_name_rename, cmd_ren       ; RENAME = REN
    dw      cmd_name_md,     cmd_md
    dw      cmd_name_mkdir,  cmd_md        ; MKDIR = MD
    dw      cmd_name_rd,     cmd_rd
    dw      cmd_name_rmdir,  cmd_rd        ; RMDIR = RD
    dw      cmd_name_cd,     cmd_cd
    dw      cmd_name_chdir,  cmd_cd        ; CHDIR = CD
    dw      cmd_name_set,    cmd_set
    dw      cmd_name_path,   cmd_path
    dw      cmd_name_prompt, cmd_prompt
    dw      cmd_name_date,   cmd_date
    dw      cmd_name_time,   cmd_time
    dw      cmd_name_vol,    cmd_vol
    dw      cmd_name_help,   cmd_help
    dw      cmd_name_exit,   cmd_exit
    dw      0, 0                           ; End of table

; Command name strings
cmd_name_dir    db  'DIR', 0
cmd_name_cls    db  'CLS', 0
cmd_name_ver    db  'VER', 0
cmd_name_echo   db  'ECHO', 0
cmd_name_type   db  'TYPE', 0
cmd_name_copy   db  'COPY', 0
cmd_name_del    db  'DEL', 0
cmd_name_erase  db  'ERASE', 0
cmd_name_ren    db  'REN', 0
cmd_name_rename db  'RENAME', 0
cmd_name_md     db  'MD', 0
cmd_name_mkdir  db  'MKDIR', 0
cmd_name_rd     db  'RD', 0
cmd_name_rmdir  db  'RMDIR', 0
cmd_name_cd     db  'CD', 0
cmd_name_chdir  db  'CHDIR', 0
cmd_name_set    db  'SET', 0
cmd_name_path   db  'PATH', 0
cmd_name_prompt db  'PROMPT', 0
cmd_name_date   db  'DATE', 0
cmd_name_time   db  'TIME', 0
cmd_name_vol    db  'VOL', 0
cmd_name_help   db  'HELP', 0
cmd_name_exit   db  'EXIT', 0

; ---------------------------------------------------------------------------
; Command line data
; ---------------------------------------------------------------------------
cmd_buffer:
    db      126                 ; Max input length
    db      0                   ; Actual length (filled by DOS)
    times   128 db 0            ; Input buffer

cmd_word        times 18 db 0   ; Current command word (uppercase)
cmd_args        dw  0           ; Pointer to arguments
prompt_path_buf times 68 db 0   ; Buffer for current path in prompt

; Messages
msg_bad_cmd     db  'Bad command or file name', 0x0D, 0x0A, '$'

; ---------------------------------------------------------------------------
; Include internal command implementations
; ---------------------------------------------------------------------------
%include "parser.asm"
%include "internal/dir_cmd.asm"
%include "internal/copy_cmd.asm"
%include "internal/del_cmd.asm"
%include "internal/type_cmd.asm"
%include "internal/ren_cmd.asm"
%include "internal/md_cmd.asm"
%include "internal/rd_cmd.asm"
%include "internal/cd_cmd.asm"
%include "internal/set_cmd.asm"
%include "internal/echo_cmd.asm"
%include "internal/cls_cmd.asm"
%include "internal/ver_cmd.asm"
%include "internal/date_cmd.asm"
%include "internal/time_cmd.asm"
%include "internal/path_cmd.asm"
%include "internal/prompt_cmd.asm"
%include "internal/vol_cmd.asm"
%include "internal/help_cmd.asm"

; Batch file interpreter
%include "batch.asm"

; I/O redirection
%include "redirect.asm"

; EXIT command (inline - just terminate)
cmd_exit:
    mov     ax, 0x4C00
    int     0x21
    ret
