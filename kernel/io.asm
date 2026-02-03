; ===========================================================================
; claudeDOS IO.SYS - Main Kernel Entry Point
; Loaded at 0060:0000 by stage2 loader
; ===========================================================================

    CPU     186
    ORG     0x0000

; Kernel is assembled as a single flat binary.
; All modules are %included here.

%include "constants.inc"
%include "macros.inc"
%include "structs.inc"
%include "bios.inc"

; ---------------------------------------------------------------------------
; Kernel entry point - jumped to by stage2
; DL = boot drive
; ---------------------------------------------------------------------------
kernel_entry:
    ; Set up kernel segments
    mov     ax, cs
    mov     ds, ax
    mov     es, ax

    ; Save boot drive
    mov     [boot_drive], dl

    ; Set up a temporary stack at the top of the kernel segment
    ; (Will be moved once we know kernel size)
    cli
    mov     ss, ax
    mov     sp, 0xFFFE
    sti

    ; Print kernel banner
    mov     si, banner_msg
    call    bios_print_string

    ; Initialize kernel subsystems
    call    kernel_init

    ; Check if COMMAND.COM loading is available
    cmp     byte [shell_available], 1
    jne     .no_shell

    ; Load and execute COMMAND.COM
    call    load_shell
    ; If load_shell returns, the shell exited
    mov     si, msg_shell_exit
    call    bios_print_string
    jmp     .halt

.no_shell:
    mov     si, msg_ready
    call    bios_print_string

.halt:
    sti
.halt_loop:
    hlt
    jmp     .halt_loop

; ---------------------------------------------------------------------------
; Include kernel modules
; ---------------------------------------------------------------------------

; Kernel initialization
%include "init.asm"

; Data areas
%include "data.asm"

; INT 21h dispatcher and function handlers
%include "int21h/dispatch.asm"
%include "int21h/char_io.asm"

; Device drivers
%include "device/devhdr.asm"
%include "device/nul.asm"
%include "device/con.asm"

; FAT filesystem
%include "fat/common.asm"
%include "fat/fat12.asm"
%include "fat/fat16.asm"

; Memory management
%include "mem/mcb.asm"

; Process execution
%include "exec/psp.asm"
%include "exec/env.asm"
%include "exec/com_loader.asm"
%include "exec/exe_loader.asm"

; Additional INT 21h function groups
%include "int21h/file_io.asm"
%include "int21h/fcb.asm"
%include "int21h/dir.asm"
%include "int21h/disk.asm"
%include "int21h/memory.asm"
%include "int21h/process.asm"
%include "int21h/misc.asm"
%include "int21h/dos5.asm"

; UMB/HMA support
%include "mem/umb.asm"
%include "mem/hma.asm"

; XMS (Extended Memory) support
%include "mem/xms.asm"
%include "int2fh.asm"
%include "int15h.asm"
%include "int31h.asm"
%include "int67h.asm"

; CONFIG.SYS parser
%include "config.asm"

; Additional device drivers
%include "device/aux.asm"
%include "device/prn.asm"
%include "device/clock.asm"
%include "device/ramdisk.asm"

; Mouse driver
%include "mouse.asm"

; ---------------------------------------------------------------------------
; bios_print_string - Print null-terminated string at DS:SI via BIOS
; Used during early boot before INT 21h is available
; ---------------------------------------------------------------------------
bios_print_string:
    pusha
    mov     ah, 0x0E
    xor     bx, bx
.loop:
    lodsb
    test    al, al
    jz      .done
    int     0x10
    jmp     .loop
.done:
    popa
    ret

; ---------------------------------------------------------------------------
; Kernel data strings
; ---------------------------------------------------------------------------
banner_msg      db  0x0D, 0x0A
                db  'claudeDOS version 5.00', 0x0D, 0x0A
                db  0x0D, 0x0A, 0
msg_ready       db  'System ready.', 0x0D, 0x0A, 0
msg_shell_exit  db  'Shell terminated.', 0x0D, 0x0A, 0

; ---------------------------------------------------------------------------
; End of kernel marker (used by memory init to find free memory)
; ---------------------------------------------------------------------------
kernel_end:
