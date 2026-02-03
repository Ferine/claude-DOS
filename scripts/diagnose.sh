#!/bin/bash
# ===========================================================================
# ClaudeDOS Build Diagnostics
# ===========================================================================
# Analyzes build output, captures emulator errors, and maps to known issues.
#
# Usage:
#   ./scripts/diagnose.sh build     # Diagnose build failures
#   ./scripts/diagnose.sh run PROG  # Run program and capture errors
#   ./scripts/diagnose.sh smoke     # Quick smoke test (boot + hello)
#   ./scripts/diagnose.sh lookup XX # Look up error code XX
# ===========================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ERRORS_DB="$PROJECT_DIR/docs/errors.md"
FLOPPY_IMG="$PROJECT_DIR/images/floppy.img"
RESULTS_DIR="$PROJECT_DIR/test_results"
MAX_FLOPPY_SIZE=1474560

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_diag() { echo -e "${CYAN}[DIAG]${NC} $1"; }

# ===========================================================================
# Error Code Lookup
# ===========================================================================

lookup_error() {
    local code="$1"
    local code_upper=$(echo "$code" | tr 'a-f' 'A-F')

    if [ ! -f "$ERRORS_DB" ]; then
        log_error "Error database not found: $ERRORS_DB"
        return 1
    fi

    echo ""
    log_diag "Looking up error code: ##${code_upper}##"
    echo ""

    # Search for the error code in the table
    local found=$(grep -i "##${code}##\|##${code_upper}##" "$ERRORS_DB" 2>/dev/null || true)

    if [ -n "$found" ]; then
        echo "$found"
        echo ""

        # Also search for related patterns
        local pattern_section=$(sed -n "/### Pattern:.*##${code}##/,/### Pattern:/p" "$ERRORS_DB" 2>/dev/null | head -n -1 || true)
        if [ -n "$pattern_section" ]; then
            echo ""
            log_diag "Related troubleshooting pattern:"
            echo "$pattern_section"
        fi
    else
        log_warn "Error code ##${code_upper}## not found in knowledge base"
        echo ""
        echo "Consider adding this error to: $ERRORS_DB"
    fi
}

# ===========================================================================
# Build Diagnosis
# ===========================================================================

diagnose_build() {
    log_info "Running build with diagnostics..."

    # Capture build output
    local build_log=$(mktemp)

    if make -C "$PROJECT_DIR" 2>&1 | tee "$build_log"; then
        log_info "Build succeeded"

        # Check floppy size
        if [ -f "$FLOPPY_IMG" ]; then
            local size=$(stat -f%z "$FLOPPY_IMG" 2>/dev/null || stat -c%s "$FLOPPY_IMG")
            local pct=$((size * 100 / MAX_FLOPPY_SIZE))

            if [ "$size" -gt "$MAX_FLOPPY_SIZE" ]; then
                log_error "Floppy image exceeds 1.44MB! ($size bytes)"
                log_diag "Remove some files or compress data"
                rm -f "$build_log"
                return 1
            elif [ "$pct" -gt 95 ]; then
                log_warn "Floppy is ${pct}% full ($size/$MAX_FLOPPY_SIZE bytes)"
            else
                log_info "Floppy size: $size bytes (${pct}% full)"
            fi
        fi

        rm -f "$build_log"
        return 0
    else
        log_error "Build failed"
        echo ""

        # Analyze errors
        log_diag "Analyzing build errors..."

        # Check for NASM errors
        if grep -q "error:" "$build_log"; then
            log_diag "NASM assembly errors found:"
            grep "error:" "$build_log" | head -10
        fi

        # Check for undefined symbols
        if grep -q "undefined" "$build_log"; then
            log_diag "Undefined symbols:"
            grep "undefined" "$build_log"
        fi

        # Check for missing files
        if grep -q "No such file" "$build_log"; then
            log_diag "Missing files:"
            grep "No such file" "$build_log"
        fi

        rm -f "$build_log"
        return 1
    fi
}

# ===========================================================================
# Smoke Test
# ===========================================================================

