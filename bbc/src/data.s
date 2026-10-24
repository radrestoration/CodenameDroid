; Codename Droid (BBC Micro, Superior Software 1987) - data blocks that the entry code moves into place
;
; Converted from codename-droid-disassembly.txt by tools/disasm_to_ca65.py.
; The preamble of that disassembly:
;
; Codename Droid was written by Nicholas Chamberlain and Martin Edmondson, and
; was published by Superior Software for the BBC Micro in 1987. It is an arcade
; adventure game in which the player must seize a spaceship from an underground
; base. It is the sequel to Superior's 1986 game, Stryker's Run.
;
; The following disassembly was created by reverse engineering binary images,
; without access to any source code. It is nevertheless reasonably complete,
; allowing the technical approaches used to be understood.
;
; The author of this disassembly imposes no additional copyright restrictions
; beyond those already present on the game itself. It is provided for educational
; purposes only, and it is hoped that the original authors will accept it in the
; good faith it was intended - as a tribute to their skills.
;

; (tape release: file DROID2, load &6500, exec &7b00, length &1700; the disc has these blocks inside CDroid4, in a different order)

; &6500 - &6cff is moved to &5800 - &5fff at &7b85


.segment "D2_5800"

tile_sprite_platform:
    .byte $ff,$af,$ff,$80,$80,$c0,$60,$30,$10,$60,$c0,$80,$80,$ff,$af,$ff
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $ff,$af,$ff,$10,$30,$60,$c0,$00,$80,$c0,$60,$30,$10,$ff,$af,$ff
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

tile_sprite_surface_wall_horizontal:
    .byte $88,$6e,$ae,$7f,$3f,$5f,$0f,$0f,$2f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
    .byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
    .byte $11,$11,$33,$23,$57,$67,$cf,$9f,$0f,$4f,$0f,$0f,$0f,$0f,$0f,$0f
    .byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f

tile_sprite_surface_wall_corner:
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $11,$11,$11,$11,$11,$33,$23,$33,$33,$11,$77,$57,$47,$47,$ef,$8f
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$33,$23,$57,$67
    .byte $cf,$8f,$5f,$8f,$0f,$2f,$8f,$0f,$0f,$8f,$0f,$0f,$0f,$8f,$0f,$0f
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$77,$57,$57,$af,$df,$8f,$8f,$2f
    .byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
    .byte $11,$11,$77,$67,$57,$ef,$cf,$47,$47,$cf,$af,$0f,$4f,$0f,$0f,$0f
    .byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f

tile_sprite_pipe_horizontal:
    .byte $00,$00,$00,$00,$a0,$50,$a0,$f0,$50,$f0,$f0,$f0,$f0,$f0,$f0,$ff
    .byte $ff,$f0,$f0,$f0,$f0,$f0,$f0,$50,$f0,$a0,$50,$a0,$00,$00,$00,$00
    .byte $03,$07,$07,$04,$81,$40,$a0,$f0,$50,$f0,$f0,$f0,$f0,$f0,$f0,$ff
    .byte $ff,$f0,$f0,$f0,$f0,$f0,$f0,$50,$f0,$a0,$40,$81,$04,$07,$07,$03
    .byte $08,$0c,$0c,$04,$0e,$0d,$07,$06,$03,$83,$83,$83,$c1,$c1,$c1,$cd
    .byte $cd,$c1,$c1,$c1,$83,$83,$83,$03,$06,$07,$0d,$0e,$04,$0c,$0c,$08
    .byte $00,$00,$00,$00,$a0,$50,$28,$78,$58,$3c,$3c,$34,$1e,$1e,$1e,$1b
    .byte $1b,$1e,$1e,$1e,$34,$3c,$3c,$58,$78,$28,$50,$a0,$00,$00,$00,$00

tile_sprite_pipe_vertical:
    .byte $20,$10,$20,$10,$20,$10,$20,$10,$20,$10,$24,$04,$0b,$0b,$0b,$09
    .byte $03,$03,$21,$01,$20,$10,$20,$10,$20,$10,$20,$10,$20,$10,$20,$10
    .byte $f1,$b1,$f1,$b1,$f1,$b1,$f1,$b1,$f1,$b1,$f1,$b1,$71,$31,$08,$0f
    .byte $0f,$07,$0d,$0f,$0f,$0f,$f1,$b1,$f1,$b1,$f1,$b1,$f1,$b1,$f1,$b1

tile_sprite_computer:
    .byte $00,$00,$00,$00,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    .byte $10,$10,$00,$10,$10,$10,$10,$10,$00,$10,$21,$62,$51,$f0,$ff,$f0
    .byte $00,$00,$00,$00,$f0,$00,$00,$06,$00,$05,$00,$02,$00,$05,$00,$f0
    .byte $b4,$f0,$00,$f0,$e0,$80,$e0,$f0,$00,$f0,$05,$aa,$55,$f0,$ff,$f0

tile_sprite_pipe_corner:
    .byte $20,$10,$20,$10,$20,$10,$20,$10,$20,$10,$00,$10,$00,$10,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $f0,$70,$d0,$70,$f0,$70,$d0,$70,$f0,$70,$d0,$70,$b0,$60,$b0,$50
    .byte $b0,$50,$20,$50,$20,$10,$00,$10,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $d8,$e8,$b8,$e8,$f8,$f8,$d8,$fc,$f4,$f4,$f6,$f2,$f2,$f3,$f1,$f1
    .byte $70,$f0,$b0,$f0,$d0,$70,$b0,$50,$a0,$50,$20,$10,$00,$00,$00,$00
    .byte $40,$80,$40,$a0,$50,$a0,$50,$a0,$d0,$60,$f0,$d0,$f0,$f0,$f8,$ff
    .byte $ff,$f0,$f0,$f0,$f0,$f0,$50,$f0,$a0,$50,$a0,$50,$00,$00,$00,$00

tile_sprite_chain:
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $32,$22,$44,$44,$44,$22,$32,$10,$32,$22,$44,$44,$44,$22,$32,$10
    .byte $32,$22,$44,$44,$44,$22,$32,$10,$32,$22,$44,$44,$44,$22,$32,$10
    .byte $80,$80,$40,$40,$40,$80,$80,$00,$80,$80,$40,$40,$40,$80,$80,$00
    .byte $80,$80,$40,$40,$40,$80,$80,$00,$80,$80,$40,$40,$40,$80,$80,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

font_data:
    .byte $0e,$02,$0e,$0a,$0a        ; ; "A"
    .byte $0c,$02,$0c,$0a,$0c        ; ; "B"
    .byte $0e,$02,$08,$0a,$0e        ; ; "C"
    .byte $0c,$02,$0a,$0a,$0c        ; ; "D"
    .byte $0e,$08,$0e,$08,$0e        ; ; "E"
    .byte $0e,$00,$0c,$08,$08        ; ; "F"
    .byte $0e,$08,$0a,$0a,$0e        ; ; "G"
    .byte $0a,$0a,$0e,$0a,$0a        ; ; "H"
    .byte $0e,$00,$04,$04,$0e        ; ; "I"
    .byte $0e,$00,$04,$04,$0c        ; ; "J"
    .byte $0a,$0a,$0c,$0a,$0a        ; ; "K"
    .byte $08,$08,$08,$0a,$0e        ; ; "L"
    .byte $0a,$0e,$0a,$0a,$0a        ; ; "M"
    .byte $0c,$02,$0a,$0a,$0a        ; ; "N"
    .byte $0e,$02,$0a,$0a,$0e        ; ; "O"
    .byte $0e,$02,$0e,$08,$08        ; ; "P"
    .byte $0e,$02,$0a,$08,$0f        ; ; "Q"
    .byte $0e,$02,$0e,$0c,$0a        ; ; "R"
    .byte $0e,$08,$0e,$02,$0e        ; ; "S"
    .byte $0e,$00,$04,$04,$04        ; ; "T"
    .byte $0a,$0a,$0a,$0a,$0e        ; ; "U"
    .byte $0a,$0a,$0a,$0a,$04        ; ; "V"
    .byte $0a,$0a,$0a,$0e,$0a        ; ; "W"
    .byte $0a,$0a,$04,$0a,$0a        ; ; "X"
    .byte $0a,$0a,$04,$04,$04        ; ; "Y"
    .byte $0e,$02,$04,$08,$0e        ; ; "Z"
    .byte $0e,$02,$0a,$0a,$0e        ; ; "0"
    .byte $04,$0c,$04,$04,$0e        ; ; "1"
    .byte $0e,$02,$0e,$08,$0e        ; ; "2"
    .byte $0e,$02,$06,$02,$0e        ; ; "3"
    .byte $08,$08,$0a,$0e,$02        ; ; "4"
    .byte $0e,$08,$0e,$02,$0e        ; ; "5"
    .byte $0e,$08,$0e,$0a,$0e        ; ; "6"
    .byte $0e,$02,$02,$02,$02        ; ; "7"
    .byte $0e,$0a,$0e,$0a,$0e        ; ; "8"
    .byte $0e,$0a,$0e,$02,$0e        ; ; "9"

