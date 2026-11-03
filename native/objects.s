; ---- objects, mines, tile changes, the score

.segment "BSS"
feet_x:     .res 1
obj_hit:    .res 1
rx:         .res 1
ry:         .res 1
rv:         .res 1
rk:         .res 1
rr:         .res 1
rc:         .res 1
ob_base:    .res 1
ctype:      .res 1
.segment "CODE"

; add_to_score: Y points at digit X, carrying leftwards
add_to_score:
    tya
    clc
    adc score,x
    sta score,x
    cmp #10
    bcc @r
    sec
    sbc #10
    sta score,x
    dex
    cpx #$ff
    beq @r
    ldy #1
    jmp add_to_score
@r: rts

; ---- replot_tile: X tile column, Y tile row, A nibble: the level's map and the picture
replot_tile:
    stx rx
    sty ry
    sta rv
    ; the map: LTILES + level * 256 + x * 4 + y / 2
    lda level
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
    lda ry
    and #1
    bne @hi
    lda (p3),y
    and #$f0
    clc
    adc rv
    sta (p3),y
    jmp @pic
@hi:
    lda rv
    asl
    asl
    asl
    asl
    sta zt
    lda (p3),y
    and #$0f
    clc
    adc zt
    sta (p3),y
@pic:
    lda rv
    asl
    asl
    asl
    asl
    sta rk                      ; index into TG, running on across the 16 cells
; draw_tile: the tile at rx, ry from TG at rk
draw_tile:
    lda #0
    sta rr
@r: lda #0
    sta rc
@c: ldx rk
    lda TG,x
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
    inc rk
    inc rc
    lda rc
    cmp #4
    bne @c
    inc rr
    lda rr
    cmp #4
    bne @r
    rts

; ---- mines
; check_for_player_collision_with_mines_to_right / _left: the cell in front of the feet
check_for_player_collision_with_mines_to_right:
    lda px
    clc
    adc #3
    jmp mines_check
check_for_player_collision_with_mines_to_left:
    lda px
    sec
    sbc #1
mines_check:
    sta feet_x
    jsr player_row
    txa
    clc
    adc #3
    asl
    asl
    asl
    sta zl                      ; feet_y
    ldx #0
@l: lda mines_x,x
    cmp feet_x
    bne @n
    lda mines_y,x
    cmp zl
    bne @n
    lda mines_state,x
    bpl @n
    lda #4
    sta mines_state,x
    dec obst_y
    lda suit_energy
    sec
    sbc #10
    sta suit_energy
    lda #8
    jmp play_sound_for_damage
@n: inx
    cpx #6
    bne @l
    rts

; the explosions: frames by the countdown
update_exploding_mines:
    ldx #0
@l: lda mines_state,x
    beq @n
    bmi @n
    stx zx
    sta zv
    ; the frame
    lda #CH_EXPL1
    sta zt
    lda zv
    cmp #1
    bne :+
    lda #0
    sta zt
:   lda zv
    and #7
    cmp #3
    bne :+
    lda #CH_EXPL0
    sta zt
:   dec mines_state,x
    lda mines_x,x
    sta zc
    lda mines_y,x
    lsr
    lsr
    lsr
    tay
    ldx zc
    lda zt
    jsr put_cell
    ldx zx
@n: inx
    cpx #6
    bne @l
    rts

; drop_mine: D
drop_mine:
    lda nmines
    bne :+
    rts
:   ldx #0
@f: lda mines_state,x
    beq @found
    inx
    cpx #6
    bne @f
    rts
@found:
    stx zx
    lda py
    and #7
    beq :+
    rts
:   jsr player_row
    txa
    and #1
    beq :+
    rts
:   ; the cell at the feet, on the side the player faces
    lda pdir
    bne @l
    lda px
    clc
    adc #3
    jmp @have
@l: lda px
    sec
    sbc #1
@have:
    sta feet_x
    txa
    clc
    adc #3
    sta zl                      ; row of the cell
    ; the cell must be blank (its eight bytes), the first byte of the one below not
    lda #0
    sta p2
    lda zl
    clc
    adc rows_page
    sta p2 + 1
    ldy feet_x
    lda (p2),y
    tay
    lda BPAT,y
    ora BPAT + $100,y
    ora BPAT + $200,y
    ora BPAT + $300,y
    ora BPAT + $400,y
    ora BPAT + $500,y
    ora BPAT + $600,y
    ora BPAT + $700,y
    beq :+
    rts
:   inc p2 + 1
    ldy feet_x
    lda (p2),y
    tay
    lda BPAT,y
    bne :+
    rts
:   dec nmines
    ldx zx
    lda feet_x
    sta mines_x,x
    lda zl
    asl
    asl
    asl
    sta mines_y,x
    lda #$ff
    sta mines_state,x
    ldx feet_x
    ldy zl
    lda #CH_MINE
    jmp put_cell

