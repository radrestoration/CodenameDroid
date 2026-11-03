; enemy.s: the enemy update's shortcuts, and the objects of a level entered by a lift. Runs from $f600 (the HIGHC segment; the
; engine's own code has no room left below $a000).
;
; update_enemies runs every enemy of the level, however far from the window. For each it buffers the pixels at the player's
; four collision points and at the colliding blasters before the enemy is plotted, and compares them after. An enemy that is
; not plotted changes nothing on the screen, so for an enemy well outside the window both are the same bytes, read and
; restored, and the test cannot find a collision: the buffering and the test are skipped for it (about 1,700 cycles an enemy;
; the mines are still tested, by position).

.segment "HIGHC"

; c64_buffer_if_near: instead of buffer_player_points_and_blasters. The enemy is far if its column (4 a tile, without the
; fraction and the offset of a flipped sprite: at most 5 more) is more than 12 columns from the window's.
c64_buffer_if_near:
    lda enemy_tile_x
    asl
    asl
    sec
    sbc left_edge_x_fraction
    sec
    sbc left_edge_tile_address_low
    cmp #RING_W + 12
    bcc @near
    cmp #256 - 12
    bcs @near
    lda #0
    sta c64_enear
    rts
@near:
    lda #1
    sta c64_enear
    jmp buffer_player_points_and_blasters

; c64_check_if_near: instead of check_for_enemy_collision_with_blasters_and_player
c64_check_if_near:
    lda c64_enear
    bne @check
    rts
@check:
    jmp check_for_enemy_collision_with_blasters_and_player

; The lifts' scrolls draw tiles only: the game plots an object a column at a time as an edge of the window passes it. The BBC's
; 32 columns start clear of the objects; the wider window can have an object across its edge or inside it, so after the scroll
; every object (not collected) in the window is plotted, column by column, as the edges would have. An object's column c is
; at level x = objects_x + 1 + c.
c64_scroll_down_objs:
    jsr scroll_down
    jmp c64_plot_window_objects
c64_scroll_up_objs:
    jsr scroll_up
c64_plot_window_objects:
.if RING_W = 32
    rts
.else
    lda level
    cmp #$0c
    bcc @go
    rts
@go:
    clc
    lda left_edge_tile_address_low
    adc left_edge_x_fraction
    sta PO_L
    lda level
    asl
    asl
    sta PO_I
    lda #4
    sta PO_K
@obj:
    ldx PO_I
    lda objects_x,x
    cmp #$ff
    beq @next                   ; (no object)
    lda objects_type_and_flags,x
    and #$0f
    bne @next                   ; collected
    lda objects_type_and_flags,x
    and #$f0
    lsr
    lsr
    sta PO_H                    ; the type * 4
    lda #0
    sta PO_X                    ; the window column
@cx:
    ldx PO_I
    lda PO_L                    ; the object's column here: x - objects_x - 1, if it is under the object's width
    clc
    adc PO_X
    sbc objects_x,x             ; (carry clear: one more)
    ldy PO_H
    cmp object_types_sprite_address_and_sizes + 3,y
    bcs @nx
    tax
    lda #0
    sta object_sprite_offset
    cpx #0
    beq @m1
@m: clc
    adc object_types_sprite_address_and_sizes + 2,y
    dex
    bne @m
    sta object_sprite_offset
@m1:
    lda PO_X
    sta object_screen_x
    ldx PO_I
    stx object_to_plot
    lda objects_type_and_flags,x
    lsr
    lsr
    lsr
    lsr
    tax
    jsr plot_object
@nx:
    inc PO_X
    lda PO_X
    cmp #RING_W
    bcs @next
    jmp @cx
@next:
    inc PO_I
    dec PO_K
    beq @ret
    jmp @obj
@ret:
    rts
.endif


; update_enemies' copies of an enemy's four variables (x, y, direction and state, fraction and frame) to the working copy and
; back; X leaves as the loops left it: the enemy's offset + 4
c64_get_enemy_vars:
    ldx enemy_to_update
    lda enemies_variables,x
    sta enemy_variables
    lda enemies_variables + 1,x
    sta enemy_variables + 1
    lda enemies_variables + 2,x
    sta enemy_variables + 2
    lda enemies_variables + 3,x
    sta enemy_variables + 3
    inx
    inx
    inx
    inx
    jmp c64_get_enemy_done

c64_set_enemy_vars:
    ldx enemy_to_update
    lda enemy_variables
    sta enemies_variables,x
    lda enemy_variables + 1
    sta enemies_variables + 1,x
    lda enemy_variables + 2
    sta enemies_variables + 2,x
    lda enemy_variables + 3
    sta enemies_variables + 3,x
    inx
    inx
    inx
    inx
    jmp c64_set_enemy_done

