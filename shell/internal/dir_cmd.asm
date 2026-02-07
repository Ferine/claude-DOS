; ===========================================================================
; DIR command - Display directory listing
; Options: /P = pause after each screenful
;          /W = wide format (5 columns)
; ===========================================================================

cmd_dir:
    pusha

    ; Parse options
    mov     byte [dir_opt_pause], 0
    mov     byte [dir_opt_wide], 0
    mov     word [dir_file_count], 0
    mov     word [dir_dir_count], 0
    mov     word [dir_total_size], 0
    mov     word [dir_total_size + 2], 0
    mov     byte [dir_line_count], 0
    mov     byte [dir_col_count], 0

    ; Save SI (filespec start)
    mov     [dir_filespec], si

.parse_opts:
    cmp     byte [si], 0
    je      .opts_done
    cmp     byte [si], '/'
    jne     .next_char
    ; Check option
    inc     si
    mov     al, [si]
    or      al, 0x20            ; Lowercase
    cmp     al, 'p'
    jne     .not_p
    mov     byte [dir_opt_pause], 1
    jmp     .skip_opt
.not_p:
    cmp     al, 'w'
    jne     .skip_opt
    mov     byte [dir_opt_wide], 1
.skip_opt:
    inc     si
    jmp     .parse_opts
.next_char:
    inc     si
    jmp     .parse_opts
.opts_done:

    ; Determine drive letter for header
    mov     si, [dir_filespec]
    cmp     byte [si + 1], ':'
    jne     .use_default_drive
    mov     al, [si]
    cmp     al, 'a'
    jb      .dir_drive_ok
    cmp     al, 'z'
    ja      .dir_drive_ok
    sub     al, 0x20            ; to uppercase
.dir_drive_ok:
    jmp     .set_dir_drive
.use_default_drive:
    mov     ah, 0x19            ; Get current drive
    int     0x21
    add     al, 'A'
.set_dir_drive:
    mov     [dir_hdr_drive], al
    mov     [dir_hdr_drive2], al

    ; Print header
    mov     dx, dir_header
    mov     ah, 0x09
    int     0x21

    ; Use FindFirst/FindNext to list files
    mov     dx, dir_dta
    mov     ah, 0x1A
    int     0x21

    ; FindFirst
    mov     si, [dir_filespec]
    mov     dx, si
    cmp     byte [si], 0
    jne     .check_slash
    mov     dx, dir_all_spec
    jmp     .have_spec
.check_slash:
    cmp     byte [si], '/'
    je      .use_all
    ; Check if path ends with backslash or colon (directory, needs *.*)
    push    si
.find_end:
    cmp     byte [si], 0
    je      .at_end
    cmp     byte [si], ' '
    je      .at_end
    cmp     byte [si], '/'
    je      .at_end
    inc     si
    jmp     .find_end
.at_end:
    dec     si              ; Point to last char
    mov     al, [si]
    pop     si
    cmp     al, '\'
    je      .append_wildcard
    cmp     al, ':'
    je      .append_wildcard

    ; No trailing \ or : — check if the spec is a bare directory name
    ; Copy spec to dir_spec_buf (null-terminated) for attribute check
    push    si
    push    cx
    mov     di, dir_spec_buf
.copy_for_chk:
    lodsb
    cmp     al, 0
    je      .chk_copied
    cmp     al, ' '
    je      .chk_copied
    cmp     al, '/'
    je      .chk_copied
    stosb
    jmp     .copy_for_chk
.chk_copied:
    mov     byte [di], 0        ; Null-terminate
    ; Try INT 21h/4300h (Get File Attributes)
    mov     dx, dir_spec_buf
    mov     ax, 0x4300
    int     0x21
    jc      .not_a_dir          ; Not found or error — use spec as-is
    test    cx, 0x10            ; ATTR_DIRECTORY?
    jz      .not_a_dir
    ; It's a directory — append \*.*
    mov     byte [di], '\'
    mov     byte [di+1], '*'
    mov     byte [di+2], '.'
    mov     byte [di+3], '*'
    mov     byte [di+4], 0
    pop     cx
    pop     si
    mov     dx, dir_spec_buf
    jmp     .have_spec
.not_a_dir:
    pop     cx
    pop     si
    jmp     .have_spec
.append_wildcard:
    ; Copy path to dir_spec_buf and append *.*
    push    si
    mov     di, dir_spec_buf
.copy_dir_path:
    lodsb
    cmp     al, 0
    je      .dir_path_end
    cmp     al, ' '
    je      .dir_path_end
    cmp     al, '/'
    je      .dir_path_end
    stosb
    jmp     .copy_dir_path
.dir_path_end:
    ; Append *.*
    mov     byte [di], '*'
    mov     byte [di+1], '.'
    mov     byte [di+2], '*'
    mov     byte [di+3], 0
    pop     si
    mov     dx, dir_spec_buf
    jmp     .have_spec
.use_all:
    mov     dx, dir_all_spec
.have_spec:
    mov     cx, 0x37            ; All attributes
    mov     ah, 0x4E
    int     0x21
    jc      .no_files

.show_entry:
    ; Check if directory
    test    byte [dir_dta + 21], 0x10
    jnz     .is_dir

    ; Count files and add size
    inc     word [dir_file_count]
    mov     ax, [dir_dta + 26]
    add     [dir_total_size], ax
    mov     ax, [dir_dta + 28]
    adc     [dir_total_size + 2], ax

    ; Wide or normal format?
    cmp     byte [dir_opt_wide], 1
    je      .show_wide

    ; Normal format: filename + size
    mov     si, dir_dta + 30
    call    .print_padded_name

    mov     ax, [dir_dta + 26]
    mov     dx, [dir_dta + 28]
    call    print_dec32

    call    print_crlf
    call    .check_pause
    jmp     .find_next

