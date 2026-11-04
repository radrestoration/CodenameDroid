; ---- the lift's ride between levels: the BBC scrolls the screen a row at a time (32 rows) with the cabin and the player fixed while
; the old level leaves and the new one comes in. Here the 40 columns at the lift's end of both levels are made into one character
; set (the old level's cells from its own characters, the new level's from its tiles), kept as two slabs of 32 rows, and the
; matrix is made a frame at a time from a window of 25 rows sliding down or up the pair; the cabin's cells are put over it at
; the same place on the screen. The ride and game share bank 3's matrices; the ride charset is kept at $d000 while the next
; level's charset is staged at $d800 and ROWS is rebuilt at $a000-$bfff.

.segment "BSS"
rw0:        .res 1              ; the first column of the slab: 216 at the right end, 0 at the left
rtc0:       .res 1              ; its first tile column
rlc:        .res 1              ; the lift's tile column
rcam:       .res 1
rstep:      .res 1
rt:         .res 1              ; the strip row at the top of the screen
rbuf:       .res 1
rpg:        .res 1              ; high byte of the matrix being made
sa_lo:      .res 1              ; the first slab of the strip, the second
sa_hi:      .res 1
sb_lo:      .res 1
sb_hi:      .res 1
tcc:        .res 1
tcy:        .res 1
rtr:        .res 1
lift_screen: .res 1
lift_slot:  .res 1
lms_slot:   .res 1
lift_sprite_index: .res 1
.segment "CODE"

SLABO       = $fa80             ; the old level's slab (renumbered characters)
SLABN       = $b800             ; the new level's
TMPB        = $b000             ; (both in ROWS, which is made again afterwards)
MAPC        = $0500             ; old character -> character of the ride's set
cabin_nib:  .byte 2, 0, 1, 3

lift_ride_scroll:
    ; the lift's cell in this level go: the old cabin would ride away with the level (in the map only: the screen still shows the cabin until the ride's first frame)
    lda #1
    sta lift_screen
    lda init_px
    bmi :+
    lda #1
    jmp :++
:   lda #62
:   sta rlc
    lda #2
    sta rtr
@c: ldx rlc
    ldy rtr
    lda #3
    jsr replot_tile
    inc rtr
    lda rtr
    cmp #6
    bne @c
    lda #$ff
    ldx #5
:   sta bl_ttl,x
    dex
    bpl :-
    lda init_px
    bmi @right
    lda #0
    sta rw0
    sta rtc0
    jmp @go
@right:
    lda #216
    sta rw0
    lda #54
    sta rtc0
@go:
    lda cur_cam
    sta rcam
    ; the old slab: 32 rows of 40 cells from column rw0
    lda #<SLABO
    sta p2
    lda #>SLABO
    sta p2 + 1
    lda #0
    sta zr
@r: lda rw0
    sta p1
    lda zr
    clc
    adc rows_page
    sta p1 + 1
    ldy #39
:   lda (p1),y
    sta (p2),y
    dey
    bpl :-
    lda p2
    clc
    adc #40
    sta p2
    bcc :+
    inc p2 + 1
:   inc zr
    lda zr
    cmp #32
    bne @r
    ; the old level's characters' bytes
    lda #<BPAT
    sta p1
    lda #>BPAT
    sta p1 + 1
    lda #<TMPB
    sta p2
    lda #>TMPB
    sta p2 + 1
    ldx #8
    ldy #0
:   lda (p1),y
    sta (p2),y
    iny
    bne :-
    inc p1 + 1
    inc p2 + 1
    dex
    bne :-
    ; the ride's character set: the old slab's cells
    lda #1
    sta lift_screen
    sei
    jsr make_sprites
    lda #0
    sta $d015                   ; no sprites while the ride's set overwrites the old sprite blocks
    jsr lift_make_sprites
    sei
    lda #$34
    sta $01
    jsr intern_reset
    lda #>RIDE_CHARSET
    sta charset_page
    ldx #7
    lda #0
:   sta RIDE_CHARSET,x          ; the blank character (the area held the sprite blocks)
    dex
    bpl :-
    jsr install_mine_chars
    ldx #0
    lda #0
