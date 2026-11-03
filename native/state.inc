; the game's variables (the BBC's names where it has them)
pc:             .res 1          ; the cell column of the sprite's left edge
px:             .res 1          ; player_x: the cell column of the player's left cell
py:             .res 1          ; the line of the top of the player (a multiple of 4)
pdir:           .res 1          ; player_direction: 0 facing right, 1 left
pstance:        .res 1          ; 0 standing, 1 kneeling, 2 crawling, 3 climbing, $f0 dead
pframe:         .res 1
jump_timer:     .res 1
jump_direction: .res 1          ; 0 none, 1 right, 2 left
pjf:            .res 1          ; player_jumping_or_falling
clim_cd:        .res 1          ; climbing_or_crawling_cooldown
swapping:       .res 1          ; player_swapping_sides_on_rope
obst_pix:       .res 1          ; obstacle_pixel_value
obst_y:         .res 1          ; obstacle_y_position
supp:           .res 1          ; suppress_horizontal_falling
frame_counter:  .res 1
suit_energy:    .res 1
blaster_energy: .res 1
lives:          .res 1
jp_energy:      .res 1          ; jet_pack_energy
jp_cool:        .res 1
maxjump:        .res 1          ; maximum_jump_timer
total_objs:     .res 1
score:          .res 8
nmines:         .res 1
carried:        .res 16         ; objects_carried
deepest:        .res 1
init_px:        .res 1          ; initial_player_x
lift_dir:       .res 1
recent_fire:    .res 1
recent_up:      .res 1
recent_down:    .res 1
sound_off:      .res 1
paused:         .res 1
objflags:       .res 56         ; objects_type_and_flags: type * 16 + collected
objabs:         .res 4 * 9      ; the characters an object's cells show once it is collected
tilechg:        .res 1

; the player on the screen (smoothed): position in 1/16 pixel, line
ppos_l:         .res 1
ppos_h:         .res 1
ppy:            .res 1          ; the line shown
pcx:            .res 1          ; the cell column the position is heading for

; enemies: five bytes each as the BBC has them (x tile, y tile, direction and state, tile fraction and frame, energy and flags)
enemies:        .res 16 * 5
last_enemy:     .res 1          ; offset
enemy_to_update: .res 1

; blasters: six slots, 0 and 1 the player's
bl_ttl:         .res 6          ; $ff none, $fe colliding
bl_dir:         .res 6
bl_c:           .res 6          ; cell column
bl_l:           .res 6          ; line
; mines
mines_x:        .res 6          ; cell column
mines_y:        .res 6          ; line of the cell's top
mines_state:    .res 6          ; $ff placed, 0 free, 1-4 exploding

; the pool of enemy characters: which enemy has each group of twelve, and what the cells under it were
pool_owner:     .res 10
pool_under:     .res 10 * 12
skel_show:      .res 1          ; the dead player shown as a skeleton
title_on:       .res 1
