; ===========================================================================
; claudeDOS INT 21h Dispatcher
; ===========================================================================

; ---------------------------------------------------------------------------
; INT 21h handler entry point
; On entry: AH = function number, other registers per function
; On exit: per function (typically AL/AX = result, CF = error)
;
; Strategy: Save all regs in kernel save area, dispatch via jump table,
; handler returns with RET, we restore regs and IRET.
; ---------------------------------------------------------------------------
int21_handler:
    ; Save all caller registers into kernel save area
    ; The stack has: IP, CS, FLAGS (from interrupt)
    mov     [cs:save_ax], ax
    mov     [cs:save_bx], bx
    mov     [cs:save_cx], cx
    mov     [cs:save_dx], dx
    mov     [cs:save_si], si
    mov     [cs:save_di], di
    mov     [cs:save_bp], bp
    mov     [cs:save_ds], ds
    mov     [cs:save_es], es

    ; Set up kernel segments
    push    cs
    pop     ds
    push    cs
    pop     es                      ; ES = kernel segment (for string operations)

    sti
    cld

    inc     byte [indos_flag]

    ; DEBUG: Trace INT 21h function calls to serial port (0x3F8)
    ; Only trace after init (when debug_trace is enabled)
    cmp     byte [debug_trace], 0
    je      .no_trace
    push    ax
    push    dx
    mov     dx, 0x3F8               ; COM1 data port
    mov     al, '['
    out     dx, al
    mov     al, [save_ax + 1]       ; AH = function number
    push    ax
    shr     al, 4
    add     al, '0'
    cmp     al, '9'
    jbe     .d1ok
    add     al, 7
.d1ok:
    out     dx, al
    pop     ax
    and     al, 0x0F
    add     al, '0'
    cmp     al, '9'
    jbe     .d2ok
    add     al, 7
.d2ok:
    out     dx, al
    mov     al, ']'
    out     dx, al
    pop     dx
    pop     ax
.no_trace:

    ; Dispatch: AH is function number
    mov     al, [save_ax + 1]   ; AH from saved AX
    xor     ah, ah
    cmp     al, INT21_MAX_FUNC
    ja      .unimplemented

    mov     si, ax
    shl     si, 1
    mov     si, [int21_table + si]
    test    si, si
    jz      .unimplemented

    ; Restore caller's register values for the handler
    ; Handlers run with DS=kernel segment, but can access caller's
    ; registers via save_XX variables
    mov     ax, [save_ax]
    mov     bx, [save_bx]
    mov     cx, [save_cx]
    mov     dx, [save_dx]
    mov     si, [save_si]
    mov     di, [save_di]
    mov     bp, [save_bp]
    ; DS and ES stay as kernel segment for now
    ; Handlers that need caller's DS/ES use [save_ds]/[save_es]

    ; Call the handler
    ; First, reload dispatch address (we clobbered SI)
    push    ax
    mov     al, [save_ax + 1]
    xor     ah, ah
    mov     si, ax
    shl     si, 1
    mov     si, [int21_table + si]
    pop     ax
    ; Save active drive state (handlers may switch drives via resolve_path)
    call    fat_save_drive

    call    si

    ; Restore active drive state after handler
    call    fat_restore_drive

    ; Handler has returned. Results are in the save area.
    jmp     .return

.unimplemented:
    ; Debug: print unimplemented function number to serial
    cmp     byte [debug_trace], 0
    je      .skip_unimp_trace
    push    ax
    push    dx
    mov     dx, 0x3F8               ; COM1 data port
    mov     al, '!'
    out     dx, al
    mov     al, [save_ax + 1]       ; Function number
    push    ax
    shr     al, 4
    add     al, '0'
    cmp     al, '9'
    jbe     .u1ok
    add     al, 7
.u1ok:
    out     dx, al
    pop     ax
    and     al, 0x0F
    add     al, '0'
    cmp     al, '9'
    jbe     .u2ok
    add     al, 7
.u2ok:
    out     dx, al
    pop     dx
    pop     ax
.skip_unimp_trace:
    ; Unimplemented function - return 0 in AL
    mov     word [save_ax], 0

