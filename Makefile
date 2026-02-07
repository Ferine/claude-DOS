NASM     := nasm
CARGO    := cargo
QEMU     := qemu-system-i386

IMGDIR   := images
TOOLDIR  := tools
BOOTDIR  := boot
KERNDIR  := kernel
SHELLDIR := shell
UTILDIR  := utils

# Battle Chess game files (disabled for space)
#CHESS_DIR := tests/battle_chess
#CHESS_FILES := $(CHESS_DIR)/CHESS.EXE $(CHESS_DIR)/ALLCANM1 $(CHESS_DIR)/ALLCANM2
CHESS_FILES :=

# Defender of the Crown (EGA version)
DEFCROWN_DIR := tests/defcrown/ega
DEFCROWN_FILES := $(DEFCROWN_DIR)/DEFENDER.COM $(DEFCROWN_DIR)/GAME.DAT

# More43 utility (use unpacked version)
MORE_EXE := tests/more43/bin/_MORE.EXE

# Frogger game (disabled for space)
#FROGGER_FILES := tests/Frogger/frogger.exe tests/Frogger/frogpant.ref
FROGGER_FILES :=

# Batch test files
BAT_FILES := $(wildcard tests/*.bat)
FROGGER_DATOS := $(wildcard tests/Frogger/datos/*.ref tests/Frogger/datos/*.REF)


FLOPPY   := $(IMGDIR)/floppy.img
VBR_BIN  := $(IMGDIR)/vbr.bin
STAGE2_BIN := $(IMGDIR)/stage2.bin
IOSYS_BIN  := $(IMGDIR)/io.sys
COMMAND_BIN := $(IMGDIR)/command.com

MKFLOPPY := $(TOOLDIR)/target/release/mkfloppy

KERN_INC := -I$(KERNDIR)/inc/ -I$(KERNDIR)/
SHELL_INC := -I$(KERNDIR)/inc/ -I$(SHELLDIR)/ -I$(SHELLDIR)/internal/

# External utilities
UTIL_SRCS := $(wildcard $(UTILDIR)/*.asm)
UTIL_BINS := $(patsubst $(UTILDIR)/%.asm,$(IMGDIR)/%.com,$(UTIL_SRCS))

# Test programs
TEST_SRCS := $(wildcard tests/*.asm)
TEST_BINS := $(patsubst tests/%.asm,$(IMGDIR)/%.com,$(TEST_SRCS))

# Extra files (EXE files placed directly in images/)
EXTRA_FILES := $(wildcard $(IMGDIR)/*.EXE)

$(IMGDIR)/%.com: tests/%.asm $(wildcard $(KERNDIR)/inc/*.inc) | $(IMGDIR)
	$(NASM) -f bin $(KERN_INC) -o $@ $<

HD_IMG   := $(IMGDIR)/hd.img

.PHONY: all floppy hd run run-serial run-hd run-hd-serial debug clean tools

all: floppy

$(IMGDIR):
	mkdir -p $(IMGDIR)

# --- Boot ---
$(VBR_BIN): $(BOOTDIR)/vbr_fat12.asm | $(IMGDIR)
	$(NASM) -f bin -o $@ $<

$(STAGE2_BIN): $(BOOTDIR)/stage2.asm $(wildcard $(KERNDIR)/inc/*.inc) | $(IMGDIR)
	$(NASM) -f bin $(KERN_INC) -o $@ $<

# --- Kernel ---
$(IOSYS_BIN): $(KERNDIR)/io.asm $(wildcard $(KERNDIR)/*.asm $(KERNDIR)/**/*.asm $(KERNDIR)/inc/*.inc) | $(IMGDIR)
	$(NASM) -f bin $(KERN_INC) -o $@ $<

# --- Shell ---
$(COMMAND_BIN): $(SHELLDIR)/command.asm $(wildcard $(SHELLDIR)/*.asm $(SHELLDIR)/internal/*.asm $(KERNDIR)/inc/*.inc) | $(IMGDIR)
	$(NASM) -f bin $(SHELL_INC) -o $@ $<

# --- External Utilities ---
$(IMGDIR)/%.com: $(UTILDIR)/%.asm $(wildcard $(KERNDIR)/inc/*.inc) | $(IMGDIR)
	$(NASM) -f bin $(KERN_INC) -o $@ $<

# --- Rust Tools ---
tools: $(MKFLOPPY)

$(MKFLOPPY): $(wildcard $(TOOLDIR)/src/*.rs $(TOOLDIR)/src/**/*.rs) $(TOOLDIR)/Cargo.toml
	cd $(TOOLDIR) && $(CARGO) build --release

# --- Floppy Image ---
floppy: $(FLOPPY)

