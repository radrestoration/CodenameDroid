; ---- the game's state: a new game, a level, a new life, the lifts, the level's events

.segment "BSS"
keep_en:    .res 1
newlvl:     .res 1
arrive_mode: .res 1            ; 1 when the player arrives by lift (keeps the line)
.segment "CODE"

new_game:
    jsr reset_surface_tiles
    ; the tile maps
    lda #<level_tiles0
    sta p1
    lda #>level_tiles0
    sta p1 + 1
    lda #<LTILES
    sta p2
    lda #>LTILES
    sta p2 + 1
    ldx #14
    ldy #0
:   lda (p1),y
    sta (p2),y
    iny
    bne :-
    inc p1 + 1
    inc p2 + 1
    dex
    bne :-
    ; the objects: not collected
    ldx #0
:   txa
    sta zt
    asl
    clc
    adc zt
    tay
    lda level_objects,y
    and #$f0
    sta objflags,x
    inx
    cpx #56
    bne :-
    lda #3
    sta lives
    lda #$25
    sta suit_energy
    sta blaster_energy
    lda #$ff
    sta jp_energy
    lda #$0c
    sta maxjump
    lda #0
    sta total_objs
    sta deepest
    sta frame_counter
    sta recent_fire
    sta recent_up
    sta recent_down
    sta swapping
    sta jump_timer
    sta jump_direction
    sta pjf
    sta clim_cd
    sta supp
    sta arrive_mode
    sta jp_cool
    ldx #7
:   sta score,x
    dex
    bpl :-
    ldx #15
:   sta carried,x
    dex
    bpl :-
    lda #NEW_GAME_PX
    sta init_px
    lda #0
    jmp set_level

