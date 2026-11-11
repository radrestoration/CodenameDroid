; ---- the display: two screen matrices (a window of 40 x 25 cells onto ROWS), the fine scroll, the player's and the blasters' sprites

.segment "CODE"

; ------------------------------------------------------------------------------------------------
; the matrices: MAT_A and MAT_B, the shown one and the one being built
.macro SHIFT dsta, srca, n3
    ldx #15
:
    .repeat 16, j
    lda srca + j * 16,x
    sta dsta + j * 16,x
    .endrepeat
    dex
    bpl :-
    ldx #15
:
    .repeat 16, j
    lda srca + $100 + j * 16,x
    sta dsta + $100 + j * 16,x
    .endrepeat
    dex
    bpl :-
    ldx #15
:
    .repeat 16, j
    lda srca + $200 + j * 16,x
    sta dsta + $200 + j * 16,x
    .endrepeat
    dex
    bpl :-
    ldx #15
:
    .repeat n3, j
    lda srca + $300 + j * 16,x
    sta dsta + $300 + j * 16,x
    .endrepeat
    dex
    bpl :-
.endmacro

; a column of the level into column 'col' of the matrix at dsta: 25 rows from the row the pointer p4 points at, cell Y
.macro NEWCOL dsta, col
    .repeat 25, r
    lda (p4),y
    sta dsta + col + 40 * r
    inc p4 + 1
    .endrepeat
.endmacro

; the 40 cells of a row of the level, from cell column zt, to the matrix row at p5
copy_row:
    ldy #39
@l: lda (p4),y
    sta (p5),y
    dey
    bpl @l
    rts

; the whole window, cur_w and cur_cam, into the matrix whose high byte is A
draw_full:
    sta p5 + 1
    lda #0
    sta p5
    sta p4
    lda cur_w
    sta p4                      ; the low byte of the pointer is the window's first column
    lda cur_cam
    clc
    adc rows_page
    sta p4 + 1
    lda #25
    sta zk
@r: jsr copy_row
    inc p4 + 1
    lda p5
    clc
    adc #40
    sta p5
    bcc :+
    inc p5 + 1
:   dec zk
    bne @r
    rts


init_view:
    lda level
    jsr start_for_level          ; px, py for the level's start (sets the player)
    lda py                       ; the camera as the follow rule leaves it for that line: the top of the level (the ship) unless the player is low
    lsr
    lsr
    lsr
    cmp #19
    bcc @top
    sec
    sbc #12
    cmp #8
    bcc @cam
    lda #7
    bne @cam
@top:
    lda #0
@cam:
    sta cur_cam
    sta want_cam
    jsr snap_player
    jsr calc_scroll
    lda t_w
    sta cur_w
    lda cur_cam
    sta mat_c
    sta mat_c + 1
    lda cur_w
    sta mat_w
    sta mat_w + 1
    lda #>MAT_A
    jsr draw_full
    lda #>MAT_B
    jsr draw_full
    lda #0
    sta cur_buf
    lda #D018_A
    sta p_d018
    rts

; calc_scroll: the scroll position follows the player (clamped to the level)
calc_scroll:
    lda ppos_l
    sec
    sbc #<CENTER
    sta spos_l
    lda ppos_h
    sbc #>CENTER
    sta spos_h
    bcs @pos
    lda #0
    sta spos_l
    sta spos_h
    jmp @px
@pos:
    lda spos_h
    cmp #>MAXPOS
    bcc @px
    bne @max
    lda spos_l
    cmp #<MAXPOS
    bcc @px
@max:
    lda #<MAXPOS
    sta spos_l
    lda #>MAXPOS
    sta spos_h
@px:
    lda spos_h
    sta spx_h
    lda spos_l
    lsr spx_h
    ror
    lsr spx_h
    ror
    lsr spx_h
    ror
    lsr spx_h
    ror
    sta spx_l
    clc
    adc #7
    sta zt
    lda spx_h
    adc #0
    lsr
    ror zt
    lsr
    ror zt
    lsr
    ror zt
    lda zt
    sta t_w
    asl
    asl
    asl
    sec
    sbc spx_l
    sta t_xs
    rts

