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
SRC := $(wildcard src/*.s src/*.inc hal/c64/*.s hal/c64/*.inc)

# the loading screens come from the original disc (without it: no loading screens)
DISC   ?= $(HOME)/retro/games/Disc032-CodenameDroidStrykersRun2.ssd
DISC   := $(call tilde,$(DISC))
export DISC

.PHONY: FORCE all test help clean zip release publish apple2-experiment test-apple2-experiment apple2gs-boot apple2gs-demo apple2gs-bars apple2gs-tiles test-apple2gs-tiles test-apple2gs spike-iigs
all: $(B)/game.prg $(if $(wildcard $(DISC)),$(B)/droid.d64)

help:
	@echo "make              build/c64/game.prg (and droid.d64 with the loading screens, if the original disc is found)"
	@echo "make CHEAT=1      the test build in build/c64-cheat; PROFILE=1: with timing bars"
	@echo "make test         the headless checks (6502 simulator, no emulator)"
	@echo "make apple2-experiment  build the Apple II HGR scrolling experiment for LinApple"
	@echo "make test-apple2-experiment  check the Apple II redraw with the headless 6502 simulator"
	@echo "make zip          build/c64/codename-droid-c64.zip: the disk image, the PRG, a VICE run script and README.md"
	@echo "make release      build a versioned zip and SHA256SUMS from a clean committed tree"
	@echo "make publish TAG=v1.0.0 [DRY=1]  create and publish a GitHub release"
	@echo "make apple2gs-boot  build the IIgs game disk (build/apple2gs/game/droid-gs.po); apple2gs-demo: the tile scroller disk; apple2gs-bars: the grey-bar test"
	@echo "make test-apple2gs-tiles  convert the tiles to Super Hi-Res and check them against the BBC data"
	@echo "make test-apple2gs  the IIgs checks: 65816 interpreter, boot block, tiles (headless, no emulator)"
	@echo "make spike-iigs  the IIgs spike: the C64 logic on a 6502 and a 65816 compared"
	@echo "make clean        remove build/c64* and build/apple2 (build/bbc: make -C bbc clean)"

# the BBC game rebuilt first (its disc.lbl and CDroid4 are what the data tools read)
$(BBC)/CDroid4 $(BBC)/disc.lbl:
	$(MAKE) -C bbc B=$(abspath $(BBC))

$(B)/game_data.inc: tools/make_data.py tools/bbcmem.py tools/make_tables.py tools/make_sound_tables.py tools/make_title_map.py tools/bbcsim.py tools/sim6502.py $(BBC)/CDroid4
	$(PYTHON) -I tools/make_data.py $(B)

$(B)/game.o: $(SRC) $(B)/game_data.inc
	$(CA65) -g $(if $(PROFILE),-DPROFILE) $(if $(CHEAT),-DCHEAT) -I $(B) -I src -I hal/c64 hal/c64/game.s -o $@ -l $(B)/game.lst

$(B)/game.prg: $(B)/game.o hal/c64/c64.cfg
	$(LD65) -C hal/c64/c64.cfg $< -o $@ -Ln $(B)/game.lbl -m $(B)/game.map

# the loading screens, a program of their own that loads the game (hal/c64/intro/)
$(GEN)/intro_data.s: tools/make_intro.py tools/mode7.py tools/make_title_map.py tools/detok.py $(wildcard $(DISC))
	@test -f "$(DISC)" || { echo "Original BBC disc image not found: $(DISC)" >&2; exit 1; }
	@mkdir -p $(GEN)
	$(PYTHON) -I tools/make_intro.py $@

$(B)/intro.prg: hal/c64/intro/intro_main.s hal/c64/intro/intro.cfg hal/c64/intro.s $(GEN)/intro_data.s
	@test -f "$(DISC)" || { echo "Original BBC disc image not found: $(DISC)" >&2; exit 1; }
	$(CA65) -g -I src -I hal/c64 -I hal/c64/intro -I $(GEN) hal/c64/intro/intro_main.s -o $(B)/intro.o -l $(B)/intro.lst
	$(LD65) -C hal/c64/intro/intro.cfg $(B)/intro.o -o $@ -m $(B)/intro.map -Ln $(B)/intro.lbl

$(B)/droid.d64: $(B)/intro.prg $(B)/game.prg
	$(C1541) -format "droid,01" d64 $@ -write $(B)/intro.prg droid -write $(B)/game.prg game >/dev/null

apple2-experiment: build/apple2/scroll.apl

test-apple2-experiment: apple2-experiment
	$(PYTHON) -I tools/test_apple2_experiment.py

build/apple2/glyphs.bin build/apple2/world.bin &: tools/make_apple2_experiment.py tools/bbcmem.py $(B)/game.prg $(BBC)/CDroid4
	$(PYTHON) -I tools/make_apple2_experiment.py $(B)

build/apple2/scroll.bin: hal/apple/ii/scroll.s hal/apple/ii/scroll.cfg build/apple2/glyphs.bin build/apple2/world.bin
	$(CA65) -I build/apple2 hal/apple/ii/scroll.s -o build/apple2/scroll.o
	$(LD65) -C hal/apple/ii/scroll.cfg build/apple2/scroll.o -o $@ -Ln build/apple2/scroll.lbl

build/apple2/scroll.apl: build/apple2/scroll.bin tools/pack_apple2_experiment.py
	$(PYTHON) -I tools/pack_apple2_experiment.py $< $@

# The Apple IIgs disks (build/apple2gs/): game/droid-gs.po (the C64 logic on the IIgs, milestone 1), demo/demo.po (the earlier
# tile scroller), bars.po (the first boot test). `apple2gs-boot` is the game disk.
apple2gs-boot: build/apple2gs/game/droid-gs.po

apple2gs-demo: build/apple2gs/demo/demo.po

apple2gs-bars: build/apple2gs/bars.po

test-apple2gs: apple2gs-boot apple2gs-demo apple2gs-bars test-apple2gs-tiles
	$(PYTHON) -I tools/test_sim65816.py
	$(PYTHON) -I tools/test_apple2gs_bars.py
	$(PYTHON) -I tools/test_apple2gs_loader.py
	$(PYTHON) -I tools/test_apple2gs_draw.py
	$(PYTHON) -I tools/test_iigs_display.py
	$(PYTHON) -I tools/test_apple2gs_game.py

spike-iigs: $(B)/game.prg
	$(PYTHON) -I tools/spike_iigs_diff.py 150 1
	$(PYTHON) -I tools/spike_iigs_diff.py 150 1 --split

apple2gs-tiles: build/apple2gs/cells.bin

build/apple2gs/cells.bin build/apple2gs/tiles.bin build/apple2gs/levels.bin build/apple2gs/palette.bin build/apple2gs/bbc2shr.bin &: tools/make_apple2gs_tiles.py tools/bbcmem.py $(BBC)/CDroid4 $(B)/game.prg
	$(PYTHON) -I tools/make_apple2gs_tiles.py

test-apple2gs-tiles: $(BBC)/CDroid4 $(B)/game.prg
	$(PYTHON) -I tools/test_apple2gs_tiles.py

# the game logic for the IIgs: src/ with hal/apple/gs/logic_hal.s, loaded at $0801 of bank 2 (logic.bin); logic.lbl has its labels
build/apple2gs/logic.bin build/apple2gs/logic.lbl &: hal/apple/gs/logic.s hal/apple/gs/logic_hal.s hal/apple/gs/hal.inc hal/apple/gs/game.inc hal/apple/gs/logic.cfg $(wildcard src/*.s src/*.inc) $(B)/game_data.inc
	mkdir -p build/apple2gs
	$(CA65) -g -I $(B) -I src -I hal/apple/gs hal/apple/gs/logic.s -o build/apple2gs/logic.o -l build/apple2gs/logic.lst
	$(LD65) -C hal/apple/gs/logic.cfg build/apple2gs/logic.o -o build/apple2gs/logic.bin -Ln build/apple2gs/logic.lbl -m build/apple2gs/logic.map

# where the logic keeps what the IIgs layers read (addresses from logic.lbl, equates from src/memory.inc and src/constants.inc)
build/apple2gs/logic_syms.inc: tools/make_iigs_logic_syms.py build/apple2gs/logic.lbl src/memory.inc src/constants.inc
	$(PYTHON) -I tools/make_iigs_logic_syms.py

build/apple2gs/bars.bin: hal/apple/gs/bars.s hal/apple/gs/bars.cfg
	mkdir -p build/apple2gs
	$(CA65) hal/apple/gs/bars.s -l build/apple2gs/bars.lst -o build/apple2gs/bars.o
	$(LD65) -C hal/apple/gs/bars.cfg build/apple2gs/bars.o -o $@

build/apple2gs/bars.po: build/apple2gs/bars.bin tools/pack_apple2gs_boot.py
	$(PYTHON) -I tools/pack_apple2gs_boot.py $< $@

build/apple2gs/boot.bin: hal/apple/gs/boot.s hal/apple/gs/boot.cfg hal/apple/gs/loader.inc
	mkdir -p build/apple2gs
	$(CA65) -I hal/apple/gs hal/apple/gs/boot.s -l build/apple2gs/boot.lst -o build/apple2gs/boot.o
	$(LD65) -C hal/apple/gs/boot.cfg build/apple2gs/boot.o -o $@

# ---- the demo: demo.s and the tile drawing routines at $2000
build/apple2gs/demo.bin: hal/apple/gs/demo.s hal/apple/gs/draw.s hal/apple/gs/demo.cfg hal/apple/gs/loader.inc
	mkdir -p build/apple2gs
	$(CA65) -I hal/apple/gs hal/apple/gs/demo.s -l build/apple2gs/demo.lst -o build/apple2gs/demo.o
	$(CA65) hal/apple/gs/draw.s -l build/apple2gs/draw.lst -o build/apple2gs/draw.o
	$(LD65) -C hal/apple/gs/demo.cfg build/apple2gs/demo.o build/apple2gs/draw.o -o $@ -Ln build/apple2gs/demo.lbl

build/apple2gs/demo/loadtab.inc: build/apple2gs/demo.bin build/apple2gs/cells.bin tools/make_apple2gs_disk.py hal/apple/gs/loader.inc
	mkdir -p build/apple2gs/demo
	$(PYTHON) -I tools/make_apple2gs_disk.py prepare demo

build/apple2gs/demo/stage1.bin: hal/apple/gs/stage1.s hal/apple/gs/stage1.cfg hal/apple/gs/loader.inc build/apple2gs/demo/loadtab.inc
	$(CA65) -I hal/apple/gs -I build/apple2gs/demo hal/apple/gs/stage1.s -l build/apple2gs/demo/stage1.lst -o build/apple2gs/demo/stage1.o
	$(LD65) -C hal/apple/gs/stage1.cfg build/apple2gs/demo/stage1.o -o $@

build/apple2gs/demo/demo.po: build/apple2gs/boot.bin build/apple2gs/demo/stage1.bin build/apple2gs/demo.bin tools/make_apple2gs_disk.py
	$(PYTHON) -I tools/make_apple2gs_disk.py pack demo

# ---- the game: the platform and display layers at $2000, the trampolines, and the C64 logic (patched) in bank 2
build/apple2gs/tramp.bin: hal/apple/gs/tramp.s hal/apple/gs/tramp.cfg hal/apple/gs/game.inc build/apple2gs/logic_syms.inc
	mkdir -p build/apple2gs
	$(CA65) -I hal/apple/gs -I build/apple2gs hal/apple/gs/tramp.s -l build/apple2gs/tramp.lst -o build/apple2gs/tramp.o
	$(LD65) -C hal/apple/gs/tramp.cfg build/apple2gs/tramp.o -o $@

build/apple2gs/game_code.bin: hal/apple/keymap.inc hal/apple/gs/platform.s hal/apple/gs/shr.s hal/apple/gs/game.cfg hal/apple/gs/game.inc build/apple2gs/logic_syms.inc
	mkdir -p build/apple2gs
	$(CA65) -I hal/apple/gs -I hal/apple -I build/apple2gs hal/apple/gs/platform.s -l build/apple2gs/platform.lst -o build/apple2gs/platform.o
	$(CA65) -D LOGIC=\$$020000 -I hal/apple/gs -I build/apple2gs hal/apple/gs/shr.s -l build/apple2gs/shr_game.lst -o build/apple2gs/shr_game.o
	$(LD65) -C hal/apple/gs/game.cfg build/apple2gs/platform.o build/apple2gs/shr_game.o -o $@ -Ln build/apple2gs/game_code.lbl
	@test -f build/apple2gs/slam.bin

build/apple2gs/slam.bin: build/apple2gs/game_code.bin
	@true

build/apple2gs/game/loadtab.inc: build/apple2gs/game_code.bin build/apple2gs/slam.bin build/apple2gs/tramp.bin build/apple2gs/logic.bin build/apple2gs/palette.bin build/apple2gs/bbc2shr.bin tools/make_apple2gs_disk.py hal/apple/gs/loader.inc hal/apple/gs/game.inc
	mkdir -p build/apple2gs/game
	$(PYTHON) -I tools/make_apple2gs_disk.py prepare game

build/apple2gs/game/stage1.bin: hal/apple/gs/stage1.s hal/apple/gs/stage1.cfg hal/apple/gs/loader.inc build/apple2gs/game/loadtab.inc
	$(CA65) -I hal/apple/gs -I build/apple2gs/game hal/apple/gs/stage1.s -l build/apple2gs/game/stage1.lst -o build/apple2gs/game/stage1.o
	$(LD65) -C hal/apple/gs/stage1.cfg build/apple2gs/game/stage1.o -o $@

build/apple2gs/game/droid-gs.po: build/apple2gs/boot.bin build/apple2gs/game/stage1.bin build/apple2gs/game_code.bin tools/make_apple2gs_disk.py
	$(PYTHON) -I tools/make_apple2gs_disk.py pack game

test: $(B)/game.prg
	bash tools/run_tests.sh
	$(if $(wildcard $(DISC)),$(MAKE) -s $(B)/intro.prg && $(PYTHON) -I tools/test_intro_loader.py $(B),@echo "Skipping intro loader test: original disc image not found")

ZIP := $(B)/codename-droid-c64.zip

zip: $(B)/game.prg $(B)/droid.d64 tools/make_zip.py tools/dist_run.sh README.md
	$(PYTHON) -I tools/make_zip.py $(B) $(ZIP)

# Release builds are isolated from normal, cheat and profile builds.
RELEASE_VERSION ?= $(shell git describe --tags --always 2>/dev/null)
RELEASE_BUILD := build/release-build
RELEASE_DIR := build/release
export TAG RELEASE_VERSION

release:
	@status=$$(git status --porcelain --untracked-files=normal) || exit 1; \
	  test -z "$$status" || { echo "release: uncommitted changes - commit first" >&2; exit 1; }
	@printf '%s\n' "$$RELEASE_VERSION" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$$' || { echo "release: invalid version" >&2; exit 1; }
	$(MAKE) -B B=$(RELEASE_BUILD) GEN=$(RELEASE_BUILD)/gen CHEAT= PROFILE= zip
	@mkdir -p $(RELEASE_DIR)
	@printf '%s\n' "Codename Droid $$RELEASE_VERSION" "commit $$(git rev-parse HEAD)" "built $$(date -u +%Y-%m-%dT%H:%MZ)" > $(RELEASE_DIR)/VERSION.txt
	@cp $(RELEASE_BUILD)/codename-droid-c64.zip "$(RELEASE_DIR)/codename-droid-c64-$$RELEASE_VERSION.zip"
	@zip -j -X -q "$(RELEASE_DIR)/codename-droid-c64-$$RELEASE_VERSION.zip" $(RELEASE_DIR)/VERSION.txt
	@cd $(RELEASE_DIR) && sha256sum "codename-droid-c64-$$RELEASE_VERSION.zip" > SHA256SUMS
	@ls -l "$(RELEASE_DIR)/codename-droid-c64-$$RELEASE_VERSION.zip" $(RELEASE_DIR)/SHA256SUMS

publish:
	@printf '%s\n' "$$TAG" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9][A-Za-z0-9.-]*)?$$' || { echo "publish: TAG=vX.Y.Z[-suffix] required" >&2; exit 1; }
	@status=$$(git status --porcelain --untracked-files=normal) || exit 1; \
	  test -z "$$status" || { echo "publish: uncommitted changes - commit first" >&2; exit 1; }
	@! git rev-parse -q --verify "refs/tags/$$TAG" >/dev/null || { echo "publish: tag $$TAG already exists" >&2; exit 1; }
	@awk -v t="$$TAG" '$$0 == "## " t || $$0 == "## [" t "]" {p=1; next} /^## /{p=0} p' CHANGELOG.md | grep -q '[^[:space:]]' || { echo "publish: no release notes for $$TAG in CHANGELOG.md" >&2; exit 1; }
	@if [ -n "$(DRY)" ]; then \
	  echo "would: build release, tag $$TAG, push to origin, and create GitHub release"; \
	  echo "---- release notes ----"; \
	  awk -v t="$$TAG" '$$0 == "## " t || $$0 == "## [" t "]" {p=1; next} /^## /{p=0} p' CHANGELOG.md; \
	else \
	  $(MAKE) release RELEASE_VERSION="$$TAG" && \
	  awk -v t="$$TAG" '$$0 == "## " t || $$0 == "## [" t "]" {p=1; next} /^## /{p=0} p' CHANGELOG.md > $(RELEASE_DIR)/NOTES.md && \
	  git tag "$$TAG" && git push origin "$$TAG" && \
	  { case "$$TAG" in *-*) gh release create "$$TAG" "$(RELEASE_DIR)/codename-droid-c64-$$TAG.zip" $(RELEASE_DIR)/SHA256SUMS --title "$$TAG" --notes-file $(RELEASE_DIR)/NOTES.md --prerelease ;; \
	    *) gh release create "$$TAG" "$(RELEASE_DIR)/codename-droid-c64-$$TAG.zip" $(RELEASE_DIR)/SHA256SUMS --title "$$TAG" --notes-file $(RELEASE_DIR)/NOTES.md ;; esac; }; \
	fi

clean:
	rm -rf build/c64 build/c64-cheat build/c64-profile build/apple2 build/apple2gs
