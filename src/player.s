; ---- the player: the BBC game's rules (bbc/src/droid.s), routine by routine. The BBC keeps the player's place as a screen address;
; here it is the cell column `pc` and the line `py` of the sprite's top left (`px` is the BBC's player_x, which the level's events
; use; they differ only for a player crawling left, whose sprite starts four cells to the left of player_x).

.segment "BSS"
scan_inv:   .res 1
.segment "CODE"

; ---- reading the level as the BBC reads its screen: the byte at cell column sa_c, line sa_l
rdb:
    lda sa_l
    lsr
    lsr
    lsr
    clc
    adc rows_page
    sta p1 + 1
    lda #0
    sta p1
    ldy sa_c
    lda (p1),y
    tay
    lda sa_l
    and #7
    clc
    adc #>BPAT
    sta p2 + 1
    lda #0
    sta p2
    lda (p2),y
    rts

; scan_v: check_for_vertical_obstacle_with_X: the lines down from (sa_c, sa_l), X counting the blank ones; A the byte found
scan_v:
    lda pjf
    beq @loop
    lda jump_timer
    bne @loop
    dex
@loop:
    jsr rdb
    bne @leave
    inx
    cpx #$20
    beq @leave
    inc sa_l
    bne @loop
    lda #$ff
@leave:
    eor carried + 2
    rts

; scan_h: check_for_horizontal_obstacle: the cells across from (sa_c, sa_l), X from its start to 3 counting the clear ones
scan_h:
@loop:
    jsr rdb
    sta zv
    ldy scan_inv
    bne @inv
    lda zv
    bne @leave
    beq @cont
@inv:
    lda zv
    beq @leave
@cont:
    inx
    cpx #3
    beq @leave
    inc sa_c
    jmp @loop
@leave:
    lda zv
    rts

; below the player: the line under the feet, the three cells across. X in (0), out; A the byte
check_for_obstacle_below_player:
    lda pc
    sta sa_c
    lda py
    clc
    adc #32
    bcs @solid
    sta sa_l
    jmp scan_h
@solid:
    lda #$ff
    sta zv
    rts

check_for_obstacle_above_player:
    ldx #0
    lda pc
    sta sa_c
    lda py
    sec
    sbc #4
    bcc @solid
    sta sa_l
    jmp scan_h
@solid:
    lda #$ff
    rts

check_for_obstacle_to_right_of_player:
    lda pc
    clc
    adc #3
    sta sa_c
    lda py
    sta sa_l
    ldx #0
    jmp scan_v

check_for_obstacle_to_left_of_player:
    lda pc
    sec
    sbc #1
    sta sa_c
    lda py
    sta sa_l
    ldx #0
    jmp scan_v

; the player's row (calculate_player_screen_address_offset's X): the line / 8
player_row:
    lda py
    lsr
    lsr
    lsr
    tax
    rts

; ---- the game's step: the BBC's main loop without the display
game_step:
.ifdef CHEAT
    jsr cheat_keys
.endif
    jsr update_exploding_mines
    jsr update_player
    jsr check_player_blasters
    lda suit_energy
    bpl :+
    jsr lose_life
:   jsr remove_colliding_blasters
    jsr check_for_player_input_other_than_movement
    lda #1
    sta supp
    jsr consider_player_falling
    lda #0
    sta supp
    jsr reset_autorepeat
    jsr update_blasters
    inc frame_counter
    jsr consider_player_falling
    jsr update_horizontally_jumping_player
    jsr consider_jumping_onto_rope
    jsr reset_autorepeat
    lda carried + 2
    beq :+
    lda #0
    sta jump_direction
:   lda swapping
    beq @input
    lda pdir
    beq @facing_right
    inc px
    jsr consider_scrolling_right_step
    dec swapping
    jmp @after
@facing_right:
    dec px
    jsr consider_scrolling_left_step
    dec swapping
    jmp @after
@input:
    jsr consider_checking_for_player_input
@after:
    jsr update_blasters
    jsr update_enemies
    jsr update_events
    jsr update_shrine
    jsr camera
    rts

camera:
    lda py
    lsr
    lsr
    lsr
    sec
    sbc want_cam
    bcc @up
    cmp #3
    bcc @up
    cmp #19
    bcs @down
    rts
