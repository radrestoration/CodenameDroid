; ---- making a level: characters from the BBC's tiles, ROWS from the level's tile map, the objects on top

.segment "BSS"
tgmask:     .res 2
charset_page: .res 1
rows_page:  .res 1
.segment "ZEROPAGE"
mk:         .res 2
tn:         .res 1
tfl:        .res 1
txf:        .res 1
tc:         .res 1
tk:         .res 1
zcb:        .res 1
cb2:        .res 8
.segment "CODE"

; intern: the cell in cb is given a character (the same cell, the same character); A = its number
intern:
    lda cb
    clc
    adc cb + 1
    eor cb + 2
    clc
    adc cb + 3
    eor cb + 4
    clc
    adc cb + 5
    eor cb + 6
    clc
    adc cb + 7
    tax
    ldy HEAD,x
@loop:
    cpy #$ff
    beq @add
    lda cb
    cmp BPAT,y
    bne @next
    lda cb + 1
    cmp BPAT + $100,y
    bne @next
    lda cb + 2
    cmp BPAT + $200,y
    bne @next
    lda cb + 3
    cmp BPAT + $300,y
    bne @next
    lda cb + 4
    cmp BPAT + $400,y
    bne @next
    lda cb + 5
    cmp BPAT + $500,y
    bne @next
    lda cb + 6
    cmp BPAT + $600,y
    bne @next
    lda cb + 7
    cmp BPAT + $700,y
    bne @next
    tya
    rts
@next:
    lda NXT,y
    tay
    jmp @loop
@add:
    ldy nchars
    cpy #MAXCH
    bcc @room
    inc overflow
    lda #0
    rts
@room:
    lda HEAD,x
    sta NXT,y
    tya
    sta HEAD,x
    sty zv
    lda cb
    sta BPAT,y
    lda cb + 1
    sta BPAT + $100,y
    lda cb + 2
    sta BPAT + $200,y
    lda cb + 3
    sta BPAT + $300,y
    lda cb + 4
    sta BPAT + $400,y
    lda cb + 5
    sta BPAT + $500,y
    lda cb + 6
    sta BPAT + $600,y
    lda cb + 7
    sta BPAT + $700,y
    lda #0
    sta p5 + 1
    tya
    asl
    rol p5 + 1
    asl
    rol p5 + 1
    asl
    rol p5 + 1
    sta p5
    lda p5 + 1
    clc
    adc charset_page
    sta p5 + 1
    lda charset_page
    cmp #>STAGE_CHARSET
    bne @write
    sei
    lda #$34
    sta $01
@write:
    ldy #7
:   ldx cb,y
    lda conv_table,x
    sta (p5),y
    dey
    bpl :-
    lda charset_page
    cmp #>STAGE_CHARSET
    bne @done
    lda #$35
    sta $01
    cli
@done:
    inc nchars
    lda zv
    rts

; make_tile_cell: cell row zr of the 32-byte column at p4, flipped by zf (1 vertically, 2 horizontally), into cb
make_tile_cell:
    lda zf
    and #1
    beq @nofv
    lda #3
    sec
    sbc zr
    asl
    asl
    asl
    clc
    adc #7
    sta zs
    lda #$ff
    sta zd
    jmp @go
@nofv:
    lda zr
    asl
    asl
    asl
    sta zs
    lda #1
    sta zd
@go:
    ldx #0
@lp:
    ldy zs
    lda (p4),y
    sta cb,x
    lda zs
    clc
    adc zd
    sta zs
    inx
    cpx #8
    bne @lp
    lda zf
    and #2
    beq @done
    ldx #7
@m: ldy cb,x
    lda mirror_table,y
    sta cb,x
    dex
    bpl @m
@done:
    rts

; the tile grids (TG) of the level's nibbles (and as nibble 16 the chandelier turned the other way, in levels 3 - 5)
.segment "ZEROPAGE"
tsrc:       .res 1
tflip:      .res 1
.segment "CODE"
build_tg:
    lda tgmask
    sta mk
    lda tgmask + 1
    sta mk + 1
    lda #0
    sta tn
    sta tflip
