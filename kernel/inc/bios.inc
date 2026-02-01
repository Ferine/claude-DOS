; ===========================================================================
; claudeDOS - BIOS Data Area (BDA) Offsets
; ===========================================================================

; BIOS Data Area starts at segment 0040h (linear 0x400)
BDA_SEG             equ     0x0040

; Equipment/hardware
BDA_EQUIPMENT       equ     0x0010  ; Equipment list word
BDA_MEMORY_SIZE     equ     0x0013  ; Memory size in KB (word)

; Keyboard
BDA_KBD_FLAGS1      equ     0x0017  ; Keyboard shift flags 1
BDA_KBD_FLAGS2      equ     0x0018  ; Keyboard shift flags 2
BDA_KBD_BUF_HEAD    equ     0x001A  ; Keyboard buffer head pointer
BDA_KBD_BUF_TAIL    equ     0x001C  ; Keyboard buffer tail pointer
BDA_KBD_BUFFER      equ     0x001E  ; Keyboard buffer (32 bytes)

; Video
BDA_VIDEO_MODE      equ     0x0049  ; Current video mode
BDA_SCREEN_COLS     equ     0x004A  ; Number of screen columns (word)
BDA_VIDEO_PAGE_SIZE equ     0x004C  ; Video page size (word)
BDA_VIDEO_PAGE_OFF  equ     0x004E  ; Active page offset (word)
BDA_CURSOR_POS      equ     0x0050  ; Cursor position (8 pages, word each)
BDA_CURSOR_TYPE     equ     0x0060  ; Cursor type (word)
BDA_ACTIVE_PAGE     equ     0x0062  ; Active display page
BDA_VIDEO_PORT      equ     0x0063  ; Video port base address (word)
BDA_VIDEO_MODE_REG  equ     0x0065  ; Current mode register setting
BDA_CGA_PALETTE     equ     0x0066  ; Current CGA palette

; Disk
BDA_DISK_STATUS     equ     0x0041  ; Disk status byte
BDA_DISK_COUNT      equ     0x0075  ; Number of hard drives
BDA_MOTOR_STATUS    equ     0x003F  ; Floppy motor status
BDA_MOTOR_TIMEOUT   equ     0x0040  ; Floppy motor timeout

; Timer
BDA_TIMER_LOW       equ     0x006C  ; Timer tick count (low word)
BDA_TIMER_HIGH      equ     0x006E  ; Timer tick count (high word)
BDA_TIMER_OVERFLOW  equ     0x0070  ; Timer overflow flag (midnight)

; Serial/Parallel ports
BDA_COM_PORTS       equ     0x0000  ; COM1-COM4 base addresses (4 words)
BDA_LPT_PORTS       equ     0x0008  ; LPT1-LPT3 base addresses (3 words)

; Misc
BDA_BREAK_FLAG      equ     0x0071  ; Ctrl+Break flag
BDA_BOOT_STATUS     equ     0x0072  ; Boot status word (1234h = warm boot)
BDA_SCREEN_ROWS     equ     0x0084  ; Screen rows minus 1 (EGA+)
BDA_CHAR_HEIGHT     equ     0x0085  ; Character height in pixels (word)