smoke_test() {
    log_info "Running smoke test..."

    if [ ! -f "$FLOPPY_IMG" ]; then
        log_error "Floppy image not found. Run 'make' first."
        return 1
    fi

    mkdir -p "$RESULTS_DIR"
    local socket="/tmp/qemu-smoke-$$.sock"
    local serial_log="$RESULTS_DIR/smoke_serial.log"

    rm -f "$socket" "$serial_log"

    # Start QEMU with serial logging
    qemu-system-i386 \
        -fda "$FLOPPY_IMG" \
        -boot a \
        -m 4 \
        -display none \
        -serial file:"$serial_log" \
        -monitor unix:"$socket",server,nowait \
        2>/dev/null &
    local qemu_pid=$!

    sleep 4  # Wait for boot

    # Send commands and capture screenshots
    {
        sleep 0.3
        # Type "hello" and press Enter
        for key in h e l l o; do
            echo "sendkey $key"
            sleep 0.08
        done
        echo "sendkey ret"
        sleep 2
        echo "screendump $RESULTS_DIR/smoke_hello.ppm"
        sleep 0.5
    } | nc -U "$socket" > /dev/null 2>&1 || true

    sleep 1
    kill $qemu_pid 2>/dev/null || true
    wait $qemu_pid 2>/dev/null || true

    # Convert screenshot
    if [ -f "$RESULTS_DIR/smoke_hello.ppm" ]; then
        if command -v sips &> /dev/null; then
            sips -s format png "$RESULTS_DIR/smoke_hello.ppm" --out "$RESULTS_DIR/smoke_hello.png" 2>/dev/null
            rm -f "$RESULTS_DIR/smoke_hello.ppm"
        fi
        log_info "Smoke test completed - screenshot: $RESULTS_DIR/smoke_hello.png"
    else
        log_warn "No screenshot captured"
    fi

    # Check serial output for errors
    if [ -f "$serial_log" ]; then
        local errors=$(grep -oE '##[0-9A-Fa-f]{2}##' "$serial_log" 2>/dev/null || true)
        if [ -n "$errors" ]; then
            log_error "Error codes detected in serial output:"
            echo "$errors" | sort -u | while read code; do
                local hex=$(echo "$code" | sed 's/##//g')
                lookup_error "$hex"
            done
            rm -f "$socket"
            return 1
        fi
    fi

    rm -f "$socket"
    log_info "Smoke test PASSED"
    return 0
}

# ===========================================================================
# Run Program with Diagnostics
# ===========================================================================

run_program() {
    local prog="$1"

    if [ -z "$prog" ]; then
        log_error "Usage: $0 run PROGRAM"
        return 1
    fi

    if [ ! -f "$FLOPPY_IMG" ]; then
        log_error "Floppy image not found. Run 'make' first."
        return 1
    fi

    log_info "Running '$prog' with diagnostics..."

    mkdir -p "$RESULTS_DIR"
    local socket="/tmp/qemu-diag-$$.sock"
    local serial_log="$RESULTS_DIR/${prog}_serial.log"

    rm -f "$socket" "$serial_log"

    # Start QEMU
    qemu-system-i386 \
        -fda "$FLOPPY_IMG" \
        -boot a \
        -m 4 \
        -display cocoa \
        -serial file:"$serial_log" \
        -monitor unix:"$socket",server,nowait \
        2>/dev/null &
    local qemu_pid=$!

    sleep 4  # Wait for boot

    # Run the program
    {
        sleep 0.3
        for (( i=0; i<${#prog}; i++ )); do
            local char="${prog:$i:1}"
            case "$char" in
                [A-Z]) echo "sendkey shift-${char,,}" ;;
                [a-z0-9]) echo "sendkey $char" ;;
                '.') echo "sendkey dot" ;;
            esac
            sleep 0.08
        done
        echo "sendkey ret"
        sleep 5
        echo "screendump $RESULTS_DIR/${prog}_output.ppm"
        sleep 0.5
    } | nc -U "$socket" > /dev/null 2>&1 || true

    sleep 1
    kill $qemu_pid 2>/dev/null || true
    wait $qemu_pid 2>/dev/null || true

    # Convert screenshot
    if [ -f "$RESULTS_DIR/${prog}_output.ppm" ]; then
        if command -v sips &> /dev/null; then
            sips -s format png "$RESULTS_DIR/${prog}_output.ppm" --out "$RESULTS_DIR/${prog}_output.png" 2>/dev/null
            rm -f "$RESULTS_DIR/${prog}_output.ppm"
        fi
        log_info "Screenshot: $RESULTS_DIR/${prog}_output.png"
    fi

    # Analyze serial output for errors
    if [ -f "$serial_log" ]; then
        local errors=$(grep -oE '##[0-9A-Fa-f]{2}##' "$serial_log" 2>/dev/null || true)
        if [ -n "$errors" ]; then
            log_error "Error codes detected:"
            echo "$errors" | sort -u | while read code; do
                local hex=$(echo "$code" | sed 's/##//g')
                lookup_error "$hex"
            done
            return 1
        else
            log_info "No error codes detected in serial output"
        fi
    fi

    rm -f "$socket"
    return 0
}

# ===========================================================================
# Main
# ===========================================================================

case "${1:-help}" in
    build)
        diagnose_build
        ;;
    smoke)
        diagnose_build && smoke_test
        ;;
    run)
        run_program "$2"
        ;;
    lookup)
        if [ -z "$2" ]; then
            log_error "Usage: $0 lookup ERROR_CODE"
            echo "Example: $0 lookup 06"
            exit 1
        fi
        lookup_error "$2"
        ;;
    help|--help|-h)
        echo "ClaudeDOS Build Diagnostics"
        echo ""
        echo "Usage:"
        echo "  $0 build       Build with diagnostics"
        echo "  $0 smoke       Build + quick smoke test"
        echo "  $0 run PROG    Run program with error capture"
        echo "  $0 lookup XX   Look up error code (hex)"
        echo ""
        echo "Examples:"
        echo "  $0 smoke"
        echo "  $0 run chess"
        echo "  $0 lookup 06"
        ;;
    *)
        log_error "Unknown command: $1"
        echo "Run '$0 help' for usage"
        exit 1
        ;;
esac