col_setup_right:
    lda cur_w
    clc
    adc #39
    sta zd
    jmp col_ptr
col_setup_left:
    lda cur_w
    sta zd
col_ptr:
    lda #0
    sta p4
    lda cur_cam
    clc
    adc rows_page
    sta p4 + 1
    rts

; Keep the picture at the logic position, even when several game steps run in one frame.
snap_player:
    lda px
    lsr
    sta ppos_h
    lda #0
    ror
    sta ppos_l
    lda py
    sta ppy
    rts


; ---- sprites
framemap:   .byte 0, 1, 2, 0, 3, 4, 0, 0
bit2:       .byte $01, $02, $04, $08, $10, $20, $40, $80

; sprite_pos: world pixel x in zt:A (16-bit), line in zl -> sprite x register (9 bits) in zt:zs, sprite y in zk; carry set if off screen
sprite_pos:
    sec
    sbc spx_l
    sta zs
    lda zt
    sbc spx_h
    sta zt
    bmi @neg
    beq @xok
    cmp #2
    bcs @off
    lda zs
    cmp #65
    bcs @off
    jmp @xok
@neg:
    cmp #$ff
    bne @off
    lda zs
    cmp #$e8
    bcc @off
@xok:
    lda zs
    clc
    adc #24
    sta zs
    lda zt
    adc #0
    sta zt
    lda cur_cam
    asl
    asl
    asl
    sta zk
    lda zl
    sec
    sbc zk
    bcc @off
    cmp #176
    bcs @off
    clc
    adc #50
    sta zk
    clc
    rts
@off:
    sec
    rts

; set sprite number X (screen x zt:zs, y zk)
set_sprite:
    lda zs
    sta p_sx,x
    lda zk
    sta p_sy,x
    lda zt
    beq :+
    lda p_msb
    ora bit2,x
    sta p_msb
:   lda p_en
    ora bit2,x
    sta p_en
    rts

make_sprites:
    lda #0
    sta p_msb
    sta p_en
    sta p_xexp
    jsr player_sprites
    jsr blaster_sprites
    rts


; the player's sprites: image and direction by stance
player_sprites:
    jsr select_player_image
@img:
    lda pdir
    beq @right
    lda sprite_index_left,x
    jmp @blk
@right:
    lda sprite_index_right,x
@blk:
    sta zv                       ; first block
    ; x of the left edge of the sprite image in world pixels
    lda ppos_h
    sta zt
    lda ppos_l
    lsr zt
    ror
    lsr zt
    ror
    lsr zt
    ror
    lsr zt
    ror
    sta zm                       ; pixels, low
    lda zt
    sta zf                       ; high
    lda pstance
    cmp #2
    bne @one
    ; crawling: 7 cells wide in three sprites of 3, 3 and 1 cells; facing left the image starts 4 cells left
    lda pdir
    beq :+
    lda zm
    sec
    sbc #32
    sta zm
    lda zf
    sbc #0
    sta zf
:   lda ppy
    sta zl
    ldy #0
@c: sty zy
    lda zm
    clc
    adc crawl_dx,y
    pha
    lda zf
    adc #0
    sta zt
    pla
    jsr sprite_pos
    bcs @nextc
    ldx zy
    jsr set_sprite
    ldy zy
    lda zv
    clc
    adc crawl_blk,y
    sta p_ptr,y
@nextc:
    ldy zy
    iny
    cpy #3
    bne @c
    rts
@one:
    lda ppy
    sta zl
    lda zf
    sta zt
    lda zm
    jsr sprite_pos
    bcs @r
    ldx #0
    jsr set_sprite
    lda zv
    sta p_ptr
    lda zk
    clc
    adc #21
    sta p_sy + 1
    lda zs
    sta p_sx + 1
    lda zt
    beq :+
    lda p_msb
    ora #2
    sta p_msb
:   lda p_en
    ora #2
    sta p_en
    lda zv
    clc
    adc #1
    sta p_ptr + 1
@r: rts

crawl_dx:   .byte 0, 24, 48
crawl_blk:  .byte 0, 1, 2

