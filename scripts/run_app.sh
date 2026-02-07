#!/bin/bash
# Launch any DOS application on ClaudeDOS
#
# Usage:
#   ./scripts/run_app.sh APP_DIR [EXE_NAME] [-m N] [-s|--serial] [-n|--no-run]
#
# Examples:
#   ./scripts/run_app.sh tests/doom              # Boot with DOOM files on C:
#   ./scripts/run_app.sh tests/doom DOOM.EXE     # Auto-run DOOM.EXE
#   ./scripts/run_app.sh tests/Quake QUAKE.EXE -m 32   # Quake with 32MB RAM

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMGDIR="${PROJECT_DIR}/images"
MKFLOPPY="${PROJECT_DIR}/tools/target/release/mkfloppy"
FLOPPY="${IMGDIR}/floppy.img"
QEMU="qemu-system-i386"

# Defaults
MEM=32
SERIAL=0
NO_RUN=0
APP_DIR=""
EXE_NAME=""

# Track whether we created a temp AUTOEXEC.BAT
CREATED_AUTOEXEC=0

cleanup() {
    if [ "$CREATED_AUTOEXEC" -eq 1 ]; then
        rm -f "${PROJECT_DIR}/tests/autoexec.bat"
    fi
}
trap cleanup EXIT

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -m)
            MEM="$2"
            shift 2
            ;;
        -s|--serial)
            SERIAL=1
            shift
            ;;
        -n|--no-run)
            NO_RUN=1
            shift
            ;;
        -h|--help)
            echo "Usage: $0 APP_DIR [EXE_NAME] [-m N] [-s|--serial] [-n|--no-run]"
            echo ""
            echo "  APP_DIR          Directory containing DOS app files"
            echo "  EXE_NAME         Executable to auto-run on C: (optional)"
            echo "  -m N             RAM in MB (default: 32)"
            echo "  -s, --serial     Serial console instead of GUI"
            echo "  -n, --no-run     Build HD image only, don't launch QEMU"
            echo ""
            echo "Examples:"
            echo "  $0 tests/doom DOOM.EXE"
            echo "  $0 tests/Quake QUAKE.EXE -m 32"
            echo "  $0 tests/doom -n"
            exit 0
            ;;
        -*)
            echo "Error: Unknown option $1"
            exit 1
            ;;
        *)
            if [ -z "$APP_DIR" ]; then
                APP_DIR="$1"
            elif [ -z "$EXE_NAME" ]; then
                EXE_NAME="$1"
            else
                echo "Error: Unexpected argument $1"
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$APP_DIR" ]; then
    echo "Error: APP_DIR is required"
    echo "Usage: $0 APP_DIR [EXE_NAME] [-m N] [-s|--serial] [-n|--no-run]"
    exit 1
fi

# Resolve to absolute path
APP_DIR="$(cd "$APP_DIR" 2>/dev/null && pwd)" || {
    echo "Error: Directory not found: $APP_DIR"
    exit 1
}

APP_NAME="$(basename "$APP_DIR" | tr 'A-Z' 'a-z')"
HD_IMG="${IMGDIR}/${APP_NAME}_hd.img"

# If auto-run requested, create AUTOEXEC.BAT before building floppy
# The Makefile picks up tests/*.bat via $(wildcard tests/*.bat)
if [ -n "$EXE_NAME" ]; then
    echo "Creating AUTOEXEC.BAT to auto-run ${EXE_NAME}..."
    # Use lowercase .bat extension so Make's $(wildcard tests/*.bat) picks it up
    printf "@ECHO OFF\r\nC:\r\n%s\r\n" "$EXE_NAME" > "${PROJECT_DIR}/tests/autoexec.bat"
    CREATED_AUTOEXEC=1
    # Force floppy rebuild to include AUTOEXEC.BAT
    rm -f "$FLOPPY"
fi

# Build mkfloppy if needed
if [ ! -f "$MKFLOPPY" ]; then
    echo "Building mkfloppy tool..."
    make -C "$PROJECT_DIR" tools
fi

# Build floppy (always rebuild if AUTOEXEC.BAT was created)
if [ ! -f "$FLOPPY" ]; then
    echo "Building floppy image..."
    make -C "$PROJECT_DIR" floppy
fi

# Collect files from APP_DIR
echo "Scanning ${APP_DIR}..."
MKFLOPPY_ARGS="--hd ${HD_IMG}"
FILE_COUNT=0
SKIP_COUNT=0

while IFS= read -r -d '' filepath; do
    # Get path relative to APP_DIR
    relpath="${filepath#${APP_DIR}/}"

    # Convert to uppercase DOS name
    dosname="$(echo "$relpath" | tr 'a-z' 'A-Z')"

    # Check for non-8.3-compatible names
    skip=0
    IFS='/' read -ra parts <<< "$dosname"
    for part in "${parts[@]}"; do
        # Check for spaces
        if echo "$part" | grep -q '[[:space:]]'; then
            skip=1
            break
        fi
        # Split name and extension
        name="${part%.*}"
        if [ "$name" = "$part" ]; then
            ext=""
        else
            ext="${part##*.}"
        fi
        # Check 8.3 lengths
        if [ ${#name} -gt 8 ] || [ ${#ext} -gt 3 ]; then
            skip=1
            break
        fi
    done

    if [ "$skip" -eq 1 ]; then
        echo "  SKIP: $relpath (not 8.3 compatible)"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        continue
    fi

    MKFLOPPY_ARGS="${MKFLOPPY_ARGS} ${filepath}:${dosname}"
    FILE_COUNT=$((FILE_COUNT + 1))
done < <(find "$APP_DIR" -type f -print0 | sort -z)

echo "Found ${FILE_COUNT} files (${SKIP_COUNT} skipped)"

if [ "$FILE_COUNT" -eq 0 ]; then
    echo "Error: No files to include"
    exit 1
fi

# Build HD image
echo "Building HD image: ${HD_IMG}"
echo "$MKFLOPPY" $MKFLOPPY_ARGS
$MKFLOPPY $MKFLOPPY_ARGS

if [ "$NO_RUN" -eq 1 ]; then
    echo "HD image ready: ${HD_IMG}"
    echo "Run manually: ${QEMU} -fda ${FLOPPY} -hda ${HD_IMG} -boot a -m ${MEM}"
    exit 0
fi

# Audio config for macOS
AUDIO_OPTS="-audiodev coreaudio,id=audio0 -machine pcspk-audiodev=audio0"

# Launch QEMU
echo "Launching QEMU (${MEM}MB RAM)..."
if [ "$SERIAL" -eq 1 ]; then
    exec $QEMU -fda "$FLOPPY" -hda "$HD_IMG" -boot a -m "$MEM" \
        -nographic -serial mon:stdio $AUDIO_OPTS
else
    exec $QEMU -fda "$FLOPPY" -hda "$HD_IMG" -boot a -m "$MEM" \
        -display cocoa $AUDIO_OPTS
fi
