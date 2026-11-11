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

.PHONY: all test help clean zip release publish
all: $(B)/game.prg $(if $(wildcard $(DISC)),$(B)/droid.d64)

help:
	@echo "make              build/c64/game.prg (and droid.d64 with the loading screens, if the original disc is found)"
	@echo "make CHEAT=1      the test build in build/c64-cheat; PROFILE=1: with timing bars"
	@echo "make test         the headless checks (6502 simulator, no emulator)"
	@echo "make zip          build/c64/codename-droid-c64.zip: the disk image, the PRG, a VICE run script and README.md"
	@echo "make release      build a versioned zip and SHA256SUMS from a clean committed tree"
	@echo "make publish TAG=v1.0.0 [DRY=1]  create and publish a GitHub release"
	@echo "make clean        remove build/c64* (build/bbc is the BBC game's: make -C bbc clean)"

# the BBC game rebuilt first (its disc.lbl and CDroid4 are what the data tools read)
$(BBC)/CDroid4 $(BBC)/disc.lbl:
	$(MAKE) -C bbc B=$(abspath $(BBC))

$(B)/game_data.inc: tools/make_data.py tools/bbcmem.py tools/make_tables.py tools/make_sound_tables.py tools/make_title_map.py tools/bbcsim.py tools/sim6502.py $(BBC)/CDroid4
	$(PYTHON) -I tools/make_data.py $(B)

$(B)/game.o: $(SRC) $(B)/game_data.inc
	$(CA65) -g $(if $(PROFILE),-DPROFILE) $(if $(CHEAT),-DCHEAT) -I $(B) -I src src/game.s -o $@ -l $(B)/game.lst

$(B)/game.prg: $(B)/game.o c64.cfg
	$(LD65) -C c64.cfg $< -o $@ -Ln $(B)/game.lbl -m $(B)/game.map

# the loading screens, a program of their own that loads the game (intro/)
$(GEN)/intro_data.s: tools/make_intro.py tools/mode7.py tools/make_title_map.py tools/detok.py $(wildcard $(DISC))
	@test -f "$(DISC)" || { echo "Original BBC disc image not found: $(DISC)" >&2; exit 1; }
	@mkdir -p $(GEN)
	$(PYTHON) -I tools/make_intro.py $@

$(B)/intro.prg: intro/intro_main.s intro/intro.cfg src/intro.s $(GEN)/intro_data.s
	@test -f "$(DISC)" || { echo "Original BBC disc image not found: $(DISC)" >&2; exit 1; }
	$(CA65) -g -I src -I intro -I $(GEN) intro/intro_main.s -o $(B)/intro.o -l $(B)/intro.lst
	$(LD65) -C intro/intro.cfg $(B)/intro.o -o $@ -m $(B)/intro.map -Ln $(B)/intro.lbl

$(B)/droid.d64: $(B)/intro.prg $(B)/game.prg
	$(C1541) -format "droid,01" d64 $@ -write $(B)/intro.prg droid -write $(B)/game.prg game >/dev/null

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
	rm -rf build/c64 build/c64-cheat build/c64-profile
