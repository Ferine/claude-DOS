; ===========================================================================
; claudeDOS - Constants and Error Codes
; ===========================================================================

; DOS version
DOS_VERSION_MAJOR   equ     5
DOS_VERSION_MINOR   equ     0

; Memory layout
KERNEL_SEG          equ     0x0800      ; IO.SYS loaded here (0800:0000 = 0x8000)
KERNEL_OFF          equ     0x0000

; PSP constants
PSP_SIZE            equ     256         ; PSP is 256 bytes
COM_LOAD_OFFSET     equ     0x0100      ; .COM programs load at PSP:0100h

; File handle constants
MAX_HANDLES         equ     20          ; Per-process handle table size
SFT_SIZE            equ     20          ; System File Table entries (default)

; FCB constants
FCB_SIZE            equ     37          ; Standard FCB size
FCB_EXT_SIZE        equ     44          ; Extended FCB size

; MCB constants
MCB_SIGNATURE_NORMAL equ    'M'         ; Not the last block
MCB_SIGNATURE_LAST   equ    'Z'         ; Last block in chain
MCB_FREE            equ     0x0000      ; Free block owner
MCB_SYSTEM          equ     0x0008      ; System-owned block

; Memory allocation strategies
ALLOC_FIRST_FIT     equ     0x00
ALLOC_BEST_FIT      equ     0x01
ALLOC_LAST_FIT      equ     0x02

; File attributes
ATTR_READ_ONLY      equ     0x01
ATTR_HIDDEN         equ     0x02
ATTR_SYSTEM         equ     0x04
ATTR_VOLUME_LABEL   equ     0x08
ATTR_DIRECTORY      equ     0x10
ATTR_ARCHIVE        equ     0x20

; File open modes
OPEN_READ           equ     0x00
OPEN_WRITE          equ     0x01
OPEN_READWRITE      equ     0x02

; Seek origins
SEEK_SET            equ     0x00
SEEK_CUR            equ     0x01
SEEK_END            equ     0x02

; DOS error codes
ERR_NONE            equ     0x00
ERR_INVALID_FUNC    equ     0x01
ERR_FILE_NOT_FOUND  equ     0x02
ERR_PATH_NOT_FOUND  equ     0x03
ERR_TOO_MANY_FILES  equ     0x04
ERR_ACCESS_DENIED   equ     0x05
ERR_INVALID_HANDLE  equ     0x06
ERR_MCB_DESTROYED   equ     0x07
ERR_INSUFFICIENT_MEM equ    0x08
ERR_INVALID_MCB     equ     0x09
ERR_INVALID_ENV     equ     0x0A
ERR_INVALID_FORMAT  equ     0x0B
ERR_INVALID_ACCESS  equ     0x0C
ERR_INVALID_DATA    equ     0x0D
ERR_INVALID_DRIVE   equ     0x0F
ERR_CURRENT_DIR     equ     0x10
ERR_NOT_SAME_DEV    equ     0x11
ERR_NO_MORE_FILES   equ     0x12
ERR_WRITE_PROTECT   equ     0x13
ERR_UNKNOWN_UNIT    equ     0x14
ERR_NOT_READY       equ     0x15
ERR_CRC             equ     0x17
ERR_SEEK            equ     0x19
ERR_NOT_DOS_DISK    equ     0x1A
ERR_SECTOR_NOT_FOUND equ    0x1B
ERR_WRITE_FAULT     equ     0x1D
ERR_READ_FAULT      equ     0x1E
ERR_GENERAL_FAIL    equ     0x1F
ERR_SHARING         equ     0x20
ERR_LOCK            equ     0x21
ERR_DISK_CHANGE     equ     0x22
ERR_NO_FCB          equ     0x23
ERR_FILE_EXISTS     equ     0x50
ERR_DIR_NOT_EMPTY   equ     0x51        ; Directory not empty
ERR_CANNOT_MAKE     equ     0x52
ERR_FAIL_INT24      equ     0x53
ERR_DISK_FULL       equ     0x27        ; Disk full (for write operations)

