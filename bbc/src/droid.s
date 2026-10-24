; Codename Droid (BBC Micro, Superior Software 1987) - the game code, &1100-&57ff
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

; (tape release: file DROID, load &1100, exec &5800, length &4800; the disc has this code as the first &4700 bytes of CDroid4)


.segment "DROID"

new_game:
    jsr to_remove_lifts_from_level_data
    jsr to_title_screen
    jsr set_level_specific_tiles
main_game_loop:
    lda $fe62                        ; User VIA data direction register B
    cmp #$d4
    beq skip_reset
    jmp (os_reset_address_low)
skip_reset:
    jsr wait_for_vsync
    jsr to_update_exploding_mines
    ldx #$c8
    stx enemy_energy_and_initial_flags ; Set to >= &20 to suppress clearing collisions
    stx enemy_to_update              ; Set to negative to indicate collision with player
    jsr to_buffer_colliding_blasters
    jsr update_player
    jsr to_check_for_collision_with_blasters ; Check for collision with player and walls
    lda suit_energy
    bpl not_out_of_energy_112f
    jsr to_lose_life
not_out_of_energy_112f:
    jsr to_remove_colliding_blasters
    jsr check_for_player_input_other_than_movement
    lda #$01
    sta suppress_horizontal_falling  ; Set to non-zero to fall vertically
    jsr consider_player_falling
    lda #$00
    sta suppress_horizontal_falling  ; Set to non-zero to move horizontally when falling
    jsr reset_autorepeat_suppression_for_fire_down_and_up
    jsr wait_for_vsync
    jsr to_update_blasters
    jsr set_colour_zero_to_black
    jsr wait_for_vsync
    inc frame_counter
    jsr consider_player_falling
    lda #$00
    sta screen_was_scrolled          ; Set to zero to indicate screen wasn't scrolled
    jsr update_horizontally_jumping_player
    jsr consider_jumping_onto_rope
    jsr reset_autorepeat_suppression_for_fire_down_and_up ; check_for_player_stance_and_firing_keys
    lda $c2                          ; objects_carried + &2 (OBJECT_JET_PACK)  # Non-zero if player is in jet pack
    beq skip_suppressing_jump
    lda #$00
    sta jump_direction               ; Set to zero to indicate player not jumping horizontally
skip_suppressing_jump:
    lda player_swapping_sides_on_rope ; Non-zero if player swapping sides on rope
    beq not_changing_direction_on_rope
    lda player_direction             ; Zero if facing right, non-zero if facing left
    beq is_facing_right_117b
is_facing_left_1171:
    inc player_x
    jsr consider_scrolling_right
    dec player_swapping_sides_on_rope ; Set to zero to indicate side swapped
    jmp skip_checking_for_player_input
is_facing_right_117b:
    dec player_x
    jsr consider_scrolling_left
    dec player_swapping_sides_on_rope ; Set to zero to indicate side swapped
    jmp skip_checking_for_player_input
not_changing_direction_on_rope:
    jsr consider_checking_for_player_input
skip_checking_for_player_input:
    lda screen_was_scrolled          ; Non-zero if screen was scrolled
    bne skip_waiting_for_vsync
    jsr wait_for_vsync
skip_waiting_for_vsync:
    jsr to_update_blasters
    jsr set_colour_zero_to_black
    jsr update_enemies
    jsr to_update_events
    lda frame_counter
    and #$0f
    cmp #$07
    bcc unflip_chandelier
flip_chandelier:
    lda #$02                         ; FLIP_HORIZONTALLY
    sta $0fda                        ; tile_sprites_addresses_table + 2 * &2d (TILE_CHANDELIER)
    jmp skip_unflipping_chandelier
unflip_chandelier:
    lda #$00
    sta $0fda                        ; tile_sprites_addresses_table + 2 * &2d (TILE_CHANDELIER)
skip_unflipping_chandelier:
    lda frame_counter
    and #$06
    cmp #$04
    bne skip_updating_ancient_shrine
    lda level
    cmp #$03
    bcc skip_updating_ancient_shrine
    cmp #$06
    bcs skip_updating_ancient_shrine
    jsr to_update_chandeliers
    jsr to_update_gargoyles
skip_updating_ancient_shrine:
    jmp main_game_loop

reset_autorepeat_suppression_for_fire_down_and_up:
    ldx #$00
reset_autorepeat_suppression_for_fire_down_and_up_loop:
    lda stance_and_firing_keys,x
    cmp os_most_recently_pressed_key
    beq consider_next_key
    cmp os_first_pressed_key
    beq consider_next_key
    lda #$00
    sta player_recent_keys,x
consider_next_key:
    inx
    cpx #$03
    bne reset_autorepeat_suppression_for_fire_down_and_up_loop
    rts

stance_and_firing_keys:
    .byte $d8                        ; ; ]
    .byte $e8                        ; ; /
    .byte $c8                        ; ; '

set_colour_zero_to_black:
    ldx #$00
    jsr to_set_palette
    ldx #$10
    jsr to_set_palette
    ldx #$40
    jsr to_set_palette
    ldx #$50
    jmp to_set_palette

consider_plotting_star:
    tay
    and #$01
    bne is_top_two_tiles
    rts
is_top_two_tiles:
    lda $e400,y                      ; Use OS ROM as source of random positions for stars  (listing: $ee00; disc: $e400)
    lsr a
    lsr a
    tay
    jsr to_calculate_screen_address
    ldy #$00
    lda (screen_address),y
    bne L_1212                       ; leave
    lda #$88                         ; 3000
    sta (screen_address),y           ; Plot star
L_1212:
    rts

leave_if_player_is_jumping_or_falling:
    lda player_jumping_or_falling
    beq leave_1219
    pla
    pla
leave_1219:
    rts

update_player:
    lda player_stance
    bne not_standing
    dec player_frame
    jmp plot_player_facing_direction
not_standing:
    cmp #$01                         ; STANCE_KNEELING
    bne not_kneeling_122a
    jmp plot_kneeling_player
not_kneeling_122a:
    cmp #$02                         ; STANCE_CRAWLING
    bne not_crawling_123b
    jsr get_player_screen_address
    lda player_direction             ; Zero if facing right, non-zero if facing left
    bne to_plot_player_crawling_left
    jmp plot_player_crawling_right_2161 ; &2161 and &21af are functionally identical
to_plot_player_crawling_left:
    jmp plot_player_crawling_left_21af
not_crawling_123b:
    cmp #$03                         ; STANCE_CLIMBING
    bne not_climbing_1242
    jmp plot_climbing_player
not_climbing_1242:
    cmp #$f0                         ; STANCE_DEAD
    beq leave_1255
    ldx #$03
    ldy #$20
    jsr get_player_screen_address
    jmp plot_player_in_jet_pack

consider_player_falling_and_leave_parent:
    jsr consider_player_falling
    pla                              ; Leave consider_jumping_onto_rope on next return
    pla
leave_1255:
    rts

update_jet_pack:
    lda jet_pack_energy
    bne not_out_of_energy_1265
exit_jet_pack:
    lda #$ff
    sta jet_pack_energy
    lda #$00
    sta $c2                          ; objects_carried + &2 (OBJECT_JET_PACK)
    jmp plot_player_standing
not_out_of_energy_1265:
    lda $c2                          ; objects_carried + &2 (OBJECT_JET_PACK)  # Non-zero if player is in jet pack
    beq leave_1273
    inc jet_pack_energy_cooldown
    lda jet_pack_energy_cooldown
    and #$03
    bne leave_1273
    dec jet_pack_energy
leave_1273:
    rts

set_level_specific_tiles:
    lda level
    cmp #$08                         ; Is this Crew's Quarters sector three?
    bcs use_pipes
use_tables:
    ldx #$1d                         ; TILE_TABLE_RIGHT
    stx $0546                        ; level_tiles_translation_table + &20 + &6  # Use tables for Crew's Quarters sectors one and two
    dex                              ; &1c : TILE_TABLE_LEFT
    stx $0547                        ; level_tiles_translation_table + &20 + &7
    rts
use_pipes:
    lda #$06                         ; TILE_PIPE_BOTTOM_RIGHT
    sta $0546                        ; level_tiles_translation_table + &20 + &6  # Use pipes for Crew's Quarters sector three
    lda #$04                         ; TILE_PIPE_BOTTOM_LEFT
    sta $0547                        ; level_tiles_translation_table + &20 + &7
    lda level
    cmp #$0a                         ; Is this Missile Factory sectors two or three?
    bcs use_spaceships
use_missiles:
    lda #$30                         ; TILE_MISSILE_TAIL_LEFT
    sta $0555                        ; level_tiles_translation_table + &30 + &5  # Use missile for Missile Factor sector one
    lda #$2e                         ; TILE_MISSILE_NOSE_LEFT
    sta $0557                        ; level_tiles_translation_table + &30 + &7
    rts
use_spaceships:
    lda #$36                         ; TILE_SPACESHIP_END_RIGHT
    sta $0555                        ; level_tiles_translation_table + &30 + &5  # Use spaceship for Missile Factor sector two
    lda #$34                         ; TILE_SPACESHIP_MIDDLE_RIGHT
    sta $0557                        ; level_tiles_translation_table + &30 + &7  # Spaceship for sector three is set at &174a
    rts

set_surface_defence_tiles:
    sta $052a                        ; level_tiles_translation_table + &00 + &a
    stx $0529                        ; level_tiles_translation_table + &00 + &9
    sty $052c                        ; level_tiles_translation_table + &00 + &c
    rts

get_top_nibble:
    lsr a
    lsr a
    lsr a
    lsr a
    rts

get_bottom_of_player_screen_address:
    lda player_screen_address_high
    adc #$04
    bpl skip_wraparound_12c2
    sec
    sbc #$20
skip_wraparound_12c2:
    sta screen_address_high
    rts

get_player_screen_address_high_after_subtraction:
    lda player_screen_address_high
    sbc #$00
    cmp #$60
    bcs skip_wraparound_12cf
    lda #$7f
skip_wraparound_12cf:
    rts

get_left_of_player_screen_address:
    sec
    lda player_screen_address_low
    sbc #$08
    sta screen_address_low
    rts

unplot_sprite:
    lda #$01                         ; &0101 = sprite_space + 1
    sta $72                          ; sprite_address_low
    sta $73                          ; sprite_address_high
    jmp to_plot_unflipped_player_274b

get_player_screen_address:
    lda player_screen_address_low
    sta screen_address_low
    lda player_screen_address_high
    sta screen_address_high
    rts

consider_moving_right:
    lda player_stance
    cmp #$02                         ; STANCE_CRAWLING
    bne not_crawling_1314
    inc climbing_or_crawling_cooldown
    lda climbing_or_crawling_cooldown
    and #$01
    beq is_crawling_right            ; Only crawl one frame in two
    rts
is_crawling_right:
    clc
    lda player_screen_address_low
    adc #$38
    sta screen_address_low
    lda player_screen_address_high
    adc #$00
    bpl skip_wraparound_1308
    lda #$60
skip_wraparound_1308:
    sta screen_address_high
    ldx #$10
    jsr check_for_vertical_obstacle_with_X ; check_for_obstacle_with_X
    cpx #$1f
    beq consider_scrolling_right
    rts
not_crawling_1314:
    jsr check_for_obstacle_to_right_of_player
    sta obstacle_pixel_value
    cpx #$20
    beq consider_scrolling_right
    cmp #$09                         ; 1001
    bne not_rope
    jsr find_hold_on_rope_right      ; Move player up until fully holding rope
    jmp consider_scrolling_right
not_rope:
    stx obstacle_y_position
    jsr check_for_player_collision_with_mines_to_right
    jsr consider_collecting_object_to_right ; Leaves if object collected
    ldx obstacle_y_position
    cpx #$18
    bcc leave_133b
    jsr consider_moving_player_up_sloping_ground ; Leaves if obstacle above player
    jmp consider_scrolling_right
leave_133b:
    rts

consider_scrolling_right:
    lda player_x
    cmp #$f8
    bne not_at_right_edge
    rts
not_at_right_edge:
    cmp #$0f
    bcs not_at_left_134a
    jmp skip_scrolling_screen_right
not_at_left_134a:
    cmp #$ef
    bcc not_at_right_1351
    jmp skip_scrolling_screen_right
not_at_right_1351:
    lda #$01
    sta screen_was_scrolled          ; Set to one to indicate screen was scrolled right
    jsr variable_delay
scroll_screen_right:
    clc
    lda screen_start_address_low
    adc #$08
    sta screen_start_address_low
    bcc skip_page_1369
    inc screen_start_address_high
    bpl skip_wraparound_1369
    lda #$60
    sta screen_start_address_high
skip_wraparound_1369:
skip_page_1369:
    inc right_edge_x_fraction
    lda right_edge_x_fraction
    cmp #$04
    bne not_next_tile_right_1380
    lda #$00
    sta right_edge_x_fraction
    clc
    lda right_edge_tile_address_low
    adc #$04
    sta right_edge_tile_address_low
    bcc skip_page_1380
    inc right_edge_tile_address_high
skip_page_1380:
not_next_tile_right_1380:
    clc
    lda screen_start_address_low
    adc #$f8
    sta screen_address_low
    lda screen_start_address_high
    adc #$00
    bpl skip_wraparound_138f
    lda #$60
skip_wraparound_138f:
    sta screen_address_high
    lda right_edge_x_fraction
    sta $77                          ; tile_x_fraction
    lda right_edge_tile_address_low
    sta $74                          ; tile_address_low
    lda right_edge_tile_address_high
    sta $75                          ; tile_address_high
    jsr plot_column_of_tiles
    lda level
    bne skip_stars_13b5
    lda player_x
    cmp #$50
    bcc skip_stars_13b5
    lda right_edge_tile_address_low
    clc
    adc right_edge_x_fraction
    tay
    ldx #$1f
    jsr consider_plotting_star
skip_stars_13b5:
    inc left_edge_x_fraction
    lda left_edge_x_fraction
    cmp #$04
    bne not_next_tile_left_13cc
    lda #$00
    sta left_edge_x_fraction
    clc
    lda left_edge_tile_address_low
    adc #$04
    sta left_edge_tile_address_low
    bcc skip_page_13cc
    inc left_edge_tile_address_high
skip_page_13cc:
not_next_tile_left_13cc:
    lda player_swapping_sides_on_rope ; Actually count when scrolling onto level
    cmp #$02
    bcs skip_waiting_for_sync
    jsr wait_for_vsync
skip_waiting_for_sync:
    inc crtc_address_low
    bne skip_page_13e5
    inc crtc_address_high
    lda crtc_address_high
    cmp #$10
    bcc skip_wraparound_13e5
    lda #$0c
    sta crtc_address_high
skip_wraparound_13e5:
skip_page_13e5:
    jsr set_crtc_address
    jsr plot_objects_on_right_edge
    jsr to_plot_mines_on_right_edge
    jsr update_jet_pack
skip_scrolling_screen_right:
    lda player_swapping_sides_on_rope ; Zero if player is not swapping sides on rope
    beq not_swapping_sides_13f6
    rts
not_swapping_sides_13f6:
    lda player_stance
    cmp #$02                         ; STANCE_CRAWLING
    beq to_crawl_right
    jmp move_player_right
to_crawl_right:
    jmp crawl_right

consider_moving_left:
    lda player_stance
    cmp #$02                         ; STANCE_CRAWLING
    bne not_crawling_1423
    inc climbing_or_crawling_cooldown
    lda climbing_or_crawling_cooldown
    and #$01
    beq is_crawling_1411             ; Only crawl one frame in two
    rts
is_crawling_1411:
    jsr get_left_of_player_screen_address
    jsr get_player_screen_address_high_after_subtraction
    sta screen_address_high
    ldx #$10
    jsr check_for_vertical_obstacle_with_X ; check_for_obstacle_with_X
    cpx #$1f
    beq consider_scrolling_left
    rts
not_crawling_1423:
    jsr check_for_obstacle_to_left_of_player
    sta obstacle_pixel_value
    cpx #$20
    beq no_obstacle_144b
    cmp #$09                         ; 1001
    bne check_left_obstacle
    jsr find_hold_on_rope_right      ; Move player up until fully holding rope
    jmp no_obstacle_144b
check_left_obstacle:
    stx obstacle_y_position
    jsr check_for_player_collision_with_mines_to_left
    jsr consider_collecting_object_to_left ; Leaves if object collected
    ldx obstacle_y_position
    cpx #$18
    bcc leave_144a
    jsr consider_moving_player_up_sloping_ground ; Leaves if obstacle above player
    jmp consider_scrolling_left
leave_144a:
    rts
no_obstacle_144b:
    lda player_stance
    cmp #$03                         ; STANCE_CLIMBING
    bne consider_scrolling_left
    sec
    lda player_screen_address_low
    sbc #$10
    sta screen_address_low
    jsr get_player_screen_address_high_after_subtraction
    sta screen_address_high
    jsr check_for_vertical_obstacle
    cpx #$20
    beq consider_scrolling_left
    rts

consider_scrolling_left:
    lda player_x
    cmp #$04
    bne not_at_left_edge
    rts
not_at_left_edge:
    cmp #$10
    bcs not_at_left_1473
    jmp skip_scrolling_left
not_at_left_1473:
    cmp #$f0
    bcc not_at_right_147a
    jmp skip_scrolling_left
not_at_right_147a:
    lda #$02
    sta screen_was_scrolled          ; Set to indicate screen was scrolled left
    sec
    lda screen_start_address_low
    sbc #$08
    sta screen_start_address_low
    bcs skip_page_1493
    dec screen_start_address_high
    lda screen_start_address_high
    cmp #$60
    bcs skip_wraparound_1493
    lda #$7f
    sta screen_start_address_high
skip_wraparound_1493:
skip_page_1493:
    jsr variable_delay
    dec left_edge_x_fraction
    lda left_edge_x_fraction
    cmp #$ff
    bne not_next_tile_left_14ad
    lda #$03
    sta left_edge_x_fraction
    sec
    lda left_edge_tile_address_low
    sbc #$04
    sta left_edge_tile_address_low
    bcs skip_page_14ad
    dec left_edge_tile_address_high
skip_page_14ad:
not_next_tile_left_14ad:
    lda screen_start_address_low
    sta screen_address_low
    lda screen_start_address_high
    sta screen_address_high
    lda left_edge_x_fraction
    sta $77                          ; tile_x_fraction
    lda left_edge_tile_address_low
    sta $74                          ; tile_address_low
    lda left_edge_tile_address_high
    sta $75                          ; tile_address_high
    jsr plot_column_of_tiles
    lda level
    bne skip_stars_14d2
    lda left_edge_tile_address_low
    clc
    adc left_edge_x_fraction
    ldx #$00
    jsr consider_plotting_star
skip_stars_14d2:
    dec right_edge_x_fraction
    lda right_edge_x_fraction
    cmp #$ff
    bne not_next_tile_right_14e9
    lda #$03
    sta right_edge_x_fraction
    sec
    lda right_edge_tile_address_low
    sbc #$04
    sta right_edge_tile_address_low
    bcs skip_page_14e9
    dec right_edge_tile_address_high
skip_page_14e9:
not_next_tile_right_14e9:
    jsr plot_objects_on_left_edge
    jsr to_plot_mines_on_left_edge
    jsr update_jet_pack
    dec crtc_address_low
    lda crtc_address_low
    cmp #$ff
    bne skip_page_1506
    dec crtc_address_high
    lda crtc_address_high
    cmp #$0c
    bcs skip_wraparound_1506
    lda #$0f
    sta crtc_address_high
skip_wraparound_1506:
skip_page_1506:
    jsr set_crtc_address
skip_scrolling_left:
    lda player_swapping_sides_on_rope ; Zero if player is not swapping sides on rope
    beq not_swapping_sides_150e
    rts
not_swapping_sides_150e:
    lda player_stance
    cmp #$02                         ; STANCE_CRAWLING
    beq to_crawl_left
    jmp move_player_left
to_crawl_left:
    jmp crawl_left

scroll_up:
scroll_up_loop:
    jsr wait_for_vsync
    sec
    lda crtc_address_low
    sbc #$20
    sta crtc_address_low
    bcs skip_page_1532
    dec crtc_address_high
    lda crtc_address_high
    cmp #$0c
    bcs skip_wraparound_1532
    lda #$0f
    sta crtc_address_high
skip_wraparound_1532:
skip_page_1532:
    jsr set_crtc_address
    dec screen_start_address_high
    lda screen_start_address_high
    cmp #$60
    bcs skip_wraparound_screen_1541
    lda #$7f
    sta screen_start_address_high
skip_wraparound_screen_1541:
    dec player_screen_address_high
    lda player_screen_address_high
    cmp #$60
    bcs skip_wraparound_player_154d
    lda #$7f
    sta player_screen_address_high
skip_wraparound_player_154d:
    jsr plot_lift
    lda vertical_scroll_count
    bne skip_initialising_scroll_up
    clc
    lda left_edge_tile_address_low
    adc #$03
    sta row_tile_address_low
    lda left_edge_tile_address_high
    adc #$01
    sta row_tile_address_high
    lda #$03
    sta row_tile_y_fraction
    lda #$01
    sta row_tile_nibble
skip_initialising_scroll_up:
    lda row_tile_y_fraction
    sta $77                          ; tile_y_fraction
    lda row_tile_address_low
    sta $74                          ; tile_address_low
    lda row_tile_address_high
    sta $75                          ; tile_address_high
    lda screen_start_address_low
    sta screen_address_low
    lda screen_start_address_high
    sta screen_address_high
    lda row_tile_nibble
    and #$01
    sta tile_nibble
    jsr plot_row_of_tiles
    dec row_tile_y_fraction
    lda row_tile_y_fraction
    cmp #$ff
    bne not_next_tile_up
    lda #$03
    sta row_tile_y_fraction
    inc row_tile_nibble
    lda row_tile_nibble
    and #$01
    beq not_next_byte_159c
    dec row_tile_address_low
not_next_byte_159c:
not_next_tile_up:
    inc vertical_scroll_count
    lda vertical_scroll_count
    cmp #$20
    beq finished_scrolling_up
    jmp scroll_up_loop
finished_scrolling_up:
    lda #$00
    sta vertical_scroll_count
    inc left_edge_tile_address_high
    inc right_edge_tile_address_high
    jmp add_lift_to_level

scroll_down:
scroll_down_loop:
    jsr wait_for_vsync
    clc
    lda crtc_address_low
    adc #$20
    sta crtc_address_low
    bcc skip_wraparound_crtc         ; skip_page_crtc
    inc crtc_address_high
skip_page_crtc:
    lda crtc_address_high
    cmp #$10
    bcc skip_wraparound_crtc
    lda #$0c
    sta crtc_address_high
skip_wraparound_crtc:
    jsr set_crtc_address
    inc screen_start_address_high
    bpl skip_wraparound_screen_15d5
    lda #$60
    sta screen_start_address_high
skip_wraparound_screen_15d5:
    inc player_screen_address_high
    bpl skip_wraparound_player_15dd
    lda #$60
    sta player_screen_address_high
skip_wraparound_player_15dd:
    jsr plot_lift
    lda vertical_scroll_count
    bne skip_initialising_scroll_down
    lda left_edge_tile_address_low
    sta row_tile_address_low
    sec
    lda left_edge_tile_address_high
    sbc #$01
    sta row_tile_address_high
    lda #$00
    sta row_tile_y_fraction
    lda #$00
    sta row_tile_nibble
skip_initialising_scroll_down:
    lda row_tile_y_fraction
    sta $77                          ; tile_y_fraction
    lda row_tile_address_low
    sta $74                          ; tile_address_low
    lda row_tile_address_high
    sta $75                          ; tile_address_high
    lda screen_start_address_low
    sta screen_address_low
    clc
    lda screen_start_address_high
    adc #$1f
    bpl skip_wraparound_1611
    sec
    sbc #$20
skip_wraparound_1611:
    sta screen_address_high
    lda row_tile_nibble
    and #$01
    sta tile_nibble
    jsr plot_row_of_tiles
    inc row_tile_y_fraction
    lda row_tile_y_fraction
    cmp #$04
    bne not_next_tile_down
    lda #$00
    sta row_tile_y_fraction
    inc row_tile_nibble
    lda row_tile_nibble
    and #$01
    bne not_next_byte_1632
    inc row_tile_address_low
not_next_byte_1632:
not_next_tile_down:
    inc vertical_scroll_count
    lda vertical_scroll_count
    cmp #$20
    beq finished_scrolling_down
    jmp scroll_down_loop
finished_scrolling_down:
    lda #$00
    sta vertical_scroll_count
    dec left_edge_tile_address_high
    dec right_edge_tile_address_high
    jmp add_lift_to_level

plot_lift:
    lda player_screen_address_low
    sta screen_address_low
    sec
    lda player_screen_address_high
    sbc #$04
    cmp #$60
    bcs skip_wraparound_1658
    clc
    adc #$20
skip_wraparound_1658:
    sta screen_address_high
    lda #$00                         ; &5e00 = tile_sprite_lift
    sta $72                          ; sprite_address_low
    lda #$5e
    sta $73                          ; sprite_address_high
    ldx #$04
    ldy #$1f
    jsr plot_vertically_flipped_sprite ; Plot top of lift
    jsr plot_player_standing         ; Plot player
    clc
    lda player_screen_address_low
    adc #$18
    sta screen_address_low
    lda player_screen_address_high
    adc #$00
    bpl skip_wraparound_167b
    lda #$60
skip_wraparound_167b:
    sta screen_address_high
    ldx #$01                         ; &0101 = sprite_space + 1
    stx $72                          ; sprite_address_low
    stx $73                          ; sprite_address_high
    ldy #$20
    jsr plot_sprite                  ; Clear right side of player
    lda player_screen_address_low
    sta screen_address_low
    clc
    jsr get_bottom_of_player_screen_address
    lda #$00                         ; &5e00 = tile_sprite_lift
    sta $72                          ; sprite_address_low
    lda #$5e
    sta $73                          ; sprite_address_high
    ldx #$04
    ldy #$20
    jmp plot_sprite                  ; Plot bottom of lift

consider_using_lift:
    jsr set_colour_zero_to_black
    lda player_x
    cmp #$05
    bcc in_lift
    cmp #$f8
    bcs in_lift
    rts
in_lift:
    ldy #$18                         ; 6 * 4  # Check top of chain on right
    ldx #$04                         ; 1 * 4 + 0  # Check top of chain on left
    lda lift_direction               ; Zero if moving up, non-zero if moving down
    beq check_for_end_of_lift_chain
    ldy #$1b                         ; 6 * 4 + 3  # Check bottom of chain on right
    ldx #$07                         ; 1 * 4 + 0  # Check bottom of chain on left
check_for_end_of_lift_chain:
    lda player_direction             ; Zero if facing right, non-zero if facing left
    bne is_facing_left_16c4
is_facing_right_16bd:
    lda (left_edge_tile_address),y
    cmp #$33                         ; NIBBLE_CHAIN | NIBBLE_CHAIN * &10
    beq can_use_lift
    rts
is_facing_left_16c4:
    txa
    tay
    lda (left_edge_tile_address),y
    cmp #$33                         ; NIBBLE_CHAIN | NIBBLE_CHAIN * &10
    beq can_use_lift
    rts
can_use_lift:
    lda #$0f                         ; TILE_SURFACE_WALL_RIGHT
    ldx #$10                         ; TILE_SURFACE_WALL_LEFT
    ldy #$16                         ; TILE_ROPE
    jsr set_surface_defence_tiles    ; Use surface and rope for Surface Defence sectors two and three
    lda #$14                         ; TILE_PLATFORM_BOTTOM
    sta $052d                        ; level_tiles_translation_table + &00 + &d  # Use platform for Surface Defence sectors two and three
    lda $c0                          ; objects_carried + &0 (OBJECT_PASSCARD)
    bne has_pass
    rts
has_pass:
    lda #$00
    sta $57                          ; unused  # Unused variable
    dec $c0                          ; objects_carried + &0 (OBJECT_PASSCARD)
    lda #$ff
    sta $26e8                        ; sound_block_0 + 3 (volume high)
    ldx #$f4
    ldy #$00
    lda #$0d
    jsr play_sound_volume_X_pitch_Y_duration_A_on_channel_two
    lda #$00
    sta $26e8                        ; sound_block_0 + 3 (volume high)
    lda player_x
    sta initial_player_x
    pla                              ; Remove returns to check_for_player_input and
    pla                              ; consider_checking_for_player_input from stack
    pla                              ; i.e. leave to main game loop on next return
    pla
    lda #$00                         ; STANCE_STANDING
    sta obstacle_pixel_value
    sta player_stance
    lda player_direction             ; Zero if facing right, non-zero if facing left
    bne is_facing_left_1717
is_facing_right_170b:
    ldy #$19                         ; 6 * 4 + 1  # Remove lift on right
    lda #$33                         ; NIBBLE_CHAIN | NIBBLE_CHAIN * &10
    sta (left_edge_tile_address),y
    iny
    sta (left_edge_tile_address),y
    jmp change_level
is_facing_left_1717:
    ldy #$05                         ; 1 * 4 + 1  # Remove lift on left
    lda #$33                         ; NIBBLE_CHAIN | NIBBLE_CHAIN * &10
    sta (left_edge_tile_address),y
    iny
    sta (left_edge_tile_address),y
change_level:
    lda lift_direction               ; Zero if moving up, non-zero if moving down
    bne move_down_a_level
move_up_a_level:
    dec level
    jsr to_initialise_level
    jsr set_level_specific_tiles
    ldy level
    lda level_offsets_table,y
    sta level_sprite_base
    jmp scroll_up
move_down_a_level:
    inc level
    jsr to_initialise_level
    jsr set_level_specific_tiles
    lda level
    cmp #$0b
    bne not_missile_factor_sector_three
    ldx #$36                         ; TILE_SPACESHIP_END_RIGHT
    stx $0555                        ; level_tiles_translation_table + &30 + &5  # Use spaceship for Missile Factor sector three
    inx                              ; &37 : TILE_SPACESHIP_END_LEFT
    stx $0557                        ; level_tiles_translation_table + &30 + &7
not_missile_factor_sector_three:
    tay
    lda level_offsets_table,y
    sta level_sprite_base
    jsr scroll_down
    jmp to_consider_saving_position

add_lift_to_level:
    lda player_direction             ; Zero if facing right, non-zero if facing left
    bne is_facing_left_1769
is_facing_right_175d:
    ldy #$19                         ; 6 * 4 + 1  # Add lift on right
    lda #$02                         ; NIBBLE_LIFT_BOTTOM | NIBBLE_SPACE * &10
    sta (left_edge_tile_address),y
    iny
    lda #$31                         ; NIBBLE_LIFT_TOP | NIBBLE_CHAIN * &10
    sta (left_edge_tile_address),y
    rts
is_facing_left_1769:
    ldy #$05                         ; 1 * 4 + 1  # Add lift on left
    lda #$02                         ; NIBBLE_LIFT_BOTTOM | NIBBLE_SPACE * &10
    sta (left_edge_tile_address),y
    iny
    lda #$31                         ; NIBBLE_LIFT_TOP | NIBBLE_CHAIN * &10
    sta (left_edge_tile_address),y
    lda level
    bne leave_177e                   ; Is the player moving up into the left of level 0?
    jsr to_display_level_2739        ; If so, redraw level to plot objects; this is the only
    jmp plot_player_standing         ; level in which objects are visible from the lift
leave_177e:
    rts

consider_checking_for_player_input:
    lda $c2                          ; objects_carried + &2 (OBJECT_JET_PACK)  # Non-zero if player is in jet pack
    bne not_jumping_or_falling
    lda player_jumping_or_falling
    beq not_jumping_or_falling
    rts
not_jumping_or_falling:
    jsr update_jet_pack
    lda os_most_recently_pressed_key
    jsr check_for_player_input       ; Leaves if player moved left or right
    lda os_first_pressed_key
    jsr check_for_player_input       ; Leaves if player moved left or right
    lda player_stance
    bne leave_179d                   ; Leave if not STANCE_STANDING
    lda player_frame
    bne plot_player_standing         ; Replot player as standing if previously walking
leave_179d:
    rts
plot_player_standing:
    lda #$ff
    sta player_frame                 ; Will become zero at &1d21 or &1dec
plot_player_facing_direction:
    jsr get_player_screen_address
    lda player_direction             ; Zero if facing right, non-zero if facing left
    bne to_plot_player_facing_left
    jmp plot_player_facing_right
to_plot_player_facing_left:
    jmp plot_player_facing_left

check_for_player_input:
    cmp #$c2                         ; X
    bne right_not_pressed            ; x_not_pressed
    lda $c2                          ; objects_carried + &2 (OBJECT_JET_PACK)  # Non-zero if player is in jet pack
    beq not_in_jet_pack_right
    lda #$01
    sta jump_direction
    jsr leave_if_player_is_jumping_or_falling ; Leaves if player is jumping or falling
not_in_jet_pack_right:
    pla                              ; Leave consider_checking_for_player_input on next return
    pla
    lda player_stance
    cmp #$01                         ; STANCE_KNEELING
    beq leave_17c9                   ; Can't move when kneeling
    jmp consider_moving_right
leave_17c9:
    rts
right_not_pressed:
    cmp #$e1                         ; Z
    bne z_not_pressed
    lda $c2                          ; objects_carried + &2 (OBJECT_JET_PACK)  # Non-zero if player is in jet pack
    beq not_in_jet_pack_left
    lda #$02
    sta jump_direction
    jsr leave_if_player_is_jumping_or_falling ; Leaves if player is jumping or falling
not_in_jet_pack_left:
    pla                              ; Leave consider_checking_for_player_input on next return
    pla
    lda player_stance
    cmp #$01                         ; STANCE_KNEELING
    beq leave_17c9                   ; Can't move when kneeling
    jmp consider_moving_left
z_not_pressed:
    cmp #$c8                         ; '
    bne up_not_pressed
    lda #$00
    sta lift_direction               ; Set to zero to indicate moving up
    jsr consider_using_lift
    jsr consider_climbing_up         ; Leaves if player is climbing
    lda player_recent_up
    bne leave_17c9                   ; Zero if up not recently pressed
    lda #$01
    sta player_recent_up             ; Set to non-zero to suppress auto-repeat
    jmp consider_stance_up
up_not_pressed:
    cmp #$e8                         ; /
    bne down_not_pressed
    lda #$01
    sta lift_direction               ; Set to non-zero to indicate moving down
    jsr consider_using_lift
    jsr consider_climbing_down       ; Leaves if player is climbing
    lda player_recent_down
    beq not_recent_down              ; Zero if down not recently pressed
leave_180f:
    rts
not_recent_down:
    lda $c2                          ; objects_carried + &2 (OBJECT_JET_PACK)  # Non-zero if player is in jet pack
    bne leave_180f
    lda #$01
    sta player_recent_down           ; Set to non-zero to suppress auto-repeat
    jmp consider_stance_down
down_not_pressed:
    cmp #$c1                         ; A
    bne a_not_pressed
    jmp to_wrist_terminal_screen
a_not_pressed:
    cmp #$c5                         ; J
    bne j_not_pressed_1829
    jmp to_jet_pack_screen
j_not_pressed_1829:
check_for_player_jumping:
    cmp #$c9                         ; ENTER
    bne jump_not_pressed
    lda player_stance
    bne leave_17c9                   ; Leave if not STANCE_STANDING
    lda maximum_jump_timer
    sta jump_timer
    lda $c2                          ; objects_carried + &2 (OBJECT_JET_PACK)  # Non-zero if player is in jet pack
    beq not_in_jet_pack
    jsr update_jet_pack
    lda #$02
    sta jump_timer
    rts
not_in_jet_pack:
    lda #$01
    sta jump_direction               ; Set to one to indicate jumping right by default
    lda #$c2                         ; X
    cmp os_most_recently_pressed_key
    beq leave_1863
    cmp os_first_pressed_key
    beq leave_1863
    inc jump_direction               ; Set to two to indicate jumping left
    lda #$e1                         ; Z
    cmp os_most_recently_pressed_key
    beq leave_1863
    cmp os_first_pressed_key
    beq leave_1863
    lda #$00
    sta jump_direction               ; Set to zero to indicate not jumping horizontally
    dec jump_timer                   ; Vertical jumps are not as high
    dec jump_timer
leave_1863:
    rts
check_for_player_firing_and_other_non_movement_actions:
jump_not_pressed:
    cmp #$d8                         ; ]
    bne fire_not_pressed
    lda player_recent_fire
    bne fire_not_pressed             ; Zero if fire not recently pressed
    lda #$01
    sta player_recent_fire           ; Set to non-zero to suppress auto-repeat
    jmp to_fire_blaster
