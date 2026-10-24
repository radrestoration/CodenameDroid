# Codename Droid (BBC Micro, Superior Software 1987) - rebuilt from the
# disassembly with cc65. The default target is the DISC release (file
# CDroid4); `make tape` builds the release the disassembly is of.
# `make help` lists the targets.

-include ../tools.cfg
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
BEM        ?= b-em
override CA65 := $(call tilde,$(CA65))
override LD65 := $(call tilde,$(LD65))
BEM_DIR    := $(call tilde,$(BEM_DIR))

LISTING := codename-droid-disassembly.txt
DISC    := $(HOME)/retro/games/Disc032-CodenameDroidStrykersRun2.ssd
SRC     := $(wildcard src/*.s src/*.inc)
B       := $(abspath ../build/bbc)

.PHONY: all tape check run clean help
all: $(B)/CDroid4 $(B)/droid.ssd $(B)/standalone.ssd check

help:
	@echo "make        build the disc release: ../build/bbc/CDroid4, droid.ssd (the original disc"
	@echo "            with CDroid4 replaced), standalone.ssd; then check"
	@echo "make tape   build the tape release as listed: ../build/bbc/DROID, DROID2"
	@echo "make check  compare with the listing's bytes, the label addresses and the disc"
	@echo "make run    start b-em on ../build/bbc/droid.ssd"
	@echo "make clean"

$(B)/disc.o: $(SRC)
	@mkdir -p $(B)
	cd src && $(CA65) -g disc.s -o $@ -l $(B)/disc.lst

$(B)/tape.o: $(SRC)
	@mkdir -p $(B)
	cd src && $(CA65) -g tape.s -o $@ -l $(B)/tape.lst

$(B)/CDroid4: $(B)/disc.o disc.cfg
	$(LD65) -C disc.cfg -m $(B)/disc.map -Ln $(B)/disc.lbl $(B)/disc.o

$(B)/DROID $(B)/DROID2: $(B)/tape.o tape.cfg
	$(LD65) -C tape.cfg -m $(B)/tape.map -Ln $(B)/tape.lbl $(B)/tape.o

tape: $(B)/DROID $(B)/DROID2

$(B)/droid.ssd: $(B)/CDroid4 tools/make_ssd.py tools/make_bbc_ssd.py
	$(PYTHON) -I tools/make_ssd.py disc $(B) $(DISC) $@

$(B)/standalone.ssd: $(B)/CDroid4 boot/boot.txt tools/make_ssd.py
	$(PYTHON) -I tools/make_ssd.py standalone $(B) $@

check: $(B)/CDroid4
	$(PYTHON) -I tools/check_build.py $(LISTING) $(B) $(DISC)
	@if [ -f $(B)/droid.ssd ] && [ -f $(DISC) ]; then cmp -s $(B)/droid.ssd $(DISC) && echo "droid.ssd is byte-identical to the original disc" || echo "droid.ssd DIFFERS from the original disc"; fi

run: $(B)/droid.ssd
	cd $(BEM_DIR) && $(BEM) $(B)/droid.ssd

clean:
	rm -rf $(B)
