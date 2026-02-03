# ClaudeDOS

x86 real-mode DOS-compatible operating system written in NASM assembly.

## Build Commands

- `make` - Build floppy image
- `make run` - Launch in QEMU with GUI
- `make run-serial` - Launch with serial output
- `make debug` - Launch with GDB support (port 1234)
- `make clean` - Clean build artifacts

## Testing

- `./scripts/test_harness.sh boot` - Boot test
- `./scripts/test_harness.sh dir` - DIR command test
- `./scripts/test_harness.sh exec` - Program execution test
- `./scripts/test_harness.sh file` - File I/O test (rw mode)

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
- `kernel/` - Kernel modules (INT 21h services, FAT12, memory, exec)
- `shell/` - COMMAND.COM and internal commands
- `utils/` - External utilities (.COM)
- `tests/` - Test programs
- `tools/` - Rust mkfloppy utility

## Constraints

- Floppy image must fit in 1.44MB (1,474,560 bytes)
- Target: 8086/186 real mode
- DOS version reported: 5.0

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
