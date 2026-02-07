; TESTDPMI.COM - Test INT 31h DPMI handler
; Exercises implemented functions and verifies error returns
org 0x100

section .text
start:
    mov     dx, msg_header
    mov     ah, 0x09
    int     0x21

    ; ===== TEST 1: Get Selector Increment (AX=0003h) =====
    mov     dx, msg_test1
    mov     ah, 0x09
    int     0x21

    mov     ax, 0x0003
    int     0x31
    jc      .test1_fail
    cmp     ax, 8
    jne     .test1_fail

    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .test2

.test1_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21
    inc     byte [fail_count]

    ; ===== TEST 2: Get Real Mode Interrupt Vector (AX=0200h) =====
.test2:
    mov     dx, msg_test2
    mov     ah, 0x09
    int     0x21

    ; Read INT 21h vector via DPMI
    mov     ax, 0x0200
    mov     bl, 0x21
    int     0x31
    jc      .test2_fail

    ; CX:DX should be non-zero (INT 21h is installed)
    mov     ax, cx
    or      ax, dx
    jz      .test2_fail

    ; Also verify it matches the IVT directly
    push    es
    xor     ax, ax
    mov     es, ax
    cmp     dx, [es:0x21*4]        ; Compare offset
    jne     .test2_fail_pop
    cmp     cx, [es:0x21*4+2]      ; Compare segment
    jne     .test2_fail_pop
    pop     es

    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .test3

.test2_fail_pop:
    pop     es
.test2_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21
    inc     byte [fail_count]

    ; ===== TEST 3: Set/Get Real Mode Interrupt Vector (AX=0201h/0200h) =====
.test3:
    mov     dx, msg_test3
    mov     ah, 0x09
    int     0x21

    ; Save original INT 66h vector (unused, safe to modify)
    mov     ax, 0x0200
    mov     bl, 0x66
    int     0x31
    jc      .test3_fail
    mov     [saved_seg], cx
    mov     [saved_off], dx

    ; Set INT 66h to a known value: 1234h:5678h
    mov     ax, 0x0201
    mov     bl, 0x66
    mov     cx, 0x1234
    mov     dx, 0x5678
    int     0x31
    jc      .test3_fail

    ; Read it back
    mov     ax, 0x0200
    mov     bl, 0x66
    int     0x31
    jc      .test3_fail
    cmp     cx, 0x1234
    jne     .test3_fail
    cmp     dx, 0x5678
    jne     .test3_fail

    ; Restore original vector
    mov     ax, 0x0201
    mov     bl, 0x66
    mov     cx, [saved_seg]
    mov     dx, [saved_off]
    int     0x31

    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .test4

.test3_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21
    inc     byte [fail_count]

    ; ===== TEST 4: Get DPMI Version (AX=0400h) =====
.test4:
    mov     dx, msg_test4
    mov     ah, 0x09
    int     0x21

    mov     ax, 0x0400
    int     0x31
    jc      .test4_fail
    ; AH=0 (major), AL=9 (minor)
    cmp     ax, 0x0009
    jne     .test4_fail
    ; BX=0002h (16-bit only)
    cmp     bx, 0x0002
    jne     .test4_fail
    ; CL=3 (386 processor)
    cmp     cl, 3
    jne     .test4_fail

    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .test5

.test4_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21
    inc     byte [fail_count]

    ; ===== TEST 5: Get Free Memory Info (AX=0500h) =====
.test5:
    mov     dx, msg_test5
    mov     ah, 0x09
    int     0x21

    ; Zero the buffer first
    push    ds
    pop     es
    mov     di, mem_buf
    mov     cx, 24
    xor     ax, ax
    rep     stosw

    ; Call Get Free Memory
    mov     di, mem_buf
    mov     ax, 0x0500
    int     0x31
    jc      .test5_fail

    ; Verify first dword is FFFFFFFFh
    cmp     word [mem_buf], 0xFFFF
    jne     .test5_fail
    cmp     word [mem_buf+2], 0xFFFF
    jne     .test5_fail

    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .test6

.test5_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21
    inc     byte [fail_count]

    ; ===== TEST 6: Get Page Size (AX=0604h) =====
.test6:
    mov     dx, msg_test6
    mov     ah, 0x09
    int     0x21

    mov     ax, 0x0604
    int     0x31
    jc      .test6_fail
    ; BX:CX should be 0000:1000h
    test    bx, bx
    jnz     .test6_fail
    cmp     cx, 0x1000
    jne     .test6_fail

    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .test7

.test6_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21
    inc     byte [fail_count]

    ; ===== TEST 7: Virtual Interrupt State (AX=0902h) =====