@up:
    lda want_cam
    beq @r
    dec want_cam
@r: rts
@down:
    lda want_cam
    cmp #7
    bcs @r
    inc want_cam
    rts

; reset_autorepeat_suppression_for_fire_down_and_up
reset_autorepeat:
    lda key1
    cmp #K_FIRE
    beq @d
    lda key2
    cmp #K_FIRE
    beq @d
    lda #0
    sta recent_fire
@d: lda key1
    cmp #K_DOWN
    beq @u
    lda key2
    cmp #K_DOWN
    beq @u
    lda #0
    sta recent_down
@u: lda key1
    cmp #K_UP
    beq @x
    lda key2
    cmp #K_UP
    beq @x
    lda #0
    sta recent_up
@x: rts

; update_player: the plotting of the BBC's loop has effects on the state, which are kept
update_player:
    lda pstance
    bne @ns
    dec pframe
    jmp plot_facing
@ns:
    cmp #3
    bne @r
    jmp plot_climbing_player
@r: rts

; plot_player_facing_direction: the frame moves on (and a player at a rope starts climbing)
plot_facing:
    lda pdir
    bne plot_facing_left
plot_facing_right:
    lda #0
    sta pdir
    lda obst_pix
    cmp #9
    bne :+
    jsr at_lift_edge            ; the chain at the end of a level is the lift's: the player does not take hold of it
    bcs :+
    jmp set_player_climbing
:   inc pframe
    lda pframe
    cmp #6
    bne :+
    lda #0
    sta pframe
:   rts
plot_facing_left:
    lda #1
    sta pdir
    lda obst_pix
    cmp #9
    bne :+
    jsr at_lift_edge            ; the chain at the end of a level is the lift's: the player does not take hold of it
    bcs :+
    jmp set_player_climbing
:   inc pframe
    lda pframe
    cmp #6
    bne :+
    lda #0
    sta pframe
:   rts

at_lift_edge:
    lda px
    cmp #5
    bcc @y
    cmp #$f8
    rts
@y: sec
    rts

set_player_climbing:
    lda #0
    sta jump_timer
    sta jump_direction
    sta pjf
    sta pframe
    sta clim_cd
    lda #3
    sta pstance
    rts

plot_player_standing:
    lda #$ff
    sta pframe
    jmp plot_facing

plot_climbing_player:
    lda pframe
    and #1
    bne @r
    sta pframe
@r: rts

; ---- falling and jumping
consider_player_falling:
    lda pstance
    beq @stand
    rts
@stand:
    jsr consider_player_jumping
    bcc @fall
    rts
@fall:
    ldx #0
    jsr check_for_obstacle_below_player
    cpx #3
    beq @noob
    lda #0
    sta pjf
    sta jump_direction
    rts
@noob:
    stx pjf
    lda supp
    bne move_player_down
    lda jump_direction
    beq move_player_down
    lda #7
    sta pframe
    rts

; move_player_down_and_replot
move_player_down:
    lda py
    clc
    adc #4
    sta py
    lda #0
    sta pframe
    lda supp
    bne @plot
    lda jump_direction
    beq @plot
    rts
@plot:
    jmp plot_facing

; consider_player_jumping: carry set if the player is jumping upwards (the caller then leaves)
consider_player_jumping:
    lda jump_timer
    bne @j
    clc
    rts
@j: lda #1
    sta pjf
    lda supp
    bne @upd
    lda jump_direction
    beq @upd
    sec
    rts
@upd:
    jsr update_jumping_player
    sec
    rts

update_jumping_player:
    dec jump_timer
    jsr check_for_obstacle_above_player
    cpx #3
    beq @free
    lda carried + 2
    beq @end
    lda key1
    cmp #K_JUMP
    beq @cont
    lda key2
    cmp #K_JUMP
    bne @end
@cont:
    lda #2
    sta jump_timer
    rts
@end:
    lda #0
    sta jump_timer
    rts
@free:
    lda py
    sec
    sbc #4
    sta py
    lda supp
    bne @plot
    lda jump_direction
    beq @plot
    rts
@plot:
    lda #0
    sta pframe
    jmp plot_facing

update_horizontally_jumping_player:
    lda jump_timer
    bne :+
    rts
:   lda jump_direction
    bne :+
    rts
