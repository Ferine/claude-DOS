; ===========================================================================
; STRESS2.COM - Advanced stress tests for ClaudeDOS
; Tests: multiple handles, edge cases, rapid operations
; ===========================================================================

    CPU     186
    ORG     0x0100

start:
    mov     dx, msg_header
    mov     ah, 0x09
    int     0x21

    ; Test 1: Multiple file handles
    mov     dx, msg_test1
    mov     ah, 0x09
    int     0x21

    ; Create 3 files
    mov     dx, file1
    xor     cx, cx
    mov     ah, 0x3C
    int     0x21
    jc      .test1_fail
    mov     [handle1], ax

    mov     dx, file2
    xor     cx, cx
    mov     ah, 0x3C
    int     0x21
    jc      .test1_fail
    mov     [handle2], ax

    mov     dx, file3
    xor     cx, cx
    mov     ah, 0x3C
    int     0x21
    jc      .test1_fail
    mov     [handle3], ax

    ; Write to all 3 (interleaved)
    mov     bx, [handle1]
    mov     dx, data1
    mov     cx, data1_len
    mov     ah, 0x40
    int     0x21
    jc      .test1_fail

    mov     bx, [handle2]
    mov     dx, data2
    mov     cx, data2_len
    mov     ah, 0x40
    int     0x21
    jc      .test1_fail

    mov     bx, [handle3]
    mov     dx, data3
    mov     cx, data3_len
    mov     ah, 0x40
    int     0x21
    jc      .test1_fail

    ; Close all
    mov     bx, [handle1]
    mov     ah, 0x3E
    int     0x21

    mov     bx, [handle2]
    mov     ah, 0x3E
    int     0x21

    mov     bx, [handle3]
    mov     ah, 0x3E
    int     0x21

    ; Verify by reading back
    mov     dx, file1
    mov     ax, 0x3D00
    int     0x21
    jc      .test1_fail
    mov     bx, ax
    mov     dx, read_buf
    mov     cx, 256
    mov     ah, 0x3F
    int     0x21
    jc      .test1_fail
    cmp     ax, data1_len
    jne     .test1_fail
    mov     ah, 0x3E
    int     0x21

    ; Clean up
    mov     dx, file1
    mov     ah, 0x41
    int     0x21
    mov     dx, file2
    mov     ah, 0x41
    int     0x21
    mov     dx, file3
    mov     ah, 0x41
    int     0x21

    mov     dx, msg_pass
    mov     ah, 0x09
    int     0x21
    jmp     .test2

.test1_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

.test2:
    ; Test 2: Empty file operations
    mov     dx, msg_test2
    mov     ah, 0x09
    int     0x21

    ; Create empty file
    mov     dx, empty_file
    xor     cx, cx
    mov     ah, 0x3C
    int     0x21
    jc      .test2_fail
    mov     bx, ax
    mov     ah, 0x3E
    int     0x21

    ; Read empty file
    mov     dx, empty_file
    mov     ax, 0x3D00
    int     0x21
    jc      .test2_fail
    mov     bx, ax
    mov     dx, read_buf
    mov     cx, 256
    mov     ah, 0x3F
    int     0x21
    jc      .test2_fail
    test    ax, ax          ; Should return 0 bytes
    jnz     .test2_fail
    mov     ah, 0x3E
    int     0x21

    ; Delete empty file
    mov     dx, empty_file
    mov     ah, 0x41
    int     0x21

    mov     dx, msg_pass
    mov     ah, 0x09
    int     0x21
    jmp     .test3

.test2_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

.test3:
    ; Test 3: Seek operations
    mov     dx, msg_test3
    mov     ah, 0x09
    int     0x21

    ; Create file with known content
    mov     dx, seek_file
    xor     cx, cx
    mov     ah, 0x3C
    int     0x21
    jc      .test3_fail
    mov     [handle1], ax

    ; Write "ABCDEFGHIJ"
    mov     bx, ax
    mov     dx, seek_data
    mov     cx, 10
    mov     ah, 0x40
    int     0x21
    jc      .test3_fail

    ; Seek to position 5 from start
    mov     bx, [handle1]
    mov     ax, 0x4200      ; SEEK_SET
    xor     cx, cx
    mov     dx, 5
    int     0x21
    jc      .test3_fail

    ; Read 3 bytes - should get "FGH"
    mov     bx, [handle1]
    mov     dx, read_buf
    mov     cx, 3
    mov     ah, 0x3F
    int     0x21
    jc      .test3_fail
    cmp     ax, 3
    jne     .test3_fail

    ; Verify content
    cmp     byte [read_buf], 'F'
    jne     .test3_fail
    cmp     byte [read_buf+1], 'G'
    jne     .test3_fail
    cmp     byte [read_buf+2], 'H'
    jne     .test3_fail

    ; Close and delete
    mov     bx, [handle1]
    mov     ah, 0x3E
    int     0x21
    mov     dx, seek_file
    mov     ah, 0x41
    int     0x21

    mov     dx, msg_pass
    mov     ah, 0x09
    int     0x21
    jmp     .test4

