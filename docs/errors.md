# ClaudeDOS Error Knowledge Base

This document contains known error codes, their meanings, and solutions.

## DOS Error Codes

Format: `##XX##` where XX is the hex error code.

| Code | Constant | Description | Common Causes | Solutions |
|------|----------|-------------|---------------|-----------|
| `##00##` | ERR_NONE | No error | N/A | N/A |
| `##01##` | ERR_INVALID_FUNC | Invalid function | Unsupported INT 21h function called | Check if the DOS function is implemented in `kernel/int21h/dispatch.asm` |
| `##02##` | ERR_FILE_NOT_FOUND | File not found | File doesn't exist on disk | Verify file is on floppy with `dir`, check filename spelling (8.3 format) |
| `##03##` | ERR_PATH_NOT_FOUND | Path not found | Directory doesn't exist | Verify directory exists, check path separator (`\` not `/`) |
| `##04##` | ERR_TOO_MANY_FILES | Too many open files | SFT exhausted (20 max) | Program didn't close file handles; check for handle leaks |
| `##05##` | ERR_ACCESS_DENIED | Access denied | Write to read-only, delete open file | Check file attributes, ensure file not in use |
| `##06##` | ERR_INVALID_HANDLE | Invalid handle | Bad file handle passed to syscall | Handle not opened, already closed, or corrupted; check handle table |
| `##07##` | ERR_MCB_DESTROYED | MCB destroyed | Memory corruption | Memory overwrite bug; check array bounds, stack overflow |
| `##08##` | ERR_INSUFFICIENT_MEM | Insufficient memory | Not enough conventional memory | Program too large for available memory (640KB limit) |
| `##09##` | ERR_INVALID_MCB | Invalid MCB | Memory chain corrupted | Similar to ##07##; memory management bug |
| `##0B##` | ERR_INVALID_FORMAT | Invalid format | Bad EXE header | File is not valid DOS executable; check MZ signature |
| `##0F##` | ERR_INVALID_DRIVE | Invalid drive | Drive letter not recognized | Only A: drive supported currently |
| `##12##` | ERR_NO_MORE_FILES | No more files | FindNext with no more matches | Normal termination of directory scan |
| `##1D##` | ERR_WRITE_FAULT | Write fault | Disk write failed | Disk full, write-protected, or hardware error |
| `##1E##` | ERR_READ_FAULT | Read fault | Disk read failed | Bad sector, hardware error, or file truncated |
| `##1F##` | ERR_GENERAL_FAIL | General failure | Unspecified error | Check serial output for more context |
| `##27##` | ERR_DISK_FULL | Disk full | No space on floppy | Floppy is 1.44MB max; remove files or use smaller data |
| `##50##` | ERR_FILE_EXISTS | File exists | Create file that exists | Use open instead of create, or delete first |
| `##52##` | ERR_CANNOT_MAKE | Cannot make | Directory creation failed | Parent directory doesn't exist or disk full |
| `##53##` | ERR_FAIL_I24 | Fail on INT 24h | Critical error handler returned Fail | Check disk, retry operation |
| `##57##` | ERR_INVALID_PARAM | Invalid parameter | Bad parameter to DOS function | Check register values passed to INT 21h |

## Runtime Error Patterns

### Pattern: Program exits immediately with `##06##`
**Symptom:** Game/program shows error code and returns to prompt immediately.
**Cause:** Invalid file handle - usually the program tried to read from a file but got an invalid handle.
**Debug steps:**
1. Check if all required data files are on the floppy
2. Run `dir` to verify files exist
3. Check if file handle table is full (too many open files from previous program)
4. Verify the program closes handles properly on exit

### Pattern: Program hangs on file access
**Symptom:** Program freezes when trying to load data.
**Cause:** FAT chain corruption or infinite loop in file read.
**Debug steps:**
1. Rebuild floppy image from scratch
2. Check for cluster chain issues with `xxd` on floppy image
3. Verify file sizes match original

### Pattern: `Bad command or file name` for existing program
**Symptom:** Program exists in DIR listing but won't execute.
**Cause:** File extension not .COM or .EXE, or filename parsing issue.
**Debug steps:**
1. Check filename is 8.3 format
2. Verify extension is .COM or .EXE
3. Check for hidden characters in filename

### Pattern: Program crashes with garbled screen
**Symptom:** Screen shows garbage, system hangs.
**Cause:** Memory corruption, stack overflow, or video mode issue.
**Debug steps:**
1. Check program memory requirements vs available
2. Look for writes beyond allocated memory
3. Check if program expects different video mode

## Game-Specific Issues

### Scorched Earth
- **Issue:** `##06##` on startup
- **Cause:** Likely missing data files or handle exhaustion
- **Solution:** Ensure all .DAT files are included on floppy

### Battle Chess
- **Issue:** Large data files (ALLCANM1, ALLCANM2)
- **Solution:** Files load correctly; if issues occur, check read buffer size

### Frogger
- **Issue:** Data files in DATOS subdirectory
- **Solution:** Subdirectory support required; datos/*.ref files needed

## Adding New Errors

When encountering a new error:
1. Note the exact error code displayed
2. Identify which program produced it
3. Check serial output if available (`make run-serial`)
4. Document the cause and solution here

## INT 21h Function Quick Reference

The dispatch table in `kernel/int21h/dispatch.asm` maps function numbers to handlers. Functions returning `dw 0` are unimplemented and return error 01h (invalid function).

## Quick Reference

```
ERR_FILE_NOT_FOUND (02): Check filename and DIR listing
ERR_PATH_NOT_FOUND (03): Directory doesn't exist
ERR_INVALID_HANDLE (06): File handle problem - check open/close pairs
ERR_MCB_DESTROYED  (07): Memory corruption - check for buffer overflows
ERR_INSUFFICIENT_MEM (08): Program too large or memory fragmented
ERR_INVALID_FORMAT (0B): Not a valid DOS executable (bad MZ header)
ERR_INVALID_DRIVE  (0F): Drive letter not available
ERR_DISK_FULL      (27): No space left on disk
```
