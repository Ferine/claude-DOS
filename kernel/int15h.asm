; ===========================================================================
; claudeDOS INT 15h Handler
; Provides extended memory size reporting for DOS extenders
; ===========================================================================

; ---------------------------------------------------------------------------
; INT 15h Handler - System Services
; Hooks extended memory functions, chains others to BIOS
; ---------------------------------------------------------------------------
int15_handler:
    ; Check for extended memory size query (AH=88h)
    cmp     ah, 88h
    je      .get_ext_mem_size

    ; Check for extended memory size (E801h) - more modern
    cmp     ax, 0E801h
    je      .get_ext_mem_e801

    ; Check for memory map (E820h) - just check AX part
    cmp     ax, 0E820h
    je      .chain_to_bios

    ; Chain to original BIOS handler for all other functions
.chain_to_bios:
    jmp     far [cs:int15_old_vector]

; ---------------------------------------------------------------------------
; AH=88h: Get Extended Memory Size (classic method)
; Returns: AX = KB of extended memory above 1MB (max 64MB - 1KB = 65535 KB)
; ---------------------------------------------------------------------------
.get_ext_mem_size:
    mov     ax, [cs:xms_total_kb]   ; Return extended memory in KB
    clc                             ; Clear carry = success
    ; Need to return with flags from stack modified
    push    bp
    mov     bp, sp
    and     word [bp + 6], 0xFFFE   ; Clear CF in flags on stack
    pop     bp
    iret

; ---------------------------------------------------------------------------
; AX=E801h: Get Extended Memory Size (modern method)
; Returns:
;   AX = extended memory between 1MB-16MB in KB (max 15MB = 15360 KB)
;   BX = extended memory above 16MB in 64KB blocks
;   CX = configured memory 1MB-16MB in KB
;   DX = configured memory above 16MB in 64KB blocks
; ---------------------------------------------------------------------------
.get_ext_mem_e801:
    ; Report 15MB below 16MB boundary, rest above
    mov     ax, [cs:xms_total_kb]
    cmp     ax, 15360               ; More than 15MB?
    jbe     .e801_small

    ; Large memory: split at 16MB boundary
    mov     cx, 15360               ; 15MB below 16MB
    mov     ax, 15360
    sub     word [cs:xms_total_kb], 15360
    mov     bx, [cs:xms_total_kb]
    shr     bx, 6                   ; Convert KB to 64KB blocks
    mov     dx, bx
    add     word [cs:xms_total_kb], 15360  ; Restore
    jmp     .e801_done

.e801_small:
    ; All memory below 16MB
    mov     cx, ax
    xor     bx, bx
    xor     dx, dx

.e801_done:
    clc
    push    bp
    mov     bp, sp
    and     word [bp + 6], 0xFFFE   ; Clear CF in flags
    pop     bp
    iret

; ---------------------------------------------------------------------------
; Storage for original INT 15h vector
; ---------------------------------------------------------------------------
int15_old_vector:
    dw      0                       ; Offset
    dw      0                       ; Segment