unused_5bb4:
    .byte " DESTROYED"               ; ; " DESTROYED"

unused_5bbe:
    .byte $00,$00

player_sprite_zero:
    .byte $00,$72,$00,$00,$b9,$80,$11,$dd,$80,$11,$dd,$80,$00,$dc,$c4,$00
    .byte $30,$a2,$00,$f0,$22,$00,$00,$22,$00,$70,$22,$00,$f0,$82,$00,$a0
    .byte $83,$00,$20,$03,$22,$28,$0f,$ee,$60,$03,$34,$e0,$83,$34,$c0,$03
    .byte $00,$03,$0f,$00,$00,$03,$00,$f0,$81,$00,$07,$08,$00,$70,$80,$00
    .byte $70,$80,$00,$70,$00,$00,$e0,$00,$00,$e0,$00,$00,$e0,$00,$00,$f0
    .byte $00,$00,$70,$00,$00,$70,$00,$00,$07,$00,$00,$07,$00,$00,$0f,$00

player_sprite_one:
    .byte $00,$00,$00,$00,$72,$00,$00,$b9,$80,$11,$dd,$80,$11,$dd,$80,$00
    .byte $dd,$c4,$00,$30,$a2,$00,$f0,$22,$00,$00,$22,$22,$70,$22,$ee,$f0
    .byte $82,$06,$a0,$83,$06,$20,$03,$30,$60,$0f,$30,$e0,$03,$00,$d0,$83
    .byte $00,$00,$03,$00,$0f,$0f,$00,$00,$03,$00,$f0,$81,$00,$07,$08,$00
    .byte $70,$80,$00,$b0,$00,$10,$b0,$00,$30,$b0,$80,$30,$30,$80,$30,$90
    .byte $c0,$10,$0c,$c0,$00,$0c,$86,$01,$08,$06,$00,$00,$06,$00,$00,$0c

player_sprite_two:
    .byte $00,$00,$00,$00,$00,$00,$00,$72,$00,$00,$b9,$80,$11,$dd,$80,$11
    .byte $dd,$80,$00,$dd,$c4,$00,$30,$a2,$00,$f0,$22,$dd,$00,$22,$66,$70
    .byte $22,$06,$70,$82,$34,$30,$83,$30,$60,$03,$10,$e0,$0f,$00,$c0,$03
    .byte $00,$30,$83,$00,$00,$03,$00,$0f,$0f,$00,$00,$03,$00,$f0,$81,$00
    .byte $07,$08,$00,$70,$80,$00,$70,$00,$00,$b0,$c3,$10,$b0,$c3,$10,$d0
    .byte $c3,$30,$90,$c3,$38,$00,$01,$3c,$00,$01,$0e,$00,$00,$06,$00,$00

player_sprite_three:
    .byte $00,$00,$00,$00,$72,$00,$00,$b9,$80,$11,$dd,$80,$11,$dd,$80,$00
    .byte $dd,$c4,$00,$30,$a2,$00,$f0,$22,$00,$00,$22,$00,$70,$22,$00,$f0
    .byte $82,$02,$a0,$83,$03,$20,$03,$12,$38,$0f,$10,$10,$03,$00,$b8,$03
    .byte $11,$e8,$03,$33,$48,$0f,$23,$08,$03,$00,$70,$81,$00,$07,$08,$00
    .byte $70,$80,$00,$f0,$80,$10,$f0,$00,$30,$c0,$00,$30,$80,$80,$30,$d0
    .byte $80,$10,$0c,$c0,$00,$0c,$86,$00,$0c,$06,$01,$08,$0c,$00,$00,$00

player_sprite_four:
    .byte $00,$00,$00,$00,$00,$00,$00,$72,$00,$00,$b9,$80,$11,$dd,$80,$11
    .byte $dd,$80,$00,$dd,$c4,$00,$30,$a2,$00,$f0,$22,$04,$00,$22,$06,$70
    .byte $22,$24,$f0,$82,$20,$e0,$83,$20,$30,$03,$00,$38,$83,$00,$10,$c1
    .byte $00,$e0,$c1,$00,$54,$83,$00,$fc,$07,$11,$ac,$03,$11,$1c,$81,$00
    .byte $03,$08,$00,$70,$80,$00,$f0,$00,$10,$f0,$00,$10,$e0,$43,$10,$80
    .byte $c3,$30,$90,$c3,$38,$00,$01,$3c,$00,$01,$0e,$00,$00,$06,$00,$00

skeleton_sprite_one:
    .byte $00,$11,$11,$00,$11,$00,$00,$11,$11,$22,$22,$22,$22,$44,$44,$00
    .byte $00,$00,$11,$11,$11,$00,$00,$00,$cc,$ee,$ee,$aa,$ee,$22,$dd,$00
    .byte $ff,$22,$ff,$22,$ff,$22,$77,$22,$55,$aa,$00,$11,$11,$88,$44,$cc
    .byte $00,$00,$00,$00,$00,$00,$cc,$22,$aa,$44,$cc,$88,$88,$00,$00,$00
    .byte $00,$88,$88,$00,$00,$88,$44,$cc
skeleton_sprite_three:
    .byte $66

    .byte $ff,$ff,$55,$ff,$66,$99,$55,$00,$00,$66,$aa,$44,$44,$77,$dd,$00
    .byte $00,$00,$00,$00,$00,$00,$00

tile_sprite_lift:
    .byte $f0,$f7,$83,$83,$c1,$60,$30,$10,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $f0,$fe,$3e,$3e,$3e,$10,$f0,$00,$72,$72,$72,$72,$31,$13,$00,$02
    .byte $12,$12,$47,$45,$44,$22,$32,$10,$30,$20,$44,$44,$44,$22,$32,$10
    .byte $f0,$f7,$83,$83,$83,$80,$f0,$00,$c0,$a0,$c0,$a0,$c0,$08,$08,$08
    .byte $08,$80,$c0,$40,$40,$80,$80,$00,$80,$80,$40,$40,$40,$80,$80,$00
    .byte $f0,$fe,$3e,$3e,$7c,$60,$c0,$80,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

tile_sprite_crane:
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$11,$33,$23,$23
    .byte $23,$01,$00,$00,$11,$11,$32,$32,$64,$64,$44,$44,$64,$64,$20,$30
    .byte $32,$22,$44,$44,$45,$03,$12,$12,$00,$01,$03,$00,$ff,$0e,$3f,$6e
    .byte $4c,$5d,$cc,$ec,$b0,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $80,$80,$40,$40,$40,$80,$80,$08,$08,$08,$08,$00,$af,$06,$83,$c0
    .byte $41,$40,$40,$c0,$90,$30,$10,$10,$00,$00,$00,$00,$00,$00,$00,$10
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$08,$00,$08
    .byte $00,$08,$00,$00,$00,$00,$80,$80,$c0,$c0,$40,$40,$c0,$c0,$80,$80

flip_table:
    .byte $00,$08,$04,$0c,$02,$0a,$06,$0e,$01,$09,$05,$0d,$03,$0b,$07,$0f
    .byte $80,$88,$84,$8c,$82,$8a,$86,$8e,$81,$89,$85,$8d,$83,$8b,$87,$8f
    .byte $40,$48,$44,$4c,$42,$4a,$46,$4e,$41,$49,$45,$4d,$43,$4b,$47,$4f
    .byte $c0,$c8,$c4,$cc,$c2,$ca,$c6,$ce,$c1,$c9,$c5,$cd,$c3,$cb,$c7,$cf
    .byte $20,$28,$24,$2c,$22,$2a,$26,$2e,$21,$29,$25,$2d,$23,$2b,$27,$2f
    .byte $a0,$a8,$a4,$ac,$a2,$aa,$a6,$ae,$a1,$a9,$a5,$ad,$a3,$ab,$a7,$af
    .byte $60,$68,$64,$6c,$62,$6a,$66,$6e,$61,$69,$65,$6d,$63,$6b,$67,$6f
    .byte $e0,$e8,$e4,$ec,$e2,$ea,$e6,$ee,$e1,$e9,$e5,$ed,$e3,$eb,$e7,$ef
    .byte $10,$18,$14,$1c,$12,$1a,$16,$1e,$11,$19,$15,$1d,$13,$1b,$17,$1f
    .byte $90,$98,$94,$9c,$92,$9a,$96,$9e,$91,$99,$95,$9d,$93,$9b,$97,$9f
    .byte $50,$58,$54,$5c,$52,$5a,$56,$5e,$51,$59,$55,$5d,$53,$5b,$57,$5f
    .byte $d0,$d8,$d4,$dc,$d2,$da,$d6,$de,$d1,$d9,$d5,$dd,$d3,$db,$d7,$df
    .byte $30,$38,$34,$3c,$32,$3a,$36,$3e,$31,$39,$35,$3d,$33,$3b,$37,$3f
    .byte $b0,$b8,$b4,$bc,$b2,$ba,$b6,$be,$b1,$b9,$b5,$bd,$b3,$bb,$b7,$bf
    .byte $70,$78,$74,$7c,$72,$7a,$76,$7e,$71,$79,$75,$7d,$73,$7b,$77,$7f
    .byte $f0,$f8,$f4,$fc,$f2,$fa,$f6,$fe,$f1,$f9,$f5,$fd,$f3,$fb,$f7,$ff

