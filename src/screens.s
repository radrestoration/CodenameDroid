; ---- the screens that are not the play: the wrist terminal, the map, the jet pack computer, game over. They are made of characters
; like the level: the screen is ROWS (a backdrop of tiles as level 12), text from the BBC's font (a character for each glyph, shared),
; and the BBC's sprites placed with the cells under them composited. BBC coordinates are used as they are: cell column x + scr_col0,
; line y; the matrix shows rows 3 - 27 (25 of the BBC's 32).

.segment "BSS"
scr_col0:   .res 1
scr_cam:    .res 1
savelevel:  .res 1
text_x:     .res 1
text_y:     .res 1
tabst:      .res 1
suppress:   .res 1
gcache:     .res 64
wf_row:     .res 40
sh_row:     .res 1
sh_l:       .res 1
sh_n:       .res 1
sh_i:       .res 1
sh_ln:      .res 1
sh_t:       .res 1
sh_ids:     .res 10
bx:         .res 1
by:         .res 1
bw:         .res 1
bh:         .res 1
bcx:        .res 1
br:         .res 1
br1:        .res 1
bl:         .res 1
be:         .res 1
bx0:        .res 1
by0:        .res 1
bcount:     .res 1
mapbase:    .res 1
mapcount:   .res 1
tcount:     .res 1
gk:         .res 1
.segment "CODE"

frame_wait:
    lda tick
:   cmp tick
    beq :-
    rts

; get_key: wait for a key press (after every key has been let go): its number
get_key:
@rel:
    jsr frame_wait
    jsr read_keys
    lda keys
    ora keys + 1
    ora keys + 2
    bne @rel
@wait:
    jsr frame_wait
    jsr read_keys
    lda key1
    beq @wait
    rts

; wait_frames_keys: A frames of nothing
; (wait_frames is in events.s)

; ---- starting and ending a screen
scr_begin:
    lda #3
    sta scr_cam
    lda #12
scr_begin_level:
    pha
    lda level
    sta savelevel
    pla
    sta level
    jsr screen_off
    jsr load_level
    lda level
    cmp #12
    bne :+
    jsr widen_frame
:   jsr pool_configure
    lda #4
    sta scr_col0
    jsr scr_reset_text
    jmp scr_view

; widen_frame: the terminal frame's interior is 32 columns instead of 24: the outer squares and the corner pieces are
; kept at each side and the middle is the interior's own cells repeated (the bars are squares 4 cells wide, the rest blank)
widen_frame:
    ; 24 rows high as well: the third and fourth square rows are left out (rows 24 - 27 move up to 16 - 19, the bar to 20 - 23),
    ; and what is under them is blank
    lda #16
    sta zr
@v: lda zr
    clc
    adc rows_page
    sta p2 + 1
    adc #8
    sta p1 + 1
    lda #0
    sta p1
    sta p2
    ldy #39
:   lda (p1),y
    sta (p2),y
    dey
    bpl :-
    inc zr
    lda zr
    cmp #24
    bne @v
@z: lda zr
    clc
    adc rows_page
    sta p2 + 1
    ldy #39
    lda #0
:   sta (p2),y
    dey
    bpl :-
    inc zr
    lda zr
    cmp #32
    bne @z
    lda #0
    sta scr_cam
    sta zr
@r: lda zr
    clc
    adc rows_page
    sta p2 + 1
    lda #0
    sta p2
    ldy #39
:   lda (p2),y
    sta wf_row,y
    dey
    bpl :-
    ldy #39
@c: cpy #8
    bcc @left
    cpy #32
    bcs @right
    tya
    and #3
    ora #16
    bne @get
@left:
    tya
    clc
    adc #4
    bne @get
@right:
    tya
    sec
    sbc #4
@get:
    tax
    lda wf_row,x
    sta (p2),y
    dey
    bpl @c
    inc zr
    lda zr
    cmp #24
    bne @r
    rts

scr_reset_text:
    ldx #63
    lda #0
:   sta gcache,x
    dex
    bpl :-
    rts

; the view of the screen: window 0, rows 3 - 27
scr_view:
    lda #0
    sta t_w
    sta cur_w
    sta mat_w
    sta mat_w + 1
    sta cur_buf
    lda scr_cam
    sta cur_cam
    sta mat_c
    sta mat_c + 1
    lda #>MAT_A
    jsr draw_full
    lda #>MAT_B
    jsr draw_full
    rts

; scr_clear: nothing on the screen but blank cells
scr_clear:
    lda #3
    sta scr_cam
    lda rows_page
    sta p2 + 1
    lda #0
    sta p2
    ldx #32
:   ldy #39
    lda #0
:   sta (p2),y
    dey
    bpl :-
    inc p2 + 1
    dex
    bne :--
    jmp scr_view

; scr_show: the screen is complete
scr_show:
    lda #0
    sta p_en
    sta p_msb
    sta p_xexp
    lda #D018_A
    sta p_d018
    lda #$10
    sta p_d016
    lda #1
    sta ready
    jsr screen_on
    jsr frame_wait
    jmp frame_wait

; scr_end: back to the level
scr_end:
    jsr screen_off
    lda savelevel
    sta level
    jsr load_level
    jsr pool_configure
    jsr reset_pool_and_mines
    jsr calc_scroll
    lda t_w
    sta cur_w
    sta mat_w
    sta mat_w + 1
    lda want_cam
    sta cur_cam
    sta mat_c
    sta mat_c + 1
    lda #0
    sta cur_buf
    lda #>MAT_A
    jsr draw_full
    lda #>MAT_B
    jsr draw_full
    lda #D018_A
    sta p_d018
    lda #$10
    ora t_xs
    sta p_d016
    lda #0
    sta p_en
    sta p_msb
    lda #1
    sta ready
    jsr screen_on
    jsr frame_wait
    jmp frame_wait

reset_pool_and_mines:
    ldx #9
    lda #$ff
:   sta pool_owner,x
    sta pg_col,x
    sta pg_img,x
    dex
    bpl :-
    ldx #0
@m: lda mines_state,x
    bpl @n
    stx zx
    lda mines_x,x
    sta zs
    lda mines_y,x
    lsr
    lsr
    lsr
    tay
    ldx zs
    lda #CH_MINE
    jsr put_cell
    ldx zx
@n: inx
    cpx #6
    bne @m
    rts

; ---- text
; glyph character for A (ASCII 0 - Z): made once
glyph_char:
    sec
    sbc #$30
    cmp #43
    bcc :+
    lda #0
    rts
:   tay
    lda gcache,y
    beq :+
    rts
:   sty gk
    lda font_offsets,y
    tax
    ldy #0
:   lda font_glyphs,x
    sta cb,y
    inx
    iny
    cpy #5
    bne :-
    lda #0
    sta cb + 5
    sta cb + 6
    sta cb + 7
    jsr intern
    ldy gk
    sta gcache,y
    rts

; shift_extra_cells: the EXTRA CELLS label and the cell's picture, one pixel (two screen pixels) left
shift_extra_cells:
    lda #26
    sta sh_l
    lda #6
    sta sh_n
    lda #11
    sta sh_row
    jsr shift_left2
    inc sh_row
    jsr shift_left2
    lda #4
    sta sh_n
    inc sh_row
    jmp shift_left2

; shift_left2: the cells sh_l .. sh_l + sh_n - 1 of row sh_row move one pixel (two screen pixels) left (text_x columns; the cell after the last is taken as blank)
shift_left2:
    ldx #0
@rd:
    stx sh_i
    txa
    clc
    adc sh_l
    clc
    adc scr_col0
    tax
    ldy sh_row
    jsr get_cell
    ldx sh_i
    sta sh_ids,x
    inx
    cpx sh_n
    bne @rd
    lda #0
    sta sh_ids,x
    lda #0
    sta sh_i
@cell:
    lda #0
    sta sh_ln
@line:
    lda #>BPAT
    clc
    adc sh_ln
    sta p1 + 1
    lda #0
    sta p1
    ldx sh_i
    ldy sh_ids,x
    lda (p1),y
    asl
    and #$ee
    sta sh_t
    ldy sh_ids + 1,x
    lda (p1),y
    lsr
    lsr
    lsr
    and #$11
    ora sh_t
    ldy sh_ln
    sta cb,y
    inc sh_ln
    lda sh_ln
    cmp #8
    bne @line
    jsr intern
    pha
    lda sh_i
    clc
    adc sh_l
    clc
    adc scr_col0
    tax
    ldy sh_row
    pla
    jsr put_cell
    inc sh_i
    lda sh_i
    cmp sh_n
    bne @cell
    rts

; plot_life_digit: the digit A two lines lower than the cell's usual place (clear of the face above it)
plot_life_digit:
    sec
    sbc #$30
    tay
    lda font_offsets,y
    sta sh_t
    lda #0
    sta sh_i
    sta cb
    sta cb + 1
    sta cb + 7
@cell:
    lda #0
    sta sh_ln
    ldx sh_t
@line:
    lda font_glyphs,x
    ldy sh_i
    bne @right
    lsr                         ; the glyph straddles two cells, centred on their join
    lsr
    jmp @s
@right:
    asl
    asl
    and #$0f
@s: ldy sh_ln
    sta cb + 2,y
    inx
    inc sh_ln
    cpy #4
    bne @line
    jsr intern
    pha
    lda text_x
    clc
    adc sh_i
    adc scr_col0
    tax
    ldy text_y
    pla
    jsr put_cell
    inc sh_i
    lda sh_i
    cmp #2
    bne @cell
    rts

; put_glyph: ASCII A at the text cursor
put_glyph:
    cmp #$20
    bne :+
    lda #0
    jmp @put
:   jsr glyph_char
@put:
    pha
    lda text_x
    clc
    adc scr_col0
    tax
    ldy text_y
    pla
    jsr put_cell
    inc text_x
    rts

; tab_to: the cursor to X, Y
tab_to:
    stx text_x
    sty text_y
    rts

; print_text: p4 the BBC's text (with TAB sequences $1f x y), A its length
print_text:
    sta tcount
    lda #0
    sta tabst
    ldy #0
@l: sty zk
    lda (p4),y
    ldx tabst
    bne @coord
    cmp #$1f
    bne @ch
    lda #2
    sta tabst
    jmp @next
@ch:
    jsr put_glyph
    jmp @next
@coord:
    cpx #2
    bne @y
    sta text_x
    lda #1
    sta tabst
    jmp @next
@y: sta text_y
    lda #0
    sta tabst
@next:
    ldy zk
    iny
    cpy tcount
    bne @l
    rts

; print_ptr: p4 text, A length, with the pointer set by the caller from a label
.macro PRINT plabel, plen
    lda #<plabel
    sta p4
    lda #>plabel
    sta p4 + 1
    lda #plen
    jsr print_text
.endmacro

plot_digit_a:
    clc
    adc #$30
    jmp put_glyph

plot_score:
    ldx #0
    stx suppress
@l: lda score,x
    bne @dig
    cpx #7
    beq @dig
    ldy suppress
    bne @plot
    jmp @next
@dig:
    ldy #1
    sty suppress
@plot:
    stx zx
    clc
    adc #$30
    jsr put_glyph
    ldx zx
@next:
    inx
    cpx #8
    bne @l
    rts

; the name token for A in the '!'-separated list at p4's table (the A-th, 1 on)
; plot_level_name: the group of the level (3 levels each)
plot_level_name:
    lda savelevel
    ldx #0
:   cmp #3
    bcc :+
    sbc #3
    inx
    jmp :-
:   inx
    ldy #0
@f: lda level_names,y
    iny
    cmp #$21
    bne @f
    dex
    bne @f
@p: lda level_names,y
    cmp #$21
    beq @done
    sty zk
    jsr put_glyph
    ldy zk
    iny
    jmp @p
@done:
    rts

plot_sector_number:
    lda savelevel
:   cmp #3
    bcc :+
    sbc #3
    jmp :-
:   clc
    adc #1
    jmp plot_digit_a

; ---- sprites: blit the column-major image at p3 (bw columns of bh lines) to cell column bx (+ scr_col0 is added by the caller)
; and line by, over what is there
blit:
    lda #0
    sta bcx
@col:
    lda by
    lsr
    lsr
    lsr
    sta br
    lda by
    clc
    adc bh
    sec
    sbc #1
    lsr
    lsr
    lsr
    sta br1
@row:
    lda bx
    clc
    adc bcx
    tax
    ldy br
    jsr cell_to_cb
    lda #0
    sta bl                      ; line in the cell
@line:
    lda br
    asl
    asl
    asl
    clc
    adc bl
    sec
    sbc by
    bcc @skip
    cmp bh
    bcs @skip
    tay
    lda (p3),y
    ldx bl
    sta cb,x
@skip:
    inc bl
    lda bl
    cmp #8
    bne @line
    jsr intern
    pha
    lda bx
    clc
    adc bcx
    tax
    ldy br
    pla
    jsr put_cell
    inc br
    lda br
    cmp br1
    beq @row
    bcc @row
    ; next column of the image
    lda p3
    clc
    adc bh
    sta p3
    bcc :+
    inc p3 + 1
:   inc bcx
    lda bcx
    cmp bw
    beq :+
    jmp @col
:   rts

; blit_at: p3 the image, A its columns, X its lines; text-cursor style place: column in text_x (BBC x), line in Y
blit_at:
    sta bw
    stx bh
    sty by
    lda text_x
    clc
    adc scr_col0
    sta bx
    jmp blit

.macro IMAGE ilabel, iw, ih, ix, iy
    lda #<ilabel
    sta p3
    lda #>ilabel
    sta p3 + 1
    lda #ix
    sta text_x
    lda #iw
    ldx #ih
    ldy #iy
    jsr blit_at
.endmacro

; ---- the energy bars: A the sections (energy / 2), X the column, Y the line
plot_energy_bar:
    sta be
    stx bx0
    sty by0
    lda #20
    sta bcount
@l: lda bcount
    cmp #20
    bne :+
    lda #<spr_bar_left
    ldx #>spr_bar_left
    jmp @draw
:   cmp #1
    bne :+
    lda #<spr_bar_right
    ldx #>spr_bar_right
    jmp @draw
:   lda be
    beq @empty
    dec be
    lda #<spr_bar_full
    ldx #>spr_bar_full
    jmp @draw
@empty:
    lda #<spr_bar_empty
    ldx #>spr_bar_empty
@draw:
    sta p3
    stx p3 + 1
    lda bx0
    sta text_x
    lda #1
    ldx #10
    ldy by0
    jsr blit_at
    inc bx0
    dec bcount
    bne @l
    rts

plot_status:
    ldx #5
    ldy #13
    jsr tab_to
    lda carried
    jsr plot_digit_a
    ldx #30
    ldy #13
    jsr tab_to
    lda #0
    jsr put_glyph
    lda carried + 1
    jsr plot_digit_a
    lda #13
    sta sh_row
    lda #30
    sta sh_l
    lda #2
    sta sh_n
    jsr shift_left2
    lda suit_energy
    lsr
    ldx #6
    ldy #96
    jsr plot_energy_bar
    lda blaster_energy
    lsr
    ldx #6
    ldy #120
    jmp plot_energy_bar

; ---- the wrist terminal
wrist_terminal:
    jsr snd_flushall
    jsr scr_begin
    IMAGE spr_face, 4, 32, 23, 48
    PRINT text_wrist_w, text_wrist_w_len
    lda nmines
    jsr plot_digit_a
    ldx #$11
    ldy #7
    jsr tab_to
    jsr plot_sector_number
    IMAGE spr_passcard, 3, 8, 1, 104
    IMAGE spr_cell, 3, 8, 27, 104
    ldx #$18
    ldy #10
    jsr tab_to
    lda lives
    clc
    adc #$30
    jsr plot_life_digit
    jsr plot_status
    jsr shift_extra_cells
    ldx #$11
    ldy #8
    jsr tab_to
    jsr plot_score
    ldx #7
    ldy #6
    jsr tab_to
    jsr plot_level_name
    jsr scr_show
    jsr sfx_chime
@loop:
    jsr plot_status
    jsr get_key
    cmp #K_S
    beq @charge
    cmp #K_B
    beq @charge
    cmp #K_M
    bne @nm
    pha
    jsr map_screen
    pla
    bcc @loop
    jmp @rebuild
@nm:
    cmp #K_SPACE
    bne @loop
    jmp scr_end
@rebuild:
    jmp wrist_terminal_again
@charge:
    pha
    lda carried + 1
    beq @nocell
    dec carried + 1
    pla
    pha
    ldx #$25
    cmp #K_B
    beq @blaster
    stx suit_energy
    jmp @nocell
@blaster:
    stx blaster_energy
@nocell:
    pla
    jmp @loop

; the wrist terminal's text for the 24-row frame: TAB x y, the words (the mines' digit follows)
text_wrist_w:
    .byte $1f, 8, 5, "WRIST TERMINAL"
    .byte $1f, 10, 7, "SECTOR"
    .byte $1f, 10, 8, "SCORE"
    .byte $1f, 10, 11, "SUIT ENERGY"
    .byte $1f, 8, 14, "BLASTER ENERGY"
    .byte $1f, 1, 11, "PASS"
    .byte $1f, 1, 12, "CARD"
    .byte $1f, 27, 11, "EXTRA"
    .byte $1f, 27, 12, "CELLS"
    .byte $1f, 8, 19, "PRESS M FOR MAPS"
    .byte $1f, 10, 9, "MINES  "