fire_not_pressed:
    cmp #$f0                         ; ESCAPE
    bne escape_not_pressed
    jsr set_colour_zero_to_black
    jmp to_game_over_screen
escape_not_pressed:
    cmp #$a0                         ; f0
    bne f0_not_pressed_1886
    lda #$01
    sta os_sound_suppression         ; Set to non-zero to suppress sound
f0_not_pressed_1886:
    cmp #$f1                         ; f1
    bne f1_not_pressed_188f
    lda #$00
    sta os_sound_suppression         ; Set to zero to permit sound
f1_not_pressed_188f:
    cmp #$e9                         ; COPY
    bne copy_not_pressed
wait_for_delete:
    lda os_most_recently_pressed_key
    cmp #$d9                         ; DELETE
    bne wait_for_delete
copy_not_pressed:
    cmp #$b2                         ; D
    bne d_not_pressed
    jmp to_drop_mine
d_not_pressed:
    cmp #$e0                         ; TAB
    bne tab_not_pressed
    pla                              ; Leave consider_checking_for_player_input or
    pla                              ; check_for_player_input_other_than_movement on next return
    jmp to_lose_life
tab_not_pressed:
    cmp #$b6                         ; O
    bne o_not_pressed
    jmp exit_jet_pack
o_not_pressed:
    rts

check_for_player_input_other_than_movement:
    lda os_most_recently_pressed_key
    jsr check_for_player_firing_and_other_non_movement_actions
    lda os_first_pressed_key
    jsr check_for_player_firing_and_other_non_movement_actions
    lda $c2                          ; objects_carried + &2 (OBJECT_JET_PACK)  # Non-zero if player is in jet pack
    bne in_jet_pack_or_on_ground
    lda player_jumping_or_falling
    beq in_jet_pack_or_on_ground
    rts
in_jet_pack_or_on_ground:
    lda os_most_recently_pressed_key
    jsr check_for_player_jumping
    lda os_first_pressed_key
    jsr check_for_player_jumping
    rts

plot_column_of_tiles:
    lda #$00
    sta $76                          ; tile_y
plot_column_of_tiles_loop:
    lda $76                          ; tile_y
    lsr a
    tay
    lda $76                          ; tile_y
    and #$01
    bne use_top_nibble_18e4
use_bottom_nibble_18dd:
    lda ($74),y                      ; tile_address
    and #$0f
    jmp translate_nibble_18e9
use_top_nibble_18e4:
    lda ($74),y                      ; tile_address
    jsr get_top_nibble
translate_nibble_18e9:
    clc
    adc level_sprite_base
    tay
    lda level_tiles_translation_table,y
    tay
    asl a
    tax
    clc
    lda tile_sprites_addresses_table,x
    and #$f8
    sta $72                          ; sprite_address_low
    lda tile_sprites_addresses_table,x
    and #$03
    sta $59                          ; flip
    lda $0f81,x                      ; tile_sprites_addresses_table + 1
    sta $73                          ; sprite_address_high
    lda $77                          ; tile_x_fraction
    cmp #$02
    bcc skip_mirroring_1936
    cpx #$1c                         ; TILE_SURFACE_WALL * 2
    beq is_mirrored_horizontally
    cpx #$64                         ; TILE_MISSILE_BODY * 2
    beq is_mirrored_horizontally
    cpx #$22                         ; TILE_SURFACE_WALL_TOP * 2
    beq is_mirrored_horizontally
    cpx #$24                         ; TILE_SURFACE_WALL_BOTTOM * 2
    beq is_mirrored_horizontally
    cpx #$26                         ; TILE_PLATFORM_TOP * 2
    beq is_mirrored_horizontally
    cpx #$46                         ; TILE_COMPUTER * 2
    beq is_mirrored_horizontally
    cpx #$28                         ; TILE_PLATFORM_BOTTOM * 2
    beq is_mirrored_horizontally
    cpx #$10                         ; TILE_PIPE_VERTICAL * 2
    beq is_mirrored_horizontally
    jmp skip_mirroring_1936
is_mirrored_horizontally:
    lda $59                          ; flip
    ora #$02
    sta $59                          ; flip
skip_mirroring_1936:
    ldx #$00
    lda $59                          ; flip
    cmp #$02                         ; FLIP_HORIZONTALLY
    bcc not_horizontally_flipped
horizontally_flipped:
    lda #$03
    sec
    sbc $77                          ; tile_x_fraction
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc $72                          ; sprite_address_low
    sta $72                          ; sprite_address_low
    lda $59                          ; flip
    cmp #$02                         ; FLIP_HORIZONTALLY
    bne to_plot_horizontally_and_vertically_flipped_column
    jmp plot_horizontally_flipped_column
to_plot_horizontally_and_vertically_flipped_column:
    jmp plot_horizontally_and_vertically_flipped_column
not_horizontally_flipped:
    lda $77                          ; tile_x_fraction
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc $72                          ; sprite_address_low
    sta $72                          ; sprite_address_low
    lda $59                          ; flip
    bne plot_vertically_flipped_column
    ldy #$00
plot_unflipped_column_loop:
    lda ($72),y                      ; sprite_address
    sta (screen_address),y
    iny
    cpy #$08
    bne plot_unflipped_column_loop
    clc
    lda $72                          ; sprite_address_low
    adc #$08
    sta $72                          ; sprite_address_low
    ldy #$00
    inc screen_address_high
    bpl skip_wraparound_1985
    lda #$60
    sta screen_address_high
skip_wraparound_1985:
    inx
    cpx #$04
    bne plot_unflipped_column_loop
consider_next_tile_in_column:
    inc $76                          ; tile_y
    lda $76                          ; tile_y
    cmp #$08
    beq leave_1995
    jmp plot_column_of_tiles_loop
leave_1995:
    rts

plot_vertically_flipped_column:
    ldy #$00
    clc
    lda $72                          ; sprite_address_low
    adc #$1f
    sta $19a6                        ; vertically_flipped_sprite_address_low
    lda $73                          ; sprite_address_high
    sta $19a7                        ; vertically_flipped_sprite_address_high
plot_vertically_flipped_column_loop:
    lda $3000
;     actually LDA vertically_flipped_sprite_address
    sta ($70),y
    dec $19a6                        ; vertically_flipped_sprite_address_low
    iny
    cpy #$08
    bne plot_vertically_flipped_column_loop
    ldy #$00
    inc screen_address_high
    bpl skip_wraparound_19bc
    lda #$60
    sta screen_address_high
skip_wraparound_19bc:
    inx
    cpx #$04
    bne plot_vertically_flipped_column_loop
    jmp consider_next_tile_in_column

plot_horizontally_flipped_column:
    ldy #$00
    sty $78                          ; tile_y_fraction
plot_horizontally_flipped_column_loop:
    lda ($72),y                      ; sprite_address
    tax
    lda flip_table,x
    sta (screen_address),y
    iny
    cpy #$08
    bne plot_horizontally_flipped_column_loop
    clc
    lda $72                          ; sprite_address_low
    adc #$08
    sta $72                          ; sprite_address_low
    ldy #$00
    inc screen_address_high
    bpl skip_wraparound_19e6
    lda #$60
    sta screen_address_high
skip_wraparound_19e6:
    inc $78                          ; tile_y_fraction
    lda $78                          ; tile_y_fraction
    cmp #$04
    bne plot_horizontally_flipped_column_loop
    jmp consider_next_tile_in_column

plot_horizontally_and_vertically_flipped_column:
    ldy #$00
    sty $78                          ; tile_y_fraction
    clc
    lda $72                          ; sprite_address_low
    adc #$1f
    sta $1a03                        ; horizontally_and_vertically_flipped_sprite_address_low
    lda $73                          ; sprite_address_high
    sta $1a04                        ; horizontally_and_vertically_flipped_sprite_address_high
plot_horizontally_and_vertically_flipped_column_loop:
    lda $3000
;     actually LDA horizontally_and_vertically_flipped_sprite_address
    tax
    lda flip_table,x
    sta (screen_address),y
    dec $1a03                        ; horizontally_and_vertically_flipped_sprite_address_low
    iny
    cpy #$08
    bne plot_horizontally_and_vertically_flipped_column_loop
    ldy #$00
    inc screen_address_high
    bpl skip_wraparound_1a1d
    lda #$60
    sta screen_address_high
skip_wraparound_1a1d:
    inc $78                          ; tile_y_fraction
    lda $78                          ; tile_y_fraction
    cmp #$04
    bne plot_horizontally_and_vertically_flipped_column_loop
    jmp consider_next_tile_in_column

plot_row_of_tiles:
    lda #$00
    sta $76                          ; tile_x
plot_row_of_tiles_loop:
    ldy #$00
    lda tile_nibble
    beq use_bottom_nibble_1a3a
use_top_nibble_1a32:
    lda ($74),y                      ; tile_address
    jsr get_top_nibble
    jmp translate_nibble_1a3e
use_bottom_nibble_1a3a:
    lda ($74),y                      ; tile_address
    and #$0f
translate_nibble_1a3e:
    clc
    adc level_sprite_base
    tay
    lda level_tiles_translation_table,y
    tay
    asl a
    tax
    clc
    lda tile_sprites_addresses_table,x
    and #$f8
    sta $72                          ; sprite_address_low
    lda tile_sprites_addresses_table,x
    and #$03
    sta $7a                          ; flip
    lda $0f81,x                      ; tile_sprites_addresses_table + 1
    sta $73                          ; sprite_address_high
    stx tile_times_two
    ldx #$00
    lda $7a                          ; flip
    and #$01                         ; FLIP_VERTICALLY
    beq not_vertically_flipped
    lda $77                          ; tile_y_fraction
    eor #$03
    asl a
    asl a
    asl a
    clc
    adc $72                          ; sprite_address_low
    sta $72                          ; sprite_address_low
    lda $7a                          ; flip
    ldy #$00
    cmp #$01                         ; FLIP_VERTICALLY
    bne to_plot_horizontally_and_vertically_flipped_row
    jmp plot_vertically_flipped_row
to_plot_horizontally_and_vertically_flipped_row:
    jmp plot_horizontally_and_vertically_flipped_row
not_vertically_flipped:
    lda $77                          ; tile_y_fraction
    asl a
    asl a
    asl a
    clc
    adc $72                          ; sprite_address_low
    sta $72                          ; sprite_address_low
    lda $7a                          ; flip
    bne plot_horizontally_flipped_row
plot_unflipped_row:
    ldy #$00
plot_unflipped_row_loop:
    lda ($72),y                      ; sprite_address
    sta (screen_address),y
    iny
    cpy #$08
    bne plot_unflipped_row_loop
    clc
    lda screen_address_low
    adc #$08
    sta screen_address_low
    bcc skip_wraparound_1aaa
    inc screen_address_high
    bpl skip_page_1aaa
    lda #$60
    sta screen_address_high
skip_wraparound_1aaa:
skip_page_1aaa:
    ldy #$00
    jsr consider_mirroring_tile_in_row
    clc
    lda $72                          ; sprite_address_low
    adc #$20
    sta $72                          ; sprite_address_low
    inx
    cpx #$04
    bne plot_unflipped_row_loop
consider_next_tile_in_row:
    clc
    lda $74                          ; tile_address_low
    adc #$04
    sta $74                          ; tile_address_low
    inc $76                          ; tile_x
    lda $76                          ; tile_x
    cmp #$08
    beq leave_1acd
    jmp plot_row_of_tiles_loop       ; plot_row_of_tiles
leave_1acd:
    rts

plot_horizontally_flipped_row:
    clc
    lda $72                          ; sprite_address_low
    adc #$60
    sta $72                          ; sprite_address_low
    ldy #$00
    sty $78                          ; tile_x_fraction
plot_horizontally_flipped_row_loop:
    lda ($72),y                      ; sprite_address
    tax
    lda flip_table,x
    sta (screen_address),y
    iny
    cpy #$08
    bne plot_horizontally_flipped_row_loop
    sec
    lda $72                          ; sprite_address_low
    sbc #$20
    sta $72                          ; sprite_address_low
    ldy #$00
    clc
    lda screen_address_low
    adc #$08
    sta screen_address_low
    bcc skip_page_1b00
    inc screen_address_high
    bpl skip_wraparound_1b00
    lda #$60
    sta screen_address_high
skip_wraparound_1b00:
skip_page_1b00:
    inc $78                          ; tile_x_fraction
    lda $78                          ; tile_x_fraction
    cmp #$04
    bne plot_horizontally_flipped_row_loop
    jmp consider_next_tile_in_row

plot_vertically_flipped_row:
    clc
    lda $72                          ; sprite_address_low
    adc #$07
    sta $1b19                        ; vertically_flipped_sprite_address_low
    lda $73                          ; sprite_address_high
    sta $1b1a                        ; vertically_flipped_sprite_address_high
plot_vertically_flipped_row_loop:
    lda $3000
;     actually LDA vertically_flipped_sprite_address
    sta ($70),y
    dec $1b19                        ; vertically_flipped_sprite_address_low
    iny
    cpy #$08
    bne plot_vertically_flipped_row_loop
    ldy #$00
    clc
    lda screen_address_low
    adc #$08
    sta screen_address_low
    bcc skip_page_1b38
    inc screen_address_high
    bpl skip_wraparound_1b38
    lda #$60
    sta screen_address_high
skip_wraparound_1b38:
skip_page_1b38:
    jsr consider_mirroring_tile_in_row
    clc
    lda $1b19                        ; vertically_flipped_sprite_address_low
    adc #$28
    sta $1b19                        ; vertically_flipped_sprite_address_low
    inx
    cpx #$04
    bne plot_vertically_flipped_row_loop
    jmp consider_next_tile_in_row

plot_horizontally_and_vertically_flipped_row:
    sty $78                          ; tile_x_fraction
    clc
    lda $72                          ; sprite_address_low
    adc #$67
    sta $1b5c                        ; horizontally_and_vertically_flipped_sprite_address_low
    lda $73                          ; sprite_address_high
    sta $1b5d                        ; horizontally_and_vertically_flipped_sprite_address_high
plot_horizontally_and_vertically_flipped_row_loop:
    lda $3000
;     actually LDA horizontally_and_vertically_flipped_sprite_address
    tax
    lda flip_table,x
    sta ($70),y
    dec $1b5c                        ; horizontally_and_vertically_flipped_sprite_address_low
    iny
    cpy #$08
    bne plot_horizontally_and_vertically_flipped_row_loop
    sec
    clc
    lda $1b5c                        ; horizontally_and_vertically_flipped_sprite_address_low
    sbc #$17
    sta $1b5c                        ; horizontally_and_vertically_flipped_sprite_address_low
    ldy #$00
    clc
    lda screen_address_low
    adc #$08
    sta screen_address_low
    bcc skip_page_1b89
    inc screen_address_high
    bpl skip_wraparound_1b89
    lda #$60
    sta screen_address_high
skip_wraparound_1b89:
skip_page_1b89:
    inc $78                          ; tile_x_fraction
    lda $78                          ; tile_x_fraction
    cmp #$04
    bne plot_horizontally_and_vertically_flipped_row_loop
    jmp consider_next_tile_in_row

consider_mirroring_tile_in_row:
    cpx #$01
    bne skip_mirroring_1bba
    lda tile_times_two
    cmp #$64                         ; TILE_MISSILE_BODY * 2
    beq mirror_tile_in_row
    cmp #$1c                         ; TILE_SURFACE_WALL * 2
    beq mirror_tile_in_row
    cmp #$22                         ; TILE_SURFACE_WALL_TOP * 2
    beq mirror_tile_in_row
    cmp #$24                         ; TILE_SURFACE_WALL_BOTTOM * 2
    beq mirror_tile_in_row
    cmp #$26                         ; TILE_PLATFORM_TOP * 2
    beq mirror_tile_in_row
    cmp #$28                         ; TILE_PLATFORM_BOTTOM * 2
    beq mirror_tile_in_row
    cmp #$46                         ; TILE_COMPUTER * 2
    beq mirror_tile_in_row
    cmp #$10                         ; TILE_PIPE_VERTICAL * 2
    beq mirror_tile_in_row
skip_mirroring_1bba:
    rts
mirror_tile_in_row:
    inx
    stx $78                          ; tile_x_fraction
    pla                              ; Pull low byte of return address
    tax
    pla                              ; Pull high byte of return address and discard
    txa
    cmp #$3a                         ; &38 + 2  # &1b38 if called from plot_vertically_flipped_row
    beq is_vertically_flipped
    jmp plot_horizontally_flipped_row_loop
is_vertically_flipped:
    clc
    lda $1b19                        ; vertically_flipped_sprite_address_low
    adc #$08
    sta $1b5c                        ; horizontally_and_vertically_flipped_sprite_address_low
    lda $1b1a                        ; vertically_flipped_sprite_address_high
    sta $1b5d                        ; horizontally_and_vertically_flipped_sprite_address_high
    jmp plot_horizontally_and_vertically_flipped_row_loop

plot_vertically_flipped_sprite:
    lda #$ca                         ; DEX
    sta plot_sprite_next_byte_opcode
    lda #$78                         ; sprite_offset
    sta $1c6c                        ; plot_sprite_add_height_opcode + 1
    sty sprite_offset
    lda #$38                         ; SEC
    sta plot_sprite_next_column_carry_opcode
    ldy #$ff
    lda #$ea                         ; NOP
    sta plot_sprite_add_height_high_opcode
    sta $1c74                        ; plot_sprite_add_height_high_opcode + 1
    jmp plot_sprite_skipping_offset

plot_sprite:                         ; # Called with X = width, Y = height
    lda #$00
    sta sprite_offset
plot_sprite_skipping_offset:
    stx width
    sty height
    ldy #$00
    lda screen_address_low
    sta column_screen_address_low
    lda screen_address_high
    sta column_screen_address_high
    lda $72                          ; sprite_address_low
    sta plot_sprite_address_low
    lda $73                          ; sprite_address_high
    sta plot_sprite_address_high
plot_sprite_column_loop:
    ldx sprite_offset
plot_sprite_row_loop:
    lda $3000,x
;     actually LDA plot_sprite_address,X
    sta (screen_address_low),y
plot_sprite_next_byte_opcode:
    inx
;     also     DEX if vertically flipped
    cpx height
    beq next_column_1c49
    inc screen_address_low           ; Move down a row
    bne skip_page_1c2d
    inc screen_address_high
    bpl skip_wraparound_1c2d
    lda #$60
    sta screen_address_high
skip_page_1c2d:
skip_wraparound_1c2d:
    lda screen_address_low
    and #$07
    bne plot_sprite_row_loop
next_group_1c33:
    sec
    lda screen_address_low
    sbc #$08                         ; Move back to start of group
    sta screen_address_low
    bcs skip_page_1c3e
    dec screen_address_high
skip_page_1c3e:
    inc screen_address_high          ; Move down a group
    bpl plot_sprite_row_loop
    lda #$60
    sta screen_address_high
    jmp plot_sprite_row_loop
next_column_1c49:
    dec width
    bne move_to_next_column
    lda #$e8                         ; INX  # Reset plot_sprite for non-flipped plotting next time
    sta plot_sprite_next_byte_opcode
    lda #$77                         ; &77 ; height
    sta $1c6c                        ; plot_sprite_add_height_opcode + 1
    lda #$18                         ; CLC
    sta plot_sprite_next_column_carry_opcode
    lda #$69                         ; ADC  # &00
    sta plot_sprite_add_height_high_opcode
    lda #$00
    sta $1c74                        ; plot_sprite_add_height_high_opcode + 1
    rts
move_to_next_column:
plot_sprite_next_column_carry_opcode:
    clc
;     also     SEC if vertically flipped
    lda plot_sprite_address_low
plot_sprite_add_height_opcode:
    adc height
;     also     ADC &78 ; sprite_offset if vertically flipped
    sta plot_sprite_address_low
    lda plot_sprite_address_high
plot_sprite_add_height_high_opcode:
    adc #$00
;     also     NOP
;              NOP if vertically flipped
    sta plot_sprite_address_high
    clc
    lda column_screen_address_low
    adc #$08
    sta column_screen_address_low
    sta screen_address_low
    bcc skip_page_1c8b
    inc column_screen_address_high
    bpl skip_wraparound_1c8b
    lda #$60
    sta column_screen_address_high
skip_page_1c8b:
skip_wraparound_1c8b:
    lda column_screen_address_high
    sta screen_address_high
    jmp plot_sprite_column_loop

move_player_left:
    lda player_stance
    cmp #$03                         ; STANCE_CLIMBING
    bne not_climbing_1ce0
is_climbing:
    lda player_direction             ; Zero if facing right, non-zero if facing left
    bne swap_to_left_side_of_rope
    lda #$00                         ; STANCE_STANDING
    sta obstacle_pixel_value
    sta player_stance
    jsr get_player_screen_address
    lda #$40                         ; &0140 = tile_sprite_rope - &40
    sta $72                          ; sprite_address_low
    lda #$01
    sta $73                          ; sprite_address_high
    ldx #$03
    ldy #$20
    dec player_x
    jsr plot_sprite
    jmp move_player_left_four_pixels_and_replot
swap_to_left_side_of_rope:
    lda #$00
    sta player_direction             ; Set to zero to indicate facing right
    jsr get_player_screen_address
    ldx #$03
    ldy #$20
    lda #$01
    sta player_swapping_sides_on_rope ; Set to non-zero to indicate player swapping sides on rope
    jsr unplot_sprite                ; Unplot player on right of rope
    sec
    lda player_screen_address_low
    sbc #$10
    sta player_screen_address_low
    sta screen_address_low
    jsr get_player_screen_address_high_after_subtraction
    sta player_screen_address_high
    sta screen_address_high
    dec player_x
    jmp plot_player_climbing_facing_left
not_climbing_1ce0:
    dec player_x
    clc
    lda player_screen_address_low
    adc #$10
    sta screen_address_low
    lda player_screen_address_high
    adc #$00
    bpl skip_wraparound_1cf1
    lda #$60
skip_wraparound_1cf1:
    sta screen_address_high
    lda #$01                         ; &0101 = sprite_space + 1
    sta $73                          ; sprite_address_high
    ldx #$01
    stx $72                          ; sprite_address_low
    ldy #$20
    jsr to_plot_unflipped_player_274b
move_player_left_four_pixels_and_replot:
    jsr get_left_of_player_screen_address
    sta player_screen_address_low
    bcs skip_page_1d13
    dec player_screen_address_high
    lda player_screen_address_high
    cmp #$60
    bcs skip_wraparound_1d13
    lda #$7f
    sta player_screen_address_high
skip_wraparound_1d13:
skip_page_1d13:
    lda player_screen_address_high
    sta screen_address_high
plot_player_facing_left:
    lda #$01
    sta player_direction             ; Set to non-zero to indicate facing left
    lda obstacle_pixel_value
    cmp #$09                         ; 1001
    beq plot_player_climbing_facing_right ; Branch if player is on rope
    inc player_frame                 ; Animate player walking
    lda player_frame
    cmp #$06
    bne skip_wraparound_1d2d
    lda #$00
    sta player_frame
skip_wraparound_1d2d:
    asl a
    tax
    lda player_sprite_addresses_table,x
    sta $72                          ; sprite_address_low
    lda $0ff3,x                      ; player_sprite_addresses_table + 1
    sta $73                          ; sprite_address_high
    ldx #$03
    ldy #$20
    jsr consider_plotting_player_in_jet_pack ; Leaves if player is in jet pack
    jmp to_plot_unflipped_player_274b
plot_player_climbing_facing_right:
    jsr set_player_climbing
    jmp to_plot_unflipped_player_274b

set_player_climbing:
    lda #$00
    sta jump_timer                   ; Set to zero to indicate player not jumping upwards
    sta jump_direction               ; Set to zero to indicate player not jumping horizontally
    sta player_jumping_or_falling    ; Set to zero to indicate player not jumping or falling
    sta player_frame
    sta climbing_or_crawling_cooldown
    lda #$03                         ; STANCE_CLIMBING
    sta player_stance
    lda #$72                         ; &0720 = player_sprite_climbing
    sta $72                          ; sprite_address_low
    lda #$07
    sta $73                          ; sprite_address_high
    ldx #$03
    ldy #$20
    rts

move_player_right:
    lda player_stance
    cmp #$03                         ; STANCE_CLIMBING
    bne not_climbing_1db9
    lda player_direction             ; Zero if facing right, non-zero if facing left
    beq swap_to_right_side_of_rope
    lda #$00                         ; STANCE_STANDING
    sta obstacle_pixel_value
    sta player_stance
    inc player_x
    jsr get_player_screen_address
    lda #$80                         ; &0180 = tile_sprite_rope
    sta $72                          ; sprite_address_low
    lda #$01
    sta $73                          ; sprite_address_high
    ldx #$01
    ldy #$20
    jsr plot_sprite
    jmp move_player_right_four_pixels_and_replot
swap_to_right_side_of_rope:
    lda #$01
    sta player_direction             ; Set to non-zero to indicate facing left
    jsr get_player_screen_address
    ldx #$02
    ldy #$20
    lda #$01
    sta player_swapping_sides_on_rope ; Set to non-zero to indicate player swapping sides on rope
    jsr unplot_sprite                ; Unplot player on left of rope
    clc
    lda player_screen_address_low
    adc #$10
    sta player_screen_address_low
    sta screen_address_low
    lda player_screen_address_high
    adc #$00
    bpl skip_wraparound_1db0
    lda #$60
skip_wraparound_1db0:
    sta player_screen_address_high
    sta screen_address_high
    inc player_x
    jmp plot_player_climbing_facing_right
not_climbing_1db9:
    inc player_x
    jsr get_player_screen_address
    ldx #$01                         ; &0101 = sprite_space + 1
    stx $72                          ; sprite_address_low
    ldy #$20
    lda #$01
    sta $73                          ; sprite_address_high
    jsr to_plot_unflipped_player_274b
move_player_right_four_pixels_and_replot:
    clc
    lda player_screen_address_low
    adc #$08
    sta player_screen_address_low
    sta screen_address_low
    bcc skip_page_1dde
    inc player_screen_address_high
    bpl skip_wraparound_1dde
    lda #$60
    sta player_screen_address_high
skip_wraparound_1dde:
skip_page_1dde:
    lda player_screen_address_high
    sta screen_address_high
plot_player_facing_right:
    lda #$00
    sta player_direction             ; Set to zero to indicate facing right
    lda obstacle_pixel_value
    cmp #$09                         ; 1001
    beq plot_player_climbing_facing_left ; Branch if player is on rope
    inc player_frame                 ; Animate player walking
    lda player_frame
    cmp #$06
    bne L_1df8                       ; skip_wraparound
    lda #$00
skip_wraparound_1df6:
    sta player_frame
L_1df8:
    asl a
    tax
    lda player_sprite_addresses_table,x
    sta $72                          ; sprite_address_low
    lda $0ff3,x                      ; player_sprite_addresses_table + 1
    sta $73                          ; sprite_address_high
    ldx #$03
    ldy #$20
    jsr consider_plotting_player_in_jet_pack ; Leaves if player is in jet pack
    jmp to_plot_flipped_player
plot_player_climbing_facing_left:
    jsr set_player_climbing
    jmp to_plot_flipped_player

consider_plotting_player_in_jet_pack:
    lda $c2                          ; objects_carried + &2 (OBJECT_JET_PACK)  # Non-zero if player is in jet pack
    bne is_in_jet_pack
    rts
is_in_jet_pack:
    pla                              ; Leave move_player_left or move_player_right on
    pla                              ; next return, i.e. skip plotting player standing
plot_player_in_jet_pack:
    lda #$49                         ; &4920 = player_sprite_in_jet_pack
    sta $73                          ; sprite_address_low
    lda #$20
    sta $72                          ; sprite_address_high
    lda player_direction             ; Zero if facing right, non-zero if facing left
    bne is_unflipped_1e2a
is_flipped_1e27:
    jmp to_plot_flipped_player
is_unflipped_1e2a:
    jmp to_plot_unflipped_player_274b

move_player_down_and_replot:
    jsr get_player_screen_address
    ldx #$03
    ldy #$04
    jsr unplot_sprite                ; Unplot top of player
    jsr move_player_down_four_pixels
    lda #$00
    sta player_frame
    lda suppress_horizontal_falling  ; Non-zero if allowing horizontal movement when falling
    bne to_plot_player_facing_direction
    lda jump_direction               ; Zero if not jumping horizontally
    beq to_plot_player_facing_direction
    rts
to_plot_player_facing_direction:
    jmp plot_player_facing_direction

move_player_down_four_pixels:
    lda player_screen_address_low
    and #$07
    bne not_aligned
    clc
    lda player_screen_address_low
    adc #$04
    sta player_screen_address_low
    rts
not_aligned:
    lda player_screen_address_low
    and #$f8
    sta player_screen_address_low
    clc
    lda player_screen_address_high
    adc #$01
    bpl skip_wraparound_1e68
    sec
    sbc #$20
skip_wraparound_1e68:
    sta player_screen_address_high
    rts

consider_player_jumping:
    lda jump_timer                   ; Non-zero if jumping upwards
    bne is_jumping_upwards_1e70
    rts
is_jumping_upwards_1e70:
    pla                              ; Leave consider_player_falling on next return
    pla
    lda #$01
    sta player_jumping_or_falling    ; Set to non-zero to indicate player jumping or falling
    lda suppress_horizontal_falling  ; Non-zero if allowing horizontal movement when falling
    bne update_jumping_player
    lda jump_direction               ; Zero if not jumping horizontally
    beq update_jumping_player
    rts
update_jumping_player:
    dec jump_timer
    jsr check_for_obstacle_above_player
    cpx #$03
    beq no_obstacle_1ea0
    lda $c2                          ; objects_carried + &2 (OBJECT_JET_PACK)  # Non-zero if player is in jet pack
    beq end_jump
    lda #$c9                         ; ENTER
    cmp os_most_recently_pressed_key
    beq continue_jump
    cmp os_first_pressed_key
    bne end_jump
continue_jump:
    lda #$02                         ; Don't start falling
    sta jump_timer
    rts
end_jump:
    lda #$00
    sta jump_timer                   ; Set to zero to indicate player not jumping upwards
    rts
no_obstacle_1ea0:
    jsr move_player_up_four_pixels
    jsr get_player_feet
    jsr unplot_sprite                ; Unplot bottom of player
    lda suppress_horizontal_falling  ; Non-zero if allowing horizontal movement when falling
    bne plot_player_jumping
    lda jump_direction               ; Zero if not jumping horizontally
    beq plot_player_jumping
    rts
plot_player_jumping:
    lda #$00
    sta player_frame
    jmp plot_player_facing_direction

move_player_up_four_pixels:
    lda player_screen_address_low
    and #$07
    beq is_aligned_1ec8
    lda player_screen_address_low
    and #$f8
    sta player_screen_address_low
    jmp L_1ed4                       ; leave
is_aligned_1ec8:
    sec
    lda player_screen_address_low
    sbc #$fc
    sta player_screen_address_low
    jsr get_player_screen_address_high_after_subtraction
    sta player_screen_address_high
L_1ed4:
    rts

get_player_feet:
    lda player_screen_address_low
    sta screen_address_low
    clc
    jsr get_bottom_of_player_screen_address
    ldx #$03
    ldy #$04
    rts

update_horizontally_jumping_player:
    lda jump_timer                   ; Non-zero if player is jumping upwards
    bne is_jumping_upwards_1ee7
    rts
is_jumping_upwards_1ee7:
    lda jump_direction               ; Non-zero if player is jumping horizontally
    bne is_jumping_horizontally
    rts
is_jumping_horizontally:
    lda #$00
    sta player_frame
    jsr update_jumping_player
    lda jump_direction
    cmp #$01
    bne is_jumping_left_1f15
is_jumping_right_1ef9:
    jsr check_for_obstacle_to_right_of_player
    sta obstacle_pixel_value
    jsr find_hold_on_rope_right      ; Move player up until fully holding rope
    cmp #$09                         ; 1001
    beq to_consider_scrolling_right  ; Branch if player on rope
    cpx #$20
    beq to_consider_scrolling_right  ; Branch if no obstacle
    lda #$00
    sta jump_direction               ; Set to zero to indicate player not jumping horizontally
    sta jump_timer                   ; Set to zero to indicate player not jumping upwards
    jmp plot_player_facing_direction
to_consider_scrolling_right:
    jmp consider_scrolling_right
is_jumping_left_1f15:
    jsr check_for_obstacle_to_left_of_player
    sta obstacle_pixel_value
    jsr find_hold_on_rope_left       ; Move player up until fully holding rope
    cmp #$09                         ; 1001
    beq to_consider_scrolling_left   ; Branch if player on rope
    cpx #$20
    beq to_consider_scrolling_left   ; Branch if no obstacle
    lda #$00
    sta jump_direction               ; Set to zero to indicate player not jumping horizontally
    sta jump_timer                   ; Set to zero to indicate player not jumping upwards
    jmp plot_player_facing_direction
to_consider_scrolling_left:
    jmp consider_scrolling_left

consider_jumping_onto_rope:
    lda player_frame
    cmp #$07                         ; FRAME_JUMPING_ONTO_ROPE
    beq is_jumping_onto_rope
    rts
is_jumping_onto_rope:
    lda #$00
    sta player_frame
    lda jump_direction
    cmp #$01
    bne is_jumping_left_1f64
is_jumping_right_1f42:
    jsr check_for_obstacle_to_right_of_player
    sta obstacle_pixel_value
    jsr find_hold_on_rope_right      ; Move player up until fully holding rope
    cmp #$09                         ; 1001
    beq no_obstacle_right            ; Branch if player on rope
    cpx #$20
    beq no_obstacle_right            ; Branch if no obstacle
    lda #$00
    sta jump_direction               ; Set to zero to indicate player not jumping horizontally
    sta jump_timer                   ; Set to zero to indicate player not jumping upwards
    jsr consider_player_falling_and_leave_parent ; Leaves
    jmp plot_player_facing_direction ; Never called
no_obstacle_right:
    jsr move_player_down_and_replot
    jmp consider_scrolling_right
is_jumping_left_1f64:
    jsr check_for_obstacle_to_left_of_player
    sta obstacle_pixel_value
    jsr find_hold_on_rope_left       ; Move player up until fully holding rope
    cmp #$09                         ; 1001
    beq no_obstacle_left             ; Branch if player on rope
    cpx #$20
    beq no_obstacle_left             ; Branch if no obstacle
    lda #$00
    sta jump_direction               ; Set to zero to indicate player not jumping horizontally
    sta jump_timer                   ; Set to zero to indicate player not jumping upwards
    jsr consider_player_falling_and_leave_parent ; Leaves
    jmp plot_player_facing_direction ; Never called
no_obstacle_left:
    jsr move_player_down_and_replot
    jmp consider_scrolling_left

consider_stance_down:
    lda player_stance
    beq is_standing_1f8d
is_kneeling_or_crawling:
    jmp consider_crawling
is_standing_1f8d:
    lda player_direction             ; Zero if facing right, non-zero if facing left
    bne is_facing_left_1fa5
is_facing_right_1f91:
    clc
    lda player_screen_address_low
    adc #$10
    sta screen_address_low
    jsr get_bottom_of_player_screen_address
    ldx #$02
    jsr check_for_horizontal_obstacle
    cpx #$03
    bcc set_player_kneeling
    rts
is_facing_left_1fa5:
    ldx #$00
    jsr check_for_obstacle_below_player
    cpx #$01
    bcc set_player_kneeling
    rts
set_player_kneeling:
    pla                              ; Leave check_for_player_input on next return
    pla
plot_kneeling_player:
    lda #$01                         ; STANCE_KNEELING
    sta player_stance
    lda #$e0                         ; &05e0 = player_sprite_kneeling
    sta $72                          ; sprite_address_low
    lda #$05
    sta $73                          ; sprite_address_high
    lda player_screen_address_low
    sta screen_address_low
    lda player_screen_address_high
    sta screen_address_high
    ldx #$03
    ldy #$20
    lda player_direction             ; Zero if facing right, non-zero if facing left
    beq is_flipped_1fd0
is_unflipped_1fcd:
    jmp to_plot_unflipped_player_274b
is_flipped_1fd0:
    jmp to_plot_flipped_player

consider_stance_up:
    lda player_stance
    cmp #$01                         ; STANCE_KNEELING
    bne not_kneeling_1fe0
    lda #$00                         ; STANCE_STANDING
    sta player_stance
    jmp plot_player_standing
not_kneeling_1fe0:
    lda player_stance
    cmp #$02                         ; STANCE_CRAWLING
    beq is_crawling_1fe7
    rts
