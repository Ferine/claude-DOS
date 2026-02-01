# claudeDOS QEMU Testing Harness - Comprehensive Plan

## Overview

This document outlines a comprehensive testing strategy for claudeDOS using QEMU as the virtualization platform. The harness enables automated testing of DOS functionality without requiring manual intervention.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Test Runner                          │
│  (scripts/test_harness.sh or Python-based runner)       │
└────────────────┬───────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│                  QEMU Instance                          │
│  ┌─────────────────┐    ┌─────────────────────────┐    │
│  │ claudeDOS       │    │ Monitor Socket          │    │
│  │ (floppy.img)    │    │ (sendkey, screendump)   │    │
│  └─────────────────┘    └─────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│              Test Results                               │
│  - Screenshots (PNG)                                    │
│  - Serial output logs                                   │
│  - Exit codes                                           │
└─────────────────────────────────────────────────────────┘
```

## Testing Methods

### 1. Screenshot-Based Testing (Current)

**Pros:**
- Works with standard VGA text mode output
- No modifications to DOS kernel needed
- Visual verification possible

**Cons:**
- Requires image comparison or OCR for automated verification
- Screenshots are large files
- Can't easily extract text programmatically

**Implementation:**
- QEMU monitor `screendump` command captures VGA buffer
- Compare screenshots using pixel-diff or perceptual hash
- Store reference screenshots for regression testing

### 2. Serial Port Testing (Recommended Enhancement)

**Approach:** Redirect DOS output to serial port for text capture.

**Kernel Changes Required:**
1. Add serial port driver (COM1: 0x3F8)
2. Modify INT 21h 40h (write) to optionally mirror output to serial
3. Create SERIAL.SYS device driver

**Benefits:**
- Text output can be captured directly
- Easy to grep/search for expected strings
- Smaller output files
- Scriptable verification

**QEMU Configuration:**
```bash
qemu-system-i386 \
    -fda floppy.img \
    -serial file:serial_output.txt \
    -nographic  # Optional: runs headless
```

### 3. VGA Text Mode Memory Dump

**Approach:** Read VGA text buffer directly from QEMU.

**Implementation:**
- VGA text buffer at 0xB8000 (CGA/EGA/VGA)
- Each character is 2 bytes: char + attribute
- 80x25 = 4000 bytes for full screen

**QEMU Commands:**
```
# In QEMU monitor
xp /2000hx 0xB8000
```

**Benefits:**
- Direct text extraction without OCR
- Can be parsed programmatically

### 4. Test Program Protocol

**Approach:** Create test programs that output results in a parseable format.

**Protocol Design:**
```
TEST:name:PASS
TEST:name:FAIL:reason
DATA:key=value
```

**Example Test Program (TEST.COM):**
```asm
; Output test result to serial or screen
mov dx, result_pass    ; "TEST:file_create:PASS\r\n"
mov ah, 09h
int 21h
```

**Benefits:**
- Clear pass/fail indication
- Machine-parseable output
- Can include timing data

## Test Categories

### 1. Boot Tests
- Boot from floppy completes
- Kernel initializes correctly
- COMMAND.COM loads and runs
- Prompt appears

### 2. Internal Command Tests
- DIR - Directory listing
- TYPE - File display
- COPY - File copying
- DEL - File deletion
- CLS - Screen clear
- VER - Version display

### 3. External Program Tests
- .COM file loading and execution
- .EXE file loading with relocations
- Program termination and return to shell
- Error level propagation

### 4. File I/O Tests
- File create (3Ch)
- File open (3Dh)
- File read (3Fh)
- File write (40h)
- File seek (42h)
- File close (3Eh)
- File delete (41h)

### 5. Directory Tests
- FindFirst (4Eh)
- FindNext (4Fh)
- Wildcard matching (*, ?)

### 6. Memory Tests
- Memory allocation (48h)
- Memory free (49h)
- Memory resize (4Ah)

## Implementation Phases

### Phase 1: Basic Harness (Current)
- [x] Shell script test runner
- [x] QEMU monitor keystroke injection
- [x] Screenshot capture
- [ ] Basic test suite (boot, dir, exec)

### Phase 2: Serial Output
- [ ] Add serial port driver to kernel
- [ ] Configure QEMU for serial capture
- [ ] Text-based test verification
- [ ] Automated pass/fail detection

### Phase 3: Test Suite Expansion
- [ ] Comprehensive file I/O tests
- [ ] Memory management tests
- [ ] Error handling tests
- [ ] Edge case testing

### Phase 4: CI Integration
- [ ] GitHub Actions workflow
- [ ] Automated test runs on PR
- [ ] Test result reporting
- [ ] Screenshot comparison

### Phase 5: Advanced Features
- [ ] Performance benchmarks
- [ ] Stress testing
- [ ] Multi-boot configuration tests
- [ ] Regression test database

## Directory Structure

```
claudeDOS/
├── scripts/
│   ├── test_harness.sh      # Main test runner
│   ├── run_tests.py         # Python test runner (future)
│   └── compare_screenshots.py
├── tests/
│   ├── hello.asm            # Simple test program
│   ├── testff.asm           # FindFirst/FindNext test
│   ├── testwr.asm           # File write test
│   └── ...
├── test_results/
│   ├── *.png                # Test screenshots
│   └── *.log                # Serial output logs
└── docs/
    └── TESTING_HARNESS_PLAN.md
```

## Running Tests

### Manual Testing
```bash
# Build the floppy image
make floppy

# Run all tests
./scripts/test_harness.sh

# Run specific test
./scripts/test_harness.sh boot
./scripts/test_harness.sh dir
./scripts/test_harness.sh exec
```

### Viewing Results
```bash
# Open test screenshots
open test_results/*.png

# Check for failures (future)
grep "FAIL" test_results/*.log
```

## Known Limitations

1. **Keystroke Timing:** QEMU's sendkey command has timing limitations; complex inputs may require tuning delays.

2. **No VGA in Headless Mode:** Screenshot capture requires VGA display; truly headless testing needs serial port.

3. **Disk Write Tests:** QEMU warns about read-only mode unless explicitly configured; use `format=raw` for write tests.

4. **macOS Specific:** The current harness uses `sips` for image conversion; Linux would need ImageMagick.

## Future Enhancements

1. **OCR-based Verification:** Use Tesseract to extract text from screenshots for automated verification.

2. **Video Recording:** Capture test runs as video for debugging complex issues.

3. **Network Testing:** When TCP/IP stack is added, test network functionality.

4. **Fuzzing:** Generate random inputs to find edge cases and crashes.

## References

- QEMU Monitor Commands: https://www.qemu.org/docs/master/system/monitor.html
- DOS Interrupts: Ralf Brown's Interrupt List
- VGA Programming: https://wiki.osdev.org/VGA_Hardware