text_wrist_w_len = * - text_wrist_w

; the terminal again after the map: the level is still the saved one
wrist_terminal_again:
    lda savelevel
    sta level
    jmp wrist_terminal

; ---- the screen of a message: "NOT AVAILABLE" for a while
not_available_screen:
    jsr scr_clear
    ldx #9
    ldy #$0e
    jsr tab_to
    PRINT text_na, $10
    jsr scr_show
    lda #35
    jmp wait_frames

; ---- the microfilm map
map_screen:
    lda carried + $c
    beq @na
    lda savelevel
    beq @na
    cmp #$0b
    bne @map
@na:
    jsr not_available_screen
    sec                         ; (the caller shows the terminal again)
    rts
@map:
    jsr scr_clear
    ldx #8
    ldy #$14
    jsr tab_to
    jsr plot_level_name
    PRINT text_map, $40
    jsr plot_sector_number
    lda px
    and #$80
    sta mapbase
@draw:
    jsr draw_map
    jsr scr_show
@key:
    jsr get_key
    ldx savelevel
    cpx #7
    beq @space
    cmp #K_LEFT
    bne @nl
    lda mapbase
    beq @key
    lda #0
    sta mapbase
    jmp @draw
@nl:
    cmp #K_RIGHT
    bne @space
    lda mapbase
    bne @key
    lda #$80
    sta mapbase
    jmp @draw