is_crawling_1fe7:
    lda player_screen_address_low
    sta previous_player_screen_address_low
    lda player_screen_address_high
    sta previous_player_screen_address_high
    lda player_direction             ; Zero if facing right, non-zero if facing left
    bne is_facing_left_200a
is_facing_right_1ff3:
    sec
    lda player_screen_address_low
    sbc #$01
    sta player_screen_address_low
    lda player_screen_address_high
    sbc #$02
    cmp #$60
    bcs skip_wraparound_2005
    clc
    adc #$20
skip_wraparound_2005:
    sta player_screen_address_high
    jmp consider_kneeling
is_facing_left_200a:
    sec
    lda player_screen_address_low
    sbc #$e1
    sta player_screen_address_low
    lda player_screen_address_high
    sbc #$01
    cmp #$60
    bcs skip_wraparound_201c
    clc
    adc #$20
skip_wraparound_201c:
    sta player_screen_address_high
consider_kneeling:
    jsr check_for_obstacles_to_kneeling ; Player can't stop crawling if blocked by obstacle
    cpx #$10
    bne revert_to_previous_screen_address
    lda previous_player_screen_address_low
    sta screen_address_low
    lda previous_player_screen_address_high
    sta screen_address_high
    ldx #$07
    ldy #$0f
    jsr unplot_sprite                ; Unplot crawling player
    dec player_stance
    jmp set_player_kneeling
revert_to_previous_screen_address:
    lda previous_player_screen_address_low
    sta player_screen_address_low
    lda previous_player_screen_address_high
    sta player_screen_address_high
    rts

consider_crawling:
    lda player_stance
    cmp #$02                         ; STANCE_CRAWLING
    bne not_crawling_2049
    rts
not_crawling_2049:
    lda player_direction             ; Zero if facing right, non-zero if facing left
    bne is_facing_left_207a
is_facing_right_204d:
    clc
    lda player_screen_address_low
    adc #$1c
    sta screen_address_low
    lda player_screen_address_high
    adc #$03
    bpl skip_wraparound_205d
    sec
    sbc #$20
skip_wraparound_205d:
    jsr check_for_horizontal_obstacle_and_leave ; Leaves if obstacle found
    clc
    lda player_screen_address_low
    adc #$01
    sta screen_address_low
    lda player_screen_address_high
    adc #$02
    bpl skip_wraparound_2070
    sec
    sbc #$20
skip_wraparound_2070:
    sta screen_address_high
    ldx #$fd
    jsr check_if_completely_supported ; Leaves if not completely supported
    jmp start_crawling
is_facing_left_207a:
    clc
    lda player_screen_address_low
    adc #$e4
    sta screen_address_low
    lda player_screen_address_high
    adc #$02
    bpl skip_wraparound_208a
    sec
    sbc #$20
skip_wraparound_208a:
    jsr check_for_horizontal_obstacle_and_leave ; Leaves if obstacle found
    clc
    lda player_screen_address_low
    adc #$e9
    sta screen_address_low
    lda player_screen_address_high
    adc #$01
    bpl skip_wraparound_209d
    sec
    sbc #$20
skip_wraparound_209d:
    sta screen_address_high
    ldx #$fd
    jsr check_if_completely_supported ; Leaves if not completely supported
start_crawling:
    lda #$00
    sta player_frame
    sta climbing_or_crawling_cooldown
    inc player_stance
    lda player_screen_address_low
    sta screen_address_low
    lda player_screen_address_high
    sta screen_address_high
    ldx #$03
    ldy #$20
    jsr unplot_sprite                ; Unplot kneeling player
plot_player_crawling:
    lda player_direction             ; Zero if facing right, non-zero if facing left
    bne plot_player_crawling_left_20e4
plot_player_crawling_right_20bf:
    clc
    lda player_screen_address_low
    adc #$01
    sta player_screen_address_low
    sta screen_address_low
    lda player_screen_address_high
    adc #$02
    bpl skip_wraparound_20d1
    sec
    sbc #$20
skip_wraparound_20d1:
    sta player_screen_address_high
    sta screen_address_high
    lda #$a9                         ; &06a9 = player_sprite_crawling_two
    sta $72                          ; sprite_address_low
    lda #$06
    sta $73                          ; sprite_address_high
    ldx #$07
    ldy #$0f
    jmp to_plot_flipped_player
plot_player_crawling_left_20e4:
    clc
    lda player_screen_address_low
    adc #$e1
    sta player_screen_address_low
    sta screen_address_low
    lda player_screen_address_high
    adc #$01
    bpl skip_wraparound_20f6
    sec
    sbc #$20
skip_wraparound_20f6:
    sta player_screen_address_high
    sta screen_address_high
    lda #$a9                         ; &06a9 = player_sprite_crawling_two
    sta $72                          ; sprite_address_low
    lda #$06
    sta $73                          ; sprite_address_high
    ldx #$07
    ldy #$0f
    jmp to_plot_unflipped_player_274b

check_for_horizontal_obstacle_and_leave:
    sta screen_address_high
    ldx #$00
check_for_horizontal_obstacle_and_leave_loop:
    lda (screen_address),y
    bne leave_calling_function_2128
    clc
    lda screen_address_low
    adc #$08
    sta screen_address_low
    lda screen_address_high
    adc #$00
    bpl skip_wraparound_2120
    lda #$60
skip_wraparound_2120:
    sta screen_address_high
    inx
    cpx #$04
    bne check_for_horizontal_obstacle_and_leave_loop
    rts
leave_calling_function_2128:
    pla                              ; Leave calling function on next return
    pla
    rts

crawl_right:
    inc player_frame
    lda player_frame
    cmp #$02
    bne skip_wraparound_2137
    lda #$00
    sta player_frame
skip_wraparound_2137:
    lda player_screen_address_low
    sta screen_address_low
    lda player_screen_address_high
    sta screen_address_high
    ldx #$01                         ; &0101 = sprite_space + 1
    ldy #$0f
    stx $72                          ; sprite_address_low
    stx $73                          ; sprite_address_high
    jsr to_plot_unflipped_player_274b
    inc player_x
    clc
    lda player_screen_address_low
    adc #$08
    sta player_screen_address_low
    sta screen_address_low
    lda player_screen_address_high
    adc #$00
    bpl skip_wraparound_215d
    lda #$60
skip_wraparound_215d:
    sta player_screen_address_high
    sta screen_address_high
plot_player_crawling_right_2161:
    lda #$06
    sta $73                          ; sprite_address_high
    ldx #$40                         ; &0640 = player_sprite_crawling_one
    lda player_frame
    bne to_set_sprite_address_low
    ldx #$a9                         ; &06a9 = player_sprite_crawling_two
to_set_sprite_address_low:
    jmp set_sprite_address_low

crawl_left:
    inc player_frame
    lda player_frame
    cmp #$02
    bne skip_wraparound_217c
    lda #$00
    sta player_frame
skip_wraparound_217c:
    lda player_screen_address_low
    sta screen_address_low
    lda player_screen_address_high
    sta screen_address_high
    clc
    lda screen_address_low
    adc #$30
    sta screen_address_low
    bcc skip_page_2195
    inc screen_address_high
    bpl skip_wraparound_2195
    lda #$60
    sta screen_address_high
skip_wraparound_2195:
skip_page_2195:
    ldx #$01
    ldy #$0f
    stx $72                          ; sprite_address_low
    stx $73                          ; sprite_address_high
    jsr to_plot_unflipped_player_274b
    dec player_x
    sec
    jsr get_left_of_player_screen_address
    sta player_screen_address_low
    jsr get_player_screen_address_high_after_subtraction
    sta player_screen_address_high
    sta screen_address_high
plot_player_crawling_left_21af:
    lda #$06
    sta $73                          ; sprite_address_high
    ldx #$40                         ; &0640 = player_sprite_crawling_one
    lda player_frame
    bne set_sprite_address_low
    ldx #$a9                         ; &06a9 = player_sprite_crawling_two
set_sprite_address_low:
    stx $72                          ; sprite_address_low
    ldx #$07
    ldy #$0f
    lda player_direction             ; Zero if facing right, non-zero if facing left
    bne is_unflipped_21c8
is_flipped_21c5:
    jmp to_plot_flipped_player       ; Plot crawling player
is_unflipped_21c8:
    jmp to_plot_unflipped_player_274b ; Plot crawling player

check_if_player_is_completely_supported: ; # Unused entry point
    lda player_screen_address_low
    sta screen_address_low
    lda player_screen_address_high
    sta screen_address_high
    ldx #$fc
check_if_completely_supported:
    lda #$f0                         ; BEQ
    sta check_for_obstacle_below_player_opcode
    clc
    lda screen_address_high
    adc #$02
    bpl skip_wraparound_21e4
    sec
    sbc #$20
skip_wraparound_21e4:
    sta screen_address_high
    jsr check_for_horizontal_obstacle ; Check for absence of obstacle
    lda #$d0                         ; BNE
    sta check_for_obstacle_below_player_opcode
    cpx #$03
    beq leave_21f4                   ; Leave if no absence of obstacle found
    pla                              ; Otherwise leave consider_crawling on next return
    pla
leave_21f4:
    rts

consider_player_falling:
    lda player_stance
    beq is_standing_21fa
    rts
is_standing_21fa:
    jsr consider_player_jumping      ; Leaves if player is jumping upwards
    ldx #$00
    jsr check_for_obstacle_below_player
    cpx #$03
    beq no_obstacle_below
    lda #$00
    sta player_jumping_or_falling    ; Set to zero to indicate player not jumping or falling
    sta jump_direction               ; Set to zero to indicate player not jumping horizontally
    rts
no_obstacle_below:
    stx player_jumping_or_falling    ; Set to non-zero to indicate player is jumping or falling
    lda suppress_horizontal_falling  ; Non-zero if allowing horizontal movement when falling
    bne to_move_player_down_and_replot
    lda jump_direction               ; Zero if player not jumping horizontally
    beq to_move_player_down_and_replot
    lda #$07                         ; FRAME_JUMPING_ONTO_ROPE
    sta player_frame
    rts
to_move_player_down_and_replot:
    jmp move_player_down_and_replot

check_for_obstacle_below_player:
    lda player_screen_address_low
    sta screen_address_low
    clc
    jsr get_bottom_of_player_screen_address
check_for_horizontal_obstacle:
    ldy #$00
check_for_obstacle_below_player_loop:
    lda (screen_address),y
check_for_obstacle_below_player_opcode:
    bne leave_2246
;     also     BEQ &2246 ; leave if checking if player is supported
    inx
    cpx #$03
    beq leave_2246
    clc
    lda screen_address_low
    adc #$08
    sta screen_address_low
    bcc check_for_obstacle_below_player_loop
    inc screen_address_high
    bpl check_for_obstacle_below_player_loop
    lda #$60
    sta screen_address_high
    jmp check_for_obstacle_below_player_loop
leave_2246:
    rts

check_for_vertical_obstacle:
    ldx #$00
check_for_vertical_obstacle_with_X:
    ldy #$00
    lda player_jumping_or_falling
    beq check_for_vertical_obstacle_loop
    lda jump_timer
    bne check_for_vertical_obstacle_loop
    dex
check_for_vertical_obstacle_loop:
    lda (screen_address),y
    bne leave_with_result
    inx
    cpx #$20
    beq leave_with_result
    lda screen_address_low
    and #$07
    cmp #$07
    beq next_group_226a
    inc screen_address_low
    jmp check_for_vertical_obstacle_loop
next_group_226a:
    clc
    lda screen_address_low
    adc #$f9
    sta screen_address_low
    bcc check_for_vertical_obstacle_loop
    inc screen_address_high
    bpl check_for_vertical_obstacle_loop
    lda #$60
    sta screen_address_high
    jmp check_for_vertical_obstacle_loop
leave_with_result:
    eor $c2                          ; objects_carried + &2 (OBJECT_JET_PACK)  # Stop player in jet pack moving through rope (but see &22da)
    rts

check_for_obstacle_to_right_of_player:
    clc
    lda player_screen_address_low
    adc #$18
    sta screen_address_low
    lda player_screen_address_high
    adc #$00
    bpl skip_wraparound_2290
    lda #$60
skip_wraparound_2290:
    sta screen_address_high
    jmp check_for_vertical_obstacle

check_for_obstacle_to_left_of_player:
    jsr get_left_of_player_screen_address
    jsr get_player_screen_address_high_after_subtraction
    sta screen_address_high
    jmp check_for_vertical_obstacle

check_for_obstacle_above_player:
    lda player_screen_address_low
    and #$07
    beq is_aligned_22b1
    lda player_screen_address_low
    and #$f8
    sta screen_address_low
    lda player_screen_address_high
    jmp set_screen_address_high
is_aligned_22b1:
    sec
    lda player_screen_address_low
    sbc #$fc
    sta screen_address_low
    jsr get_player_screen_address_high_after_subtraction
set_screen_address_high:
    sta screen_address_high
    ldx #$00
    jmp check_for_horizontal_obstacle
    rts

find_hold_on_rope_right:
    lda obstacle_pixel_value
    cmp #$09                         ; 1001
    beq is_rope_22ce
leave_with_zero:
    lda #$00
    sta obstacle_pixel_value
    rts
is_rope_22ce:
    clc
    lda player_screen_address_low
    adc #$18
    sta screen_address_low
    jsr get_bottom_of_player_screen_address
find_hold_on_rope:
    sta screen_address_high
    lda $c2                          ; objects_carried + &2 (OBJECT_JET_PACK)  # Non-zero if player is in jet pack
    bne leave_with_zero
    ldy #$00
    lda (screen_address),y
    cmp #$09                         ; 1001
    beq leave_with_rope
    jsr to_calculate_player_screen_address_offset ; Returns offset high
    and #$03
    eor #$03
    sta y_fraction
    ldy #$20
    ldx #$03
    lda player_screen_address_low
    sta screen_address_low
    lda player_screen_address_high
    sta screen_address_high
    jsr unplot_sprite                ; Unplot player
    lda player_jumping_or_falling
    beq not_at_top_of_jump
    lda jump_timer
    bne not_at_top_of_jump
    inc y_fraction
not_at_top_of_jump:
    sec
    lda player_screen_address_high
    sbc y_fraction
    cmp #$60
    bcs skip_wraparound_2314
    clc
    adc #$20
skip_wraparound_2314:
    sta player_screen_address_high
    lda player_screen_address_low
    and #$f8
    sta player_screen_address_low
leave_with_rope:
    lda #$09                         ; 1001
    rts

find_hold_on_rope_left:
    lda obstacle_pixel_value
    cmp #$09                         ; 1001
    beq is_rope_2326
    rts
is_rope_2326:
    clc
    lda player_screen_address_low
    adc #$f8
    sta screen_address_low
    lda player_screen_address_high
    adc #$03
    bpl find_hold_on_rope
    sec
    sbc #$20
    jmp find_hold_on_rope

check_for_obstacles_to_kneeling:
    ldx #$00
    ldy #$00
check_for_obstacles_to_kneeling_loop:
    lda kneeling_check_offsets,x
    clc
    adc player_screen_address_low
    sta screen_address_low
    lda player_screen_address_high
    adc $0571,x                      ; kneeling_check_offsets + 1
    bpl skip_wraparound_234f
    sec
    sbc #$20
skip_wraparound_234f:
    sta screen_address_high
    lda (screen_address),y
    bne leave_235b
    inx
    inx
    cpx #$10
    bne check_for_obstacles_to_kneeling_loop
leave_235b:
    rts

check_for_player_collision_with_mines_to_right:
    ldx player_x
    inx
    inx
    inx
    jmp check_for_player_collision_with_mines
check_for_player_collision_with_mines_to_left:
    ldx player_x
    dex
check_for_player_collision_with_mines:
    stx $53                          ; player_feet_x
    jsr to_calculate_player_screen_address_offset
    txa
    clc
    adc #$03
    asl a
    asl a
    asl a
    sta player_feet_y
    ldx #$00
check_for_player_collision_with_mines_loop:
    lda mines_x,x
    cmp $53                          ; player_feet_x
    bne consider_next_mine_23aa
    lda mines_y,x
    cmp player_feet_y
    bne consider_next_mine_23aa
    lda mines_state,x                ; Positive if mine exploding or not placed
    bpl consider_next_mine_23aa
    lda #$04
    sta mines_state,x                ; Set to positive non-zero to indicate mine exploding
    jsr to_get_player_feet_screen_address
    lda screen_address_low
    sta mines_x,x
    lda screen_address_high
    sta mines_y,x
    dec obstacle_y_position          ; Treat detonated mine as obstacle
    sec
    lda suit_energy
    sbc #$0a                         ; Detonating mine drains 10 energy
    sta suit_energy
    lda #$08
    jmp to_play_sound_for_damage
consider_next_mine_23aa:
    inx
    cpx #$06
    bne check_for_player_collision_with_mines_loop
    rts

plot_objects_on_right_edge:
    lda level
    cmp #$0c
    bcc not_title_or_status_screen_23b7
    rts
not_title_or_status_screen_23b7:
    lda right_edge_tile_address_low
    clc
    adc right_edge_x_fraction
    sta $70                          ; edge_x
    lda level
    asl a
    asl a
    tax
    lda #$04
    sta object_to_update
plot_objects_on_right_edge_loop:
    lda objects_x,x
    cmp $70                          ; edge_x
    bcs consider_next_object_23e1
    lda objects_type_and_flags,x
    and #$f0                         ; Top nibble sets object type
    lsr a                            ; 8421.... -> ..8421..
    lsr a
    tay
    lda $0937,y                      ; object_types_sprite_address_and_sizes + 3 (width)
    clc
    adc objects_x,x
    cmp $70                          ; edge_x
    bcs is_visible_23e7
consider_next_object_23e1:
    inx
    dec object_to_update
    bne plot_objects_on_right_edge_loop
    rts
is_visible_23e7:
    pha                              ; object_right_x
    lda objects_type_and_flags,x
    stx object_to_plot
    sta object_type_and_flags
    and #$0f                         ; Bottom nibble is zero if not collected
    beq not_collected_23f5
    pla                              ; object_right_x
    rts
not_collected_23f5:
    ldx #$1f
    stx object_screen_x
update_object:
    pla                              ; object_right_x
    sec
    sbc $70                          ; edge_x
    sta object_relative_x
    sec
    lda $0937,y                      ; object_types_sprite_address_and_sizes + 3 (width)
    sbc object_relative_x
    tax
    dex
    lda #$00
calculate_sprite_offset_loop:
    cpx #$00
    beq set_sprite_offset
    clc
    adc $0936,y                      ; object_types_sprite_address_and_sizes + 2 (height)
    dex
    jmp calculate_sprite_offset_loop
set_sprite_offset:
    sta object_sprite_offset
    lda object_type_and_flags        ; Top nibble sets object type
    jsr get_top_nibble
    tax
    jmp plot_object

plot_objects_on_left_edge:
    lda left_edge_tile_address_low
    clc
    adc left_edge_x_fraction
    sta $70                          ; edge_x
    lda level
    asl a
    asl a
    tax
    lda #$04
    sta screen_address_high
plot_objects_on_left_edge_loop:
    lda objects_x,x
    stx object_to_plot
    cmp screen_address_low
    bcs consider_next_object_244c
    lda objects_type_and_flags,x
    and #$f0                         ; Top nibble sets object type
    lsr a                            ; 8421.... -> ..8421..
    lsr a
    tay
    lda $0937,y                      ; object_types_sprite_address_and_sizes + 3 (width)
    clc
    adc objects_x,x
    cmp screen_address_low
    bcs is_visible_2452
consider_next_object_244c:
    inx
    dec screen_address_high
    bne plot_objects_on_left_edge_loop
    rts
is_visible_2452:
    pha                              ; object_right_x
    lda objects_type_and_flags,x
    sta object_type_and_flags
    and #$0f                         ; Bottom nibble is zero if not collected
    beq not_collected_245e
    pla                              ; object_right_x
    rts
not_collected_245e:
    ldx #$00
    stx object_screen_x
    jmp update_object

check_if_touching_object_vertically:
    stx object_to_check
    jsr to_calculate_player_screen_address_offset
    txa
    asl a
    asl a
    asl a
    ldx object_to_check
    sec
    sbc objects_y,x
    cmp #$e0
    bcs leave_247a
    pla                              ; Leave consider_collecting_object_to_right or
    pla                              ; consider_collecting_object_to_left on next return
leave_247a:
    rts

consider_collecting_object_to_right:
    ldx object_to_consider
    cpx #$10
    bcc leave_249c
    clc
    lda player_x
    adc #$02
    sta $70                          ; player_feet_x
    lda level
    asl a
    asl a
    tax
    ldy #$00
consider_collecting_object_to_right_loop:
    lda objects_x,x
    cmp screen_address_low
    beq is_touching_object_horizontally_249d
    inx
    iny
    cpy #$04
    bne consider_collecting_object_to_right_loop
leave_249c:
    rts
is_touching_object_horizontally_249d:
    jsr check_if_touching_object_vertically ; Leaves if not touching object vertically
    lda objects_type_and_flags,x
    sta collected_object_type
    and #$0f                         ; Bottom nibble is zero if not collected
    bne leave_249c                   ; Leave if object has already been collected
    lda collected_object_type
    clc
    adc #$01                         ; Set bottom nibble to non-zero to indicate collected
    sta objects_type_and_flags,x
    clc
    lda player_screen_address_low
    adc #$18
    sta screen_address_low
    lda player_screen_address_high
    adc #$02
    bpl skip_wraparound_24c1
    sec
    sbc #$20
skip_wraparound_24c1:
    sta screen_address_high
    pla                              ; Leave consider_moving_right on next return
    pla
    ldx #$03
    ldy #$10
    lda collected_object_type
    cmp #$70                         ; OBJECT_SWITCH * &10
    bcc not_switch_or_button
    cmp #$90                         ; (OBJECT_BUTTON + 1) * &10
    bcs not_switch_or_button
    ldx #$01                         ; Switches and buttons are smaller
not_switch_or_button:
    jsr unplot_sprite                ; Unplot object to right of player
collect_object:
    inc total_objects_collected
    ldx #$04
    ldy #$c8
    lda #$02
    jsr play_sound_volume_X_pitch_Y_duration_A_on_channel_two
    lda collected_object_type
    jsr get_top_nibble
    sta collected_object_type
    tax
    lda scores_for_collecting_objects,x ; Bug: overflows into kneeling_check_offsets
    and #$07                         ; AND #&07 should probably be at &24ea
    tay
    iny
    ldx #$04                         ; Score 1000 - 7000 for collecting objects
    jsr to_add_to_score
    ldx collected_object_type
    inc objects_carried,x
    lda #$0b                         ; Remove effect of spring
    sta maximum_jump_timer
    cpx #$02                         ; OBJECT_JET_PACK
    bne not_jet_pack
    jmp plot_player_standing
not_jet_pack:
    lda $c3                          ; objects_carried + &3 (OBJECT_CRATE)
    beq not_crate
    clc
    lda $c0                          ; objects_carried + &0 (OBJECT_PASSCARD)
    adc #$06                         ; Crate contains six pass cards
    sta $c0                          ; objects_carried + &0 (OBJECT_PASSCARD)
    lda #$00
    sta $c3                          ; objects_carried + &3 (OBJECT_CRATE)
    inc $c1                          ; objects_carried + &1 (OBJECT_ENERGY_CELL)  # and two energy cells
    inc $c1                          ; objects_carried + &1 (OBJECT_ENERGY_CELL)
not_crate:
    lda $c5                          ; objects_carried + &5 (OBJECT_SPRING)
    beq not_spring
    lda #$11
    sta maximum_jump_timer
    lda #$00
    sta $c5                          ; objects_carried + &5 (OBJECT_SPRING)
not_spring:
    lda $c6                          ; objects_carried + &6 (OBJECT_FUEL)
    beq not_fuel
    lda #$ff
    sta jet_pack_energy
    dec $c6                          ; objects_carried + &6 (OBJECT_FUEL)
not_fuel:
    lda $c7                          ; objects_carried + &7 (OBJECT_SWITCH)
    beq not_switch
    dec $c7                          ; objects_carried + &7 (OBJECT_SWITCH)
    ldx #$1e                         ; Lower rope in Ancient Shrine sector three
    ldy #$04
    lda #$0f                         ; NIBBLE_SHRINE_ROPE
    jsr to_replot_tile
    ldx #$1e
    ldy #$05
    lda #$0f                         ; NIBBLE_SHRINE_ROPE
    jsr to_replot_tile
not_switch:
    lda $ce                          ; objects_carried + &e (OBJECT_REMOTE_ACTIVATOR)
    beq not_carrying_remote_activator_and_two_spanners
    lda $c9                          ; objects_carried + &9 (OBJECT_SPANNER)
    cmp #$02
    bcc not_carrying_remote_activator_and_two_spanners
    ldx #$2b                         ; Lift pipe in Crew's Quarters sector one
    ldy #$06
    lda #$00                         ; NIBBLE_SPACE
    sta $ce                          ; objects_carried + &e (OBJECT_REMOTE_ACTIVATOR)
    jsr to_replot_tile
    ldx #$2b
    ldy #$03
    lda #$0f                         ; NIBBLE_QUARTERS_PIPE_HORIZONTAL
    jsr to_replot_tile
not_carrying_remote_activator_and_two_spanners:
    lda collected_object_type
    cmp #$08                         ; OBJECT_BUTTON
    bne not_button
    lda #$00
    sta $c8                          ; objects_carried + &8 (OBJECT_BUTTON)
    lda player_x
    cmp #$b0
    bcc not_button
    inc $c8                          ; objects_carried + &8 (OBJECT_BUTTON)
not_button:
    rts

consider_collecting_object_to_left:
    ldx object_to_consider
    cpx #$10
    bcc leave_2599
    sec
    lda player_x
    sbc #$04
    sta $70                          ; player_feet_x
    lda level
    asl a
    asl a
    tax
    ldy #$00
consider_collecting_object_to_left_loop:
    lda objects_x,x
    cmp $70                          ; player_feet_x
    beq is_touching_object_horizontally_259a
    inx
    iny
    cpy #$04
    bne consider_collecting_object_to_left_loop
leave_2599:
    rts
is_touching_object_horizontally_259a:
    jsr check_if_touching_object_vertically ; Leaves if not touching object vertically
    lda objects_type_and_flags,x
    sta collected_object_type
    and #$0f
    bne leave_2599                   ; Leave if object has already been collected
    lda collected_object_type
    clc
    adc #$01                         ; Set bottom nibble to non-zero to indicate collected
    sta objects_type_and_flags,x
    clc
    lda player_screen_address_low
    adc #$e8
    sta screen_address_low
    lda player_screen_address_high
    adc #$01
    bpl skip_wraparound_25be
    sec
    sbc #$20
skip_wraparound_25be:
    sta screen_address_high
    pla                              ; Leave consider_moving_left on next return
    pla
    ldx #$03
    ldy #$10
    jsr unplot_sprite                ; Unplot object to left of player
    jmp collect_object

plot_object:
    stx object_type
    ldx object_to_plot
    lda objects_y,x
    tay
    ldx object_screen_x
    jsr to_calculate_screen_address
    lda object_type
    asl a
    asl a
    tax
    clc
    lda object_types_sprite_address_and_sizes,x ; object_types_sprite_address_and_sizes + 0 (address low)
    adc object_sprite_offset
    sta $72                          ; sprite_address_low
    lda $0935,x                      ; object_types_sprite_address_and_sizes + 1 (address high)
    adc #$00
    sta $73                          ; sprite_address_high
    lda $0936,x                      ; object_types_sprite_address_and_sizes + 2 (height)
    tay
    ldx #$01
    jmp plot_sprite                  ; Plot a single column of the object

consider_climbing_up:
    lda player_stance
    cmp #$03                         ; STANCE_CLIMBING
    beq is_climbing_up
    rts
is_climbing_up:
    pla                              ; Leave check_for_player_input on next return
    pla
    jsr check_for_obstacle_above_player
    cmp #$09                         ; 1001
    beq is_rope_above
    rts
is_rope_above:
    inc climbing_or_crawling_cooldown
    lda climbing_or_crawling_cooldown
    cmp #$02
    beq climb_up                     ; Player can climb one in three frames
    rts
climb_up:
    lda #$00
    sta climbing_or_crawling_cooldown
    jsr move_player_up_four_pixels
    jsr get_player_feet
    lda #$d2                         ; &07d2 = sprite_rope_section
    sta $72                          ; sprite_address_low
    lda #$07
    sta $73                          ; sprite_address_high
    lda player_direction             ; Zero if facing right, non-zero if facing left
    beq is_facing_right_262a
is_facing_left_2626:
    lda #$da                         ; &07da = sprite_rope_section + 8
    sta $72                          ; sprite_address_low
is_facing_right_262a:
    jsr plot_sprite
    inc player_frame
plot_climbing_player:
    lda #$12                         ; &0712 = player_sprite_climbing_one
    sta $72                          ; sprite_address_low
    lda player_frame
    and #$01
    bne not_frame_zero
    sta player_frame
    lda #$72                         ; &0772 = player_sprite_climbing_zero
    sta $72                          ; sprite_address_low
not_frame_zero:
    lda player_screen_address_low
    sta screen_address_low
    lda player_screen_address_high
    sta screen_address_high
    ldx #$03
    ldy #$20
    lda #$07
    sta $73                          ; sprite_address_low
    lda player_direction             ; Zero if facing right, non-zero if facing left
    bne is_unflipped_2656
is_flipped_2653:
    jmp to_plot_flipped_player
is_unflipped_2656:
    jmp to_plot_unflipped_player_274b

consider_climbing_down:
    lda player_stance
    cmp #$03                         ; STANCE_CLIMBING
    beq is_climbing_down
    rts
is_climbing_down:
    pla                              ; Leave check_for_player_input on next return
    pla
    ldx #$00
    jsr check_for_obstacle_below_player
    cmp #$09                         ; 1001
    beq is_rope_below
    rts
is_rope_below:
    jsr get_player_screen_address
    lda #$d2                         ; &07d2 = sprite_rope_section
    sta $72                          ; sprite_address_low
    lda #$07
    sta $73                          ; sprite_address_high
    lda player_direction             ; Zero if facing right, non-zero if facing left
    beq is_facing_right_267f
is_facing_left_267b:
    lda #$da                         ; &07da = sprite_rope_section + 8
    sta $72                          ; sprite_address_low
is_facing_right_267f:
    ldx #$03
    ldy #$04
    jsr plot_sprite
    jsr move_player_down_four_pixels
    lda #$00
    sta player_frame
    jmp plot_climbing_player

consider_moving_player_up_sloping_ground:
    lda obstacle_y_position
    and #$03
    bne leave_calling_function_269d
    jsr check_for_obstacle_above_player
    cpx #$03
    beq move_player_up_sloping_ground ; Branch if no obstacle above player
leave_calling_function_269d:
    pla                              ; Leave consider_moving_right or consider_moving_left
    pla                              ; on next return
    rts
move_player_up_sloping_ground:
    lda #$01                         ; &0101 = sprite_space + 1
    sta $72                          ; sprite_address_low
    sta $73                          ; sprite_address_high
    ldx obstacle_y_position
    cpx #$1c
    bcs move_player_up_once
move_player_up_twice:
    jsr move_player_up_four_pixels
    jsr move_player_up_four_pixels
    jsr get_player_feet
    ldy #$08
    jmp to_plot_unflipped_player_274b ; Unplot player
move_player_up_once:
    jsr move_player_up_four_pixels
    jsr get_player_feet
    jmp to_plot_unflipped_player_274b ; Unplot player

play_sound_volume_X_pitch_Y_duration_A:
    stx $26e7                        ; sound_block_0 + 2 (volume)
    sty $26e9                        ; sound_block_0 + 4 (pitch)
    sta $26eb                        ; sound_block_0 + 6 (duration)
    ldx #$e5
    ldy #$26
    lda #$07                         ; Generate a sound
    jsr OSWORD
    lda #$03
    sta sound_block_0                ; sound_block_0 + 0 (channel)  # Use channel 3 for next sound unless otherwise set
    rts

play_sound_volume_X_pitch_Y_duration_A_on_channel_two:
    pha                              ; tmp_a
    lda #$12
    sta sound_block_0                ; sound_block_0 + 0 (channel)
    pla                              ; tmp_a
    jmp play_sound_volume_X_pitch_Y_duration_A

;     chan  vol   pitch dur
sound_block_0:
    .byte $03,$00,$00,$00,$00,$00,$00,$00

variable_delay:
    lda #$00
    sta count_low
    sta count_high
variable_delay_loop:
    inc count_low
    lda count_low
    cmp delay_length_low
    bne variable_delay_loop
    inc count_high
    lda count_high
    cmp delay_length_high
    bne variable_delay_loop
    rts

set_crtc_address:
    lda #$0c                         ; R12: Displayed screen start address register (high)
    sta $fe00                        ; video register number
    lda crtc_address_high
    sta $fe01                        ; video register value
    lda #$0d                         ; R13: Displayed screen start address register (low)
    sta $fe00                        ; video register number
    lda crtc_address_low
    sta $fe01                        ; video register value
    rts

wait_for_vsync:
    lda #$13                         ; Wait for vertical retrace
    jmp OSBYTE

to_title_screen:
    jmp title_screen
to_calculate_screen_address:
    jmp calculate_screen_address
to_game_over_screen:
    jmp game_over_screen
to_wrist_terminal_screen:
    jmp wrist_terminal_screen
to_fire_blaster:
    jmp fire_blaster
to_update_blasters:
    jmp update_blasters
to_replot_tile:
    jmp replot_tile
to_jet_pack_screen:
    jmp jet_pack_screen
to_update_gargoyles:
    jmp update_gargoyles
to_display_level_2739:
    jmp display_level
to_plot_unflipped_player_273c:       ; # Unused
    jmp plot_unflipped_player
to_plot_unflipped_player_using_addresses: ; # Unused
    jmp plot_unflipped_player_using_addresses
to_set_palette:
    jmp set_palette
to_update_events:
    jmp update_events
to_update_chandeliers:
    jmp update_chandeliers
to_plot_unflipped_player_274b:
    jmp plot_unflipped_player
to_add_to_score:
    jmp add_to_score
to_plot_flipped_player:
    jmp plot_flipped_player
to_remove_lifts_from_level_data:
    jmp remove_lifts_from_level_data
to_drop_mine:
    jmp drop_mine
to_initialise_level:
    jmp initialise_level
to_buffer_colliding_blasters:
    jmp buffer_colliding_blasters
to_check_for_collision_with_blasters:
    jmp check_for_collision_with_blasters
to_lose_life:
    jmp lose_life
to_calculate_player_screen_address_offset:
    jmp calculate_player_screen_address_offset
to_plot_mines_on_right_edge:
    jmp plot_mines_on_right_edge
to_plot_mines_on_left_edge:
    jmp plot_mines_on_left_edge
to_remove_colliding_blasters:
    jmp remove_colliding_blasters
to_get_player_feet_screen_address:
    jmp get_player_feet_screen_address
to_play_sound_for_damage:
    jmp play_sound_for_damage
to_consider_saving_position:
    jmp consider_saving_position
to_update_exploding_mines:
    jmp update_exploding_mines

update_enemies:
    jsr consider_using_keys
    inc frame_counter
    lda #$00
    sta enemy_to_update
update_enemies_loop:
    ldx enemy_to_update
    ldy #$00
get_enemy_variables_loop:
    lda enemies_variables,x
    sta a:enemy_variables,y
    inx
    iny
    cpy #$04
    bne get_enemy_variables_loop
    lda enemy_direction_and_state
    sta enemy_previous_direction_and_state
    lsr a
    lsr a
    tay                              ; Unnecessary code; unused
    lsr a
    lsr a
    sta $a3                          ; unused  # Top nibble is unused
    lda enemy_direction_and_state
    and #$0f
    sta enemy_direction_and_state    ; Bottom nibble contains direction and state
    lda enemy_tile_x
    bmi set_enemy_variables          ; Negative if enemy not present
    lda $04,x                        ; enemies_energy_and_initial_flags - 4
    sta enemy_energy_and_initial_flags
    jsr buffer_player_points_and_blasters
    lda enemy_tile_fraction_and_frame
    and #$f0                         ; Top nibble contains frame
    lsr a                            ; 8421.... -> ...8421.
    lsr a
    lsr a
    tax
    lda enemy_sprite_addresses_table,x
    sta $5d                          ; enemy_sprite_address_low
    lda $4bd1,x                      ; enemy_sprite_addresses_table + 1
    sta $a4                          ; enemy_sprite_address_high
    lda enemy_tile_fraction_and_frame
    and #$07                         ; Bottom nibble contains tile fraction
    sta enemy_tile_fraction_and_frame
    lda enemy_direction_and_state
    cmp #$04                         ; STATE_SKELETON
    bcc not_skeleton_27e0
    and #$0e                         ; Get skeleton animation frame
    sec
    sbc #$04                         ; STATE_SKELETON
    tax
    lda skeleton_sprite_addresses_table,x ; skeleton_sprite_addresses_table - 2
    sta $5d                          ; enemy_sprite_address_low
    lda $4bdd,x                      ; skeleton_sprite_addresses_table - 2 + 1
    sta $a4                          ; enemy_sprite_address_high
