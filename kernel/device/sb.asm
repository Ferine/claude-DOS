; ===========================================================================
; claudeDOS Sound Blaster Device Driver
; Supports Sound Blaster 1.x/2.0/Pro/16 detection and 8-bit DMA playback
; Default: Base 0x220, IRQ 5, DMA 1
; ===========================================================================

; ---------------------------------------------------------------------------
; DOS device driver header
; ---------------------------------------------------------------------------
sb_device:
    dw      0xFFFF                  ; Next driver (filled by init_devices)
    dw      0
    dw      DEV_ATTR_CHAR | DEV_ATTR_IOCTL
    dw      sb_strategy
    dw      sb_dev_interrupt
    db      'SBSND$  '             ; Device name (8 bytes, space-padded)

sb_req_ptr      dd  0               ; Request packet pointer

; ---------------------------------------------------------------------------
; Strategy routine - store request packet pointer
; ---------------------------------------------------------------------------
sb_strategy:
    mov     [cs:sb_req_ptr], bx
    mov     [cs:sb_req_ptr + 2], es
    retf

; ---------------------------------------------------------------------------
; Interrupt routine - dispatch on command code
; ---------------------------------------------------------------------------
sb_dev_interrupt:
    push    ds
    push    bx
    push    cx
    push    dx
    push    si
    push    di
    push    es
    push    ax

    lds     bx, [cs:sb_req_ptr]
    mov     al, [bx + 2]           ; Command code

    cmp     al, 0                   ; Init
    je      .cmd_init
    cmp     al, 8                   ; Output (write)
    je      .cmd_write
    cmp     al, 13                  ; IOCTL output
    je      .cmd_ioctl

    ; Unknown command - done with no error
    mov     word [bx + 3], 0x0100
    jmp     .done

.cmd_init:
    ; Device init - hardware detection is done in sb_init
    mov     word [bx + 3], 0x0100
    jmp     .done

.cmd_write:
    ; Output command: direct DAC output of buffer contents
    ; This provides simple polled playback through the device driver
    cmp     byte [cs:sb_present], 0
    je      .write_no_hw

    mov     cx, [bx + 18]          ; Transfer count
    push    ds
    lds     si, [bx + 14]          ; Buffer address

.write_loop:
    test    cx, cx
    jz      .write_done
    lodsb                           ; Get sample byte
    call    sb_direct_dac           ; Output via direct DAC
    dec     cx
    jmp     .write_loop

.write_done:
    pop     ds
    lds     bx, [cs:sb_req_ptr]
    mov     word [bx + 3], 0x0100
    jmp     .done

.write_no_hw:
    mov     word [bx + 3], 0x8102  ; Error: device not ready
    jmp     .done

.cmd_ioctl:
    ; IOCTL output - control commands
    ; First byte of buffer = subcommand:
    ;   0 = Get status (returns: present, version, base, irq, dma)
    ;   1 = Speaker on
    ;   2 = Speaker off
    ;   3 = Set sample rate (next byte = time constant)
    ;   4 = Start DMA playback (next 4 bytes = linear addr, next 2 = length)
    ;   5 = Stop DMA playback
    push    ds
    lds     si, [bx + 14]          ; Buffer address
    lodsb                           ; Subcommand

    cmp     al, 0
    je      .ioctl_status
    cmp     al, 1
    je      .ioctl_speaker_on
    cmp     al, 2
    je      .ioctl_speaker_off
    cmp     al, 3
    je      .ioctl_set_rate
    cmp     al, 4
    je      .ioctl_start_dma
    cmp     al, 5
    je      .ioctl_stop_dma

    pop     ds
    lds     bx, [cs:sb_req_ptr]
    mov     word [bx + 3], 0x8103  ; Unknown command
    jmp     .done

.ioctl_status:
    ; Write status info back to caller's buffer
    ; Buffer: [0]=subcommand(0), [1]=present, [2-3]=version, [4-5]=base, [6]=irq, [7]=dma
    pop     ds
    lds     bx, [cs:sb_req_ptr]
    push    es
    push    di
    les     di, [bx + 14]
    mov     al, [cs:sb_present]
    mov     [es:di + 1], al
    mov     ax, [cs:sb_dsp_version]
    mov     [es:di + 2], ax
    mov     ax, [cs:sb_base_port]
    mov     [es:di + 4], ax
    mov     al, [cs:sb_irq]
    mov     [es:di + 6], al
    mov     al, [cs:sb_dma_channel]
    mov     [es:di + 7], al
    pop     di
    pop     es
    mov     word [bx + 3], 0x0100
    jmp     .done