@n: lsr mk + 1
    ror mk
    bcc @skip
    lda tn
    sta tsrc
    jsr build_grid
@skip:
    inc tn
    lda tn
    cmp #16
    bne @n
    lda level
    cmp #3
    bcc @done
    cmp #6
    bcs @done
    lda #8
    sta tsrc
    lda #2
    sta tflip
    jsr build_grid
@done:
    rts

; build_grid: the tile of nibble tsrc (its flags xor tflip) as the 16 characters of grid tn
build_grid:
    lda level
    asl
    asl
    asl
    asl
    clc
    adc tsrc
    tax
    lda level_xlat,x
    tay
    lda tile_flags,y
    eor tflip
    sta tfl
    lda tile_art_index,y
    tax
    lda tile_art_lo,x
    clc
    adc #<tile_art_data
    sta p2
    lda tile_art_hi,x
    adc #>tile_art_data
    sta p2 + 1
    lda #0
    sta txf
@xf:
    lda tfl
    and #3
    sta zf
    lda txf
    cmp #2
    bcc :+
    lda tfl
    and #4
    beq :+
    lda zf
    ora #2
    sta zf
:   lda zf
    and #2
    beq :+
    lda #3
    sec
    sbc txf
    jmp :++
:   lda txf
:   asl
    asl
    asl
    asl
    asl
    clc
    adc p2
    sta p4
    lda p2 + 1
    adc #0
    sta p4 + 1
    lda #0
    sta zr
@r: jsr make_tile_cell
    jsr intern
    pha
    lda tflip
    beq :+
    lda #0                      ; (the other flip is stored apart, at TGALT)
    jmp :++
:   lda tn
    asl
    asl
    asl
    asl
:   sta zt
    lda zr
    asl
    asl
    clc
    adc txf
    clc
    adc zt
    tax
    pla
    ldy tflip
    bne @alt
    sta TG,x
    jmp @stored
@alt:
    sta TGALT,x
@stored:
    inc zr
    lda zr
    cmp #4
    bne @r
    inc txf
    lda txf
    cmp #4
    bne @xf
    rts

; tile_put: nibble A at tile row X, first cell column zcb: its 16 characters into ROWS
tile_put:
    stx zt
    asl
    asl
    asl
    asl
    tax
    lda zt
    asl
    asl
    clc
    adc rows_page
    sta p2 + 1
    lda #0
    sta p2
    ldy zcb
    lda #4
    sta zk
@r: lda TG,x
    sta (p2),y
    inx
    iny
    lda TG,x
    sta (p2),y
    inx
    iny
    lda TG,x
    sta (p2),y
    inx
    iny
    lda TG,x
    sta (p2),y
    inx
    dey
    dey
    dey
    inc p2 + 1
    dec zk
    bne @r
    rts

fill_rows:
    lda level
    clc
    adc #>LTILES
    sta p3 + 1
    lda #0
    sta p3
    sta tc
@col:
    lda tc
    asl
    asl
    sta zcb
    lda #0
    sta tk
@byte:
    lda zcb
    clc
    adc tk
    tay
    lda (p3),y
    sta zm
    and #$0f
    pha
    lda tk
    asl
    tax
    pla
    jsr tile_put
    lda zm
    lsr
    lsr
    lsr
    lsr
    pha
    lda tk
    asl
    tax
    inx
    pla
    jsr tile_put
    inc tk
    lda tk
    cmp #4
    bne @byte
    inc tc
    lda tc
    cmp #64
    bne @col
    rts

; cell_to_cb: the bytes of the character at ROWS row Y, column X into cb
cell_to_cb:
    lda #0
    sta p2
    tya
    clc
    adc rows_page
    sta p2 + 1
    txa
    tay
    lda (p2),y
    tay
    lda BPAT,y
    sta cb
    lda BPAT + $100,y
    sta cb + 1
    lda BPAT + $200,y
    sta cb + 2
    lda BPAT + $300,y
    sta cb + 3
    lda BPAT + $400,y
    sta cb + 4
    lda BPAT + $500,y
    sta cb + 5
    lda BPAT + $600,y
    sta cb + 6
    lda BPAT + $700,y
    sta cb + 7
    rts

