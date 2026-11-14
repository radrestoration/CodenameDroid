; Game constants and key numbers shared by every platform.
MAXCH       = 204               ; characters 1 - 203 are the level's; 253 - 255 the mine
CH_EXPL1    = 253
CH_EXPL0    = 254
CH_MINE     = 255

CENTER      = 17 * 8 * 16       ; where the player is on the screen (1/16 pixel)
MAXPOS      = 216 * 8 * 16
STEP_ACC    = 24

; keys (one byte each in `keys` as bits; `key1` and `key2` give the order of pressing)
K_RIGHT     = 1                 ; X
K_LEFT      = 2                 ; Z
K_UP        = 3
K_DOWN      = 4
K_TERM      = 5                 ; A
K_JET       = 6                 ; J
K_JUMP      = 7                 ; RETURN
K_FIRE      = 8
K_ESC       = 9
K_F0        = 10
K_F1        = 11
K_PAUSE     = 12
K_MINE      = 13                ; D
K_TAB       = 14
K_O         = 15
K_SPACE     = 16
K_S         = 17
K_B         = 18
K_M         = 19
KEYS        = 20                ; key numbers 1 - KEYS (K_M is the last used)
