; Test filesystem operations: mkdir, rmdir, rename, seek
org 0x100

section .text
start:
    ; Print header
    mov     dx, msg_header
    mov     ah, 0x09
    int     0x21

    ; ===== TEST 1: Create directory =====
    mov     dx, msg_test1
    mov     ah, 0x09
    int     0x21

    mov     dx, dirname
    mov     ah, 0x39            ; mkdir
    int     0x21
    jc      .mkdir_error

    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21

    ; ===== TEST 2: Create file in root =====
    mov     dx, msg_test2
    mov     ah, 0x09
    int     0x21

    mov     dx, filename1
    mov     cx, 0x00
    mov     ah, 0x3C            ; create file
    int     0x21
    jc      .create_error

    mov     [handle], ax

    ; Write data
    mov     bx, [handle]
    mov     dx, test_data
    mov     cx, test_data_len
    mov     ah, 0x40
    int     0x21
    jc      .write_error

    ; Close
    mov     bx, [handle]
    mov     ah, 0x3E
    int     0x21

    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21

    ; ===== TEST 3: Seek test =====
    mov     dx, msg_test3
    mov     ah, 0x09
    int     0x21

    ; Re-open file
    mov     dx, filename1
    mov     al, 0
    mov     ah, 0x3D
    int     0x21
    jc      .open_error
    mov     [handle], ax

    ; Seek to position 6 from start (skip "Hello ")
    mov     bx, [handle]
    mov     al, 0               ; SEEK_SET
    mov     cx, 0
    mov     dx, 6
    mov     ah, 0x42
    int     0x21
    jc      .seek_error

    ; Read remaining data
    mov     bx, [handle]
    mov     dx, read_buffer
    mov     cx, 50
    mov     ah, 0x3F
    int     0x21
    jc      .read_error

    ; Verify we got "from claudeDOS!"
    mov     si, read_buffer
    cmp     byte [si], 'f'      ; Should be 'f' from "from"
    jne     .seek_verify_error

    ; Seek to end
    mov     bx, [handle]
    mov     al, 2               ; SEEK_END
    mov     cx, 0
    mov     dx, 0
    mov     ah, 0x42
    int     0x21
    jc      .seek_error

    ; Check position (should be 21 = length of "Hello from claudeDOS!")
    cmp     ax, test_data_len
    jne     .seek_verify_error

    ; Close
    mov     bx, [handle]
    mov     ah, 0x3E
    int     0x21

    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21

    ; ===== TEST 4: Rename file =====
    mov     dx, msg_test4
    mov     ah, 0x09
    int     0x21

    push    ds
    pop     es
    mov     dx, filename1       ; old name
    mov     di, filename2       ; new name
    mov     ah, 0x56
    int     0x21
    jc      .rename_error

    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21

    ; ===== TEST 5: Verify renamed file exists =====
    mov     dx, msg_test5
    mov     ah, 0x09
    int     0x21

    mov     dx, filename2
    mov     al, 0
    mov     ah, 0x3D
    int     0x21
    jc      .open_error

    mov     bx, ax
    mov     ah, 0x3E            ; close
    int     0x21

    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21

    ; ===== TEST 6: Delete renamed file =====
    mov     dx, msg_test6
    mov     ah, 0x09
    int     0x21

    mov     dx, filename2
    mov     ah, 0x41
    int     0x21
    jc      .delete_error

    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21

    ; ===== TEST 7: Remove directory =====
    mov     dx, msg_test7
    mov     ah, 0x09
    int     0x21

    mov     dx, dirname
    mov     ah, 0x3A            ; rmdir
    int     0x21
    jc      .rmdir_error

    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21

    ; ===== All tests passed =====
    mov     dx, msg_done
    mov     ah, 0x09
    int     0x21

    mov     ax, 0x4C00
    int     0x21

; Error handlers
.mkdir_error:
    mov     dx, msg_mkdir_err
    jmp     .error_exit

.create_error:
    mov     dx, msg_create_err
    jmp     .error_exit

.write_error:
    mov     dx, msg_write_err
    jmp     .error_exit

.open_error:
    mov     dx, msg_open_err
    jmp     .error_exit

.seek_error:
    mov     dx, msg_seek_err
    jmp     .error_exit

.seek_verify_error:
    mov     dx, msg_seekv_err
    jmp     .error_exit

.read_error:
    mov     dx, msg_read_err
    jmp     .error_exit

.rename_error:
    mov     dx, msg_rename_err
    jmp     .error_exit

.delete_error:
    mov     dx, msg_delete_err
    jmp     .error_exit

.rmdir_error:
    mov     dx, msg_rmdir_err
    jmp     .error_exit

.error_exit:
    mov     ah, 0x09
    int     0x21
    mov     ax, 0x4C01
    int     0x21

section .data
msg_header      db 'Filesystem operations test', 13, 10
                db '==========================', 13, 10, '$'
msg_test1       db 'Test 1: mkdir TESTDIR... $'
msg_test2       db 'Test 2: create/write file... $'
msg_test3       db 'Test 3: seek operations... $'
msg_test4       db 'Test 4: rename file... $'
msg_test5       db 'Test 5: verify renamed... $'
msg_test6       db 'Test 6: delete file... $'
msg_test7       db 'Test 7: rmdir TESTDIR... $'
msg_ok          db 'OK', 13, 10, '$'
msg_done        db 13, 10, 'All tests passed!', 13, 10, '$'

msg_mkdir_err   db 'FAILED (mkdir)', 13, 10, '$'
msg_create_err  db 'FAILED (create)', 13, 10, '$'
msg_write_err   db 'FAILED (write)', 13, 10, '$'
msg_open_err    db 'FAILED (open)', 13, 10, '$'
msg_seek_err    db 'FAILED (seek)', 13, 10, '$'
msg_seekv_err   db 'FAILED (seek verify)', 13, 10, '$'
msg_read_err    db 'FAILED (read)', 13, 10, '$'
msg_rename_err  db 'FAILED (rename)', 13, 10, '$'
msg_delete_err  db 'FAILED (delete)', 13, 10, '$'
msg_rmdir_err   db 'FAILED (rmdir)', 13, 10, '$'

dirname         db 'TESTDIR', 0
filename1       db 'FSTEST.TXT', 0
filename2       db 'RENAMED.TXT', 0
test_data       db 'Hello from claudeDOS!'
test_data_len   equ $ - test_data

section .bss
handle          resw 1
read_buffer     resb 128