; &6d00 - &6d3f is moved to &03a0 - &03df at &7b98


.segment "D2_03A0"

objects_type_and_flags:
    .byte $10,$a0,$10,$00            ; ; level &00
    .byte $00,$10,$00,$c0            ; ; level &01
    .byte $30,$10,$b0,$20            ; ; level &02
    .byte $20,$10,$00,$00            ; ; level &03
    .byte $40,$00,$50,$a0            ; ; level &04
    .byte $90,$00,$00,$70            ; ; level &05
    .byte $d0,$30,$e0,$10            ; ; level &06
    .byte $20,$40,$00,$00            ; ; level &07
    .byte $00,$f0,$a0,$10            ; ; level &08
    .byte $80,$80,$00,$10            ; ; level &09
    .byte $60,$90,$00,$a0            ; ; level &0a
    .byte $10,$10,$10,$10            ; ; level &0b

object_sprite_remote_activator:
    .byte $22,$22,$22,$22,$22,$22,$0f,$49,$49,$49,$09,$0f,$09,$0f,$09,$0f

; &6d40 - &6d7f is moved to &0180 - &01bf at &7b9e


.segment "D2_0180"

tile_sprite_rope:
    .byte $09,$0f,$0f,$06,$09,$0f,$0f,$06,$09,$0f,$0f,$06,$09,$0f,$0f,$06
    .byte $09,$0f,$0f,$06,$09,$0f,$0f,$06,$09,$0f,$0f,$06,$09,$0f,$0f,$06
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

; &6d80 - &6d9f is moved to &0380 - &039f at &7bad


.segment "D2_0380"

object_sprite_spanner:
    .byte $c0,$73,$70,$c0,$30,$ec,$e0,$30

map_sprite_enemy:
    .byte $04,$06,$44,$66,$66,$44,$44,$06

unused_0390:
    .byte "     FIRESTAR"            ; ; "     FIRESTAR"

unused_039d:
    .byte $80,$00,$00

; &6da0 - &6dff is moved to &0300 - &035f at &7bd4


.segment "D2_0300"

jet_pack_text:
    .byte $1f,$08,$06                ; ; TAB(&08, &06)
    .byte $4a,$45,$54,$20,$50,$41,$43,$4b,$20,$43,$4f,$4d,$50,$55,$54,$45 ; ; "JET PACK COMPUTER"
    .byte $52
    .byte $1f,$0e,$0d                ; ; TAB(&0e, &0d)
    .byte "FUEL"                     ; ; "FUEL"
    .byte $1f,$09,$13                ; ; TAB(&09, &13)
    .byte $42,$4c,$41,$53,$54,$45,$52,$20,$45,$4e,$45,$52,$47,$59 ; ; "BLASTER"
    .byte $1f,$0a,$1b                ; ; TAB(&0a, &1b)
    .byte "SPACE TO EXIT"            ; ; "SPACE TO EXIT"

unused_033c:
    .byte $00

pillars_x:
    .byte $2d,$2b,$07,$05,$03,$2d,$29

;      l px  x  y
gargoyle_locations:
    .byte $04,$14,$05,$01
    .byte $04,$1c,$07,$01
    .byte $04,$b0,$2c,$03
    .byte $04,$c0,$30,$03
    .byte $04,$b8,$2e,$02
    .byte $05,$d8,$36,$03
    .byte $05,$e8,$3a,$03

; &6e00 - &7aff is moved to &0400 - &10ff at &7b65


.segment "D2_0400"

title_screen_tune_data:
    .byte $ff,$06
    .byte $ff,$00
    .byte $ff,$00
    .byte $ff,$04
    .byte $ff,$00
    .byte $ff,$00
    .byte $ff,$06
    .byte $ff,$00
    .byte $ff,$00
    .byte $ff,$04
    .byte $ff,$04
    .byte $ff,$04
    .byte $ff,$06
    .byte $ff,$00
    .byte $ff,$00
    .byte $ff,$04
    .byte $ff,$00
    .byte $ff,$00
    .byte $ff,$06
    .byte $ff,$00
    .byte $ff,$00
    .byte $ff,$04
    .byte $ff,$05
    .byte $ff,$05
    .byte $ff,$06
    .byte $ff,$00
    .byte $ff,$00
    .byte $ff,$04
    .byte $ff,$00
    .byte $ff,$00
    .byte $ff,$06
    .byte $ff,$00
    .byte $ff,$00
    .byte $ff,$04
    .byte $ff,$04
    .byte $ff,$04
    .byte $ff,$06
    .byte $ff,$00
    .byte $ff,$00
    .byte $ff,$04
    .byte $ff,$00
    .byte $ff,$00
    .byte $ff,$06
    .byte $ff,$04
    .byte $ff,$04
    .byte $ff,$04
    .byte $ff,$04
    .byte $ff,$04
title_screen_tune_repeat:
    .byte $29,$06
    .byte $3d,$00
    .byte $45,$00
    .byte $51,$04
    .byte $65,$00
    .byte $51,$00
    .byte $59,$06
    .byte $45,$00
    .byte $51,$00
    .byte $3d,$04
    .byte $45,$04
    .byte $51,$04
    .byte $29,$06
    .byte $3d,$00
    .byte $45,$00
    .byte $51,$04
    .byte $65,$00
    .byte $51,$00
    .byte $59,$06
    .byte $45,$00
    .byte $51,$00
    .byte $3d,$04
    .byte $45,$05
    .byte $51,$05
    .byte $29,$06
    .byte $3d,$00
    .byte $45,$00
    .byte $51,$04
    .byte $65,$00
    .byte $51,$00
    .byte $59,$06
    .byte $45,$00
    .byte $51,$00
    .byte $3d,$04
    .byte $45,$04
    .byte $51,$04
    .byte $29,$06
    .byte $3d,$00
    .byte $45,$00
    .byte $51,$04
    .byte $65,$00
    .byte $51,$00
    .byte $59,$06
    .byte $45,$04
    .byte $51,$04
    .byte $3d,$04
    .byte $45,$04
    .byte $51,$04
    .byte $35,$06
    .byte $49,$00
    .byte $51,$00
    .byte $65,$00
    .byte $79,$00
    .byte $65,$00
    .byte $75,$06
    .byte $5d,$00
    .byte $65,$00
    .byte $49,$04
    .byte $51,$04
    .byte $5d,$04
    .byte $35,$06
    .byte $49,$00
    .byte $51,$00
    .byte $65,$00
    .byte $79,$00
    .byte $65,$00
    .byte $75,$06
    .byte $5d,$00
    .byte $65,$00
    .byte $49,$04
    .byte $51,$05
    .byte $5d,$05
    .byte $35,$06
    .byte $49,$00
    .byte $51,$00
    .byte $65,$00
    .byte $79,$00
    .byte $65,$00
    .byte $75,$06
    .byte $5d,$00
    .byte $65,$00
    .byte $49,$04
    .byte $51,$04
    .byte $5d,$04
    .byte $35,$06
    .byte $49,$00
    .byte $51,$00
    .byte $65,$04
    .byte $79,$04
    .byte $65,$04
    .byte $75,$00
    .byte $5d,$04
    .byte $65,$00
    .byte $49,$04
    .byte $51,$00
    .byte $5d,$04