; set_level: A the level (the player's side from init_px, the line from arrive_mode)
set_level:
    sta level
    lda #0
    sta keep_en
    jmp set_level_go

; a new life: the level again, the enemies as they were
set_level_keep:
    sta level
    lda #1
    sta keep_en
set_level_go:
    lda lift_screen
    bne :+
    jsr screen_off
:   
    lda #0
    sta pstance
    sta obst_pix
    sta pframe
    sta jump_timer
    sta jump_direction
    sta pjf
    sta swapping
    jsr load_level
    jsr pool_configure
    lda keep_en
    bne @keep
    jsr init_enemies
    jmp @en
@keep:
    jsr pool_reset
@en:
    jsr init_mines_blasters
    lda #0
    sta arrive_mode
    lda lift_screen
    bne @ride
    jsr init_view
    jsr screen_on
    rts
@ride:
    rts

NEW_GAME_PX = $c4               ; the BBC's start of a new game, under the ship

; The surface's spaceship tiles become walls and rope on the first lift attempt.
reset_surface_tiles:
    lda #$35
    sta level_xlat + 9
    lda #$34
    sta level_xlat + 10
    lda #$36
    sta level_xlat + 12
    lda #$37
    sta level_xlat + 13
    rts

set_surface_tiles:
    lda #$10
    sta level_xlat + 9
    lda #$0f
    sta level_xlat + 10
    lda #$16
    sta level_xlat + 12
    lda #$14
    sta level_xlat + 13
    rts

; start_for_level: the player's place from init_px
start_for_level:
    lda init_px
    cmp #NEW_GAME_PX
    bne :+
    sta px
    sta pc
    lda #0
    sta pdir
    lda #128                    ; standing on the ground under the ship
    sta py
    rts
:   lda init_px
    bmi @right
    lda #4
    sta px
    sta pc
    lda #1
    sta pdir
    jmp @y
@right:
    lda #$f8
    sta px
    sta pc
    lda #0
    sta pdir
@y: lda arrive_mode
    bne @r
    lda #96
    sta py
@r: rts

; initialise_level: the enemies of the level, then the mines
pool_reset:
    ldx #9
    lda #$ff
:   sta pool_owner,x
    sta pg_col,x
    sta pg_img,x
    dex
    bpl :-
    rts

init_enemies:
    jsr pool_reset
    ldx level
    lda level_enemy_offsets,x
    sta zk                      ; first entry
    lda level_enemy_offsets + 1,x
    sta zs                      ; end
    ldy #0                      ; offset in enemies
@l: lda zk
    cmp zs
    beq @done
    asl
    tax
    lda level_enemies,x
    sta enemies,y               ; x
    lda level_enemies + 1,x
    pha
    and #7
    sta enemies + 1,y           ; y
    pla
    sta zt
    lsr
    lsr
    lsr
    lsr
    and #3
    sta enemies + 2,y           ; bit 0 facing left, bit 1 stationary
    lda #1
    sta enemies + 3,y           ; frame 0, fraction 1
    lda level
    lsr
    clc
    adc #1
    sta zv
    lda zt
    and #$f0
    clc
    adc zv
    sta enemies + 4,y           ; energy and flags
    iny
    iny
    iny
    iny
    iny
    inc zk
    jmp @l
@done:
    sty last_enemy
    rts

init_mines_blasters:
    lda #6
    sta nmines
    lda #0
    ldx #5
:   sta mines_state,x
    dex
    bpl :-
    lda #$ff
    ldx #5
:   sta bl_ttl,x
    dex
    bpl :-
    rts

; ---- the lift (consider_using_lift beyond the position test): carry set if the player rode
lift_ride:
    ; which tile column has the chain: the right lift at tile column 6 (62 of the level), the left at 1
    lda lift_dir
    beq :+
    lda #3
:   sta zk                      ; byte in the column: 0 at the top, 3 at the bottom
    lda px
    cmp #5
    bcc @leftend
    ; at the right end
    lda pdir
    bne @c57
    lda #62
    jmp @col
@c57:
    lda #57
    jmp @col
@leftend:
    lda pdir
    bne @c1
    lda #6
    jmp @col
@c1:
    lda #1
@col:
    sta zm                      ; the tile column
    asl
    asl
    clc
    adc zk
    tay
    lda level
    clc
    adc #>LTILES
    sta p3 + 1
    lda #0
    sta p3
    lda (p3),y
    cmp #$33
    beq :+
    clc
    rts
:   jsr set_surface_tiles
    lda carried
    bne :+
    clc
    rts
:   dec carried
    jsr sfx_lift
    lda px
    sta init_px
    lda #0
    sta pstance
    sta obst_pix
    ; the lift is removed from this level: two bytes of the column
    lda zm
    asl
    asl
    clc
    adc #1
    tay
    lda #$33
    sta (p3),y
    iny
    sta (p3),y
    ; the ride: the cabin's cells in this level become chain, the new level scrolls in
    lda lift_dir
    bne :+
    ldx level
    dex
    jmp :++
:   ldx level
    inx
:   stx newlvl
    jsr lift_ride_scroll
    ; the new level
    lda newlvl
    sta level
    lda #1
    sta arrive_mode
    lda level
    pha
    jsr set_level
    pla
    ; the lift is added to the new level: its four tiles (the map and the picture)
    lda init_px
    bmi @addright
    lda #1
    jmp @add
@addright:
    lda #62
@add:
    sta zm
    ldx zm
    ldy #2
    lda #2
    jsr replot_tile
    ldx zm
    ldy #3
    lda #0
    jsr replot_tile
    ldx zm
    ldy #4
    lda #1
    jsr replot_tile
    ldx zm
    ldy #5
    lda #3
    jsr replot_tile
    jsr lift_finish_view
    lda lift_dir
    beq @r
    jsr consider_saving_position
@r: sec
    rts

consider_saving_position:
    lda level
    cmp #3
    bne :+
    lda #1
    jmp @set
:   cmp #6
    bne @r
    lda #2
@set:
    sta deepest
    jmp save_game
@r: rts

; ---- losing a life
lose_life_key:
    jsr lose_life
    sec
    rts

lose_life:
    jsr remove_colliding_blasters
    dec lives
    bne @alive
    jmp game_over
@alive:
    lda pstance
    bne :+
    lda #1
    sta skel_show
:   jsr make_sprites
    lda #1
    sta ready
    lda #8
    jsr play_sound_for_damage
    lda #100
    jsr wait_frames
    lda #$25
    sta suit_energy
new_life:
    lda #0
    sta skel_show
    sta pstance
    sta obst_pix
    sta jump_timer
    sta jump_direction
    sta pjf
    sta pframe
    sta swapping
    jsr init_mines_blasters
    lda #$25
    sta blaster_energy
    dec carried + $a
    lda init_px
    sta px
    lda level
    jmp set_level_keep

give_up:
    jmp game_over

; ---- the level's events (update_events)
update_events:
    jsr consider_energy_warning_and_check_for_completion
    jsr consider_dropping_girder
    jsr consider_using_disk_or_spanner
    lda carried + 8
    bne @nobutton
    lda level
    cmp #9
    bne @nobutton
    lda px
    cmp #$78
    bne @nobutton
    ldx #$1e
    ldy #5
    jsr replot_chain_and_crane
    jmp kill_player
@nobutton:
    lda level
    cmp #10
    bne @r
    lda px
    cmp #$51
    bne @n1
    jsr damage_player_if_not_crawling
    ldx #$14
    ldy #4
    jmp replot_chain_and_crane
@n1:
    cmp #$59
    bne @r
    jsr damage_player_if_not_crawling
    ldx #$16
    ldy #4
    jmp replot_chain_and_crane
@r: rts

replot_chain_and_crane:
    stx zx
    sty zy
    lda #3
    jsr replot_tile
    ldx zx
    ldy zy
    iny
    lda #$0e
    jmp replot_tile

kill_player:
    lda #$f0
    sta suit_energy
    sta pstance
    rts

consider_energy_warning_and_check_for_completion:
    lda suit_energy
    cmp #$0b
    bcs @nw
    bmi @nw
    lda frame_counter
    and #$1f
    cmp #3
    bcs @nw
    jsr sfx_warning
@nw:
    lda carried + $b
    beq @r
    lda carried + $a
    cmp #4
    bne @r
    lda level
    cmp #$0b
    bne @r
    lda pjf
    bne @r
    lda px
    cmp #$4d
    bne @r
    jmp game_completed
@r: rts

consider_dropping_girder:
    jsr player_row
    cpx #$0f
    bcs @r
    lda level
    cmp #1
    bne @r
    lda px
    cmp #$51
    bne @r
    jsr damage_player_if_not_crawling
    ldx #$14
    ldy #1
    lda #3
    jsr replot_tile
    ldx #$14
    ldy #2
    lda #2
    jmp replot_tile
@r: rts

consider_using_disk_or_spanner:
    lda level
    cmp #$0b
    bne @skipdisk
    lda carried + $f
    beq @skipdisk
    lda px
    cmp #$19
    bne @skipdisk
    jsr sfx_chime
    ldx #6
    ldy #3
    lda #0
    sta carried + $f
    jsr replot_tile
    ldx #6
    ldy #2
    lda #$0e
    jmp replot_tile
@skipdisk:
    lda carried + 9
    beq @r
    lda level
    cmp #8
    bne @nolamp
    lda px
    cmp #$68
    bne @nolamp
    jsr sfx_chime
    lda #0
    sta carried + 9
    ldx #$19
    ldy #6
    lda #0
    jsr replot_tile
    ldx #$18
    ldy #5
    lda #$0b
    jmp replot_tile
@nolamp:
    lda pstance
    cmp #3
    beq @r
    lda level
    cmp #6
    bne @r
    lda px
    cmp #$b8
    bne @r
    lda #2
    sta carried + 9
    jsr sfx_chime
@r: rts

damage_player_if_not_crawling:
    lda pstance
    bne @r
    lda #2
    sta pstance
    lda pdir
    beq :+
    lda pc
    sec
    sbc #4
    sta pc
:   lda py
    clc
    adc #17
    sta py
    lda suit_energy
    sec
    sbc #$1e
    sta suit_energy
    lda #8
    jmp play_sound_for_damage
@r: rts

; consider_using_keys (from update_enemies): the shrine's and the quarters' doors
consider_using_keys:
    lda carried + 4
    beq @r
    lda pstance
    cmp #3
    beq @r
    lda pjf
    bne @r
    lda level
    cmp #4
    bne @nots
    lda px
    cmp #$29
    bne @nots
    ldx #$0b
    ldy #3
    lda #0
    sta carried + 4
    jsr replot_tile
    ldx #$0b
    ldy #2
    lda #4
    jmp replot_tile
@nots:
    cmp #7
    bne @r
    lda px
    cmp #$d1
    bne @r
    ldx #$35
    ldy #4
    lda #0
    sta carried + 4
    jsr replot_tile
    ldx #$39
    ldy #4
    lda #0
    jmp replot_tile
@r: rts

; the shrine: chandeliers swing, gargoyles look, pillars rise and fall
chandelier_flip: .byte 0

update_shrine:
    lda frame_counter
    and #$0f
    cmp #7
    lda #0
    bcc :+
    lda #1
:   sta chandelier_flip
    lda frame_counter
    and #6
    cmp #4
    bne @r
    lda level
    cmp #3
    bcc @r
    cmp #6
    bcs @r
    jsr update_chandeliers
    jsr update_gargoyles
@r: rts

update_chandeliers:
    lda #0
    sta rx                      ; tile column
@c: lda #0
    sta ry
@t: lda level
    clc
    adc #>LTILES
    sta p3 + 1
    lda rx
    asl
    asl
    sta zt
    lda ry
    lsr
    clc
    adc zt
    sta p3
    ldy #0
    lda (p3),y
    sta zv
    lda ry
    and #1
    beq :+
    lda zv
    lsr
    lsr
    lsr
    lsr
    sta zv
:   lda zv
    and #$0f
    cmp #8
    bne @n
    lda chandelier_flip
    bne @alt
    lda #128
    sta rk
    jsr draw_tile
    jmp @n
@alt:
    jsr draw_tile_alt
@n: inc ry
    lda ry
    cmp #8
    bne @t
    inc rx
    lda rx
    cmp #64
    bne @c
    rts

; the chandelier's other grid is at TGALT, which draw_tile reads as TG + 256 + index
draw_tile_alt:
    lda #0
    sta rr
@r: lda #0
    sta rc
@c: lda rr
    asl
    asl
    clc
    adc rc
    tax
    lda TGALT,x
    pha
    lda rx
    asl
    asl
    clc
    adc rc
    tax
    lda ry
    asl
    asl
    clc
    adc rr
    tay
    pla
    jsr put_cell
    inc rc
    lda rc
    cmp #4
    bne @c
    inc rr
    lda rr
    cmp #4
    bne @r
    rts

update_gargoyles:
    jsr update_pillars
    ldx #0
@l: stx zx
    lda gargoyle_locations,x
    cmp level
    bne @n
    lda gargoyle_locations + 1,x
    cmp px
    lda #6
    bcc :+
    lda #5
:   sta zv
    lda gargoyle_locations + 3,x
    tay
    lda gargoyle_locations + 2,x
    tax
    lda zv
    jsr replot_tile
@n: ldx zx
    inx
    inx
    inx
    inx
    cpx #28
    bne @l
    rts

gargoyle_locations:
    .byte 4, $14, 5, 1
    .byte 4, $1c, 7, 1
    .byte 4, $b0, $2c, 3
    .byte 4, $c0, $30, 3
    .byte 4, $b8, $2e, 2
    .byte 5, $d8, $36, 3
    .byte 5, $e8, $3a, 3

pillars_x:  .byte $2d, $2b, 7, 5, 3, $2d, $29

update_pillars:
    lda level
    cmp #5
    beq :+
    rts
:   lda frame_counter
    and #$1e
    cmp #$0c
    bne @notraise
    lda #6
    sta zy
    lda #0
    jsr update_pillar_tiles
    lda #5
    sta zy
    lda #4
    jmp update_pillar_tiles
@notraise:
    cmp #$1c
    beq :+
    rts
:   lda #5
    sta zy
    lda #$0b
    jsr update_pillar_tiles
    lda #6
    sta zy
    lda #4
    jsr update_pillar_tiles
    ; a lowered pillar on the player kills
    jmp pillars_hit_player

update_pillar_tiles:
    sta zr
    lda #6
    sta zk
@l: ldx zk
    lda pillars_x,x
    tax
    ldy zy
    lda zr
    stx zs
    jsr replot_tile
    dec zk
    bne @l
    rts

; the player's four points against the lowered pillars
pillars_hit_player:
    ldx #0
@p: lda point_dx,x
    clc
    adc pc
    sta sa_c
    lda point_dy,x
    clc
    adc py
    sta sa_l
    stx zx
    jsr rdb
    ldx zx
    cmp #0
    beq @n
    ; is it a pillar's column?
    lda sa_c
    lsr
    lsr
    ldy #6
@q: cmp pillars_x,y
    beq @hit
    dey
    bne @q
@n: inx
    cpx #4
    bne @p
    rts
@hit:
    jmp kill_player

point_dx:   .byte 2, 0, 2, 0
point_dy:   .byte 0, 0, 27, 27
