; ===========================================================================
; STRESS.COM - Stress test shell commands
; Tests DIR, TYPE, COPY, TIME, DATE in various sequences
; ===========================================================================

    CPU     186
    ORG     0x0100

start:
    ; Print header
    mov     dx, msg_header
    mov     ah, 0x09
    int     0x21

    ; Test 1: Multiple TIME calls
    mov     dx, msg_test1
    mov     ah, 0x09
    int     0x21

    mov     cx, 5
.time_loop:
    push    cx
    mov     ah, 0x2C        ; Get time
    int     0x21
    ; Print HH:MM:SS
    mov     al, ch
    call    print_byte
    mov     dl, ':'
    mov     ah, 0x02
    int     0x21
    mov     ah, 0x2C        ; Get time again for minutes
    int     0x21
    mov     al, cl
    call    print_byte
    mov     dl, ':'
    mov     ah, 0x02
    int     0x21
    mov     ah, 0x2C        ; Get time again for seconds
    int     0x21
    mov     al, dh
    call    print_byte
    call    print_crlf
    pop     cx
    loop    .time_loop

    mov     dx, msg_pass
    mov     ah, 0x09
    int     0x21

    ; Test 2: Multiple DATE calls
    mov     dx, msg_test2
    mov     ah, 0x09
    int     0x21

    mov     cx, 5
.date_loop:
    push    cx
    mov     ah, 0x2A        ; Get date
    int     0x21
    ; Save values
    push    cx              ; Year
    push    dx              ; Month/Day
    push    ax              ; Day of week in AL

    ; Print day of week
    pop     ax
    mov     bl, al
    xor     bh, bh
    shl     bx, 1               ; *2 for word table offset
    add     bx, dow_table
    mov     dx, [bx]
    mov     ah, 0x09
    int     0x21

    ; Print month
    pop     dx
    mov     al, dh
    call    print_byte
    mov     dl, '/'
    mov     ah, 0x02
    int     0x21

    ; Print day
    mov     ah, 0x2A
    int     0x21
    mov     al, dl
    call    print_byte
    mov     dl, '/'
    mov     ah, 0x02
    int     0x21

    ; Print year
    pop     cx
    mov     ax, cx
    call    print_dec16
    call    print_crlf

    pop     cx
    loop    .date_loop

    mov     dx, msg_pass
    mov     ah, 0x09
    int     0x21

    ; Test 3: Create/Write/Read/Delete cycle
    mov     dx, msg_test3
    mov     ah, 0x09
    int     0x21

    mov     cx, 3
.file_loop:
    push    cx

    ; Create file
    mov     dx, test_file
    xor     cx, cx
    mov     ah, 0x3C
    int     0x21
    jc      .file_fail
    mov     [file_handle], ax

    ; Write data
    mov     bx, ax
    mov     dx, test_data
    mov     cx, test_data_len
    mov     ah, 0x40
    int     0x21
    jc      .file_fail

    ; Close file
    mov     bx, [file_handle]
    mov     ah, 0x3E
    int     0x21

    ; Open file
    mov     dx, test_file
    mov     ax, 0x3D00
    int     0x21
    jc      .file_fail
    mov     [file_handle], ax

    ; Read data
    mov     bx, ax
    mov     dx, read_buf
    mov     cx, 256
    mov     ah, 0x3F
    int     0x21
    jc      .file_fail

    ; Verify length
    cmp     ax, test_data_len
    jne     .file_fail

    ; Close file
    mov     bx, [file_handle]
    mov     ah, 0x3E
    int     0x21

    ; Delete file
    mov     dx, test_file
    mov     ah, 0x41
    int     0x21
    jc      .file_fail

    mov     dl, '.'
    mov     ah, 0x02
    int     0x21

    pop     cx
    loop    .file_loop

    call    print_crlf
    mov     dx, msg_pass
    mov     ah, 0x09
    int     0x21
    jmp     .test4

.file_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21
    pop     cx

.test4:
    ; Test 4: FindFirst/FindNext stress
    mov     dx, msg_test4
    mov     ah, 0x09
    int     0x21

    mov     cx, 5
.find_loop:
    push    cx

    ; Set DTA
    mov     dx, find_dta
    mov     ah, 0x1A
    int     0x21

    ; FindFirst
    mov     dx, find_spec
    mov     cx, 0x37
    mov     ah, 0x4E
    int     0x21
    jc      .find_none

    xor     bx, bx          ; Count files