; the blasters: sprites 3 - 7
blaster_sprites:
    ldx #0
    lda #3
    sta zr
@b: stx zx
    lda bl_ttl,x
    cmp #$fe
    bcs @next
    lda zr
    cmp #8
    bcs @next
    lda bl_c,x
    sta zm
    lda #0
    sta zt
    asl zm
    rol zt
    asl zm
    rol zt
    asl zm
    rol zt
    lda bl_l,x
    sec
    sbc #1
    sta zl
    lda zm
    jsr sprite_pos
    bcs @next
    ldx zr
    jsr set_sprite
    lda #SPR_BULLET
    sta p_ptr,x
    inc zr
@next:
    ldx zx
    inx
    cpx #6
    bne @b
    rts

; make the matrix the window needs: one step at a time (a cell to the side, or a row), into the matrix not shown
matrix_update:
    lda cur_w
    cmp t_w
    beq @samew
    lda t_w
    sec
    sbc cur_w
    cmp #1
    bne :+
    jmp @left
:   cmp #$ff
    bne :+
    jmp @right
:   lda t_w                     ; a jump: all of it
    sta cur_w
    lda cur_buf
    eor #1
    sta cur_buf
    beq :+
    lda #>MAT_B
    jmp @full
:   lda #>MAT_A
@full:
    jsr draw_full
    jmp @shown
@samew:
    lda cur_cam
    cmp want_cam
    bne :+
    jmp @shown
:   bcc :+
    jmp @rowup
:   jmp @rowdown
@left:                          ; the window moves a cell right: the picture one cell left
    inc cur_w
    lda cur_buf
    beq :+
    jmp @left_b
:   SHIFT MAT_B, MAT_A + 1, 15
    jsr col_setup_right
    ldy zd
    NEWCOL MAT_B, 39
    jmp @swap
@left_b:
    SHIFT MAT_A, MAT_B + 1, 15
    jsr col_setup_right
    ldy zd
    NEWCOL MAT_A, 39
    jmp @swap
@right:
    dec cur_w
    lda cur_buf
    beq :+
    jmp @right_b
:   SHIFT MAT_B + 1, MAT_A, 15
    jsr col_setup_left
    ldy zd
    NEWCOL MAT_B, 0
    jmp @swap
@right_b:
    SHIFT MAT_A + 1, MAT_B, 15
    jsr col_setup_left
    ldy zd
    NEWCOL MAT_A, 0
    jmp @swap
@rowup:                         ; the camera moves up: the picture down a row
    dec cur_cam
    lda cur_buf
    beq :+
    jmp @rowup_b
:   SHIFT MAT_B + 40, MAT_A, 12
    lda #>MAT_B
    jmp @toprow
@rowup_b:
    SHIFT MAT_A + 40, MAT_B, 12
    lda #>MAT_A
@toprow:
    sta p5 + 1
    lda #0
    sta p5
    lda cur_w
    sta p4
    lda cur_cam
    clc
    adc rows_page
    sta p4 + 1
    jsr copy_row
    jmp @swap
@rowdown:
    inc cur_cam
    lda cur_buf
    beq :+
    jmp @rowdown_b
:   SHIFT MAT_B, MAT_A + 40, 15
    lda #>MAT_B
    jmp @botrow
@rowdown_b:
    SHIFT MAT_A, MAT_B + 40, 15
    lda #>MAT_A
@botrow:
    clc
    adc #>(24 * 40)             ; the last row: 24 * 40 = $3c0
    sta p5 + 1
    lda #<(24 * 40)
    sta p5
    lda cur_w
    sta p4
    lda cur_cam
    clc
    adc #24
    clc
    adc rows_page
    sta p4 + 1
    jsr copy_row
@swap:
    lda cur_buf
    eor #1
    sta cur_buf
@shown:
    ldx cur_buf
    lda cur_w
    sta mat_w,x
    lda cur_cam
    sta mat_c,x
    cpx #0
    bne :+
    lda #D018_A
    bne :++
:   lda #D018_B
:   sta p_d018
    rts