.return:
    dec     byte [indos_flag]

    ; Restore all registers from save area
    mov     ax, [save_ax]
    mov     bx, [save_bx]
    mov     cx, [save_cx]
    mov     dx, [save_dx]
    mov     si, [save_si]
    mov     di, [save_di]
    mov     bp, [save_bp]
    mov     es, [save_es]
    mov     ds, [save_ds]

    ; Handle carry flag: if handler set [save_flags_cf], set CF in caller's flags
    ; The flags word is at [SP+4] on the stack (IP=SP+0, CS=SP+2, FLAGS=SP+4)
    push    bp
    mov     bp, sp
    test    byte [cs:save_flags_cf], 1
    jz      .clear_cf
    or      word [bp + 6], 0x0001   ; Set CF in saved flags
    jmp     .flags_done
.clear_cf:
    and     word [bp + 6], 0xFFFE   ; Clear CF in saved flags
.flags_done:
    pop     bp
    iret

; ---------------------------------------------------------------------------
; Register save area for INT 21h
; ---------------------------------------------------------------------------
save_ax         dw  0
save_bx         dw  0
save_cx         dw  0
save_dx         dw  0
save_si         dw  0
save_di         dw  0
save_bp         dw  0
save_ds         dw  0
save_es         dw  0
save_flags_cf   db  0           ; 1 = set carry on return

; ---------------------------------------------------------------------------
; Helper: Set carry flag for error return
; Input: AX = error code
; ---------------------------------------------------------------------------
dos_set_error:
    mov     [save_ax], ax
    mov     byte [save_flags_cf], 1
    ret

; ---------------------------------------------------------------------------
; Helper: Clear carry flag for success return
; ---------------------------------------------------------------------------
dos_clear_error:
    mov     byte [save_flags_cf], 0
    ret

; ---------------------------------------------------------------------------
; Helper: Return value in AX (success)
; ---------------------------------------------------------------------------
dos_return_ax:
    mov     [save_ax], ax
    mov     byte [save_flags_cf], 0
    ret

; ---------------------------------------------------------------------------
; INT 21h Function Jump Table
; ---------------------------------------------------------------------------
INT21_MAX_FUNC  equ     0x6C