:   lda #0
    sta pframe
    jsr update_jumping_player
    lda jump_direction
    cmp #1
    bne @left
    jsr check_for_obstacle_to_right_of_player
    sta obst_pix
    jsr find_hold_on_rope_right
    cmp #9
    beq @sr
    cpx #$20
    beq @sr
    lda #0
    sta jump_direction
    sta jump_timer
    jmp plot_facing
@sr:
    jmp consider_scrolling_right
@left:
    jsr check_for_obstacle_to_left_of_player
    sta obst_pix
    jsr find_hold_on_rope_left
    cmp #9
    beq @sl
    cpx #$20
    beq @sl
    lda #0
    sta jump_direction
    sta jump_timer
    jmp plot_facing
@sl:
    jmp consider_scrolling_left

consider_jumping_onto_rope:
    lda pframe
    cmp #7
    beq :+
    rts
:   lda #0
    sta pframe
    lda jump_direction
    cmp #1
    bne @left
    jsr check_for_obstacle_to_right_of_player
    sta obst_pix
    jsr find_hold_on_rope_right
    cmp #9
    beq @nor
    cpx #$20
    beq @nor
    lda #0
    sta jump_direction
    sta jump_timer
    jsr consider_player_falling
    rts
@nor:
    jsr move_player_down
    jmp consider_scrolling_right
@left:
    jsr check_for_obstacle_to_left_of_player
    sta obst_pix
    jsr find_hold_on_rope_left
    cmp #9
    beq @nol
    cpx #$20
    beq @nol
    lda #0
    sta jump_direction
    sta jump_timer
    jsr consider_player_falling
    rts
@nol:
    jsr move_player_down
    jmp consider_scrolling_left

; ---- ropes
find_hold_on_rope_right:
    lda obst_pix
    cmp #9
    beq hold_rope_right
leave_with_zero:
    lda #0
    sta obst_pix
    rts
hold_rope_right:
    lda pc
    clc
    adc #3
    sta sa_c
    lda py
    clc
    adc #32
    sta sa_l
    jmp find_hold_on_rope

find_hold_on_rope_left:
    lda obst_pix
    cmp #9
    beq @rope
    rts
@rope:
    lda pc
    sec
    sbc #1
    sta sa_c
    lda py
    clc
    adc #32
    sta sa_l
find_hold_on_rope:
    lda carried + 2
    bne leave_with_zero
    stx zx
    jsr rdb
    ldx zx
    cmp #9
    beq leave_with_rope
    jsr player_row
    txa
    and #3                      ; (the BBC's: (minus_offset_high & 3) eor 3, which is the row's low two bits)
    sta zt                      ; y_fraction
    ldx zx
    lda pjf
    beq :+
    lda jump_timer
    bne :+
    inc zt
:   lda zt
    asl
    asl
    asl
    sta zt
    lda py
    and #$f8
    sec
    sbc zt
    sta py
leave_with_rope:
    ldx zx
    lda #9
    rts

; ---- moving
consider_scrolling_right:
    lda px
    cmp #$f8
    bne :+
    rts
:   jsr consider_scrolling_right_step
    lda swapping
    beq :+
    rts
:   lda pstance
    cmp #2
    bne :+
    jmp crawl_right
:   jmp move_player_right

; the scrolling of the BBC (the screen does that here by following the player); the jet pack's fuel goes as it scrolls
consider_scrolling_right_step:
    lda px
    cmp #$0f
    bcc @r
    cmp #$ef
    bcs @r
    jmp update_jet_pack
@r: rts

consider_scrolling_left:
    lda px
    cmp #4
    bne :+
    rts
:   jsr consider_scrolling_left_step
    lda swapping
    beq :+
    rts
:   lda pstance
    cmp #2
    bne :+
    jmp crawl_left
:   jmp move_player_left

consider_scrolling_left_step:
    lda px
    cmp #$10
    bcc @r
    cmp #$f0
    bcs @r
    jmp update_jet_pack
@r: rts

update_jet_pack:
    lda jp_energy
    bne has_energy
exit_jet_pack:
    lda #$ff
    sta jp_energy
    lda #0
    sta carried + 2
    jmp plot_player_standing
has_energy:
    lda carried + 2
    beq @r
    inc jp_cool
    lda jp_cool
    and #3
    bne @r
    dec jp_energy