level_tiles_translation_table:
    .byte $00                        ; ; &00 &0 : TILE_SPACE  # Used for Surface Defence
    .byte $02                        ; ; &1 : TILE_LIFT_TOP
    .byte $03                        ; ; &2 : TILE_LIFT_BOTTOM
    .byte $15                        ; ; &3 : TILE_CHAIN
    .byte $0a                        ; ; &4 : TILE_SURFACE_WALL_TOP_LEFT
    .byte $0b                        ; ; &5 : TILE_SURFACE_WALL_BOTTOM_LEFT
    .byte $0c                        ; ; &6 : TILE_SURFACE_WALL_TOP_RIGHT
    .byte $0d                        ; ; &7 : TILE_SURFACE_WALL_BOTTOM_RIGHT
    .byte $11                        ; ; &8 : TILE_SURFACE_WALL_TOP
    .byte $10                        ; ; &9 : TILE_SURFACE_WALL_LEFT
    .byte $0f                        ; ; &a : TILE_SURFACE_WALL_RIGHT
    .byte $0e                        ; ; &b : TILE_SURFACE_WALL
    .byte $16                        ; ; &c : TILE_ROPE
    .byte $14                        ; ; &d : TILE_PLATFORM_BOTTOM
    .byte $13                        ; ; &e : TILE_PLATFORM_TOP
    .byte $12                        ; ; &f : TILE_SURFACE_WALL_BOTTOM

    .byte $00                        ; ; &10 &0 : TILE_SPACE  # Used for Ancient Shrine
    .byte $02                        ; ; &1 : TILE_LIFT_TOP
    .byte $03                        ; ; &2 : TILE_LIFT_BOTTOM
    .byte $15                        ; ; &3 : TILE_CHAIN
    .byte $27                        ; ; &4 : TILE_PILLAR_BOTTOM
    .byte $26                        ; ; &5 : TILE_GARGOYLE_LEFT
    .byte $25                        ; ; &6 : TILE_GARGOYLE_RIGHT
    .byte $24                        ; ; &7 : TILE_SHRINE_WALL
    .byte $2d                        ; ; &8 : TILE_CHANDELIER
    .byte $2a                        ; ; &9 : TILE_SHRINE_WALL_TOP_RIGHT
    .byte $29                        ; ; &a : TILE_SHRINE_WALL_TOP_LEFT
    .byte $28                        ; ; &b : TILE_PILLAR_TOP
    .byte $2c                        ; ; &c : TILE_SHRINE_WALL_BOTTOM_RIGHT
    .byte $2b                        ; ; &d : TILE_SHRINE_WALL_BOTTOM_LEFT
    .byte $21                        ; ; &e : TILE_BARREL
    .byte $16                        ; ; &f : TILE_ROPE

    .byte $00                        ; ; &20 &0 : TILE_SPACE  # Used for Crew's Quarters
    .byte $02                        ; ; &1 : TILE_LIFT_TOP
    .byte $03                        ; ; &2 : TILE_LIFT_BOTTOM
    .byte $15                        ; ; &3 : TILE_CHAIN
    .byte $1f                        ; ; &4 : TILE_CHAIR_LEFT
    .byte $1e                        ; ; &5 : TILE_CHAIR_RIGHT
    .byte $1d                        ; ; &6 : TILE_TABLE_RIGHT
    .byte $1c                        ; ; &7 : TILE_TABLE_LEFT
    .byte $08                        ; ; &8 : TILE_PIPE_VERTICAL
    .byte $22                        ; ; &9 : TILE_QUARTERS_WALL_INVERTED
    .byte $17                        ; ; &a : TILE_QUARTERS_WALL
    .byte $20                        ; ; &b : TILE_LAMP
    .byte $16                        ; ; &c : TILE_ROPE
    .byte $07                        ; ; &d : TILE_PIPE_TOP_RIGHT
    .byte $05                        ; ; &e : TILE_PIPE_TOP_LEFT
    .byte $09                        ; ; &f : TILE_PIPE_HORIZONTAL

    .byte $00                        ; ; &30 &0 : TILE_SPACE  # Used for Missile Factory
    .byte $02                        ; ; &1 : TILE_LIFT_TOP
    .byte $03                        ; ; &2 : TILE_LIFT_BOTTOM
    .byte $15                        ; ; &3 : TILE_CHAIN
    .byte $31                        ; ; &4 : TILE_MISSILE_TAIL_RIGHT
    .byte $30                        ; ; &5 : TILE_MISSILE_TAIL_LEFT
    .byte $2f                        ; ; &6 : TILE_MISSILE_NOSE_RIGHT
    .byte $2e                        ; ; &7 : TILE_MISSILE_NOSE_LEFT
    .byte $32                        ; ; &8 : TILE_MISSILE_BODY
    .byte $33                        ; ; &9 : TILE_FACTORY_WALL
    .byte $21                        ; ; &a : TILE_BARREL
    .byte $16                        ; ; &b : TILE_ROPE
    .byte $14                        ; ; &c : TILE_PLATFORM_BOTTOM
    .byte $13                        ; ; &d : TILE_PLATFORM_TOP
    .byte $01                        ; ; &e : TILE_CRANE
    .byte $23                        ; ; &f : TILE_COMPUTER

    .byte $00                        ; ; &40 &0 ; TILE_SPACE  # Used for title and status screen
    .byte $17                        ; ; &1 ; TILE_QUARTERS_WALL
    .byte $18                        ; ; &2 ; TILE_QUARTERS_WALL_TOP_RIGHT
    .byte $19                        ; ; &3 ; TILE_QUARTERS_WALL_BOTTOM_RIGHT
    .byte $1a                        ; ; &4 ; TILE_QUARTERS_WALL_TOP_LEFT
    .byte $1b                        ; ; &5 ; TILE_QUARTERS_WALL_BOTTOM_LEFT
    .byte $38                        ; ; &6 ; TILE_SPACE_TWO  # Used for middle of status screen
    .byte $00                        ; ; &7 ; TILE_SPACE  # Unused

scores_for_collecting_objects:       ; # Overflows into kneeling_check_offsets
    .byte $01                        ; ; &00 : OBJECT_PASSCARD  # 2000 points
    .byte $01                        ; ; &01 : OBJECT_ENERGY_CELL  # 2000 points
    .byte $05                        ; ; &02 : OBJECT_JET_PACK  # 6000 points
    .byte $05                        ; ; &03 : OBJECT_CRATE  # 6000 points
    .byte $04                        ; ; &04 : OBJECT_KEY  # 5000 points
    .byte $06                        ; ; &05 : OBJECT_SPRING  # 7000 points
    .byte $02                        ; ; &06 : OBJECT_FUEL  # 3000 points
    .byte $03                        ; ; &07 : OBJECT_SWITCH  # 4000 points
;          &08 : OBJECT_BUTTON                                      # 1000 points
;          &09 : OBJECT_SPANNER                                     # 2000 points
;          &0a : OBJECT_PLUTONIUM                                   # 1000 points
;          &0b : OBJECT_NAVIGATION_ROM                              # 2000 points
;          &0c : OBJECT_MICROFILM                                   # 1000 points
;          &0d : OBJECT_HERBERT_DROID                               # 3000 points
;          &0e : OBJECT_REMOTE_ACTIVATOR                            # 1000 points
;          &0f : OBJECT_DISK                                        # 1000 points

kneeling_check_offsets:
    .byte $00,$01                    ; ; &0100 = (0, 1)
    .byte $10,$01                    ; ; &0110 = (2, 1)
    .byte $10,$02                    ; ; &0210 = (2, 2)
    .byte $10,$00                    ; ; &0010 = (2, 0)
    .byte $00,$00                    ; ; &0000 = (0, 0)
    .byte $08,$00                    ; ; &0008 = (1, 0)
    .byte $00,$02                    ; ; &0200 = (2, 0)
    .byte $10,$02                    ; ; &0210 = (2, 2)

game_over_tune_data:
    .byte $29,$00
    .byte $ff,$00
    .byte $ff,$00
    .byte $29,$00
    .byte $29,$00
    .byte $29,$00
    .byte $29,$00
    .byte $ff,$00
    .byte $ff,$00
    .byte $29,$00
    .byte $29,$00
    .byte $29,$00
    .byte $3d,$00
    .byte $ff,$00
    .byte $ff,$00
    .byte $3d,$00
    .byte $3d,$00
    .byte $3d,$00
    .byte $51,$00
    .byte $ff,$00
    .byte $ff,$00
    .byte $51,$00
    .byte $51,$00
    .byte $51,$00
    .byte $65,$00
    .byte $65,$00
    .byte $65,$00
    .byte $65,$00
    .byte $65,$00
    .byte $65,$00
    .byte $79,$00
    .byte $79,$00
    .byte $79,$00
    .byte $79,$04
    .byte $79,$00
    .byte $79,$04
    .byte $75,$00
    .byte $75,$04
    .byte $75,$00
    .byte $75,$04
    .byte $75,$04
    .byte $75,$04
    .byte $75,$05
    .byte $75,$05
    .byte $75,$05
    .byte $75,$06
    .byte $75,$06
    .byte $75,$06