not_skeleton_27e0:
    jsr consider_plotting_enemy
    jsr check_for_enemy_collision_with_blasters_and_player
    jsr check_for_enemy_collision_with_mines
    ldx enemy_to_update
    lda enemy_direction_and_state
    and #$02                         ; STATE_STATIONARY
    beq not_stationary
    lda enemy_direction_and_state
    cmp #$04                         ; STATE_SKELETON
    bcs not_stationary
    lda #$f0                         ; Becomes &00 at &2800
    sta enemies_tile_fraction_and_frame,x ; i.e. use enemy_sprite_zero, aligned with tile
not_stationary:
    lda enemies_tile_fraction_and_frame,x
    and #$f0                         ; Top nibble contains frame
    clc
    adc #$10                         ; Move to next frame of animation
    cmp #$60
    bne skip_wraparound_2808
    lda #$00                         ; Wrap around to start of animation
skip_wraparound_2808:
    cmp #$a0                         ; (FRAME_SKELETON + 2) * &10  # Animate skeleton once in two frames
    bne skip_animating_skeleton
    inc enemy_direction_and_state    ; Move to next frame of skeleton animation
    inc enemy_direction_and_state
    lda #$80                         ; FRAME_SKELETON
    ldx enemy_direction_and_state
    cpx #$0e                         ; STATE_SKELETON + 8
    bcc skip_animating_skeleton      ; Is this the end of the skeleton animation?
    ldx #$ff                         ; Set to negative to remove enemy
    stx enemy_tile_x
skip_removing_skeleton:
skip_animating_skeleton:
    clc
    adc enemy_tile_fraction_and_frame ; Add the bottom nibble, i.e. tile fraction
    sta enemy_tile_fraction_and_frame
set_enemy_variables:
    ldx enemy_to_update
    ldy #$00
set_enemy_variables_loop:
    lda a:enemy_variables,y
    sta enemies_variables,x
    inx
    iny
    cpy #$04
    bne set_enemy_variables_loop
    lda enemy_energy_and_initial_flags
    sta $04,x                        ; enemies_energy_and_initial_flags - 4
    inx
    stx enemy_to_update
    lda enemy_previous_direction_and_state ; Keep the previous (unused) top nibble
    and #$f0
    clc
    adc enemy_direction_and_state    ; Add the bottom nibble, i.e. direction and state
    sta $01,x                        ; enemies_direction_and_state - 5
    cpx last_enemy_offset
    beq leave_2847
    jmp update_enemies_loop
leave_2847:
    rts

play_sound_for_damage:
    sta $3630                        ; sound_block_1 + 6 (duration)
    lda #$ff
    sta $362d                        ; sound_block_1 + 1 (volume high)
    lda #$10
    ldx #$f1
    ldy #$07
    jsr play_sound_on_channel_A_volume_X_pitch_Y
    lda #$11
    sta sound_block_0                ; sound_block_0 + 0 (channel)
    lda #$08
    ldx #$03
    ldy #$b4
    jsr play_sound_volume_X_pitch_Y_duration_A
    lda #$00
    sta $362d                        ; sound_block_1 + 1 (volume high)
    lda #$03
    sta $3630                        ; sound_block_1 + 6 (duration)
    rts

consider_plotting_enemy:
    lda #$fa                         ; UNCROPPED_ENEMY
    sta flipped_sprite_cropping_type_or_width ; Set to &fa to treat as uncropped enemy if flipped
    lda enemy_tile_fraction_and_frame ; This contains only the tile fraction here
    cmp #$04
    bne not_new_tile
    lda #$00
    sta enemy_tile_fraction_and_frame
    jsr move_enemy
not_new_tile:
    lda enemy_direction_and_state
    cmp #$02                         ; STATE_STATIONARY
    bcc not_stationary_or_skeleton
is_stationary_or_skeleton:
    dec enemy_tile_fraction_and_frame ; Keep current tile fraction (undone at &291a or &299d)
    lda enemy_tile_fraction_and_frame
    cmp #$ff
    bne skip_wraparound_2895
    lda #$03
    sta enemy_tile_fraction_and_frame
skip_wraparound_2895:
not_stationary_or_skeleton:
    lda #$03
    sta columns_to_plot
    lda #$00                         ; Set to zero to indicate enemy not cropped to left
    sta cropped_to_left              ; and edge of enemy needs unplotting
    lda enemy_tile_x
    asl a
    asl a
    tax
    lda left_edge_tile_address_low
    clc
    adc left_edge_x_fraction
    sta $74                          ; left_edge_x
    lda enemy_direction_and_state
    and #$01                         ; STATE_DIRECTION
    bne is_facing_left_28b7
is_facing_right_28af:
    txa
    clc
    adc enemy_tile_fraction_and_frame
    tax
    jmp check_left_edge
is_facing_left_28b7:
    stx $75                          ; enemy_x
    sec
    lda $75                          ; enemy_x
    sbc enemy_tile_fraction_and_frame
    sec
    sbc #$02
    tax
check_left_edge:
    txa                              ; enemy_x
    sec
    sbc $74                          ; left_edge_x
    sta $7b                          ; enemy_x_relative_to_left_edge
    cmp #$1c                         ; 7 * 4
    bcc skip_cropping
    cmp #$20                         ; 8 * 4
    bcc crop_to_right
    cmp #$fc
    bcc not_visible
crop_to_left:                        ; # Enemy is on or straddles left edge of screen
    eor #$fc
    sta columns_to_plot
    ldx #$02                         ; Set to two to indicate not cropped to left by default
    stx cropped_to_left              ; but no edge unplotting required if enemy moving right
    cmp #$03
    beq skip_cropping
    tax
    stx size_for_offset_table        ; Number of columns to plot
    lda enemy_direction_and_state
    cmp #$04                         ; : STATE_SKELETON
    bcc not_skeleton_28f5
    lda enemy_direction_and_state
    and #$0e
    sec
    sbc #$04                         ; STATE_SKELETON
    asl a
    clc
    adc size_for_offset_table        ; Height of skeleton sprite adds 0, 4, 8 or 12
    tax
not_skeleton_28f5:
    lda left_crop_offsets,x
    ldx size_for_offset_table        ; Number of columns to plot
    clc
    adc $5d                          ; enemy_sprite_address_low  # Calculate start of visible sprite
    sta $5d                          ; enemy_sprite_address_low
    lda $a4                          ; enemy_sprite_address_high
    adc #$00
    sta $a4                          ; enemy_sprite_address_high
    dex
    txa
    sta columns_to_plot_minus_one
    lda #$02
    sec
    sbc columns_to_plot_minus_one
    asl a
    asl a
    asl a
    sta enemy_screen_address_offset
    lda #$01                         ; Set to one to indicate enemy cropped to left, and so
    sta cropped_to_left              ; no edge unplotting required if enemy moving right
    jmp skip_cropping
not_visible:
    inc enemy_tile_fraction_and_frame ; Increase tile fraction, i.e. move enemy a fraction
    rts
crop_to_right:                       ; # Enemy straddles right edge of screen
    sta $74                          ; enemy_x_relative_to_left_edge
    lda #$fb                         ; CROPPED_ENEMY
    sta flipped_sprite_cropping_type_or_width ; Set to &fb to treat as enemy cropped to right if flipped
    sec
    lda $74                          ; enemy_x_relative_to_left_edge
    sbc #$1c
    sta enemy_x_relative_to_right_edge
    sec
    lda #$03
    sbc enemy_x_relative_to_right_edge
    sta columns_to_plot
skip_cropping:
    ldx enemy_tile_x
    ldy enemy_tile_y
    jsr calculate_enemy_screen_address
    lda #$01                         ; &0101 = sprite_space + 1
    sta $72                          ; sprite_address_low
    sta $73                          ; sprite_address_high
    lda enemy_direction_and_state
    and #$01                         ; STATE_DIRECTION
    bne is_facing_left_2966
is_facing_right_2944:
    lda cropped_to_left              ; Zero if edge of enemy needs unplotting
    beq unplot_left_edge_of_enemy
    jmp move_and_plot_enemy_without_unplotting
unplot_left_edge_of_enemy:
    lda enemy_tile_fraction_and_frame
    asl a
    asl a
    asl a
calculate_screen_address_for_unplotting_enemy:
    clc
    adc screen_address_low
    sta screen_address_low
    lda screen_address_high
    adc #$00
    bpl skip_wraparound_295d
    lda #$60
skip_wraparound_295d:
    sta screen_address_high
    ldx #$01
    ldy #$20
    jmp unplot_move_and_replot_enemy
is_facing_left_2966:
    lda $7b                          ; enemy_x_relative_to_left_edge
    cmp #$1c
    beq move_and_plot_enemy_without_unplotting
    lda cropped_to_left              ; One if enemy is cropped to left
    cmp #$01
    beq unplot_right_edge_of_enemy
    lda columns_to_plot
    cmp #$03                         ; If enemy is cropped to right and moving left,
    bne move_and_plot_enemy_without_unplotting ; skip unplotting right edge
unplot_right_edge_of_enemy:
    lda enemy_tile_fraction_and_frame
    asl a
    asl a
    asl a
    sta $76                          ; offset
    sec
    lda screen_address_low
    sbc $76                          ; offset
    sta screen_address_low
    lda screen_address_high
    sbc #$00
    cmp #$60
    bcs L_2990                       ; skip_wraparound
    lda #$7f
L_2990:
    sta screen_address_high
skip_wraparound_2992:
    lda #$10
    jmp calculate_screen_address_for_unplotting_enemy
to_plot_enemy:
    jmp plot_enemy                   ; Unused code
unplot_move_and_replot_enemy:
    jsr plot_sprite                  ; Unplot enemy
move_and_plot_enemy_without_unplotting:
    inc enemy_tile_fraction_and_frame ; Increase tile fraction, i.e. move enemy a fraction
    lda columns_to_plot
    bne plot_enemy
    rts
plot_enemy:
    ldx enemy_tile_x
    ldy enemy_tile_y
    jsr calculate_enemy_screen_address
    jsr adjust_screen_address_to_allow_for_left_cropping
    lda enemy_direction_and_state
    and #$01                         ; STATE_DIRECTION
    bne is_facing_left_29cb
is_facing_right_29b4:
    lda enemy_tile_fraction_and_frame
    asl a
    asl a
    asl a
    clc
    adc screen_address_low
    sta screen_address_low
    lda screen_address_high
    adc #$00
    bpl skip_wraparound_29c6
    lda #$60
skip_wraparound_29c6:
    sta screen_address_high
    jmp consider_clearing_skeleton
is_facing_left_29cb:
    lda enemy_tile_fraction_and_frame
    asl a
    asl a
    asl a
    sta $72                          ; sprite_address_low
    sec
    lda screen_address_low
    sbc $72                          ; sprite_address_low
    sta screen_address_low
    lda screen_address_high
    sbc #$00
    cmp #$60
    bcs skip_wraparound_29e3
    lda #$7f
skip_wraparound_29e3:
    sta screen_address_high
consider_clearing_skeleton:
    ldy #$20                         ; Height of non-skeleton sprites and skeleton_sprite_zero
    lda #$00
    sta size_for_offset_table
    lda enemy_direction_and_state
    cmp #$06                         ; STATE_SKELETON + 2
    bcc skip_clearing_skeleton
    lda screen_address_low
    pha                              ; screen_address_low
    lda screen_address_high
    pha                              ; screen_address_high
    lda #$01
    sta $72                          ; sprite_address_low
    sta $73                          ; sprite_address_high
    ldx columns_to_plot
    ldy #$20
    jsr plot_sprite                  ; Unplot skeleton
    pla                              ; screen_address_high
    sta screen_address_high
    pla                              ; screen_address_low
    sta screen_address_low
    ldx #$01                         ; Move one group down for skeleton_sprite_one
    ldy #$18                         ; Set height for skeleton_sprite_one
    lda enemy_direction_and_state
    cmp #$0c                         ; STATE_SKELETON + 6
    bcs leave_2a51
    and #$0e
    cmp #$06                         ; STATE_SKELETON + 4
    beq set_size_for_offset_table
    inx                              ; Move two groups down for skeleton_sprite_two
    ldy #$10                         ; Set height for skeleton_sprite_two
    cmp #$08                         ; STATE_SKELETON + 2
    beq set_size_for_offset_table
    inx                              ; Move three groups down for skeleton_sprite_three
    ldy #$08                         ; Set height for skeleton_sprite_three
set_size_for_offset_table:
    txa
    asl a
    asl a
    asl a
    sta size_for_offset_table
    txa
    clc
    adc screen_address_high
    bpl skip_wraparound_2a33
    sec
    sbc #$20
skip_wraparound_2a33:
    sta screen_address_high
skip_clearing_skeleton:
    lda $5d                          ; enemy_sprite_address_low
    sta $72                          ; sprite_address_low
    lda $a4                          ; enemy_sprite_address_high
    sta $73                          ; sprite_address_high
    ldx columns_to_plot
    lda enemy_direction_and_state
    and #$01                         ; STATE_DIRECTION
    beq is_flipped_2a4b
not_flipped:
    jsr plot_sprite
    jmp consider_enemy_firing
is_flipped_2a4b:
    jsr plot_flipped_enemy
    jmp consider_enemy_firing
leave_2a51:
    rts

lose_life:
    jsr remove_colliding_blasters
    jsr set_colour_zero_to_black
    lda player_stance
    bne skip_skeleton                ; Don't plot skeleton if not STANCE_STANDING
    lda player_screen_address_low
    sta screen_address_low
    lda player_screen_address_high
    sta screen_address_high
    lda #$e0                         ; &0be0 = skeleton_sprite_zero
    sta $72                          ; sprite_address_low
    lda #$0b
    sta $73                          ; sprite_address_high
    ldx #$03
    ldy #$20
    jsr plot_sprite                  ; Plot skeleton for dead player
skip_skeleton:
    dec lives
    bne not_game_over
    pha                              ; Remove call to lose_life from stack
    pha
    jmp game_over_screen_after_delay
not_game_over:
    lda #$08
    jsr play_sound_for_damage
    jsr very_long_delay
    lda #$25
    sta suit_energy
new_life:
    lda #$00                         ; STANCE_STANDING
    sta player_stance
    sta obstacle_pixel_value
    sta left_edge_x_fraction
    lda #$03
    sta right_edge_x_fraction
    jsr initialise_mines_and_blasters
    lda #$25
    sta blaster_energy
    lda #$0c
    sta crtc_address_high
    dec $ca                          ; objects_carried + &a (OBJECT_PLUTONIUM)  # Prevent game from being completed if life lost
    lda initial_player_x
    sta player_x
    bpl in_left_left
in_right_lift:
    lda #$00
    sta screen_start_address_low
    sta player_direction             ; Set to zero to indicate facing right
    lda #$67
    sta screen_start_address_high
    lda #$73
    sta player_screen_address_high
    lda #$c0
    sta player_screen_address_low
    lda #$e0
    sta left_edge_tile_address_low
    lda #$fc
    sta right_edge_tile_address_low
    lda #$e0
    sta crtc_address_low
    jmp display_level
in_left_left:
    lda #$00
    sta screen_start_address_low
    sta left_edge_tile_address_low
    sta crtc_address_low
    lda #$1c
    sta right_edge_tile_address_low
    lda #$6c
    sta player_screen_address_high
    lda #$20
    sta player_screen_address_low
    lda #$01
    sta player_direction             ; Set to non-zero to indicate facing left
    lda #$60
    sta screen_start_address_high
    jmp display_level

initialise_level:
    ldx level
    lda $2b70,x                      ; initial_enemy_position_offsets + 1
    sta last_initial_enemy_offset
    lda initial_enemy_position_offsets,x
    tax
    ldy #$00
initialise_enemies_loop:
    lda level
    lsr a
    clc
    adc #$01
    sta a:enemies_energy_and_initial_flags,y ; Enemy energy is (level / 2) + 1
    lda initial_enemy_positions,x
    sta a:enemies_x,y
    lda $4141,x                      ; initial_enemy_positions + 1
    sta a:enemies_y,y
    and #$f0
    clc
    adc a:enemies_energy_and_initial_flags,y
    sta a:enemies_energy_and_initial_flags,y
    lsr a
    lsr a
    lsr a
    lsr a
    and #$03
    sta a:enemies_direction_and_state,y ; &01 set if facing left, &02 set if stationary
    lda a:enemies_y,y
    and #$07
    sta a:enemies_y,y
    lda #$01
    sta a:enemies_tile_fraction_and_frame,y ; Set frame to zero, tile fraction to one
    iny                              ; Move to next enemy slot
    iny
    iny
    iny
    iny
    inx
    inx
    cpx last_initial_enemy_offset
    bne initialise_enemies_loop
    sty last_enemy_offset
initialise_mines_and_blasters:
    ldx #$06
    stx mines
initialise_mines_loop:
    lda #$00
    sta $02f5,x                      ; mines_state - 1  # Set to zero to indicate mine not used
    dex
    bne initialise_mines_loop
    ldx #$00
    lda #$ff
initialise_blasters_loop:
    sta blasters_ttl,x               ; Set to &ff to indicate no blaster in slot
    inx
    inx
    inx
    inx
    cpx #$18
    bne initialise_blasters_loop
    ldx level
    lda level_offsets_table,x
    beq is_surface_or_factory
    cmp #$30
    beq is_surface_or_factory
    lda $0a20                        ; enemy_sprite_zero + &20
    cmp #$77                         ; 0333
    bne leave_2b6e
    jmp swap_enemy_colours
is_surface_or_factory:
    lda $0a20                        ; enemy_sprite_zero + &20
    cmp #$77                         ; 0333
    beq leave_2b6e
    jmp swap_enemy_colours
leave_2b6e:
    rts

;      0  1  2  3  4  5  6  7  8  9  a  b  c
initial_enemy_position_offsets:
    .byte $00,$02,$12,$24,$38,$4c,$60,$74,$7a,$8c,$9e,$b2,$bc

calculate_enemy_screen_address:      ; # Called with X = enemy_tile_x, Y = enemy_tile_y
    tya
    asl a
    asl a
    sta enemy_y
    lda left_edge_tile_address_low
    clc
    adc left_edge_x_fraction
    sta $74                          ; left_edge_x
    txa
    asl a
    asl a
    cmp $74                          ; left_edge_x
    bcs is_right_of_left_edge
is_left_of_left_edge:
    sta $75                          ; enemy_x
    sec
    lda $74                          ; left_edge_x
    sbc $75                          ; enemy_x
    asl a
    asl a
    asl a
    sta $73                          ; offset
    sec
    lda screen_start_address_low
    sbc $73                          ; offset
    sta screen_address_low
    lda screen_start_address_high
    sbc #$00
    cmp #$60
    bcs skip_wraparound_2bac
    lda #$7f
skip_wraparound_2bac:
    clc
    adc enemy_y
    bpl skip_wraparound_2bb4
    sec
    sbc #$20
skip_wraparound_2bb4:
    sta screen_address_high
    rts
is_right_of_left_edge:
    sec
    sbc $74                          ; left_edge_x
    asl a
    asl a
    asl a
    php
    clc
    adc screen_start_address_low
    sta screen_address_low
    lda screen_start_address_high
    adc enemy_y
    plp
    adc #$00
    bpl skip_wraparound_2bcf
    sec
    sbc #$20
skip_wraparound_2bcf:
    sta screen_address_high
    rts

;      0  1  2  3 columns to plot
left_crop_offsets:
    .byte $00,$40,$20,$00            ; ; 4 groups
    .byte $00,$30,$18,$00            ; ; 3 groups
    .byte $00,$20,$10,$00            ; ; 2 groups
    .byte $00,$10,$08,$00            ; ; 1 group

adjust_screen_address_to_allow_for_left_cropping:
    lda cropped_to_left              ; One if enemy is cropped to left
    cmp #$01
    bne leave_2bf9
    clc
    lda screen_address_low
    adc enemy_screen_address_offset
    sta screen_address_low
    lda screen_address_high
    adc #$00
    bpl skip_wraparound_2bf7
    lda #$60
skip_wraparound_2bf7:
    sta screen_address_high
leave_2bf9:
    rts

swap_enemy_colours:                  ; # Swaps red and white in enemy sprites
    lda #$0a                         ; &0a00 = enemy_sprite_zero
    sta $71                          ; sprite_address_high
    lda #$00
    sta $70                          ; sprite_address_low
swap_enemy_colours_byte_loop:
    ldx #$00
    ldy #$00
    sty output_byte
    lda ($70),y                      ; sprite_address
    sta input_byte
swap_enemy_colours_pixel_loop:
    lda input_byte
    stx pixel
shift_right_loop:
    cpx #$00
    beq shifted_right
    dex
    lsr a
    jmp shift_right_loop
shifted_right:
    and #$11                         ; 0003
    sta pixel_value
    lsr a
    lsr a
    lsr a
    clc
    adc pixel_value
    and #$03
    tax
    lda colour_swap_table,x
    ldx pixel
shift_left_loop:
    cpx #$00
    beq shifted_left
    asl a
    dex
    jmp shift_left_loop
shifted_left:
    clc
    adc output_byte
    sta output_byte
    ldx pixel
    inx
    cpx #$04
    bne swap_enemy_colours_pixel_loop
    lda output_byte
    ldy #$00
    sta ($70),y                      ; sprite_address
    inc $70                          ; sprite_address_low
    bne skip_page_2c4c
    inc $71                          ; sprite_address_high
skip_page_2c4c:
    lda $70                          ; sprite_address_low
    cmp #$e0                         ; &0be0 = enemy_sprite_four + &60
    bne swap_enemy_colours_byte_loop
    lda $71                          ; sprite_address_high
    cmp #$0b
    bne swap_enemy_colours_byte_loop
    rts

;      0  1  2  3                                                   #  input: 0 1 2 3
colour_swap_table:
    .byte $00,$11,$10,$01            ;   # output: 0 3 2 1

check_for_enemy_collision_with_mines:
    lda enemy_direction_and_state
    cmp #$04                         ; STATE_SKELETON
    bcc not_skeleton_2c64
    rts
not_skeleton_2c64:
    lda enemy_tile_y
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc #$18
    sta enemy_feet_y
    lda enemy_direction_and_state
    and #$01                         ; STATE_DIRECTION
    bne is_facing_left_2c84
is_facing_right_2c76:
    lda enemy_tile_x
    asl a
    asl a
    clc
    adc enemy_tile_fraction_and_frame ; This contains only the tile fraction here
    tax
    inx
    inx
    txa
    jmp set_enemy_feet_x
is_facing_left_2c84:
    lda enemy_tile_x
    asl a
    asl a
    sec
    sbc enemy_tile_fraction_and_frame ; This contains only the tile fraction here
set_enemy_feet_x:
    sta enemy_feet_x
    ldx #$00
check_for_enemy_collision_with_mines_loop:
    lda mines_state,x                ; Positive if mine exploding or not placed
    bpl consider_next_mine_2cae
    lda mines_x,x
    cmp enemy_feet_x
    bne consider_next_mine_2cae
    lda mines_y,x
    cmp enemy_feet_y
    bne consider_next_mine_2cae
    lda #$00
    sta mines_state,x                ; Set to zero to indicate mine not placed
    lda #$01
    sta enemy_energy_and_initial_flags ; Will become zero in damage_player_or_enemy
    jmp damage_player_or_enemy
consider_next_mine_2cae:
    inx
    cpx #$06
    bne check_for_enemy_collision_with_mines_loop
    rts

drop_mine:
    lda mines
    beq L_2cc4                       ; leave
    ldx #$00
find_slot_for_mine_loop:
    lda mines_state,x                ; Zero if mine not exploding or placed
    beq found_slot_2cc5
    inx
    cpx #$06
    bne find_slot_for_mine_loop
L_2cc4:
    rts
found_slot_2cc5:
    stx mine_slot
    jsr calculate_player_screen_address_offset ; Returns X = offset_high
    txa
    asl a
    asl a
    asl a
    clc
    adc #$18
    sta mine_y
    lda player_direction             ; Zero if facing right, non-zero if facing left
    lda player_screen_address_low
    and #$07
    bne leave_2d1a
    txa
    and #$01
    bne leave_2d1a
    jsr get_player_feet_screen_address
    ldy #$00
check_for_obstacles_to_mine_loop:
    lda (screen_address),y
    bne leave_2d1a
    iny
    cpy #$08
    bne check_for_obstacles_to_mine_loop
    lda screen_address_low
    sta ground_screen_address_low
    clc
    lda screen_address_high
    adc #$01
    bpl skip_wraparound_2cfc
    sec
    sbc #$20
skip_wraparound_2cfc:
    sta ground_screen_address_high
    ldy #$00
    lda (ground_screen_address),y
    beq leave_2d1a
    dec mines
    ldx mine_slot
    lda $75                          ; player_feet_x
    sta mines_x,x
    lda mine_y
    sta mines_y,x
    lda #$ff
    sta mines_state,x                ; Set to negative to indicate mine placed
    jmp plot_mine
leave_2d1a:
    rts

consider_enemy_firing:
    jsr calculate_player_screen_address_offset ; Returns X = offset_high
    stx $70                          ; offset_high
    lda enemy_tile_y
    asl a
    asl a
    sec
    sbc $70                          ; offset_high
    cmp #$04
    bcc is_within_range_vertically
    cmp #$fe
    bcs is_within_range_vertically   ; Enemies can't fire if not level with player
    rts
is_within_range_vertically:
    lda $fe64                        ; User VIA timer 1 counter LSB
    and #$03                         ; 1 in 4 chance of firing
    bne leave_2d3d
    lda enemy_direction_and_state
    cmp #$04                         ; STATE_SKELETON
    bcc not_skeleton_2d3e            ; Skeletons can't fire
leave_2d3d:
    rts
not_skeleton_2d3e:
    lda left_edge_tile_address_low
    clc
    adc left_edge_x_fraction
    sta $54                          ; left_edge_x
    ldx enemy_tile_fraction_and_frame
    dex
    lda enemy_direction_and_state
    and #$01                         ; STATE_DIRECTION
    beq is_facing_right_2d54
is_facing_left_2d4e:
    lda #$00
    sec
    sbc enemy_tile_fraction_and_frame
    tax
is_facing_right_2d54:
    stx enemy_x_fraction
    lda enemy_tile_x
    asl a
    asl a
    clc
    adc enemy_x_fraction
    sta $51                          ; enemy_x
    sec
    sbc $54                          ; left_edge_x
    sta enemy_relative_x
    cmp #$20
    bcc is_on_screen                 ; Enemies can't fire if not on screen
    rts
is_on_screen:
    ldx #$08
find_slot_for_blaster_loop:
    lda blasters_ttl,x               ; &ff if no blaster in slot
    cmp #$ff
    beq found_slot_2d7a
    inx
    inx
    inx
    inx
    cpx #$18
    bne find_slot_for_blaster_loop
    rts
found_slot_2d7a:
    lda enemy_direction_and_state
    and #$01                         ; STATE_DIRECTION
    sta blasters_direction,x         ; Set to zero if firing right, non-zero if firing left
    lda enemy_tile_y
    asl a
    asl a
    clc
    adc #$01
    sta blaster_offset_high
    lda enemy_relative_x
    asl a
    asl a
    asl a
    sta blaster_offset_low
    lda blasters_direction,x         ; Zero if firing right, non-zero if firing left
    bne is_firing_left
is_firing_right:
    lda $51                          ; enemy_x
    cmp player_x
    bcc is_left_of_enemy
    rts
is_left_of_enemy:
    clc
    lda blaster_offset_low
    adc #$1d
    jmp add_enemy_blaster
is_firing_left:
    lda $51                          ; enemy_x
    cmp player_x
    bcs is_right_of_enemy
    rts
is_right_of_enemy:
    sec
    lda blaster_offset_low
    sbc #$03
add_enemy_blaster:
    sta blaster_offset_low
    lda #$0e
    sta blasters_ttl,x
    clc
    lda screen_start_address_low
    adc blaster_offset_low
    sta blasters_screen_address_low,x
    lda screen_start_address_high
    adc blaster_offset_high
    bpl skip_wraparound_2dc5
    sec
    sbc #$20
skip_wraparound_2dc5:
    sta blasters_screen_address_high,x
    ldx #$02
    ldy #$8c
    lda #$01
    jmp play_sound_volume_X_pitch_Y_duration_A_on_channel_two

get_player_feet_screen_address:
    lda player_direction             ; Zero if facing right, non-zero if facing left
    bne is_facing_left_2de9
is_facing_right_2dd4:
    clc
    lda player_x
    adc #$03
    sta $75                          ; player_feet_x
    clc
    lda player_screen_address_low
    adc #$18
    sta screen_address_low
    lda player_screen_address_high
    adc #$03
    jmp check_for_wraparound
is_facing_left_2de9:
    lda player_x
    sta $75                          ; player_feet_x
    dec $75                          ; player_feet_x
    clc
    lda player_screen_address_low
    adc #$f8
    sta screen_address_low
    lda player_screen_address_high
    adc #$02
check_for_wraparound:
    bpl skip_wraparound_2dff
    sec
    sbc #$20
skip_wraparound_2dff:
    sta screen_address_high
    rts

buffer_player_points_and_blasters:
    ldx #$00
    lda #$04
    sta $73                          ; count
buffer_player_points_loop:
    jsr get_player_point             ; Returns X halved
    sta player_points_buffer,x
    ldx $72                          ; offset
    dec $73                          ; count
    bne buffer_player_points_loop
    jmp buffer_colliding_blasters

check_for_enemy_collision_with_blasters_and_player:
    jsr check_for_collision_with_blasters
check_for_collision_with_player:
    ldx #$00
    lda #$04
    sta $73                          ; count
check_for_collision_with_player_loop:
    jsr get_player_point
    cmp player_points_buffer,x
    bne collided_with_player
    ldx $72                          ; offset
    dec $73                          ; count
    bne check_for_collision_with_player_loop
    rts
collided_with_player:
    lda enemy_direction_and_state
    cmp #$04                         ; STATE_SKELETON
    bcs leave_2e46
    sec
    lda suit_energy
    sbc #$0a                         ; Colliding with enemy drains 10 energy
    sta suit_energy
    lda #$01
    sta enemy_energy_and_initial_flags ; Will become zero in damage_player_or_enemy
    jsr damage_player_or_enemy
    jmp set_colour_zero_to_white
leave_2e46:
    rts

get_player_point:
    lda standing_point_offsets,x
    ldy player_stance
    beq add_to_screen_address_low
    cpy #$01                         ; STANCE_KNEELING
    bne not_kneeling_2e58
    lda kneeling_point_offsets,x
    jmp add_to_screen_address_low
not_kneeling_2e58:
    cpy #$02                         ; STANCE_CRAWLING
    bne add_to_screen_address_low
    lda crawling_point_offsets,x
add_to_screen_address_low:
    clc
    adc player_screen_address_low
    sta screen_address_low
    lda player_screen_address_high
    adc $2e7f,x                      ; standing_point_offsets + 1  # Bug: uses &03 for bottom two crawling points, not &01
    bpl skip_wraparound_2e6e
    sec
    sbc #$20
skip_wraparound_2e6e:
    sta screen_address_high
    ldy #$00
    lda (screen_address),y
    inx
    inx
    stx $72                          ; offset
    tay
    txa
    lsr a
    tax
    tya
    rts

standing_point_offsets:
    .byte $10,$00
    .byte $00,$00
    .byte $13,$03
    .byte $03,$03

kneeling_point_offsets:
    .byte $10,$01
    .byte $00,$01
    .byte $13,$03
    .byte $03,$03

crawling_point_offsets:
    .byte $28,$00
    .byte $00,$00
    .byte $2b,$01
    .byte $03,$01

buffer_colliding_blasters:
    ldx #$00
    ldy #$00
buffer_colliding_blasters_loop:
    lda blasters_ttl,x
    cmp #$fe                         ; BLASTER_COLLIDING
    bne consider_next_blaster_2eaf
    lda (blasters_screen_address,x)
    sta blasters_buffer,y
    lda enemy_energy_and_initial_flags
    cmp #$20                         ; STATE_STATIONARY * &10
    bcc consider_next_blaster_2eaf   ; Branch if moving enemy
    lda #$00
    sta (blasters_screen_address,x)
consider_next_blaster_2eaf:
    inx
    inx
    inx
    inx
    iny
    cpy #$06
    bne buffer_colliding_blasters_loop
    rts

check_for_collision_with_blasters:
    ldx #$00
    ldy #$00
check_for_collision_with_blasters_loop:
    lda blasters_ttl,x
    cmp #$fe                         ; BLASTER_COLLIDING
    bne consider_next_blaster_2eec
    lda enemy_energy_and_initial_flags
    cmp #$20                         ; STATE_STATIONARY * &10
    bcs is_stationary                ; Branch if not moving enemy
    lda (blasters_screen_address,x)
    cmp blasters_buffer,y
    beq unplot_colliding_blaster
    jsr damage_player_or_enemy       ; Blaster hit moving enemy
    ldx $70                          ; tmp_x
    ldy $71                          ; tmp_y
    jmp consider_next_blaster_2eec
is_stationary:
    lda (blasters_screen_address,x)
    cmp #$00
    beq unplot_colliding_blaster
    jsr damage_player_or_enemy       ; Blaster hit stationery enemy or player
    ldx $70                          ; tmp_x
    ldy $71                          ; tmp_y
unplot_colliding_blaster:
    lda blasters_buffer,y
    sta (blasters_screen_address,x)
consider_next_blaster_2eec:
    inx
    inx
    inx
    inx
    iny
    cpy #$06
    bne check_for_collision_with_blasters_loop
    rts

remove_colliding_blasters:
    ldx #$00
remove_colliding_blasters_loop:
    lda blasters_ttl,x
    cmp #$fe                         ; BLASTER_COLLIDING
    bne consider_next_blaster_2f00
    inc blasters_ttl,x               ; Set to &ff to indicate no blaster in slot
consider_next_blaster_2f00:
    inx
    inx
    inx
    inx
    cpx #$18
    bne remove_colliding_blasters_loop
    rts

damage_player_or_enemy:
    stx $70                          ; tmp_x
    sty tmo_y
    lda enemy_to_update              ; Positive if enemy, negative if collision with player
    bpl is_enemy
is_player:
    dec suit_energy                  ; Enemy blaster hit drains 2 energy
    dec suit_energy
play_short_sound_for_damage:
    lda #$02
    jmp play_sound_for_damage
is_enemy:
    lda enemy_direction_and_state
    cmp #$04                         ; STATE_SKELETON
    bcs L_2f47                       ; leave
    ldy #$05                         ; Score 500 for killing enemy
    ldx #$05
    jsr add_to_score
    dec enemy_energy_and_initial_flags ; Player blaster hits drains 1 enemy energy
    lda enemy_energy_and_initial_flags
    and #$07
    bne play_short_sound_for_damage  ; Is the enemy out of energy?
    ldx enemy_to_update
    lda #$70                         ; (FRAME_SKELETON - 1) * &10  # Becomes &80 at &2800
    sta enemies_tile_fraction_and_frame,x
    lda #$08
    jsr play_sound_for_damage
    lda enemy_direction_and_state
    and #$01                         ; STATE_DIRECTION
    clc
    adc #$04                         ; STATE_SKELETON
    sta enemy_direction_and_state
    ldx $70                          ; tmp_x
    ldy $71                          ; tmp_y
L_2f47:
    rts

set_colour_zero_to_white:
    ldx #$07
    jsr set_palette
    ldx #$17
    jsr set_palette
    ldx #$47
    jsr set_palette
    ldx #$57
    jsr set_palette                  ; Unnecessary code
set_palette:
    lda #$9b                         ; Write to Video ULA palette register and RAM copy
    ldy #$00
    jmp OSBYTE

wrist_terminal_screen:
    jsr prepare_status_screen
    ldx #$17
    ldy #$3e
    jsr calculate_screen_address
    lda #$80                         ; &4780 = sprite_face
    sta $72                          ; sprite_address_low
    lda #$47
    sta $73                          ; sprite_address_high
    ldx #$04
    ldy #$20
    jsr plot_sprite                  ; Plot face
    ldy #$00