@r: rts

move_player_left:
    lda pstance
    cmp #3
    bne @notclimb
    lda pdir
    bne @swap
    lda #0
    sta obst_pix
    sta pstance
    dec px
    dec pc
    jmp plot_facing_left
@swap:
    lda #0
    sta pdir
    lda #1
    sta swapping
    lda pc
    sec
    sbc #2
    sta pc
    dec px
    jmp set_climbing_facing
@notclimb:
    dec px
    dec pc
    jmp plot_facing_left

move_player_right:
    lda pstance
    cmp #3
    bne @notclimb
    lda pdir
    beq @swap
    lda #0
    sta obst_pix
    sta pstance
    inc px
    inc pc
    jmp plot_facing_right
@swap:
    lda #1
    sta pdir
    lda #1
    sta swapping
    lda pc
    clc
    adc #2
    sta pc
    inc px
    jmp set_climbing_facing
@notclimb:
    inc px
    inc pc
    jmp plot_facing_right

set_climbing_facing:
    jmp set_player_climbing

; crawl_right / crawl_left
crawl_right:
    inc pframe
    lda pframe
    cmp #2
    bne :+
    lda #0
    sta pframe
:   inc px
    inc pc
    rts

crawl_left:
    inc pframe
    lda pframe
    cmp #2
    bne :+
    lda #0
    sta pframe
:   dec px
    dec pc
    rts

consider_moving_right:
    lda pstance
    cmp #2
    bne @notcrawl
    inc clim_cd
    lda clim_cd
    and #1
    beq @crawling
    rts
@crawling:
    lda pc
    clc
    adc #7
    sta sa_c
    lda py
    sta sa_l
    ldx #$10
    jsr scan_v
    cpx #$1f
    beq :+
    rts
:   jmp consider_scrolling_right
@notcrawl:
    jsr check_for_obstacle_to_right_of_player
    sta obst_pix
    cpx #$20
    bne :+
    jmp consider_scrolling_right
:   cmp #9
    bne @notrope
    jsr find_hold_on_rope_right
    jmp consider_scrolling_right
@notrope:
    stx obst_y
    jsr check_for_player_collision_with_mines_to_right
    jsr consider_collecting_object_to_right
    bcc :+
    rts
:   ldx obst_y
    cpx #$18
    bcc @leave
    jsr consider_moving_player_up_sloping_ground
    bcs @leave
    jmp consider_scrolling_right
@leave:
    rts

consider_moving_left:
    lda pstance
    cmp #2
    bne @notcrawl
    inc clim_cd
    lda clim_cd
    and #1
    beq @crawling
    rts
@crawling:
    lda pc
    sec
    sbc #1
    sta sa_c
    lda py
    sta sa_l
    ldx #$10
    jsr scan_v
    cpx #$1f
    beq :+
    rts
:   jmp consider_scrolling_left
@notcrawl:
    jsr check_for_obstacle_to_left_of_player
    sta obst_pix
    cpx #$20
    beq @free
    cmp #9
    bne @check
    jsr find_hold_on_rope_right
    jmp @free
@check:
    stx obst_y
    jsr check_for_player_collision_with_mines_to_left
    jsr consider_collecting_object_to_left
    bcc :+
    rts
:   ldx obst_y
    cpx #$18
    bcc @leave
    jsr consider_moving_player_up_sloping_ground
    bcs @leave
    jmp consider_scrolling_left
@free:
    lda pstance
    cmp #3
    bne :+
    ; climbing: the cell to the left of the rope's side must be clear
    lda pc
    sec
    sbc #2
    sta sa_c
    lda py
    sta sa_l
    ldx #0
    jsr scan_v
    cpx #$20
    beq :+
    rts
:   jmp consider_scrolling_left
@leave:
    rts

; sloping ground: carry set if the caller must leave
consider_moving_player_up_sloping_ground:
    lda obst_y
    and #3
    bne @leave
    jsr check_for_obstacle_above_player
    cpx #3
    beq @move
@leave:
    sec
    rts
@move:
    lda obst_y
    cmp #$1c
    bcs @once
    lda py
    sec
    sbc #4
    sta py
@once:
    lda py
    sec
    sbc #4
    sta py
    clc
    rts

