; ===========================================================================
; claudeDOS Kernel Data Areas
; ===========================================================================

; ---------------------------------------------------------------------------
; List of Lists (SysVars) structure
; INT 21h AH=52h returns pointer to 'sysvars'
; First MCB segment is at [sysvars - 2] per DOS convention
; ---------------------------------------------------------------------------
sysvars_mcb_ptr     dw  0           ; First MCB segment (at sysvars - 2)
sysvars:                            ; INT 21h AH=52h returns ES:BX pointing here
    .dpb_ptr        dd  0           ; +00h: Pointer to first DPB
    .sft_ptr        dd  0           ; +04h: Pointer to SFT
    .clock_ptr      dd  0           ; +08h: Pointer to CLOCK$ device
    .con_ptr        dd  0           ; +0Ch: Pointer to CON device
    .max_bytes_sec  dw  512         ; +10h: Max bytes per sector
    .disk_buf_ptr   dd  0           ; +12h: Pointer to disk buffer info
    .cds_ptr        dd  0           ; +16h: Pointer to CDS array
    .fcb_table_ptr  dd  0           ; +1Ah: Pointer to FCB table
    .fcb_keep_count dw  0           ; +1Eh: FCB keep count
    .block_devices  db  1           ; +20h: Number of block devices
    .lastdrive      db  LASTDRIVE   ; +21h: LASTDRIVE value
    ; (more fields exist in real DOS but we stop here)

; ---------------------------------------------------------------------------
; System variables
; ---------------------------------------------------------------------------
boot_drive          db  0           ; Boot drive number (from BIOS)
current_drive       db  0           ; Current default drive (0=A:)
verify_flag         db  0           ; Verify-after-write flag
break_flag          db  0           ; Ctrl+Break check flag
indos_flag          db  0           ; InDOS flag (reentrancy guard)
error_mode          db  0           ; Error mode flag
debug_trace         db  0           ; Debug: trace INT 21h calls (0=off, 1=on)
shell_available     db  0           ; 1 if COMMAND.COM can be loaded
return_code         dw  0           ; Last program return code
alloc_strategy      db  0           ; Memory allocation strategy

; Timer tick counter (18.2 Hz)
ticks_count         dd  0
int08_old_vector    dd  0
int1c_old_vector    dd  0

; DOS version info
dos_version_major   db  DOS_VERSION_MAJOR
dos_version_minor   db  DOS_VERSION_MINOR

; Current DTA (Disk Transfer Area) pointer
current_dta_off     dw  0
current_dta_seg     dw  0

; Default DTA (128 bytes, used before any program loads)
default_dta         times 128 db 0

; ---------------------------------------------------------------------------
; System File Table (SFT)
; First 5 entries are for STDIN, STDOUT, STDERR, STDAUX, STDPRN
; ---------------------------------------------------------------------------
sft_header:
    dw      0xFFFF              ; Next SFT pointer (offset) - no next
    dw      0                   ; Next SFT pointer (segment)
    dw      SFT_SIZE            ; Number of entries in this table
sft_table:
    times   SFT_ENTRY_SIZE * SFT_SIZE db 0

; ---------------------------------------------------------------------------
; Current Directory Structure (CDS) - one per drive (A:-Z:)
; For now, only allocate for drives A: and B: to save space
; ---------------------------------------------------------------------------
MAX_DRIVES          equ     26
LASTDRIVE           equ     5       ; Default: A: through E:
cds_table:
    times   CDS_SIZE * LASTDRIVE db 0

; ---------------------------------------------------------------------------
; Device driver chain head
; ---------------------------------------------------------------------------
dev_chain_head:
    dw      0                   ; Offset of first device driver
    dw      0                   ; Segment of first device driver

; ---------------------------------------------------------------------------
; Disk I/O buffer (one sector)
; ---------------------------------------------------------------------------
disk_buffer:
    times   512 db 0

; ---------------------------------------------------------------------------
; FAT buffer (for single FAT sector caching)
; ---------------------------------------------------------------------------
fat_buffer:
    times   512 db 0
fat_buffer_sector   dw  0xFFFF      ; Cached FAT sector number (FFFF=none)

; ---------------------------------------------------------------------------
; File operation workspace
; ---------------------------------------------------------------------------
found_dir_entry     times 32 db 0   ; Last found directory entry
search_attr         db  0           ; Search attribute for FindFirst/Next
search_drive        db  0           ; Drive for current search
search_name         times 11 db 0   ; FCB-format search name
search_dir_sector   dw  0           ; Current directory sector being searched
search_dir_index    dw  0           ; Current entry index in search
search_dir_cluster  dw  0           ; Directory cluster being searched (0=root)

; ---------------------------------------------------------------------------
; Path parsing workspace
; ---------------------------------------------------------------------------
path_buffer         times 128 db 0  ; Temporary path buffer
fcb_name_buffer     times 11 db 0   ; Temporary FCB name

