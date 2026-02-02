# ClaudeDOS

A DOS-compatible operating system implementation written in x86 assembly language.

## Overview

ClaudeDOS is a functional DOS clone that implements core DOS services including:

- **Memory Management**: MCB (Memory Control Block) chain with allocation, free, and resize operations
- **Extended Memory**: XMS 2.0/3.0 driver for extended memory access
- **File System**: FAT12 file system driver for floppy disk access
- **DOS Services**: INT 21h handler implementing common DOS functions
- **Program Execution**: Support for loading and running .COM and .EXE programs
- **Command Shell**: COMMAND.COM interpreter with internal commands

## Building

### Prerequisites

- NASM (Netwide Assembler)
- Rust/Cargo (for the mkfloppy tool)
- QEMU (for running)

### Build Commands

```bash
# Build the floppy image
make

# Clean build artifacts
make clean
```

## Running

```bash
# Run in QEMU with graphical display
make run

# Run with serial output (useful for debugging)
make run-serial

# Run with GDB debugging support
make debug
```

## Project Structure

```
boot/           - Boot loader (VBR and stage2)
kernel/         - Kernel code
  inc/          - Include files and constants
  mem/          - Memory management (MCB, XMS)
  fat/          - FAT12 file system driver
  int21h/       - DOS INT 21h services
shell/          - COMMAND.COM shell
utils/          - External utility programs
tools/          - Build tools (Rust)
tests/          - Test programs and DOS games
images/         - Build output directory
```

## Features

- Real mode x86 operation
- FAT12 floppy disk support
- MCB-based conventional memory management
- XMS extended memory support
- Timer interrupt handling (INT 08h/1Ch)
- Standard DOS interrupt services
- Program loading (COM/EXE formats)

## Known Issues

- Subdirectory file creation is not fully implemented
- Limited to floppy disk (no hard drive support)
- Some advanced DOS features are stubbed

## Testing

The `tests/` directory contains various DOS programs for testing compatibility, including classic DOS games like Scorched Earth.