player_sprite_kneeling:
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $72,$00,$00,$b9,$80,$11,$dd,$80,$11,$dd,$80,$00,$dd,$c4,$00,$30
    .byte $a2,$00,$f0,$22,$00,$00,$22,$00,$70,$22,$00,$f0,$82,$00,$a0,$83
    .byte $00,$20,$03,$22,$28,$0f,$ee,$60,$03,$34,$e0,$83,$34,$c0,$03,$00
    .byte $01,$0f,$30,$80,$03,$70,$f0,$81,$70,$f0,$00,$60,$e0,$00,$60,$10
    .byte $00,$60,$30,$00,$60,$30,$03,$06,$30,$c3,$06,$30,$c3,$0e,$10,$c1

player_sprite_crawling_one:
    .byte $00,$31,$80,$00,$00,$00,$00,$00,$54,$c8,$00,$00,$00,$00,$00,$ee
    .byte $c9,$0f,$00,$00,$00,$00,$ee,$c9,$0f,$00,$00,$00,$00,$66,$eb,$0f
    .byte $08,$00,$00,$00,$10,$c1,$0f,$08,$00,$00,$00,$30,$80,$0a,$00,$00
    .byte $00,$00,$00,$70,$5a,$08,$00,$00,$00,$10,$30,$5a,$08,$00,$00,$00
    .byte $00,$d0,$5a,$48,$03,$06,$00,$10,$d0,$5a,$68,$43,$06,$22,$10,$d0
    .byte $5a,$78,$c3,$06,$ee,$30,$b0,$5a,$78,$c3,$06,$34,$f0,$70,$5a,$38
    .byte $c1,$02,$34,$e0,$b0,$5a,$10,$81,$02

player_sprite_crawling_zero:
    .byte $00,$30,$80,$00,$00,$00,$00,$00,$66,$c0,$00,$00,$00,$00,$00,$ff
    .byte $41,$0f,$00,$00,$00,$00,$ff,$41,$0f,$00,$00,$00,$00,$77,$63,$0f
    .byte $08,$00,$00,$00,$00,$c1,$0f,$08,$00,$00,$00,$70,$80,$0a,$00,$00
    .byte $00,$00,$00,$70,$5a,$08,$00,$00,$00,$10,$30,$5a,$08,$00,$00,$00
    .byte $20,$d0,$5a,$48,$01,$08,$00,$60,$d0,$5a,$68,$21,$08,$00,$72,$60
    .byte $5a,$78,$e1,$08,$00,$ee,$60,$5a,$78,$e1,$08,$78,$b4,$d0,$5a,$38
    .byte $e0,$08,$78,$34,$d0,$5a,$00,$c0,$08

player_sprite_climbing_one:
    .byte $09,$72,$00,$0e,$b9,$80,$79,$dd,$80,$71,$dd,$80,$38,$dd,$c4,$3c
    .byte $30,$a2,$1c,$b0,$22,$14,$80,$22,$08,$d0,$22,$0e,$d0,$82,$0e,$e0
    .byte $83,$06,$60,$03,$08,$09,$0f,$0e,$00,$03,$0e,$f0,$83,$06,$00,$03
    .byte $08,$0f,$0f,$0e,$00,$03,$0e,$f0,$81,$06,$0f,$08,$08,$70,$80,$0f
    .byte $70,$00,$0f,$70,$00,$06,$60,$00,$08,$e0,$00,$0e,$e0,$00,$0e,$c0
    .byte $00,$14,$c0,$00,$18,$80,$00,$1a,$80,$00,$0b,$80,$00,$07,$00,$00

player_sprite_climbing_zero:
    .byte $08,$72,$00,$0e,$b9,$80,$1f,$dd,$80,$17,$dd,$80,$08,$dd,$c4,$4a
    .byte $30,$a2,$68,$f0,$22,$70,$00,$22,$38,$b0,$22,$1c,$d0,$82,$0e,$e0
    .byte $83,$06,$60,$03,$08,$09,$0f,$0e,$00,$03,$0e,$f0,$83,$06,$00,$03
    .byte $08,$0f,$0f,$0e,$00,$03,$3c,$b0,$81,$70,$d0,$08,$78,$f0,$80,$78
    .byte $f0,$80,$68,$f0,$00,$60,$00,$00,$68,$00,$00,$06,$00,$00,$0e,$00
    .byte $00,$0e,$00,$00,$01,$00,$00,$0f,$00,$00,$0f,$00,$00,$06,$00,$00

sprite_rope_section:
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$09,$0f,$0f,$06,$00,$00,$00,$00
    .byte $00,$00,$00,$00

player_points_buffer:
    .byte $00,$00,$32,$22,$44

unused_07eb:
    .byte $44,$44,$22,$32,$10

score:
    .byte $00,$00,$00,$00,$00,$00,$00,$00

unused_07f8:
    .byte $00,$00

blasters_buffer:
    .byte $00,$00,$00,$00,$00,$00

os_sound_workspace:
    .byte $0f,$0f,$0f,$0f,$00,$00,$00,$00,$c0,$c0,$c0,$c0,$04,$04,$04,$04
    .byte $0f,$0f,$0f,$64,$25,$25,$25,$ff,$ee,$ae,$ae,$00,$00,$00,$00,$00
    .byte $05,$05,$05,$05,$0f,$0f,$0f,$ff,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$64,$58,$98,$98,$00,$ff,$ff,$c1,$00,$00,$ef,$00,$0d
    .byte $06,$03,$f8,$00,$03,$f8,$00,$03,$18,$04,$03,$f8,$00,$03,$0f,$18
    .byte $00,$03,$f8,$00,$03,$f8,$00,$03,$f8,$00,$03,$f8,$00,$03,$0f,$f8
    .byte $00,$03,$f8,$00,$03,$f8,$00,$03,$f8,$00,$03,$f8,$00,$03,$0f,$f8
    .byte $64,$06,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$90

sprite_bar_left_end:
    .byte $11,$22,$22,$22,$22,$22,$22,$22,$22,$11

sprite_bar_full:
    .byte $ff,$00,$0f,$0f,$0f,$0f,$0f,$0f,$00,$ff

sprite_bar_empty:
    .byte $ff,$00,$00,$00,$00,$00,$00,$00,$00,$ff

sprite_bar_right_end:
    .byte $88,$44,$44,$44,$44,$44,$44,$44,$44,$88

object_sprite_passcard:
    .byte $ff,$f8,$cb,$da,$cb,$da,$da,$70,$ff,$f0,$78,$78,$4b,$f0,$f0,$f0
    .byte $ee,$f0,$78,$3c,$1e,$3c,$78,$f0

os_envelope_storage:
    .byte $01,$00,$00,$00,$01,$01,$01,$5a,$fc,$ff,$ff,$7e,$46,$00,$00,$00 ; ; 1
    .byte $01,$fc,$fd,$fe,$0c,$0c,$0c,$7e,$fc,$fe,$ff,$7e,$56,$00,$00,$00 ; ; 2
    .byte $01,$fe,$00,$00,$ff,$00,$00,$00,$00,$00,$9c,$00,$00,$00,$00,$00 ; ; 3
    .byte $01,$00,$00,$00,$01,$01,$01,$3c,$fb,$fb,$fb,$78,$3c,$00,$00,$00 ; ; 4

object_sprite_jet_pack:
    .byte $77,$ee,$44,$44,$66,$77,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$ff,$00,$03,$07,$07,$0f,$0e,$11,$32,$74,$44
    .byte $07,$0f,$0f,$09,$67,$cd,$67,$09,$0f,$0f,$0f,$06,$80,$c0,$e0,$20

unused_0930:
    .byte "LADE"                     ; ; "LADE"