.ioctl_speaker_on:
    call    sb_speaker_on
    pop     ds
    lds     bx, [cs:sb_req_ptr]
    mov     word [bx + 3], 0x0100
    jmp     .done

.ioctl_speaker_off:
    call    sb_speaker_off
    pop     ds
    lds     bx, [cs:sb_req_ptr]
    mov     word [bx + 3], 0x0100
    jmp     .done

.ioctl_set_rate:
    lodsb                           ; Time constant byte
    call    sb_set_time_constant
    pop     ds
    lds     bx, [cs:sb_req_ptr]
    mov     word [bx + 3], 0x0100
    jmp     .done

.ioctl_start_dma:
    ; Buffer[1..4] = 20-bit linear address (low word, high word)
    ; Buffer[5..6] = transfer length - 1
    lodsw                           ; AX = linear address low word
    mov     dx, ax
    lodsw                           ; AX = linear address high word (page)
    mov     bx, ax
    lodsw                           ; AX = transfer length - 1
    mov     cx, ax
    ; BX:DX = linear address, CX = length-1
    call    sb_start_dma_playback
    pop     ds
    lds     bx, [cs:sb_req_ptr]
    mov     word [bx + 3], 0x0100
    jmp     .done

.ioctl_stop_dma:
    call    sb_stop_dma
    pop     ds
    lds     bx, [cs:sb_req_ptr]
    mov     word [bx + 3], 0x0100
    jmp     .done

.done:
    pop     ax
    pop     es
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ds
    retf

; ===========================================================================
; Sound Blaster Hardware Interface
; ===========================================================================

; ---------------------------------------------------------------------------
; sb_init - Detect and initialize Sound Blaster hardware
; Output: CF=0 if detected, CF=1 if not found
;         Sets sb_present, sb_dsp_version
; ---------------------------------------------------------------------------
sb_init:
    pusha
    push    es

    ; Step 1: Reset the DSP
    call    sb_reset_dsp
    jc      .not_found

    ; Step 2: Read DSP version
    mov     al, SB_CMD_DSP_VERSION
    call    sb_write_dsp
    jc      .not_found

    call    sb_read_dsp             ; Major version
    jc      .not_found
    mov     ah, al                  ; AH = major
    push    ax
    call    sb_read_dsp             ; Minor version
    pop     bx
    jc      .not_found
    ; BH = major, AL = minor
    mov     [cs:sb_dsp_version], al     ; Low byte = minor
    mov     [cs:sb_dsp_version + 1], bh ; High byte = major

    ; Step 3: Mark as present
    mov     byte [cs:sb_present], 1

    ; Step 4: Install IRQ handler
    call    sb_install_irq

    ; Step 5: Turn speaker on by default
    call    sb_speaker_on

    ; Step 6: Print detection message
    mov     si, sb_msg_detected
    call    bios_print_string

    ; Print DSP version
    mov     al, [cs:sb_dsp_version + 1]    ; Major
    add     al, '0'
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    mov     al, '.'
    int     0x10
    mov     al, [cs:sb_dsp_version]         ; Minor
    ; Minor might be > 9, print as two digits
    xor     ah, ah
    mov     cl, 10
    div     cl                      ; AL = tens, AH = ones
    add     al, '0'
    push    ax
    mov     ah, 0x0E
    xor     bx, bx
    int     0x10
    pop     ax
    mov     al, ah
    add     al, '0'
    mov     ah, 0x0E
    int     0x10

    mov     si, sb_msg_crlf
    call    bios_print_string

    pop     es
    popa
    clc
    ret

.not_found:
    mov     byte [cs:sb_present], 0
    pop     es
    popa
    stc
    ret

; ---------------------------------------------------------------------------
; sb_reset_dsp - Reset the DSP chip
; Output: CF=0 success, CF=1 timeout
; ---------------------------------------------------------------------------
sb_reset_dsp:
    push    ax
    push    cx
    push    dx

    ; Write 1 to reset port
    mov     dx, [cs:sb_base_port]
    add     dx, SB_PORT_RESET
    mov     al, 1
    out     dx, al

    ; Wait at least 3 microseconds (~10 I/O port reads)
    mov     cx, 10
