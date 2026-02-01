; ===========================================================================
; claudeDOS Environment Block Management
; ===========================================================================

; The environment block is a series of ASCIIZ strings,
; terminated by an additional NUL byte.
; After the double-NUL, a word count, then the program name.
;
; Format:
;   VAR1=VALUE1\0
;   VAR2=VALUE2\0
;   \0                    <- double NUL (end of variables)
;   \x01\x00              <- count word (always 1)
;   A:\PROGRAM.EXE\0      <- program full path

; ---------------------------------------------------------------------------
; Default environment
; ---------------------------------------------------------------------------
default_env:
    db  'PATH=A:\', 0
    db  'COMSPEC=A:\COMMAND.COM', 0
    db  'PROMPT=$P$G', 0
    db  0                       ; End of environment

; ---------------------------------------------------------------------------
; env_create_with_path - Create new environment block with program path
; Input:  DS:SI = source environment segment (or 0 for default)
;         ES:DI = program filename (ASCIIZ, e.g. "CHESS.EXE")
; Output: AX = segment of new environment block
;         CF set on error (out of memory)
; Notes:  Caller must free the environment block when process terminates
; ---------------------------------------------------------------------------
env_create_with_path:
    push    bx
    push    cx
    push    dx
    push    si
    push    di
    push    es

    ; Save program name pointer
    mov     [cs:.prog_name_off], di
    mov     [cs:.prog_name_seg], es

    ; Source environment segment
    mov     [cs:.src_env_seg], si

    ; Calculate size needed:
    ; - Size of source environment (up to and including double-NUL)
    ; - 2 bytes for count word
    ; - Length of "A:\" prefix (3 bytes)
    ; - Length of program filename + NUL

    ; First, measure source environment
    mov     ax, si
    test    ax, ax
    jnz     .has_src_env
    ; No source - use default environment
    mov     ax, cs
    mov     ds, ax              ; DS = kernel segment (for default_env)
    mov     si, default_env
    jmp     .measure_env

.has_src_env:
    mov     ds, ax
    xor     si, si              ; Start at offset 0

.measure_env:
    ; DS:SI = start of environment
    ; Count bytes until double-NUL
    xor     cx, cx              ; Byte count
.measure_loop:
    lodsb
    inc     cx
    test    al, al              ; End of string?
    jnz     .measure_loop
    ; Found NUL - check if next byte is also NUL (double-NUL)
    cmp     byte [si], 0
    jne     .measure_loop       ; More strings, continue
    ; Found double-NUL, cx includes first NUL
    inc     cx                  ; Include the terminating NUL

    ; Save environment size (includes double-NUL)
    mov     [cs:.env_size], cx

    ; Add space for: count word (2) + "A:\" (3) + filename + NUL
    add     cx, 2               ; Count word
    add     cx, 3               ; "A:\" prefix

    ; Measure program filename
    push    cx
    mov     es, [cs:.prog_name_seg]
    mov     di, [cs:.prog_name_off]
    xor     cx, cx
.measure_name:
    mov     al, [es:di]
    inc     di
    inc     cx
    test    al, al
    jnz     .measure_name
    ; CX = length including NUL
    mov     [cs:.name_len], cx
    pop     cx
    add     cx, [cs:.name_len]

    ; Round up to paragraphs: (cx + 15) / 16
    add     cx, 15
    shr     cx, 4
    mov     bx, cx              ; BX = paragraphs needed

    ; Allocate memory
    push    cs
    pop     ds                  ; DS = kernel for mcb_alloc
    call    mcb_alloc
    jc      .alloc_fail

    ; AX = new environment segment
    mov     [cs:.new_env_seg], ax

    ; Copy source environment to new block
    mov     es, ax
    xor     di, di              ; ES:DI = dest

    ; Set up source
    mov     ax, [cs:.src_env_seg]
    test    ax, ax
    jnz     .copy_from_seg
    ; Copy from default
    mov     ax, cs
    mov     ds, ax              ; DS = kernel segment (for default_env)
    mov     si, default_env
    jmp     .do_copy

.copy_from_seg:
    mov     ds, ax
    xor     si, si

.do_copy:
    ; Copy environment variables (up to and including double-NUL)
    mov     cx, [cs:.env_size]

    ; DEBUG: print copy params (DS, SI, ES, DI, CX)
    cmp     byte [cs:debug_trace], 0
    je      .skip_copy_debug
    push    ax
    push    bx
    ; Print 'C' DS:SI->ES:DI cx
    mov     al, 'C'
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    mov     ax, ds
    call    .dbg_hex_ax
    mov     al, ':'
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    mov     ax, si
    call    .dbg_hex_ax
    mov     al, '-'
    mov     ah, 0x0E
    int     0x10
    mov     al, '>'
    int     0x10
    mov     ax, es
    call    .dbg_hex_ax
    mov     al, ':'
    mov     ah, 0x0E
    int     0x10
    mov     ax, di
    call    .dbg_hex_ax
    mov     al, ' '
    mov     ah, 0x0E
    int     0x10
    mov     ax, [cs:.env_size]
    call    .dbg_hex_ax
    mov     al, ' '
    mov     ah, 0x0E
    int     0x10
    pop     bx
    pop     ax
