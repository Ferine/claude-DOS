; Directory operations and FindFirst/FindNext test
org 0x100

section .text
start:
    mov     dx, msg_header
    mov     ah, 0x09
    int     0x21

    ; Set DTA for find operations
    mov     dx, dta
    mov     ah, 0x1A
    int     0x21

    ; ===== DIRECTORY TESTS =====
    mov     dx, msg_section_dir
    mov     ah, 0x09
    int     0x21

    ; Test 1: Create directory
.t1:
    mov     dx, msg_t1
    mov     ah, 0x09
    int     0x21
    mov     dx, dirname
    mov     ah, 0x39
    int     0x21
    jc      .t1_fail
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .t2

.t1_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

    ; Test 2: Change to new directory
.t2:
    mov     dx, msg_t2
    mov     ah, 0x09
    int     0x21
    mov     dx, dirname
    mov     ah, 0x3B
    int     0x21
    jc      .t2_fail
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .t3

.t2_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

    ; Test 3: Get current directory
.t3:
    mov     dx, msg_t3
    mov     ah, 0x09
    int     0x21
    mov     si, curdir_buf
    mov     dl, 0               ; Current drive
    mov     ah, 0x47
    int     0x21
    jc      .t3_fail
    ; Print the current dir
    mov     dx, msg_curdir
    mov     ah, 0x09
    int     0x21
    mov     dx, curdir_buf
    call    print_asciiz
    mov     dx, crlf
    mov     ah, 0x09
    int     0x21
    jmp     .t4

.t3_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

    ; Test 4: Create file in subdirectory
.t4:
    mov     dx, msg_t4
    mov     ah, 0x09
    int     0x21
    mov     dx, subfile
    mov     cx, 0
    mov     ah, 0x3C
    int     0x21
    jc      .t4_fail
    mov     [handle], ax
    ; Write something
    mov     bx, ax
    mov     dx, subdata
    mov     cx, subdata_len
    mov     ah, 0x40
    int     0x21
    ; Close
    mov     bx, [handle]
    mov     ah, 0x3E
    int     0x21
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .t5

.t4_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

    ; Test 5: Change back to root
.t5:
    mov     dx, msg_t5
    mov     ah, 0x09
    int     0x21
    mov     dx, rootdir
    mov     ah, 0x3B
    int     0x21
    jc      .t5_fail
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .t6

.t5_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

    ; ===== FINDFIRST/FINDNEXT TESTS =====
    mov     dx, msg_section_find
    mov     ah, 0x09
    int     0x21

    ; Test 6: FindFirst *.COM
.t6:
    mov     dx, msg_t6
    mov     ah, 0x09
    int     0x21
    mov     dx, pattern_com
    mov     cx, 0               ; Normal files
    mov     ah, 0x4E
    int     0x21
    jc      .t6_fail
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    ; Print first match
    mov     dx, msg_found
    mov     ah, 0x09
    int     0x21
    lea     dx, [dta + 30]      ; Filename at offset 30 in DTA
    call    print_asciiz
    mov     dx, crlf
    mov     ah, 0x09
    int     0x21
    jmp     .t7

.t6_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

    ; Test 7: FindNext (continue search)
.t7:
    mov     dx, msg_t7
    mov     ah, 0x09
    int     0x21
    mov     ah, 0x4F
    int     0x21
    jc      .t7_nomore
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    ; Print next match
    mov     dx, msg_found
    mov     ah, 0x09
    int     0x21
    lea     dx, [dta + 30]
    call    print_asciiz
    mov     dx, crlf
    mov     ah, 0x09
    int     0x21
    jmp     .t8

.t7_nomore:
    mov     dx, msg_nomore
    mov     ah, 0x09
    int     0x21

    ; Test 8: FindFirst for directories
.t8:
    mov     dx, msg_t8
    mov     ah, 0x09
    int     0x21
    mov     dx, pattern_all
    mov     cx, 0x10            ; Include directories
    mov     ah, 0x4E
    int     0x21
    jc      .t8_fail
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .t9

.t8_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

    ; Test 9: Count files with *.* pattern