; ---- the keys
consider_checking_for_player_input:
    lda carried + 2
    bne @nj
    lda pjf
    beq @nj
    rts
@nj:
    jsr update_jet_pack
    lda key1
    jsr check_for_player_input
    bcs @out
    lda key2
    jsr check_for_player_input
    bcs @out
    lda pstance
    bne @out
    lda pframe
    beq @out
    jmp plot_player_standing
@out:
    rts

; check_for_player_input: A the key. Carry set if the caller is to leave
check_for_player_input:
    cmp #K_RIGHT
    bne @notright
    lda carried + 2
    beq @r1
    lda #1
    sta jump_direction
    lda pjf
    beq @r1
    clc
    rts
@r1:
    lda pstance
    cmp #1
    beq @leave
    jsr consider_moving_right
@leave:
    sec
    rts
@notright:
    cmp #K_LEFT
    bne @notleft
    lda carried + 2
    beq @l1
    lda #2
    sta jump_direction
    lda pjf
    beq @l1
    clc
    rts
@l1:
    lda pstance
    cmp #1
    beq @leave
    jsr consider_moving_left
    sec
    rts
@notleft:
    cmp #K_UP
    bne @notup
    lda #0
    sta lift_dir
    jsr consider_using_lift
    bcs @leave                  ; (the lift: the BBC leaves for the main loop)
    jsr consider_climbing_up
    bcs @cont                   ; (climbing: leaves check_for_player_input only)
    lda recent_up
    bne @cont
    lda #1
    sta recent_up
    jsr consider_stance_up
@cont:
    clc
    rts
@notup:
    cmp #K_DOWN
    bne @notdown
    lda #1
    sta lift_dir
    jsr consider_using_lift
    bcs @leave
    jsr consider_climbing_down
    bcs @cont
    lda recent_down
    bne @cont
    lda carried + 2
    bne @cont
    lda #1
    sta recent_down
    jsr consider_stance_down
    clc
    rts
@notdown:
    cmp #K_TERM
    bne @notterm
    jsr wrist_terminal
    clc
    rts
@notterm:
    cmp #K_JET
    bne @notjet
    jsr jet_pack_screen
    clc
    rts
@notjet:
    sta zr
    jsr check_for_player_jumping
    lda zr
    jmp check_for_player_firing_and_other

; check_for_player_jumping: A the key
check_for_player_jumping:
    cmp #K_JUMP
    beq :+
    rts
:   lda pstance
    beq :+
    rts
:   lda maxjump
    sta jump_timer
    lda carried + 2
    beq @nojet
    jsr update_jet_pack
    lda #2
    sta jump_timer
    rts
@nojet:
    lda #1
    sta jump_direction
    lda key1
    cmp #K_RIGHT
    beq @r
    lda key2
    cmp #K_RIGHT
    beq @r
    inc jump_direction
    lda key1
    cmp #K_LEFT
    beq @r
    lda key2
    cmp #K_LEFT
    beq @r
    lda #0
    sta jump_direction
    dec jump_timer
    dec jump_timer
@r: rts

; check_for_player_firing_and_other_non_movement_actions: A the key. Carry set if the caller leaves
check_for_player_firing_and_other:
    sta zr
    cmp #K_FIRE
    bne @nf
    lda recent_fire
    bne @nf
    lda #1
    sta recent_fire
    jsr fire_blaster
    clc
    rts
@nf:
    lda zr
    cmp #K_ESC
    bne @ne
    jmp give_up
@ne:
    lda zr
    cmp #K_F0
    bne @n0
    lda #1
    sta sound_off
@n0:
    lda zr
    cmp #K_F1
    bne @n1
    lda #0
    sta sound_off
@n1:
    lda zr
    cmp #K_PAUSE
    bne @np
    jsr pause
@np:
    lda zr
    cmp #K_MINE
    bne @nd
    jsr drop_mine
    clc
    rts
@nd:
    lda zr
    cmp #K_TAB
    bne @nt
    jmp lose_life_key
@nt:
    lda zr
    cmp #K_O
    bne @no
    jsr exit_jet_pack
@no:
    clc
    rts

check_for_player_input_other_than_movement:
    lda key1
    jsr check_for_player_firing_and_other
    bcs @r
    lda key2
    jsr check_for_player_firing_and_other
    bcs @r
    lda carried + 2
    bne @jp
    lda pjf
    beq @jp
