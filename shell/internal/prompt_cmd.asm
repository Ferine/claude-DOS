; ===========================================================================
; PROMPT command - Set command prompt
; Tokens: $P=path, $N=drive, $G=>, $L=<, $D=date, $T=time,
;         $Q==, $B=|, $$=$, $_=CRLF, $H=backspace
; ===========================================================================

cmd_prompt:
    pusha

    ; Check if argument provided
    cmp     byte [si], 0
    je      .reset_default

    ; Copy prompt string to prompt_string buffer
    mov     di, prompt_string
.copy_loop:
    lodsb
    cmp     al, 0x0D
    je      .copy_done
    test    al, al
    jz      .copy_done
    stosb
    jmp     .copy_loop
.copy_done:
    mov     byte [di], 0

    popa
    ret

.reset_default:
    ; No argument - reset to default "$P$G"
    mov     word [prompt_string], 'P$'  ; "$P" backwards due to little-endian
    mov     word [prompt_string], '$P'
    mov     byte [prompt_string], '$'
    mov     byte [prompt_string + 1], 'P'
    mov     byte [prompt_string + 2], '$'
    mov     byte [prompt_string + 3], 'G'
    mov     byte [prompt_string + 4], 0

    popa
    ret

; Prompt string storage (default: $P$G)
prompt_string   db  '$P$G', 0
                times 60 db 0       ; Room for custom prompts
