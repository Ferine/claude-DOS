#!/bin/bash
# ===========================================================================
# claudeDOS QEMU Testing Harness
# ===========================================================================
# Automated testing framework for claudeDOS using QEMU
#
# Requirements:
#   - QEMU (qemu-system-i386)
#   - netcat (nc) for monitor communication
#   - sips (macOS) or ImageMagick for image conversion
#
# Usage:
#   ./scripts/test_harness.sh [test_name]
#   ./scripts/test_harness.sh              # Run all tests
#   ./scripts/test_harness.sh boot         # Run specific test
# ===========================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FLOPPY_IMG="$PROJECT_DIR/images/floppy.img"
RESULTS_DIR="$PROJECT_DIR/test_results"
SOCKET="/tmp/qemu-test-$$.sock"

# Test configuration
BOOT_TIMEOUT=5        # Seconds to wait for boot
COMMAND_DELAY=0.08    # Delay between keystrokes
COMMAND_WAIT=2        # Seconds to wait after command

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ===========================================================================
# Helper Functions
# ===========================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Send a string as keystrokes to QEMU
send_keys() {
    local str="$1"
    for (( i=0; i<${#str}; i++ )); do
        local char="${str:$i:1}"
        case "$char" in
            [A-Z]) echo "sendkey shift-$(echo "$char" | tr 'A-Z' 'a-z')" ;;
            [a-z0-9]) echo "sendkey $char" ;;
            '.') echo "sendkey dot" ;;
            ' ') echo "sendkey spc" ;;
            '*') echo "sendkey shift-8" ;;
            '/') echo "sendkey slash" ;;
            '-') echo "sendkey minus" ;;
            ':') echo "sendkey shift-semicolon" ;;
            '\\') echo "sendkey backslash" ;;
            '_') echo "sendkey shift-minus" ;;
        esac
        sleep $COMMAND_DELAY
    done
    echo "sendkey ret"
}

# Capture screenshot
capture_screen() {
    local name="$1"
    local ppm_file="$RESULTS_DIR/${name}.ppm"
    local png_file="$RESULTS_DIR/${name}.png"

    echo "screendump $ppm_file"
    sleep 0.5

    # Convert to PNG after QEMU exits
    if command -v sips &> /dev/null; then
        echo "$ppm_file:$png_file" >> "$RESULTS_DIR/.convert_queue"
    fi
}

# Start QEMU
start_qemu() {
    local rw_mode="${1:-ro}"  # ro or rw

    rm -f "$SOCKET"
    mkdir -p "$RESULTS_DIR"

    local format_opt=""
    if [ "$rw_mode" = "rw" ]; then
        format_opt=",format=raw"
    fi

    qemu-system-i386 \
        -fda "$FLOPPY_IMG$format_opt" \
        -boot a \
        -m 4 \
        -display cocoa \
        -monitor unix:$SOCKET,server,nowait \
        2>/dev/null &
    QEMU_PID=$!

    sleep $BOOT_TIMEOUT
}

# Stop QEMU and convert screenshots
stop_qemu() {
    kill $QEMU_PID 2>/dev/null || true
    wait $QEMU_PID 2>/dev/null || true

    # Convert queued screenshots
    if [ -f "$RESULTS_DIR/.convert_queue" ]; then
        while IFS=: read -r ppm png; do
            if [ -f "$ppm" ]; then
                sips -s format png "$ppm" --out "$png" 2>/dev/null || true
                rm -f "$ppm"
            fi
        done < "$RESULTS_DIR/.convert_queue"
        rm -f "$RESULTS_DIR/.convert_queue"
    fi

    rm -f "$SOCKET"
}

# Run commands via monitor
run_monitor_script() {
    nc -U "$SOCKET" > /dev/null 2>&1
}

# ===========================================================================
# Test Cases
# ===========================================================================

test_boot() {
    log_info "Testing boot sequence..."
    start_qemu

    {
        sleep 0.3
        capture_screen "boot_complete"
    } | run_monitor_script

    stop_qemu

    if [ -f "$RESULTS_DIR/boot_complete.png" ]; then
        log_info "Boot test: PASSED (screenshot captured)"
        return 0
    else
        log_error "Boot test: FAILED"
        return 1
    fi
}

test_dir() {
    log_info "Testing DIR command (FindFirst/FindNext)..."
    start_qemu

    {
        sleep 0.3
        send_keys "dir"
        sleep $COMMAND_WAIT
        capture_screen "dir_output"
    } | run_monitor_script

    stop_qemu

    if [ -f "$RESULTS_DIR/dir_output.png" ]; then
        log_info "DIR test: Screenshot captured"
        return 0
    else
        log_error "DIR test: FAILED"
        return 1
    fi
}

test_exec() {
    log_info "Testing program execution..."
    start_qemu

    {
        sleep 0.3
        send_keys "hello"
        sleep $COMMAND_WAIT
        capture_screen "exec_hello"
    } | run_monitor_script

    stop_qemu

    if [ -f "$RESULTS_DIR/exec_hello.png" ]; then
        log_info "EXEC test: Screenshot captured"
        return 0
    else
        log_error "EXEC test: FAILED"
        return 1
    fi
}

test_file_ops() {
    log_info "Testing file operations (create/write/read/delete)..."
    start_qemu rw

    {
        sleep 0.3
        send_keys "testwr"
        sleep 3
        capture_screen "file_ops"
        sleep 0.5
        send_keys "dir"
        sleep 2
        capture_screen "file_ops_dir"
    } | run_monitor_script

    stop_qemu

    log_info "File ops test: Screenshots captured"
}

test_find_files() {
    log_info "Testing FindFirst/FindNext..."
    start_qemu

    {
        sleep 0.3
        send_keys "testff"
        sleep 3
        capture_screen "find_files"
    } | run_monitor_script

    stop_qemu

    log_info "FindFirst test: Screenshot captured"
}

# ===========================================================================
# Main
# ===========================================================================

# Ensure floppy image exists
if [ ! -f "$FLOPPY_IMG" ]; then
    log_error "Floppy image not found: $FLOPPY_IMG"
    log_info "Run 'make floppy' first"
    exit 1
fi

# Clean old results
rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"

# Run tests
if [ $# -eq 0 ]; then
    # Run all tests
    log_info "Running all tests..."
    test_boot
    test_dir
    test_exec
else
    # Run specific test
    case "$1" in
        boot) test_boot ;;
        dir) test_dir ;;
        exec) test_exec ;;
        file) test_file_ops ;;
        find) test_find_files ;;
        *)
            log_error "Unknown test: $1"
            echo "Available tests: boot, dir, exec, file, find"
            exit 1
            ;;
    esac
fi

log_info "Test results in: $RESULTS_DIR"
ls -la "$RESULTS_DIR"/*.png 2>/dev/null || log_warn "No screenshots captured"
