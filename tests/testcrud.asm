; Comprehensive CRUD filesystem test
; Tests: Create, Read, Update, Delete with edge cases
org 0x100

section .text
start:
    mov     dx, msg_header
    mov     ah, 0x09
    int     0x21

    ; ===== CREATE TESTS =====
    mov     dx, msg_section_create
    mov     ah, 0x09
    int     0x21

    ; Test 1: Basic create
    mov     dx, msg_t1
    mov     ah, 0x09
    int     0x21
    mov     dx, file1
    mov     cx, 0
    mov     ah, 0x3C
    int     0x21
    jc      .t1_fail
    mov     [handle1], ax
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .t2

.t1_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21
    jmp     .cleanup

    ; Test 2: Exclusive create (should succeed - new file)
.t2:
    mov     dx, msg_t2
    mov     ah, 0x09
    int     0x21
    mov     dx, file2
    mov     cx, 0
    mov     ah, 0x5B            ; Create new (exclusive)
    int     0x21
    jc      .t2_fail
    mov     [handle2], ax
    mov     bx, ax
    mov     ah, 0x3E            ; Close it
    int     0x21
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .t3

.t2_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

    ; Test 3: Exclusive create (should FAIL - file exists)
.t3:
    mov     dx, msg_t3
    mov     ah, 0x09
    int     0x21
    mov     dx, file2
    mov     cx, 0
    mov     ah, 0x5B            ; Create new (exclusive)
    int     0x21
    jnc     .t3_fail            ; Should fail!
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .t4

.t3_fail:
    mov     bx, ax
    mov     ah, 0x3E
    int     0x21
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

    ; Test 4: Create with attributes (hidden)
.t4:
    mov     dx, msg_t4
    mov     ah, 0x09
    int     0x21
    mov     dx, file3
    mov     cx, 0x02            ; Hidden attribute
    mov     ah, 0x3C
    int     0x21
    jc      .t4_fail
    mov     [handle3], ax
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .write_tests

.t4_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

    ; ===== WRITE/UPDATE TESTS =====
.write_tests:
    mov     dx, msg_section_update
    mov     ah, 0x09
    int     0x21

    ; Test 5: Write to file
.t5:
    mov     dx, msg_t5
    mov     ah, 0x09
    int     0x21
    mov     bx, [handle1]
    mov     dx, data1
    mov     cx, data1_len
    mov     ah, 0x40
    int     0x21
    jc      .t5_fail
    cmp     ax, data1_len       ; Check bytes written
    jne     .t5_fail
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .t6

.t5_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

    ; Test 6: Seek to middle and overwrite
.t6:
    mov     dx, msg_t6
    mov     ah, 0x09
    int     0x21
    mov     bx, [handle1]
    mov     al, 0               ; SEEK_SET
    mov     cx, 0
    mov     dx, 7               ; Position 7 ("WORLD" starts at 7)
    mov     ah, 0x42
    int     0x21
    jc      .t6_fail
    ; Write "CLAUDE" over "WORLD!"
    mov     bx, [handle1]
    mov     dx, overwrite_data
    mov     cx, overwrite_len
    mov     ah, 0x40
    int     0x21
    jc      .t6_fail
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .t7

.t6_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

    ; Test 7: Seek to end and append
.t7:
    mov     dx, msg_t7
    mov     ah, 0x09
    int     0x21
    mov     bx, [handle1]
    mov     al, 2               ; SEEK_END
    mov     cx, 0
    mov     dx, 0
    mov     ah, 0x42
    int     0x21
    jc      .t7_fail
    ; Append " - appended"
    mov     bx, [handle1]
    mov     dx, append_data
    mov     cx, append_len
    mov     ah, 0x40
    int     0x21
    jc      .t7_fail
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .t8

.t7_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

    ; Test 8: Close and reopen to verify
.t8:
    mov     dx, msg_t8
    mov     ah, 0x09
    int     0x21
    mov     bx, [handle1]
    mov     ah, 0x3E
    int     0x21
    ; Reopen
    mov     dx, file1
    mov     al, 0
    mov     ah, 0x3D
    int     0x21
    jc      .t8_fail
    mov     [handle1], ax
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .read_tests

