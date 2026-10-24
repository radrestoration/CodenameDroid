# Codename Droid, C64 port; see README.md and C64-README.md. The BBC game it runs is in bbc/ (built into build/bbc by `make -C bbc`).
-include tools.cfg
tilde = $(patsubst ~%,$(HOME)%,$(1))
ifneq ($(strip $(CC65_HOME)),)
CC65_HOME := $(call tilde,$(CC65_HOME))
export CC65_HOME
CA65       ?= $(CC65_HOME)/bin/ca65
LD65       ?= $(CC65_HOME)/bin/ld65
endif
CA65       ?= ca65
LD65       ?= ld65
PYTHON     ?= python3
C1541      ?= c1541
override CA65 := $(call tilde,$(CA65))
override LD65 := $(call tilde,$(LD65))

# the game's window is WIDE cells wide: 40 (the default), or the BBC's 32 (the same build directory)
WIDE ?= 40
export WIDE
B   ?= build/c64
BBC := build/bbc
GEN := $(B)/gen
SRC := $(wildcard src/*.s src/*.inc)

.PHONY: all gen levels test help clean FORCE zip
all: $(B)/droid.prg

help:
	@echo "make              build/c64/droid.prg (and droid.d64), the game's window 40 cells wide"
	@echo "make WIDE=32      the same with the BBC's 32-cell window (into the same directory)"
	@echo "make test         the checks in the headless 6502 simulator (make test WIDE=32 for the 32-cell build's)"
	@echo "make levels       render the 12 levels to build/c64/levels/*.png"
	@echo "make zip         build/c64/codename-droid-c64.zip: the PRG, the disk image, a VICE run script and README.md"
	@echo "make clean        remove build/c64 (build/bbc is the BBC game's: make -C bbc clean)"

# the BBC game rebuilt first (its disc.lbl and CDroid4 are what the tools read)
$(BBC)/CDroid4 $(BBC)/disc.lbl:
	$(MAKE) -C bbc

# switching WIDE rebuilds everything: the width is recorded in a stamp that changes only when it does
$(B)/wide: FORCE
	@mkdir -p $(B)
	@echo $(WIDE) | cmp -s - $@ || echo $(WIDE) > $@

FORCE:

$(GEN)/game.s: $(B)/wide tools/make_game_source.py tools/make_tables.py tools/make_sound_tables.py tools/bbcmem.py tools/wide_patches.py tools/wide_sites.py bbc/src/droid.s bbc/src/data.s bbc/src/symbols.inc $(BBC)/CDroid4
	$(PYTHON) -I tools/make_game_source.py $(GEN)

# the loading screens come from the original disc (without it: no loading screens)
DISC   ?= $(HOME)/retro/games/Disc032-CodenameDroidStrykersRun2.ssd
DISC   := $(call tilde,$(DISC))
export DISC

$(GEN)/intro_data.s: tools/make_intro.py tools/mode7.py tools/make_title_map.py tools/detok.py $(wildcard $(DISC)) $(B)/wide
	@mkdir -p $(GEN)
	$(PYTHON) -I tools/make_intro.py $@

$(B)/c64.o: $(SRC) $(GEN)/game.s $(GEN)/intro_data.s
	$(CA65) -g $(AFLAGS) -I src -I $(GEN) src/c64.s -o $@ -l $(B)/c64.lst

# the PRG area: from $0801 to wherever the engine, tables, sound driver and loading screens end (the file is not padded);
# the file must end below $d000 (the loading screens' screen RAM is under the I/O area there)
PRGSIZE ?= $$c7ff
CFG := c64_$(WIDE).cfg

$(B)/c64.cfg: $(CFG) Makefile $(B)/wide
	sed 's/size = \$$8a00,/size = $(PRGSIZE),/' $(CFG) > $@

$(B)/droid.prg: $(B)/c64.o $(B)/c64.cfg
	$(LD65) -C $(B)/c64.cfg -m $(B)/c64.map -Ln $(B)/c64.lbl -o $@ $(B)/c64.o
	$(PYTHON) -I tools/check_map.py $(B)/c64.map
	$(C1541) -format "droid,01" d64 $(B)/droid.d64 -write $@ droid >/dev/null

levels: $(BBC)/CDroid4
	$(PYTHON) -I tools/extract_levels.py $(B)/levels

test: $(B)/droid.prg
	bash tools/run_tests.sh

ZIP := $(B)/codename-droid-c64$(if $(filter 32,$(WIDE)),-narrow).zip

zip: $(B)/droid.prg tools/make_zip.py tools/dist_run.sh README.md
	$(PYTHON) -I tools/make_zip.py $(B) $(ZIP)

clean:
	rm -rf $(B)