.skip_copy_debug:

    rep     movsb

    ; DEBUG: verify first byte after copy
    cmp     byte [cs:debug_trace], 0
    je      .skip_verify_debug
    push    ax
    push    bx
    push    es
    mov     es, [cs:.new_env_seg]
    mov     al, '>'
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    mov     al, [es:0]
    call    .dbg_hex_al
    mov     al, ' '
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    pop     es
    pop     bx
    pop     ax
.skip_verify_debug:

    ; ES:DI now points after double-NUL
    ; Add count word (always 1)
    mov     word [es:di], 0x0001
    add     di, 2

    ; Add drive prefix "A:\"
    mov     byte [es:di], 'A'
    inc     di
    mov     byte [es:di], ':'
    inc     di
    mov     byte [es:di], '\'
    inc     di

    ; Copy program filename
    mov     ds, [cs:.prog_name_seg]
    mov     si, [cs:.prog_name_off]
    mov     cx, [cs:.name_len]
    rep     movsb

    ; Return new environment segment
    mov     ax, [cs:.new_env_seg]

    ; DEBUG: verify env data is still valid before returning
    cmp     byte [cs:debug_trace], 0
    je      .skip_final_debug
    push    ax
    push    bx
    push    es
    mov     es, ax
    mov     al, '!'
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    mov     al, [es:0]
    call    .dbg_hex_al
    mov     al, ' '
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    pop     es
    pop     bx
    pop     ax
.skip_final_debug:

    clc

.done:
    push    cs
    pop     ds                  ; Restore DS = kernel
    pop     es
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    ret

.alloc_fail:
    push    cs
    pop     ds
    stc
    jmp     .done

; Local variables for env_create_with_path
.src_env_seg    dw  0
.prog_name_off  dw  0
.prog_name_seg  dw  0
.env_size       dw  0
.name_len       dw  0
.new_env_seg    dw  0

; Debug helper: print AX as hex
.dbg_hex_ax:
    push    ax
    push    cx
    mov     cx, 4
.dha_loop:
    rol     ax, 4
    push    ax
    and     al, 0x0F
    add     al, '0'
    cmp     al, '9'
    jbe     .dha_p
    add     al, 7
.dha_p:
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    pop     ax
    loop    .dha_loop
    pop     cx
    pop     ax
    ret

; Debug helper: print AL as hex
.dbg_hex_al:
    push    ax
    push    bx
    mov     ah, al
    shr     al, 4
    add     al, '0'
    cmp     al, '9'
    jbe     .dha_hi
    add     al, 7
.dha_hi:
    push    ax
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    pop     ax
    mov     al, ah
    and     al, 0x0F
    add     al, '0'
    cmp     al, '9'
    jbe     .dha_lo
    add     al, 7
.dha_lo:
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    pop     bx
    pop     ax
    ret

; ---------------------------------------------------------------------------
; env_find - Find an environment variable
; Input: ES:DI = environment segment:0
;        DS:SI = variable name (e.g. "PATH")
; Output: CF=0, ES:DI = value string / CF=1 not found
; ---------------------------------------------------------------------------
env_find:
    push    ax
    push    bx
    push    cx
    push    si
    
.next_var:
    ; Check for end of environment
    cmp     byte [es:di], 0
    je      .not_found
    
    ; Compare variable name
    push    si
    push    di
.cmp_loop:
    lodsb                       ; From search name
    test    al, al              ; End of search name?
    jz      .check_equals
    mov     ah, [es:di]
    inc     di
    ; Case-insensitive compare
    cmp     al, 'a'
    jb      .no_upper1
    cmp     al, 'z'
    ja      .no_upper1
    sub     al, 0x20
.no_upper1:
    cmp     ah, 'a'
    jb      .no_upper2
    cmp     ah, 'z'
    ja      .no_upper2
    sub     ah, 0x20
.no_upper2:
    cmp     al, ah
    jne     .skip_var
    jmp     .cmp_loop
    
.check_equals:
    cmp     byte [es:di], '='
    jne     .skip_var
    inc     di                  ; Skip '='
    pop     bx                  ; Discard saved DI
    pop     bx                  ; Discard saved SI
    ; ES:DI now points to the value
    clc
    pop     si
    pop     cx
    pop     bx
    pop     ax
    ret
    
.skip_var:
    pop     di
    pop     si
    ; Skip to next variable (find NUL)
.find_nul:
    cmp     byte [es:di], 0
    je      .found_nul
    inc     di
    jmp     .find_nul
.found_nul:
    inc     di
    jmp     .next_var
    
.not_found:
    stc
    pop     si
    pop     cx
    pop     bx
    pop     ax
    ret