.reset_delay:
    in      al, dx
    loop    .reset_delay

    ; Write 0 to reset port
    xor     al, al
    out     dx, al

    ; Wait for DSP ready (read 0xAA from read port)
    ; Poll read-status port with limited total attempts
    mov     cx, 0xFFFF
.reset_poll:
    mov     dx, [cs:sb_base_port]
    add     dx, SB_PORT_READ_STATUS
    in      al, dx
    test    al, 0x80                ; Bit 7 = data available
    jnz     .reset_read
    loop    .reset_poll
    jmp     .reset_fail

.reset_read:
    mov     dx, [cs:sb_base_port]
    add     dx, SB_PORT_READ
    in      al, dx
    cmp     al, 0xAA                ; DSP ready signature
    je      .reset_ok

    ; Not ready yet - keep polling with remaining CX count
    ; (don't reset CX, so the outer loop will eventually timeout)
    test    cx, cx
    jz      .reset_fail
    jmp     .reset_poll

.reset_ok:
    pop     dx
    pop     cx
    pop     ax
    clc
    ret

.reset_fail:
    pop     dx
    pop     cx
    pop     ax
    stc
    ret

; ---------------------------------------------------------------------------
; sb_write_dsp - Write a command/data byte to the DSP
; Input:  AL = byte to write
; Output: CF=0 success, CF=1 timeout
; ---------------------------------------------------------------------------
sb_write_dsp:
    push    cx
    push    dx
    push    ax                      ; Save data byte

    ; Wait for DSP ready to accept data (bit 7 of write-status = 0)
    mov     cx, 0xFFFF
    mov     dx, [cs:sb_base_port]
    add     dx, SB_PORT_WRITE_STATUS
.write_wait:
    in      al, dx
    test    al, 0x80
    jz      .write_ready
    loop    .write_wait

    ; Timeout
    pop     ax
    pop     dx
    pop     cx
    stc
    ret

.write_ready:
    pop     ax                      ; Restore data byte
    mov     dx, [cs:sb_base_port]
    add     dx, SB_PORT_WRITE
    out     dx, al

    pop     dx
    pop     cx
    clc
    ret

; ---------------------------------------------------------------------------
; sb_read_dsp - Read a byte from the DSP
; Output: AL = data byte, CF=0 success, CF=1 timeout
; ---------------------------------------------------------------------------
sb_read_dsp:
    push    cx
    push    dx

    ; Wait for data available (bit 7 of read-status = 1)
    mov     cx, 0xFFFF
    mov     dx, [cs:sb_base_port]
    add     dx, SB_PORT_READ_STATUS
.read_wait:
    in      al, dx
    test    al, 0x80
    jnz     .read_ready
    loop    .read_wait

    ; Timeout
    pop     dx
    pop     cx
    stc
    ret

.read_ready:
    mov     dx, [cs:sb_base_port]
    add     dx, SB_PORT_READ
    in      al, dx

    pop     dx
    pop     cx
    clc
    ret

; ---------------------------------------------------------------------------
; sb_speaker_on - Enable DSP speaker output
; ---------------------------------------------------------------------------
sb_speaker_on:
    push    ax
    mov     al, SB_CMD_SPEAKER_ON
    call    sb_write_dsp
    pop     ax
    ret

; ---------------------------------------------------------------------------
; sb_speaker_off - Disable DSP speaker output
; ---------------------------------------------------------------------------
sb_speaker_off:
    push    ax
    mov     al, SB_CMD_SPEAKER_OFF
    call    sb_write_dsp
    pop     ax
    ret

; ---------------------------------------------------------------------------
; sb_set_time_constant - Set the DSP sample rate via time constant
; Input: AL = time constant (256 - 1000000 / sample_rate)
;        e.g., AL=165 for 11025 Hz, AL=211 for 22050 Hz, AL=233 for 44100 Hz
; ---------------------------------------------------------------------------
sb_set_time_constant:
    push    ax
    push    bx
    mov     bl, al                  ; Save time constant
    mov     al, SB_CMD_TIME_CONST
    call    sb_write_dsp
    mov     al, bl
    call    sb_write_dsp
    pop     bx
    pop     ax
    ret

; ---------------------------------------------------------------------------
; sb_direct_dac - Output a single sample byte via direct DAC
; Input: AL = 8-bit unsigned sample (0x80 = silence)
; ---------------------------------------------------------------------------
sb_direct_dac:
    push    ax
    push    bx
    mov     bl, al                  ; Save sample
    mov     al, SB_CMD_DIRECT_DAC
    call    sb_write_dsp
    mov     al, bl
    call    sb_write_dsp
    pop     bx
    pop     ax
    ret

; ---------------------------------------------------------------------------
; sb_install_irq - Install Sound Blaster IRQ handler
; Saves old vector, installs ours, unmasks IRQ on PIC
; ---------------------------------------------------------------------------
sb_install_irq:
    push    es
    push    ax
    push    bx

    xor     ax, ax
    mov     es, ax

    ; Save old IRQ 5 vector (INT 0Dh at 0x34)
    cli
    mov     ax, [es:SB_INT_VECTOR_ADDR]
    mov     [cs:sb_old_irq_vector], ax
    mov     ax, [es:SB_INT_VECTOR_ADDR + 2]
    mov     [cs:sb_old_irq_vector + 2], ax

    ; Install our handler
    mov     word [es:SB_INT_VECTOR_ADDR], sb_irq_handler
    mov     [es:SB_INT_VECTOR_ADDR + 2], cs
    sti

    ; Unmask IRQ 5 on master PIC (bit 5)
    in      al, PIC1_DATA
    and     al, ~SB_IRQ_MASK
    out     PIC1_DATA, al

    pop     bx
    pop     ax
    pop     es
    ret

; ---------------------------------------------------------------------------
; sb_irq_handler - Sound Blaster IRQ handler (IRQ 5 -> INT 0Dh)
; Called when DMA transfer completes a block
; ---------------------------------------------------------------------------
sb_irq_handler:
    push    ax
    push    dx
    push    ds

    mov     ax, cs
    mov     ds, ax

    ; Acknowledge the DSP interrupt by reading the read-status port
    mov     dx, [sb_base_port]
    add     dx, SB_PORT_READ_STATUS
    in      al, dx

    ; Signal that IRQ has fired (for polling by application)
    mov     byte [sb_irq_fired], 1

    ; Clear DMA playing flag for single-cycle mode
    mov     byte [sb_dma_playing], 0

    ; Send EOI to PIC
    mov     al, PIC_EOI
    out     PIC1_COMMAND, al

    pop     ds
    pop     dx
    pop     ax
    iret

; ---------------------------------------------------------------------------
; sb_setup_dma - Program the 8237A DMA controller for Sound Blaster transfer
; Input: BX:DX = 20-bit linear address (BX = page/high, DX = offset/low)
;        CX = transfer length - 1
;        AL = DMA mode byte
; Notes: Address must not cross a 64K page boundary
; ---------------------------------------------------------------------------
sb_setup_dma:
    push    ax
    push    dx

    ; Mask DMA channel 1 (set bit 0 of mask = channel, bit 2 = mask)
    push    ax
    mov     al, 0x05                ; Channel 1 + mask bit
    out     DMA_SINGLE_MASK, al

    ; Reset byte pointer flip-flop
    xor     al, al
    out     DMA_FLIPFLOP_RESET, al

    ; Set DMA mode
    pop     ax                      ; Restore mode byte
    or      al, 0x01                ; Merge in channel 1
    out     DMA_MODE, al

    ; Set base address (low byte, then high byte)
    mov     al, dl                  ; Low byte of address
    out     DMA_ADDR_CH1, al
    mov     al, dh                  ; High byte of address
    out     DMA_ADDR_CH1, al

    ; Set page register (bits 16-19 of linear address)
    mov     al, bl
    out     DMA_PAGE_CH1, al

    ; Set transfer count (low byte, then high byte)
    mov     al, cl
    out     DMA_COUNT_CH1, al
    mov     al, ch
    out     DMA_COUNT_CH1, al

    ; Unmask DMA channel 1
    mov     al, 0x01                ; Channel 1, mask bit = 0
    out     DMA_SINGLE_MASK, al

    pop     dx
    pop     ax
    ret

; ---------------------------------------------------------------------------
; sb_start_dma_playback - Start single-cycle 8-bit DMA playback
; Input: BX:DX = 20-bit linear address (BX = page, DX = offset within page)
;        CX = transfer length - 1
; ---------------------------------------------------------------------------
sb_start_dma_playback:
    push    ax

    ; Clear IRQ fired flag
    mov     byte [cs:sb_irq_fired], 0

    ; Program DMA: single mode, read (device->memory direction is "read" from
    ; DMA perspective, but for playback we want memory->device which is "write")
    ; Actually: for SB playback, DMA reads from memory, so mode = single + read
    ; DMA_MODE_SINGLE (0x40) | DMA_MODE_READ (0x08) | auto-increment
    mov     al, DMA_MODE_SINGLE | DMA_MODE_READ
    call    sb_setup_dma

    ; Tell DSP to do single-cycle 8-bit DMA output
    mov     al, SB_CMD_DMA_8BIT
    call    sb_write_dsp

    ; Send transfer length - 1 (low byte first, then high byte)
    mov     al, cl
    call    sb_write_dsp
    mov     al, ch
    call    sb_write_dsp

    ; Mark as playing
    mov     byte [cs:sb_dma_playing], 1

    pop     ax
    ret

; ---------------------------------------------------------------------------
; sb_start_dma_auto - Start auto-initialize 8-bit DMA playback
; Input: BX:DX = 20-bit linear address (BX = page, DX = offset within page)
;        CX = DMA block size - 1
; Notes: Auto-init loops the DMA buffer continuously. Use sb_set_dma_block_size
;        first to set the DSP's block size, then call this.
; ---------------------------------------------------------------------------
sb_start_dma_auto:
    push    ax

    mov     byte [cs:sb_irq_fired], 0

    ; Program DMA: single mode + auto-initialize + read from memory
    mov     al, DMA_MODE_SINGLE | DMA_MODE_AUTO_INIT | DMA_MODE_READ
    call    sb_setup_dma

    ; Set DSP block transfer size (length - 1)
    mov     al, SB_CMD_DMA_BLOCK_SZ
    call    sb_write_dsp
    mov     al, cl
    call    sb_write_dsp
    mov     al, ch
    call    sb_write_dsp

    ; Start auto-initialize DMA output
    mov     al, SB_CMD_DMA_AUTO_8
    call    sb_write_dsp

    mov     byte [cs:sb_dma_playing], 1

    pop     ax
    ret

; ---------------------------------------------------------------------------
; sb_stop_dma - Halt DMA playback
; ---------------------------------------------------------------------------
sb_stop_dma:
    push    ax

    mov     al, SB_CMD_DMA_HALT
    call    sb_write_dsp

    ; Mask DMA channel 1
    mov     al, 0x05                ; Channel 1 + mask bit
    out     DMA_SINGLE_MASK, al

    mov     byte [cs:sb_dma_playing], 0
    mov     byte [cs:sb_irq_fired], 0

    pop     ax
    ret

; ---------------------------------------------------------------------------
; sb_set_mixer - Write a value to the SBPro/SB16 mixer
; Input: AH = register, AL = value
; ---------------------------------------------------------------------------
sb_set_mixer:
    push    dx
    mov     dx, [cs:sb_base_port]
    add     dx, SB_PORT_MIXER_ADDR
    xchg    ah, al
    out     dx, al                  ; Write register number
    xchg    ah, al
    mov     dx, [cs:sb_base_port]
    add     dx, SB_PORT_MIXER_DATA
    out     dx, al                  ; Write value
    pop     dx
    ret

; ---------------------------------------------------------------------------
; sb_get_mixer - Read a value from the SBPro/SB16 mixer
; Input:  AH = register
; Output: AL = value
; ---------------------------------------------------------------------------
sb_get_mixer:
    push    dx
    mov     dx, [cs:sb_base_port]
    add     dx, SB_PORT_MIXER_ADDR
    mov     al, ah
    out     dx, al                  ; Write register number
    mov     dx, [cs:sb_base_port]
    add     dx, SB_PORT_MIXER_DATA
    in      al, dx                  ; Read value
    pop     dx
    ret

; ---------------------------------------------------------------------------
; Strings
; ---------------------------------------------------------------------------
sb_msg_detected     db  'Sound Blaster detected, DSP version ', 0
sb_msg_crlf         db  0x0D, 0x0A, 0