; ---------------------------------------------------------------------------
; Current directory state
; ---------------------------------------------------------------------------
current_dir_cluster dw  0           ; 0 = root directory
current_dir_path    times 64 db 0   ; Current directory path string (ASCIIZ)

; ---------------------------------------------------------------------------
; Disk geometry for LBA-to-CHS conversion (used as memory operand for DIV)
; ---------------------------------------------------------------------------
fat_spt             dw  18          ; Sectors per track (1.44MB floppy)
fat_heads           dw  2           ; Number of heads

; ---------------------------------------------------------------------------
; XMS (Extended Memory Specification) State
; ---------------------------------------------------------------------------
xms_installed       db  1           ; XMS available (always 1 for claudeDOS)
xms_total_kb        dw  16384       ; Total extended memory (16MB)
xms_free_kb         dw  16384       ; Free extended memory in KB
xms_handles:                        ; XMS handle table (16 handles)
    times XMS_MAX_HANDLES * XMS_HANDLE_SIZE db 0

; ---------------------------------------------------------------------------
; EXEC workspace (saved parent state)
; ---------------------------------------------------------------------------
exec_parent_ss      dw  0           ; Parent SS during EXEC
exec_parent_sp      dw  0           ; Parent SP during EXEC
exec_parent_psp     dw  0           ; Parent PSP segment
exec_filename       times 128 db 0  ; Filename buffer for EXEC
exec_fcb_name       times 11 db 0   ; FCB name for EXEC
exec_is_exe         db  0           ; 1 = .EXE, 0 = .COM
exec_start_cluster  dw  0           ; Start cluster for EXEC file
exec_min_alloc      dw  0           ; Min extra paragraphs from EXE header
exec_max_alloc      dw  0           ; Max extra paragraphs from EXE header
exec_load_paras     dw  0           ; Load size in paragraphs (code+data)
exec_child_seg      dw  0           ; Child PSP segment
exec_load_size      dw  0           ; Size loaded (paragraphs)
exec_init_cs        dw  0           ; .EXE initial CS
exec_init_ip        dw  0           ; .EXE initial IP
exec_init_ss        dw  0           ; .EXE initial SS
exec_init_sp        dw  0           ; .EXE initial SP
exec_save_area      times 18 db 0   ; Saved parent register save area (9 words)
exec_child_env      dw  0           ; Child environment segment (for cleanup)

; ---------------------------------------------------------------------------
; Current PSP segment
; ---------------------------------------------------------------------------
current_psp         dw  0           ; Segment of current program's PSP

; ---------------------------------------------------------------------------
; Disk Parameter Block (DPB) for drive A:
; ---------------------------------------------------------------------------
dpb_a:
    .drive          db  0           ; Drive number (0=A:)
    .unit           db  0           ; Unit number
    .bytes_per_sec  dw  512
    .sec_per_clus   db  0           ; Sectors per cluster - 1
    .clus_shift     db  0           ; Log2(sectors per cluster)
    .rsvd_sectors   dw  1
    .num_fats       db  2
    .root_entries   dw  224
    .data_start     dw  33
    .max_cluster    dw  2849        ; Highest cluster + 1 (for 1.44MB floppy)
    .fat_size       dw  9           ; Sectors per FAT (was db, needs to be word for FAT16)
    .root_start     dw  19
    .device_ptr     dd  0           ; Pointer to device driver
    .media_byte     db  0xF0
    .access_flag    db  0           ; 0 = accessed
    .next_dpb       dd  0           ; Pointer to next DPB
    .first_free     dw  2           ; First free cluster (search hint)
    .free_count     dw  0xFFFF      ; Free clusters (-1 = unknown)
    .fat_type       db  12          ; FAT type: 12 for FAT12, 16 for FAT16

; ---------------------------------------------------------------------------
; Disk Parameter Block (DPB) for RAM disk (drive D:)
; ---------------------------------------------------------------------------
dpb_ramdisk:
    .drive          db  3           ; Drive number (3=D:)
    .unit           db  0           ; Unit number
    .bytes_per_sec  dw  512
    .sec_per_clus   db  0           ; Sectors per cluster - 1
    .clus_shift     db  0           ; Log2(sectors per cluster)
    .rsvd_sectors   dw  1
    .num_fats       db  2
    .root_entries   dw  112
    .data_start     dw  12          ; 1 boot + 2*2 FAT + 7 root dir sectors
    .max_cluster    dw  0           ; Filled at init
    .fat_size       dw  2           ; Sectors per FAT
    .root_start     dw  5           ; 1 boot + 2*2 FAT sectors
    .device_ptr     dd  0           ; Pointer to device driver
    .media_byte     db  0xF8        ; Fixed disk media byte
    .access_flag    db  0
    .next_dpb       dd  0
    .first_free     dw  2
    .free_count     dw  0xFFFF
    .fat_type       db  12          ; FAT12
