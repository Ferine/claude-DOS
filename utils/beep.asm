; ===========================================================================
; BEEP.COM - Sound the PC speaker
; Usage: BEEP
; ===========================================================================

bits 16
org 0x100

%include "constants.inc"

start:
    ; Output BEL character to trigger beep
    mov     ah, 0x02        ; DOS character output
    mov     dl, BEL_CHAR    ; Bell character (0x07)
    int     0x21

    ; Exit
    mov     ax, 0x4C00
    int     0x21
