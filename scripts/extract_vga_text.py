#!/usr/bin/env python3
"""Extract text from QEMU 'xp /2000hb 0xb8000' VGA text memory dump."""
import sys
import re

def extract_vga_text(dump_file):
    with open(dump_file) as f:
        raw = f.read()

    # Parse hex bytes from lines like: 00000000000b8000: 0x53 0x07 0x65 0x07
    hex_bytes = []
    for line in raw.splitlines():
        m = re.match(r'^[0-9a-f]+:\s+(.*)', line)
        if m:
            for tok in m.group(1).split():
                if tok.startswith('0x'):
                    hex_bytes.append(int(tok, 16))

    # VGA text mode: pairs of (character, attribute) bytes, 80 columns x 25 rows
    lines = []
    for row in range(25):
        chars = []
        for col in range(80):
            idx = (row * 80 + col) * 2
            if idx < len(hex_bytes):
                ch = hex_bytes[idx]
                if 0x20 <= ch < 0x7f:
                    chars.append(chr(ch))
                else:
                    chars.append(' ')
            else:
                chars.append(' ')
        lines.append(''.join(chars).rstrip())

    return '\n'.join(lines)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <vga_dump_file>", file=sys.stderr)
        sys.exit(1)
    print(extract_vga_text(sys.argv[1]))