; ------------------------------------------------------------------------------------------------
; The enemies' sprites. An enemy is three columns of 32 bytes (column by column in the sprite data), which the BBC's loops plot
; a byte at a time, with the screen address worked out for each (about 40 cycles a byte). Here a group of 8 rows is done at a
; time: the three columns' cells are addressed by three self-modified stores, the row in the group is Y. Done where the plot
; starts on a cell (screen address a multiple of 8), is 3 columns wide and a whole number of groups tall; anything else goes
; to the BBC's loops (the jump replaced the instruction in front of them, which is done first). The screen addresses and the
; width are left as the loops leave them.
ENEMY_SA = $3a78                ; (the flipped plot's sprite address: the operand of its load)


; c64_swap_hook: the enemy sprites are about to be rewritten (swap_enemy_colours)
c64_swap_hook:
    jsr e3_forget
    lda #$0a                    ; (what the call replaced)
    sta $71
    rts

e3_wrap:
    WRAP_CELL zp_ci
    rts

; e3_forget: the memo is empty (a high byte of 0 is no sprite's). Needed when the characters are all new (cells_reset): a
; character the memo remembers may be on the free list.
e3_forget:
    lda #0
    ldx #127
e3_f:
    sta MEMHI,x
    dex
    bpl e3_f
    rts

; e3_cell: the cell zp_ci has just had its 8 bytes written from the sprite bytes at e3_key. The character for them is the one the
; cell got the last time the same source was plotted, so that is remembered (a memo of 256 entries by source address): no dirty
; list, no hash, no comparing. Otherwise update_cell finds or makes the character, and it is remembered. (The enemies' sprites
; are changed in place when a level starts: c64_swap_hook forgets them. Sources elsewhere are not remembered: some of the game's
; graphics change as it plays.)
e3_cell:
    lda e3_key + 1              ; only the sprites that do not change while the game plays are remembered. The enemies' are in
    ldx e3_fl                   ; page $0a-$0b (a flipped plot's address has bit 14 set; the flip is checked, so no other sprite is
    bmi e3_tl                   ; mistaken for one); a tile's (e3_fl = $80) are anywhere but there, with bit 13 set (c64_tile_begin)
    and #$fe
    eor e3_fl
    cmp #$0a
    bne e3_nm
    beq e3_use
e3_tl:
    cmp #$20                    ; (page 0)
    beq e3_nm
    and #$fe
    cmp #$2a                    ; (the enemies' sprites, which are rewritten in place)
    bne e3_use
e3_nm:
    jmp update_cell             ; (not remembered)
e3_use:
    lda e3_key                  ; the memo entry: bits of the address, mixed
    lsr
    eor e3_key + 1
    and #$7f
    sta e3_idx
    tax
    lda MEMLO,x
    cmp e3_key
    bne e3_miss
    lda MEMHI,x
    cmp e3_key + 1
    bne e3_miss
    ldy MEMC,x
    lda VER,y                   ; (the character must still be the pattern it was)
    cmp MEMV,x
    bne e3_miss
    sty zp_c
    jmp uc_have                 ; (zp_ci and zp_c: the cell takes the character, if it is not the one it has)
e3_miss:
    jsr update_cell
    lda zp_ci + 1
    clc
    adc #>CELLCHAR
    sta zp_u + 1
    lda #0
    sta zp_u
    ldy zp_ci
    lda (zp_u),y                ; the character the cell has now (if there was none to be had, the old one: not remembered)
    sta zp_c
    tax
    jsr cell_is                 ; (zp_p1 is still the cell's bytes)
    bne e3_nok
    ldx e3_idx
    lda zp_c
    sta MEMC,x
    tay
    lda VER,y
    sta MEMV,x
    lda e3_key
    sta MEMLO,x
    lda e3_key + 1
    sta MEMHI,x
e3_nok:
    rts

; e3_pre: carry clear if the plot can be done here (see above); e3_cnt = the groups of 8 rows
e3_pre:
    lda screen_address_low
    and #7
    bne e3_no
    lda width
    beq e3_no
    cmp #4
    bcs e3_no
    sta e3_nc
    lda height
    beq e3_no
    and #7
    bne e3_no
    lda height
    cmp #41
    bcs e3_no
    lsr
    lsr
    lsr
    sta e3_cnt
    lda screen_address_low
    sta e3_gp
    lda screen_address_high
    sta e3_gp + 1
    clc
    rts
e3_no:
    sec
    rts

; e3_cells: the three cells of the group of rows just plotted (e3_gp: the first column's cell, e3_s0: the first column's source in
; the order of the columns, e3_fl: 0 or $40, the plot's flip), through e3_cell. A column on is 8 bytes on in the ring (round
; its end) and a height before (flipped) or after in the sprite.
e3_cells:
    ldx e3_nc
    stx e3_k
    lda e3_s0
    sta e3_a
    lda e3_s0 + 1
    sta e3_a + 1
    lda e3_gp + 1               ; the first cell's index (zp_ci is not changed by e3_cell: the next columns are the next cells)
    ldx e3_gp
    jsr addr_to_cell
e3_col:
    lda e3_a
    sta e3_key
    lda e3_a + 1
    ora e3_fl
    sta e3_key + 1
    jsr e3_cell
    dec e3_k
    beq e3_cd
    inc zp_ci
    bne e3_ci1
    inc zp_ci + 1
e3_ci1:
    jsr e3_wrap
    lda e3_fl                   ; and a height on (or back) in the sprite
    bne e3_back
    clc
    lda e3_a
    adc height
    sta e3_a
    bcc e3_col
    inc e3_a + 1
    bne e3_col
e3_back:
    sec
    lda e3_a
    sbc height
    sta e3_a
    lda e3_a + 1
    sbc #0
    sta e3_a + 1
    jmp e3_col
e3_cd:
    rts

; e3_run: the plot, in groups of 8 rows. Carry set if it was not done (the caller goes on into the BBC's loops).
; The row loop is the flipped one (the byte through flip_table); a plot that is not flipped has the flip's four bytes (tax, lda
; flip_table,x) made a BIT of page 0 and a NOP (6 cycles, as they are).
e3_tu:   .byte $2c,0,0,$ea     ; bit $0000 / nop: what an unflipped plot has where the flip is
e3_tf:   .byte $aa,$bd,<flip_table,>flip_table

e3_run:
    jsr e3_pre
    bcs e3_no
    ldy #3                      ; the flip's four instructions, for three columns
    ldx #3
    lda e3_fl
    beq e3_fx
    ldx #7
e3_fx:
    lda e3_tu,x
    sta FX0,y
    sta FX1,y
    sta FX2,y
    dex
    dey
    bpl e3_fx
e3_src:
    lda e3_s0                   ; the columns' sprite addresses: SA0, and SA1, SA2 a column on (or before: flipped)
    sta SA0 + 1
    lda e3_s0 + 1
    sta SA0 + 2
    lda height
    ldx e3_fl
    beq e3_p
    eor #$ff                    ; (minus the height)
    clc
    adc #1
    ldx #$ff
    bne e3_q
e3_p:
    ldx #0
e3_q:
    stx zp_t                    ; the high byte of +-height
    sta zp_u                    ; and the low
    clc
    lda SA0 + 1
    adc zp_u
    sta SA1 + 1
    lda SA0 + 2
    adc zp_t
    sta SA1 + 2
    clc
    lda SA1 + 1
    adc zp_u
    sta SA2 + 1
    lda SA1 + 2
    adc zp_t
    sta SA2 + 2
e3_group:
    lda e3_gp
    sta DC0 + 1
    lda e3_gp + 1
    sta DC0 + 2
    clc
    lda e3_gp
    adc #8
    sta DC1 + 1
    lda e3_gp + 1
    adc #0
    cmp #$80
    bcc e3_c1
    lda #RING_HI
e3_c1:
    sta DC1 + 2
    clc
    lda e3_gp
    adc #16
    sta DC2 + 1
    lda e3_gp + 1
    adc #0
    cmp #$80
    bcc e3_c2
    lda #RING_HI
e3_c2:
    sta DC2 + 2
    lda e3_nc                   ; (a plot of one or two columns: the others are written where nothing is)
    cmp #3
    bcs e3_full
    lda #<e3_dummy
    sta DC2 + 1
    lda #>e3_dummy
    sta DC2 + 2
    lda e3_nc
    cmp #2
    bcs e3_full
    lda #<e3_dummy
    sta DC1 + 1
    lda #>e3_dummy
    sta DC1 + 2
e3_full:
    ldy #0
e3_row:
SA0:
    lda $ffff,y
FX0:
    tax
    lda flip_table,x
DC0:
    sta $ffff,y
SA1:
    lda $ffff,y
FX1:
    tax
    lda flip_table,x
DC1:
    sta $ffff,y
SA2:
    lda $ffff,y
FX2:
    tax
    lda flip_table,x
DC2:
    sta $ffff,y
    iny
    cpy #8
    bne e3_row
    lda SA0 + 1                 ; this group's cells
    sta e3_s0
    lda SA0 + 2
    sta e3_s0 + 1
    jsr e3_cells
    dec e3_cnt
    beq e3_end
    clc                         ; the next group of rows: a stride down, round the ring, and the sprite columns 8 on
    lda e3_gp
    adc #<STRIDE
    sta e3_gp
    lda e3_gp + 1
    adc #>STRIDE
    cmp #$80
    bcc e3_n1
    sbc #RING_SZ_HI
e3_n1:
    sta e3_gp + 1
    ldx #0
e3_adv:                         ; (SA0, SA1, SA2 are 10 bytes apart in the loop)
    clc
    lda SA0 + 1,x
    adc #8
    sta SA0 + 1,x
    bcc e3_n2
    inc SA0 + 2,x
e3_n2:
    txa
    clc
    adc #10
    tax
    cpx #30
    bcc e3_adv
    jmp e3_group
e3_end:
    lda #0                      ; what the loops leave: width 0 (and no marking by the hook: the cells are done)
    sta width
    sta hk_cols
    lda e3_fl
    bne e3_done
    lda e3_nc                   ; (plot_sprite: the screen address is left at the last column's last row's byte: 8 * columns - 1 on)
    asl
    asl
    asl
    sec
    sbc #1
    clc
    adc e3_gp
    sta screen_address_low
    lda e3_gp + 1
    adc #0
    cmp #$80
    bcc e3_w2
    lda #RING_HI
e3_w2:
    sta screen_address_high
e3_done:
    clc
    rts

c64_fenemy_go:
    sta $3a79                   ; (what the jump replaced)
    lda ENEMY_SA
    sta e3_s0
    lda ENEMY_SA + 1
    sta e3_s0 + 1
    lda #$40
    sta e3_fl
    jsr e3_run
    bcs c64_fenemy_slow
    rts
c64_fenemy_slow:
    jmp plot_flipped_enemy_column_loop

c64_sprite_go:
    sta plot_sprite_address_high ; (what the jump replaced)
    lda sprite_offset           ; not a plot from the middle of the sprite, nor a vertically flipped one
    bne c64_sprite_no
    lda plot_sprite_next_byte_opcode
    cmp #$e8
    beq c64_sprite_yes
c64_sprite_no:
    jmp plot_sprite_column_loop
c64_sprite_yes:
    lda $72
    sta e3_s0
    lda $73
    sta e3_s0 + 1
    lda #0
    sta e3_fl
    jsr e3_run
    bcs c64_sprite_no
    rts

; ------------------------------------------------------------------------------------------------
; A column of tiles (plot_column_of_tiles): a tile is four cells, each the same 8 bytes whenever the tile, its fraction (the
; part of it that is in the column) and its flipping are the same. c64_tile_begin, where the BBC's code has settled the
; flipping, notes where the tile's bytes come from: the sprite address ($72/$73) and a fraction of 32 bytes, with the flipping in
; the bottom bits (the addresses are in the tile graphics, from $8000: no sprite of an enemy is). c64_tile_end, after the four
; cells are plotted, gives each its character as e3_cell does, and the column's hook marks nothing.

c64_tile_begin:
    lda screen_address_low      ; the tile's first cell
    sta t_sa
    lda screen_address_high
    sta t_sa + 1
    lda $77                     ; tile_x_fraction
    ldy $59                     ; the flipping
    cpy #2
    bcc t_k1
    lda #3                      ; (a horizontally flipped tile is read from the other end of its four fractions)
    sec
    sbc $77
t_k1:
    asl
    asl
    asl
    asl
    asl
    clc
    adc $72
    sta t_key
    lda $73
    adc #0
    ora #$20                    ; (a tile: not mistaken for an enemy's source)
    sta t_key + 1
    tya
    ora t_key
    sta t_key
    ldx #0                      ; (what the call replaced)
    tya
    rts

c64_tile_end:
    lda #$80                    ; (what e3_cell is told: a tile's)
    sta e3_fl
    lda t_key
    sta e3_key
    lda t_key + 1
    sta e3_key + 1
    lda t_sa + 1
    ldx t_sa
    jsr addr_to_cell
    lda #4
    sta t_k
t_cell:
    jsr e3_cell
    dec t_k
    beq t_done
    clc                         ; the next cell down: 8 more of the sprite, a row on in the ring
    lda e3_key
    adc #8
    sta e3_key
    bcc t_c1
    inc e3_key + 1
t_c1:
    clc
    lda zp_ci
    adc #RING_W
    sta zp_ci
    bcc t_c2
    inc zp_ci + 1
t_c2:
    jsr e3_wrap
    jmp t_cell
t_done:
    lda #0
    sta hk_cols                 ; (the hook finds nothing to mark)
    inc $76                     ; (what the call replaced)
    lda $76
    rts

.assert * <= MEMLO, error, "the high code runs into the memo of enemy.s"
