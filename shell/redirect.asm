; ===========================================================================
; claudeDOS I/O Redirection
; Implements: > (output), >> (append), < (input)
; ===========================================================================

; Redirection state
redir_stdin_save    dw  0xFFFF      ; Saved stdin handle (0xFFFF = not redirected)
redir_stdout_save   dw  0xFFFF      ; Saved stdout handle
redir_stdin_file    dw  0xFFFF      ; Input file handle
redir_stdout_file   dw  0xFFFF      ; Output file handle
redir_out_filename  times 80 db 0   ; Output filename buffer
redir_in_filename   times 80 db 0   ; Input filename buffer
redir_out_append    db  0           ; 1 = append mode (>>)

; ---------------------------------------------------------------------------
; parse_redirection - Parse and set up I/O redirection from command line
; Input: DS:SI = command line
; Output: Command line modified (redirection parts removed)
;         Redirection state variables set
;         CF set on error
; ---------------------------------------------------------------------------
parse_redirection:
    pusha

    ; Reset redirection state
    mov     word [redir_stdin_save], 0xFFFF
    mov     word [redir_stdout_save], 0xFFFF
    mov     word [redir_stdin_file], 0xFFFF
    mov     word [redir_stdout_file], 0xFFFF
    mov     byte [redir_out_append], 0

    ; Scan command line for redirection operators
    mov     si, cmd_buffer + 2
    mov     di, si                  ; DI = write position (to remove redir parts)

.scan_loop:
    lodsb
    test    al, al
    jz      .scan_done

    cmp     al, '>'
    je      .found_output
    cmp     al, '<'
    je      .found_input

    ; Regular character - copy to output
    stosb
    jmp     .scan_loop

.found_output:
    ; Check for >> (append)
    cmp     byte [si], '>'
    jne     .output_create
    inc     si                      ; Skip second >
    mov     byte [redir_out_append], 1

.output_create:
    ; Skip spaces
    call    .skip_sp
    ; Copy filename
    push    di
    mov     di, redir_out_filename
    call    .copy_filename
    pop     di
    jmp     .scan_loop

.found_input:
    ; Skip spaces
    call    .skip_sp
    ; Copy filename
    push    di
    mov     di, redir_in_filename
    call    .copy_filename
    pop     di
    jmp     .scan_loop

.scan_done:
    ; Null-terminate the cleaned command
    mov     byte [di], 0

    ; Update command length
    mov     ax, di
    sub     ax, cmd_buffer + 2
    mov     [cmd_buffer + 1], al

    popa
    clc
    ret

.skip_sp:
    cmp     byte [si], ' '
    jne     .skip_sp_done
    inc     si
    jmp     .skip_sp
.skip_sp_done:
    ret

.copy_filename:
    ; Copy until space or redirection char or end
.copy_fn_loop:
    lodsb
    test    al, al
    jz      .copy_fn_end
    cmp     al, ' '
    je      .copy_fn_end
    cmp     al, '>'
    je      .copy_fn_backup
    cmp     al, '<'
    je      .copy_fn_backup
    stosb
    jmp     .copy_fn_loop
.copy_fn_backup:
    dec     si                      ; Back up so we process this char
.copy_fn_end:
    mov     byte [di], 0
    ret

; ---------------------------------------------------------------------------
; setup_redirection - Open files and redirect handles
; Call after parse_redirection, before executing command
; Output: CF set on error
; ---------------------------------------------------------------------------
setup_redirection:
    pusha

    ; Check for input redirection
    cmp     byte [redir_in_filename], 0
    je      .check_output

    ; Save original stdin (handle 0)
    mov     bx, 0                   ; stdin
    mov     ah, 0x45                ; Dup
    int     0x21
    jc      .redir_error
    mov     [redir_stdin_save], ax

    ; Open input file
    mov     dx, redir_in_filename
    mov     ax, 0x3D00              ; Open read-only
    int     0x21
    jc      .restore_stdin_fail
    mov     [redir_stdin_file], ax

    ; Redirect stdin to file (force dup)
    mov     bx, ax                  ; BX = file handle
    mov     cx, 0                   ; CX = stdin
    mov     ah, 0x46                ; Dup2/ForceDup
    int     0x21
    jc      .close_stdin_fail

