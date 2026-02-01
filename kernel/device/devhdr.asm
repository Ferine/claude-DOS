; ===========================================================================
; claudeDOS Device Driver Framework
; ===========================================================================

; ---------------------------------------------------------------------------
; init_devices - Initialize the built-in device driver chain
; NUL is always the first device in the chain
; Chain: NUL -> CON -> AUX -> PRN -> CLOCK$
; ---------------------------------------------------------------------------
init_devices:
    push    es
    push    ax

    ; Set device chain head to NUL device
    mov     word [dev_chain_head], nul_device
    mov     [dev_chain_head + 2], cs

    ; Link NUL -> CON
    mov     word [nul_device + DEV_HDR.next_off], con_device
    mov     [nul_device + DEV_HDR.next_seg], cs

    ; Link CON -> AUX
    mov     word [con_device + DEV_HDR.next_off], aux_device
    mov     [con_device + DEV_HDR.next_seg], cs

    ; Link AUX -> PRN
    mov     word [aux_device + DEV_HDR.next_off], prn_device
    mov     [aux_device + DEV_HDR.next_seg], cs

    ; Link PRN -> CLOCK$
    mov     word [prn_device + DEV_HDR.next_off], clock_device
    mov     [prn_device + DEV_HDR.next_seg], cs

    ; CLOCK$ is last
    mov     word [clock_device + DEV_HDR.next_off], 0xFFFF
    mov     word [clock_device + DEV_HDR.next_seg], 0xFFFF

    pop     ax
    pop     es
    ret