write_wrist_terminal_loop:
    lda wrist_terminal_text,y
    jsr plot_character
    iny
    cpy #$7e
    bne write_wrist_terminal_loop
    clc
    lda mines
    adc #$30                         ; "0"
    jsr plot_character               ; Plot number of mines
    ldx #$11
    ldy #$09
    jsr tab_to_x_y
    jsr plot_sector_number
    ldx #$07
    ldy #$c6
    jsr calculate_screen_address
    lda #$a8                         ; &08a8 = object_sprite_passcard
    sta $72                          ; sprite_address_low
    lda #$08
    sta $73                          ; sprite_address_high
    ldx #$03
    ldy #$08
    jsr plot_sprite                  ; Plot pass card
    ldx #$13
    ldy #$c6
    jsr calculate_screen_address
    lda #$40                         ; &0c40 = object_sprite_energy_cell
    sta $72                          ; sprite_address_low
    lda #$0c
    sta $73                          ; sprite_address_high
    ldx #$03
    ldy #$08
    jsr plot_sprite                  ; Plot energy cell
    ldx #$19
    ldy #$0c
    jsr tab_to_x_y
    clc
    lda lives
    adc #$30                         ; "0"
    jsr plot_character               ; Plot number of lives
    jsr plot_status
    ldx #$11
    ldy #$0b
    jsr tab_to_x_y
    jsr plot_score
    ldx #$07
    ldy #$08
    jsr tab_to_x_y
    jsr plot_level_name
    jsr flush_buffers
    jsr play_chime
wrist_terminal_screen_loop:
    jsr plot_status
    jsr OSRDCH
    cmp #$53                         ; "S"
    beq charge_suit_or_blaster
    cmp #$42                         ; "B"
    beq charge_suit_or_blaster
    cmp #$4d                         ; "M"
    bne not_maps
    jmp map_screen
not_maps:
    cmp #$20                         ; " "
    bne wrist_terminal_screen_loop
to_display_level_300c:
    jmp display_level
charge_suit_or_blaster:
    ldx $c1                          ; objects_carried + &1 (OBJECT_ENERGY_CELL)
    beq wrist_terminal_screen_loop
    dec $c1                          ; objects_carried + &1 (OBJECT_ENERGY_CELL)
    ldx #$25                         ; Energy cell recharges to 37 energy
    cmp #$42                         ; "B"
    beq charge_blaster
charge_suit:
    stx suit_energy
    jmp wrist_terminal_screen_loop
charge_blaster:
    stx blaster_energy
    jmp wrist_terminal_screen_loop

plot_mines_on_right_edge:
    lda right_edge_tile_address_high
    cmp #$57
    bne not_title_or_status_screen_3032
    lda right_edge_tile_address_low
    cmp #$a8
    bcs not_title_or_status_screen_3032
    rts
not_title_or_status_screen_3032:
    lda right_edge_tile_address_low
    clc
    adc right_edge_x_fraction
    sta $4f                          ; edge_x
    clc
    lda screen_start_address_low
    adc #$f8
    sta edge_screen_address_low
    lda screen_start_address_high
    adc #$00
    bpl plot_mines_on_screen_edge
    lda #$60
plot_mines_on_screen_edge:
    sta edge_screen_address_high
    lda #$00
    sta mine_to_plot
plot_mines_loop:
    ldx mine_to_plot
    lda mines_state,x                ; Positive if mine exploding or not placed
    bpl consider_next_mine_3080
    lda mines_x,x
    cmp $4f                          ; edge_x
    bne consider_next_mine_3080
    lda mines_y,x
    and #$07
    sta row_in_group
    lda mines_y,x
    lsr a
    lsr a
    lsr a
    sta group
    clc
    lda edge_screen_address_low
    adc row_in_group
    sta screen_address_low
    lda edge_screen_address_high
    adc group
    bpl skip_wraparound_307b
    sec
    sbc #$20
skip_wraparound_307b:
    sta screen_address_high
    jsr plot_mine
consider_next_mine_3080:
    inc mine_to_plot
    lda mine_to_plot
    cmp #$06
    bne plot_mines_loop
    rts

plot_mine:
    lda #$40                         ; &4540 = sprite_mine
    sta $72                          ; sprite_address_low
    lda #$45
    sta $73                          ; sprite_address_high
    ldx #$01
    ldy #$08
    jmp plot_unflipped_player

plot_mines_on_left_edge:
    lda left_edge_tile_address_low
    clc
    adc left_edge_x_fraction
    sta $4f                          ; edge_x
    lda screen_start_address_low
    sta edge_screen_address_low
    lda screen_start_address_high
    jmp plot_mines_on_screen_edge

plot_status:
    ldx #$0b
    ldy #$19
    jsr tab_to_x_y
    clc
    lda $c0                          ; objects_carried + &0 (OBJECT_PASSCARD)
    adc #$30                         ; "0"
    jsr plot_character               ; Plot number of pass cards
    ldx #$17
    ldy #$19
    jsr tab_to_x_y
    clc
    lda $c1                          ; objects_carried + &1 (OBJECT_ENERGY_CELL)
    adc #$30                         ; "0"
    jsr plot_character               ; Plot number of energy cells
    lda suit_energy
    lsr a
    ldx #$06
    ldy #$7f
    jsr plot_energy_bar              ; Plot suit energy
    lda blaster_energy
    lsr a
    ldx #$06
    ldy #$a6
plot_energy_bar:                     ; # Plot blaster energy
    sta energy
    lda #$14
    sta $7e                          ; count
    stx bar_x
    sty bar_y
plot_energy_bar_loop:
    ldx bar_x
    ldy bar_y
    jsr calculate_screen_address
    lda #$08                         ; &088a = sprite_bar_full
    sta $73                          ; sprite_address_high
    lda #$8a
    sta $72                          ; sprite_address_low
    lda $7e                          ; count
    cmp #$14
    bne not_left_end
    lda #$80                         ; &0880 = sprite_bar_left_end
    sta $72                          ; sprite_address_low
    jmp plot_energy_bar_section
not_left_end:
    cmp #$01
    bne not_right_end
    lda #$9e                         ; &089e = sprite_bar_right_end
    sta $72                          ; sprite_address_low
    jmp plot_energy_bar_section
not_right_end:
    lda energy
    beq use_empty
    dec energy
    jmp plot_energy_bar_section
use_empty:
    lda #$94                         ; &0894 = sprite_bar_empty
    sta $72                          ; sprite_address_low
plot_energy_bar_section:
    ldx #$01
    ldy #$0a
    jsr plot_sprite
    inc bar_x
    dec $7e                          ; count
    bne plot_energy_bar_loop
    rts

add_to_score:
    tya
    clc
    adc score,x
    sta score,x
    cmp #$0a
    bcc leave_313f
    sec
    sbc #$0a
    sta score,x
    dex
    cpx #$ff
    beq leave_313f
    ldy #$01
    jmp add_to_score
leave_313f:
    rts

plot_top_or_bottom_of_box:
    ldx #$08
    ldy box_y
    jsr calculate_screen_address
    lda #$6f                         ; &476f = sprite_box_top_or_bottom
    sta $72                          ; sprite_address_low
    lda #$47
    sta $73                          ; sprite_address_high
    ldx #$11
    ldy #$01
    jsr plot_sprite
    inc box_y
    rts

game_over_screen_after_delay:
    jsr set_colour_zero_to_black
    lda #$08
    jsr play_sound_for_damage
    jsr very_long_delay
game_over_screen:
    pla                              ; Remove consider_energy_warning_and_check_for_completion
    pla                              ; and to_update_events, or check_for_player_input and
    pla                              ; consider_checking_for_player_input from stack
    pla
    lda #$3c
    sta box_y
    jsr plot_top_or_bottom_of_box
plot_middle_of_box_loop:
    ldx #$08
    ldy box_y
    jsr calculate_screen_address
    lda #$5e                         ; &475e = sprite_box_middle
    sta $72                          ; sprite_address_low
    lda #$47
    sta $73                          ; sprite-address_high
    ldx #$11
    ldy #$01
    jsr to_plot_flipped_player
    inc box_y
    lda box_y
    cmp #$b4
    bne plot_middle_of_box_loop
    jsr plot_top_or_bottom_of_box
    ldy #$00
write_game_over_loop:
    lda game_over_text,y
    jsr plot_character
    iny
    cpy #$36
    bne write_game_over_loop
    jsr plot_space
    jsr plot_sector_number
    ldx #$09
    ldy #$0d
    jsr tab_to_x_y
    jsr plot_level_name
    ldx #$10
    ldy #$10
    jsr tab_to_x_y
    jsr plot_score
    ldx #$11
    ldy #$12
    jsr tab_to_x_y
    lda #$cc                         ; &4ccc = ranking_names
    sta name_address_low
    lda #$4c
    sta name_address_high
    ldx #$00
find_rank_loop:
    lda ranking_requirements,x
    inx
    cmp total_objects_collected      ; Ranking depends on total number of objects collected
    bcc find_rank_loop
    jsr plot_name
    jsr start_game_over_tune
    inc tune_finished                ; Set to non-zero to indicate game over tune playing
game_over_screen_loop:
    lda tune_finished                ; Zero if game over tune has finished playing
    beq skip_updating_tune
    jsr update_tune
skip_updating_tune:
    lda os_most_recently_pressed_key
    cmp #$e2                         ; SPACE
    bne game_over_screen_loop
    jsr flush_buffers
    jmp new_game

display_status_screen_level:
    lda left_edge_x_fraction         ; Store current level variables
    pha                              ; left_edge_x_fraction
    lda right_edge_x_fraction
    pha                              ; right_edge_x_fraction
    lda left_edge_tile_address_low
    pha                              ; left_edge_tile_address_low
    lda left_edge_tile_address_high
    pha                              ; left_edge_tile_address_high
    lda right_edge_tile_address_low
    pha                              ; right_edge_tile_address_low
    lda right_edge_tile_address_high
    pha                              ; right_edge_tile_address_high
    lda level
    pha                              ; level
    lda level_sprite_base
    pha                              ; level_sprite_base
    lda #$57                         ; &57a8 = level_0_data + &a8  # Use status screen
    sta right_edge_tile_address_high
    lda #$a8
    sta right_edge_tile_address_low
    lda #$0c                         ; Suppress plotting of objects
    sta level
    lda #$03
    sta right_edge_x_fraction
    jsr display_level
    pla                              ; level_sprite_base  # Restore level variables
    sta level_sprite_base
    pla                              ; level
    sta level
    pla                              ; right_edge_tile_address_high
    sta right_edge_tile_address_high
    pla                              ; right_edge_tile_address_low
    sta right_edge_tile_address_low
    pla                              ; left_edge_tile_address_high
    sta left_edge_tile_address_high
    pla                              ; left_edge_tile_address_low
    sta left_edge_tile_address_low
    pla                              ; right_edge_x_fraction
    sta right_edge_x_fraction
    pla                              ; left_edge_x_fraction
    sta left_edge_x_fraction
    rts

title_screen:
    jsr reset_tiles
    jsr initialise_variables
    jsr initialise_levels
    jsr clear_screen
    jsr initialise_level
    lda #$ff
    sta delay_length
    jsr delay_for_length
    jsr delay_for_length
    lda #$8e
    sta scroll_count
    lda #$0a
    sta player_screen_address_high   ; Unnecessary code
    lda #$10                         ; Suppress plotting of objects
    sta level
    lda #$40                         ; Use corner tiles
    sta level_sprite_base
    jsr scroll_right_for_count       ; Scroll through DROID and onto title screen
    clc
    lda screen_start_address_low
    adc #$3a
    sta map_screen_address_low
    lda screen_start_address_high
    adc #$0a
    bpl skip_wraparound_326b
    sec
    sbc #$20
skip_wraparound_326b:
    sta map_screen_address_high
    lda #$40
    sta map_tile_count
    lda #$00
    sta map_data_address_low
    sta level                        ; Use level_0_data for DROID logo
    jsr draw_map_from_addresses      ; Plot DROID logo using map sprites
    ldy #$00
write_title_screen_text_loop:
    lda title_screen_text,y
    jsr plot_character
    iny
    cpy #$3e
    bne write_title_screen_text_loop
    ldx #$14
    ldy #$d3
    jsr calculate_screen_address
    lda #$58                         ; &0c58 = sprite_stereo
    sta $72                          ; sprite_address_low
    lda #$0c
    sta $73                          ; sprite_address_high
    ldx #$03
    ldy #$08
    jsr plot_sprite
    jsr plot_music_state
    ldy #$00
    sty level
    sty $a2                          ; unused  # Unused variable
    lda deepest_level
    beq skip_jump_text
write_jump_text_loop:
    lda jump_text,y
    jsr plot_character
    iny
    cpy #$0f
    bne write_jump_text_loop
skip_jump_text:
    lda #$d0
    sta player_screen_address_low
    lda #$76
    sta player_screen_address_high
title_screen_loop:
    cmp #$a0                         ; f0
    bne f0_not_pressed_32c9
    lda #$01
    sta os_sound_suppression         ; Set to non-zero to suppress sound
    jsr plot_music_state
f0_not_pressed_32c9:
    cmp #$f1                         ; f1
    bne f1_not_pressed_32d5
    lda #$00
    sta os_sound_suppression         ; Set to zero to permit sound
    jsr plot_music_state
f1_not_pressed_32d5:
    jsr wait_for_vsync
    jsr remove_colliding_blasters
    jsr wait_for_vsync
    jsr update_blasters
    inc title_screen_frame_count
    lda title_screen_frame_count
    and #$01
    bne skip_title_screen_firing
    jsr plot_player_facing_direction
    lda $fe64                        ; User VIA timer 1 counter LSB
    and #$07
    bne skip_title_screen_firing
    jsr fire_blaster
skip_title_screen_firing:
    jsr update_tune
    lda os_most_recently_pressed_key
    ldx deepest_level
    beq j_not_pressed_3303
    cmp #$c5                         ; J
    beq jump_to_level
j_not_pressed_3303:
    cmp #$e2                         ; SPACE
    bne title_screen_loop
    jsr flush_buffers
    lda #$00
    sta level_sprite_base
    lda #$29
    sta scroll_count
    jsr scroll_right_for_count       ; Scroll onto right of Surface Defence sector one
initialise_variables_and_level:
    ldx #$00
backup_screen_variables_loop:
    lda $80,x                        ; Push screen variables
    pha
    inx
    cpx #$15
    bne backup_screen_variables_loop
    jsr initialise_variables
    ldx #$15
restore_screen_variables_loop:
    pla
    sta $7f,x
    dex
    bne restore_screen_variables_loop
    lda #$1e
    sta delay_length_low
    lda #$07
    sta delay_length_high
    lda #$24
    sta player_screen_address_low
    lda #$75
    sta player_screen_address_high
    lda #$0c
    sta maximum_jump_timer
    lda #$f8
    sta initial_player_x
    jmp initialise_level
jump_to_level:
    jsr initialise_variables_and_level
    ldx #$00
restore_score_loop:
    lda saved_score,x
    sta score,x
    inx
    cpx #$08
    bne restore_score_loop
    ldx #$00
restore_objects_carried_loop:
    lda saved_objects_carried,x
    sta objects_carried,x
    inx
    cpx #$10
    bne restore_objects_carried_loop
    lda saved_suit_energy
    sta suit_energy
    lda saved_blaster_energy
    sta blaster_energy
    lda saved_jet_pack_energy
    sta jet_pack_energy
    lda saved_lives
    sta lives
    lda saved_maximum_jump_timer
    sta maximum_jump_timer
    lda saved_total_objects_collected
    sta total_objects_collected
    ldx #$02
    ldy #$31                         ; NIBBLE_LIFT_TOP | NIBBLE_CHAIN * &10
    lda deepest_level
    cmp #$01
    bne jump_to_crews_quarters
jump_to_ancient_shrine:
    lda #$37                         ; NIBBLE_SHRINE_WALL | NIBBLE_CHAIN * &10
    sta $54f8                        ; level_3_data + &f8  # Stop player moving up in right lift
    stx $54f9                        ; level_3_data + &f9
    sty $54fa                        ; level_3_data + &fa
    lda #$03
    sta level
    lda #$54                         ; &5400 = level_3_data
    jmp set_tile_addresses_high
jump_to_crews_quarters:
    lda #$3a                         ; NIBBLE_QUARTERS_WALL | NIBBLE_CHAIN * &10
    sta $5104                        ; level_6_data + &04  # Stop player moving up in left lift
    stx $5105                        ; level_6_data + &05
    sty $5106                        ; level_6_data + &06
    lda #$06
    sta level
    lda #$04
    sta initial_player_x
    lda #$51                         ; &5100 = level_6_data
set_tile_addresses_high:
    sta left_edge_tile_address_high
    sta right_edge_tile_address_high
    jsr initialise_level
    jmp new_life

scroll_right_for_count:
    sei
    jsr wait_for_vsync
    lda #$01
    sta player_swapping_sides_on_rope ; Set to non-zero to indicate player swapping sides on rope
    lda #$00
    sta $7e                          ; count
scroll_right_for_count_loop:
    jsr delay
    jsr consider_scrolling_right
    inc player_x
    dec scroll_count
    bne scroll_right_for_count_loop
    cli
    rts

delay:
    lda #$03
    sta delay_length
delay_for_length:
    lda #$00
    sta delay_low
    sta delay_high
delay_loop:
    inc delay_low
    lda delay_low
    cmp #$6e
    bne delay_loop
    lda #$00
    sta delay_low
    inc delay_high
    lda delay_high
    cmp delay_length
    bne delay_loop
    rts

initialise_levels:
    ldx #$00
    ldy #$00
initialise_levels_loop:
    lda initial_tiles,x
    sta $00                          ; tile_address_low
    lda $40ed,x                      ; initial_tiles + 1
    sta $01                          ; tile_address_high
    lda $40ee,x                      ; initial_tiles + 2
    sta ($00),y                      ; tile_address
    inx
    inx
    inx
    cpx #$54
    bne initialise_levels_loop
    rts

plot_music_state:
    ldx #$16
    ldy #$c9
    jsr calculate_screen_address
    lda #$01                         ; &0170 = sprite_space + &70
    sta $73                          ; sprite_address_high
    lda #$70
    sta $72                          ; sprite_address_low
    lda os_sound_suppression
    bne is_off
    lda #$0c                         ; &0c70 = sprite_notes
    sta $73                          ; sprite_address_high
is_off:
    ldx #$02
    ldy #$07
    jmp plot_sprite

map_screen:
    lda $cc                          ; objects_carried + &c (OBJECT_MICROFILM)
    beq not_available
    lda level
    beq not_available                ; No map for Surface Defence sector one
    cmp #$0b
    bne display_map                  ; No map for Missile Factory sector three
not_available:
    jsr not_available_screen
    jmp wrist_terminal_screen
display_map:
    jsr clear_screen
    ldx #$08
    ldy #$14
    jsr tab_to_x_y
    jsr plot_level_name
    ldy #$00
write_map_text_loop:
    lda map_text,y
    jsr plot_character
    iny
    cpy #$40
    bne write_map_text_loop
    jsr plot_sector_number
    lda player_x
    and #$80
    sta map_data_address_low
    lda #$00
    sta map_tile_count
draw_map:
    lda screen_start_address_low
    sta map_screen_address_low
    clc
    lda screen_start_address_high
    adc #$0a
    bpl skip_wraparound_3476
    sec
    sbc #$20
skip_wraparound_3476:
    sta map_screen_address_high
draw_map_from_addresses:
    lda left_edge_tile_address_high
    sta map_data_address_high
draw_map_loop:
    ldx #$00
plot_enemies_on_map_loop:
    lda map_tile_count
    and #$07
    cmp enemies_y,x
    bne consider_next_enemy
    lda map_tile_count
    lsr a
    lsr a
    lsr a
    sta map_x_fraction
    lda map_data_address_low
    lsr a
    lsr a
    clc
    adc map_x_fraction
    cmp enemies_x,x
    bne consider_next_enemy
    lda #$88                         ; &0388 = map_sprite_enemy
    sta $72                          ; sprite_address_low
    lda #$03
    sta $73                          ; sprite_address_high
    jmp plot_map_tile_34db
consider_next_enemy:
    inx
    inx
    inx
    inx
    inx
    cpx last_enemy_offset
    bne plot_enemies_on_map_loop
    lda map_tile_count
    lsr a
    tay
    lda map_tile_count
    and #$01
    bne use_top_nibble_34bd
use_bottom_nibble_34b6:
    lda (map_data_address),y
    and #$0f
    jmp plot_map_tile_34c2
use_top_nibble_34bd:
    lda (map_data_address),y
    jsr get_top_nibble
plot_map_tile_34c2:
    clc
    adc level_sprite_base
    tay
    lda level_tiles_translation_table,y
    cmp #$34                         ; TILE_SPACESHIP_MIDDLE_RIGHT
    bcc not_spaceship
    lda #$00                         ; TILE_SPACE  # Don't plot spaceships on map
not_spaceship:
    clc
    asl a
    asl a
    asl a
    sta $72                          ; sprite_address_low
    lda #$00
    adc #$42                         ; &4200 = map_sprites
    sta $73                          ; sprite_address_high
plot_map_tile_34db:
    lda map_screen_address_low
    sta screen_address_low
    lda map_screen_address_high
    sta screen_address_high
    ldx #$01
    ldy #$08
    jsr plot_sprite                  ; Plot map tile
    inc map_screen_address_high
    bpl skip_wraparound_34f2
    lda #$60
    sta map_screen_address_high
skip_wraparound_34f2:
    lda level
    bne next_tile                    ; Is this the title screen?
    lda map_tile_count
    cmp #$e0                         ; If so, only plot DROID
    bne next_tile
    rts                              ; then leave
next_tile:
    inc map_tile_count
    beq map_screen_loop
    lda map_tile_count
    and #$07
    beq next_column_of_map
    jmp draw_map_loop
next_column_of_map:
    clc
    lda map_screen_address_low
    adc #$08                         ; Move right four pixels
    sta map_screen_address_low
    lda map_screen_address_high
    adc #$18                         ; Move to top of column
    bpl skip_wraparound_351a
    sec
    sbc #$20
skip_wraparound_351a:
    sta map_screen_address_high
    jmp draw_map_loop
map_screen_loop:
    lda level
    cmp #$07                         ; Crew's Quarters sector two only has right half
    beq not_scrolling_map_right
    lda os_most_recently_pressed_key
    cmp #$e1                         ; Z
    bne not_scrolling_map_left
    lda map_data_address_low
    beq map_screen_loop
    sec
    lda map_data_address_low
    sbc #$04
    sta map_data_address_low
    jmp draw_map
not_scrolling_map_left:
    cmp #$c2                         ; X
    bne not_scrolling_map_right
    lda map_data_address_low
    cmp #$80
    beq map_screen_loop
    clc
    lda map_data_address_low
    adc #$04
    sta map_data_address_low
    jmp draw_map
not_scrolling_map_right:
    lda os_most_recently_pressed_key
    cmp #$e2                         ; SPACE
    bne map_screen_loop
    jmp wrist_terminal_screen

long_delay:
    ldx #$fa
long_delay_loop:
    lda #$ff
    sta delay_length
    jsr delay
    dex
    bne long_delay_loop
    rts

very_long_delay:
    jsr long_delay
    jsr long_delay
    jmp long_delay

not_available_screen:
    jsr clear_screen
write_not_available_loop:
    lda not_available_text,y
    jsr plot_character
    iny
    cpy #$10
    bne write_not_available_loop
    jsr long_delay
    rts

update_tune:
    lda #$80                         ; Read buffer status
    ldx #$fb                         ; Sound output buffer 0
    ldy #$ff
    jsr OSBYTE                       ; Returns X = number of spaces remaining in buffer
    cpx #$00
    bne next_note
    jmp leave_3604
next_note:
    inc tune_address_low
    bne skip_page_3594
    inc tune_address_high
skip_page_3594:
    ldy #$00
    lda (tune_address),y             ; Get a byte of tune data for melody
    cmp #$ff
    bne not_silent                   ; &ff indicates silence, otherwise used to set pitch
    lda #$01
    ldx #$00
    ldy #$00
    jsr play_sound_on_channel_A_volume_X_pitch_Y ; Silence channel 1
    lda #$02
    ldx #$00
    ldy #$00
    jsr play_sound_on_channel_A_volume_X_pitch_Y ; Silence channel 2
    jmp update_percussion
not_silent:
    sec
    sbc #$22
    sta pitch
    lda #$01
    ldx #$01
    ldy pitch
    jsr play_sound_on_channel_A_volume_X_pitch_Y ; Play melody on channel 1
    lda #$02
    ldx #$01
    ldy pitch
    iny
    jsr play_sound_on_channel_A_volume_X_pitch_Y ; Play melody on channel 2
update_percussion:
    inc tune_address_low
    bne skip_page_35cf
    inc tune_address_high
skip_page_35cf:
    ldy #$00
    lda (tune_address),y             ; Get a byte of tune data for percussion
    sta pitch
    bne not_silent_percussion
    lda #$00
    ldx #$00
    ldy #$00
    jsr play_sound_on_channel_A_volume_X_pitch_Y ; Silence channel 0
    jmp check_for_end_of_tune
not_silent_percussion:
    lda #$00
    ldx #$04
    ldy pitch
    jsr play_sound_on_channel_A_volume_X_pitch_Y ; Play percussion on channel 0
check_for_end_of_tune:
    lda tune_finished
    bne is_game_over_tune
is_title_screen_tune:
    lda tune_address_high
    cmp #$05                         ; &051f = end_of_title_screen_tune_data
    bcc leave_3604
    lda tune_address_low
    cmp #$1f
    bne leave_3604
    lda #$5f                         ; &045f = title_screen_tune_repeat - 1
    sta tune_address_low
    lda #$04
    sta tune_address_high
leave_3604:
    rts
is_game_over_tune:
    lda tune_address_low
    cmp #$df                         ; &05df = end_of_game_over_tune_data
    bne leave_3604
start_game_over_tune:
    lda #$7f                         ; &057f = game_over_tune_data - 1
    sta tune_address_low
    lda #$05
    sta tune_address_high
    lda #$00
    sta tune_finished
    rts

play_sound_on_channel_A_volume_X_pitch_Y:
    sta sound_block_1                ; sound_block_1 + 0 (channel)
    stx $362c                        ; sound_block_1 + 2 (volume)
    sty $362e                        ; sound_block_1 + 4 (pitch)
    ldx #$2a                         ; &362a = sound_block_1
    ldy #$36
    lda #$07                         ; Generate a sound
    jmp OSWORD

;     chan  vol   pitch dur
sound_block_1:
    .byte $10,$00,$00,$00,$00,$00,$03,$00

replot_tile:                         ; # Called with X = tile_x, Y = tile_Y, A = tile
    stx $7a                          ; tile_x
    sty $7b                          ; tile_y
    sta tile_type
    clc
    adc level_sprite_base
    tay
    lda level_tiles_translation_table,y
    asl a
    tax
    lda tile_sprites_addresses_table,x
    and #$f8
    sta $72                          ; sprite_address_low
    lda tile_sprites_addresses_table,x
    and #$03
    sta tile_flip
    lda $0f81,x                      ; tile_sprites_addresses_table + 1
    sta $73                          ; sprite_address_high
    lda left_edge_tile_address_low
    lsr a
    lsr a
    sta edge_tile_x
    lda $7a                          ; tile_x
    cmp edge_tile_x
    bcs check_right_edge
    jmp set_tile
check_right_edge:
    clc
    lda edge_tile_x
    adc #$08
    cmp $7a                          ; tile_x
    bcc set_tile                     ; Branch if tile is beyond right of screen
    sec
    lda $7a                          ; tile_x
    sbc edge_tile_x
    tay                              ; Y is relative_tile_x
    lda left_edge_x_fraction
    sta $78                          ; tile_x_fraction
    lda edge_tile_x
    ldx #$04
    stx flipped_sprite_cropping_type_or_width ; Set to &04 to treat as uncropped tile if flipped
    cpy #$00
    bne skip_cropping_tile_to_left
    lda #$04
    sec
    sbc left_edge_x_fraction
    sta flipped_sprite_cropping_type_or_width ; or &00 - &03 to treat as cropped tile if flipped
    lda left_edge_x_fraction
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc $72                          ; sprite_address_low
    sta $72                          ; sprite_address_low
    ldy #$00
    sty $78                          ; tile_x_fraction
    lda screen_start_address_low
    sta screen_address_low
skip_cropping_tile_to_left:
    cpy #$08
    bne skip_cropping_tile_to_right
    lda left_edge_x_fraction
    beq set_tile                     ; Branch if tiles are aligned, and so nothing to plot
    clc
    adc #$10                         ; Treat as uncropped (to right) tile if flipped
    sta flipped_sprite_cropping_type_or_width
skip_cropping_tile_to_right:
    tya
    asl a
    asl a
    sec
    sbc $78                          ; tile_x_fraction
    asl a
    asl a
    asl a
    sta screen_address_low
    lda $7b                          ; tile_y
    asl a
    asl a
    sta screen_address_high
    clc
    lda screen_start_address_low
    adc screen_address_low
    sta screen_address_low
    lda screen_start_address_high
    adc screen_address_high
    bpl skip_wraparound_36c9
    sec
    sbc #$20
skip_wraparound_36c9:
    sta screen_address_high
    lda flipped_sprite_cropping_type_or_width
    and #$07
    tax
    ldy #$20
    lda tile_flip
    beq plot_and_set_tile
    cmp #$01                         ; FLIP_VERTICALLY
    beq is_flipped_vertically
    jsr plot_horizontally_flipped_tile
    jmp set_tile
is_flipped_vertically:
    dey
    jsr plot_vertically_flipped_sprite
    jmp set_tile
plot_and_set_tile:
    jsr plot_sprite
set_tile:
    lda left_edge_tile_address_high
    sta screen_address_high
    lda $7a                          ; tile_x
    asl a
    asl a
    sta $70                          ; tile_address_low
    lda $7b                          ; tile_y
    lsr a
    clc
    adc $70                          ; tile_address_low
    sta $70                          ; tile_address_low
    lda $7b                          ; tile_y
    and #$01
    bne set_top_nibble_of_tile_data
set_bottom_nibble_of_tile_data:
    ldy #$00
    lda ($70),y                      ; tile_address
    and #$f0
    clc
    adc tile_type
    sta ($70),y                      ; tile_address
    rts
set_top_nibble_of_tile_data:
    lda tile_type
    asl a
    asl a
    asl a
    asl a
    sta tile_type
    ldy #$00
    lda ($70),y                      ; tile_address
    and #$0f
    clc
    adc tile_type
    sta ($70),y                      ; tile_address
    rts

plot_character:
    stx $79                          ; tmp_x
    sty $7a                          ; tmp_y
    tax
    cmp #$1f
    bne not_tab
    lda #$02
    sta coordinates_remaining
    jmp leave_3783
not_tab:
    lda coordinates_remaining
    cmp #$02
    bne not_x_coordinate
    stx text_x
    dec coordinates_remaining
    jmp leave_3783
not_x_coordinate:
    cmp #$01
    bne not_y_coordinate
    dec coordinates_remaining
    stx text_y
    jmp leave_3783
not_y_coordinate:
    stx character
    ldx text_x
    lda text_y
    asl a
    asl a
    asl a
    tay
    jsr calculate_screen_address
    ldx character
    txa
    cmp #$20                         ; " "
    bne not_space
    lda #$01
    sta $72                          ; sprite_address_low
    sta $73                          ; sprite_address_high
    jmp plot_character_using_addresses
not_space:
    txa
    sec
    sbc #$30                         ; "0"
    tax
    clc
    lda #$00
    adc font_offsets,x
    sta $72                          ; sprite_address_low
    lda #$5b                         ; &5b00 = font_data
    adc #$00
    sta $73                          ; sprite_address_high
plot_character_using_addresses:
    inc text_x
    ldx #$01
    ldy #$05
    jsr plot_sprite
leave_3783:
    ldx $79                          ; tmp_x
    ldy $7a                          ; tmp_y
    rts

calculate_screen_address:            ; # Called with X = x, Y = y
    tya
    lsr a
    lsr a
    lsr a
    clc
    adc screen_start_address_high
    sta screen_address_high
    txa
    asl a
    asl a
    asl a
    clc
    adc screen_start_address_low
    sta screen_address_low
    lda screen_address_high
    adc #$00
    bpl skip_wraparound_37a3
    sec
    sbc #$20                         ; screen_address_high
skip_wraparound_37a3:
    sta screen_address_high
    tya
    and #$07
    clc
    adc screen_address_low
    sta screen_address_low
    rts

plot_score:
    ldx #$00
    stx suppress_leading_zeros
plot_score_loop:
    lda score,x
    bne plot_digit
    cpx #$07
    beq plot_digit
    ldy suppress_leading_zeros
    bne L_37c6                       ; consider_next_digit
    jmp consider_next_digit
plot_digit:
    ldy #$01
    sty suppress_leading_zeros
L_37c6:
    clc
    adc #$30                         ; "0"
    jsr plot_character
consider_next_digit:
    inx
    cpx #$08
    bne plot_score_loop
    rts

plot_level_name:
    lda #$00                         ; &5000 = level_names
    sta name_address_low
    lda #$50
    sta name_address_high
    ldy level
    lda level_offsets_table,y
    lsr a
    lsr a
    lsr a
    lsr a
    tax
    inx
plot_name:
    ldy #$00
find_start_of_name:
    lda (name_address),y
    iny
    cmp #$21                         ; "!"
    bne find_start_of_name
    dex
    bne find_start_of_name           ; find_start_of_level_name
plot_name_loop:
    lda (name_address),y
    cmp #$21                         ; "!"
    beq leave_37fe
    jsr plot_character
    iny
    jmp plot_name_loop
leave_37fe:
    rts

tab_to_x_y:
    lda #$1f
    jsr plot_character
    txa
    jsr plot_character
    tya
    jmp plot_character

plot_space:
    lda #$20                         ; " "
    jmp plot_character

plot_zero:                           ; # Unused code
    lda #$30                         ; "0"
    jmp plot_character

plot_sector_number:
    lda level
get_sector_loop:
    cmp #$03
    bcc got_sector
    sec
    sbc #$03
    jmp get_sector_loop
got_sector:
    clc
    adc #$31                         ; "1"
    jmp plot_character

flush_buffers:
    lda #$0f                         ; Flush buffers
    ldx #$00                         ; flush all buffers
    jmp OSBYTE

play_chime:
    ldy #$d2
play_chime_of_pitch_Y:
    ldx #$04
    lda #$04
    jmp play_sound_volume_X_pitch_Y_duration_A_on_channel_two

reset_tiles:
    lda #$37                         ; TILE_SPACESHIP_END_LEFT
    sta $052d                        ; level_tiles_translation_table + &00 + &d  # Use spaceship for Surface Defence sector one
    lda #$34                         ; TILE_SPACESHIP_MIDDLE_RIGHT
    ldx #$35                         ; TILE_SPACESHIP_MIDDLE_LEFT
    ldy #$36                         ; TILE_SPACESHIP_END_RIGHT
    jsr set_surface_defence_tiles
    lda #$30                         ; TILE_MISSILE_TAIL_LEFT
    sta $0555                        ; level_tiles_translation_table + &30 + &5  # Use missile for Missile Factor sector one
    lda #$2e                         ; TILE_MISSILE_NOSE_LEFT
    sta $0557                        ; level_tiles_translation_table + &30 + &7
    rts

prepare_status_screen:
    jsr set_colour_zero_to_black
    jsr flush_buffers
    jmp display_status_screen_level

jet_pack_screen:
    lda $c2                          ; objects_carried + &2 (OBJECT_JET_PACK)  # Non-zero if player is in jet pack
    bne is_available
    jsr not_available_screen
    jmp to_to_display_level
is_available:
    jsr prepare_status_screen
    ldy #$00
write_jet_pack_text_loop:
    lda jet_pack_text,y
    jsr plot_character
    iny
    cpy #$3c
    bne write_jet_pack_text_loop
    ldx #$06
    ldy #$7a
    lda jet_pack_energy
    jsr get_top_nibble
    jsr plot_energy_bar              ; Plot jet pack energy
    lda #$1e
    ldx #$06
    ldy #$aa
    jsr plot_energy_bar              ; Plot full blaster energy
    ldx #$08
    ldy #$3f
    jsr use_player_in_jet_pack
    jsr to_plot_flipped_player       ; Plot play in jet pack on left
    ldx #$15
    ldy #$3f
    jsr use_player_in_jet_pack
    jsr plot_unflipped_player        ; Plot play in jet pack on right
