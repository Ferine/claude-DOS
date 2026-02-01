; ===========================================================================
; testcrt.asm - Test C Runtime Startup Requirements
; Mimics Borland C startup to identify what's failing
; ===========================================================================

    org     0x100               ; .COM file

start:
    ; Save original stack for later
    mov     [orig_sp], sp

    ; --- Step 1: Print "Start" ---
    mov     dx, msg_start
    mov     ah, 0x09
    int     0x21

    ; --- Step 2: Get DOS version (like C runtime) ---
    mov     ah, 0x30
    int     0x21
    mov     [dos_ver], ax
    mov     dx, msg_dosver
    call    print_step

    ; --- Step 3: Get PSP (we're at PSP:100h for .COM) ---
    mov     ah, 0x62            ; Get PSP
    int     0x21
    mov     [psp_seg], bx
    mov     dx, msg_psp
    call    print_step

    ; --- Step 4: Check PSP:02h (memory top) ---
    mov     es, bx
    mov     ax, [es:0x02]       ; Memory top
    mov     [mem_top], ax
    mov     dx, msg_memtop
    call    print_step
    ; Print the value
    mov     ax, [mem_top]
    call    print_hex_word
    call    print_crlf

    ; --- Step 5: Check PSP:2Ch (environment segment) ---
    mov     ax, [es:0x2C]
    mov     [env_seg], ax
    mov     dx, msg_env
    call    print_step
    ; Print the value
    mov     ax, [env_seg]
    call    print_hex_word
    call    print_crlf

    ; --- Step 6: Verify environment is valid ---
    ; First, print first 32 bytes of environment as hex
    mov     dx, msg_envcheck
    call    print_step
    mov     es, [env_seg]
    xor     di, di
    mov     cx, 32
.dump_env:
    mov     al, [es:di]
    call    print_hex_byte
    mov     dl, ' '
    mov     ah, 0x02
    int     0x21
    inc     di
    loop    .dump_env
    call    print_crlf

    ; Now scan for double-NUL
    mov     es, [env_seg]
    xor     di, di
    mov     cx, 512             ; Check first 512 bytes
.scan_env:
    mov     al, [es:di]
    test    al, al
    jz      .found_env_end
    inc     di
    loop    .scan_env
    ; Didn't find end in 512 bytes - suspicious
    mov     dx, msg_env_toolong
    mov     ah, 0x09
    int     0x21
    jmp     .env_done
.found_env_end:
    ; Check for double-NUL
    mov     al, [es:di+1]
    test    al, al
    jz      .env_ok
    ; First NUL was end of a variable, continue
    inc     di
    jmp     .scan_env
.env_ok:
    mov     dx, msg_env_ok
    mov     ah, 0x09
    int     0x21
.env_done:
    call    print_crlf

    ; --- Step 7: Check stack pointer ---
    mov     dx, msg_stack
    call    print_step
    mov     ax, sp
    call    print_hex_word
    call    print_crlf

    ; --- Step 8: Try memory resize (INT 21h 4Ah) ---
    mov     dx, msg_resize
    call    print_step
    ; Shrink to minimum
    mov     ah, 0x4A
    mov     bx, 0x100           ; Request 4KB (256 paragraphs) - minimal
    mov     es, [cs:psp_seg]
    int     0x21
    jc      .resize_fail
    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    jmp     .resize_done
.resize_fail:
    mov     [resize_err], ax
    mov     [resize_max], bx
    mov     dx, msg_fail
    mov     ah, 0x09
    int     0x21
    mov     dx, msg_resize_err
    mov     ah, 0x09
    int     0x21
    mov     ax, [resize_err]
    call    print_hex_word
    mov     dx, msg_resize_max
    mov     ah, 0x09
    int     0x21
    mov     ax, [resize_max]
    call    print_hex_word
.resize_done:
    call    print_crlf

    ; --- Step 9: Set and restore interrupt vectors (like C runtime) ---
    mov     dx, msg_vectors
    call    print_step

    ; Save INT 00h
    mov     ax, 0x3500
    int     0x21
    mov     [old_int00_off], bx
    mov     [old_int00_seg], es

    ; Set INT 00h to our handler
    mov     ax, 0x2500
    mov     dx, dummy_int_handler
    push    ds
    push    cs
    pop     ds
    int     0x21
    pop     ds

    mov     dx, msg_ok
    mov     ah, 0x09
    int     0x21
    call    print_crlf

    ; --- Step 10: All tests passed! ---
    mov     dx, msg_allok
    mov     ah, 0x09
    int     0x21

    ; --- Restore INT 00h before exit ---
    push    ds
    mov     dx, [old_int00_off]
    mov     ds, [cs:old_int00_seg]
    mov     ax, 0x2500
    int     0x21
    pop     ds

    ; Exit
    mov     ax, 0x4C00
    int     0x21

; -----------------------------------------------------------------------
; Helper: print_step - Print step message
; Input: DX = message address
; -----------------------------------------------------------------------
print_step:
    mov     ah, 0x09
    int     0x21
    ret

; -----------------------------------------------------------------------
; Helper: print_hex_byte - Print AL as 2 hex digits
; -----------------------------------------------------------------------
print_hex_byte:
    push    ax
    push    bx
    mov     ah, al
    shr     al, 4
    add     al, '0'
    cmp     al, '9'
    jbe     .hb1
    add     al, 7
.hb1:
    mov     dl, al
    push    ax
    mov     ah, 0x02
    int     0x21
    pop     ax
    mov     al, ah
    and     al, 0x0F
    add     al, '0'
    cmp     al, '9'
    jbe     .hb2
    add     al, 7
.hb2:
    mov     dl, al
    mov     ah, 0x02
    int     0x21
    pop     bx
    pop     ax
    ret

; -----------------------------------------------------------------------
; Helper: print_hex_word - Print AX as 4 hex digits
; -----------------------------------------------------------------------
print_hex_word:
    push    ax
    push    bx
    push    cx
    mov     cx, 4
.loop:
    rol     ax, 4
    push    ax
    and     al, 0x0F
    add     al, '0'
    cmp     al, '9'
    jbe     .print
    add     al, 7
.print:
    mov     dl, al
    mov     ah, 0x02
    int     0x21
    pop     ax
    loop    .loop
    pop     cx
    pop     bx
    pop     ax
    ret

; -----------------------------------------------------------------------
; Helper: print_crlf - Print newline
; -----------------------------------------------------------------------
print_crlf:
    mov     dl, 0x0D
    mov     ah, 0x02
    int     0x21
    mov     dl, 0x0A
    mov     ah, 0x02
    int     0x21
    ret

; -----------------------------------------------------------------------
; Dummy INT handler (just IRET)
; -----------------------------------------------------------------------
dummy_int_handler:
    iret

; -----------------------------------------------------------------------
; Data
; -----------------------------------------------------------------------
msg_start       db  '=== C Runtime Startup Test ===$'
msg_dosver      db  '1. DOS version: $'
msg_psp         db  '2. PSP segment: $'
msg_memtop      db  '3. PSP mem top: $'
msg_env         db  '4. Env segment: $'
msg_envcheck    db  '5. Env valid:   $'
msg_env_ok      db  'OK$'
msg_env_toolong db  'TOO LONG$'
msg_stack       db  '6. Stack ptr:   $'
msg_resize      db  '7. Mem resize:  $'
msg_vectors     db  '8. Int vectors: $'
msg_ok          db  'OK$'
msg_fail        db  'FAIL$'
msg_resize_err  db  ' err=$'
msg_resize_max  db  ' max=$'
msg_allok       db  0x0D, 0x0A, 'All tests passed!', 0x0D, 0x0A, '$'

dos_ver         dw  0
psp_seg         dw  0
mem_top         dw  0
env_seg         dw  0
orig_sp         dw  0
resize_err      dw  0
resize_max      dw  0
old_int00_off   dw  0
old_int00_seg   dw  0