.check_output:
    ; Check for output redirection
    cmp     byte [redir_out_filename], 0
    je      .setup_done

    ; Save original stdout (handle 1)
    mov     bx, 1                   ; stdout
    mov     ah, 0x45                ; Dup
    int     0x21
    jc      .redir_error
    mov     [redir_stdout_save], ax

    ; Open/create output file
    cmp     byte [redir_out_append], 1
    je      .append_mode

    ; Create new file (truncate if exists)
    mov     dx, redir_out_filename
    xor     cx, cx                  ; Normal attributes
    mov     ah, 0x3C                ; Create
    int     0x21
    jc      .restore_stdout_fail
    mov     [redir_stdout_file], ax
    jmp     .redirect_stdout

.append_mode:
    ; Open existing file for append, or create if doesn't exist
    mov     dx, redir_out_filename
    mov     ax, 0x3D01              ; Open for writing
    int     0x21
    jc      .create_for_append

    ; Seek to end
    mov     [redir_stdout_file], ax
    mov     bx, ax
    mov     ax, 0x4202              ; Seek from end
    xor     cx, cx
    xor     dx, dx
    int     0x21
    jmp     .redirect_stdout

.create_for_append:
    ; File doesn't exist - create it
    mov     dx, redir_out_filename
    xor     cx, cx
    mov     ah, 0x3C
    int     0x21
    jc      .restore_stdout_fail
    mov     [redir_stdout_file], ax

.redirect_stdout:
    ; Redirect stdout to file
    mov     bx, [redir_stdout_file]
    mov     cx, 1                   ; stdout
    mov     ah, 0x46                ; Dup2/ForceDup
    int     0x21
    jc      .close_stdout_fail

.setup_done:
    popa
    clc
    ret

.close_stdin_fail:
    ; Close the input file we opened
    mov     bx, [redir_stdin_file]
    mov     ah, 0x3E
    int     0x21
.restore_stdin_fail:
    ; Restore stdin
    mov     bx, [redir_stdin_save]
    mov     cx, 0
    mov     ah, 0x46
    int     0x21
    mov     word [redir_stdin_save], 0xFFFF
    jmp     .redir_error

.close_stdout_fail:
    mov     bx, [redir_stdout_file]
    mov     ah, 0x3E
    int     0x21
.restore_stdout_fail:
    mov     bx, [redir_stdout_save]
    mov     cx, 1
    mov     ah, 0x46
    int     0x21
    mov     word [redir_stdout_save], 0xFFFF
    jmp     .redir_error

.redir_error:
    ; Print error
    push    cs
    pop     ds
    mov     dx, redir_err_msg
    mov     ah, 0x09
    int     0x21
    popa
    stc
    ret

; ---------------------------------------------------------------------------
; cleanup_redirection - Restore original handles and close files
; Call after command execution
; ---------------------------------------------------------------------------
cleanup_redirection:
    pusha

    ; Restore stdin if it was redirected
    cmp     word [redir_stdin_save], 0xFFFF
    je      .check_stdout_cleanup

    ; Close the redirect file
    mov     bx, [redir_stdin_file]
    cmp     bx, 0xFFFF
    je      .restore_stdin
    mov     ah, 0x3E
    int     0x21

.restore_stdin:
    ; Restore original stdin
    mov     bx, [redir_stdin_save]
    mov     cx, 0
    mov     ah, 0x46
    int     0x21

    ; Close saved handle
    mov     bx, [redir_stdin_save]
    mov     ah, 0x3E
    int     0x21

    mov     word [redir_stdin_save], 0xFFFF
    mov     word [redir_stdin_file], 0xFFFF

.check_stdout_cleanup:
    ; Restore stdout if it was redirected
    cmp     word [redir_stdout_save], 0xFFFF
    je      .cleanup_done

    ; Close the redirect file
    mov     bx, [redir_stdout_file]
    cmp     bx, 0xFFFF
    je      .restore_stdout
    mov     ah, 0x3E
    int     0x21

