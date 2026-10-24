; C64 memory map. The BBC game runs unchanged at its own addresses:
;   $0100-$01ff stack and game variables     $0300-$10ff game data blocks (moved there at start)
;   $1100-$57ff game code
;   the game's screen buffer ("the ring": 32 rows of RING_W cells of 8 bytes, BBC MODE 5 format):
;     RING_W = 32: $6000-$7fff, the tile graphics at $5800-$5fff (the BBC's layout)
;     RING_W = 40: $5800-$7fff, the tile graphics moved to $8000-$87ff
; and the C64 side sits above it (VIC-II bank 2, $8000-$bfff; the CPU runs with $01 = $35: RAM everywhere except I/O):
;   engine code, tables, one-shot start-up;  $a000 charset (2 KB), $a800/$ac00 screen matrices, then the cell/character
;   bookkeeping.
; RING_W (cells per row of the ring, and the width of the game's window) comes from params.inc, written by
; tools/make_game_source.py (WIDE=32 or WIDE=40).
.include "params.inc"

RING_CELLS  = RING_W * 32   ; cells in the ring
STRIDE      = RING_W * 8    ; bytes from a cell to the one below it
RING_SZ     = RING_CELLS * 8
RING        = $8000 - RING_SZ         ; the ring ends at $8000 (the game wraps its addresses with a sign test)
RING_HI     = >RING
RING_SZ_HI  = >RING_SZ
CRTC_HI     = RING_HI / 8       ; the CRTC start address (in cells) of the ring's first cell: $0c00, or $0b00

CHARSET     = $a000
.if RING_W = 32
TILES       = $5800         ; the tile graphics (2 KB, as on the BBC)
ENGINE      = $8000         ; the engine (start, code, tables)
.else
TILES       = $8000         ; moved above the ring
ENGINE      = $8800
.endif
MATRIX      = $a800         ; the two screen matrices: one is shown while the other is built, and the interrupt swaps them
MATRIX2     = $ac00
.if RING_W = 32
CELLCHAR    = $b000         ; 1056: the character shown for each of the ring's 1024 cells,
                            ; plus a copy of the first 32 so a row never wraps
DFLAG       = $b500         ; 1024, page-aligned: cell is on the dirty list
HEAD        = $b900         ; hash bucket -> first character, $ff = none
NXT         = $ba00         ; character -> next in its bucket
HASHV       = $bb00         ; character -> its bucket
REFL        = $bc00         ; reference counts (16 bit: a character can be on 1024 cells)
REFH        = $bd00
FREELIST    = $be00         ; free characters (stack)
DLO         = $c000         ; the dirty list: 1024 entries of cell index low/high
DHI         = $c400
BPAT0       = $c800         ; the BBC-format bytes of each character, one table per line
BPAT1       = $c900         ; (so a comparison can index by character)
BPAT2       = $ca00
BPAT3       = $cb00
BPAT4       = $cc00
BPAT5       = $cd00
BPAT6       = $ce00
BPAT7       = $cf00
.else
CELLCHAR    = $b000         ; 1320: the character shown for each of the ring's 1280 cells + a copy of the first 40
DFLAG       = $b600         ; 1280, page-aligned: cell is on the dirty list
HEAD        = $bb00         ; hash bucket -> first character, $ff = none
NXT         = $bc00         ; character -> next in its bucket
HASHV       = $bd00         ; character -> its bucket
REFL        = $be00         ; reference counts (16 bit)
REFH        = $bf00
FREELIST    = $c000         ; free characters (stack)
DLO         = $c100         ; the dirty list: 1280 entries of cell index low/high
DHI         = $c600
ROWTAB      = $cb00         ; 1280: row of a cell offset d from the top left of the view (d / RING_W)
BPAT0       = $e000         ; the BBC-format bytes of each character, one table per line (RAM the VIC-II does not see)
BPAT1       = $e100
BPAT2       = $e200
BPAT3       = $e300
BPAT4       = $e400
BPAT5       = $e500
BPAT6       = $e600
BPAT7       = $e700
COLTAB      = $e800         ; 1280: column of a cell offset d (d mod RING_W)
.endif

; matrix layout: 25 rows of 40. The view is c64_vcols columns of the ring's window, in matrix columns c64_mcol0 on
; (32 columns at 4 when the game's window is 32 wide, and on the title and the status screens when it is wider: they
; are drawn in the leftmost 32 columns; 40 columns at 0 in play)
VIEW_ROWS   = 25

; small variables the patched game code refers to (RAM page 2, free on the C64)
c64_crtc_high   = $0200     ; the game's "CRTC start address" (R12/R13), set by set_crtc_address
c64_crtc_low    = $0201
c64_via_ddr_b   = $0202     ; the game checks this still holds $d4 each loop (BBC: User VIA DDRB)
c64_cam         = $0203     ; vertical camera: first ring row shown (0-7)
c64_flash       = $0204     ; spare
c64_t0          = $0218     ; scratch for the geometry helpers (ring_ops.s)
c64_t1          = $0219
c64_t2          = $021a
c64_t3          = $021b
c64_mcol0       = $0214     ; matrix column of the view's first column
c64_vcols       = $0215     ; columns in the view
c64_back        = $020b     ; high byte of the matrix being built ($a8 or $ac); the other one is shown
c64_flip        = $020c     ; 1 = the back matrix is complete: the next interrupt swaps
c64_title       = $020f     ; 1 = the title screen: 24 rows (RSEL = 0, YSCROLL 7): ring rows 4-27 exactly, centred
c64_skip        = $020e     ; toggles: while the title scrolls the display is updated every other step
c64_busy        = $020d     ; 1 = the back matrix is being built: no swap
hk_lo           = $0210     ; set by the plot hooks
hk_hi           = $0211
hk_cols         = $0212
hk_lines        = $0213
bl_prev         = $0220     ; blaster slots' previous screen address (lo, hi) x 6, $ffff = none (24 bytes)

; keyboard scan state (page 2)
kb_rows         = $0230     ; 8 bytes: the keyboard matrix rows read for each column (0 bits = pressed)
kb_new          = $0238     ; 12: codes pressed in this scan (table order), kb_nnew of them
kb_held         = $0244     ; 4: held game keys, oldest first
kb_nheld        = $0248
kb_nnew         = $0249
kb_ascii        = $024a     ; ASCII of the first key newly pressed in the last scan (0 = none); for OSRDCH
kb_joy          = $024b
kb_tmp          = $024c
kb_prev         = $0280     ; 9: the keyboard rows and joystick as the last scan with a change saw them

c64_pal         = $0205     ; 1 = PAL (50 Hz), 0 = NTSC (60 Hz)
c64_frames      = $0206     ; counts the raster interrupts (frames)
c64_lastf       = $0208     ; c64_frames when hw_wait_frame last returned
c64_acc         = $0209     ; NTSC pacing: frames owed to the BBC's 50 Hz, in fifths, plus 32
c64_defer       = $020a     ; 1 = a vertical-blank wait has returned and its display update is still to come
c64_gamemode    = $0207     ; 1 = gameplay (the camera follows the player), 0 = any other screen
