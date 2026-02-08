# ClaudeDOS

x86 real-mode DOS-compatible operating system written in NASM assembly.
Runs Quake (DJGPP go32 + CWSDPMI) and Duke Nukem 3D (DOS4GW).

## Build Commands

- `make` - Build floppy image
- `make hd` - Build 32MB FAT16 hard disk image
- `make quake-hd` - Build 32MB Quake hard disk image
- `make run` - Launch in QEMU with GUI
- `make run-serial` - Launch with serial output
- `make run-hd` - Launch with floppy + hard disk (C:)
- `make run-hd-serial` - Launch with hard disk + serial output
- `make run-quake` - Launch with Quake HD (32MB RAM)
- `make run-quake-serial` - Launch Quake with serial output
- `make debug` - Launch with GDB support (port 1234)
- `make clean` - Clean build artifacts

## Testing

- `./scripts/test_harness.sh boot` - Boot test
- `./scripts/test_harness.sh dir` - DIR command test
- `./scripts/test_harness.sh exec` - Program execution test
- `./scripts/test_harness.sh file` - File I/O test (rw mode)
- `./scripts/test_harness.sh find` - FindFirst/FindNext test

Screenshots saved to `test_results/`

### Quake Test

Requires `tests/Quake/` with `quake.exe`, `cwsdpmi.exe`, `id1/pak0.pak`, `id1/config.cfg`.
```
make run-quake    # Builds floppy + quake HD, launches QEMU with 32MB RAM
                  # At prompt: C:  then  QUAKE
```
The go32 stub auto-detects DPMI, loads CWSDPMI.EXE as TSR, enters protected mode.

### Duke Nukem 3D Test

