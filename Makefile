# Codename Droid for the C64; see README.md. The BBC game whose rules and data it follows is in bbc/ (built into build/bbc by `make -C bbc`).
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

# make CHEAT=1: a test build (its own directory): the player cannot die, and level and item keys (see run.sh)
# make PROFILE=1: border-colour timing bars
PROFILE ?=
CHEAT ?=
B   ?= build/c64$(if $(PROFILE),-profile)$(if $(CHEAT),-cheat)
BBC := build/bbc
GEN := build/c64/gen
SRC := $(wildcard src/*.s src/*.inc)

# the loading screens come from the original disc (without it: no loading screens)
DISC   ?= $(HOME)/retro/games/Disc032-CodenameDroidStrykersRun2.ssd
DISC   := $(call tilde,$(DISC))
export DISC

.PHONY: all test help clean zip
all: $(B)/game.prg

help:
	@echo "make              build/c64/game.prg and game.d64 (and droid.d64 with the loading screens, if the original disc is found)"
	@echo "make CHEAT=1      the test build in build/c64-cheat; PROFILE=1: with timing bars"
	@echo "make test         the headless checks (6502 simulator, no emulator)"
	@echo "make zip          build/c64/codename-droid-c64.zip: the disk image, the PRG, a VICE run script and README.md"
	@echo "make clean        remove build/c64* (build/bbc is the BBC game's: make -C bbc clean)"

# the BBC game rebuilt first (its disc.lbl and CDroid4 are what the data tools read)
$(BBC)/CDroid4 $(BBC)/disc.lbl:
	$(MAKE) -C bbc

$(B)/game_data.inc: tools/make_data.py tools/bbcmem.py tools/make_tables.py tools/make_sound_tables.py tools/make_title_map.py tools/bbcsim.py tools/sim6502.py $(BBC)/CDroid4
	$(PYTHON) -I tools/make_data.py $(B)

$(B)/game.o: $(SRC) $(B)/game_data.inc
	$(CA65) -g $(if $(PROFILE),-DPROFILE) $(if $(CHEAT),-DCHEAT) -I $(B) -I src src/game.s -o $@ -l $(B)/game.lst

$(B)/game.prg: $(B)/game.o c64.cfg
	$(LD65) -C c64.cfg $< -o $@ -Ln $(B)/game.lbl -m $(B)/game.map
	$(C1541) -format "droid,01" d64 $(B)/game.d64 -write $@ game >/dev/null
	@if [ -n "$(wildcard $(DISC))" ]; then $(MAKE) -s $(B)/intro.prg && \
	  $(C1541) -format "droid,01" d64 $(B)/droid.d64 -write $(B)/intro.prg droid -write $@ game >/dev/null; fi

# the loading screens, a program of their own that loads the game (intro/)
$(GEN)/intro_data.s: tools/make_intro.py tools/mode7.py tools/make_title_map.py tools/detok.py $(wildcard $(DISC))
	@mkdir -p $(GEN)
	$(PYTHON) -I tools/make_intro.py $@

$(B)/intro.prg: intro/intro_main.s intro/intro.cfg src/intro.s $(GEN)/intro_data.s
	$(CA65) -g -I src -I intro -I $(GEN) intro/intro_main.s -o $(B)/intro.o -l $(B)/intro.lst
	$(LD65) -C intro/intro.cfg $(B)/intro.o -o $@ -m $(B)/intro.map

test: $(B)/game.prg
	bash tools/run_tests.sh

ZIP := $(B)/codename-droid-c64.zip

zip: $(B)/game.prg tools/make_zip.py tools/dist_run.sh README.md
	$(PYTHON) -I tools/make_zip.py $(B) $(ZIP)

clean:
	rm -rf build/c64 build/c64-cheat build/c64-profile
