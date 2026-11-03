; ---- the enemies (update_enemies and what it calls in the BBC game). An enemy is five bytes as the BBC has them; its picture is
; twelve characters of the pool, written into ROWS where it stands (the cells under it are kept to put back).

.segment "BSS"
ev_x:       .res 1
ev_y:       .res 1
ev_state:   .res 1
ev_prev:    .res 1
ev_raw:     .res 1              ; tile fraction and frame as stored
ev_ff:      .res 1              ; the tile fraction
ev_energy:  .res 1
ev_col:     .res 1
ev_g:       .res 1
ev_drawn:   .res 1
pg_col:     .res 10
pg_row:     .res 10
pg_img:     .res 10
pool_base:  .res 1
pool_groups:.res 1
seed:       .res 1
ev_idx:     .res 1
ev_dir:     .res 1
ev_row:     .res 1
ro_x:       .res 1
ro_y:       .res 1
ro_i:       .res 1
enemy_under: .res 12
.segment "CODE"

; rnd: a byte
rnd:
    lda seed
    asl
    bcc :+
    eor #$1d
:   sta seed
    eor tick
    rts

; get_cell: the character at column X, row Y
get_cell:
    lda #0
    sta p2
    tya
    clc
    adc rows_page
    sta p2 + 1
    txa
    tay
    lda (p2),y
    rts

update_enemies:
    jsr consider_using_keys
    inc frame_counter
    lda seed
    bne :+
    lda #$a5
    sta seed
:   lda #0
    sta enemy_to_update
@loop:
    lda enemy_to_update
    cmp last_enemy
    bne :+
    rts
:   tax
    lda enemies,x
    sta ev_x
    lda enemies + 1,x
    sta ev_y
    lda enemies + 2,x
    sta ev_prev
    and #$0f
    sta ev_state
    lda enemies + 3,x
    sta ev_raw
    lda enemies + 4,x
    sta ev_energy
    lda ev_x
    bpl :+
    jmp @store
:   lda ev_raw
    and #7
    sta ev_ff
    jsr plot_enemy_step
    ; write back before the collisions
    ldx enemy_to_update
    lda ev_x
    sta enemies,x
    lda ev_prev
    and #$f0
    clc
    adc ev_state
    sta enemies + 2,x
    lda ev_raw
    and #$f0
    clc
    adc ev_ff
    sta enemies + 3,x
    jsr enemy_collisions
    ; reload what the collisions may have changed
    ldx enemy_to_update
    lda enemies + 2,x
    and #$0f
    sta ev_state
    lda enemies + 3,x
    sta ev_raw
    lda enemies + 4,x
    sta ev_energy
    lda enemies,x
    sta ev_x
    ; the animation
    lda ev_state
    and #2
    beq @nst
    lda ev_state
    cmp #4
    bcs @nst
    lda #$f0
    sta ev_raw
@nst:
    lda ev_raw
    and #$f0
    clc
    adc #$10
    cmp #$60
    bne :+
    lda #0
:   cmp #$a0
    bne @sk
    inc ev_state
    inc ev_state
    lda #$80
    ldx ev_state
    cpx #$0e
    bcc @sk
    ldx #$ff
    stx ev_x
@sk:
    sta ev_raw
    ldx enemy_to_update
    lda enemies + 3,x
    and #7
    clc
    adc ev_raw
    sta enemies + 3,x
    lda ev_x
    sta enemies,x
    lda ev_prev
    and #$f0
    clc
    adc ev_state
    sta enemies + 2,x
    lda ev_energy
    sta enemies + 4,x
    jmp @next
@store:
    ; (an enemy that is not there: its picture, if any, goes)
    jsr enemy_gone
@next:
    lda enemy_to_update
    clc
    adc #5
    sta enemy_to_update
    jmp @loop

enemy_gone:
    jsr find_group
    cpx #$ff
    beq @r
    jsr erase_group
    lda #$ff
    sta pool_owner,x
@r: rts

; ---- the pool of characters
; find_group: the group of enemy_to_update in X ($ff if none)
pool_configure:
    lda nchars
    sta pool_base
    lda #$fc
    sec
    sbc pool_base
    sta zt
    lda #0
    sta pool_groups
