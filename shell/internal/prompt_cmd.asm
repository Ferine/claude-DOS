; ===========================================================================
; PROMPT command - Set command prompt
; ===========================================================================

cmd_prompt:
    pusha

    ; Stub - just acknowledge
    mov     dx, prompt_stub_msg
    mov     ah, 0x09
    int     0x21

    popa
    ret

prompt_stub_msg db  'PROMPT set.', 0x0D, 0x0A, '$'