;     addr   h  w
object_types_sprite_address_and_sizes:
    .byte $a8,$08,$08,$03            ; ; &08a8 = object_sprite_passcard
    .byte $40,$0c,$08,$03            ; ; &0c40 = object_sprite_energy_cell
    .byte $00,$09,$10,$03            ; ; &0900 = object_sprite_jet_pack
    .byte $d0,$43,$10,$03            ; ; &43d0 = object_sprite_crate
    .byte $00,$49,$08,$03            ; ; &4900 = object_sprite_key
    .byte $ba,$43,$0b,$02            ; ; &43ba = object_sprite_spring
    .byte $b4,$4c,$08,$03            ; ; &4cb4 = object_sprite_fuel
    .byte $ac,$4c,$04,$01            ; ; &4cac = object_sprite_switch
    .byte $b0,$4c,$04,$01            ; ; &4cb0 = object_sprite_button
    .byte $80,$03,$04,$02            ; ; &0380 = object_sprite_spanner
    .byte $9c,$4c,$08,$02            ; ; &4c9c = object_sprite_plutonium
    .byte $e8,$4b,$08,$03            ; ; &4be8 = object_sprite_navigation_rom
    .byte $18,$49,$04,$02            ; ; &4918 = object_sprite_microfilm
    .byte $00,$44,$10,$02            ; ; &4400 = object_sprite_herbert_droid
    .byte $d0,$03,$10,$01            ; ; &03d0 = object_sprite_remote_activator
    .byte $41,$50,$0e,$02            ; ; &5041 = object_sprite_disk

;      0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
font_offsets:
    .byte $82,$87,$8c,$91,$96,$9b,$a0,$a5,$aa,$af,$00,$00,$00,$00,$00,$00 ; ; &30
    .byte $00,$00,$05,$0a,$0f,$14,$19,$1e,$23,$28,$2d,$32,$37,$3c,$41,$46 ; ; &40
    .byte $4b,$50,$55,$5a,$5f,$64,$69,$6e,$73,$78,$7d,$00 ; ; &50

objects_x:
    .byte $07,$0a,$ff,$e2            ; ; level &00
    .byte $ff,$d0,$31,$38            ; ; level &01
    .byte $25,$64,$b8,$d6            ; ; level &02
    .byte $9f,$a4,$53,$0d            ; ; level &03
    .byte $99,$cc,$6c,$87            ; ; level &04
    .byte $b7,$70,$30,$46            ; ; level &05
    .byte $b5,$94,$88,$83            ; ; level &06
    .byte $da,$91,$c6,$00            ; ; level &07
    .byte $dc,$09,$4c,$a8            ; ; level &08
    .byte $aa,$ba,$7d,$40            ; ; level &09
    .byte $dc,$d0,$62,$c4            ; ; level &0a
    .byte $28,$ff,$ff,$ff            ; ; level &0b

objects_y:
    .byte $78,$c8,$38,$98            ; ; level &00
    .byte $00,$d8,$98,$3c            ; ; level &01
    .byte $c0,$48,$d8,$60            ; ; level &02
    .byte $50,$d8,$d8,$b8            ; ; level &03
    .byte $b8,$78,$95,$98            ; ; level &04
    .byte $7c,$78,$78,$90            ; ; level &05
    .byte $90,$d0,$90,$d8            ; ; level &06
    .byte $90,$40,$38,$00            ; ; level &07
    .byte $d8,$52,$38,$58            ; ; level &08
    .byte $50,$50,$38,$78            ; ; level &09
    .byte $d8,$3c,$48,$78            ; ; level &0a
    .byte $38,$00,$00,$00            ; ; level &0b

enemy_sprite_zero:
    .byte $00,$00,$00,$11,$00,$11,$00,$00,$00,$00,$00,$00,$20,$e0,$37,$37
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $77,$9f,$5b,$ff,$33,$ff,$ff,$00,$77,$ff,$aa,$22,$a2,$66,$ee,$cc
    .byte $30,$00,$ff,$07,$77,$77,$ff,$ee,$ee,$ee,$ff,$77,$77,$07,$07,$0f
    .byte $00,$89,$99,$99,$99,$99,$11,$00,$10,$b8,$b8,$30,$d0,$30,$b8,$30
    .byte $d0,$30,$b8,$08,$88,$88,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

enemy_sprite_one:
    .byte $00,$00,$00,$00,$11,$00,$11,$00,$00,$20,$e0,$06,$06,$33,$33,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$11,$33,$33,$33,$11,$00,$01,$00,$00
    .byte $00,$77,$9f,$5b,$ff,$33,$ff,$ff,$00,$77,$ff,$aa,$22,$66,$ee,$dd
    .byte $00,$f0,$00,$ff,$07,$77,$bb,$bb,$bb,$33,$99,$1d,$0c,$08,$00,$00
    .byte $00,$00,$89,$99,$99,$99,$99,$11,$00,$10,$b8,$b8,$30,$d0,$30,$b8
    .byte $30,$d0,$30,$88,$08,$88,$00,$00,$00,$88,$88,$cc,$8e,$06,$06,$0c

enemy_sprite_two:
    .byte $00,$00,$00,$00,$00,$11,$00,$11,$00,$d0,$60,$06,$37,$33,$11,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$11,$11,$33,$3b,$3f,$0e,$06
    .byte $00,$00,$77,$9f,$5b,$ff,$33,$ff,$ff,$00,$77,$77,$33,$66,$ee,$cc
    .byte $33,$00,$f0,$00,$ff,$07,$77,$77,$bb,$bb,$dd,$99,$00,$00,$00,$00
    .byte $00,$00,$00,$89,$99,$99,$99,$99,$11,$11,$00,$98,$b8,$30,$d0,$30
    .byte $b8,$30,$d0,$30,$88,$08,$88,$00,$cf,$cf,$cf,$cf,$01,$01,$00,$00

enemy_sprite_three:
    .byte $00,$00,$00,$00,$11,$00,$11,$00,$00,$00,$00,$02,$03,$13,$11,$00
    .byte $10,$30,$21,$00,$00,$00,$00,$11,$33,$33,$33,$11,$00,$00,$01,$00
    .byte $00,$77,$9f,$5b,$ff,$33,$ff,$ff,$00,$77,$ff,$aa,$22,$b3,$11,$b3
    .byte $e6,$4c,$08,$77,$07,$77,$ff,$ff,$cc,$88,$dd,$0c,$0c,$0c,$08,$00
    .byte $00,$00,$89,$99,$99,$99,$99,$11,$11,$00,$98,$b8,$30,$d0,$30,$30
    .byte $30,$d0,$30,$88,$08,$88,$88,$00,$00,$88,$88,$cc,$8e,$06,$0c,$00

enemy_sprite_four:
    .byte $00,$00,$00,$00,$00,$11,$00,$11,$00,$04,$06,$26,$22,$22,$00,$00
    .byte $00,$00,$00,$10,$10,$00,$00,$00,$11,$11,$11,$33,$3b,$3f,$0e,$06
    .byte $00,$00,$77,$9f,$5b,$ff,$33,$ff,$ff,$00,$77,$ff,$ee,$33,$b3,$11
    .byte $ee,$51,$f3,$a6,$1d,$03,$77,$ff,$ff,$ee,$88,$99,$00,$00,$00,$00
    .byte $00,$00,$00,$89,$99,$99,$99,$99,$11,$11,$00,$98,$b8,$30,$98,$dc
    .byte $dc,$b8,$50,$30,$88,$08,$88,$00,$00,$47,$cf,$cf,$01,$01,$00,$00

skeleton_sprite_zero:
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$11,$11,$11,$11,$11,$11,$22
    .byte $22,$22,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $33,$77,$77,$22,$77,$00,$33,$00,$ff,$11,$77,$11,$77,$11,$77,$11
    .byte $33,$11,$33,$66,$55,$44,$44,$44,$88,$88,$88,$44,$44,$44,$44,$cc
    .byte $00,$88,$88,$88,$88,$88,$00,$00,$ee,$11,$dd,$11,$dd,$11,$dd,$11
    .byte $aa,$22,$aa,$cc,$44,$44,$44,$44,$88,$88,$88,$88,$44,$44,$44,$cc

object_sprite_energy_cell:
    .byte $07,$8f,$8f,$bc,$8f,$8f,$8f,$07,$0f,$1e,$1e,$3c,$1e,$1e,$0f,$0f
    .byte $0c,$2e,$2e,$b7,$3f,$2e,$2e,$0c

sprite_stereo:
    .byte $00,$00,$00,$61,$90,$f0,$90,$61,$00,$ff,$99,$0f,$0f,$6f,$6f,$0f
    .byte $22,$22,$22,$68,$90,$f0,$90,$68

sprite_notes:
    .byte $00,$00,$44,$44,$55,$44,$88,$ff,$99,$99,$99,$22,$00,$00

unused_0c7e:
    .byte $00,$00

tile_sprite_quarters_wall_corner:
    .byte $80,$80,$c0,$c0,$a0,$a0,$90,$90,$80,$80,$90,$90,$90,$90,$90,$90
    .byte $90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$91,$b3,$f7,$f0,$f0
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$80,$80,$40,$40,$a0,$a0,$90,$90
    .byte $a0,$a0,$b0,$b0,$b0,$b3,$f7,$f0,$f0,$f0,$f0,$ff,$ff,$ff,$f0,$f0
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $80,$80,$40,$40,$a0,$a8,$dc,$d0,$e0,$e0,$f0,$ff,$ff,$ff,$f0,$f0
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$80,$80,$40,$40,$a8,$a8,$f0,$f0