@r: rts
@jp:
    lda key1
    jsr check_for_player_jumping
    lda key2
    jmp check_for_player_jumping

; ---- stances
consider_stance_down:
    lda pstance
    beq @stand
    jmp consider_crawling
@stand:
    lda pdir
    bne @left
    ; facing right: the two cells at the right, one row down from the feet
    lda pc
    clc
    adc #2
    sta sa_c
    lda py
    clc
    adc #32
    sta sa_l
    ldx #2
    jsr scan_h
    cpx #3
    bcc set_player_kneeling
    rts
@left:
    ldx #0
    jsr check_for_obstacle_below_player
    cpx #1
    bcc set_player_kneeling
    rts
set_player_kneeling:
    lda #1
    sta pstance
    rts

consider_stance_up:
    lda pstance
    cmp #1
    bne @nk
    lda #0
    sta pstance
    jmp plot_player_standing
@nk:
    cmp #2
    beq :+
    rts
:   lda pc
    sta zm                       ; the previous address
    lda py
    sta zf
    lda pdir
    bne @left
    lda py
    sec
    sbc #17
    sta py
    jmp consider_kneeling
@left:
    lda pc
    clc
    adc #4
    sta pc
    lda py
    sec
    sbc #17
    sta py
consider_kneeling:
    jsr check_for_obstacles_to_kneeling
    cpx #$10
    bne @revert
    dec pstance
    jmp set_player_kneeling
@revert:
    lda zm
    sta pc
    lda zf
    sta py
    rts

; the eight cells that must be clear for the player to get up
check_for_obstacles_to_kneeling:
    ldx #0
@l: lda kneeling_check_dx,x
    clc
    adc pc
    sta sa_c
    lda kneeling_check_dy,x
    clc
    adc py
    sta sa_l
    stx zx
    jsr rdb
    ldx zx
    cmp #0
    bne @leave
    inx
    inx
    cpx #$10
    bne @l
@leave:
    rts

; (cells, lines) from the BBC's kneeling_check_offsets: $0100 $0110 $0210 $0010 $0000 $0008 $0200 $0210
kneeling_check_dx: .byte 0, 0, 2, 0, 2, 0, 2, 0, 0, 0, 1, 0, 0, 0, 2, 0
kneeling_check_dy: .byte 8, 0, 8, 0, 16, 0, 0, 0, 0, 0, 0, 0, 16, 0, 16, 0

consider_crawling:
    lda pstance
    cmp #2
    bne :+
    rts
:   lda pdir
    bne @left
    ; facing right: the four cells across at the crawling height, then the support below
    lda pc
    clc
    adc #3
    sta sa_c
    lda py
    clc
    adc #28
    sta sa_l
    jsr horizontal_obstacle_and_leave
    bcs crawl_out
    lda pc
    sta sa_c
    lda py
    clc
    adc #17
    sta sa_l
    jsr completely_supported
    bcs crawl_out
    jmp start_crawling
@left:
    lda pc
    sec
    sbc #4
    sta sa_c
    lda py
    clc
    adc #28
    sta sa_l
    jsr horizontal_obstacle_and_leave
    bcs crawl_out
    lda pc
    sec
    sbc #3
    sta sa_c
    lda py
    clc
    adc #17
    sta sa_l
    jsr completely_supported
    bcs crawl_out
start_crawling:
    lda #0
    sta pframe
    sta clim_cd
    inc pstance
    lda pdir
    bne @cl
    lda py
    clc
    adc #17
    sta py
    rts
@cl:
    lda pc
    sec
    sbc #4
    sta pc
    lda py
    clc
    adc #17
    sta py
crawl_out:
    rts

; the four cells down the column at sa: carry set if any is not clear (the BBC leaves its caller)
horizontal_obstacle_and_leave:
    ldx #0
@l: stx zx
    jsr rdb
    ldx zx
    cmp #0
    bne @leave
    inc sa_c
    inx
    cpx #4
    bne @l
    clc
    rts
@leave:
    sec
    rts

; completely_supported: the three cells at sa, two rows down, must all be solid: carry set if not
completely_supported:
    lda sa_l
    clc
    adc #16
    sta sa_l
    lda #1
    sta scan_inv
    ldx #$fd
    jsr scan_h
    lda #0
    sta scan_inv
    cpx #3
    beq @ok
    sec
    rts