.test7:
    mov     dx, msg_test7
    mov     ah, 0x09
    int     0x21

    ; Interrupts should be enabled, so AL should be 1
    sti
    mov     ax, 0x0902
    int     0x31
    jc      .test7_fail
    cmp     al, 1
    jne     .test7_fail

    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .test8

.test7_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21
    inc     byte [fail_count]

    ; ===== TEST 8: Get & Disable Interrupt State (AX=0900h) =====
.test8:
    mov     dx, msg_test8
    mov     ah, 0x09
    int     0x21

    sti                             ; Ensure IF is set
    mov     ax, 0x0900
    int     0x31
    jc      .test8_fail
    ; AL should be 1 (was enabled)
    cmp     al, 1
    jne     .test8_fail

    ; After iret, IF should be cleared — verify via 0902h
    mov     ax, 0x0902
    int     0x31
    cmp     al, 0
    jne     .test8_fail

    ; Re-enable interrupts for remaining tests
    sti

    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .test9

.test8_fail:
    sti                             ; Safety: re-enable interrupts
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21
    inc     byte [fail_count]

    ; ===== TEST 9: Get & Enable Interrupt State (AX=0901h) =====
.test9:
    mov     dx, msg_test9
    mov     ah, 0x09
    int     0x21

    ; Disable interrupts first, then use 0901h to re-enable
    cli
    mov     ax, 0x0901
    int     0x31
    jc      .test9_fail
    ; AL should be 0 (was disabled)
    cmp     al, 0
    jne     .test9_fail

    ; After iret, IF should be set — verify
    mov     ax, 0x0902
    int     0x31
    cmp     al, 1
    jne     .test9_fail

    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .test10

.test9_fail:
    sti                             ; Safety
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21
    inc     byte [fail_count]

    ; ===== TEST 10: Unsupported function returns error (AX=0000h) =====
.test10:
    mov     dx, msg_test10
    mov     ah, 0x09
    int     0x21

    mov     ax, 0x0000              ; Allocate LDT Descriptors — unsupported
    mov     cx, 1
    int     0x31
    jnc     .test10_fail            ; Should fail with CF set
    cmp     ax, 0x8011              ; DPMI_ERR_NO_DESCRIPTORS
    jne     .test10_fail

    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .test11

.test10_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21
    inc     byte [fail_count]

    ; ===== TEST 11: Unknown group returns unsupported (AH=FFh) =====
.test11:
    mov     dx, msg_test11
    mov     ah, 0x09
    int     0x21

    mov     ax, 0xFF00              ; Completely unknown group
    int     0x31
    jnc     .test11_fail            ; Should fail
    cmp     ax, 0x8001              ; DPMI_ERR_UNSUPPORTED
    jne     .test11_fail

    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .done

.test11_fail:
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21
    inc     byte [fail_count]

    ; ===== Summary =====
.done:
    mov     dx, msg_divider
    mov     ah, 0x09
    int     0x21

    cmp     byte [fail_count], 0
    jne     .some_failed

    mov     dx, msg_all_pass
    mov     ah, 0x09
    int     0x21
    mov     ax, 0x4C00              ; Exit with code 0
    int     0x21

.some_failed:
    ; Print fail count
    mov     dx, msg_fail_prefix
    mov     ah, 0x09
    int     0x21
    mov     al, [fail_count]
    add     al, '0'
    mov     dl, al
    mov     ah, 0x02
    int     0x21
    mov     dx, msg_fail_suffix
    mov     ah, 0x09
    int     0x21
    mov     ax, 0x4C01              ; Exit with code 1
    int     0x21

section .data
msg_header      db 'INT 31h DPMI Handler Tests', 13, 10
                db '==========================', 13, 10, '$'
msg_test1       db 'Test 1:  Selector increment.. $'
msg_test2       db 'Test 2:  Get int vector...... $'
msg_test3       db 'Test 3:  Set/get int vector.. $'
msg_test4       db 'Test 4:  DPMI version........ $'
msg_test5       db 'Test 5:  Free memory info.... $'
msg_test6       db 'Test 6:  Page size........... $'
msg_test7       db 'Test 7:  Get IF state........ $'
msg_test8       db 'Test 8:  Disable interrupts.. $'
msg_test9       db 'Test 9:  Enable interrupts... $'
msg_test10      db 'Test 10: Unsupported func.... $'
msg_test11      db 'Test 11: Unknown group....... $'
msg_ok          db 'OK', 13, 10, '$'
msg_fail        db 'FAIL', 13, 10, '$'
msg_divider     db '==========================', 13, 10, '$'
msg_all_pass    db 'All 11 tests passed!', 13, 10, '$'
msg_fail_prefix db '$'
msg_fail_suffix db ' test(s) FAILED', 13, 10, '$'

section .bss
fail_count      resb 1
saved_seg       resw 1
saved_off       resw 1
mem_buf         resb 48