@space:
    cmp #K_SPACE
    bne @key
    sec
    rts

; the half of the level from mapbase (0 or $80): a cell for each tile, 32 columns of 8 rows at screen column 0, row 10
draw_map:
    lda #0
    sta mapcount
@t: ; the tile's nibble: byte mapbase + count / 2
    lda savelevel
    clc
    adc #>LTILES
    sta p3 + 1
    lda mapcount
    lsr
    clc
    adc mapbase
    sta p3
    ldy #0
    lda (p3),y
    sta zv
    lda mapcount
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
    sta zv
    ; an enemy here?
    ldx #0
@e: cpx last_enemy
    bcs @tile
    lda enemies + 1,x
    sta zt
    lda mapcount
    and #7
    cmp zt
    bne @en
    lda mapcount
    lsr
    lsr
    lsr
    sta zt
    lda mapbase
    lsr
    lsr
    clc
    adc zt
    cmp enemies,x
    bne @en
    ; the enemy's cell
    ldx #7
:   lda map_enemy,x
    sta cb,x
    dex
    bpl :-
    jmp @put
@en:
    inx
    inx
    inx
    inx
    inx
    jmp @e
@tile:
    lda savelevel
    asl
    asl
    asl
    asl
    clc
    adc zv
    tax
    lda level_xlat,x
    cmp #$34
    bcc :+
    lda #0
