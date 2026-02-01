; ===========================================================================
; ECHO command - Display message or toggle echo
; ===========================================================================

cmd_echo:
    pusha

    ; Check for no arguments -> show echo state
    cmp     byte [si], 0
    je      .show_state

    ; Check for ON/OFF
    push    si
    mov     di, echo_on_str
    call    str_equal
    pop     si
    je      .set_on

    push    si
    mov     di, echo_off_str
    call    str_equal
    pop     si
    je      .set_off

    ; Check for "." (ECHO.)
    cmp     byte [si], '.'
    je      .blank_line

    ; Print the argument text
    mov     dx, si
    call    print_asciiz
    call    print_crlf
    jmp     .done

.show_state:
    cmp     byte [echo_on], 1
    je      .echo_is_on
    mov     dx, echo_off_msg
    jmp     .print_state
.echo_is_on:
    mov     dx, echo_on_msg
.print_state:
    mov     ah, 0x09
    int     0x21
    jmp     .done

.set_on:
    mov     byte [echo_on], 1
    jmp     .done

.set_off:
    mov     byte [echo_on], 0
    jmp     .done

.blank_line:
    call    print_crlf

.done:
    popa
    ret

echo_on_str     db  'ON', 0
echo_off_str    db  'OFF', 0
echo_on_msg     db  'ECHO is on', 0x0D, 0x0A, '$'
echo_off_msg    db  'ECHO is off', 0x0D, 0x0A, '$'
