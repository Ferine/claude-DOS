# ClaudeDOS

x86 real-mode DOS-compatible operating system written in NASM assembly.

## Build Commands

- `make` - Build floppy image
- `make hd` - Build 32MB FAT16 hard disk image
- `make run` - Launch in QEMU with GUI
- `make run-serial` - Launch with serial output
- `make run-hd` - Launch with floppy + hard disk (C:)
- `make run-hd-serial` - Launch with hard disk + serial output
- `make debug` - Launch with GDB support (port 1234)
- `make clean` - Clean build artifacts

## Testing

- `./scripts/test_harness.sh boot` - Boot test
- `./scripts/test_harness.sh dir` - DIR command test
- `./scripts/test_harness.sh exec` - Program execution test
- `./scripts/test_harness.sh file` - File I/O test (rw mode)
- `./scripts/test_harness.sh find` - FindFirst/FindNext test

Screenshots saved to `test_results/`

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
3. Common errors: `##06##` = invalid handle, `##02##` = file not found, `##08##` = out of memory
4. When making incremental changes, commit after each successful change for easy bisection

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
- `tools/` - Rust mkfloppy utility

## Constraints

- Floppy image must fit in 1.44MB (1,474,560 bytes)
- Target: 8086/186 real mode
- DOS version reported: 5.0

## Key Data Structures

- **MCB**: 16-byte header (signature, owner, size) before each memory block
- **PSP**: 256-byte Program Segment Prefix at start of each program's memory
- **SFT**: System File Table with 40 entries (SFT_ENTRY_SIZE = 43 bytes)
- **DPB**: Drive Parameter Block per drive (34 bytes, field offsets in constants.inc)
- **FCB**: File Control Block (37 bytes, legacy DOS file API)

## INT 21h Handler Pattern

Handlers are dispatched via jump table in `dispatch.asm`. On entry:
- All caller registers saved to `save_ax`, `save_bx`, etc. in kernel data
- `cs:` segment override required to access kernel variables
- Carry flag for errors set via `save_flags_cf`
- InDOS flag incremented/decremented for reentrancy guard
- Active drive saved/restored around each handler

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