@ok:
    clc
    rts

; ---- climbing
consider_climbing_up:
    lda pstance
    cmp #3
    beq :+
    clc
    rts
:   jsr check_for_obstacle_above_player
    cmp #9
    bne @no
    inc clim_cd
    lda clim_cd
    cmp #2
    bne @no
    lda #0
    sta clim_cd
    lda py
    sec
    sbc #4
    sta py
    inc pframe
    jsr plot_climbing_player
@no:
    sec
    rts

consider_climbing_down:
    lda pstance
    cmp #3
    beq :+
    clc
    rts
:   ldx #0
    jsr check_for_obstacle_below_player
    cmp #9
    bne @no
    lda py
    clc
    adc #4
    sta py
    lda #0
    sta pframe
    jsr plot_climbing_player
@no:
    sec
    rts

; ---- the lift
consider_using_lift:
    lda px
    cmp #5
    bcc in_lift
    cmp #$f8
    bcs in_lift
    clc
    rts
in_lift:
    jmp lift_ride

; ---- the player's picture: the image number (0 - 10) and the bytes of it (for the collisions)
.segment "BSS"
pb_w:       .res 1
pb_h:       .res 1
pb_dx:      .res 1
pb_dy:      .res 1
.segment "CODE"

select_player_image:
    lda skel_show
    beq :+
    ldx #SPR_SKEL
    rts
:   lda pstance
    bne @ns
    lda carried + 2
    beq @walk
    ldx #SPR_JET
    rts
@walk:
    lda pframe
    and #7
    tay
    ldx framemap,y
    rts
@ns:
    cmp #1
    bne @nk
    ldx #SPR_KNEEL
    rts
@nk:
    cmp #3
    bne @ncl
    lda pframe
    and #1
    clc
    adc #SPR_CLIMB0
    tax
    rts
@ncl:
    cmp #2
    beq @crawl
    ldx #0
    rts
@crawl:
    lda pframe
    and #1
    clc
    adc #SPR_CRAWL0
    tax
    rts

; player_byte: A the cell, Y the line in the player's image: the C64 byte of the picture there (0 outside it)
player_byte:
    sta pb_dx
    sty pb_dy
    lda pstance
    cmp #$f0
    bne :+
    lda #0
    rts
:   jsr select_player_image
    lda pdir
    bne :+
    lda sprite_index_right,x
    jmp :++
:   lda sprite_index_left,x
:   sta pb_w                    ; the first block
    cpx #SPR_CRAWL0
    bcc @normal
    cpx #SPR_SKEL
    bcs @normal
    ; crawling: 7 cells in three chunks of 3 cells, 15 lines
    lda pb_dy
    cmp #15
    bcs @z1
    lda pb_dx
    cmp #7
    bcs @z1
    ldx #0
:   cmp #3
    bcc :+
    sbc #3
    inx
    jmp :-
:   sta pb_h                    ; the cell in the chunk
    txa
    clc
    adc pb_w
    sta pb_w                    ; the block
    lda pb_dy
    jmp @off
@z1:
    jmp @zero
@normal:
    lda pb_dx
    cmp #3
    bcs @zero
    sta pb_h
    lda pb_dy
    cmp #32
    bcs @zero
    cmp #21
    bcc @off
    sbc #21
    inc pb_w                    ; the lower block
@off:
    ; line * 3 + cell
    sta zt
    asl
    clc
    adc zt
    clc
    adc pb_h
    sta zt                      ; offset in the block
    ; address = sprite_blocks + block * 64 + offset
    lda #0
    sta p3 + 1
    lda pb_w
    asl
    rol p3 + 1
    asl
    rol p3 + 1
    asl
    rol p3 + 1
    asl
    rol p3 + 1
    asl
    rol p3 + 1
    asl
    rol p3 + 1
    clc
    adc zt
    sta p3
    lda p3 + 1
    adc #0
    sta p3 + 1
    lda p3
    clc
    adc #<sprite_blocks
    sta p3
    lda p3 + 1
    adc #>sprite_blocks
    sta p3 + 1
    ldy #0
    lda (p3),y
    rts
@zero:
    lda #0
    rts
