; ===========================================================================
; DIR command - Display directory listing
; ===========================================================================

cmd_dir:
    pusha

    ; Print header
    mov     dx, dir_header
    mov     ah, 0x09
    int     0x21

    ; Use FindFirst/FindNext to list files
    ; Set DTA to our buffer
    mov     dx, dir_dta
    mov     ah, 0x1A
    int     0x21

    ; FindFirst: DS:DX = filespec, CX = attributes
    mov     dx, si              ; Use argument as filespec
    cmp     byte [si], 0        ; No argument?
    jne     .have_spec
    mov     dx, dir_all_spec    ; Default: "*.*"
.have_spec:
    mov     cx, 0x37            ; All attributes including dirs
    mov     ah, 0x4E
    int     0x21
    jc      .no_files

.show_entry:
    ; DTA+21 = attribute, DTA+22 = time, DTA+24 = date,
    ; DTA+26 = size (dword), DTA+30 = name (13 bytes)

    ; Check if directory
    test    byte [dir_dta + 21], 0x10
    jnz     .show_dir

    ; Print filename (padded to 13 chars)
    mov     si, dir_dta + 30
    call    .print_padded_name

    ; Print file size (32-bit)
    mov     ax, [dir_dta + 26]  ; Low word of size
    mov     dx, [dir_dta + 28]  ; High word of size
    call    print_dec32

    call    print_crlf
    jmp     .find_next

.show_dir:
    mov     si, dir_dta + 30
    call    .print_padded_name
    mov     dx, dir_dir_tag
    mov     ah, 0x09
    int     0x21
    call    print_crlf

.find_next:
    mov     ah, 0x4F
    int     0x21
    jnc     .show_entry

.no_files:
    popa
    ret

.print_padded_name:
    ; Print name, pad with spaces to 15 chars
    push    cx
    xor     cx, cx
.pn_loop:
    lodsb
    test    al, al
    jz      .pn_pad
    mov     dl, al
    mov     ah, 0x02
    int     0x21
    inc     cx
    jmp     .pn_loop
.pn_pad:
    cmp     cx, 15
    jae     .pn_done
    mov     dl, ' '
    mov     ah, 0x02
    int     0x21
    inc     cx
    jmp     .pn_pad
.pn_done:
    pop     cx
    ret

; DIR data
dir_header      db  ' Volume in drive A is CLAUDEDOS', 0x0D, 0x0A
                db  ' Directory of A:\', 0x0D, 0x0A, 0x0D, 0x0A, '$'
dir_all_spec    db  '*.*', 0
dir_dir_tag     db  '<DIR>$'
dir_dta         times 43 db 0