@count:
    lda zt
    cmp #12
    bcc @done
    sec
    sbc #12
    sta zt
    inc pool_groups
    lda pool_groups
    cmp #10
    bne @count
@done:
    rts

find_group:
    lda pool_groups
    beq @none
    tax
    dex
@l: lda pool_owner,x
    cmp enemy_to_update
    beq @r
    dex
    bpl @l
@none:
    ldx #$ff
@r: rts

; erase_group: X the group: the cells it covered are put back
erase_group:
    lda pg_col,x
    cmp #$ff
    beq @r
    stx zx
    lda #0
    sta zr                      ; the cell 0 - 11
@l: ; the cell's place
    lda zr
    jsr cell_xy                 ; zc column offset, zk row offset
    ldx zx
    lda pg_col,x
    clc
    adc zc
    sta zs
    lda pg_row,x
    clc
    adc zk
    pha
    lda zx
    asl
    clc
    adc zx
    asl
    asl                         ; group * 12
    clc
    adc zr
    sta zt
    ldx zs
    pla
    tay
    pha
    jsr get_cell
    sec
    sbc pool_base
    cmp zt
    bne @skip                   ; another enemy's character is on top: leave it
    pla
    tay
    ldx zt
    lda pool_under,x
    ldx zs
    jsr put_cell
    jmp @next
@skip:
    pla
@next:
    inc zr
    lda zr
    cmp #12
    bne @l
    ldx zx
    lda #$ff
    sta pg_col,x
@r: rts

; cell_xy: cell number A (0 - 11): column offset in zc, row offset in zk
cell_xy:
    ldx #0
    stx zk
    cmp #3
    bcc :+
    sec
    sbc #3
    inc zk
    cmp #3
    bcc :+
    sec
    sbc #3
    inc zk
    cmp #3
    bcc :+
    sec
    sbc #3
    inc zk
:   sta zc
    rts

; install_group: group X gets the picture (image ev_dir * 16 + zv) as its twelve characters
fr96_lo:
    .repeat 11, i
    .byte <(i * 96)
    .endrepeat
fr96_hi:
    .repeat 11, i
    .byte >(i * 96)
    .endrepeat

install_group:
    stx zx
    ldy zv
    lda fr96_lo,y
    clc
    adc #<enemy_frames_left
    sta p3
    lda fr96_hi,y
    adc #>enemy_frames_left
    sta p3 + 1
    ldx level
    lda level_swap,x
    sta zm
    lda #0
    sta zr
@c: ; the cell of the left-facing picture this one is made from: the same, or for the right the mirror image across the row
    lda zr
    ldx ev_dir
    bne @src
    jsr mirror_cell_index
@src:
    asl
    asl
    asl
    tay
    ldx #0
@b: lda (p3),y
    sta zt
    lda ev_dir
    bne @nm
    stx zs
    ldx zt
    lda mirror_table,x
    sta zt
    ldx zs
@nm:
    lda zm
    beq @plain
    lda zt                      ; colours 1 and 3 swapped: the high bit of each pixel ^= its low bit
    and #$0f
    asl
    asl
    asl
    asl
    eor zt
    jmp @put
@plain:
    lda zt
@put:
    sta cb,x
    iny
    inx
    cpx #8
    bne @b
    lda zx
    asl
    clc
    adc zx
    asl
    asl
    clc
    adc zr
    clc
    adc pool_base
    jsr set_char
    inc zr
    lda zr
    cmp #12
    bne @c
    ldx zx
    rts

; mirror_cell_index: cell A (0 - 11, 3 to a row) -> the cell at the other end of its row
mirror_cell_index:
    tax
    lda mirror_cell,x
    rts
mirror_cell:
    .byte 2, 1, 0, 5, 4, 3, 8, 7, 6, 11, 10, 9

; alloc_group: a free group in X ($ff if none), for enemy_to_update
alloc_group:
    lda pool_groups
    beq @none
    tax
    dex
@l: lda pool_owner,x
    cmp #$ff
    beq @f
    dex
    bpl @l
