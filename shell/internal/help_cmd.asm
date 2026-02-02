; ===========================================================================
; HELP command - Display list of available commands
; ===========================================================================

cmd_help:
    pusha

    ; Check if specific command requested
    cmp     byte [si], 0
    je      .show_all

    ; TODO: Show help for specific command
    mov     dx, help_specific_msg
    mov     ah, 0x09
    int     0x21
    popa
    ret

.show_all:
    mov     dx, help_header
    mov     ah, 0x09
    int     0x21

    ; Print command list
    mov     dx, help_commands
    mov     ah, 0x09
    int     0x21

    popa
    ret

help_header db  0x0D, 0x0A
            db  'claudeDOS Shell Commands', 0x0D, 0x0A
            db  '========================', 0x0D, 0x0A, 0x0D, 0x0A, '$'

help_commands:
    db  'CD/CHDIR    Change directory', 0x0D, 0x0A
    db  'CLS         Clear screen', 0x0D, 0x0A
    db  'COPY        Copy files', 0x0D, 0x0A
    db  'DATE        Display/set date', 0x0D, 0x0A
    db  'DEL/ERASE   Delete files', 0x0D, 0x0A
    db  'DIR         List directory (/P=pause, /W=wide)', 0x0D, 0x0A
    db  'ECHO        Display message or toggle echo', 0x0D, 0x0A
    db  'EXIT        Exit shell', 0x0D, 0x0A
    db  'HELP        Show this help', 0x0D, 0x0A
    db  'MD/MKDIR    Create directory', 0x0D, 0x0A
    db  'PATH        Display/set search path', 0x0D, 0x0A
    db  'PROMPT      Set command prompt', 0x0D, 0x0A
    db  'RD/RMDIR    Remove directory', 0x0D, 0x0A
    db  'REN/RENAME  Rename file', 0x0D, 0x0A
    db  'SET         Display/set environment variables', 0x0D, 0x0A
    db  'TIME        Display/set time', 0x0D, 0x0A
    db  'TYPE        Display file contents', 0x0D, 0x0A
    db  'VER         Display version', 0x0D, 0x0A
    db  'VOL         Display volume label', 0x0D, 0x0A
    db  0x0D, 0x0A
    db  'Batch commands: CALL, FOR, GOTO, IF, PAUSE, REM, SHIFT', 0x0D, 0x0A
    db  '$'

help_specific_msg db 'Type HELP for list of commands', 0x0D, 0x0A, '$'