.find_next:
    inc     bx
    mov     ah, 0x4F
    int     0x21
    jnc     .find_next

    ; Print count
    mov     ax, bx
    call    print_dec16
    mov     dx, msg_files
    mov     ah, 0x09
    int     0x21

.find_none:
    pop     cx
    loop    .find_loop

    mov     dx, msg_pass
    mov     ah, 0x09
    int     0x21

    ; Test 5: Rapid command sequence simulation
    mov     dx, msg_test5
    mov     ah, 0x09
    int     0x21

    mov     cx, 10
.rapid_loop:
    push    cx

    ; Get time
    mov     ah, 0x2C
    int     0x21

    ; Get date
    mov     ah, 0x2A
    int     0x21

    ; Get current drive
    mov     ah, 0x19
    int     0x21

    ; Get current directory
    mov     dl, 0
    mov     si, dir_buf
    mov     ah, 0x47
    int     0x21

    ; Get DOS version
    mov     ah, 0x30
    int     0x21

    mov     dl, '.'
    mov     ah, 0x02
    int     0x21

    pop     cx
    loop    .rapid_loop

    call    print_crlf
    mov     dx, msg_pass
    mov     ah, 0x09
    int     0x21

    ; All tests done
    mov     dx, msg_done
    mov     ah, 0x09
    int     0x21

    ; Exit
    mov     ax, 0x4C00
    int     0x21

; ---------------------------------------------------------------------------
; print_byte - Print AL as 2-digit decimal
; ---------------------------------------------------------------------------
print_byte:
    push    ax
    push    dx
    xor     ah, ah
    cmp     al, 10
    jae     .no_lead
    push    ax
    mov     dl, '0'
    mov     ah, 0x02
    int     0x21
    pop     ax
.no_lead:
    call    print_dec16
    pop     dx
    pop     ax
    ret

; ---------------------------------------------------------------------------
; print_dec16 - Print AX as decimal
; ---------------------------------------------------------------------------
print_dec16:
    push    ax
    push    bx
    push    cx
    push    dx
    xor     cx, cx
    mov     bx, 10
.div_loop:
    xor     dx, dx
    div     bx
    push    dx
    inc     cx
    test    ax, ax
    jnz     .div_loop
.print_loop:
    pop     dx
    add     dl, '0'
    mov     ah, 0x02
    int     0x21
    loop    .print_loop
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

; ---------------------------------------------------------------------------
; print_crlf - Print CR+LF
; ---------------------------------------------------------------------------
print_crlf:
    push    ax
    push    dx
    mov     dl, 0x0D
    mov     ah, 0x02
    int     0x21
    mov     dl, 0x0A
    int     0x21
    pop     dx
    pop     ax
    ret

; ---------------------------------------------------------------------------
; Data
; ---------------------------------------------------------------------------
msg_header  db  '=== ClaudeDOS Stress Test ===', 0x0D, 0x0A, 0x0D, 0x0A, '$'
msg_test1   db  'Test 1: TIME calls (5x)...', 0x0D, 0x0A, '$'
msg_test2   db  'Test 2: DATE calls (5x)...', 0x0D, 0x0A, '$'
msg_test3   db  'Test 3: File create/write/read/delete (3x)...', '$'
msg_test4   db  'Test 4: FindFirst/FindNext (5x)...', 0x0D, 0x0A, '$'
msg_test5   db  'Test 5: Rapid syscall sequence (10x)...', '$'
msg_pass    db  'PASS', 0x0D, 0x0A, '$'
msg_fail    db  'FAIL', 0x0D, 0x0A, '$'
msg_done    db  0x0D, 0x0A, 'All tests completed!', 0x0D, 0x0A, '$'
msg_files   db  ' files found', 0x0D, 0x0A, '$'

dow_table:
    dw      dow_sun, dow_mon, dow_tue, dow_wed
    dw      dow_thu, dow_fri, dow_sat

dow_sun     db  'Sun $'
dow_mon     db  'Mon $'
dow_tue     db  'Tue $'
dow_wed     db  'Wed $'
dow_thu     db  'Thu $'
dow_fri     db  'Fri $'
dow_sat     db  'Sat $'

test_file   db  'TEST.$$$', 0
test_data   db  'Hello from stress test!', 0x0D, 0x0A
test_data_len equ $ - test_data

find_spec   db  '*.*', 0

file_handle dw  0
find_dta    times 43 db 0
read_buf    times 256 db 0
dir_buf     times 68 db 0