tile_sprite_quarters_wall:
    .byte $f0,$f0,$80,$80,$80,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90
    .byte $90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$91,$b3,$f7,$f0,$f0
    .byte $f0,$f0,$00,$00,$00,$f0,$f0,$f0,$f0,$80,$80,$b0,$b0,$b0,$b0,$b0
    .byte $b0,$b0,$b0,$b0,$b0,$b3,$f7,$f0,$f0,$f0,$f0,$ff,$ff,$ff,$f0,$f0
    .byte $f0,$f0,$00,$00,$00,$f0,$f0,$f0,$f0,$10,$32,$f2,$f2,$f2,$f2,$f2
    .byte $f2,$f2,$f2,$f2,$f2,$fe,$fe,$f0,$f0,$f0,$f0,$ff,$ff,$ff,$f0,$f0
    .byte $f0,$f0,$10,$32,$76,$f6,$f6,$f6,$f6,$f6,$f6,$f6,$f6,$f6,$f6,$f6
    .byte $f6,$f6,$f6,$f6,$f6,$f6,$f6,$f6,$f6,$f6,$f6,$fe,$fe,$fe,$f0,$f0

tile_sprite_table:
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$07,$7f,$0f,$07,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$0f,$ff,$0f,$0f,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$0f,$ff,$0f,$0f,$00,$11,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$10,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$0f,$ff,$0f,$0f,$00,$ff,$ff,$77
    .byte $00,$03,$03,$03,$03,$03,$03,$03,$00,$70,$70,$70,$f0,$f0,$f0,$00

tile_sprite_chair:
    .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
    .byte $03,$03,$03,$03,$03,$01,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$08,$08,$0f,$05,$0f,$00,$33,$11,$11,$11,$13,$13,$27,$4f
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$0f,$05,$0f,$00,$0c,$08,$08,$08,$0c,$0c,$0e,$0f
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$0c,$06,$0e,$06,$02,$02,$02,$02,$02,$00,$00,$00

tile_sprite_lamp:
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$10,$10,$31,$31,$72,$72,$f4,$f3,$70,$00,$00,$00,$00
    .byte $32,$22,$44,$44,$45,$03,$12,$12,$02,$00,$01,$03,$03,$01,$40,$70
    .byte $70,$f4,$f4,$f8,$f8,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$00,$33,$11
    .byte $80,$80,$40,$40,$40,$80,$80,$08,$08,$08,$08,$08,$08,$00,$40,$c0
    .byte $a0,$c0,$a0,$d0,$e0,$d0,$e0,$f0,$e0,$f0,$e0,$d0,$a0,$00,$88,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$80,$00,$80,$40,$80,$40,$a0,$40,$00,$00,$00,$00

tile_sprite_barrel:
    .byte $07,$00,$00,$01,$33,$23,$33,$23,$33,$23,$33,$23,$33,$23,$33,$00
    .byte $07,$00,$00,$01,$33,$23,$33,$23,$33,$23,$33,$23,$33,$33,$00,$07
    .byte $0f,$00,$23,$8f,$2f,$8f,$4f,$8f,$2f,$8f,$4f,$8f,$2f,$8f,$ef,$00
    .byte $0f,$00,$23,$8f,$2f,$8f,$4f,$8f,$2f,$8f,$4f,$8f,$2f,$cf,$00,$0f
    .byte $0f,$00,$08,$0e,$0d,$0f,$0e,$0f,$0d,$0f,$0e,$0f,$0d,$0f,$8e,$00
    .byte $0f,$00,$08,$0e,$0d,$0f,$0e,$0f,$0d,$0f,$0e,$0f,$0d,$0f,$00,$0f
    .byte $0f,$00,$00,$00,$08,$04,$08,$04,$0a,$04,$08,$04,$0a,$04,$08,$00
    .byte $0f,$00,$00,$00,$08,$04,$0a,$04,$08,$04,$0a,$04,$08,$04,$00,$0f

