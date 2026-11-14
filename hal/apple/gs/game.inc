; The Apple IIgs game build's memory map, shared by logic_hal.s, tramp.s, platform.s, shr.s and the packer.
;
; Bank 2 is the game logic's 64 KB (the C64's layout, src/memory.inc): the logic, built from src/ with the IIgs HAL
; (hal/apple/gs/logic.s), is loaded at $0801 and everything it addresses ($0200-$FFFF, including the places a C64 keeps RAM under
; I/O and ROM) is plain RAM there. The logic runs in 6502 (emulation) mode with the program and data banks set to 2 and the
; direct page at bank 0, page 0.
LOGIC       = $020000           ; the bank-2 address of C64 address 0

; bank 2, in the C64's unused $0700-$07FF
TRAMP       = $0700             ; trampolines: JSL here from emulation mode to call a logic routine (16 bytes each)
TR_COMPUTE_FRAME = TRAMP + 0 * 16
TR_START         = TRAMP + 1 * 16       ; the logic's first routine (logic_start); it does not come back
; (the display layer's direct page is $0700-$0762 in bank 0, and in the display test, where the logic is in bank 0 too, these
; addresses are above it)
; the other way round: stubs in bank 2 that the logic JSRs, which call the platform (bank 0) - tramp.s makes them (`jsl`, `rts`)
HAL_FRAME   = $0768             ; frame_wait: wait for the next frame; the platform shows a staged picture
HAL_WAIT    = $0770             ; wait_frames: A frames
HAL_CHAR    = $0778             ; hal_store_char: character Y has new BBC bytes
HAL_MAIN    = $0780             ; hal_main: the game's main loop (`jml`: it does not come back)
KEYBITS     = $0790             ; 3 bytes: the keys held, as the logic keeps them (bit n - 1 of the three bytes is key n)

; bank 3: the display layer's tables
BBC2SHR     = $030000           ; 1 KB, loaded
SHRCHARS    = $031000           ; 8 KB
SHADOW      = $033000           ; 2 KB: BPAT as last seen
DIRTY       = $033800           ; 256 flags
SHADOWMAT   = $033a00           ; 1000 bytes: the matrix as drawn
CELLSCR     = $033e00           ; 2000 bytes: the screen offset of each cell
; (shr_init zeroes the tables, so the platform need not)

; bank 0
PLAT_FRAME  = $002004           ; the platform's table of entry points (platform.s, segment ENTRY): jml plat_frame ...
PLAT_WAIT   = $002008
PLAT_CHAR   = $00200c
PLAT_MAIN   = $002010
PALETTE_SRC = $1c00             ; palette.bin, loaded here by stage 1
