#!/bin/bash
# Launch claudeDOS in QEMU with GDB stub
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMG="${PROJECT_DIR}/images/floppy.img"

if [ ! -f "$IMG" ]; then
    echo "Error: $IMG not found. Run 'make floppy' first."
    exit 1
fi

echo "QEMU waiting for GDB on localhost:1234"
echo "Connect with: gdb -ex 'target remote :1234' -ex 'set architecture i8086' -ex 'break *0x7c00'"

exec qemu-system-i386 \
    -fda "$IMG" \
    -boot a \
    -m 4 \
    -S -s \
    -display curses \
    "$@"