; INT 21h function numbers (commonly used)
DOS_TERMINATE       equ     0x00
DOS_CHAR_INPUT      equ     0x01
DOS_CHAR_OUTPUT     equ     0x02
DOS_AUX_INPUT       equ     0x03
DOS_AUX_OUTPUT      equ     0x04
DOS_PRN_OUTPUT      equ     0x05
DOS_DIRECT_IO       equ     0x06
DOS_DIRECT_INPUT    equ     0x07
DOS_INPUT_NO_ECHO   equ     0x08
DOS_PRINT_STRING    equ     0x09
DOS_BUFFERED_INPUT  equ     0x0A
DOS_CHECK_INPUT     equ     0x0B
DOS_FLUSH_AND_INPUT equ     0x0C
DOS_DISK_RESET      equ     0x0D
DOS_SET_DRIVE       equ     0x0E
DOS_GET_DRIVE       equ     0x19
DOS_SET_DTA         equ     0x1A
DOS_SET_VECTOR      equ     0x25
DOS_GET_DATE        equ     0x2A
DOS_SET_DATE        equ     0x2B
DOS_GET_TIME        equ     0x2C
DOS_SET_TIME        equ     0x2D
DOS_SET_VERIFY      equ     0x2E
DOS_GET_DTA         equ     0x2F
DOS_GET_VERSION     equ     0x30
DOS_KEEP_PROCESS    equ     0x31
DOS_GET_INDOS       equ     0x34
DOS_GET_VECTOR      equ     0x35
DOS_GET_FREE_SPACE  equ     0x36
DOS_MKDIR           equ     0x39
DOS_RMDIR           equ     0x3A
DOS_CHDIR           equ     0x3B
DOS_CREATE_FILE     equ     0x3C
DOS_OPEN_FILE       equ     0x3D
DOS_CLOSE_FILE      equ     0x3E
DOS_READ_FILE       equ     0x3F
DOS_WRITE_FILE      equ     0x40
DOS_DELETE_FILE     equ     0x41
DOS_SEEK_FILE       equ     0x42
DOS_GET_SET_ATTR    equ     0x43
DOS_IOCTL           equ     0x44
DOS_DUP_HANDLE      equ     0x45
DOS_FORCE_DUP       equ     0x46
DOS_GET_CWD         equ     0x47
DOS_ALLOC_MEM       equ     0x48
DOS_FREE_MEM        equ     0x49
DOS_RESIZE_MEM      equ     0x4A
DOS_EXEC            equ     0x4B
DOS_EXIT            equ     0x4C
DOS_GET_RETCODE     equ     0x4D
DOS_FIND_FIRST      equ     0x4E
DOS_FIND_NEXT       equ     0x4F
DOS_RENAME          equ     0x56
DOS_GET_SET_TIME    equ     0x57
DOS_GET_SET_ALLOC   equ     0x58
DOS_CREATE_NEW      equ     0x5B
DOS_EXT_OPEN        equ     0x6C

; Standard file handles
STDIN               equ     0
STDOUT              equ     1
STDERR              equ     2
STDAUX              equ     3
STDPRN              equ     4

; XMS (Extended Memory Specification) constants
XMS_MAX_HANDLES     equ     16          ; Maximum XMS handles
XMS_HANDLE_SIZE     equ     6           ; Size per handle (2 size + 4 address)

; PS/2 controller ports
PS2_DATA_PORT       equ     0x60
PS2_STATUS_PORT     equ     0x64
PS2_COMMAND_PORT    equ     0x64

; PS/2 status register bits
PS2_STATUS_OUTPUT   equ     0x01
PS2_STATUS_INPUT    equ     0x02
PS2_STATUS_MOUSE    equ     0x20

; PS/2 controller commands
PS2_CMD_READ_CONFIG equ     0x20
PS2_CMD_WRITE_CONFIG equ    0x60
PS2_CMD_DISABLE_PORT2 equ   0xA7
PS2_CMD_ENABLE_PORT2 equ    0xA8
PS2_CMD_TEST_PORT2  equ     0xA9
PS2_CMD_WRITE_PORT2 equ     0xD4

; PS/2 configuration byte bits
PS2_CFG_PORT1_INT   equ     0x01
PS2_CFG_PORT2_INT   equ     0x02
PS2_CFG_PORT1_CLK   equ     0x10
PS2_CFG_PORT2_CLK   equ     0x20

; Mouse commands
MOUSE_CMD_SET_SCALE equ     0xE6
MOUSE_CMD_SET_RES   equ     0xE8
MOUSE_CMD_STATUS    equ     0xE9
MOUSE_CMD_STREAM    equ     0xEA
MOUSE_CMD_READ_DATA equ     0xEB
MOUSE_CMD_SET_SAMPLE equ    0xF3
MOUSE_CMD_ENABLE    equ     0xF4
MOUSE_CMD_DISABLE   equ     0xF5
MOUSE_CMD_DEFAULT   equ     0xF6
MOUSE_CMD_RESET     equ     0xFF

; Mouse response codes
MOUSE_ACK           equ     0xFA
MOUSE_RESEND        equ     0xFE
MOUSE_RESET_OK      equ     0xAA

; PIC ports
PIC1_COMMAND        equ     0x20
PIC1_DATA           equ     0x21
PIC2_COMMAND        equ     0xA0
PIC2_DATA           equ     0xA1
PIC_EOI             equ     0x20

; Screen dimensions
SCREEN_WIDTH        equ     80
SCREEN_HEIGHT       equ     25
SCREEN_PIXELS_X     equ     640
SCREEN_PIXELS_Y     equ     200

; Mouse button masks
MOUSE_BTN_LEFT      equ     0x01
MOUSE_BTN_RIGHT     equ     0x02
MOUSE_BTN_MIDDLE    equ     0x04

; PC Speaker / Timer constants
TIMER_CTRL_PORT     equ     0x43        ; 8253/8254 timer control port
TIMER_CH2_PORT      equ     0x42        ; Timer channel 2 data port
SPEAKER_PORT        equ     0x61        ; Speaker control port (8255 PPI)
TIMER_CH2_MODE3     equ     0xB6        ; Channel 2, lobyte/hibyte, mode 3 (square wave)
BEEP_FREQUENCY      equ     880         ; Default beep frequency (Hz) - A5 note
BEEP_DIVISOR        equ     1193182 / BEEP_FREQUENCY  ; Timer divisor for beep
BEL_CHAR            equ     0x07        ; Bell character (Ctrl+G)
