; ===========================================================================
; VOL command - Display disk volume label
; ===========================================================================

cmd_vol:
    pusha

    ; Get current drive
    mov     ah, 0x19
    int     0x21
    add     al, 'A'
    mov     [vol_drive], al

    ; Print "Volume in drive X"
    mov     dx, vol_msg1
    mov     ah, 0x09
    int     0x21

    ; Print drive letter
    mov     dl, [vol_drive]
    mov     ah, 0x02
    int     0x21

    ; Find volume label using FindFirst with volume attribute
    mov     dx, vol_dta
    mov     ah, 0x1A                ; Set DTA
    int     0x21

    ; Build search path "X:\*.*"
    mov     al, [vol_drive]
    mov     [vol_search], al

    mov     dx, vol_search
    mov     cx, 0x08                ; Volume label attribute only
    mov     ah, 0x4E                ; FindFirst
    int     0x21
    jc      .no_label

    ; Found volume label - print it
    mov     dx, vol_msg2
    mov     ah, 0x09
    int     0x21

    ; Print volume label (at DTA+30)
    mov     si, vol_dta + 30
    call    print_asciiz
    call    print_crlf
    jmp     .done

.no_label:
    ; No volume label
    mov     dx, vol_msg3
    mov     ah, 0x09
    int     0x21

.done:
    popa
    ret

vol_msg1    db  ' Volume in drive $'
vol_msg2    db  ' is $'
vol_msg3    db  ' has no label', 0x0D, 0x0A, '$'
vol_drive   db  0
vol_search  db  'A:\*.*', 0
vol_dta     times 43 db 0
