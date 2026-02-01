#!/bin/bash
# Launch claudeDOS in QEMU
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMG="${PROJECT_DIR}/images/floppy.img"

if [ ! -f "$IMG" ]; then
    echo "Error: $IMG not found. Run 'make floppy' first."
    exit 1
fi

exec qemu-system-i386 \
    -fda "$IMG" \
    -boot a \
    -m 4 \
    -display cocoa \
    "$@"