.restore_stdout:
    ; Restore original stdout
    mov     bx, [redir_stdout_save]
    mov     cx, 1
    mov     ah, 0x46
    int     0x21

    ; Close saved handle
    mov     bx, [redir_stdout_save]
    mov     ah, 0x3E
    int     0x21

    mov     word [redir_stdout_save], 0xFFFF
    mov     word [redir_stdout_file], 0xFFFF

.cleanup_done:
    ; Clear filenames
    mov     byte [redir_out_filename], 0
    mov     byte [redir_in_filename], 0
    mov     byte [redir_out_append], 0

    popa
    ret

redir_err_msg   db  'Error setting up redirection', 0x0D, 0x0A, '$'

; ===========================================================================
; Pipe Support
; Implements: cmd1 | cmd2 [| cmd3 ...]  using temporary files
; ===========================================================================

; Pipe state
pipe_tempfile   db  '\AZPIPE$.$$$', 0
pipe_saved_stdout dw 0xFFFF
pipe_saved_stdin  dw 0xFFFF
pipe_temp_handle  dw 0xFFFF

; Buffer to hold the right side of a pipe (may contain more pipes)
pipe_right_buf  times 130 db 0

; ---------------------------------------------------------------------------
; check_pipe - Scan cmd_buffer for a pipe character and handle it
; Output: AL = 1 if pipe was found and handled, 0 if no pipe
; ---------------------------------------------------------------------------
check_pipe:
    push    bx
    push    cx
    push    dx
    push    si
    push    di

    ; Scan cmd_buffer+2 for '|' not inside quotes
    mov     si, cmd_buffer + 2
    xor     cl, cl              ; Quote state: 0 = not in quotes
.scan:
    lodsb
    test    al, al
    jz      .no_pipe
    cmp     al, '"'
    jne     .not_quote
    xor     cl, 1               ; Toggle quote state
    jmp     .scan
.not_quote:
    test    cl, cl
    jnz     .scan               ; Inside quotes - skip
    cmp     al, '|'
    je      .found_pipe
    jmp     .scan

.no_pipe:
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    xor     al, al              ; Return 0 - no pipe
    ret

.found_pipe:
    ; SI points one past the '|'. Split the command here.
    ; Null-terminate the left command (replace '|' with 0)
    mov     byte [si - 1], 0

    ; Copy right side (SI onward) to pipe_right_buf
    mov     di, pipe_right_buf
.copy_right:
    lodsb
    stosb
    test    al, al
    jnz     .copy_right

    ; --- Execute left command with stdout redirected to temp file ---

    ; Create the temp file
    mov     dx, pipe_tempfile
    xor     cx, cx              ; Normal attributes
    mov     ah, 0x3C            ; Create file
    int     0x21
    jc      .pipe_error
    mov     [pipe_temp_handle], ax

    ; Save original stdout (dup handle 1)
    mov     bx, 1
    mov     ah, 0x45            ; Dup
    int     0x21
    jc      .pipe_close_temp
    mov     [pipe_saved_stdout], ax

    ; Redirect stdout to temp file (force dup temp handle onto handle 1)
    mov     bx, [pipe_temp_handle]
    mov     cx, 1               ; Target: stdout
    mov     ah, 0x46            ; ForceDup
    int     0x21
    jc      .pipe_restore_stdout

    ; Close our copy of the temp handle (stdout now points to the file)
    mov     bx, [pipe_temp_handle]
    mov     ah, 0x3E
    int     0x21

    ; Dispatch left command (cmd_buffer+2 still has the left side)
    call    dispatch_single_cmd

    ; Restore original stdout
    mov     bx, [pipe_saved_stdout]
    mov     cx, 1
    mov     ah, 0x46            ; ForceDup saved handle onto handle 1
    int     0x21
    ; Close saved stdout handle
    mov     bx, [pipe_saved_stdout]
    mov     ah, 0x3E
    int     0x21
    mov     word [pipe_saved_stdout], 0xFFFF

    ; --- Execute right command with stdin redirected from temp file ---

    ; Open temp file for reading
    mov     dx, pipe_tempfile
    mov     ax, 0x3D00          ; Open read-only
    int     0x21
    jc      .pipe_delete
    mov     [pipe_temp_handle], ax

    ; Save original stdin (dup handle 0)
    mov     bx, 0
    mov     ah, 0x45
    int     0x21
    jc      .pipe_close_input
    mov     [pipe_saved_stdin], ax

    ; Redirect stdin from temp file (force dup onto handle 0)
    mov     bx, [pipe_temp_handle]
    mov     cx, 0               ; Target: stdin
    mov     ah, 0x46
    int     0x21
    jc      .pipe_restore_stdin

    ; Close our copy of the temp handle (stdin now points to the file)
    mov     bx, [pipe_temp_handle]
    mov     ah, 0x3E
    int     0x21

    ; Copy right side into cmd_buffer for dispatch
    mov     si, pipe_right_buf
    mov     di, cmd_buffer + 2
    xor     cl, cl              ; Length counter