jet_pack_screen_loop:
    lda os_most_recently_pressed_key
    cmp #$e2                         ; SPACE
    bne jet_pack_screen_loop
to_to_display_level:
    jmp to_display_level_300c

use_player_in_jet_pack:
    jsr calculate_screen_address
    lda #$20                         ; &4920 = player_sprite_in_jet_pack
    sta $72                          ; sprite_address_low
    lda #$49
    sta $73                          ; sprite_address_high
    ldx #$03
    ldy #$20
    rts

calculate_player_screen_address_offset:
    sec
    lda screen_start_address_low     ; screen_start_address is between &6000 and &6700
    sbc player_screen_address_low    ; player_screen_address is always greater
    sta minus_offset_low
    lda screen_start_address_high
    sbc player_screen_address_high
    sta minus_offset_high
    cmp #$20
    bcc leave_38d2                   ; Never branches
    tay
    sec
    lda #$ff
    sbc minus_offset_high
    tax
    tya
    clc
    adc #$20
leave_38d2:
    rts                              ; Leave with X = offset_high, Y = &20 - offset_high

clear_screen:
    lda #$60
    sta screen_address_high
    lda #$00
    sta screen_address_low
    tay
clear_screen_loop:
    sta (screen_address),y           ; Wipe &6000 - &7fff
    iny
    bne clear_screen_loop
    inc screen_address_high
    bpl clear_screen_loop
    rts

consider_using_keys:
    lda $c4                          ; objects_carried + &4 (OBJECT_KEY)
    beq leave_3932
    lda player_stance
    cmp #$03                         ; STANCE_CLIMBING
    beq leave_3932
    lda player_jumping_or_falling
    bne leave_3932
    lda level
    cmp #$04                         ; Is this Ancient Shrine sector two?
    bne not_ancient_shrine_key
    lda player_x
    cmp #$29
    bne not_ancient_shrine_key
    ldx #$0b                         ; Lift pillar in Ancient Shrine sector two
    ldy #$03
    lda #$00                         ; NIBBLE_SPACE
    sta $c4                          ; objects_carried + &4 (OBJECT_KEY)
    jsr replot_tile
    ldx #$0b
    ldy #$02
    lda #$04                         ; NIBBLE_SHRINE_PILLAR_BOTTOM
    jmp replot_tile
not_ancient_shrine_key:
    cmp #$07                         ; Is this Crew's Quarters sector two?
    bne leave_3932
    lda player_x
    cmp #$d1
    bne leave_3932
    ldx #$35                         ; Remove walls in Crew's Quarters sector two
    ldy #$04
    lda #$00                         ; NIBBLE_SPACE
    sta $c4                          ; objects_carried + &4 (OBJECT_KEY)
    jsr replot_tile
    ldx #$39
    ldy #$04
    lda #$00                         ; NIBBLE_SPACE
    jmp replot_tile
leave_3932:
    rts

plot_unflipped_player:
    stx width
    sty height
    lda screen_address_low
    sta column_screen_address_low
    lda screen_address_high
    sta column_screen_address_high
    lda $72                          ; sprite_address_low
plot_unflipped_player_using_addresses: ; # Unused entry point
    sta unflipped_player_sprite_address_low
    lda $73                          ; sprite_address_high
    sta unflipped_player_sprite_address_high
    ldy #$00
plot_unflipped_player_row_loop:
    ldx #$00
plot_unflipped_player_column_loop:
    lda $3000,x
;     actually LDA unflipped_player_sprite_address,X
    sta (screen_address),y
    clc
    lda screen_address_low
    adc #$08
    sta screen_address_low
    bcc skip_page_3963
    inc screen_address_high
    bpl skip_wraparound_3963
    lda #$60
    sta screen_address_high
skip_wraparound_3963:
skip_page_3963:
    inx
    cpx width
    bne plot_unflipped_player_column_loop
    dec height
    beq leave_39a8
    clc
    lda $72                          ; sprite_address_low
    adc width
    sta $72                          ; sprite_address_low
    sta unflipped_player_sprite_address_low
    bcc skip_page_397b
    inc unflipped_player_sprite_address_high
skip_page_397b:
    lda column_screen_address_low
    and #$07
    cmp #$07
    bne not_next_group_399b
    sec
    lda column_screen_address_low
    sbc #$07
    sta column_screen_address_low
    sta screen_address_low
    inc column_screen_address_high
    bpl skip_wraparound_3994
    lda #$60
    sta column_screen_address_high
skip_wraparound_3994:
    lda column_screen_address_high
    sta screen_address_high
    jmp plot_unflipped_player_row_loop
not_next_group_399b:
    inc column_screen_address_low
    lda column_screen_address_low
    sta screen_address_low
    lda column_screen_address_high
    sta screen_address_high
    jmp plot_unflipped_player_row_loop
leave_39a8:
    rts

plot_flipped_player:
    stx width
    sty height
    lda screen_address_low
    sta column_screen_address_low
    lda screen_address_high
    sta column_screen_address_high
    lda $72                          ; sprite_address_low
    sta flipped_player_sprite_address_low
    lda $73                          ; sprite_address_high
    sta flipped_player_sprite_address_high
plot_flipped_player_row_loop:
    ldx width
plot_flipped_player_column_loop:
    dex
    lda $3000,x
;     actually LDA flipped_player_sprite_address,X
    tay
    lda flip_table,y
    ldy #$00
    sta (screen_address),y
    clc
    lda screen_address_low
    adc #$08
    sta screen_address_low
    bcc skip_page_39de
    inc screen_address_high
    bpl skip_wraparound_39de
    lda #$60
    sta screen_address_high
skip_wraparound_39de:
skip_page_39de:
    cpx #$00
    bne plot_flipped_player_column_loop
    dec height
    beq leave_3a22
    clc
    lda $72                          ; sprite_address_low
    adc width
    sta $72                          ; sprite_address_low
    sta flipped_player_sprite_address_low
    bcc skip_page_39f5
    inc flipped_player_sprite_address_high
skip_page_39f5:
    lda column_screen_address_low
    and #$07
    cmp #$07
    bne not_next_group_3a15
    sec
    lda column_screen_address_low
    sbc #$07
    sta column_screen_address_low
    sta screen_address_low
    inc column_screen_address_high
    bpl skip_wraparound_3a0e
    lda #$60
    sta column_screen_address_high
skip_wraparound_3a0e:
    lda column_screen_address_high
    sta screen_address_high
    jmp plot_flipped_player_row_loop
not_next_group_3a15:
    inc column_screen_address_low
    lda column_screen_address_low
    sta screen_address_low
    lda column_screen_address_high
    sta screen_address_high
    jmp plot_flipped_player_row_loop
leave_3a22:
    rts

plot_horizontally_flipped_tile:
    lda #$00
    sta size_for_offset_table
plot_flipped_enemy:
    stx width
    sty height
    txa
    asl a
    clc
    adc size_for_offset_table
    tax
    lda flipped_sprite_cropping_type_or_width
    cmp #$04
    bcc is_tile_cropped_to_right
    cmp #$fa                         ; UNCROPPED_ENEMY
    bcc is_uncropped_enemy           ; is_uncropped_tile
    cmp #$fb                         ; CROPPED_ENEMY
    bne is_uncropped_enemy_or_tile_cropped_to_left
is_enemy_cropped_to_right:
    lda #$06
    clc
    adc size_for_offset_table
    tax
is_uncropped_enemy_or_tile_cropped_to_left:
    lda $3aea,x                      ; cropped_flipped_enemy_offsets + 1
    sta $55                          ; offset_high
    lda cropped_flipped_enemy_offsets,x
    jmp set_offset_low
is_uncropped_enemy:
    ldx #$08
is_tile_cropped_to_right:
    lda $3ae0,x                      ; cropped_flipped_tile_offsets + 1
    sta $55                          ; offset_high
    lda cropped_flipped_tile_offsets,x
set_offset_low:
    sta offset_low
    ldy #$00
    lda screen_address_low
    sta column_screen_address_low
    lda screen_address_high
    sta column_screen_address_high
    clc
    lda $72                          ; sprite_address_low
    adc offset_low
    sta $3a78                        ; enemy_sprite_address_low
    lda $73                          ; sprite_address_high
    adc $55                          ; offset_high
    sta $3a79                        ; enemy_sprite_address_high
plot_flipped_enemy_column_loop:
    ldx #$00
plot_flipped_enemy_row_loop:
    lda $3000,x
;     actually LDA enemy_sprite_address
    tay
    lda flip_table,y
    ldy #$00
    sta (screen_address),y
    inx
    cpx height
    beq next_column_3aaf
    inc screen_address_low
    bne skip_page_3a93
    inc screen_address_high
    bpl skip_wraparound_3a93
    lda #$60
    sta screen_address_high
skip_wraparound_3a93:
skip_page_3a93:
    lda screen_address_low
    and #$07
    bne plot_flipped_enemy_row_loop
    sec
    lda screen_address_low
    sbc #$08
    sta screen_address_low
    bcs skip_page_3aa4
    dec screen_address_high
skip_page_3aa4:
    inc screen_address_high
    bpl plot_flipped_enemy_row_loop
    lda #$60
    sta screen_address_high
    jmp plot_flipped_enemy_row_loop
next_column_3aaf:
    sec
    lda $3a78                        ; enemy_sprite_address_low
    sbc height                       ; Move back a column of sprite data
    sta $3a78                        ; enemy_sprite_address_low
    lda $3a79                        ; enemy_sprite_address_high
    sbc #$00
    sta $3a79                        ; enemy_sprite_address_high
    clc
    lda column_screen_address_low
    adc #$08
    sta column_screen_address_low
    sta screen_address_low
    bcc skip_page_3ad3
    inc column_screen_address_high
    bpl skip_wraparound_3ad3
    lda #$60
    sta column_screen_address_high
skip_wraparound_3ad3:
skip_page_3ad3:
    lda column_screen_address_high
    sta screen_address_high
    dec width
    bne to_plot_flipped_enemy_column_loop
    rts
to_plot_flipped_enemy_column_loop:
    jmp plot_flipped_enemy_column_loop

cropped_flipped_tile_offsets:
    .byte $00,$00                    ; ; &00 : 0 columns to plot
    .byte $a0,$ff                    ; ; &02 : 1 column to plot
    .byte $e0,$ff                    ; ; &04 : 2 columns to plot
    .byte $20,$00                    ; ; &06 : 3 columns to plot
    .byte $60,$00                    ; ; &08 : 4 columns to plot

cropped_flipped_enemy_offsets:
    .byte $00,$00                    ; ; &00 : 0 columns to plot, 4 groups
    .byte $c0,$ff                    ; ; &02 : 1 column to plot
    .byte $00,$00                    ; ; &04 : 2 columns to plot
    .byte $40,$00                    ; ; &06 : 3 columns to plot

    .byte $00,$00                    ; ; &08 : 0 columns to plot, 3 groups
    .byte $d0,$ff                    ; ; &0a : 1 column to plot
    .byte $00,$00                    ; ; &0c : 2 columns to plot
    .byte $30,$00                    ; ; &0e : 3 columns to plot

    .byte $00,$00                    ; ; &10 : 0 columns to plot, 2 groups
    .byte $e0,$ff                    ; ; &12 : 1 column to plot
    .byte $00,$00                    ; ; &14 : 2 columns to plot
    .byte $20,$00                    ; ; &16 : 3 columns to plot

    .byte $00,$00                    ; ; &18 : 0 columns to plot, 1 group
    .byte $f0,$ff                    ; ; &1a : 1 column to plot
    .byte $00,$00                    ; ; &1c : 2 columns to plot
    .byte $10,$00                    ; ; &1e : 3 columns to plot

update_gargoyles:
    jsr update_pillars
    ldx #$00
update_gargoyles_loop:
    stx gargoyle_to_update
    lda gargoyle_locations,x         ; gargoyle_locations (level)
    cmp level
    bne consider_next_gargoyle
    ldy #$05                         ; NIBBLE_SHRINE_GARGOYLE_LEFT
    lda $0345,x                      ; gargoyle_locations + 1 (player x)
    cmp player_x
    bcs set_gargoyle_nibble
    iny                              ; &06 ; NIBBLE_SHRINE_GARGOYLE_RIGHT
set_gargoyle_nibble:
    sty gargoyle_nibble
    lda $0347,x                      ; gargoyle_locations + 3 (gargoyle y)
    tay
    lda $0346,x                      ; gargoyle_locations + 2 (gargoyle x)
    tax
    lda gargoyle_nibble
    jsr replot_tile
consider_next_gargoyle:
    ldx gargoyle_to_update
    inx
    inx
    inx
    inx
    cpx #$1c
    bne update_gargoyles_loop
    rts

initialise_variables:
    ldx #$00
    txa
wipe_0000_to_009f_loop:
    sta $00,x                        ; Wipe &0000 - &009f
    inx
    cpx #$a0
    bne wipe_0000_to_009f_loop
    lda #$0c
    sta crtc_address_high
    lda #$60
    sta screen_start_address_high
    lda #$03
    sta right_edge_x_fraction
    sta tune_address_high
    ldx #$10
    lda #$00
initialise_objects_carried:
    sta $bf,x                        ; objects_carried - 1  # Wipe &00c0 - &00cf
    dex
    bne initialise_objects_carried
    ldy #$00
    sty $c0                          ; objects_carried + &0 (OBJECT_PASSCARD)  # Unnecessary code
initialise_objects_loop:
    lda objects_type_and_flags,x
    and #$f0                         ; Clear bottom nibble to indicate object not collected
    sta objects_type_and_flags,x
    inx
    cpx #$30
    bne initialise_objects_loop
    lda #$ff
    sta blasters_ttl                 ; Set to &ff to indicate no blaster in slot
    sta jet_pack_energy
    sta $3d                          ; blasters_ttl + 4  # Set to &ff to indicate no blaster in slot
    lda #$25
    sta suit_energy
    lda #$25
    sta blaster_energy
    lda #$03
    sta lives                        ; Player starts with three lives
    ldx #$00
    txa
initialise_score_loop:
    sta score,x                      ; Wipe &07f0 - &07f7
    inx
    cpx #$08
    bne initialise_score_loop
    lda #$57                         ; &5700 = level_0_data  # Set screen to start scrolling onto DROID
    sta left_edge_tile_address_high
    lda #$1c                         ; &571c = level_0_data + &1c
    sta right_edge_tile_address_low
    lda #$57
    sta right_edge_tile_address_high
    lda #$ff
    sta tune_address_low
    lda #$46
    sta delay_length_low
    lda #$08
    sta delay_length_high
    lda #$0d
    sta player_x
    rts

remove_lifts_from_level_data:
    lda #$4c                         ; &4c00 = level_data
    sta $71                          ; tile_address_high
    lda #$00
    sta $70                          ; tile_address_low
    tay
    tax
remove_lifts_from_level_data_loop:
    lda ($70),y                      ; tile_address
    cmp #$02                         ; NIBBLE_LIFT_BOTTOM
    bne L_3bc1                       ; remove_lifts_from_level_data_loop
    lda #$33                         ; NIBBLE_CHAIN | NIBBLE_CHAIN * &10
    sta ($70),y                      ; tile_address
    iny
    sta ($70),y                      ; tile_address
    dey
L_3bc1:
    iny
    bne remove_lifts_from_level_data_loop
    inc $71                          ; tile_address_high
    inx
    cpx #$0b                         ; Processes &4c00 - &56ff (not level 0)
    bne remove_lifts_from_level_data_loop
    rts

update_chandeliers:
    lda left_edge_tile_address_high
    sta $01                          ; tile_address_high
    lda #$00
    sta $00                          ; tile_address_low
    sta $02                          ; tile_x
    sta $03                          ; tile_y
update_chandeliers_loop:
    ldy #$00
    lda ($00),y                      ; tile_address
    and #$0f
    cmp #$08                         ; NIBBLE_SHRINE_CHANDELIER
    bne skip_bottom_nibble
    ldx $02                          ; tile_x
    ldy $03                          ; tile_y
    jsr replot_tile
skip_bottom_nibble:
    inc $03                          ; tile_y
    ldy #$00
    lda ($00),y                      ; tile_address
    and #$f0
    cmp #$80                         ; NIBBLE_SHRINE_CHANDELIER * &10
    bne skip_top_nibble
    lda #$08                         ; NIBBLE_SHRINE_CHANDELIER
    ldx $02                          ; tile_x
    ldy $03                          ; tile_y
    jsr replot_tile
skip_top_nibble:
    inc $03                          ; tile_y
    inc $00                          ; tile_address_low  # Bug: this should only increment every two tiles
    lda $03                          ; tile_y
    cmp #$08
    bne update_chandeliers_loop
    lda #$00
    sta $03                          ; tile_y
    inc $02                          ; tile_x
    lda $02                          ; tile_x
    cmp #$40
    bne update_chandeliers_loop
    rts

update_pillars:
    lda level
    cmp #$05
    beq is_ancient_shrine_sector_three
leave_3c1b:
    rts
is_ancient_shrine_sector_three:
    lda frame_counter
    and #$1e
    cmp #$0c
    bne skip_raising_pillars
raise_pillars:
    lda #$06
    sta pillar_y
    lda #$00                         ; NIBBLE_SPACE
    sta pillar_tile_pair
    jsr update_pillar_tiles
    lda #$05
    sta pillar_y
    lda #$04                         ; NIBBLE_SHRINE_PILLAR_BOTTOM
    sta pillar_tile_pair
    jmp update_pillar_tiles
skip_raising_pillars:
    cmp #$1c
    bne leave_3c1b
lower_pillars:
    lda #$0a
    sta enemy_energy_and_initial_flags ; Treat pillars as moving enemies for collisions
    jsr buffer_player_points_and_blasters
    lda #$05
    sta pillar_y
    lda #$0b                         ; NIBBLE_SHRINE_PILLAR_TOP
    sta pillar_tile_pair
    jsr update_pillar_tiles
    lda #$06
    sta pillar_y
    lda #$04                         ; NIBBLE_SHRINE_PILLAR_BOTTOM
    sta pillar_tile_pair
    jsr update_pillar_tiles
    lda suit_energy
    pha                              ; suit_energy
    lda #$00
    sta enemy_direction_and_state    ; Set to zero to treat pillar as enemy, not skeleton
    lda #$c8
    sta enemy_to_update              ; Set to negative to indicate collision with player
    jsr check_for_collision_with_player
    pla                              ; suit_energy
    cmp suit_energy
    beq leave_3c75                   ; Has the pillar hit the player? If so, kill the player
kill_player:
    lda #$f0                         ; STANCE_DEAD
    sta suit_energy
    sta player_stance
    rts
leave_3c75:
    rts

update_pillar_tiles:
    lda #$06
    sta pillar_to_update
update_pillar_tiles_loop:
    ldx pillar_to_update
    lda pillars_x,x
    tax
    ldy pillar_y
    lda pillar_tile_pair
    jsr replot_tile
    dec pillar_to_update
    bne update_pillar_tiles_loop
    rts

update_events:
    jsr consider_energy_warning_and_check_for_completion
    jsr consider_dropping_girder_in_surface_defence_sector_two
    jsr consider_using_disk_or_spanner
    lda $c8                          ; objects_carried + &8 (OBJECT_BUTTON)
    bne not_missile_factor_sector_one_button
    lda level
    cmp #$09
    bne not_missile_factor_sector_one_button
    lda player_x
    cmp #$78
    bne not_missile_factor_sector_one_button
    ldx #$1e
    ldy #$05
    jsr replot_chain_and_crane
    jmp kill_player
not_missile_factor_sector_one_button:
    lda level
    cmp #$0a
    bne not_missile_factor_sector_two_buttons
    lda player_x
    cmp #$51
    bne skip_dropping_crane
    jsr damage_player_if_not_crawling
    ldx #$14
    ldy #$04
    jmp replot_chain_and_crane
skip_dropping_crane:
    cmp #$59
    bne not_missile_factor_sector_two_buttons
    jsr damage_player_if_not_crawling
    ldx #$16
    ldy #$04
    jmp replot_chain_and_crane
not_missile_factor_sector_two_buttons:
    rts

update_blasters:
    ldx #$00
update_blasters_loop:
    lda blasters_ttl,x
    cmp #$ff
    bcc is_active
    jmp consider_next_blaster_3d55
is_active:
    cmp #$fe                         ; BLASTER_COLLIDING
    beq skip_unplotting_blaster
    lda (blasters_screen_address,x)
    cmp #$6f                         ; 1331
    bne skip_unplotting_blaster
    lda #$00
    sta (blasters_screen_address,x)  ; Unplot middle of blaster
    tay
    jsr plot_or_unplot_blaster       ; Unplot top and bottom of blaster
skip_unplotting_blaster:
    lda blasters_direction,x         ; Zero if firing right, non-zero if firing left
    bne move_blaster_left
move_blaster_right:
    clc
    lda blasters_screen_address_low,x
    adc #$08
    sta blasters_screen_address_low,x
    bcc reduce_blaster_ttl
    inc blasters_screen_address_high,x
    bpl reduce_blaster_ttl
    lda #$60
    sta blasters_screen_address_high,x
    jmp reduce_blaster_ttl
move_blaster_left:
    sec
    lda blasters_screen_address_low,x
    sbc #$08
    sta blasters_screen_address_low,x
    bcs reduce_blaster_ttl
    dec blasters_screen_address_high,x
    lda blasters_screen_address_high,x
    cmp #$60
    bcs reduce_blaster_ttl
    lda #$7f
    sta blasters_screen_address_high,x
reduce_blaster_ttl:
    lda blasters_ttl,x
    bmi consider_next_blaster_3d55
    dec blasters_ttl,x
    bne update_blaster
remove_blaster:
    lda #$ff
    sta blasters_ttl,x               ; Set to &ff to indicate no blaster in slot
    jmp consider_next_blaster_3d55
update_blaster:
    lda blasters_screen_address_low,x
    and #$f8
    cmp screen_start_address_low
    beq remove_blaster               ; Remove blaster at left and right edges of screen
    lda (blasters_screen_address,x)
    beq no_collision
    cmp #$6f                         ; 1331
    beq plot_blaster                 ; Blaster doesn't collide with other blaster
collision:
    lda #$fe                         ; BLASTER_COLLIDING
    sta blasters_ttl,x               ; Set to &fe to indicate blaster hit player or enemy
    jmp consider_next_blaster_3d55
no_collision:
    inc blasters_screen_address_low,x
    lda (blasters_screen_address,x)
    bne collision
    dec blasters_screen_address_low,x
plot_blaster:
    lda #$6f                         ; 1331
    sta (blasters_screen_address,x)  ; Plot middle of blaster
    lda #$06                         ; 0110
    jsr plot_or_unplot_blaster       ; Plot top and bottom of blaster
consider_next_blaster_3d55:
    inx
    inx
    inx
    inx
    cpx #$18
    beq leave_3d60
    jmp update_blasters_loop
leave_3d60:
    rts

plot_or_unplot_blaster:
    dec blasters_screen_address_low,x
    sta (blasters_screen_address,x)  ; Plot or unplot top of blaster
    inc blasters_screen_address_low,x
    inc blasters_screen_address_low,x
    sta (blasters_screen_address,x)  ; Plot or unplot bottom of blaster
    dec blasters_screen_address_low,x
    rts

fire_blaster:
    ldx #$00
    lda blasters_ttl
    cmp #$ff                         ; &ff if no blaster in slot
    beq found_free_slot
    ldx #$04
    lda $3d                          ; blasters_ttl + 4
    cmp #$ff                         ; &ff if no blaster in slot
    beq found_free_slot
    rts
found_free_slot:
    lda $c2                          ; objects_carried + &2 (OBJECT_JET_PACK)  # Non-zero if player is in jet pack
    bne skip_draining_energy
    lda blaster_energy
    bne has_energy
    rts
has_energy:
    dec blaster_energy
skip_draining_energy:
    lda player_stance
    cmp #$02                         ; STANCE_CRAWLING
    bne not_crawling_3d93
    jmp leave_3e28                   ; Can't fire if crawling
not_crawling_3d93:
    lda #$0e
    clc
    adc player_direction             ; Zero if facing right, non-zero if facing left
    sta blasters_ttl,x
    lda player_direction             ; Zero if facing right, non-zero if facing left
    bne fire_blaster_left
fire_blaster_right:
    lda #$00
    sta blasters_direction,x         ; Set to zero to indicate moving right
    lda #$1d
    sta blaster_screen_offset_low
    lda #$01
    sta blaster_screen_offset_high
    lda player_screen_address_low
    and #$07
    beq fire_blaster_when_aligned    ; is_aligned
    lda #$15
    sta blaster_screen_offset_low
    lda #$02
    sta blaster_screen_offset_high
    lda player_stance
    cmp #$01                         ; : STANCE_KNEELING
    bne add_player_blaster
    lda #$1a
    sta blaster_screen_offset_low
    jmp add_player_blaster
fire_blaster_when_aligned:
    lda player_stance
    cmp #$01                         ; STANCE_KNEELING
    bne add_player_blaster
is_kneeling:
    clc
    lda blaster_screen_offset_low
    adc #$05
    sta blaster_screen_offset_low
    bcc L_3dd6                       ; skip_page
    inc blaster_screen_offset_high
L_3dd6:
    clc
skip_page_3dd7:
    lda blaster_screen_offset_low
    adc #$f8
    sta blaster_screen_offset_low
    lda blaster_screen_offset_high
    adc #$00
    sta blaster_screen_offset_high
add_player_blaster:
    txa
    pha                              ; blaster_slot
    lda level_sprite_base
    cmp #$40
    beq skip_sound                   ; Don't play sound for firing on title screen
    ldx #$02
    ldy #$65
    lda #$01
    jsr play_sound_volume_X_pitch_Y_duration_A
skip_sound:
    pla                              ; blaster_slot
    tax
    clc
    lda player_screen_address_low
    adc blaster_screen_offset_low
    sta blasters_screen_address_low,x
    lda player_screen_address_high
    adc blaster_screen_offset_high
    bpl skip_wraparound_3e06
    sec
    sbc #$20
skip_wraparound_3e06:
    sta blasters_screen_address_high,x
    jmp update_blaster
fire_blaster_left:
    lda #$01
    sta blasters_direction,x         ; Set to non-zero to indicate moving left
    lda #$fd
    sta blaster_screen_offset_low
    lda #$00
    sta blaster_screen_offset_high
    lda player_screen_address_low
    and #$07
    beq fire_blaster_when_aligned
    lda #$f5
    sta blaster_screen_offset_low
    lda #$01
    sta blaster_screen_offset_high
    jmp fire_blaster_when_aligned
leave_3e28:
    rts

consider_saving_position:
    lda level
    cmp #$03
    bne not_ancient_shrine_sector_one
    lda #$01
    jmp set_deepest_level
not_ancient_shrine_sector_one:
    cmp #$06
    bne leave_3e73
    lda #$02
set_deepest_level:
    sta deepest_level
    ldx #$00
save_score_loop:
    lda score,x
    sta saved_score,x
    inx
    cpx #$08
    bne save_score_loop
    ldx #$00
save_objects_carried_loop:
    lda objects_carried,x
    sta saved_objects_carried,x
    inx
    cpx #$10
    bne save_objects_carried_loop
    lda suit_energy
    sta saved_suit_energy
    lda blaster_energy
    sta saved_blaster_energy
    lda jet_pack_energy
    sta saved_jet_pack_energy
    lda lives
    sta saved_lives
    lda maximum_jump_timer
    sta saved_maximum_jump_timer
    lda total_objects_collected
    sta saved_total_objects_collected
leave_3e73:
    rts

update_exploding_mines:
    ldx #$00
    stx mine_to_update
update_exploding_mines_loop:
    lda #$90                         ; &4c90 = sprite_exploding_mine_one
    sta $72                          ; sprite_address_low
    lda #$4c
    sta $73                          ; sprite_address_high
    lda mines_state,x                ; Positive non-zero if mine exploding
    beq consider_next_mine_3eb5
    bmi consider_next_mine_3eb5
    cmp #$01
    bne skip_unplotting
    lda #$00                         ; &0100 = sprite_space
    sta $72                          ; sprite_address_low
    lda #$01
    sta $73                          ; sprite_address_high
skip_unplotting:
    and #$07
    cmp #$03
    bne plot_exploding_mine
    lda #$78                         ; &4478 = sprite_exploding_mine_zero
    sta $72                          ; sprite_address_low
    lda #$44
    sta $73                          ; sprite_address_high
plot_exploding_mine:
    dec mines_state,x
    lda mines_x,x                    ; Actually screen_address_low for exploding mine
    sta screen_address_low
    lda mines_y,x                    ; Actually screen_address_high for exploding mine
    sta screen_address_high
    ldx #$01
    ldy #$08
    jsr plot_sprite
consider_next_mine_3eb5:
    inc mine_to_update
    ldx mine_to_update
    cpx #$06
    bne update_exploding_mines_loop
    rts

replot_chain_and_crane:
    stx $7a                          ; tile_x
    sty $7b                          ; tile_y
    lda #$03                         ; NIBBLE_CHAIN
    jsr replot_tile
    ldx $7a                          ; tile_x
    ldy $7b                          ; tile_y
    iny
    lda #$0e                         ; NIBBLE_FACTORY_CRANE
    jmp replot_tile

display_level:
    lda #$08                         ; R8: Interlace and delay register
    sta $fe00                        ; video register number
    lda #$30                         ; Disable video output
    sta $fe01                        ; video register value
    dec screen_start_address_high
    lda screen_start_address_high
    cmp #$60
    bcs skip_wraparound_3ee7
    lda #$7f
    sta screen_start_address_high
skip_wraparound_3ee7:
    ldy level
    lda level_offsets_table,y
    sta level_sprite_base
    sec
    lda left_edge_tile_address_low
    sbc #$20
    sta left_edge_tile_address_low
    bcs skip_page_left
    dec left_edge_tile_address_high
skip_page_left:
    sec
    lda crtc_address_low
    sbc #$20
    sta crtc_address_low
    lda crtc_address_high
    sbc #$00
    cmp #$0c
    bcs skip_crtc_wraparound
    lda #$0f
skip_crtc_wraparound:
    sta crtc_address_high
    sec
    lda right_edge_tile_address_low
    sbc #$20
    sta right_edge_tile_address_low
    lda right_edge_tile_address_high
    sbc #$00
    sta right_edge_tile_address_high
    lda #$20
    sta $6c                          ; count
display_level_loop:
    jsr scroll_screen_right
    dec $6c                          ; count
    bne display_level_loop
    lda #$08                         ; R8: Interlace and delay register
    sta $fe00                        ; video register number
    lda #$00                         ; Enable video output
    sta $fe01                        ; video register value
    rts

get_tile_at_x_y:                     ; # Called with X = tile x, Y = tile y
    txa
    asl a
    asl a
    sta $70                          ; tile_address_low
    sty $72                          ; tile_y
    tya
    lsr a
    clc
    adc $70                          ; tile_address_low
    sta $70                          ; tile_address_low
    lda left_edge_tile_address_high
    sta $71                          ; tile_address_high
    ldx #$0f
    lda $72                          ; tile_y
    and #$01
    beq set_tile_nibble_mask
    ldx #$f0
set_tile_nibble_mask:
    stx tile_nibble_mask
    ldy #$00
    lda ($70),y                      ; tile_address
    and tile_nibble_mask
    cmp #$00
    rts

move_enemy:
    lda enemy_direction_and_state
    cmp #$04                         ; STATE_SKELETON
    bcc not_skeleton_3f5d
leave_3f5c:
    rts
not_skeleton_3f5d:
    lda enemy_energy_and_initial_flags
    and #$f0
    cmp #$30                         ; (STATE_STATIONARY + 1) * &10  # Bug: should be CMP #&20
    bcs leave_3f5c                   ; Should never branch, as move_enemy not called for stationary enemies
    lda enemy_direction_and_state
    bne move_enemy_moving_left
move_enemy_moving_right:
    ldx enemy_tile_x
    inx
    inx
    ldy enemy_tile_y
    jsr get_tile_at_x_y              ; Get tile to right of enemy
    bne flip_enemy_direction         ; Enemy changes direction if obstacle to right
    ldx enemy_tile_x
    inx
    inx
    ldy enemy_tile_y
    iny
    jsr get_tile_at_x_y              ; Get tile to right of and below enemy
consider_flipping_enemy_direction:
    beq flip_enemy_direction         ; Enemy changes direction if no support below
    cmp #$04                         ; NIBBLE_SURFACE_WALL_TOP_LEFT
    beq flip_enemy_direction
    cmp #$06                         ; NIBBLE_SURFACE_WALL_TOP_RIGHT
    beq flip_enemy_direction
    cmp #$0d                         ; NIBBLE_SURFACE_PLATFORM_BOTTOM
    beq flip_enemy_direction
    cmp #$d0                         ; NIBBLE_SURFACE_PLATFORM_BOTTOM * &10
    beq flip_enemy_direction
    cmp #$40                         ; NIBBLE_SURFACE_WALL_TOP_LEFT * &10
    beq flip_enemy_direction
    cmp #$60                         ; NIBBLE_SURFACE_WALL_TOP_RIGHT * &10
    beq flip_enemy_direction
move_enemy_left_or_right:
    lda enemy_direction_and_state
    bne move_enemy_left
move_enemy_right:
    inc enemy_tile_x
    rts
move_enemy_left:
    dec enemy_tile_x
    rts

flip_enemy_direction:
    jsr move_enemy_left_or_right
    lda enemy_direction_and_state
    eor #$01                         ; STATE_DIRECTION
    sta enemy_direction_and_state
    rts

move_enemy_moving_left:
    ldx enemy_tile_x
    dex
    dex
    ldy enemy_tile_y
    jsr get_tile_at_x_y              ; Get tile to left of enemy
    bne flip_enemy_direction         ; Enemy changes direction if obstacle to left
    ldx enemy_tile_x
    dex
    dex
    ldy enemy_tile_y
    iny
    jsr get_tile_at_x_y              ; Get tile to left of and below enemy
    jmp consider_flipping_enemy_direction
leave_3fc4:
    rts

consider_energy_warning_and_check_for_completion:
    lda suit_energy
    cmp #$0b
    bcs skip_energy_warning_sound    ; Play warning sound if energy is 10 or less
    lda frame_counter
    and #$1f
    cmp #$03
    bcs skip_energy_warning_sound
    ldy #$19
    jsr play_chime_of_pitch_Y
skip_energy_warning_sound:
    lda $cb                          ; objects_carried + &b (OBJECT_NAVIGATION_ROM)
    beq leave_3fc4                   ; Is the player carrying the navigation ROM?
    lda $ca                          ; objects_carried + &a (OBJECT_PLUTONIUM)
    cmp #$04
    bne leave_3fc4                   ; and all four sets of plutonium (and no lives lost)?
    lda level
    cmp #$0b
    bne leave_3fc4                   ; Is this Missile Factory sector three?
    lda player_jumping_or_falling
    bne leave_3fc4
    lda player_x
    cmp #$4d
    bne leave_3fc4
    jsr reset_tiles
    lda #$7c                         ; &507c = completion_level_data + &1c
    sta right_edge_tile_address_low
    lda #$50
    sta right_edge_tile_address_high
    lda #$02                         ; Use Surface Defence tiles
    sta level
    lda #$03
    sta right_edge_x_fraction
    jsr display_level                ; Plot completion screen
    ldy #$00
write_droid_is_completed_loop:
    lda droid_is_completed_text,y
    jsr plot_character
    iny
    cpy #$17
    bne write_droid_is_completed_loop
    lda #$0b
    sta level
    jmp game_over_screen_after_delay

consider_dropping_girder_in_surface_defence_sector_two:
    jsr calculate_player_screen_address_offset ; Returns X = offset_high
    cpx #$0f
    bcs leave_4044
    lda level
    cmp #$01
    bne leave_4044
    lda player_x
    cmp #$51
    bne leave_4044
    jsr damage_player_if_not_crawling
    ldx #$14                         ; Drop girder in Surface Defence sector two
    ldy #$01
    lda #$03                         ; NIBBLE_CHAIN
    jsr replot_tile
    ldx #$14
    ldy #$02
    lda #$02                         ; NIBBLE_LIFT_BOTTOM
    jsr replot_tile
leave_4044:
    rts