.t8_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

    ; ===== READ TESTS =====
.read_tests:
    mov     dx, msg_section_read
    mov     ah, 0x09
    int     0x21

    ; Test 9: Read entire file
.t9:
    mov     dx, msg_t9
    mov     ah, 0x09
    int     0x21
    mov     bx, [handle1]
    mov     dx, buffer
    mov     cx, 256
    mov     ah, 0x3F
    int     0x21
    jc      .t9_fail
    mov     [bytes_read], ax
    ; Verify content starts with "HELLO, "
    cmp     byte [buffer], 'H'
    jne     .t9_fail
    cmp     byte [buffer+1], 'E'
    jne     .t9_fail
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    ; Print what we read
    mov     dx, msg_content
    mov     ah, 0x09
    int     0x21
    mov     cx, [bytes_read]
    mov     si, buffer
.print_content:
    test    cx, cx
    jz      .print_done
    lodsb
    mov     dl, al
    mov     ah, 0x02
    int     0x21
    dec     cx
    jmp     .print_content
.print_done:
    mov     dx, crlf
    mov     ah, 0x09
    int     0x21
    jmp     .t10

.t9_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

    ; Test 10: Read at EOF (should return 0 bytes)
.t10:
    mov     dx, msg_t10
    mov     ah, 0x09
    int     0x21
    mov     bx, [handle1]
    mov     dx, buffer
    mov     cx, 256
    mov     ah, 0x3F
    int     0x21
    jc      .t10_fail
    test    ax, ax              ; Should be 0 bytes at EOF
    jnz     .t10_fail
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .t11

.t10_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

    ; Test 11: Seek backward and read partial
.t11:
    mov     dx, msg_t11
    mov     ah, 0x09
    int     0x21
    mov     bx, [handle1]
    mov     al, 0               ; SEEK_SET
    mov     cx, 0
    mov     dx, 7               ; Position 7
    mov     ah, 0x42
    int     0x21
    jc      .t11_fail
    mov     bx, [handle1]
    mov     dx, buffer
    mov     cx, 6               ; Read exactly 6 bytes
    mov     ah, 0x3F
    int     0x21
    jc      .t11_fail
    cmp     ax, 6
    jne     .t11_fail
    ; Should read "CLAUDE" (we overwrote "WORLD!" with "CLAUDE")
    cmp     byte [buffer], 'C'
    jne     .t11_fail
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .attr_tests

.t11_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

    ; ===== ATTRIBUTE TESTS =====
.attr_tests:
    mov     dx, msg_section_attr
    mov     ah, 0x09
    int     0x21

    ; Test 12: Get file attributes
.t12:
    mov     dx, msg_t12
    mov     ah, 0x09
    int     0x21
    mov     dx, file3           ; Hidden file
    mov     al, 0               ; Get attributes
    mov     ah, 0x43
    int     0x21
    jc      .t12_fail
    test    cx, 0x02            ; Check hidden bit
    jz      .t12_fail
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .t13

.t12_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

    ; Test 13: Set file attributes (remove hidden)
.t13:
    mov     dx, msg_t13
    mov     ah, 0x09
    int     0x21
    mov     dx, file3
    mov     cx, 0               ; Normal attributes
    mov     al, 1               ; Set attributes
    mov     ah, 0x43
    int     0x21
    jc      .t13_fail
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .delete_tests

.t13_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

    ; ===== DELETE TESTS =====
.delete_tests:
    mov     dx, msg_section_delete
    mov     ah, 0x09
    int     0x21

    ; Close open handles first
    mov     bx, [handle1]
    mov     ah, 0x3E
    int     0x21
    mov     bx, [handle3]
    mov     ah, 0x3E
    int     0x21

    ; Test 14: Delete file1
.t14:
    mov     dx, msg_t14
    mov     ah, 0x09
    int     0x21
    mov     dx, file1
    mov     ah, 0x41
    int     0x21
    jc      .t14_fail
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .t15