:   sta zt
    lda #0
    sta zs
    lda zt
    asl
    rol zs
    asl
    rol zs
    asl
    rol zs
    clc
    adc #<map_sprites
    sta p3
    lda zs
    adc #>map_sprites
    sta p3 + 1
    ldy #7
:   lda (p3),y
    sta cb,y
    dey
    bpl :-
@put:
    jsr intern
    pha
    lda mapcount
    lsr
    lsr
    lsr
    clc
    adc scr_col0
    tax
    lda mapcount
    and #7
    clc
    adc #10
    tay
    pla
    jsr put_cell
    inc mapcount
    beq @done
    jmp @t
@done:
    rts

; ---- the jet pack computer
jet_pack_screen:
    lda carried + 2
    bne @have
    jsr scr_begin
    jsr not_available_screen
    jmp scr_end
@have:
    jsr snd_flushall
    jsr scr_begin
    PRINT text_jet_w, text_jet_w_len
    lda jp_energy
    lsr
    lsr
    lsr
    lsr
    ldx #6
    ldy #96
    jsr plot_energy_bar
    lda #$1e
    ldx #6
    ldy #128
    jsr plot_energy_bar
    IMAGE spr_jet_f, 3, 32, 8, 48
    IMAGE spr_jet_u, 3, 32, 21, 48
    jsr scr_show
