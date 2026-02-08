; ===========================================================================
; claudeDOS DOS 5.0 Specific Functions
; ===========================================================================

; ---------------------------------------------------------------------------
; INT 21h AH=38h - Get/Set Country Info
;
; Get: DS:DX = pointer to 34-byte buffer
;      AL = country code (0=current, 01h-FEh=specific, FFh=BX has code)
; Returns: BX = country code, buffer filled
;
; Set: DX = FFFFh
;      AL = country code (01h-FEh, or FFh=BX has code)
; Returns: success
; ---------------------------------------------------------------------------
int21_38:
    ; Check if this is Set Country (DX=FFFFh)
    cmp     word [save_dx], 0xFFFF
    je      .set_country

    ; --- Get Country Info ---
    ; Set up source: DS:SI -> country_info (already in kernel segment)
    mov     si, country_info
    mov     cx, 34

    ; Set up destination: ES:DI -> caller's buffer (save_ds:save_dx)
    mov     es, [save_ds]
    mov     di, [save_dx]

    ; Copy 34 bytes
    rep     movsb

    ; Patch the case-map FAR pointer at offset 12h in caller's buffer
    ; Write the actual FAR address of casemap_func (CS:casemap_func)
    mov     di, [save_dx]
    mov     word [es:di + 12h], casemap_func
    mov     word [es:di + 14h], cs

    ; Restore ES to kernel segment
    push    cs
    pop     es

    ; Return country code in BX
    mov     ax, [current_country]
    mov     [save_bx], ax

    call    dos_clear_error
    ret

.set_country:
    ; --- Set Country ---
    ; Determine country code from AL (or BX if AL=FFh)
    mov     al, [save_ax]           ; AL from caller
    cmp     al, 0FFh
    je      .set_from_bx
    xor     ah, ah
    mov     [current_country], ax
    jmp     .set_done
.set_from_bx:
    mov     ax, [save_bx]
    mov     [current_country], ax
.set_done:
    call    dos_clear_error
    ret

; ---------------------------------------------------------------------------
; Case-map function (FAR callable)
; Called via the pointer in the country info structure
; Input: AL = character to uppercase
; Output: AL = uppercased character
; ---------------------------------------------------------------------------
casemap_func:
    cmp     al, 'a'
    jb      .no_change
    cmp     al, 'z'
    ja      .no_change
    sub     al, 20h
.no_change:
    retf