.copy_to_buf:
    lodsb
    stosb
    test    al, al
    jz      .copy_done
    inc     cl
    jmp     .copy_to_buf
.copy_done:
    mov     [cmd_buffer + 1], cl

    ; Check if the right side itself contains a pipe (chained pipes)
    call    check_pipe
    test    al, al
    jnz     .right_had_pipe

    ; No more pipes - dispatch right command normally
    call    dispatch_single_cmd

.right_had_pipe:
    ; Restore original stdin
    mov     bx, [pipe_saved_stdin]
    mov     cx, 0
    mov     ah, 0x46
    int     0x21
    ; Close saved stdin handle
    mov     bx, [pipe_saved_stdin]
    mov     ah, 0x3E
    int     0x21
    mov     word [pipe_saved_stdin], 0xFFFF

.pipe_delete:
    ; Delete the temp file
    mov     dx, pipe_tempfile
    mov     ah, 0x41            ; Delete file
    int     0x21

    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    mov     al, 1               ; Return 1 - pipe was handled
    ret

.pipe_restore_stdin:
    mov     bx, [pipe_saved_stdin]
    mov     cx, 0
    mov     ah, 0x46
    int     0x21
    mov     bx, [pipe_saved_stdin]
    mov     ah, 0x3E
    int     0x21
    mov     word [pipe_saved_stdin], 0xFFFF
.pipe_close_input:
    mov     bx, [pipe_temp_handle]
    mov     ah, 0x3E
    int     0x21
    jmp     .pipe_delete

.pipe_restore_stdout:
    mov     bx, [pipe_saved_stdout]
    mov     cx, 1
    mov     ah, 0x46
    int     0x21
    mov     bx, [pipe_saved_stdout]
    mov     ah, 0x3E
    int     0x21
    mov     word [pipe_saved_stdout], 0xFFFF
.pipe_close_temp:
    mov     bx, [pipe_temp_handle]
    mov     ah, 0x3E
    int     0x21
.pipe_error:
    ; Print pipe error message
    push    cs
    pop     ds
    mov     dx, pipe_err_msg
    mov     ah, 0x09
    int     0x21

    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    mov     al, 1               ; Return handled (with error)
    ret

pipe_err_msg    db  'Error in pipe', 0x0D, 0x0A, '$'

; ---------------------------------------------------------------------------
; dispatch_single_cmd - Execute a single command from cmd_buffer
; Handles redirection parsing, drive changes, internal + external commands
; ---------------------------------------------------------------------------
dispatch_single_cmd:
    pusha

    ; Parse redirection operators
    call    parse_redirection

    ; Point to command text
    mov     si, cmd_buffer + 2
    call    skip_spaces

    ; Check for empty
    cmp     byte [si], 0
    je      .disp_done

    ; Check for drive change
    call    try_drive_change
    test    al, al
    jnz     .disp_done

    ; Set up redirection
    call    setup_redirection
    jc      .disp_done

    ; Try internal commands
    call    try_internal_cmd
    test    al, al
    jnz     .disp_cmd_done

    ; Try external command
    call    try_external_cmd

.disp_cmd_done:
    call    cleanup_redirection

.disp_done:
    popa
    ret