@w: jsr get_key
    cmp #K_SPACE
    bne @w
    jmp scr_end

text_jet_w:
    .byte $1f, 8, 5, "JET PACK COMPUTER"
    .byte $1f, 14, 11, "FUEL"
    .byte $1f, 9, 15, "BLASTER ENERGY"
    .byte $1f, 10, 19, "SPACE TO EXIT"
text_jet_w_len = * - text_jet_w

; ---- game over: a box over the level
game_over:
    jsr snd_flushall
    lda #8
    jsr play_sound_for_damage
    lda #100
    jsr wait_frames
    lda #0                      ; no sprites over the box
    sta p_en
    sta p_msb
    lda #1
    sta ready
@sp: lda ready
    bne @sp
    lda t_w
    clc
    adc #4
    sta scr_col0
    jsr scr_reset_text
    ; the box: cells 8 - 24, rows 7 - 22 (lines 60 - 180)
    lda #0
    sta bcx
@bc:
    lda #7
    sta br
@br:
    lda scr_col0
    clc
    adc #8
    clc
    adc bcx
    tax
    ldy br
    jsr cell_to_cb
    ldx #0
@bl:
    ; the line: br * 8 + x, in 60 - 180?
    lda br
    asl
    asl
    asl
    stx zs
    clc
    adc zs
    cmp #60
    bcc @keep
    cmp #181
    bcs @keep
    cmp #60
    beq @edge
    cmp #180
    beq @edge
    ldy bcx
    beq @left
    cpy #16
    beq @right
    lda #0
    jmp @set