@none:
    ldx #$ff
    rts
@f: lda enemy_to_update
    sta pool_owner,x
    lda #$ff
    sta pg_col,x
    sta pg_img,x
    rts

; draw_enemy: ev_col, the row ev_y * 4, the picture ev_dir / zv (255 for none, a blank)
draw_enemy:
    jsr find_group
    lda zv
    cmp #$ff
    bne @pic
    cpx #$ff
    beq @r
    jsr erase_group
    lda #$ff
    sta pool_owner,x
@r: rts
@pic:
    cpx #$ff
    bne @have
    jsr alloc_group
    cpx #$ff
    beq @r
@have:
    stx ev_g
    lda ev_y
    asl
    asl
    sta ev_row
    ; the picture
    lda ev_dir
    asl
    asl
    asl
    asl
    ora zv
    cmp pg_img,x
    beq :+
    pha
    jsr install_group
    ldx ev_g
    pla
    sta pg_img,x
:   ; what lies under the new place (read before anything changes, so it may include this group's own old cells)
    lda #0
    sta zr
@u: lda zr
    jsr cell_xy
    lda ev_col
    clc
    adc zc
    tax
    lda ev_row
    clc
    adc zk
    tay
    jsr get_cell
    jsr resolve_under
    ldx zr
    sta enemy_under,x
    inc zr
    lda zr
    cmp #12
    bne @u
    ; the old cells outside the new place go back; the others are written over, so the picture is never missing
    jsr release_old
    ldx ev_g
    lda ev_col
    sta pg_col,x
    lda ev_row
    sta pg_row,x
    lda #0
    sta zr
@l: lda zr
    jsr cell_xy
    lda ev_col
    clc
    adc zc
    sta zs
    lda ev_row
    clc
    adc zk
    sta zl
    lda ev_g
    asl
    clc
    adc ev_g
    asl
    asl
    clc
    adc zr
    tax
    ldy zr
    lda enemy_under,y
    sta pool_under,x
    txa
    clc
    adc pool_base
    ldx zs
    ldy zl
    jsr put_cell
    inc zr
    lda zr
    cmp #12
    bne @l
    rts

; release_old: the cells of group ev_g's old place that the new place does not cover are put back
release_old:
    ldx ev_g
    lda pg_col,x
    cmp #$ff
    beq @r
    lda #0
    sta zr
@l: lda zr
    jsr cell_xy
    ldx ev_g
    lda pg_col,x
    clc
    adc zc
    sta ro_x
    lda pg_row,x
    clc
    adc zk
    sta ro_y
    lda ro_x
    sec
    sbc ev_col
    cmp #3
    bcs @out
    lda ro_y
    sec
    sbc ev_row
    cmp #4
    bcc @next                   ; still covered
@out:
    lda ev_g
    asl
    clc
    adc ev_g
    asl
    asl
    clc
    adc zr
    sta ro_i
    clc
    adc pool_base
    sta zt
    ldx ro_x
    ldy ro_y
    jsr get_cell
    cmp zt
    bne @next                   ; another enemy's character is on top: leave it
    ldx ro_i
    lda pool_under,x
    ldx ro_x
    ldy ro_y
    jsr put_cell
@next:
    inc zr
    lda zr
    cmp #12
    bne @l
@r: rts

; resolve_under: a pool character is replaced by what lies under it
resolve_under:
    cmp #$fc
    bcs @r
    cmp pool_base
    bcc @r
    sec
    sbc pool_base
    tax
    lda pool_under,x
@r: rts

; ---- consider_plotting_enemy
plot_enemy_step:
    lda ev_ff
    cmp #4
    bne :+
    lda #0
    sta ev_ff
    jsr move_enemy
:   lda ev_state
    cmp #2
    bcc @moving
    dec ev_ff
    lda ev_ff
    cmp #$ff
    bne @moving
    lda #3
    sta ev_ff
@moving:
    ; the cell column of its left edge
    lda ev_x
    asl
    asl
    ldx ev_state
    sta zt
    txa
    and #1
    sta ev_dir
    bne @left
    lda zt
    sec                         ; (the BBC plots after the fraction has gone up by one)
    adc ev_ff
    jmp @col
@left:
    lda zt
    sec
    sbc ev_ff
    sec
    sbc #1
@col:
    sta ev_col
    ; the picture
    lda ev_state
    cmp #4
    bcs @skel
    lda ev_raw
    lsr
    lsr
    lsr
    lsr
    sta zv
    jmp @vis
@skel:
    and #$0e
    sec
    sbc #4
    lsr
    clc
    adc #6
    sta zv
    cmp #10
    bcc @vis
    lda #$ff                    ; the last one is blank
    sta zv
@vis:
    ; on the screen (the window with some to spare)?
    lda ev_col
    cmp #$fa
    bcs @hide
    clc
    adc #3
    bcs @hide
    sec
    sbc t_w
    bcc @hide
    cmp #46
    bcs @hide
    jsr draw_enemy
    ; firing
    lda ev_state
    cmp #4
    bcs @done
    jsr enemy_fire
@done:
    inc ev_ff
    rts
@hide:
    lda #$ff
    sta zv
    jsr draw_enemy
    inc ev_ff
    rts

; ---- move_enemy: a step to the next tile
move_enemy:
    lda ev_state
    cmp #4
    bcs me_ret
    lda ev_energy
    and #$f0
    cmp #$30
    bcs me_ret
    lda ev_state
    bne me_left
    ; moving right
    ldx ev_x
    inx
    inx
    ldy ev_y
    jsr get_tile_at_x_y
    bne flip_enemy_direction
    ldx ev_x
    inx
    inx
    ldy ev_y
    iny
    jsr get_tile_at_x_y
consider_flipping:
    beq flip_enemy_direction
    cmp #$04
    beq flip_enemy_direction
    cmp #$06
    beq flip_enemy_direction
    cmp #$0d
    beq flip_enemy_direction
    cmp #$d0
    beq flip_enemy_direction
    cmp #$40
    beq flip_enemy_direction
    cmp #$60
    beq flip_enemy_direction
move_left_or_right:
    lda ev_state
    bne @l
    inc ev_x
    rts
@l: dec ev_x
me_ret:
    rts

flip_enemy_direction:
    jsr move_left_or_right
    lda ev_state
    eor #1
    sta ev_state
    rts

me_left:
    ldx ev_x
    dex
    dex
    ldy ev_y
    jsr get_tile_at_x_y
    bne flip_enemy_direction
    ldx ev_x
    dex
    dex
    ldy ev_y
    iny
    jsr get_tile_at_x_y
    jmp consider_flipping

; get_tile_at_x_y: X tile column, Y tile row: the nibble of the map, masked (so a high nibble is $x0); Z set if space
get_tile_at_x_y:
    txa
    asl
    asl
    sta zt
    tya
    lsr
    clc
    adc zt
    sta p3
    lda level
    clc
    adc #>LTILES
    sta p3 + 1
    ldx #$0f
    tya
    and #1
    beq :+
    ldx #$f0
:   stx zt
    ldy #0
    lda (p3),y
    and zt
    cmp #0
    rts

; ---- firing
enemy_fire:
    jsr player_row
    stx zt
    lda ev_y
    asl
    asl
    sec
    sbc zt
    cmp #4
    bcc @inrange
    cmp #$fe
    bcs @inrange
    rts
@inrange:
    jsr rnd
    and #3
    beq :+
    rts
:   ; on the screen
    lda ev_col
    sec
    sbc t_w
    cmp #36
    bcc :+
    rts
:   ldx #2
@f: lda bl_ttl,x
    cmp #$ff
    beq @found
    inx
    cpx #6
    bne @f
    rts
@found:
    lda ev_state
    and #1
    sta bl_dir,x
    bne @left
    lda ev_col
    sec
    sbc #1
    cmp px
    bcc :+
    rts
:   lda ev_col
    clc
    adc #2
    jmp @set
@left:
    lda ev_col
    cmp px
    bcs :+
    rts
:   sec
    sbc #1
@set:
    sta bl_c,x
    lda ev_y
    asl
    asl
    asl
    asl
    asl
    clc
    adc #13
    sta bl_l,x
    lda #$0e
    sta bl_ttl,x
    jmp sfx_enemy_fire

; ---- collisions with the player and with mines
enemy_collisions:
    ldx enemy_to_update
    lda enemies + 2,x
    and #$0f
    cmp #4
    bcc :+
    rts
:   jsr enemy_vs_player
    jmp enemy_vs_mines

; the player's four points: (cells, lines) by stance
point_tab:
    .byte 2, 0,  0, 0,  2, 27,  0, 27          ; standing
    .byte 2, 8,  0, 8,  2, 27,  0, 27          ; kneeling
    .byte 5, 0,  0, 0,  5, 27,  0, 27          ; crawling

enemy_vs_player:
    jsr find_group
    cpx #$ff
    bne :+
    rts
:   stx ev_g
    lda pstance
    cmp #1
    beq @kneel
    cmp #2
    beq @crawl
    ldy #0
    jmp @go
@kneel:
    ldy #8
    jmp @go
@crawl:
    ldy #16
@go:
    sty zy
    lda #0
    sta zr                      ; the point
@p: ldy zy
    lda point_tab,y
    sta zs                      ; dx
    lda point_tab + 1,y
    sta zk                      ; dy
    lda pc
    clc
    adc zs
    sta sa_c
    lda py
    clc
    adc zk
    bcs @n
    sta sa_l
    lsr
    lsr
    lsr
    tay
    ldx sa_c
    jsr get_cell
    sec
    sbc pool_base
    bcc @n
    ldx #0
@slot:
    cmp #12
    bcc @slot_found
    sbc #12
    inx
    cpx pool_groups
    bcs @n
    jmp @slot
@slot_found:
    cpx ev_g
    bne @n
    jsr rdb
    tax
    lda conv_table,x
    sta zv
    lda zs
    ldy zk
    jsr player_byte
    cmp zv
    beq @n
    jmp enemy_hits_player
@n: lda zy
    clc
    adc #2
    sta zy
    inc zr
    lda zr
    cmp #4
    bne @p
    rts

enemy_hits_player:
    lda suit_energy
    sec
    sbc #10
    sta suit_energy
    ldx enemy_to_update
    lda #1
    sta enemies + 4,x
    jmp damage_enemy

enemy_vs_mines:
    ldx enemy_to_update
    lda enemies + 2,x
    and #$0f
    cmp #4
    bcc :+
    rts
:   lda enemies + 1,x
    asl
    asl
    asl
    asl
    asl
    clc
    adc #24
    sta zl                      ; feet y
    lda enemies,x
    asl
    asl
    sta zt
    lda enemies + 3,x
    and #7
    sta zs
    lda enemies + 2,x
    and #1
    bne @left
    lda zt
    clc
    adc zs
    adc #2
    jmp @have
@left:
    lda zt
    sec
    sbc zs
@have:
    sta zc
    ldx #0
@m: lda mines_state,x
    bpl @n
    lda mines_x,x
    cmp zc
    bne @n
    lda mines_y,x
    cmp zl
    bne @n
    lda #0
    sta mines_state,x
    stx zx
    lda mines_x,x
    sta zs
    lda mines_y,x
    lsr
    lsr
    lsr
    tay
    ldx zs
    lda #0
    jsr put_cell
    ldx enemy_to_update
    lda #1
    sta enemies + 4,x
    jmp damage_enemy
@n: inx
    cpx #6
    bne @m
    rts

; damage_enemy: X the enemy's offset: a hit of the blaster (or the player or a mine, which set its energy to 1)
damage_enemy:
    lda enemies + 2,x
    and #$0f
    cmp #4
    bcs @r
    stx zx
    ldy #5
    ldx #5
    jsr add_to_score
    ldx zx
    dec enemies + 4,x
    lda enemies + 4,x
    and #7
    bne @short
    lda enemies + 3,x
    and #7
    ora #$70
    sta enemies + 3,x
    lda enemies + 2,x
    and #1
    clc
    adc #4
    sta enemies + 2,x
    lda #8
    jmp play_sound_for_damage
@short:
    lda #2
    jmp play_sound_for_damage
@r: rts