consider_using_disk_or_spanner:
    lda level
    cmp #$0b                         ; Is this Missile Factory sector three?
    bne skip_using_disk
    lda $cf                          ; objects_carried + &f (OBJECT_DISK)
    beq skip_using_disk              ; If the player has the disk,
    lda player_x
    cmp #$19
    bne skip_using_disk
    jsr play_chime
    ldx #$06                         ; Lift crane in Missile Factory sector three
    ldy #$03
    lda #$00                         ; NIBBLE_SPACE
    sta $cf                          ; objects_carried + &f (OBJECT_DISK)
    jsr replot_tile
    ldx #$06
    ldy #$02
    lda #$0e                         ; NIBBLE_FACTORY_CRANE
    jmp replot_tile
skip_using_disk:
    lda $c9                          ; objects_carried + &9 (OBJECT_SPANNER)
    beq leave_40ae
    lda level
    cmp #$08                         ; Is this Crew's Quarters sector three?
    bne skip_lifting_lamp
    lda player_x
    cmp #$68
    bne skip_lifting_lamp
    jsr play_chime
    lda #$00
    sta $c9                          ; objects_carried + &9 (OBJECT_SPANNER)
    ldx #$19                         ; Lift lamp in Crew's Quarters sector three
    ldy #$06
    lda #$00                         ; NIBBLE_SPACE
    jsr replot_tile
    ldx #$18
    ldy #$05
    lda #$0b                         ; NIBBLE_QUARTERS_LAMP
    jmp replot_tile
skip_lifting_lamp:
    lda player_stance
    cmp #$03                         ; STANCE_CLIMBING
    beq leave_40ae
    lda level
    cmp #$06                         ; Is this Crew's Quarter sector one?
    bne leave_40ae
    lda player_x
    cmp #$b8
    bne leave_40ae
    lda #$02
    sta $c9                          ; objects_carried + &9 (OBJECT_SPANNER)
    jsr play_chime
leave_40ae:
    rts

damage_player_if_not_crawling:
    lda player_stance
    bne leave_40ae
    lda player_screen_address_low
    sta screen_address_low
    lda player_screen_address_high
    sta screen_address_high
    lda #$02                         ; STANCE_CRAWLING
    sta player_stance
    ldx #$03
    ldy #$20
    jsr unplot_sprite                ; Unplot standing player
    jsr plot_player_crawling
    sec
    lda suit_energy
    sbc #$1e
    sta suit_energy
    lda #$08
    jmp play_sound_for_damage

unused_40d5:                         ; # Source code fragment
    .byte $50,$4c,$63,$68,$72,$34,$3a,$4c,$44,$41,$23,$26,$36,$30,$3a,$53 ; ; "PLchr4:LDA  # &60:STA&71:."
    .byte $54,$41,$26,$37,$31,$3a,$2e

initial_tiles:
    .byte $04,$51,$33                ; ; &5104 = &33 : level_6_data + &04 = NIBBLE_CHAIN | NIBBLE_CHAIN * &10
    .byte $f8,$54,$33                ; ; &54f8 = &33 : level_3_data + &f8 = NIBBLE_CHAIN | NIBBLE_CHAIN * &10
    .byte $50,$56,$23                ; ; &5650 = &23 : level_1_data + &50 = NIBBLE_CHAIN | NIBBLE_LIFT_BOTTOM * &10
    .byte $51,$56,$d0                ; ; &5651 = &d0 : level_1_data + &51 = NIBBLE_SPACE | NIBBLE_SURFACE_PLATFORM_BOTTOM * &10
    .byte $57,$55,$8d                ; ; &5557 = &8d : level_2_data + &57 = NIBBLE_SURFACE_PLATFORM_BOTTOM | NIBBLE_SURFACE_WALL_TOP * &10
    .byte $2d,$53,$4b                ; ; &532d = &4b : level_4_data + &2d = NIBBLE_SHRINE_PILLAR_TOP | NIBBLE_SHRINE_PILLAR_BOTTOM * &10
    .byte $7a,$52,$00                ; ; &527a = &00 : level_5_data + &7a = NIBBLE_SPACE | NIBBLE_SHRINE_WALL * &10
    .byte $af,$51,$af                ; ; &51af = &af : level_6_data + &af = NIBBLE_QUARTERS_PIPE_HORIZONTAL | NIBBLE_QUARTERS_WALL * &10
    .byte $ad,$51,$0a                ; ; &51ad = &0a : level_6_data + &ad = NIBBLE_QUARTERS_WALL | NIBBLE_SPACE * &10
    .byte $d6,$50,$9a                ; ; &50d6 = &9a : level_7_data + &d6 = NIBBLE_QUARTERS_WALL | NIBBLE_QUARTERS_WALL_INVERTED * &10
    .byte $e6,$50,$9a                ; ; &50e6 = &9a : level_7_data + &e6 = NIBBLE_QUARTERS_WALL | NIBBLE_QUARTERS_WALL_INVERTED * &10
    .byte $7a,$4e,$e3                ; ; &4e7a = &e3 : level_9_data + &7a = NIBBLE_CHAIN | NIBBLE_FACTORY_CRANE * &10
    .byte $7b,$4e,$90                ; ; &4e7b = &90 : level_9_data + &7b = NIBBLE_SPACE | NIBBLE_FACTORY_WALL * &10
    .byte $52,$4d,$0e                ; ; &4d52 = &0e : level_a_data + &52 = NIBBLE_FACTORY_CRANE | NIBBLE_SPACE * &10
    .byte $5a,$4d,$0e                ; ; &4d5a = &0e : level_a_data + &5a = NIBBLE_FACTORY_CRANE | NIBBLE_SPACE * &10
    .byte $05,$4e,$02                ; ; &4e05 = &02 : level_9_data + &05 = NIBBLE_LIFT_BOTTOM | NIBBLE_SPACE * &10
    .byte $06,$4e,$31                ; ; &4e06 = &31 : level_9_data + &06 = NIBBLE_LIFT_TOP | NIBBLE_CHAIN * &10
    .byte $05,$52,$02                ; ; &5205 = &02 : level_5_data + &05 = NIBBLE_LIFT_BOTTOM | NIBBLE_SPACE * &10
    .byte $06,$52,$31                ; ; &5206 = &31 : level_5_data + &06 = NIBBLE_LIFT_TOP | NIBBLE_CHAIN * &10
    .byte $05,$56,$02                ; ; &5605 = &02 : level_1_data + &05 = NIBBLE_LIFT_BOTTOM | NIBBLE_SPACE * &10
    .byte $06,$56,$31                ; ; &5606 = &31 : level_1_data + &06 = NIBBLE_LIFT_TOP | NIBBLE_CHAIN * &10
    .byte $f9,$51,$02                ; ; &51f9 = &02 : level_6_data + &f9 = NIBBLE_LIFT_BOTTOM | NIBBLE_SPACE * &10
    .byte $fa,$51,$31                ; ; &51fa = &31 : level_6_data + &fa = NIBBLE_LIFT_TOP | NIBBLE_CHAIN * &10
    .byte $f9,$57,$02                ; ; &57f9 = &02 : level_0_data + &f9 = NIBBLE_LIFT_BOTTOM | NIBBLE_SPACE * &10
    .byte $fa,$57,$31                ; ; &57fa = &31 : level_0_data + &fa = NIBBLE_LIFT_TOP | NIBBLE_CHAIN * &10
    .byte $f9,$55,$02                ; ; &55f9 = &02 : level_2_data + &f9 = NIBBLE_LIFT_BOTTOM | NIBBLE_SPACE * &10
    .byte $fa,$55,$31                ; ; &55fa = &31 : level_2_data + &fa = NIBBLE_LIFT_TOP | NIBBLE_CHAIN * &10
    .byte $19,$4c,$e3                ; ; &4c19 = &e3 : level_b_data + &19 = NIBBLE_CHAIN | NIBBLE_FACTORY_CRANE * &10

;      x fy
initial_enemy_positions:
    .byte $3b,$33                    ;   # Level &00
    .byte $12,$04                    ;   # Level &01
    .byte $1b,$04
    .byte $33,$23
    .byte $25,$06
    .byte $2d,$06
    .byte $0d,$06
    .byte $1c,$06
    .byte $04,$23
    .byte $04,$33                    ;   # Level &02
    .byte $1e,$06
    .byte $23,$01
    .byte $2f,$01
    .byte $32,$01
    .byte $3d,$33
    .byte $25,$01
    .byte $24,$36
    .byte $0e,$31
    .byte $32,$36                    ;   # Level &03
    .byte $2b,$26
    .byte $24,$01
    .byte $28,$36
    .byte $1d,$06
    .byte $1b,$06
    .byte $0b,$01
    .byte $0e,$04
    .byte $11,$06
    .byte $36,$26
    .byte $30,$06                    ;   # Level &04
    .byte $36,$06
    .byte $3b,$06
    .byte $32,$33
    .byte $0a,$33
    .byte $11,$14
    .byte $0e,$06
    .byte $17,$06
    .byte $21,$06
    .byte $1b,$11
    .byte $38,$06                    ;   # Level &05
    .byte $2c,$26
    .byte $2a,$26
    .byte $22,$12
    .byte $04,$26
    .byte $06,$26
    .byte $08,$13
    .byte $0e,$06
    .byte $1a,$06
    .byte $11,$34
    .byte $34,$25                    ;   # Level &06
    .byte $2e,$24
    .byte $20,$36
    .byte $20,$34
    .byte $14,$03
    .byte $0b,$06
    .byte $33,$11
    .byte $0a,$11
    .byte $10,$01
    .byte $29,$01
    .byte $36,$02                    ;   # Level &07
    .byte $25,$24
    .byte $27,$22
    .byte $36,$02                    ;   # Level &08
    .byte $28,$06
    .byte $2b,$06
    .byte $29,$32
    .byte $22,$11
    .byte $1c,$16
    .byte $08,$06
    .byte $0c,$06
    .byte $15,$06
    .byte $34,$02                    ;   # Level &09
    .byte $32,$06
    .byte $2e,$16
    .byte $29,$04
    .byte $1b,$06
    .byte $0b,$06
    .byte $0d,$06
    .byte $0f,$06
    .byte $0a,$11
    .byte $08,$34                    ;   # Level &0a
    .byte $08,$36
    .byte $1d,$06
    .byte $1b,$06
    .byte $2d,$33
    .byte $28,$34
    .byte $27,$16
    .byte $20,$31
    .byte $38,$02
    .byte $3b,$34
    .byte $0c,$35                    ;   # Level &0b
    .byte $0e,$06
    .byte $10,$06
    .byte $06,$36
    .byte $05,$33

unused_41fc:
    .byte $00,$00,$00,$00

map_sprites:
    .byte $00,$00,$00,$00,$00,$00,$00,$00 ; ; &00 : TILE_SPACE
    .byte $64,$64,$98,$98,$98,$98,$98,$00 ; ; &01 : TILE_CRANE
    .byte $ff,$0f,$ff,$64,$00,$64,$00,$64 ; ; &02 : TILE_LIFT_TOP
    .byte $64,$00,$64,$00,$64,$ff,$0f,$ff ; ; &03 : TILE_LIFT_BOTTOM
    .byte $64,$64,$74,$74,$30,$30,$00,$00 ; ; &04 : TILE_PIPE_BOTTOM_LEFT
    .byte $00,$00,$30,$30,$74,$74,$64,$64 ; ; &05 : TILE_PIPE_TOP_LEFT
    .byte $60,$60,$e0,$e0,$c0,$c0,$00,$00 ; ; &06 : TILE_PIPE_BOTTOM_RIGHT
    .byte $00,$00,$c0,$c0,$e0,$e0,$64,$64 ; ; &07 : TILE_PIPE_TOP_RIGHT
    .byte $64,$64,$64,$09,$0f,$06,$64,$64 ; ; &08 : TILE_PIPE_VERTICAL
    .byte $00,$04,$d2,$d2,$d2,$d2,$04,$00 ; ; &09 : TILE_PIPE_HORIZONTAL
    .byte $11,$11,$23,$47,$47,$47,$cf,$8f ; ; &0a : TILE_SURFACE_WALL_TOP_LEFT
    .byte $8f,$47,$47,$47,$23,$33,$11,$11 ; ; &0b : TILE_SURFACE_WALL_BOTTOM_LEFT
    .byte $88,$cc,$4c,$2e,$2e,$1f,$1f,$1f ; ; &0c : TILE_SURFACE_WALL_TOP_RIGHT
    .byte $1f,$2e,$2e,$2e,$4c,$4c,$4c,$88 ; ; &0d : TILE_SURFACE_WALL_BOTTOM_RIGHT
    .byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f ; ; &0e : TILE_SURFACE_WALL
    .byte $1f,$2e,$2e,$2e,$1f,$3f,$2e,$1f ; ; &0f : TILE_SURFACE_WALL_RIGHT
    .byte $8f,$47,$8f,$8f,$47,$47,$47,$8f ; ; &10 : TILE_SURFACE_WALL_LEFT
    .byte $99,$ef,$8f,$0f,$0f,$0f,$0f,$0f ; ; &11 : TILE_SURFACE_WALL_TOP
    .byte $0f,$0f,$0f,$0f,$0f,$2f,$5d,$99 ; ; &12 : TILE_SURFACE_WALL_BOTTOM
    .byte $ff,$80,$50,$20,$ff,$00,$00,$00 ; ; &13 : TILE_PLATFORM_TOP
    .byte $00,$00,$00,$ff,$80,$50,$20,$ff ; ; &14 : TILE_PLATFORM_BOTTOM
    .byte $64,$00,$64,$00,$64,$00,$64,$00 ; ; &15 : TILE_CHAIN
    .byte $02,$02,$02,$02,$02,$02,$02,$02 ; ; &16 : TILE_ROPE
    .byte $f0,$80,$b1,$b1,$b1,$b1,$b3,$f0 ; ; &17 : TILE_QUARTERS_WALL
    .byte $80,$80,$c0,$c0,$a0,$a0,$b3,$f0 ; ; &18 : TILE_QUARTERS_WALL_TOP_RIGHT
    .byte $f0,$90,$a0,$a0,$c0,$c0,$80,$80 ; ; &19 : TILE_QUARTERS_WALL_BOTTOM_RIGHT
    .byte $10,$11,$31,$31,$71,$71,$f7,$f0 ; ; &1a : TILE_QUARTERS_WALL_TOP_LEFT
    .byte $f0,$f0,$51,$71,$31,$31,$11,$10 ; ; &1b : TILE_QUARTERS_WALL_BOTTOM_LEFT
    .byte $00,$00,$0f,$7f,$11,$11,$32,$32 ; ; &1c : TILE_TABLE_LEFT
    .byte $00,$00,$0f,$ef,$80,$80,$c0,$c0 ; ; &1d : TILE_TABLE_RIGHT
    .byte $08,$08,$08,$08,$0e,$41,$41,$e0 ; ; &1e : TILE_CHAIR_RIGHT
    .byte $01,$01,$01,$01,$07,$28,$28,$70 ; ; &1f : TILE_CHAIR_LEFT
    .byte $60,$60,$60,$f0,$f0,$66,$00,$00 ; ; &20 : TILE_LAMP
    .byte $cf,$00,$8f,$cf,$8f,$cf,$00,$cf ; ; &21 : TILE_BARREL
    .byte $f0,$fe,$d8,$d8,$d8,$d8,$98,$f0 ; ; &22 : TILE_QUARTERS_WALL_INVERTED
    .byte $64,$9e,$9e,$f8,$98,$fc,$64,$fc ; ; &23 : TILE_COMPUTER
    .byte $76,$74,$74,$00,$d9,$d1,$d1,$00 ; ; &24 : TILE_SHRINE_WALL
    .byte $00,$60,$52,$f0,$d0,$c0,$80,$60 ; ; &25 : TILE_GARGOYLE_RIGHT
    .byte $00,$60,$a4,$f0,$b0,$30,$10,$60 ; ; &26 : TILE_GARGOYLE_LEFT
    .byte $64,$44,$64,$44,$64,$44,$64,$f8 ; ; &27 : TILE_PILLAR_BOTTOM
    .byte $f8,$44,$64,$44,$64,$44,$64,$44 ; ; &28 : TILE_PILLAR_TOP
    .byte $00,$f0,$90,$a0,$c0,$c0,$80,$80 ; ; &29 : TILE_SHRINE_WALL_TOP_LEFT
    .byte $00,$f0,$90,$50,$30,$30,$10,$10 ; ; &2a : TILE_SHRINE_WALL_TOP_RIGHT
    .byte $80,$80,$c0,$c0,$a0,$90,$f0,$00 ; ; &2b : TILE_SHRINE_WALL_BOTTOM_LEFT
    .byte $10,$10,$30,$30,$50,$90,$f0,$00 ; ; &2c : TILE_SHRINE_WALL_BOTTOM_RIGHT
    .byte $09,$08,$99,$99,$99,$99,$ff,$66 ; ; &2d : TILE_CHANDELIER
    .byte $00,$00,$77,$ff,$88,$77,$00,$00 ; ; &2e : TILE_MISSILE_NOSE_LEFT
    .byte $00,$00,$ee,$ff,$11,$ee,$00,$00 ; ; &2f : TILE_MISSILE_NOSE_RIGHT
    .byte $03,$06,$ee,$ff,$11,$ee,$06,$03 ; ; &30 : TILE_MISSILE_TAIL_LEFT
    .byte $0c,$06,$77,$ff,$88,$77,$06,$0c ; ; &31 : TILE_MISSILE_TAIL_RIGHT
    .byte $09,$09,$6f,$6f,$09,$6f,$09,$09 ; ; &32 : TILE_MISSILE_BODY
    .byte $ff,$99,$9b,$9b,$9b,$9b,$9b,$ff ; ; &33 : TILE_FACTORY_WALL

droid_is_completed_text:
    .byte $1f,$0c,$05                ; ; TAB(&0c, &05)
    .byte "DROID IS"                 ; ; "DROID IS"
    .byte $1f,$0c,$06                ; ; TAB(&0c, &06)
    .byte "COMPLETED"                ; ; "COMPLETED"

unused_43b7:
    .byte $11,$00,$00

object_sprite_spring:
    .byte $4f,$4e,$03,$00,$00,$4f,$4e,$03,$00,$00,$4f,$0f,$00,$08,$0e,$03
    .byte $0f,$00,$08,$0e,$03,$0f

object_sprite_crate:
    .byte $22,$1d,$1d,$11,$1d,$11,$3b,$22,$2a,$33,$1d,$11,$1d,$11,$1d,$22
    .byte $60,$49,$69,$20,$69,$00,$8e,$88,$8e,$88,$0f,$00,$0f,$00,$0f,$00
    .byte $88,$47,$47,$44,$47,$44,$ef,$aa,$ab,$ee,$47,$44,$47,$44,$47,$88

object_sprite_herbert_droid:
    .byte $03,$05,$27,$07,$06,$14,$20,$0d,$0d,$28,$38,$a8,$b8,$31,$71,$60
    .byte $0c,$0a,$4e,$0e,$06,$82,$40,$0b,$0b,$41,$c1,$51,$d1,$c8,$e8,$60

unused_4420:
    .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01

map_text:
    .byte $1f,$06,$05                ; ; TAB(&06, 05)
    .byte $4d,$49,$43,$52,$4f,$20,$46,$49,$4c,$4d,$20,$44,$49,$53,$50,$4c ; ; "MICRO FILM DISPLAY"
    .byte $41,$59
    .byte $1f,$01,$28                ; ; TAB(&01, 28)
    .byte $5a,$20,$58,$20,$54,$4f,$20,$53,$43,$52,$4f,$4c,$4c,$20,$4f,$52 ; ; "Z X TO SCROLL OR SPACE TO EXIT"
    .byte $20,$53,$50,$41,$43,$45,$20,$54,$4f,$20,$45,$58,$49,$54
    .byte $1f,$0b,$16                ; ; TAB(&0b, 16)
    .byte "SECTOR "                  ; ; "SECTOR "

unused_446d:
    .byte $00,$00,$00

ranking_requirements:
    .byte $04,$08,$0e,$13,$18,$1d,$23,$2e

sprite_exploding_mine_zero:
    .byte $00,$01,$0a,$02,$27,$6f,$6f,$06

tile_sprite_gargoyle:
    .byte $10,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$10,$20,$10
    .byte $20,$50,$30,$50,$b0,$70,$b0,$70,$b0,$50,$30,$50,$30,$00,$00,$00
    .byte $80,$e0,$70,$30,$30,$10,$10,$00,$00,$00,$00,$70,$b0,$70,$f0,$f0
    .byte $f0,$e0,$d0,$b0,$70,$70,$f0,$f0,$e0,$d0,$d0,$b0,$70,$e0,$f0,$f0
    .byte $80,$80,$c0,$f0,$10,$06,$93,$f0,$e0,$30,$dc,$22,$d1,$e0,$f0,$70
    .byte $60,$20,$d0,$e0,$f0,$f0,$70,$70,$e0,$d0,$d0,$b0,$30,$30,$30,$b0
    .byte $00,$00,$00,$00,$80,$c0,$40,$e0,$70,$10,$c0,$60,$00,$00,$00,$80
    .byte $80,$80,$80,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$80,$80

not_available_text:
    .byte $1f,$09,$0e                ; ; TAB(&09, &0e)
    .byte "NOT AVAILABLE"            ; ; "NOT AVAILABLE"

skeleton_sprite_two:
    .byte $33,$77,$77,$22,$77,$33,$44,$77,$44,$55,$88,$99,$33,$66,$cc,$77
    .byte $00,$88,$88,$88,$99,$66,$11,$ff,$aa,$ee,$aa,$cc,$44,$44,$44,$33
    .byte $00,$00,$00,$00,$88,$88,$00,$00,$00,$00,$00,$00,$00,$00,$00,$88

sprite_mine:
    .byte $00,$00,$00,$00,$60,$f4,$f4,$f4

game_over_text:
    .byte $1f,$0b,$09                ; ; TAB(&0b, &09)
    .byte "GAME  OVER"               ; ; "GAME  OVER"
    .byte $1f,$0a,$10                ; ; TAB(&0a, &10)
    .byte "SCORE"                    ; ; "SCORE"
    .byte $1f,$0a,$15                ; ; TAB(&0a, &15)
    .byte "PRESS  SPACE"             ; ; "PRESS  SPACE"
    .byte $1f,$0a,$12                ; ; TAB(&0a, &12)
    .byte "RATING"                   ; ; "RATING"
    .byte $1f,$0c,$0e                ; ; TAB(&0c, &0e)
    .byte "SECTOR"                   ; ; "SECTOR"

unused_457e:
    .byte $20,$20

tile_sprite_missile_tail:
    .byte $04,$04,$0c,$0c,$04,$05,$2c,$3c,$04,$37,$3f,$3f,$37,$37,$3f,$3f
    .byte $37,$37,$3f,$3f,$37,$04,$3f,$0c,$34,$24,$0d,$0d,$04,$04,$0c,$0c
    .byte $00,$01,$03,$07,$0f,$0f,$0f,$07,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $ff,$ff,$00,$ff,$ff,$00,$ff,$00,$00,$00,$0f,$0f,$0f,$07,$03,$01
    .byte $00,$0f,$8f,$8e,$8e,$8e,$8e,$0e,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $ff,$ff,$11,$ff,$ff,$11,$ff,$00,$00,$00,$0e,$0e,$0e,$0e,$0f,$0f
    .byte $00,$08,$00,$00,$00,$00,$00,$00,$00,$33,$77,$dd,$33,$ff,$11,$11
    .byte $ff,$11,$11,$ff,$33,$dd,$77,$33,$00,$00,$00,$00,$00,$00,$00,$08

tile_sprite_chandelier:
    .byte $00,$00,$00,$02,$00,$04,$04,$0c,$0a,$4e,$4e,$44,$00,$04,$04,$66
    .byte $66,$66,$66,$66,$66,$66,$66,$66,$66,$66,$66,$66,$66,$33,$33,$11
    .byte $30,$20,$40,$40,$41,$21,$30,$10,$01,$01,$01,$09,$01,$09,$2a,$bb
    .byte $11,$99,$99,$99,$99,$99,$99,$99,$99,$99,$bb,$77,$33,$66,$ee,$cc
    .byte $c0,$40,$20,$20,$28,$48,$c0,$80,$08,$08,$08,$08,$09,$08,$45,$dd
    .byte $88,$99,$99,$99,$99,$99,$99,$99,$99,$99,$dd,$ee,$cc,$66,$77,$33
    .byte $00,$00,$00,$00,$01,$00,$01,$03,$06,$27,$27,$02,$00,$02,$02,$66
    .byte $66,$66,$66,$66,$66,$66,$66,$66,$66,$66,$66,$66,$66,$cc,$cc,$88

tile_sprite_surface_wall_vertical:
    .byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
    .byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
    .byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
    .byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
    .byte $0f,$0f,$0f,$1f,$0f,$4f,$0f,$1f,$0f,$0f,$0f,$2f,$0f,$0f,$0f,$8f
    .byte $1f,$0f,$0f,$0f,$1f,$0f,$2f,$0f,$1f,$5f,$1f,$3f,$1f,$2f,$0f,$0f
    .byte $ae,$6e,$ee,$4c,$cc,$4c,$6e,$2e,$4c,$cc,$6e,$bf,$5f,$1f,$ae,$4c
    .byte $4c,$88,$cc,$4c,$6e,$2e,$ee,$88,$00,$00,$00,$00,$cc,$6e,$ae,$7f

title_screen_text:
    .byte $1f,$0c,$07                ; ; TAB(&0c, &07)
    .byte "SUPERIOR"                 ; ; "SUPERIOR"
    .byte $1f,$0c,$09                ; ; TAB(&0c, &09)
    .byte "PRESENTS"                 ; ; "PRESENTS"
    .byte $1f,$0c,$0b                ; ; TAB(&0c, &0b)
    .byte "CODENAME"                 ; ; "CODENAME"
    .byte $1f,$0b,$17                ; ; TAB(&0b, &17)
    .byte "HIT SPACE"                ; ; "HIT SPACE"
    .byte $1f,$09,$11                ; ; TAB(&09, &11)
    .byte "STRYKERS RUN 2"           ; ; "STRYKERS RUN 2"

unused_473e:
    .byte $11

saved_total_objects_collected:
    .byte $11
saved_score:
    .byte $11,$11,$01,$00,$00,$10,$01,$00
saved_objects_carried:
    .byte $00,$10,$01,$00,$00,$10,$01,$00,$00,$10,$01,$00,$00,$10,$01,$00
saved_suit_energy:
    .byte $00
saved_blaster_energy:
    .byte $10
saved_jet_pack_energy:
    .byte $11
saved_lives:
    .byte $11
saved_maximum_jump_timer:
    .byte $11

unused_475d:
    .byte $11

sprite_box_middle:
    .byte $88,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $11

sprite_box_top_or_bottom:
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $ff

sprite_face:
    .byte $00,$11,$00,$11,$55,$88,$cc,$9b,$99,$bb,$bb,$bb,$bb,$bb,$06,$07
    .byte $07,$26,$27,$37,$27,$37,$33,$33,$33,$33,$33,$11,$11,$11,$11,$00
    .byte $26,$00,$00,$66,$08,$44,$00,$cc,$ff,$ff,$ef,$ef,$ff,$cf,$03,$0d
    .byte $03,$13,$3f,$3f,$7f,$ff,$ff,$df,$ef,$ff,$ff,$cf,$ff,$cf,$ff,$ef
    .byte $08,$01,$0a,$23,$02,$88,$00,$07,$0f,$0f,$0f,$0f,$0f,$0f,$08,$0b
    .byte $04,$00,$07,$07,$03,$8b,$8b,$07,$0f,$0f,$0f,$0f,$07,$0f,$0f,$0e
    .byte $00,$00,$00,$04,$00,$0a,$02,$06,$02,$0a,$0a,$0a,$0a,$0a,$08,$0c
    .byte $0c,$0c,$0c,$0c,$0c,$0c,$08,$08,$08,$08,$08,$00,$00,$00,$00,$00

tile_sprite_spaceship_middle:
    .byte $3c,$37,$34,$3c,$10,$60,$f0,$f0,$0f,$0f,$c3,$43,$c3,$21,$e1,$10
    .byte $f0,$c0,$b0,$b3,$b0,$80,$c0,$f0,$00,$70,$03,$70,$00,$11,$11,$33
    .byte $f0,$fb,$f0,$f0,$00,$f0,$80,$80,$91,$80,$c0,$48,$68,$3c,$0f,$0f
    .byte $07,$80,$f0,$ff,$f0,$00,$00,$f0,$00,$f0,$0f,$f0,$00,$33,$11,$ff
    .byte $00,$cc,$c0,$00,$00,$80,$60,$10,$cc,$77,$11,$00,$00,$80,$f0,$1e
    .byte $0b,$40,$f0,$ff,$f0,$00,$00,$f0,$00,$f0,$0f,$f0,$00,$00,$88,$ff
    .byte $00,$00,$00,$00,$00,$00,$00,$80,$60,$10,$cc,$00,$00,$00,$00,$f0
    .byte $3c,$0f,$00,$ee,$00,$00,$f0,$f0,$00,$f0,$0f,$f0,$00,$00,$88,$00

tile_sprite_spaceship_end:
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$80,$60,$10,$00,$00,$00,$00
    .byte $f0,$0f,$07,$b0,$70,$f0,$f0,$f0,$00,$c0,$91,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$80,$60,$10,$00,$00
    .byte $f0,$0f,$0f,$f0,$80,$80,$b0,$c0,$00,$00,$88,$cc,$66,$33,$11,$77
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$80,$60,$10
    .byte $f0,$0f,$0f,$f0,$10,$70,$80,$00,$00,$00,$00,$00,$00,$00,$99,$ee
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$80
    .byte $e0,$0f,$0e,$c0,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

object_sprite_key:
    .byte $00,$00,$00,$ff,$0f,$07,$05,$04,$00,$00,$11,$ef,$0f,$01,$00,$00
    .byte $66,$9f,$09,$09,$09,$09,$6f,$06

object_sprite_microfilm:
    .byte $73,$a0,$a0,$40,$ec,$50,$50,$20

player_sprite_in_jet_pack:
    .byte $00,$70,$00,$00,$b9,$80,$11,$dd,$80,$11,$dd,$80,$00,$dd,$c4,$00
    .byte $30,$a2,$00,$f0,$22,$00,$00,$22,$00,$70,$22,$00,$f0,$83,$00,$a0
    .byte $83,$33,$20,$03,$66,$28,$0f,$ff,$60,$07,$74,$e0,$0f,$54,$c0,$09
    .byte $66,$00,$67,$77,$ff,$cd,$00,$00,$67,$70,$c3,$09,$70,$87,$0f,$60
    .byte $07,$0f,$60,$0f,$0f,$60,$0e,$06,$06,$11,$80,$06,$32,$c0,$0e,$74
    .byte $e0,$00,$44,$20,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

tile_sprite_shrine_wall:
    .byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$e0,$d0,$a0,$00
    .byte $11,$33,$32,$75,$76,$75,$76,$74,$66,$64,$54,$30,$72,$30,$00,$00
    .byte $80,$c0,$c0,$c0,$a0,$c0,$80,$d0,$a0,$40,$a0,$50,$80,$40,$80,$00
    .byte $cc,$f5,$f8,$f0,$f8,$f0,$f0,$30,$f0,$f0,$70,$b0,$b0,$f0,$f0,$00
    .byte $33,$76,$44,$fa,$fd,$fa,$fd,$76,$74,$76,$74,$74,$f4,$70,$10,$00
    .byte $f8,$f0,$f0,$f0,$b0,$f0,$f0,$e0,$f0,$f0,$f0,$b0,$f0,$e0,$50,$00
    .byte $ff,$fa,$d4,$30,$70,$b0,$d0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$00
    .byte $80,$e0,$c0,$e0,$d0,$e0,$c0,$a0,$d0,$a0,$40,$a0,$50,$a0,$40,$00

tile_sprite_pillar:
    .byte $11,$11,$11,$11,$11,$00,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11
    .byte $11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$00,$30,$70,$70,$00
    .byte $f8,$f4,$f8,$f4,$70,$f4,$70,$b0,$d8,$d4,$f8,$f4,$f8,$f4,$f8,$f4
    .byte $f8,$f4,$f8,$f4,$e8,$d0,$f8,$e4,$f8,$f4,$f8,$00,$f0,$f0,$f0,$00
    .byte $e0,$d0,$e0,$f0,$e0,$d0,$e0,$f0,$e0,$d0,$e0,$f0,$e0,$d0,$e0,$f0
    .byte $e0,$d0,$e0,$90,$60,$50,$60,$f0,$e0,$d0,$e0,$00,$f0,$f0,$f0,$00
    .byte $80,$00,$80,$00,$80,$00,$80,$00,$80,$00,$80,$00,$80,$00,$80,$00
    .byte $80,$00,$80,$00,$80,$00,$80,$00,$80,$00,$80,$00,$c0,$e0,$e0,$00

tile_sprite_shrine_wall_corner:
    .byte $70,$40,$30,$70,$70,$00,$70,$40,$51,$51,$51,$51,$51,$51,$51,$51
    .byte $51,$51,$51,$51,$51,$51,$51,$51,$40,$40,$40,$40,$50,$50,$50,$70
    .byte $f0,$90,$70,$b0,$e0,$00,$f0,$00,$ff,$22,$66,$66,$66,$66,$77,$bb
    .byte $bb,$77,$66,$cc,$98,$a8,$20,$40,$40,$80,$80,$80,$00,$00,$00,$00
    .byte $f0,$f0,$f0,$d0,$a0,$00,$b0,$43,$52,$a5,$a5,$a5,$a5,$a5,$52,$43
    .byte $b8,$10,$60,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $e0,$d0,$a0,$50,$a0,$00,$80,$48,$48,$a4,$a4,$a4,$a4,$a4,$48,$48
    .byte $80,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

tile_sprite_missile_nose:
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$11,$33,$77,$77
    .byte $cc,$77,$55,$22,$11,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$77,$ff,$ff,$ff,$ff
    .byte $ff,$11,$ee,$77,$88,$77,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $ff,$ff,$00,$ff,$ff,$00,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $02,$02,$03,$03,$02,$02,$43,$c3,$02,$ce,$cf,$cf,$ce,$ce,$cf,$cf
    .byte $ce,$ce,$03,$cf,$ce,$02,$cf,$03,$c2,$42,$03,$03,$02,$02,$03,$03

tile_sprite_missile_body:
    .byte $04,$04,$0c,$0c,$04,$04,$2c,$3c,$04,$37,$3f,$3f,$37,$37,$3f,$3f
    .byte $37,$37,$0c,$3f,$37,$04,$3f,$0c,$34,$24,$0c,$0c,$04,$04,$0c,$0c
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $ff,$ff,$88,$ff,$ff,$00,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00

level_offsets_table:
    .byte $00,$00,$00,$10,$10,$10,$20,$20,$20,$30,$30,$30,$40,$40,$40,$40

enemy_sprite_addresses_table:
    .byte $00,$0a                    ; ; &00 : &0a00 = enemy_sprite_zero
    .byte $60,$0a                    ; ; &01 : &0a60 = enemy_sprite_one
    .byte $c0,$0a                    ; ; &02 : &0ac0 = enemy_sprite_two
    .byte $00,$0a                    ; ; &03 : &0a00 = enemy_sprite_zero
    .byte $20,$0b                    ; ; &04 : &0b20 = enemy_sprite_three
    .byte $80,$0b                    ; ; &05 : &0b80 = enemy_sprite_four

skeleton_sprite_addresses_table:
    .byte $e0,$0b                    ; ; &04 : &0be0 = skeleton_sprite_zero
    .byte $a0,$5d                    ; ; &06 : &5da0 = skeleton_sprite_one
    .byte $10,$45                    ; ; &08 : &4510 = skeleton_sprite_two
    .byte $e8,$5d                    ; ; &0a : &5de8 = skeleton_sprite_three
    .byte $00,$01                    ; ; &0c : &0100 = sprite_space

unused_4be6:
    .byte $01,$01

object_sprite_navigation_rom:
    .byte $50,$0f,$1f,$1f,$1f,$1f,$0f,$50,$50,$0f,$6f,$4f,$4f,$6f,$0f,$50
    .byte $40,$0e,$0e,$0c,$0c,$0e,$0e,$40


