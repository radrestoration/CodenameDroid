; The memory map of the game logic: where it keeps its tables. It is the C64's (VIC-II bank 3), and the other platforms keep it, so
; that the logic and its data run unchanged in a 64 KB space of their own. (Platforms add what is theirs to their hal.inc.)
; ---- memory
BPAT        = $ee00             ; the BBC bytes of each character: line n of character c at BPAT + n * 256 + c
HEAD        = $f600             ; character sharing: hash chains
NXT         = $f700
TG          = $f800             ; the level's tile grids: 16 characters for each of the 16 nibbles
TGALT       = $f900             ; the chandelier turned the other way
ROWS        = $a000             ; 32 rows of 256 characters ($a000-$bfff)
CHARSET     = $c000             ; VIC-II bank 3
MAT_A       = $c800
MAT_B       = $cc00
RIDE_CHARSET = $d000            ; lift display charset; ride sprites are staged at $de80
RIDE_MAT_A  = MAT_A
RIDE_MAT_B  = MAT_B
STAGE_CHARSET = $d800           ; next level's charset while the ride is displayed
SPRAREA     = $d000             ; the sprite blocks, copied under the I/O area at start
SPRBASE     = $40               ; their pointer base
D018_A      = $20
D018_B      = $30
RIDE_D018_A = $24
RIDE_D018_B = $34
LTILES      = $e000             ; the 14 levels' tile maps as they stand (a page each: $e000-$edff)
MIRROR_TABLE = $0600            ; a byte with its four two-bit pixels in the other order (made at start)
mirror_table = MIRROR_TABLE
SND         = $fa00             ; the sound driver's variables