@left:
    lda #$88
    jmp @set
@right:
    lda #$11
    jmp @set
@edge:
    lda #$ff
@set:
    sta cb,x
@keep:
    ldx zs
    inx
    cpx #8
    bne @bl
    jsr intern
    pha
    lda scr_col0
    clc
    adc #8
    clc
    adc bcx
    tax
    ldy br
    pla
    jsr put_cell
    inc br
    lda br
    cmp #23
    bne @br
    inc bcx
    lda bcx
    cmp #17
    bne @bc
    ; the text
    lda savelevel
    pha
    lda level
    sta savelevel
    PRINT text_gameover, $36
    lda #$20
    jsr put_glyph
    jsr plot_sector_number
    ldx #9
    ldy #$0d
    jsr tab_to
    jsr plot_level_name
    ldx #$10
    ldy #$10
    jsr tab_to
    jsr plot_score
    ldx #$11
    ldy #$12
    jsr tab_to
    ; the rating: the first of the eight limits that the objects collected do not pass
    ldx #0
:   lda ranking_req,x
    inx
    cmp total_objs
    bcc :-
    ; name number X in ranking_names
    ldy #0
@f: lda ranking_names,y
    iny
    cmp #$21
    bne @f
    dex
    bne @f
@p: lda ranking_names,y
    cmp #$21
    beq @pd
    sty zk
    jsr put_glyph
    ldy zk
    iny
    jmp @p
@pd:
    pla
    sta savelevel
    jsr start_game_over_tune
    lda #1
    sta tune_playing
    jsr frame_wait
@w: lda tune_playing
    beq :+
    jsr update_tune
:   jsr frame_wait
    jsr read_keys
    lda #K_SPACE
    jsr is_held
    beq @w
    jsr snd_flushall
restart_game:
    ldx #$ff
    txs
    lda #0
    sta ready
    jsr title_screen
    jsr new_game
    lda title_jump
    beq :+
    jsr jump_to_saved
:   jmp main

game_completed:
    lda #7
    sta scr_cam
    lda #13
    jsr scr_begin_level
    PRINT text_done2, $17
    jsr scr_show
    lda #100
    jsr wait_frames
    lda #$0b
    sta level                   ; (the sector shown on the game over screen)
    jmp game_over

text_done2:
    .byte $1f, 12, 7, "DROID IS", $1f, 12, 8, "COMPLETED"

pause:
    jsr frame_wait
    jsr read_keys
    lda #K_PAUSE
    jsr is_held
    bne pause
:   jsr frame_wait
    jsr read_keys
    lda #K_PAUSE
    jsr is_held
    beq :-
:   jsr frame_wait
    jsr read_keys
    lda #K_PAUSE
    jsr is_held
    bne :-
    rts