.t9:
    mov     dx, msg_t9
    mov     ah, 0x09
    int     0x21
    mov     dx, pattern_all
    mov     cx, 0x17            ; All attributes
    mov     ah, 0x4E
    int     0x21
    jc      .t9_fail
    mov     word [file_count], 1
.count_loop:
    mov     ah, 0x4F
    int     0x21
    jc      .count_done
    inc     word [file_count]
    jmp     .count_loop
.count_done:
    mov     ax, [file_count]
    call    print_decimal
    mov     dx, msg_files_found
    mov     ah, 0x09
    int     0x21
    jmp     .cleanup

.t9_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21

    ; ===== CLEANUP =====
.cleanup:
    mov     dx, msg_section_cleanup
    mov     ah, 0x09
    int     0x21

    ; Delete file in subdirectory
    mov     dx, subfile_full
    mov     ah, 0x41
    int     0x21

    ; Remove subdirectory
    mov     dx, dirname
    mov     ah, 0x3A
    int     0x21
    jc      .rmdir_fail
    mov     dx, msg_rmdir_ok
    mov     ah, 0x09
    int     0x21
    jmp     .done

.rmdir_fail:
    mov     dx, msg_rmdir_fail
    mov     ah, 0x09
    int     0x21

.done:
    mov     dx, msg_done
    mov     ah, 0x09
    int     0x21
    mov     ax, 0x4C00
    int     0x21

; Print ASCIIZ string at DS:DX
print_asciiz:
    push    si
    push    ax
    mov     si, dx
.loop:
    lodsb
    test    al, al
    jz      .done
    mov     dl, al
    mov     ah, 0x02
    int     0x21
    jmp     .loop
.done:
    pop     ax
    pop     si
    ret

; Print AX as decimal
print_decimal:
    push    bx
    push    cx
    push    dx
    mov     bx, 10
    xor     cx, cx
.div_loop:
    xor     dx, dx
    div     bx
    push    dx
    inc     cx
    test    ax, ax
    jnz     .div_loop
.print_digits:
    pop     dx
    add     dl, '0'
    mov     ah, 0x02
    int     0x21
    loop    .print_digits
    pop     dx
    pop     cx
    pop     bx
    ret

section .data
msg_header      db 'Directory and FindFirst/FindNext Test', 13, 10
                db '======================================', 13, 10, '$'
msg_section_dir     db 13, 10, '--- DIRECTORY TESTS ---', 13, 10, '$'
msg_section_find    db 13, 10, '--- FIND TESTS ---', 13, 10, '$'
msg_section_cleanup db 13, 10, '--- CLEANUP ---', 13, 10, '$'

msg_t1          db 'T1: mkdir SUBDIR... $'
msg_t2          db 'T2: cd SUBDIR... $'
msg_t3          db 'T3: getcwd... $'
msg_t4          db 'T4: create file in subdir... $'
msg_t5          db 'T5: cd \ (back to root)... $'
msg_t6          db 'T6: FindFirst *.COM... $'
msg_t7          db 'T7: FindNext... $'
msg_t8          db 'T8: FindFirst with dirs... $'
msg_t9          db 'T9: Count *.* files: $'

msg_ok          db 'OK', 13, 10, '$'
msg_fail        db 'FAIL', 13, 10, '$'
msg_nomore      db 'No more files', 13, 10, '$'
msg_found       db '     Found: $'
msg_curdir      db '     Current: $'
msg_files_found db ' files found', 13, 10, '$'
msg_rmdir_ok    db 'Removed SUBDIR OK', 13, 10, '$'
msg_rmdir_fail  db 'Failed to remove SUBDIR', 13, 10, '$'
msg_done        db 13, 10, '=== DIRECTORY TESTS COMPLETE ===', 13, 10, '$'
crlf            db 13, 10, '$'

dirname         db 'SUBDIR', 0
rootdir         db '\', 0
subfile         db 'SUBTEST.TXT', 0
subfile_full    db 'SUBDIR\SUBTEST.TXT', 0
subdata         db 'Data in subdirectory'
subdata_len     equ $ - subdata

pattern_com     db '*.COM', 0
pattern_all     db '*.*', 0

section .bss
handle          resw 1
file_count      resw 1
curdir_buf      resb 64
dta             resb 128