.t14_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

    ; Test 15: Delete file2
.t15:
    mov     dx, msg_t15
    mov     ah, 0x09
    int     0x21
    mov     dx, file2
    mov     ah, 0x41
    int     0x21
    jc      .t15_fail
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .t16

.t15_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

    ; Test 16: Delete file3
.t16:
    mov     dx, msg_t16
    mov     ah, 0x09
    int     0x21
    mov     dx, file3
    mov     ah, 0x41
    int     0x21
    jc      .t16_fail
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .t17

.t16_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

    ; Test 17: Delete non-existent file (should fail)
.t17:
    mov     dx, msg_t17
    mov     ah, 0x09
    int     0x21
    mov     dx, nofile
    mov     ah, 0x41
    int     0x21
    jnc     .t17_fail           ; Should fail!
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .done

.t17_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

.done:
    mov     dx, msg_done
    mov     ah, 0x09
    int     0x21
    mov     ax, 0x4C00
    int     0x21

.cleanup:
    ; Clean up any open handles on error
    mov     bx, [handle1]
    test    bx, bx
    jz      .c1
    mov     ah, 0x3E
    int     0x21
.c1:
    mov     bx, [handle2]
    test    bx, bx
    jz      .c2
    mov     ah, 0x3E
    int     0x21
.c2:
    mov     bx, [handle3]
    test    bx, bx
    jz      .c3
    mov     ah, 0x3E
    int     0x21
.c3:
    mov     ax, 0x4C01
    int     0x21

section .data
msg_header      db 'Comprehensive CRUD Filesystem Test', 13, 10
                db '===================================', 13, 10, '$'
msg_section_create  db 13, 10, '--- CREATE TESTS ---', 13, 10, '$'
msg_section_update  db 13, 10, '--- UPDATE TESTS ---', 13, 10, '$'
msg_section_read    db 13, 10, '--- READ TESTS ---', 13, 10, '$'
msg_section_attr    db 13, 10, '--- ATTRIBUTE TESTS ---', 13, 10, '$'
msg_section_delete  db 13, 10, '--- DELETE TESTS ---', 13, 10, '$'

msg_t1          db 'T1:  Create basic file... $'
msg_t2          db 'T2:  Exclusive create new... $'
msg_t3          db 'T3:  Exclusive create exists (expect fail)... $'
msg_t4          db 'T4:  Create with hidden attr... $'
msg_t5          db 'T5:  Write data... $'
msg_t6          db 'T6:  Seek and overwrite... $'
msg_t7          db 'T7:  Seek to end and append... $'
msg_t8          db 'T8:  Close and reopen... $'
msg_t9          db 'T9:  Read entire file... $'
msg_t10         db 'T10: Read at EOF (0 bytes)... $'
msg_t11         db 'T11: Seek back and read partial... $'
msg_t12         db 'T12: Get file attributes... $'
msg_t13         db 'T13: Set file attributes... $'
msg_t14         db 'T14: Delete file1... $'
msg_t15         db 'T15: Delete file2... $'
msg_t16         db 'T16: Delete file3... $'
msg_t17         db 'T17: Delete non-existent (expect fail)... $'

msg_ok          db 'OK', 13, 10, '$'
msg_fail        db 'FAIL', 13, 10, '$'
msg_content     db '     Content: $'
msg_done        db 13, 10, '=== ALL TESTS COMPLETE ===', 13, 10, '$'
crlf            db 13, 10, '$'

file1           db 'CRUD1.TXT', 0
file2           db 'CRUD2.TXT', 0
file3           db 'CRUD3.TXT', 0
nofile          db 'NOEXIST.XXX', 0

data1           db 'HELLO, WORLD!'
data1_len       equ $ - data1

overwrite_data  db 'CLAUDE'
overwrite_len   equ $ - overwrite_data

append_data     db ' - appended'
append_len      equ $ - append_data

section .bss
handle1         resw 1
handle2         resw 1
handle3         resw 1
bytes_read      resw 1
buffer          resb 256
