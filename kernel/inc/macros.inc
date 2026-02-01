; ===========================================================================
; claudeDOS - Common NASM Macros
; ===========================================================================

; Print a null-terminated string using INT 21h AH=09h ($-terminated)
; For use after INT 21h is installed
%macro DOS_PRINT 1
    push    dx
    push    ax
    mov     dx, %1
    mov     ah, 0x09
    int     0x21
    pop     ax
    pop     dx
%endmacro

; Print a null-terminated string using BIOS INT 10h
; For use during early boot before INT 21h is installed
%macro BIOS_PRINT 1
    push    si
    mov     si, %1
    call    bios_print_string
    pop     si
%endmacro

; Set DS:DX to a string address
%macro SET_DSDX 1
    mov     dx, %1
%endmacro

; Return from INT 21h with carry flag clear (success)
%macro RET_SUCCESS 0
    clc
    retf    2       ; Return from interrupt, discard saved flags
%endmacro

; Return from INT 21h with carry flag set (error) and error code in AX
%macro RET_ERROR 1
    mov     ax, %1
    stc
    retf    2
%endmacro

; Save all registers used in INT 21h handlers
%macro SAVE_REGS 0
    push    bx
    push    cx
    push    dx
    push    si
    push    di
    push    bp
    push    ds
    push    es
%endmacro

; Restore all registers
%macro RESTORE_REGS 0
    pop     es
    pop     ds
    pop     bp
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
%endmacro

; Define a device driver header
; %1 = next driver offset (or -1)
; %2 = attribute word
; %3 = strategy entry point
; %4 = interrupt entry point
; %5 = device name (8 bytes)
%macro DEV_HEADER 5
    dw      %1          ; Offset of next driver (or FFFFh)
    dw      0           ; Segment of next driver (filled in at init)
    dw      %2          ; Device attribute word
    dw      %3          ; Strategy routine offset
    dw      %4          ; Interrupt routine offset
    db      %5          ; Device name (8 bytes, space-padded)
%endmacro

; Align to paragraph (16-byte) boundary
%macro ALIGN_PARA 0
    align   16
%endmacro