; the objects of the level: each one's cells with the object (or, once collected, without it) over the background
.segment "ZEROPAGE"
oi:         .res 1
ox:         .res 1
oy:         .res 1
ow:         .res 1
oh:         .res 1
ocx:        .res 1
ocr:        .res 1
ocr0:       .res 1
ocr1:       .res 1
olo:        .res 1
.segment "CODE"

place_objects:
    lda #0
    sta oi
@obj:
    lda level
    asl
    asl
    clc
    adc oi
    sta zt                      ; object number in the table
    asl
    clc
    adc zt
    tax
    lda level_objects + 1,x
    sta ox
    lda level_objects + 2,x
    sta oy
    lda ox
    cmp #$ff
    bne :+
    jmp @next
:   inc ox                      ; (the BBC draws an object from the column after its x)
    ldx zt
    lda objflags,x
    lsr
    lsr
    lsr
    lsr
    tay                         ; type
    lda objtype_w,y
    sta ow
    lda objtype_h,y
    sta oh
    lda objtype_lo,y
    clc
    adc #<object_data
    sta p3
    lda objtype_hi,y
    adc #>object_data
    sta p3 + 1
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
    lda #0
    sta ocx
@col:
    lda ocr0
    sta ocr
@row:
    lda ox
    clc
    adc ocx
    tax
    ldy ocr
    jsr cell_to_cb
    ldx #7
:   lda cb,x
    sta cb2,x
    dex
    bpl :-
    ; the object's lines in this cell
    lda #0
    sta olo                     ; line in the cell
@line:
    lda ocr
    asl
    asl
    asl
    clc
    adc olo
    sec
    sbc oy                      ; line of the object this is
    bcc @skip
    cmp oh
    bcs @skip
    sta zs
    ; data byte: ocx * oh + line
    lda ocx
    beq @c0
    ldx ocx
    lda #0
:   clc
    adc oh
    dex
    bne :-
@c0:
    clc
    adc zs
    tay
    lda (p3),y
    ldx olo
    sta cb,x                    ; present
    lda #0
    sta cb2,x                   ; absent
@skip:
    inc olo
    lda olo
    cmp #8
    bne @line
    ; the characters
    jsr intern                  ; present
    pha
    ldx #7
:   lda cb2,x
    sta cb,x
    dex
    bpl :-
    jsr intern                  ; absent
    sta zv
    ; objabs[oi * 9 + ocx * 3 + (ocr - ocr0)]
    lda oi
    asl
    asl
    asl
    clc
    adc oi
    sta zs
    lda ocx
    asl
    clc
    adc ocx
    clc
    adc zs
    clc
    adc ocr
    sec
    sbc ocr0
    tax
    lda zv
    sta objabs,x
    pla
    sta zt                      ; present
    ; collected? show the absent one
    lda level
    asl
    asl
    clc
    adc oi
    tax
    lda objflags,x
    and #$0f
    beq :+
    lda zv
    sta zt
:   lda #0
    sta p2
    lda ocr
    clc
    adc rows_page
    sta p2 + 1
    lda ox
    clc
    adc ocx
    tay
    lda zt
    sta (p2),y
    inc ocr
    lda ocr
    cmp ocr1
    beq :+
    bcs @coldone
:   jmp @row
@coldone:
    inc ocx
    lda ocx
    cmp ow
    beq :+
    jmp @col
:
@next:
    inc oi
    lda oi
    cmp #4
    beq :+
    jmp @obj
:   rts

; the mine's characters are fixed
install_mine_chars:
    ldx #7
:   lda mine_cells,x
    sta cb,x
    dex
    bpl :-
    lda #CH_MINE
    jsr set_char
    ldx #7
