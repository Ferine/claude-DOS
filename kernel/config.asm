; ===========================================================================
; claudeDOS CONFIG.SYS Parser - Stub (Phase 10)
; ===========================================================================

; ---------------------------------------------------------------------------
; parse_config_sys - Parse CONFIG.SYS at boot time
; ---------------------------------------------------------------------------
parse_config_sys:
    ret

; CONFIG.SYS settings (defaults)
config_files    dw  8           ; FILES= (default 8)
config_buffers  dw  15          ; BUFFERS= (default 15)
config_lastdrive db 5           ; LASTDRIVE= (default E)
config_shell    times 64 db 0   ; SHELL= path
config_dos_high db  0           ; DOS=HIGH
config_dos_umb  db  0           ; DOS=UMB
