; The Apple keyboard (the IIe's and the IIgs's keyboard registers return the same ASCII codes): the key the player presses -> the
; game's key number (src/constants.inc K_*). Upper case; lower case is folded by the reader. Needs K_* (logic_syms.inc).

; ASCII (upper case) -> the logic's key number
keymap: .byte   'X', K_RIGHT, $15, K_RIGHT
        .byte   'Z', K_LEFT, $08, K_LEFT
        .byte   ';', K_UP, $0b, K_UP
        .byte   '/', K_DOWN, $0a, K_DOWN
        .byte   ':', K_UP, '?', K_DOWN             ; the same keys with Shift held (jump)
        .byte   'A', K_TERM, 'J', K_JET, $0d, K_JUMP, '=', K_FIRE, $1b, K_ESC
        .byte   'P', K_PAUSE, $7f, K_PAUSE, 'D', K_MINE, $09, K_TAB, 'O', K_O
        .byte   ' ', K_SPACE, 'S', K_S, 'B', K_B, 'M', K_M
        .byte   0
