; ===========================================================================
; claudeDOS - Data Structure Definitions
; ===========================================================================

; ---------------------------------------------------------------------------
; Program Segment Prefix (PSP) - 256 bytes at start of each program
; ---------------------------------------------------------------------------
struc PSP
    .int20h         resw    1       ; 00h: INT 20h instruction (CD 20)
    .mem_top        resw    1       ; 02h: Segment of memory top
    .reserved1      resb    1       ; 04h: Reserved
    .dos_call       resb    5       ; 05h: Far call to DOS dispatcher
    .prev_term      resd    1       ; 0Ah: Previous INT 22h (terminate)
    .prev_ctrlc     resd    1       ; 0Eh: Previous INT 23h (Ctrl+C)
    .prev_criterr   resd    1       ; 12h: Previous INT 24h (critical error)
    .parent_psp     resw    1       ; 16h: Parent PSP segment
    .handle_table   resb    20      ; 18h: Job File Table (handle->SFT index)
    .env_seg        resw    1       ; 2Ch: Environment segment
    .saved_sssp     resd    1       ; 2Eh: Saved SS:SP on last INT 21h
    .handle_count   resw    1       ; 32h: Handle table size
    .handle_ptr     resd    1       ; 34h: Far pointer to handle table
    .prev_psp       resd    1       ; 38h: Previous PSP pointer
    .reserved2      resb    20      ; 3Ch: Reserved
    .dos_dispatch   resb    3       ; 50h: INT 21h / RETF
    .reserved3      resb    9       ; 53h: Reserved
    .fcb1           resb    16      ; 5Ch: Default FCB 1
    .fcb2           resb    20      ; 6Ch: Default FCB 2
    .cmd_tail_len   resb    1       ; 80h: Command tail length
    .cmd_tail       resb    127     ; 81h: Command tail string
endstruc

; ---------------------------------------------------------------------------
; File Control Block (FCB) - 37 bytes
; ---------------------------------------------------------------------------
struc FCB
    .drive          resb    1       ; 00h: Drive number (0=default, 1=A:, etc)
    .filename       resb    8       ; 01h: Filename (space-padded)
    .extension      resb    3       ; 09h: Extension (space-padded)
    .cur_block      resw    1       ; 0Ch: Current block number
    .rec_size       resw    1       ; 0Eh: Logical record size
    .file_size      resd    1       ; 10h: File size
    .date           resw    1       ; 14h: Date
    .time           resw    1       ; 16h: Time
    .reserved       resb    8       ; 18h: Reserved (used internally)
    .cur_rec        resb    1       ; 20h: Current record within block
    .rand_rec       resd    1       ; 21h: Random record number
endstruc

; ---------------------------------------------------------------------------
; Memory Control Block (MCB) - 16 bytes (paragraph header)
; ---------------------------------------------------------------------------
struc MCB
    .signature      resb    1       ; 00h: 'M' = more blocks, 'Z' = last
    .owner          resw    1       ; 01h: Owner PSP segment (0 = free)
    .size           resw    1       ; 03h: Size in paragraphs (excl. header)
    .reserved       resb    3       ; 05h: Reserved
    .name           resb    8       ; 08h: Owner name (DOS 4.0+)
endstruc

; ---------------------------------------------------------------------------
; System File Table Entry (SFT) - internal file tracking
; ---------------------------------------------------------------------------
struc SFT_ENTRY
    .ref_count      resw    1       ; 00h: Reference count
    .open_mode      resw    1       ; 02h: Open mode
    .attr           resb    1       ; 04h: File attribute
    .flags          resw    1       ; 05h: Device info / flags
    .device_ptr     resd    1       ; 07h: Pointer to device header or DPB
    .first_cluster  resw    1       ; 0Bh: First cluster
    .time           resw    1       ; 0Dh: Time stamp
    .date           resw    1       ; 0Fh: Date stamp
    .file_size      resd    1       ; 11h: File size
    .file_pos       resd    1       ; 15h: Current file position
    .rel_cluster    resw    1       ; 19h: Relative cluster within file
    .cur_cluster    resw    1       ; 1Bh: Current cluster
    .dir_sector     resw    1       ; 1Dh: Sector of directory entry
    .dir_index      resb    1       ; 1Fh: Index within directory sector
    .name           resb    11      ; 20h: FCB-style filename
endstruc
SFT_ENTRY_SIZE equ 43

; ---------------------------------------------------------------------------
; Device Driver Header
; ---------------------------------------------------------------------------
struc DEV_HDR
    .next_off       resw    1       ; 00h: Next driver offset (FFFFh if last)
    .next_seg       resw    1       ; 02h: Next driver segment
    .attribute      resw    1       ; 04h: Device attribute word
    .strategy       resw    1       ; 06h: Strategy routine offset
    .interrupt      resw    1       ; 08h: Interrupt routine offset
    .name           resb    8       ; 0Ah: Device name (char) or units (block)
endstruc

; Device attribute bits
DEV_ATTR_CHAR       equ     0x8000  ; Character device (vs block)
DEV_ATTR_IOCTL      equ     0x4000  ; IOCTL supported
DEV_ATTR_OCRM       equ     0x0800  ; Open/Close/RM supported
DEV_ATTR_ISCLK      equ     0x0008  ; Current CLOCK$ device
DEV_ATTR_ISNUL      equ     0x0004  ; Current NUL device
DEV_ATTR_STDOUT     equ     0x0002  ; Current STDOUT device
DEV_ATTR_STDIN      equ     0x0001  ; Current STDIN device

; ---------------------------------------------------------------------------
; Current Directory Structure (CDS)
; ---------------------------------------------------------------------------
struc CDS
    .path           resb    67      ; 00h: Current path (e.g., "A:\DIR")
    .flags          resw    1       ; 43h: Flags
    .dpb_ptr        resd    1       ; 45h: Pointer to DPB
    .start_cluster  resw    1       ; 49h: Start cluster of current dir
    .reserved       resw    2       ; 4Bh: Reserved
    .backslash_off  resw    1       ; 4Fh: Offset of backslash in path
endstruc
CDS_SIZE equ 81

; CDS flags
CDS_VALID           equ     0x4000  ; Drive is valid
CDS_PHYSICAL        equ     0xC000  ; Physical drive
CDS_NETWORK         equ     0x8000  ; Network drive
CDS_JOINED          equ     0x2000  ; JOINed drive
CDS_SUBST           equ     0x1000  ; SUBSTed drive

; ---------------------------------------------------------------------------
; Disk Transfer Area (DTA) for FindFirst/FindNext - 43 bytes
; ---------------------------------------------------------------------------
struc DTA
    .reserved       resb    21      ; 00h: Reserved (search state)
    .attr           resb    1       ; 15h: File attribute
    .time           resw    1       ; 16h: File time
    .date           resw    1       ; 18h: File date
    .size           resd    1       ; 1Ah: File size
    .name           resb    13      ; 1Eh: Filename (ASCIIZ)
endstruc