level_data:
level_b_data:                        ; # Missile factor, sector 3
    .byte $99,$99,$99,$99,$33,$33,$33,$99,$99,$09,$99,$99,$49,$bc,$bb,$90 ; ; 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
    .byte $69,$0c,$0d,$90,$99,$09,$0d,$90,$39,$e3,$0d,$90,$99,$09,$99,$9f ; ; 048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c
    .byte $b9,$bb,$99,$99,$09,$0d,$00,$90,$09,$0d,$00,$d0,$39,$d3,$00,$d0
    .byte $09,$d4,$00,$9a,$09,$d8,$00,$d0,$09,$d6,$00,$d0,$39,$d3,$00,$90 ; ; 0  # :##############################
    .byte $b9,$bb,$bb,$d0,$09,$0c,$00,$d0,$09,$3c,$de,$9f,$09,$00,$d0,$90 ; ; 1  # :#MM#:#|  :   :|   ##   MMM####
    .byte $99,$00,$d7,$90,$99,$00,$d5,$90,$09,$00,$d0,$9f,$09,$3c,$de,$90 ; ; 2  # :#--#:#|~~:MMM:|--    --   ####
    .byte $09,$0c,$00,$90,$49,$00,$00,$9a,$89,$00,$a0,$9a,$69,$a0,$aa,$9a ; ; 3  # : |  v |  ~~~~~| :    :   B####
    .byte $99,$99,$99,$99,$99,$99,$99,$99,$99,$99,$99,$99,$99,$99,$99,$99 ; ; 4  # :#|~~~##       | v SS v   B####
                                                      ; 5  #:#|   ##       | ~~~~~~  BB####
                                                      ; 6  ###    C#   B     C   C  BBB####
                                                      ; 7  ##########~~#~~#~~##############

jump_text:
    .byte $1f,$0a,$18                ; ; TAB(&0a, &18)
    .byte "OR J TO JUMP"             ; ; "OR J TO JUMP"

unused_4c8f:
    .byte $00

sprite_exploding_mine_one:
    .byte $00,$00,$00,$00,$00,$0a,$26,$06

unused_4c98:
    .byte $00,$00,$00,$00

object_sprite_plutonium:
    .byte $50,$50,$50,$0f,$ef,$af,$ef,$8f,$40,$40,$40,$0e,$0e,$ae,$ae,$ee

object_sprite_switch:
    .byte $81,$41,$21,$01

object_sprite_button:
    .byte $88,$8f,$8f,$88

object_sprite_fuel:
    .byte $07,$df,$9f,$df,$9f,$9f,$07,$32,$0f,$5f,$5f,$5f,$5f,$df,$0f,$00
    .byte $0e,$af,$2f,$af,$2f,$bf,$0e,$c8

ranking_names:
    .byte "!AWFUL"                   ; ; "!AWFUL"  # 0 -  4 objects collected
    .byte "!FEEBLE"                  ; ; "!FEEBLE"  # 5 -  8 objects collected
    .byte "!POOR"                    ; ; "!POOR"  # 9 - 14 objects collected
    .byte "!NOT BAD"                 ; ; "!NOT BAD"  # 15 - 19 objects collected
    .byte "!FAIR"                    ; ; "!FAIR"  # 20 - 24 objects collected
    .byte "!GOOD"                    ; ; "!GOOD"  # 25 - 28 objects collected
    .byte "!SUPERB"                  ; ; "!SUPERB"  # 29 - 35 objects collected
    .byte "!AMAZING"                 ; ; "!AMAZING"  # 36 - 46 objects collected
    .byte "!"                        ; ; "!"

level_a_data:                        ; # Missile factor, sector 2
    .byte $99,$99,$99,$99,$33,$33,$33,$33,$99,$09,$99,$99,$49,$0d,$49,$9d ; ; 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
    .byte $69,$0d,$69,$9d,$09,$00,$00,$90,$b9,$bb,$bb,$9b,$09,$00,$00,$90 ; ; 048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c
    .byte $b9,$0b,$d0,$90,$09,$d0,$dd,$9d,$09,$d0,$dd,$9d,$49,$dd,$dd,$9d
    .byte $89,$dd,$dd,$9d,$69,$dd,$dd,$9d,$09,$dd,$dd,$9d,$f9,$dd,$dd,$9d ; ; 0  # :########################################-#-#-#-###-#-#-#-#-#:#
    .byte $99,$99,$09,$90,$b9,$bb,$bb,$90,$09,$0c,$00,$9c,$99,$09,$00,$9c ; ; 1  # :#MM | |  MMM C#| #   #   |       MM |##      MM #  #  #v   #:#
    .byte $09,$3c,$0e,$9c,$09,$0c,$00,$9c,$09,$3c,$0e,$9c,$99,$09,$00,$9c ; ; 2  # :#~~ | |  ~~~~~#|-#---#-- |~~~~~  ~~~|## -   ~~~~# ##      ##:#
    .byte $09,$0c,$00,$9c,$09,$9c,$b9,$9b,$09,$00,$00,$90,$b9,$bb,$bb,$90 ; ; 3  # :    |  ~~~~~~~#|  : :  # |MM        |   |       # #  #### # :#
    .byte $09,$7d,$0d,$90,$09,$5d,$0d,$90,$09,$0d,$0d,$90,$09,$0d,$00,$9a ; ; 4  # :### |  ~~~~~~~#|  v v  # |~~~       |   |  ~ ~~~# # ###   # :#
    .byte $09,$0d,$a0,$9a,$09,$00,$90,$99,$09,$00,$90,$99,$79,$0d,$90,$99 ; ; 5  # :#MM | ~~~~~~~~ |       | |    B###   ~~ ~~~~~~~~# # ### ### :#
    .byte $59,$0d,$00,$9a,$09,$0d,$00,$90,$b9,$bb,$0b,$90,$99,$09,$d0,$90 ; ; 6  # :#~~ |  ~~~~~~~  -------|     BB###B     B MMMM C#   #       ##
    .byte $99,$09,$d0,$90,$09,$00,$00,$90,$0c,$bc,$db,$da,$09,$00,$d0,$90 ; ; 7  # :########################################~#~#~#~###~#~#~#~#~###
    .byte $0c,$00,$d0,$d4,$09,$00,$dd,$98,$0c,$0d,$d0,$d8,$79,$0d,$dd,$96
    .byte $5c,$0d,$dd,$d0,$09,$0d,$dd,$9f,$99,$99,$99,$99,$09,$00,$00,$90
    .byte $0c,$99,$99,$d0,$99,$09,$00,$90,$0c,$00,$99,$d9,$09,$90,$99,$90
    .byte $9c,$90,$99,$d0,$e9,$90,$00,$90,$0c,$90,$90,$d0,$09,$00,$90,$90
    .byte $0c,$99,$99,$d0,$99,$09,$00,$90,$33,$33,$33,$99,$99,$99,$99,$99

level_9_data:                        ; # Missile factor, sector 1
    .byte $99,$99,$99,$99,$99,$02,$31,$33,$99,$09,$99,$99,$09,$00,$09,$9f ; ; 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
    .byte $09,$99,$09,$9f,$b9,$bb,$bb,$9b,$09,$09,$00,$90,$09,$39,$e3,$90 ; ; 048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c
    .byte $09,$79,$00,$90,$09,$69,$00,$90,$09,$39,$e3,$90,$09,$79,$00,$90
    .byte $09,$69,$00,$90,$09,$09,$00,$90,$09,$99,$09,$90,$09,$00,$09,$90 ; ; 0  # #############################################################:#
    .byte $09,$00,$09,$90,$39,$0e,$00,$90,$09,$a0,$09,$90,$09,$aa,$09,$90 ; ; 1  # ##  |           :  #   |MM####   MMM #  |   |   |     |  ####:#
    .byte $99,$99,$09,$90,$09,$00,$00,$9a,$09,$90,$99,$99,$09,$00,$00,$90 ; ; 2  # L# #|#########  v B#   |  ####~~       #| #C| #C|    #|   MMM:#
    .byte $b9,$bb,$bb,$90,$79,$00,$00,$90,$69,$00,$00,$90,$99,$09,$00,$90 ; ; 3  # #| :MM:MM #   BB# # |   : :    ###  ###############|      :#
    .byte $99,$39,$e3,$90,$99,$09,$00,$90,$99,$39,$e3,$90,$09,$0d,$00,$90 ; ; 4  # L###| :  :   ### ### # |   : :    | ##       MM:MMMMM   ~~~~~:#
    .byte $09,$0d,$00,$90,$09,$00,$00,$90,$49,$00,$00,$90,$89,$90,$bb,$99 ; ; 5  # :#  | v  v           # |   v v    |  #######   v       ------:#
    .byte $69,$90,$00,$90,$09,$90,$09,$90,$99,$00,$99,$90,$09,$00,$90,$90 ; ; 6  # :#CC|               B#            #                    C#####:#
    .byte $09,$99,$90,$90,$b9,$9b,$90,$90,$09,$90,$90,$90,$09,$99,$90,$90 ; ; 7  # :############################################################:#
    .byte $09,$9f,$90,$90,$b9,$9b,$00,$90,$09,$90,$07,$90,$09,$99,$05,$90
    .byte $09,$9f,$e3,$90,$b9,$9b,$04,$90,$09,$90,$08,$90,$09,$90,$08,$90
    .byte $09,$90,$08,$90,$09,$90,$06,$90,$09,$99,$00,$90,$b9,$bb,$00,$90
    .byte $09,$00,$c0,$9f,$09,$00,$cd,$99,$99,$00,$cd,$99,$99,$07,$cd,$99
    .byte $99,$08,$cd,$99,$99,$05,$cd,$99,$33,$33,$33,$33,$99,$99,$99,$99

level_8_data:                        ; # Crew's quarters, sector 3
    .byte $aa,$aa,$aa,$aa,$ca,$cc,$ac,$a0,$b3,$90,$a0,$a0,$ca,$9c,$cc,$ac ; ; 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
    .byte $0a,$99,$99,$a0,$0a,$09,$00,$a0,$0a,$00,$aa,$a0,$aa,$aa,$aa,$a0 ; ; 048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c
    .byte $0a,$00,$7e,$a0,$ea,$88,$f6,$a0,$68,$00,$f0,$a0,$78,$8e,$f7,$a0
    .byte $fa,$0f,$6d,$a0,$fa,$0f,$00,$a0,$68,$7d,$00,$a0,$88,$68,$00,$a0 ; ; 0  # #:#######PP##PP########P###############PP####P#PPPP##PPPPPP##:#
    .byte $ca,$cc,$cc,$a0,$aa,$a0,$7a,$a0,$ca,$ac,$fa,$a0,$0a,$aa,$fa,$a0 ; ; 1  # |L|   # PPPPPPP|#| ##PPP#### |          PPPPPP:PPPPPPPPP     :#
    .byte $aa,$8e,$68,$a0,$aa,$0f,$00,$a0,$ea,$06,$00,$a0,$fa,$0a,$00,$a0 ; ; 2  # | |## # P PPPPP| |#PPP###    |########    C PP:    |         :#
    .byte $68,$3a,$03,$a0,$aa,$aa,$0a,$ab,$aa,$00,$aa,$a0,$aa,$00,$00,$a0 ; ; 3  # |###  # P P  PP|###P   :#    |       | ####PPPLPPP |#### ##  :#
    .byte $aa,$00,$00,$a0,$0a,$00,$00,$a0,$ca,$cc,$cc,$a0,$0a,$09,$00,$a0 ; ; 4  # | |# ##PP PP   |###P   :##   |       | #PPPP P P P |## : : ##:#
    .byte $0a,$09,$e0,$a8,$0a,$09,$d0,$88,$0a,$09,$e0,$88,$0a,$09,$d0,$a8 ; ; 5  # ##|# ##PPPPP   |PPPP     #   | PPPP  | #PPPPPP PPP |#  L L  #:#
    .byte $0a,$09,$00,$a0,$0a,$09,$00,$a0,$0a,$c9,$cc,$a0,$0a,$00,$00,$a0 ; ; 6  # |                     L      PPPP                 #C     C#:#
    .byte $07,$a0,$aa,$a0,$7d,$a0,$7e,$a0,$fa,$a0,$ff,$a0,$fa,$a4,$ff,$a0 ; ; 7  # ################################PP###########################:#
    .byte $fa,$e0,$f6,$a0,$da,$68,$f0,$a0,$88,$88,$68,$a0,$3a,$b3,$00,$a0
    .byte $78,$e0,$78,$a0,$f7,$f0,$f0,$a0,$ff,$d0,$68,$a0,$f6,$00,$00,$a0
    .byte $fa,$cc,$cc,$a0,$fa,$a0,$aa,$aa,$f7,$a0,$0a,$a5,$ff,$a0,$00,$a0
    .byte $68,$a0,$b3,$a0,$0f,$00,$00,$a0,$0f,$a0,$b3,$a0,$06,$a0,$00,$a0
    .byte $0a,$00,$0a,$a4,$0a,$00,$aa,$aa,$33,$33,$33,$33,$aa,$aa,$aa,$aa

level_names:
    .byte "!SURFACE DEFENCE"         ; ; "!SURFACE DEFENCE"
    .byte "! ANCIENT SHRINE"         ; ; "! ANCIENT SHRINE"
    .byte "! CREWS QUARTERS"         ; ; "! CREWS QUARTERS"
    .byte "!MISSILE FACTORY"         ; ; "!MISSILE FACTORY"
    .byte "!"                        ; ; "!"

object_sprite_disk:
    .byte $ef,$ef,$ef,$0f,$0e,$0c,$0c,$0c,$0e,$0f,$0e,$0e,$0e,$0f,$0e,$0e
    .byte $0e,$0c,$0c,$06,$06,$06,$0e,$0e,$0e,$0e,$0e,$0e

unused_505d:
    .byte $ec,$e0,$30

completion_level_data:               ; # Completion screen
    .byte $7b,$76,$76,$b6,$0f,$00,$00,$60,$07,$00,$00,$4d,$0d,$00,$00,$89 ; ; 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
    .byte $0c,$00,$00,$8a,$05,$00,$00,$6c,$0f,$00,$00,$40,$5b,$54,$54,$b4 ; ; 048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c
                                                      ;
                                                      ; 0                          ##/SS\##                                
                                                      ; 1                          /      \                                
                                                      ; 2                          \      /                                
                                                      ; 3                          /      \                                
                                                      ; 4                          \      /                                
                                                      ; 5                          /      \                                
                                                      ; 6                          \ SSSS /                                
                                                      ; 7                          #\/##\/#                                

; level_7_data + &80                                                # Crew's quarters, sector 2
    .byte $99,$99,$99,$99,$99,$9a,$9a,$9a,$99,$9a,$9a,$9a,$99,$99,$99,$99 ; ; 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
    .byte $09,$97,$90,$95,$09,$96,$90,$95,$09,$90,$00,$90,$09,$90,$90,$99 ; ; 048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c
    .byte $09,$00,$90,$8e,$09,$00,$90,$0f,$09,$00,$90,$0f,$09,$00,$90,$0f
    .byte $39,$0b,$e0,$88,$09,$00,$f0,$8d,$39,$0b,$f0,$8e,$09,$00,$f0,$0f ; ; 0  # #############################:#
    .byte $c9,$cc,$f0,$8d,$09,$99,$d0,$88,$09,$99,$90,$00,$09,$00,$90,$8e ; ; 1  # ###        : : |   |#####| ##:#
    .byte $c9,$0c,$90,$0f,$99,$90,$9a,$0f,$99,$90,$90,$8d,$99,$90,$90,$00 ; ; 2  # ###TT      L L |## |     |  #:#
    .byte $99,$90,$90,$8e,$99,$90,$9a,$0f,$c9,$cc,$90,$0f,$09,$00,$90,$8d ; ; 3  # #######        |##  #####|   :#
    .byte $99,$00,$99,$99,$99,$09,$99,$99,$33,$33,$33,$33,$99,$99,$99,$99 ; ; 4  # ###                 #   #  ##:#
                                                      ; 5                                  ###### #####PPPPPP############:#
                                                      ; 6                                  ####CC #PPPPPPPPPP PPPP PPPP##:#
                                                      ; 7                                  ########P   PPP PP P  P P  P##:#

level_6_data:                        ; # Crew's quarters, sector 1
    .byte $aa,$aa,$aa,$aa,$33,$33,$33,$aa,$aa,$0a,$aa,$aa,$ca,$cc,$9a,$a9 ; ; 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
    .byte $0a,$0a,$aa,$aa,$0a,$ca,$cc,$a5,$0a,$3a,$0b,$a0,$0a,$0a,$00,$a0 ; ; 048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c
    .byte $0a,$0a,$00,$a7,$0a,$3a,$0b,$a6,$0a,$0a,$00,$a0,$0a,$0a,$00,$a0
    .byte $0a,$ca,$cc,$a0,$0a,$aa,$a0,$a0,$0a,$aa,$a0,$a0,$0a,$ca,$0c,$a0 ; ; 0  # :##############################################################
    .byte $0a,$0a,$aa,$a0,$0a,$0a,$0a,$a5,$0a,$0a,$0a,$a5,$0a,$0a,$0a,$a5 ; ; 1  # :#|                                          |           |#####
    .byte $0a,$0a,$0a,$a0,$0a,$0a,$0a,$a7,$0a,$0a,$0a,$a6,$0a,$0a,$0a,$a4 ; ; 2  # :#|######################################################|###:#
    .byte $0a,$0a,$0a,$a0,$0a,$0a,$aa,$a0,$0a,$ca,$cc,$a0,$0a,$aa,$00,$a0 ; ; 3  # : | |:  :  |##|          |#########PPP##PP PPP##PPP## :| |   :#
    .byte $0a,$aa,$00,$aa,$0a,$aa,$00,$aa,$0a,$aa,$00,$a0,$0a,$aa,$cc,$a0 ; ; 4  # :###|L  L  |  |##########|    |   #P           |      L|#####:#
    .byte $0a,$aa,$a0,$a0,$0a,$aa,$a0,$a0,$0a,$aa,$a0,$a0,$0a,$aa,$aa,$aa ; ; 5  # :###|      |## #        #|    |####P        ###|       |#    :#
    .byte $0a,$ea,$88,$88,$0a,$fa,$00,$a0,$0a,$fa,$00,$a0,$0a,$aa,$00,$aa ; ; 6  # ####C  TT       CCC TTC    ##     #P  ##  P  |    ##   | CTTC:#
    .byte $0a,$aa,$00,$aa,$0a,$fa,$00,$a0,$0a,$fa,$00,$a0,$0a,$0a,$00,$af ; ; 7  # ###################################P#########################:#
    .byte $0a,$fa,$00,$a0,$0a,$fa,$a0,$a0,$ca,$fa,$a0,$ac,$0a,$aa,$a0,$a0
    .byte $0a,$aa,$cc,$a0,$0a,$fa,$00,$a0,$0a,$fa,$00,$a0,$0a,$fa,$00,$aa
    .byte $0a,$aa,$00,$aa,$0a,$aa,$00,$a0,$0a,$0a,$00,$a0,$0a,$3a,$0b,$a0
    .byte $0a,$ca,$cc,$ac,$0a,$0a,$aa,$a0,$ca,$cc,$0a,$a5,$aa,$0a,$0a,$a7
    .byte $9a,$0a,$0a,$a6,$aa,$0a,$0a,$a4,$3a,$33,$33,$33,$aa,$aa,$aa,$aa

level_5_data:                        ; # Ancient shrine, sector 3
    .byte $77,$77,$77,$77,$33,$33,$33,$33,$77,$f7,$ff,$7f,$67,$0a,$b7,$74 ; ; 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
    .byte $07,$00,$07,$70,$37,$08,$b7,$74,$07,$00,$07,$70,$07,$00,$b7,$74 ; ; 048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c
    .byte $37,$08,$07,$70,$07,$00,$47,$70,$77,$ff,$07,$70,$07,$00,$47,$70
    .byte $07,$00,$07,$70,$07,$70,$77,$7f,$07,$00,$00,$70,$f7,$ff,$7f,$70 ; ; 0  # :############################################################:#
    .byte $07,$00,$70,$70,$57,$09,$70,$70,$77,$77,$77,$70,$67,$0a,$0a,$70 ; ; 1  # :#G :  : #    | G#G : : :| G#|  P P   # : : : #    |  : :  ##:#
    .byte $07,$00,$00,$70,$37,$08,$00,$70,$07,$00,$00,$70,$37,$83,$00,$70 ; ; 2  # :#/ C  C |    | \#/ C : C| \#|        # C C C #    |  : :  ##:#
    .byte $07,$00,$00,$70,$37,$08,$00,$70,$f7,$ff,$ff,$70,$07,$00,$00,$70 ; ; 3  # :|       |  # |  #    C  |  #| #####            ## | G: :G   :#
    .byte $57,$09,$09,$70,$77,$77,$77,$70,$f7,$ff,$00,$70,$07,$00,$00,$70 ; ; 4  # :|########### |  #/      | \#      | \######### ## | \###/ ##:#
    .byte $07,$70,$00,$70,$47,$70,$70,$77,$07,$70,$70,$70,$47,$70,$70,$70 ; ; 5  # :|P P P P P # ####       |  #   ###|  # P P P # ## |       ##:#
    .byte $07,$70,$ff,$7f,$07,$00,$00,$70,$07,$00,$09,$70,$77,$07,$77,$7f ; ; 6  # :|P P P     |                   #  |  | P P P | ##         ####
    .byte $07,$00,$07,$70,$37,$08,$b7,$74,$07,$00,$07,$70,$37,$08,$b7,$74 ; ; 7  # :##############################################################
    .byte $07,$00,$07,$70,$37,$08,$b7,$74,$07,$00,$07,$70,$77,$07,$77,$7f
    .byte $07,$00,$00,$70,$07,$70,$77,$77,$07,$70,$77,$77,$07,$00,$00,$70
    .byte $f7,$ff,$ff,$70,$07,$00,$00,$70,$07,$50,$09,$70,$37,$33,$07,$70
    .byte $07,$00,$07,$70,$37,$33,$07,$70,$07,$60,$0a,$70,$07,$00,$00,$70
    .byte $77,$07,$77,$77,$77,$07,$77,$77,$33,$33,$33,$77,$77,$77,$77,$77

level_4_data:                        ; # Ancient shrine, sector 2
    .byte $77,$77,$77,$77,$77,$33,$33,$33,$77,$07,$ee,$7e,$77,$00,$ee,$7e ; ; 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
    .byte $07,$00,$e0,$7e,$67,$09,$e0,$7e,$07,$07,$00,$7e,$67,$0a,$00,$7e ; ; 048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c
    .byte $07,$00,$00,$70,$77,$ff,$ff,$70,$77,$00,$77,$77,$77,$4b,$77,$77
    .byte $07,$00,$77,$77,$f7,$ff,$ff,$70,$07,$95,$00,$70,$77,$77,$70,$70 ; ; 0  # #############################################################:#
    .byte $07,$a6,$70,$70,$07,$00,$70,$70,$07,$95,$70,$70,$77,$77,$70,$70 ; ; 1  # ### G G ### | #   #  | |       |  ###  : #  : :    #  #  #|##:#
    .byte $07,$a6,$70,$70,$07,$00,$00,$70,$f7,$ff,$ff,$70,$07,$00,$77,$70 ; ; 2  # :#  \#/ | P |G#G G#G | |#######| G###G : #  :G:    P/\P/\P|  :#
    .byte $f7,$ff,$77,$70,$07,$07,$77,$70,$07,$f7,$7f,$70,$07,$07,$70,$70 ; ; 3  # :       | P |\#/ \#/ | | |   B#| \###/ C # G:P:G   P\/P\/P|  :#
    .byte $07,$07,$70,$70,$07,$07,$7e,$70,$07,$e7,$7e,$70,$07,$77,$77,$70 ; ; 4  # :BB     |###|        |###|  BB#|  ###    # \###/ ###  #  #| #:#
    .byte $f7,$ff,$7f,$70,$07,$00,$70,$70,$07,$95,$70,$70,$77,$77,$77,$77 ; ; 5  # :BBBB   |###| ###### |###############    #   P     #######| #:#
    .byte $77,$77,$77,$77,$77,$77,$77,$77,$07,$a6,$00,$77,$07,$00,$00,$77 ; ; 6  # :BBBBBB  ###                      #####                     #:#
    .byte $37,$83,$00,$70,$07,$00,$00,$70,$77,$77,$77,$70,$07,$00,$00,$70 ; ; 7  # :############################################################:#
    .byte $07,$50,$09,$70,$37,$33,$07,$70,$07,$b6,$47,$70,$37,$33,$07,$70
    .byte $07,$60,$0a,$70,$07,$00,$00,$70,$07,$00,$07,$70,$07,$00,$07,$70
    .byte $77,$4b,$77,$70,$07,$9c,$70,$70,$07,$ad,$70,$70,$77,$4b,$77,$70
    .byte $07,$9c,$70,$70,$07,$ad,$70,$70,$77,$4b,$77,$70,$f7,$ff,$ff,$70
    .byte $77,$00,$00,$70,$77,$00,$77,$77,$33,$33,$33,$33,$77,$77,$77,$77

level_3_data:                        ; # Ancient shrine, sector 1
    .byte $77,$77,$77,$77,$07,$00,$00,$77,$07,$77,$07,$77,$07,$77,$07,$77 ; ; 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
    .byte $07,$77,$07,$77,$07,$07,$00,$70,$07,$f7,$ff,$70,$07,$07,$00,$70 ; ; 048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c
    .byte $07,$07,$70,$70,$07,$07,$70,$70,$07,$77,$70,$70,$07,$07,$70,$70
    .byte $07,$77,$70,$70,$07,$07,$70,$70,$07,$77,$70,$70,$f7,$ff,$70,$70 ; ; 0  # ########################### | ###############################:#
    .byte $07,$00,$70,$70,$07,$00,$70,$70,$37,$83,$70,$70,$07,$00,$70,$7f ; ; 1  # |  : :        |    |         #            G####:#
    .byte $37,$83,$70,$70,$07,$00,$70,$70,$07,$00,$70,$77,$07,$00,$00,$70 ; ; 2  # #############|  : :   #####|### |####  ## #            \####:#
    .byte $07,$b7,$74,$70,$07,$07,$70,$70,$07,$b7,$74,$70,$07,$07,$70,$70 ; ; 3  # ### |   # # #|  C C   P P P|#|     ###### # GG  G/#\G   ##  :#
    .byte $00,$b7,$74,$70,$ff,$ff,$7f,$70,$00,$77,$70,$70,$07,$f7,$ff,$70 ; ; 4  # ### |                 P P P| |          # # \/  \###/   ## #:#
    .byte $07,$07,$00,$70,$07,$00,$00,$7e,$f7,$0f,$e0,$7e,$07,$07,$70,$77 ; ; 5  # | ############### #######|  B#      P # /\   P P    ## #:#
    .byte $07,$07,$00,$7e,$07,$77,$00,$7e,$07,$77,$00,$70,$07,$70,$00,$70 ; ; 6  # ####              |  #          BB#BB    P   ##   P P       #:#
    .byte $07,$70,$00,$70,$07,$77,$00,$70,$07,$77,$b7,$74,$07,$00,$00,$70 ; ; 7  # #############################################################:#
    .byte $77,$77,$77,$70,$07,$00,$00,$70,$07,$50,$c9,$77,$07,$60,$da,$77
    .byte $07,$00,$00,$70,$07,$00,$00,$70,$07,$50,$09,$70,$07,$c0,$b7,$74
    .byte $07,$70,$07,$70,$07,$d0,$b7,$74,$07,$60,$0a,$70,$07,$00,$00,$70
    .byte $07,$00,$00,$70,$57,$09,$00,$70,$77,$77,$77,$70,$77,$77,$77,$70
    .byte $77,$07,$00,$70,$77,$07,$77,$77,$33,$33,$33,$33,$77,$77,$77,$77

level_2_data:                        ; # Surface defence, sector 3
    .byte $aa,$aa,$aa,$5b,$33,$33,$33,$f8,$99,$05,$4e,$bb,$87,$0f,$8e,$ab ; ; 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
    .byte $b4,$07,$6e,$5b,$f8,$00,$0e,$b6,$fb,$00,$00,$8d,$fb,$cc,$cc,$8d ; ; 048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c
    .byte $bb,$99,$05,$8d,$b6,$ab,$07,$8d,$a9,$07,$00,$8d,$cf,$cc,$cc,$8d
    .byte $0f,$0e,$00,$8d,$0b,$99,$05,$74,$0b,$7b,$96,$07,$0f,$56,$74,$94 ; ; 0  # :#//####\##########\/#######/\######/   \/  \##########/\######
    .byte $0f,$80,$9b,$ba,$0f,$60,$7a,$8d,$5b,$00,$00,$8d,$bb,$99,$05,$8d ; ; 1  # :#########|      \###\\/        |                  |  \##/#####
    .byte $b6,$67,$07,$8d,$b4,$05,$00,$8d,$6f,$5b,$00,$b4,$5a,$76,$00,$b6 ; ; 2  # :\#/  |##/|~##\   #/\#\ ------- |~~~~~ ----~~~~~~~~~   ## \#/:#
    .byte $79,$00,$00,$b4,$0f,$5d,$00,$b8,$0f,$fd,$cc,$b8,$0f,$7d,$00,$b6 ; ; 3  # :     |## | #/\#\ #\ \/ \#/##// |      \###     ------/##    :#
    .byte $0f,$9d,$05,$80,$07,$ad,$0f,$80,$05,$4d,$07,$80,$0f,$7d,$00,$80 ; ; 4  # :~~~~ |\/ | \\/## \/     | \#/  | /\/\  \#/    ~      \#/ /#\:\
    .byte $0f,$00,$00,$80,$cf,$cc,$cc,$60,$0f,$0e,$00,$40,$0f,$0e,$54,$80 ; ; 5  # :/#\  |   |  #/#/        |      | \#/\\       ------      \##:/
    .byte $0f,$0e,$f6,$80,$07,$0e,$74,$80,$00,$0e,$56,$b4,$00,$00,$60,$bb ; ; 6  # ####\-------///#-----/\/##\          /#\  /\  /\  /\-------##:#
    .byte $00,$5d,$00,$b6,$05,$ad,$05,$80,$07,$9d,$0f,$80,$00,$ad,$07,$b4 ; ; 7  \  # ##\########/ ##################\/###########################:#
    .byte $00,$0e,$00,$b6,$05,$0e,$00,$80,$0f,$0e,$00,$80,$0f,$0e,$d0,$b4
    .byte $0f,$0e,$de,$b6,$0f,$de,$d0,$80,$0f,$de,$d0,$80,$0f,$de,$d0,$b4
    .byte $cf,$de,$d0,$b6,$0f,$d0,$00,$8d,$0f,$d0,$00,$8d,$5b,$40,$05,$8d
    .byte $87,$b9,$0f,$8d,$85,$aa,$07,$8d,$7b,$00,$00,$8d,$9b,$05,$54,$8d
    .byte $8f,$0f,$b8,$b9,$bb,$07,$a6,$aa,$fb,$33,$33,$33,$bb,$99,$45,$99

level_1_data:                        ; # Surface defence, sector 2
    .byte $aa,$aa,$aa,$aa,$33,$33,$33,$33,$99,$05,$4e,$99,$8f,$0f,$8e,$ab ; ; 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
    .byte $bb,$07,$6e,$5b,$fa,$00,$0e,$f8,$f9,$cc,$cc,$b6,$7b,$00,$00,$8e ; ; 048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c
    .byte $0f,$00,$00,$8e,$4f,$59,$00,$80,$bb,$87,$05,$80,$bb,$a9,$e7,$80
    .byte $a6,$07,$e0,$80,$cc,$0e,$e0,$80,$00,$de,$e0,$80,$00,$d0,$e0,$80 ; ; 0  # :##########\|  |\#/:\######/\#######/  |\####################:/
    .byte $cc,$dc,$ee,$80,$05,$d0,$e0,$80,$0f,$d0,$e0,$80,$07,$d0,$e0,$80 ; ; 1  # :#####/ /###|  |   L \#\/##   |        | | #\/#\##/ \########:#
    .byte $23,$d0,$e0,$80,$05,$d0,$e0,$80,$5b,$d0,$e0,$80,$fb,$d0,$e0,$80 ; ; 2  # :\#/ |  #/#/~~ |       \##/   |   /##\ | | \##/      |\#/ \#/L#
    .byte $6f,$d5,$e0,$80,$4f,$df,$e0,$80,$bb,$df,$e0,$80,$ab,$d7,$e0,$80 ; ; 3  # :    |  \##  ---------------- | /##### | |  ##       | |      #
    .byte $07,$d0,$e0,$80,$05,$d0,$e0,$80,$0f,$00,$e0,$80,$cf,$cc,$00,$80 ; ; 4  # :~~~~|   \/    ~                ### \/ | | /## /###\ | | -~~~L#
    .byte $0f,$00,$00,$80,$0f,$40,$59,$80,$0f,$80,$fb,$60,$0f,$b4,$7a,$40 ; ; 5  # :/#\ |    ~~~~~~~~~~~~~~~~~~~~  \#/    |   \#/ \###/ | | /##\:#
    .byte $0f,$f8,$00,$80,$07,$b8,$05,$80,$00,$a6,$07,$80,$00,$00,$00,$80 ; ; 6  # :####\~~                                        \#\      \/\###
    .byte $cc,$cc,$cc,$80,$05,$00,$00,$80,$cf,$cc,$0c,$80,$0f,$00,$00,$80 ; ; 7  # :##\#############################\/#######################\/###
    .byte $9b,$05,$54,$80,$6f,$9b,$fb,$80,$4f,$ab,$7a,$80,$ab,$07,$00,$80
    .byte $5b,$00,$54,$80,$fa,$00,$b8,$85,$f9,$00,$b8,$bb,$7b,$00,$f8,$b6
    .byte $0f,$00,$76,$80,$5b,$00,$00,$80,$fb,$cc,$cc,$80,$bb,$05,$00,$80
    .byte $8f,$cf,$cc,$80,$bb,$07,$00,$80,$fb,$00,$4d,$85,$ba,$05,$8e,$67
    .byte $b9,$0f,$8e,$45,$aa,$07,$6e,$bb,$33,$02,$31,$b8,$94,$99,$99,$bb

level_0_data:                        ; # Surface defence, sector 1, title and status screen
    .byte $bb,$aa,$aa,$aa,$fb,$33,$33,$33,$7b,$00,$0e,$4d,$cf,$cc,$cc,$8d ; ; 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
    .byte $9b,$99,$99,$b9,$a6,$bb,$bb,$ab,$94,$bb,$bb,$4f,$bb,$bb,$bb,$bb ; ; 048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c048c
    .byte $00,$00,$00,$00,$00,$11,$11,$00,$00,$01,$10,$00,$00,$12,$31,$00
    .byte $00,$00,$00,$00,$00,$11,$11,$00,$00,$11,$05,$00,$00,$12,$12,$00 ; ; 0  # ####\/#                           /######\           \#########
    .byte $00,$00,$00,$00,$00,$14,$51,$00,$00,$01,$10,$00,$00,$12,$31,$00 ; ; 1  # #/|####                           #/    \# #\SSSS      \####/:\
    .byte $00,$00,$00,$00,$00,$11,$11,$00,$00,$00,$00,$00,$00,$11,$11,$00 ; ; 2  # : |#### ##\ ##\ /#\ # ##\         #  ..  # ######\        \/ L/
    .byte $00,$01,$10,$00,$00,$12,$31,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ; 3  # : |#### # # ### # # # # #         # .... # ####/\/            \
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ; 4  # :~|#### # # #\# # # # # #         # .... # ####\         ~~~~L/
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$14,$11,$11,$51 ; ; 5  # : |#### ##/ # # \#/ # ##/         #  ..  # #######\/#\/#####\:\
    .byte $31,$00,$00,$12,$01,$60,$06,$10,$01,$66,$66,$10,$01,$66,$66,$10 ; ; 6  # :--####                           #\    /# #################/:/
    .byte $01,$60,$06,$10,$51,$00,$00,$14,$12,$11,$11,$31,$00,$00,$00,$00 ; ; 7  # :/###/#                           \######: #################\:\
    .byte $80,$bb,$bb,$bb,$60,$bb,$bb,$bb,$d0,$b8,$bb,$bb,$90,$b8,$bb,$bb
    .byte $a0,$78,$b6,$bb,$c0,$58,$80,$bb,$00,$76,$80,$bb,$00,$00,$60,$bb
    .byte $00,$00,$40,$bb,$00,$00,$80,$bb,$05,$00,$60,$bb,$0f,$00,$40,$bb
    .byte $5b,$00,$80,$bb,$fb,$00,$80,$bb,$fb,$00,$8e,$bb,$bb,$05,$8e,$bb
    .byte $bb,$07,$8e,$8f,$7b,$00,$6e,$67,$3f,$02,$31,$33,$5b,$54,$54,$54