:   lda mine_cells + 8,x
    sta cb,x
    dex
    bpl :-
    lda #CH_EXPL0
    jsr set_char
    ldx #7
:   lda mine_cells + 16,x
    sta cb,x
    dex
    bpl :-
    lda #CH_EXPL1
    ; fall through

; set_char: the cell in cb becomes character A (BBC bytes in BPAT, the C64's in the character set)
set_char:
    tay
    lda cb
    sta BPAT,y
    lda cb + 1
    sta BPAT + $100,y
    lda cb + 2
    sta BPAT + $200,y
    lda cb + 3
    sta BPAT + $300,y
    lda cb + 4
    sta BPAT + $400,y
    lda cb + 5
    sta BPAT + $500,y
    lda cb + 6
    sta BPAT + $600,y
    lda cb + 7
    sta BPAT + $700,y
    lda #0
    sta p5 + 1
    tya
    asl
    rol p5 + 1
    asl
    rol p5 + 1
    asl
    rol p5 + 1
    sta p5
    lda p5 + 1
    clc
    adc charset_page
    sta p5 + 1
    lda charset_page
    cmp #>STAGE_CHARSET
    bne @write
    sei
    lda #$34
    sta $01
@write:
    ldy #7
:   ldx cb,y
    lda conv_table,x
    sta (p5),y
    dey
    bpl :-
    lda charset_page
    cmp #>STAGE_CHARSET
    bne @done
    lda #$35
    sta $01
    cli
@done:
    rts

; load_level: the character set and ROWS for `level` (its tile map is in LTILES)
intern_reset:
    lda #>ROWS
    sta rows_page
    ldx #0
    lda #$ff
:   sta HEAD,x
    sta NXT,x
    inx
    bne :-
    lda #0
    sta overflow
    sta HEAD                    ; the blank cell's hash is 0: its chain is character 0 alone
    lda #$ff
    sta NXT
    lda #1
    sta nchars
    lda lift_screen
    beq @normal
    lda #>STAGE_CHARSET
    sta charset_page
    ; the staging area holds the sprite blocks: the blank character must be cleared
    php
    sei
    lda $01
    pha
    lda #$34
    sta $01
    lda #0
    ldx #7
:   sta STAGE_CHARSET,x
    dex
    bpl :-
    pla
    sta $01
    plp
    rts
@normal:
    lda #>CHARSET
    sta charset_page
    rts

load_level:
    lda level
    asl
    tax
    lda level_nibmask,x
    sta tgmask
    lda level_nibmask + 1,x
    sta tgmask + 1
    jsr intern_reset
    jsr install_mine_chars
    jsr build_tg
    jsr fill_rows
    jsr place_objects
    rts

; put_cell: character A into ROWS at column X, row Y, and into the matrices where they show it
put_cell:
    sta zt
    stx zc
    sty zl
    lda #0
    sta p2
    tya
    clc
    adc rows_page
    sta p2 + 1
    txa
    tay
    lda zt
    sta (p2),y
    lda lift_screen
    bne @done
    ldx #1
@m: lda zc
    sec
    sbc mat_w,x
    cmp #40
    bcs @nx
    sta zs
    lda zl
    sec
    sbc mat_c,x
    cmp #25
    bcs @nx
    tay
    lda mul40_lo,y
    clc
    adc zs
    sta p2
    lda mul40_hi,y
    adc #0
    sta p2 + 1
    lda p2 + 1
    cpx #0
    bne :+
    clc
    adc #>MAT_A
    jmp :++
:   clc
    adc #>MAT_B
:   sta p2 + 1
    ldy #0
    lda zt
    sta (p2),y
@nx:
    dex
    bpl @m
@done:
    ldx zc
    ldy zl
    lda zt
    rts

mul40_lo:
    .repeat 32, i
    .byte <(i * 40)
    .endrepeat
mul40_hi:
    .repeat 32, i
    .byte >(i * 40)
    .endrepeat