$(FLOPPY): $(VBR_BIN) $(STAGE2_BIN) $(IOSYS_BIN) $(COMMAND_BIN) $(UTIL_BINS) $(TEST_BINS) $(MKFLOPPY) | $(IMGDIR)
	@ARGS="$(FLOPPY) $(VBR_BIN)"; \
	ARGS="$$ARGS $(STAGE2_BIN):STAGE2.BIN"; \
	ARGS="$$ARGS $(IOSYS_BIN):IO.SYS"; \
	ARGS="$$ARGS $(COMMAND_BIN):COMMAND.COM"; \
	for f in $(UTIL_BINS) $(TEST_BINS); do \
		NAME=$$(basename "$$f" | tr 'a-z' 'A-Z'); \
		ARGS="$$ARGS $$f:$$NAME"; \
	done; \
	for f in $$(ls $(IMGDIR)/*.EXE $(IMGDIR)/*.LIB 2>/dev/null); do \
		NAME=$$(basename "$$f"); \
		ARGS="$$ARGS $$f:$$NAME"; \
	done; \
	for f in $(CHESS_FILES) $(DEFCROWN_FILES) $(MORE_EXE) $(FROGGER_FILES); do \
		if [ -f "$$f" ]; then \
			NAME=$$(basename "$$f"); \
			ARGS="$$ARGS $$f:$$NAME"; \
		fi; \
	done; \
	for f in $(BAT_FILES); do \
		if [ -f "$$f" ]; then \
			NAME=$$(basename "$$f" | tr 'a-z' 'A-Z'); \
			ARGS="$$ARGS $$f:$$NAME"; \
		fi; \
	done; \
	@# Frogger data files excluded to save space \
	echo "$(MKFLOPPY) $$ARGS"; \
	$(MKFLOPPY) $$ARGS

# --- Hard Disk Image (FAT16, 32MB) ---
hd: $(HD_IMG)

$(HD_IMG): $(UTIL_BINS) $(TEST_BINS) $(MKFLOPPY) | $(IMGDIR)
	@ARGS="--hd $(HD_IMG)"; \
	for f in $(UTIL_BINS) $(TEST_BINS); do \
		NAME=$$(basename "$$f" | tr 'a-z' 'A-Z'); \
		ARGS="$$ARGS $$f:$$NAME"; \
	done; \
	echo "$(MKFLOPPY) $$ARGS"; \
	$(MKFLOPPY) $$ARGS

# --- Run ---
# Audio config for PC speaker on macOS
AUDIO_OPTS := -audiodev coreaudio,id=audio0 -machine pcspk-audiodev=audio0

run: floppy
	$(QEMU) -fda $(FLOPPY) -boot a -m 4 -display cocoa $(AUDIO_OPTS)

run-serial: floppy
	$(QEMU) -fda $(FLOPPY) -boot a -m 4 -nographic -serial mon:stdio $(AUDIO_OPTS)

run-hd: floppy hd
	$(QEMU) -fda $(FLOPPY) -hda $(HD_IMG) -boot a -m 4 -display cocoa $(AUDIO_OPTS)

run-hd-serial: floppy hd
	$(QEMU) -fda $(FLOPPY) -hda $(HD_IMG) -boot a -m 4 -nographic -serial mon:stdio $(AUDIO_OPTS)

# --- Quake ---
QUAKE_DIR := tests/Quake
QUAKE_HD  := $(IMGDIR)/quake_hd.img

quake-hd: $(QUAKE_HD)

$(QUAKE_HD): $(MKFLOPPY) | $(IMGDIR)
	$(MKFLOPPY) --hd $(QUAKE_HD) \
		$(QUAKE_DIR)/quake.exe:QUAKE.EXE \
		$(QUAKE_DIR)/cwsdpmi.exe:CWSDPMI.EXE \
		$(QUAKE_DIR)/id1/pak0.pak:ID1/PAK0.PAK \
		$(QUAKE_DIR)/id1/config.cfg:ID1/CONFIG.CFG

run-quake: floppy quake-hd
	$(QEMU) -fda $(FLOPPY) -hda $(QUAKE_HD) -boot a -m 16 -display cocoa $(AUDIO_OPTS)

run-quake-serial: floppy quake-hd
	$(QEMU) -fda $(FLOPPY) -hda $(QUAKE_HD) -boot a -m 16 -nographic -serial mon:stdio $(AUDIO_OPTS)

debug: floppy
	$(QEMU) -fda $(FLOPPY) -boot a -m 4 -S -s -display cocoa $(AUDIO_OPTS) &
	@echo "GDB: target remote :1234 / set architecture i8086 / break *0x7c00"

# --- Clean ---
clean:
	rm -rf $(IMGDIR)
	cd $(TOOLDIR) && $(CARGO) clean 2>/dev/null || true
