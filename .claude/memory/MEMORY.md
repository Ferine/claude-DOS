# ClaudeDOS Memory

## Multi-Drive FAT Support
- FAT12 (floppy A:) and FAT16 (hard disk C:) both supported
- `active_dpb` pointer + `active_drive_num` control which drive is active
- `fat_set_active_drive(AL)` switches all FAT state (DPB, EOC markers, geometry)
- `fat_save_drive` / `fat_restore_drive` for context save/restore
- INT 21h dispatcher auto-saves/restores drive state around all handlers
- `resolve_path` auto-switches drive based on path prefix (e.g., "C:\")
- SFT `.flags` low byte stores BIOS drive number for open files
- FindFirst/FindNext store drive in DTA reserved byte 18
- DPB field offsets in `constants.inc` (DPB_DRIVE, DPB_DATA_START, etc.)

## Key Files
- `kernel/fat/common.asm` - Drive switching, sector I/O, path resolution
- `kernel/data.asm` - DPB blocks (dpb_a, dpb_c, dpb_ramdisk)
- `kernel/init.asm` - `init_hard_disk` probes INT 13h for drive 0x80
- `tools/src/fatimg/fat16.rs` - FAT16 image builder (32MB)

## Build Notes
- macOS default bash is old (3.2) - `${var,,}` syntax not available
- Test harness uses `nc -U` for QEMU monitor socket, not socat
- QEMU needs `-display cocoa` for screenshots on macOS

## Common Pitfalls
- NASM local labels (`.foo`) are scoped to previous global label - use global labels for cross-scope references
- `[bp + offset]` defaults to SS segment, need `cs:` override for kernel data
- FAT12 EOC: 0x0FF8-0x0FFF; FAT16 EOC: 0xFFF8-0xFFFF - use `[fat_eoc_min]`