:   sta MAPC,x
    inx
    bne :-
    lda #<SLABO
    sta p3
    lda #>SLABO
    sta p3 + 1
    lda #5
    sta zr                      ; pages (1280 bytes = 5)
    ldy #0
@m: lda (p3),y
    beq @put
    tax
    lda MAPC,x
    bne @put
    sty tcy
    stx tcc
    lda TMPB,x
    sta cb
    lda TMPB + $100,x
    sta cb + 1
    lda TMPB + $200,x
    sta cb + 2
    lda TMPB + $300,x
    sta cb + 3
    lda TMPB + $400,x
    sta cb + 4
    lda TMPB + $500,x
    sta cb + 5
    lda TMPB + $600,x
    sta cb + 6
    lda TMPB + $700,x
    sta cb + 7
    jsr intern
    ldx tcc
    sta MAPC,x
    ldy tcy
@put:
    sta (p3),y
    iny
    bne @m
    inc p3 + 1
    dec zr
    bne @m
    ; the new level's slab: the grids of the nibbles in its ten tile columns (and the cabin's)
    lda newlvl
    sta level
    lda #0
    sta tgmask
    sta tgmask + 1
    lda #$0f                    ; nibbles 0 - 3
    sta tgmask
    lda newlvl
    clc
    adc #>LTILES
    sta p3 + 1
    lda rtc0
    asl
    asl
    sta p3
    ldx #40
    ldy #0
@n: lda (p3),y
    pha
    and #$0f
    jsr mask_nibble
    pla
    lsr
    lsr
    lsr
    lsr
    jsr mask_nibble
    iny
    dex
    bne @n
    jsr build_tg
    jsr fill_slabn
    ; the ride
    lda #$35
    sta $01
    cli
    lda #0
    sta rstep
    sta rbuf
@frame:
    lda lift_dir
    bne @down
    lda #32
    clc
    adc rcam
    sec
    sbc rstep
    sta rt
    lda #<SLABN
    sta sa_lo
    lda #>SLABN
    sta sa_hi
    lda #<SLABO
    sta sb_lo
    lda #>SLABO
    sta sb_hi
    jmp @made
@down:
    lda rcam
    clc
    adc rstep
    sta rt
    lda #<SLABO
    sta sa_lo
    lda #>SLABO
    sta sa_hi
    lda #<SLABN
    sta sb_lo
    lda #>SLABN
    sta sb_hi
@made:
    lda cur_buf
    eor #1
    sta rbuf
    beq :+
    lda #>RIDE_MAT_B
    jmp :++
:   lda #>RIDE_MAT_A
:   sta rpg
    sta p5 + 1
    lda #0
    sta p5
    sta zk                      ; screen row
@row:
    lda rt
    clc
    adc zk
    cmp #32
    bcs @second
    ldx sa_lo
    stx p4
    ldx sa_hi
    stx p4 + 1
    jmp @addr
@second:
    sec
    sbc #32
    ldx sb_lo
    stx p4
    ldx sb_hi
    stx p4 + 1
@addr:
    tax
    lda p4
    clc
    adc mul40_lo,x
    sta p4
    lda p4 + 1
    adc mul40_hi,x
    sta p4 + 1
    ldy #39
:   lda (p4),y
    sta (p5),y
    dey
    bpl :-
    lda p5
    clc
    adc #40
    sta p5
    bcc :+
    inc p5 + 1
:   inc zk
    lda zk
    cmp #25
    bne @row
    jsr stamp_cabin
    sei                         ; the interrupt must not see make_sprites' pointers with the ride's base
    jsr make_sprites
    jsr blank_under_player
    jsr lift_make_sprites
    lda rbuf
    sta cur_buf
    beq :+
    lda #RIDE_D018_B
    jmp :++
:   lda #RIDE_D018_A
:   sta p_d018
    lda #$10
    ora t_xs
    sta p_d016
    lda rstep
    bne :+
    lda p_dd00
    and #$fc
    sta p_dd00
    lda #1
    sta lift_screen
:   lda #1
    sta ready