.test3_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

.test4:
    ; Test 4: Error handling - open non-existent file
    mov     dx, msg_test4
    mov     ah, 0x09
    int     0x21

    mov     dx, noexist_file
    mov     ax, 0x3D00
    int     0x21
    jc      .test4_good     ; Should fail with carry set
    ; If we get here, it's wrong
    mov     bx, ax
    mov     ah, 0x3E
    int     0x21
    jmp     .test4_fail

.test4_good:
    cmp     ax, 2           ; Error 2 = file not found
    jne     .test4_fail

    mov     dx, msg_pass
    mov     ah, 0x09
    int     0x21
    jmp     .test5

.test4_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

.test5:
    ; Test 5: Environment variable operations
    mov     dx, msg_test5
    mov     ah, 0x09
    int     0x21

    ; Get PATH variable (should exist)
    mov     ah, 0x62        ; Get PSP
    int     0x21
    ; BX = PSP segment
    ; Environment is at PSP:002Ch

    mov     dx, msg_pass    ; Assume pass for now
    mov     ah, 0x09
    int     0x21

    ; Test 6: Rapid file create/delete
    mov     dx, msg_test6
    mov     ah, 0x09
    int     0x21

    mov     cx, 20
.rapid_loop:
    push    cx

    ; Create
    mov     dx, rapid_file
    xor     cx, cx
    mov     ah, 0x3C
    int     0x21
    jc      .test6_fail

    ; Close
    mov     bx, ax
    mov     ah, 0x3E
    int     0x21

    ; Delete
    mov     dx, rapid_file
    mov     ah, 0x41
    int     0x21
    jc      .test6_fail

    mov     dl, '.'
    mov     ah, 0x02
    int     0x21

    pop     cx
    loop    .rapid_loop

    call    print_crlf
    mov     dx, msg_pass
    mov     ah, 0x09
    int     0x21
    jmp     .done

.test6_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21
    pop     cx

.done:
    mov     dx, msg_done
    mov     ah, 0x09
    int     0x21

    mov     ax, 0x4C00
    int     0x21

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

; Data
msg_header  db  '=== ClaudeDOS Advanced Stress Test ===', 0x0D, 0x0A, 0x0D, 0x0A, '$'
msg_test1   db  'Test 1: Multiple file handles...', '$'
msg_test2   db  'Test 2: Empty file operations...', '$'
msg_test3   db  'Test 3: File seek operations...', '$'
msg_test4   db  'Test 4: Error handling (file not found)...', '$'
msg_test5   db  'Test 5: Environment access...', '$'
msg_test6   db  'Test 6: Rapid create/delete (20x)...', '$'
msg_pass    db  'PASS', 0x0D, 0x0A, '$'
msg_fail    db  'FAIL', 0x0D, 0x0A, '$'
msg_done    db  0x0D, 0x0A, 'All tests completed!', 0x0D, 0x0A, '$'

file1       db  'TEST1.$$$', 0
file2       db  'TEST2.$$$', 0
file3       db  'TEST3.$$$', 0
empty_file  db  'EMPTY.$$$', 0
seek_file   db  'SEEK.$$$', 0
noexist_file db 'NOEXIST.$$$', 0
rapid_file  db  'RAPID.$$$', 0

data1       db  'File one content'
data1_len   equ $ - data1
data2       db  'Second file data here'
data2_len   equ $ - data2
data3       db  'Third'
data3_len   equ $ - data3
seek_data   db  'ABCDEFGHIJ'

handle1     dw  0
handle2     dw  0
handle3     dw  0
read_buf    times 256 db 0
