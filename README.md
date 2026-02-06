# ClaudeDOS

A DOS 5.0-compatible operating system written in x86 real-mode assembly (NASM). Boots from floppy, supports FAT12/FAT16 filesystems, runs .COM and .EXE programs, and provides a COMMAND.COM shell with batch file support.

## Building

### Prerequisites

- NASM (Netwide Assembler)
- Rust/Cargo (for the mkfloppy tool)
- QEMU (for running/testing)

### Build Commands

```bash
make              # Build 1.44MB floppy image
make hd           # Build 32MB FAT16 hard disk image
make clean        # Clean build artifacts
```

## Running

```bash
make run           # Launch in QEMU with GUI
make run-serial    # Launch with serial output
make run-hd        # Launch with floppy + hard disk (C:)
make run-hd-serial # Launch with hard disk + serial output
make debug         # Launch with GDB support (port 1234)
```

## Features

### Kernel

- **Boot**: Two-stage bootloader (VBR + stage2) loads IO.SYS kernel
- **DOS Services**: 85 of 109 INT 21h functions implemented (00h-6Ch)
- **File System**: FAT12 (floppy) and FAT16 (hard disk) with subdirectory support
- **Memory**: MCB chain with first-fit/best-fit/last-fit allocation strategies, XMS 3.0 driver (16MB)
- **Program Execution**: .COM and .EXE loading with relocation, overlay support, handle inheritance
- **Device Drivers**: CON, NUL, AUX, PRN, CLOCK$, RAMDISK (D:)
- **Mouse**: PS/2 mouse driver with INT 33h API
- **Interrupts**: INT 20h (terminate), INT 23h (Ctrl-C), INT 24h (critical error), INT 2Fh (multiplex), INT 67h (EMS stub)

### Shell (COMMAND.COM)

**Internal Commands:**
CD, CLS, COPY, DATE, DEL, DIR, ECHO, HELP, MD, PATH, PROMPT, RD, REN, SET, TIME, TYPE, VER, VOL

**I/O Features:**
- Output redirection: `>` and `>>`
- Input redirection: `<`
- Pipes: `DIR | FIND "TXT"`
- Command-line editing: backspace, arrows, Home/End, Delete, Escape
- PATH search for .COM, .EXE, and .BAT files

**Batch Files:**
REM, ECHO, PAUSE, GOTO, IF (EXIST/ERRORLEVEL/string comparison/NOT), CALL, SHIFT, FOR loops, `%0`-`%9` parameters, `%VARNAME%` environment variables. AUTOEXEC.BAT runs at startup.

### External Utilities

BEEP, CHKDSK, FIND, FORMAT, MEM, MORE, SORT, SYS

### INT 21h API Coverage

Fully implemented:

| Range | Functions |
|-------|-----------|
| 00h-0Eh | Program terminate, char I/O, buffered input, disk reset, set drive |
| 0Fh-17h | FCB open/close/find/read/write/create/rename |
| 19h-1Ah | Get drive, set DTA |
| 21h-2Fh | FCB random/block I/O, set/get vectors, parse filename, date/time, DTA |
| 30h-36h | DOS version, TSR, break flag, InDOS, get/set vector, disk free space |
| 39h-47h | Mkdir/rmdir/chdir, create/open/close/read/write/delete/seek, attributes, IOCTL, dup handle, get CWD |
| 48h-52h | Memory alloc/free/resize, EXEC, exit, return code, find first/next, set/get PSP, SysVars |
| 56h-5Bh | Rename, file date/time, allocation strategy, extended error, temp/new file |
| 60h-6Ch | Truename, get PSP, set handle count, commit file, extended open |

Not yet implemented: 1Bh-1Ch (drive info), 38h (country info), 54h (verify flag), 5Ch (file locking), 65h-66h (extended country/code page).

## Project Structure

```
boot/               VBR and stage2 bootloader
kernel/
  inc/              Constants, structures, macros
  mem/              MCB allocator, XMS driver, UMB stubs
  fat/              FAT12/FAT16 drivers, path resolution, sector cache
  int21h/           DOS service handlers (char_io, file_io, fcb, memory, process, disk, misc)
  exec/             Program loaders (COM, EXE), PSP builder, environment
  device/           Device drivers (CON, NUL, AUX, PRN, CLOCK$, RAMDISK)
shell/
  command.asm       Main shell loop, command dispatch, PATH search
  internal/         18 built-in commands
  redirect.asm      I/O redirection and pipe support
  batch.asm         Batch file interpreter
utils/              External .COM utilities
tests/              Test programs
tools/              Rust mkfloppy image builder
scripts/            Test harness and diagnostic scripts
```

## Testing

```bash
./scripts/test_harness.sh boot    # Boot test
./scripts/test_harness.sh dir     # DIR command test
./scripts/test_harness.sh exec    # Program execution test
./scripts/test_harness.sh file    # File I/O test (rw mode)
./scripts/test_harness.sh find    # FindFirst/FindNext test
```

Screenshots saved to `test_results/`.

### Diagnostics

```bash
./scripts/diagnose.sh build       # Build with error analysis
./scripts/diagnose.sh smoke       # Build + quick smoke test
./scripts/diagnose.sh run PROG    # Run program with error capture
./scripts/diagnose.sh lookup XX   # Look up error code (e.g., lookup 06)
```

Error codes like `##XX##` map to DOS errors. See `docs/errors.md` for the full reference.

## Technical Details

- **Target**: 8086/186 real mode, DOS version 5.00
- **Floppy**: 1.44MB (1,474,560 bytes), FAT12
- **Hard disk**: 32MB, FAT16 (drive C:)
- **RAM disk**: Drive D:, FAT12
- **Memory**: Up to 640KB conventional + 16MB XMS extended
- **SFT**: 40 system file table entries
- **Handles**: 20 per process (expandable via INT 21h/67h)