:   lda ready
    bne :-
    inc rstep                   ; (two rows a frame: a frame is not long enough to make the matrix twice)
    inc rstep
    lda rstep
    cmp #34
    beq :+
    jmp @frame
:   rts

; the BBC draws the player over a black box: a sprite lets the chain show through its blank pixels, so the cells behind it (3 x 4) are blanked in the ride's matrix
blank_under_player:
    lda p_en
    and #1
    beq @r
    lda p_sy
    sec
    sbc #50
    bcc @r
    lsr
    lsr
    lsr
    cmp #22
    bcs @r
    tax
    lda mul40_lo,x
    sta p4
    lda mul40_hi,x
    clc
    adc rpg
    sta p4 + 1
    lda p_sx
    sec
    sbc #24
    sta zt
    lda p_msb
    and #1
    sbc #0
    sta zs
    lda zt
    sec
    sbc t_xs
    sta zt
    lda zs
    sbc #0
    bmi @r
    sta zs
    lda zt
    lsr zs
    ror
    lsr zs
    ror
    lsr zs
    ror
    cmp #38
    bcs @r
    clc
    adc p4
    sta p4
    bcc :+
    inc p4 + 1
:   ldx #4
@row:
    ldy #2
    lda #0
:   sta (p4),y
    dey
    bpl :-
    lda p4
    clc
    adc #40
    sta p4
    bcc :+
    inc p4 + 1
:   dex
    bne @row
@r: rts

lift_make_sprites:
    sei
    lda #$34
    sta $01
    ldx #0
@slot:
    stx lms_slot
    lda p_ptr,x
    sta lift_sprite_index
    and #3
    asl
    asl
    asl
    asl
    asl
    asl
    sta p1
    lda lift_sprite_index
    lsr
    lsr
    sta p1 + 1
    clc
    lda p1
    adc #<sprite_blocks
    sta p1
    lda p1 + 1
    adc #>sprite_blocks
    sta p1 + 1
    ldx lms_slot
    lda ride_sprite_lo,x
    sta p2
    lda ride_sprite_hi,x
    sta p2 + 1
    ldy #0
    ldx #64
@copy:
    lda (p1),y
    sta (p2),y
    iny
    dex
    bne @copy
    ldx lms_slot
    lda ride_sprite_ptr,x
    sta p_ptr,x
    inx
    cpx #3
    bne @slot
    lda #0
    sta p_spr_base
    lda p_en
    and #7                      ; only the three copied sprites exist during the ride
    sta p_en
    ldx #7
:   lda p_ptr,x                 ; the interrupt only refreshes these once a ride frame is ready: until then the old view
    sta MAT_A + $3f8,x          ; would keep pointing at blocks the ride's charset has replaced
    sta MAT_B + $3f8,x
    dex
    bpl :-
    lda #$35
    sta $01
    lda p_en
    sta $d015
    cli
    rts

ride_sprite_lo: .byte $80, $c0, $00
ride_sprite_hi: .byte $de, $de, $df
ride_sprite_ptr: .byte $7a, $7b, $7c

lift_finish_view:
    ; Restore the new level's charset from staging while the ride charset is still displayed.
    sei
    lda #$34
    sta $01
    lda #<STAGE_CHARSET
    sta p1
    lda #>STAGE_CHARSET
    sta p1 + 1
    lda #<CHARSET
    sta p2
    lda #>CHARSET
    sta p2 + 1
    ldx #8
    ldy #0
@charset:
    lda (p1),y
    sta (p2),y
    iny
    bne @charset
    inc p1 + 1
    inc p2 + 1
    dex
    bne @charset
    lda #$35
    sta $01
    cli
    lda #>CHARSET               ; the enemies' characters go to the live set from here
    sta charset_page

    lda level
    jsr start_for_level
    lda rcam                    ; the ride ends on the rows it was showing: the camera stays
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

    lda cur_buf
    eor #1
    sta lift_slot
    beq @draw_a
    lda #>MAT_B
    jsr draw_full
    lda #D018_B
    bne @switch
@draw_a:
    lda #>MAT_A
    jsr draw_full
    lda #D018_A