Requires `tests/DUKE3D/` with `DUKE3D/DUKE3D.EXE`, `DUKE3D/DUKE3D.GRP`, `DUKE3D/DUKE3D.CFG`, `DUKE3D.BAT`.
```
./scripts/run_app.sh tests/DUKE3D -n    # Build HD image only
qemu-system-i386 -fda images/floppy.img -hda images/duke3d_hd.img \
    -boot a -m 32 -display cocoa \
    -audiodev coreaudio,id=audio0 -machine pcspk-audiodev=audio0 \
    -device adlib,audiodev=audio0 -device sb16,audiodev=audio0,irq=7
```
AUTOEXEC.BAT runs `C:` then `DUKE3D` which chains to `DUKE3D.BAT` (`cd \DUKE3D`, `DUKE3D`).
DOS4GW provides its own DPMI host. The standalone `-device adlib` is required for OPL2 FM
chip detection (QEMU's SB16 integrated OPL3 timer emulation fails the Apogee Sound System probe).

## Diagnostics

- `./scripts/diagnose.sh build` - Build with error analysis
- `./scripts/diagnose.sh smoke` - Build + quick smoke test
- `./scripts/diagnose.sh run PROG` - Run program with error capture
- `./scripts/diagnose.sh lookup XX` - Look up error code (e.g., `lookup 06`)

Error knowledge base: `docs/errors.md`

## Debugging

When debugging issues:
1. Always verify the baseline works first before assuming recent changes are the problem
2. Error codes like `##XX##` map to DOS errors - use `./scripts/diagnose.sh lookup XX`
3. CPU exception codes: `#05#` = Bound Range, `#UD@SSSS:OOOO` = Invalid Opcode at CS:IP
4. Common errors: `##06##` = invalid handle, `##02##` = file not found, `##08##` = out of memory
5. When making incremental changes, commit after each successful change for easy bisection
6. INT 2Fh calls are logged to serial port (COM1 0x3F8) as `<XXXX>` for tracing

## Architecture

- `boot/` - VBR and stage2 bootloader
- `kernel/` - Kernel modules (INT 21h services, FAT12/FAT16, memory, exec)
- `kernel/inc/` - Constants (`constants.inc`), structures (`structs.inc`), macros (`macros.inc`)
- `kernel/mem/` - MCB allocator, XMS 3.0 driver, UMB stubs
- `kernel/fat/` - FAT12/FAT16 drivers, path resolution, sector cache
- `kernel/int21h/` - DOS INT 21h service handlers
- `kernel/exec/` - COM/EXE loaders, PSP builder, environment block
- `kernel/device/` - Device drivers (CON, NUL, AUX, PRN, CLOCK$, RAMDISK)
- `shell/` - COMMAND.COM, internal commands, redirection, batch interpreter
- `utils/` - External utilities (.COM): BEEP, CHKDSK, FIND, FORMAT, MEM, MORE, SORT, SYS
- `tests/` - Test programs
- `tools/` - Rust mkfloppy/mkhd utility

## Disk Layout

### Floppy (A:)
- FAT12, 1.44MB, 1 sector/cluster (512 bytes)
- Contains kernel (IO.SYS), COMMAND.COM, utilities, test programs

### Hard Disk (C:)
- FAT16, 32MB, 8 sectors/cluster (4KB)
- 65536 total sectors, 32 sectors per FAT, 512 root directory entries
- BPB configured in `tools/src/fatimg/bpb.rs`

## Constraints

- Floppy image must fit in 1.44MB (1,474,560 bytes)
- Target: 8086/186 real mode
- DOS version reported: 5.0
- Quake requires 32MB RAM (CWSDPMI + DPMI overhead)

## Key Data Structures

- **MCB**: 16-byte header (signature, owner, size) before each memory block
- **PSP**: 256-byte Program Segment Prefix at start of each program's memory
- **SFT**: System File Table with 40 entries (SFT_ENTRY_SIZE = 43 bytes)
- **DPB**: Drive Parameter Block per drive (34 bytes, field offsets in constants.inc)
  - `DPB_SEC_PER_CLUS` stores (actual_count - 1); use `inc cx` for real count
  - `DPB_CLUS_SHIFT` = log2(sectors_per_cluster), used by `fat_cluster_to_lba`
- **FCB**: File Control Block (37 bytes, legacy DOS file API)

## INT 21h Handler Pattern

Handlers are dispatched via jump table in `dispatch.asm`. On entry:
- All caller registers saved to `save_ax`, `save_bx`, etc. in kernel data
- `cs:` segment override required to access kernel variables
- Carry flag for errors set via `save_flags_cf`
- InDOS flag incremented/decremented for reentrancy guard
- Active drive saved/restored around each handler

## Multi-Sector Cluster Handling

With FAT16 (8 sectors/cluster), code that reads files must iterate all sectors
within each cluster before calling `fat_get_next_cluster`. Key patterns:

- **COM loader** (`com_loader.asm`): Inner loop using `DPB_SEC_PER_CLUS` + `inc cx`
- **EXE loader** (`exe_loader.asm`): `.sector_in_cluster` loop with `secs_remaining` counter
- **File read AH=3Fh** (`file_io.asm`): Uses `(file_pos >> 9) & sec_per_clus` bitmask
- **`fat_cluster_to_lba`**: Returns first LBA only; caller adds sector offset within cluster

## EXE (MZ) Loading

The EXE loader (`kernel/exec/exe_loader.asm`) handles:
- 32-bit load size calculation (supports EXE files > 64KB)
- Segment boundary crossing during load (split copy with ES advance)
- Relocation fixups including entries spanning sector boundaries
- `last_page_bytes == 0` means all pages are full (don't decrement page_count)

## TSR (Terminate and Stay Resident)

INT 21h AH=31h keeps program memory resident while freeing other allocations:
- Resizes program MCB to DX paragraphs
- Frees environment and other blocks owned by the process
- Sets return code with AH=3 termination type (callers check via AH=4Dh)
- Calls `terminate_common` to restore parent context

CWSDPMI uses TSR to install DPMI hooks on INT 2Fh and INT 31h.

## XMS Driver

XMS 3.0 driver (`kernel/mem/xms.asm`) provides extended memory management:
- Functions 00h-11h (query, alloc, free, move, lock, unlock, etc.)
- Function 0Bh (Move EMB) copies in 64KB chunks via INT 15h AH=87h
- No artificial size limit on moves; handles >64KB with chunked loop
- Entry point returned via INT 2Fh AX=4310h

## Environment Block

Format (`kernel/exec/env.asm`):
```
VAR1=VALUE1\0
VAR2=VALUE2\0
\0                    <- double NUL (end of variables)
\x01\x00              <- count word (always 1)
C:\PROGRAM.EXE\0     <- program full path
```
Default PATH includes `A:\;C:\`. Program path is built from current drive + directory
for relative names, or preserved as-is for absolute paths with drive letters.

## Batch File Support

Supported batch commands:
- `REM` - Comments (also `::`)
- `ECHO` - Display text / toggle echo (ECHO ON/OFF)
- `PAUSE` - Wait for keypress
- `GOTO :label` - Jump to label
- `IF` - Conditionals (EXIST, ERRORLEVEL, string==string, NOT)
- `CALL` - Call another batch file (1 level nesting)
- `SHIFT` - Shift parameters left
- `FOR %%X IN (set) DO command` - Loop over set

Variable substitution:
- `%0-%9` - Batch parameters
- `%VARNAME%` - Environment variables
- `%%` - Literal percent sign

AUTOEXEC.BAT runs automatically at startup if present.

## Coding Conventions

- Use NASM syntax with `bits 16`
- Include files in `kernel/inc/`
- Constants in `constants.inc`, macros in `macros.inc`
- INT 21h handlers in `kernel/int21h/`
- Use `cs:` segment override for kernel data access from handlers
- Preserve caller registers; return values via `save_ax` etc.
- Error returns: set `save_flags_cf` to 1, error code in `save_ax`
- FAT code must handle sectors_per_cluster > 1 (use DPB fields, not hardcoded 1)