; ---- objects
; consider_collecting_object_to_right / _left: carry set if one was collected (the caller then leaves)
consider_collecting_object_to_right:
    lda obst_y
    cmp #$10
    bcs :+
    clc
    rts
:   lda px
    clc
    adc #2
    jmp object_search
consider_collecting_object_to_left:
    lda obst_y
    cmp #$10
    bcs :+
    clc
    rts
:   lda px
    sec
    sbc #4
object_search:
    sta feet_x
    lda level
    asl
    asl
    sta zk                      ; object number in the table
    lda #0
    sta ry
@l: lda zk
    sta zt
    asl
    clc
    adc zt
    tax
    lda level_objects + 1,x
    cmp feet_x
    bne @next
    lda level_objects + 2,x
    sta rx                      ; its y
    jmp @touch
@next:
    inc zk
    inc ry
    lda ry
    cmp #4
    bne @l
    clc
    rts
@touch:
    ; vertically: (row * 8 - y) in $e0 - $ff
    jsr player_row
    txa
    asl
    asl
    asl
    sec
    sbc rx
    cmp #$e0
    bcs @vert
    clc
    rts
@vert:
    ldx zk
    lda objflags,x
    sta obj_hit
    and #$0f
    beq :+
    clc
    rts
:   inc objflags,x
    jsr unplot_object
    lda obj_hit
    jsr collect_object
    sec
    rts

; unplot_object: object number zk (in the whole table) shows its absent cells
unplot_object:
    lda zk
    and #3
    sta zv                      ; object in the level (the table is level * 4 + i)
    lda zk
    asl
    clc
    adc zk
    tax
    lda level_objects + 1,x
    clc
    adc #1                      ; (the BBC draws an object from the column after its x)
    sta ox
    lda level_objects + 2,x
    sta oy
    lda obj_hit
    lsr
    lsr
    lsr
    lsr
    tay
    lda objtype_w,y
    sta ow
    lda objtype_h,y
    sta oh
    lda oy
    lsr
    lsr
    lsr
    sta ocr0
    lda oy
    clc
    adc oh
    sec
    sbc #1
    lsr
    lsr
    lsr
    sta ocr1
    ; objabs index: (oi * 9) with oi = zk & 3 within the level: oi * 9 + ocx * 3 + (row - ocr0)
    lda zv
    asl
    asl
    asl
    clc
    adc zv
    sta ob_base
    lda #0
    sta ocx
@c: lda ocr0
    sta ocr
@r: lda ocx
    asl
    clc
    adc ocx
    clc
    adc ocr
    sec
    sbc ocr0
    clc
    adc ob_base
    tax
    lda objabs,x
    pha
    lda ox
    clc
    adc ocx
    tax
    ldy ocr
    pla
    jsr put_cell
    inc ocr
    lda ocr
    cmp ocr1
    beq @r
    bcc @r
    inc ocx
    lda ocx
    cmp ow
    bne @c
    rts

; collect_object: A the object's flags (type * 16)
collect_object:
    inc total_objs
    lda obj_hit
    lsr
    lsr
    lsr
    lsr
    sta ctype                   ; type
    tax
    lda objscore,x
    tay
    iny
    ldx #4
    jsr add_to_score
    jsr sfx_pickup
    ldx ctype
    inc carried,x
    lda #$0b
    sta maxjump
    cpx #2
    bne :+
    jmp plot_player_standing
:   lda carried + 3
    beq @nocrate
    clc
    lda carried
    adc #6
    sta carried
    lda #0
    sta carried + 3
    inc carried + 1
    inc carried + 1
@nocrate:
    lda carried + 5
    beq @nospring
    lda #$11
    sta maxjump
    lda #0
    sta carried + 5
@nospring:
    lda carried + 6
    beq @nofuel
    lda #$ff
    sta jp_energy
    dec carried + 6
@nofuel:
    lda carried + 7
    beq @noswitch
    dec carried + 7
    ldx #$1e
    ldy #4
    lda #$0f
    jsr replot_tile
    ldx #$1e
    ldy #5
    lda #$0f
    jsr replot_tile
@noswitch:
    lda carried + $e
    beq @noremote
    lda carried + 9
    cmp #2
    bcc @noremote
    ldx #$2b
    ldy #6
    lda #0
    sta carried + $e
    jsr replot_tile
    ldx #$2b
    ldy #3
    lda #$0f
    jsr replot_tile
@noremote:
    lda ctype
    cmp #8
    bne @r
    lda #0
    sta carried + 8
    lda px
    cmp #$b0
    bcc @r
    inc carried + 8
@r: rts

objscore:   .byte 1, 1, 5, 5, 4, 6, 2, 3, 0, 1, 0, 1, 0, 2, 0, 0