@switch:
    sta p_d018
    lda #$10
    ora t_xs
    sta p_d016
    jsr make_sprites            ; the player stays on the screen through the handoff, from the copies the ride made
    jsr lift_make_sprites       ; (the game's blocks come back over the ride's charset only after the display has changed)
    lda lift_slot
    sta cur_buf
    lda #1
    sta ready
@wait:
    lda ready
    bne @wait

    sei
    jsr copy_sprites
    cli
    lda #SPRBASE
    sta p_spr_base
    jsr make_sprites
    lda #1
    sta ready
@wait_sprites:
    lda ready
    bne @wait_sprites

    lda lift_slot
    beq @draw_b
    lda #>MAT_A
    jsr draw_full
    jmp @done
@draw_b:
    lda #>MAT_B
    jsr draw_full
@done:
    lda #0
    sta lift_screen
    rts


; mask_nibble: A the nibble: its bit in tgmask
mask_nibble:
    stx zx
    pha
    and #7
    tax
    lda bit2,x
    sta zt
    pla
    cmp #8
    bcs @hi
    lda zt
    ora tgmask
    sta tgmask
    jmp @r
@hi:
    lda zt
    ora tgmask + 1
    sta tgmask + 1
@r: ldx zx
    rts

; the new level's slab from TG: tile columns rtc0 + 0 - 9, 8 rows
fill_slabn:
    lda #0
    sta zr                      ; tile column
@tc:
    lda newlvl
    clc
    adc #>LTILES
    sta p3 + 1
    lda rtc0
    clc
    adc zr
    asl
    asl
    sta p3
    lda #0
    sta rtr                     ; tile row
@tr:
    lda rtr
    lsr
    tay
    lda (p3),y
    ldx rtr
    stx zs
    lda rtr
    and #1
    beq :+
    lda (p3),y
    lsr
    lsr
    lsr
    lsr
    jmp :++
:   lda (p3),y
    and #$0f
:   asl
    asl
    asl
    asl
    sta zt                      ; TG offset
    lda rtr
    asl
    asl
    tax                         ; first cell row
    lda mul40_lo,x
    clc
    adc #<SLABN
    sta p4
    lda mul40_hi,x
    adc #>SLABN
    sta p4 + 1
    lda zr
    asl
    asl
    clc
    adc p4
    sta p4
    bcc :+
    inc p4 + 1
:   lda #4
    sta zk
    ldx zt
@cr:
    ldy #0
:   lda TG,x
    sta (p4),y
    inx
    iny
    cpy #4
    bne :-
    lda p4
    clc
    adc #40
    sta p4
    bcc :+
    inc p4 + 1
:   dec zk
    bne @cr
    inc rtr
    lda rtr
    cmp #8
    beq :+
    jmp @tr
:   inc zr
    lda zr
    cmp #10
    beq :+
    jmp @tc
:   rts

; the cabin: tile rows 2 - 5 of the lift's column, at the same place on the screen all the way
stamp_cabin:
    lda #0
    sta rtr
@tr:
    ldx rtr
    lda cabin_nib,x
    asl
    asl
    asl
    asl
    sta zt                      ; TG offset
    lda #0
    sta zs                      ; cell row in the tile
@r: lda rtr
    clc
    adc #2
    asl
    asl
    clc
    adc zs
    sec
    sbc rcam
    bcc @next
    cmp #25
    bcs @next
    tax
    lda rpg
    clc
    adc #0
    sta p4 + 1
    lda #0
    sta p4
    lda mul40_lo,x
    clc
    adc p4
    sta p4
    lda mul40_hi,x
    adc p4 + 1
    sta p4 + 1
    ; the column: rlc * 4 - rw0
    lda rlc
    asl
    asl
    sec
    sbc rw0
    clc
    adc p4
    sta p4
    bcc :+
    inc p4 + 1
:   lda zs
    asl
    asl
    clc
    adc zt
    tax                         ; TG index of the row
    ldy #0
:   lda TG,x
    sta (p4),y
    inx
    iny
    cpy #4
    bne :-
@next:
    inc zs
    lda zs
    cmp #4
    bne @r
    inc rtr
    lda rtr
    cmp #4
    bne @tr
    rts