tile_sprites_addresses_table:
    .byte $00,$01                    ; ; &00 (TILE_SPACE)                      : &0100 (tile_sprite_space)
    .byte $80,$5e                    ; ; &01 (TILE_CRANE)                      : &5e80 (tile_sprite_crane)
    .byte $00,$5e                    ; ; &02 (TILE_LIFT_TOP)                   : &5e00 (tile_sprite_lift)
    .byte $01,$5e                    ; ; &03 (TILE_LIFT_BOTTOM)                : &5e00 (tile_sprite_lift)                      FLIP_VERTICALLY
    .byte $00,$5a                    ; ; &04 (TILE_PIPE_BOTTOM_LEFT)           : &5a00 (tile_sprite_pipe_corner)
    .byte $01,$5a                    ; ; &05 (TILE_PIPE_TOP_LEFT)              : &5a00 (tile_sprite_pipe_corner)               FLIP_VERTICALLY
    .byte $02,$5a                    ; ; &06 (TILE_PIPE_BOTTOM_RIGHT)          : &5a00 (tile_sprite_pipe_corner)               FLIP_HORIZONTALLY
    .byte $03,$5a                    ; ; &07 (TILE_PIPE_TOP_RIGHT)             : &5a00 (tile_sprite_pipe_corner)               FLIP_HORIZONTALLY_AND_VERTICALLY
    .byte $80,$59                    ; ; &08 (TILE_PIPE_VERTICAL)              : &5980 (tile_sprite_pipe_vertical)             mirrored
    .byte $00,$59                    ; ; &09 (TILE_PIPE_HORIZONTAL)            : &5900 (tile_sprite_pipe_horizontal)
    .byte $80,$58                    ; ; &0a (TILE_SURFACE_WALL_TOP_LEFT)      : &5880 (tile_sprite_surface_wall_corner)
    .byte $81,$58                    ; ; &0b (TILE_SURFACE_WALL_BOTTOM_LEFT)   : &5880 (tile_sprite_surface_wall_corner)       FLIP_VERTICALLY
    .byte $82,$58                    ; ; &0c (TILE_SURFACE_WALL_TOP_RIGHT)     : &5880 (tile_sprite_surface_wall_corner)       FLIP_HORIZONTALLY
    .byte $83,$58                    ; ; &0d (TILE_SURFACE_WALL_BOTTOM_RIGHT)  : &5880 (tile_sprite_surface_wall_corner)       FLIP_HORIZONTALLY_AND_VERTICALLY
    .byte $80,$46                    ; ; &0e (TILE_SURFACE_WALL)               : &4680 (tile_sprite_surface_wall_vertical)     mirrored
    .byte $80,$46                    ; ; &0f (TILE_SURFACE_WALL_RIGHT)         : &4680 (tile_sprite_surface_wall_vertical)
    .byte $82,$46                    ; ; &10 (TILE_SURFACE_WALL_LEFT)          : &4680 (tile_sprite_surface_wall_vertical)     FLIP_HORIZONTALLY
    .byte $40,$58                    ; ; &11 (TILE_SURFACE_WALL_TOP)           : &5840 (tile_sprite_surface_wall_horizontal)   mirrored
    .byte $41,$58                    ; ; &12 (TILE_SURFACE_WALL_BOTTOM)        : &5840 (tile_sprite_surface_wall_horizontal)   FLIP_VERTICALLY, mirrored
    .byte $00,$58                    ; ; &13 (TILE_PLATFORM_TOP)               : &5800 (tile_sprite_platform)                  mirrored
    .byte $01,$58                    ; ; &14 (TILE_PLATFORM_BOTTOM)            : &5800 (tile_sprite_platform)                  FLIP_VERTICALLY, mirrored
    .byte $80,$5a                    ; ; &15 (TILE_CHAIN)                      : &5a80 (tile_sprite_chain)
    .byte $42,$01                    ; ; &16 (TILE_ROPE)                       : &0140 (tile_sprite_rope - &40)                FLIP_HORIZONTALLY
    .byte $00,$0d                    ; ; &17 (TILE_QUARTERS_WALL)              : &0d00 (tile_sprite_quarters_wall)
    .byte $80,$0c                    ; ; &18 (TILE_QUARTERS_WALL_TOP_RIGHT)    : &0c80 (tile_sprite_quarters_wall_corner)
    .byte $81,$0c                    ; ; &19 (TILE_QUARTERS_WALL_BOTTOM_RIGHT) : &0c80 (tile_sprite_quarters_wall_corner)      FLIP_VERTICALLY
    .byte $82,$0c                    ; ; &1a (TILE_QUARTERS_WALL_TOP_LEFT)     : &0c80 (tile_sprite_quarters_wall_corner)      FLIP_HORIZONTALLY
    .byte $83,$0c                    ; ; &1b (TILE_QUARTERS_WALL_BOTTOM_LEFT)  : &0c80 (tile_sprite_quarters_wall_corner)      FLIP_HORIZONTALLY_AND_VERTICALLY
    .byte $80,$0d                    ; ; &1c (TILE_TABLE_LEFT)                 : &0d80 (tile_sprite_table)
    .byte $82,$0d                    ; ; &1d (TILE_TABLE_RIGHT)                : &0d80 (tile_sprite_table)                     FLIP_HORIZONTALLY
    .byte $00,$0e                    ; ; &1e (TILE_CHAIR_RIGHT)                : &0e00 (tile_sprite_chair)
    .byte $02,$0e                    ; ; &1f (TILE_CHAIR_LEFT)                 : &0e00 (tile_sprite_chair)                     FLIP_HORIZONTALLY
    .byte $80,$0e                    ; ; &20 (TILE_LAMP)                       : &0e80 (tile_sprite_lamp)
    .byte $00,$0f                    ; ; &21 (TILE_BARREL)                     : &0f00 (tile_sprite_barrel)
    .byte $03,$0d                    ; ; &22 (TILE_QUARTERS_WALL_INVERTED)     : &0d00 (tile_sprite_quarters_wall)             FLIP_HORIZONTALLY_AND_VERTICALLY
    .byte $c0,$59                    ; ; &23 (TILE_COMPUTER)                   : &59c0 (tile_sprite_computer)                  mirrored
    .byte $80,$49                    ; ; &24 (TILE_SHRINE_WALL)                : &4980 (tile_sprite_shrine_wall)
    .byte $80,$44                    ; ; &25 (TILE_GARGOYLE_RIGHT)             : &4480 (tile_sprite_gargoyle)
    .byte $82,$44                    ; ; &26 (TILE_GARGOYLE_LEFT)              : &4480 (tile_sprite_gargoyle)                  FLIP_HORIZONTALLY
    .byte $00,$4a                    ; ; &27 (TILE_PILLAR_BOTTOM)              : &4a00 (tile_sprite_pillar)
    .byte $01,$4a                    ; ; &28 (TILE_PILLAR_TOP)                 : &4a00 (tile_sprite_pillar)                    FLIP_VERTICALLY
    .byte $80,$4a                    ; ; &29 (TILE_SHRINE_WALL_TOP_LEFT)       : &4a80 (tile_sprite_shrine_wall_corner)
    .byte $82,$4a                    ; ; &2a (TILE_SHRINE_WALL_TOP_RIGHT)      : &4a80 (tile_sprite_shrine_wall_corner)        FLIP_HORIZONTALLY
    .byte $81,$4a                    ; ; &2b (TILE_SHRINE_WALL_BOTTOM_LEFT)    : &4a80 (tile_sprite_shrine_wall_corner)        FLIP_VERTICALLY
    .byte $83,$4a                    ; ; &2c (TILE_SHRINE_WALL_BOTTOM_RIGHT)   : &4a80 (tile_sprite_shrine_wall_corner)        FLIP_HORIZONTALLY_AND_VERTICALLY
    .byte $00,$46                    ; ; &2d (TILE_CHANDELIER)                 : &4600 (tile_sprite_chandelier)
    .byte $00,$4b                    ; ; &2e (TILE_MISSILE_NOSE_LEFT)          : &4b00 (tile_sprite_missile_nose)
    .byte $02,$4b                    ; ; &2f (TILE_MISSILE_NOSE_RIGHT)         : &4b00 (tile_sprite_missile_nose)              FLIP_HORIZONTALLY
    .byte $80,$45                    ; ; &30 (TILE_MISSILE_TAIL_LEFT)          : &4580 (tile_sprite_missile_tail)
    .byte $82,$45                    ; ; &31 (TILE_MISSILE_TAIL_RIGHT)         : &4580 (tile_sprite_missile_tail)              FLIP_HORIZONTALLY
    .byte $80,$4b                    ; ; &32 (TILE_MISSILE_BODY)               : &4b80 (tile_sprite_missile_body)              mirrored
    .byte $00,$10                    ; ; &33 (TILE_FACTORY_WALL)               : &1000 (tile_sprite_factory_wall)
    .byte $00,$48                    ; ; &34 (TILE_SPACESHIP_MIDDLE_RIGHT)     : &4800 (tile_sprite_spaceship_middle)
    .byte $02,$48                    ; ; &35 (TILE_SPACESHIP_MIDDLE_LEFT)      : &4800 (tile_sprite_spaceship_middle)          FLIP_HORIZONTALLY
    .byte $80,$48                    ; ; &36 (TILE_SPACESHIP_END_RIGHT)        : &4880 (tile_sprite_spaceship_end)
    .byte $82,$48                    ; ; &37 (TILE_SPACESHIP_END_LEFT)         : &4880 (tile_sprite_spaceship_end)             FLIP_HORIZONTALLY
    .byte $00,$01                    ; ; &38 (TILE_SPACE_TWO)                  ; &0100 (tile_sprite_space)

player_sprite_addresses_table:
    .byte $c0,$5b                    ; ; &00 : &5bc0 = player_sprite_zero
    .byte $20,$5c                    ; ; &01 : &5c20 = player_sprite_one
    .byte $80,$5c                    ; ; &02 : &5c80 = player_sprite_two
    .byte $c0,$5b                    ; ; &03 : &5bc0 = player_sprite_zero
    .byte $e0,$5c                    ; ; &04 : &5ce0 = player_sprite_three
    .byte $40,$5d                    ; ; &05 : &5d40 = player_sprite_four

unused_0ffe:
    .byte $0d,$06

tile_sprite_factory_wall:
    .byte $77,$77,$bb,$bb,$cc,$cc,$cd,$cc,$cd,$cc,$cd,$cc,$cd,$cc,$cd,$cc
    .byte $cd,$cc,$cd,$cc,$cd,$cc,$cd,$cc,$cd,$cc,$cd,$cc,$bb,$bb,$77,$77
    .byte $ff,$ff,$ff,$ff,$00,$00,$05,$0a,$05,$0a,$05,$0b,$05,$0b,$07,$0b
    .byte $07,$0b,$07,$0f,$07,$0f,$07,$0f,$07,$0f,$07,$00,$ff,$ff,$ff,$ff
    .byte $ff,$ff,$ff,$ff,$00,$00,$05,$0a,$07,$0f,$0f,$0f,$0f,$0f,$0f,$0f
    .byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$00,$ff,$ff,$ff,$ff
    .byte $ee,$ee,$dd,$dd,$33,$33,$33,$3b,$3b,$3b,$3b,$3b,$3b,$3b,$3b,$3b
    .byte $3b,$3b,$3b,$3b,$3b,$3b,$3b,$3b,$3b,$3b,$3b,$33,$dd,$dd,$ee,$ee

wrist_terminal_text:
    .byte $1f,$08,$05                ; ; TAB(&08, &05)
    .byte "WRIST TERMINAL"           ; ; "WRIST TERMINAL"
    .byte $1f,$0a,$09                ; ; TAB(&0a, &09)
    .byte "SECTOR"                   ; ; "SECTOR"
    .byte $1f,$0a,$0b                ; ; TAB(&0a, &0b)
    .byte "SCORE"                    ; ; "SCORE"
    .byte $1f,$0a,$0e                ; ; TAB(&0a, &0e)
    .byte $53,$55,$49,$54,$20,$45,$4e,$45,$52,$47,$59,$20,$20,$20,$20,$20 ; ; "SUIT ENERGY      "
    .byte $20
    .byte $1f,$08,$13                ; ; TAB(&08, &13)
    .byte "BLASTER ENERGY"           ; ; "BLASTER ENERGY"
    .byte $1f,$05,$17                ; ; TAB(&05, &17)
    .byte "PASS CARD"                ; ; "PASS CARD"
    .byte $1f,$10,$17                ; ; TAB(&10, &17)
    .byte "EXTRA CELLS"              ; ; "EXTRA CELLS"
    .byte $1f,$08,$1b                ; ; TAB(&08, &1b)
    .byte "PRESS M FOR MAPS"         ; ; "PRESS M FOR MAPS"
    .byte $1f,$0a,$0c                ; ; TAB(&0a, &0c)
    .byte "MINES  "                  ; ; "MINES  "

unused_10fe:
    .byte "  "                       ; ; "  "