int21_table:
    dw      int21_00            ; 00h - Terminate program
    dw      int21_01            ; 01h - Character input with echo
    dw      int21_02            ; 02h - Character output
    dw      int21_03            ; 03h - Auxiliary input
    dw      int21_04            ; 04h - Auxiliary output
    dw      int21_05            ; 05h - Printer output
    dw      int21_06            ; 06h - Direct console I/O
    dw      int21_07            ; 07h - Direct input without echo
    dw      int21_08            ; 08h - Input without echo
    dw      int21_09            ; 09h - Print string
    dw      int21_0A            ; 0Ah - Buffered input
    dw      int21_0B            ; 0Bh - Check input status
    dw      int21_0C            ; 0Ch - Flush buffer and input
    dw      int21_0D            ; 0Dh - Disk reset
    dw      int21_0E            ; 0Eh - Set default drive
    dw      int21_0F            ; 0Fh - Open file (FCB)
    dw      int21_10            ; 10h - Close file (FCB)
    dw      int21_11            ; 11h - Find first (FCB)
    dw      int21_12            ; 12h - Find next (FCB)
    dw      int21_13            ; 13h - Delete file (FCB)
    dw      int21_14            ; 14h - Sequential read (FCB)
    dw      int21_15            ; 15h - Sequential write (FCB)
    dw      int21_16            ; 16h - Create file (FCB)
    dw      int21_17            ; 17h - Rename file (FCB)
    dw      int21_18            ; 18h - Reserved
    dw      int21_19            ; 19h - Get default drive
    dw      int21_1A            ; 1Ah - Set DTA
    dw      0                   ; 1Bh - Get default drive info
    dw      0                   ; 1Ch - Get drive info
    dw      0                   ; 1Dh - Reserved
    dw      0                   ; 1Eh - Reserved
    dw      0                   ; 1Fh - Reserved
    dw      0                   ; 20h - Reserved
    dw      int21_21            ; 21h - Random read (FCB)
    dw      int21_22            ; 22h - Random write (FCB)
    dw      int21_23            ; 23h - Get file size (FCB)
    dw      0                   ; 24h - Set random record (FCB)
    dw      int21_25            ; 25h - Set interrupt vector
    dw      0                   ; 26h - Create PSP
    dw      0                   ; 27h - Random block read (FCB)
    dw      0                   ; 28h - Random block write (FCB)
    dw      0                   ; 29h - Parse filename
    dw      int21_2A            ; 2Ah - Get date
    dw      int21_2B            ; 2Bh - Set date
    dw      int21_2C            ; 2Ch - Get time
    dw      int21_2D            ; 2Dh - Set time
    dw      int21_2E            ; 2Eh - Set verify flag
    dw      int21_2F            ; 2Fh - Get DTA
    dw      int21_30            ; 30h - Get DOS version
    dw      int21_31            ; 31h - Terminate and stay resident
    dw      0                   ; 32h - Reserved
    dw      int21_33            ; 33h - Get/Set break flag
    dw      int21_34            ; 34h - Get InDOS flag address
    dw      int21_35            ; 35h - Get interrupt vector
    dw      int21_36            ; 36h - Get disk free space
    dw      0                   ; 37h - Reserved
    dw      0                   ; 38h - Get/Set country info
    dw      int21_39            ; 39h - Create directory
    dw      int21_3A            ; 3Ah - Remove directory
    dw      int21_3B            ; 3Bh - Change directory
    dw      int21_3C            ; 3Ch - Create file
    dw      int21_3D            ; 3Dh - Open file
    dw      int21_3E            ; 3Eh - Close file
    dw      int21_3F            ; 3Fh - Read file
    dw      int21_40            ; 40h - Write file
    dw      int21_41            ; 41h - Delete file
    dw      int21_42            ; 42h - Seek file
    dw      int21_43            ; 43h - Get/Set file attributes
    dw      int21_44            ; 44h - IOCTL
    dw      int21_45            ; 45h - Duplicate handle
    dw      int21_46            ; 46h - Force duplicate handle
    dw      int21_47            ; 47h - Get current directory
    dw      int21_48            ; 48h - Allocate memory
    dw      int21_49            ; 49h - Free memory
    dw      int21_4A            ; 4Ah - Resize memory block
    dw      int21_4B            ; 4Bh - EXEC (load and execute)
    dw      int21_4C            ; 4Ch - Terminate with return code
    dw      int21_4D            ; 4Dh - Get return code
    dw      int21_4E            ; 4Eh - Find first matching file
    dw      int21_4F            ; 4Fh - Find next matching file
    dw      int21_50            ; 50h - Set PSP
    dw      int21_51            ; 51h - Get PSP
    dw      int21_52            ; 52h - Get SysVars (List of Lists)
    dw      0                   ; 53h - Reserved
    dw      0                   ; 54h - Get verify flag
    dw      0                   ; 55h - Reserved
    dw      int21_56            ; 56h - Rename file
    dw      int21_57            ; 57h - Get/Set file date/time
    dw      int21_58            ; 58h - Get/Set allocation strategy
    dw      0                   ; 59h - Get extended error
    dw      0                   ; 5Ah - Create temporary file
    dw      int21_5B            ; 5Bh - Create new file
    dw      0                   ; 5Ch - Lock/Unlock
    dw      0                   ; 5Dh - Reserved
    dw      0                   ; 5Eh - Reserved
    dw      0                   ; 5Fh - Reserved
    dw      0                   ; 60h - Truename
    dw      0                   ; 61h - Reserved
    dw      int21_62            ; 62h - Get PSP address
    dw      0                   ; 63h - Reserved
    dw      0                   ; 64h - Reserved
    dw      0                   ; 65h - Get extended country info
    dw      0                   ; 66h - Get/Set code page
    dw      0                   ; 67h - Set handle count
    dw      0                   ; 68h - Commit file
    dw      0                   ; 69h - Reserved
    dw      0                   ; 6Ah - Reserved
    dw      0                   ; 6Bh - Reserved
    dw      int21_6C            ; 6Ch - Extended open/create