.is_dir:
    inc     word [dir_dir_count]

    cmp     byte [dir_opt_wide], 1
    je      .show_dir_wide

    ; Normal format: dirname + <DIR>
    mov     si, dir_dta + 30
    call    .print_padded_name
    mov     dx, dir_dir_tag
    mov     ah, 0x09
    int     0x21
    call    print_crlf
    call    .check_pause
    jmp     .find_next

.show_wide:
    ; Wide format: just name in columns
    mov     si, dir_dta + 30
    call    .print_wide_name
    jmp     .find_next

.show_dir_wide:
    ; Wide format with [dirname]
    mov     dl, '['
    mov     ah, 0x02
    int     0x21
    mov     si, dir_dta + 30
    call    .print_wide_dir
    mov     dl, ']'
    mov     ah, 0x02
    int     0x21
    ; Pad to column width
    call    .wide_next_col
    jmp     .find_next

.find_next:
    mov     ah, 0x4F
    int     0x21
    jnc     .show_entry

    ; End of listing - finish wide line if needed
    cmp     byte [dir_opt_wide], 1
    jne     .show_summary
    cmp     byte [dir_col_count], 0
    je      .show_summary
    call    print_crlf

.show_summary:
    ; Print summary
    call    print_crlf
    mov     ax, [dir_file_count]
    call    print_dec16
    mov     dx, dir_files_msg
    mov     ah, 0x09
    int     0x21
    mov     ax, [dir_total_size]
    mov     dx, [dir_total_size + 2]
    call    print_dec32
    mov     dx, dir_bytes_msg
    mov     ah, 0x09
    int     0x21

.no_files:
    popa
    ret

.print_padded_name:
    ; Print name, pad with spaces to 15 chars
    push    cx
    xor     cx, cx
.pn_loop:
    lodsb
    test    al, al
    jz      .pn_pad
    mov     dl, al
    mov     ah, 0x02
    int     0x21
    inc     cx
    jmp     .pn_loop
.pn_pad:
    cmp     cx, 15
    jae     .pn_done
    mov     dl, ' '
    mov     ah, 0x02
    int     0x21
    inc     cx
    jmp     .pn_pad
.pn_done:
    pop     cx
    ret

.print_wide_name:
    ; Print name padded to 15 chars for wide format
    push    cx
    xor     cx, cx
.pwn_loop:
    lodsb
    test    al, al
    jz      .pwn_pad
    mov     dl, al
    mov     ah, 0x02
    int     0x21
    inc     cx
    jmp     .pwn_loop
.pwn_pad:
    cmp     cx, 14
    jae     .pwn_next
    mov     dl, ' '
    mov     ah, 0x02
    int     0x21
    inc     cx
    jmp     .pwn_pad
.pwn_next:
    pop     cx
    call    .wide_next_col
    ret

.print_wide_dir:
    ; Print dir name (max 12 chars for [ ])
    push    cx
    xor     cx, cx
.pwd_loop:
    lodsb
    test    al, al
    jz      .pwd_done
    cmp     cx, 12
    jae     .pwd_done
    mov     dl, al
    mov     ah, 0x02
    int     0x21
    inc     cx
    jmp     .pwd_loop
.pwd_done:
    pop     cx
    ret

.wide_next_col:
    inc     byte [dir_col_count]
    cmp     byte [dir_col_count], 5
    jb      .wnc_done
    mov     byte [dir_col_count], 0
    call    print_crlf
    call    .check_pause
.wnc_done:
    ret

.check_pause:
    cmp     byte [dir_opt_pause], 0
    je      .cp_done
    inc     byte [dir_line_count]
    cmp     byte [dir_line_count], 23
    jb      .cp_done
    mov     byte [dir_line_count], 0
    ; Print "Press any key..." and wait
    mov     dx, dir_pause_msg
    mov     ah, 0x09
    int     0x21
    xor     ah, ah
    int     0x16
    ; Clear the line
    mov     dl, 0x0D
    mov     ah, 0x02
    int     0x21
    mov     cx, 25
.cp_clear:
    mov     dl, ' '
    int     0x21
    loop    .cp_clear
    mov     dl, 0x0D
    int     0x21
.cp_done:
    ret

; DIR data
dir_header      db  ' Volume in drive '
dir_hdr_drive   db  'A'
                db  ' is CLAUDEDOS', 0x0D, 0x0A
                db  ' Directory of '
dir_hdr_drive2  db  'A'
                db  ':\', 0x0D, 0x0A, 0x0D, 0x0A, '$'
dir_all_spec    db  '*.*', 0
dir_spec_buf    times 80 db 0
dir_dir_tag     db  '<DIR>$'
dir_files_msg   db  ' file(s)  $'
dir_bytes_msg   db  ' bytes', 0x0D, 0x0A, '$'
dir_pause_msg   db  'Press any key to continue...$'

dir_dta         times 43 db 0
dir_filespec    dw  0
dir_opt_pause   db  0
dir_opt_wide    db  0
dir_file_count  dw  0
dir_dir_count   dw  0
dir_total_size  dd  0
dir_line_count  db  0
dir_col_count   db  0
