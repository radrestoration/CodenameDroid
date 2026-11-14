; Apple IIgs: draw and scroll a 40 x 25 cell window of a level in Super Hi-Res (320 mode, bank $E1).
;
; Data (from tools/make_apple2gs_tiles.py), addressed with 24-bit long addressing:
;   cells   626 x 32 bytes: a cell is 8 lines of 4 bytes (two 4-bit pixels per byte)
;   tiles   76 x 16 words: cell index for each cell of a tile, row-major (4 rows x 4 columns)
;   levels  12 x 64 columns x 8 rows of tile numbers, column-major (512 bytes a level)
; A level is 64 tiles wide and 8 tall = 256 x 32 cells; a tile is 4 x 4 cells.
;
; Call all public routines in native mode with 16-bit A and index registers and the direct page set to the
; page holding the variables below. They restore the data bank.
;   draw_view     A = level (0-11); cam_x = leftmost cell (0-216), cam_y = top cell (0-7). Draws the whole window.
;   scroll_right  camera one cell right (cam_x + 1)     } carry set and nothing done if the camera is already at
;   scroll_left   camera one cell left                  } its limit (cam_x 0-216, cam_y 0-7); carry clear
;   scroll_down   camera one cell down (cam_y + 1)      } after a scroll. draw_view must have run first (it sets
;   scroll_up     camera one cell up                    } the level).
; A scroll moves the existing screen with block moves and draws the newly exposed column or row. Horizontally each
; line is shifted by 4 bytes and given its 4 new edge bytes at once; vertically the whole screen moves, then the row.
.p816
.smart +
.export draw_view, scroll_left, scroll_right, scroll_up, scroll_down, cam_x, cam_y
.import cells, tiles, levels

CAM_X_MAX = 216
CAM_Y_MAX = 7
SCREEN    = $2000               ; SHR pixels in bank $E1
LINE      = 160                 ; bytes a line
CELL_ROW  = 8 * LINE            ; bytes a screen row of cells

.segment "ZEROPAGE"
cam_x:      .res 2
cam_y:      .res 2
level_ofs:  .res 2
row:        .res 2
col:        .res 2
row_ofs:    .res 2              ; levels offset of this screen row's tile row in the first tile column
col_ofs:    .res 2              ; levels offset of this screen column's tile column (tile row 0)
yf4:        .res 2              ; (cell row within the tile) * 4
scr_row:    .res 2              ; byte offset of this screen cell row from SCREEN
cell_ofs:   .res 2
ln:         .res 2              ; screen line being scrolled
dstp:       .res 2              ; its address in the screen
colcells:   .res 50             ; offsets into `cells` of the exposed column's 25 cells

; 8 lines x 4 bytes of the cell at cells+X to the screen at SCREEN+Y (data bank $E1)
.macro blit_cell
.repeat 8, line
        lda     f:cells + line * 4,x
        sta     SCREEN + line * LINE,y
        lda     f:cells + line * 4 + 2,x
        sta     SCREEN + line * LINE + 2,y
.endrepeat
.endmacro

.macro set_bank_e1
        phb
        pea     $e1e1
        plb
        plb
.endmacro

.segment "CODE"

; ---- whole window -------------------------------------------------------------------------------------------
.proc draw_view
        .a16                    ; entered with 16-bit A and index registers
        .i16
        set_bank_e1
        xba
        asl     a               ; level * 512
        sta     level_ofs
        stz     row
nextrow:
        jsr     draw_row
        inc     row
        lda     row
        cmp     #25
        bne     nextrow
        plb
        rts
.endproc

; ---- one screen row of 40 cells (row = 0-24); data bank must be $E1 -----------------------------------------
.proc draw_row
        .a16
        .i16
        lda     cam_y
        clc
        adc     row             ; world cell row
        pha
        and     #3
        asl     a
        asl     a
        sta     yf4
        pla
        lsr     a
        lsr     a               ; tile row
        clc
        adc     level_ofs
        sta     row_ofs
        lda     row             ; row * 1280 = row * 256 * 5
        xba
        sta     cell_ofs
        asl     a
        asl     a
        clc
        adc     cell_ofs
        sta     scr_row
        stz     col
nextcol:
        lda     cam_x
        clc
        adc     col             ; world cell column
        pha
        and     #3
        clc
        adc     yf4
        asl     a
        sta     cell_ofs        ; byte offset of this cell's word within the tile's 16
        pla
        lsr     a
        lsr     a               ; tile column
        asl     a
        asl     a
        asl     a               ; * 8 rows
        clc
        adc     row_ofs
        tax
        sep     #$20
        lda     f:levels,x      ; tile number
        rep     #$20
        and     #$00ff
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a               ; * 32 bytes a tile
        clc
        adc     cell_ofs
        tax
        lda     f:tiles,x       ; cell index
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a               ; * 32 bytes a cell
        tax
        lda     col
        asl     a
        asl     a
        clc
        adc     scr_row
        tay
        blit_cell
        inc     col
        lda     col
        cmp     #40
        beq     done
        jmp     nextcol
done:   rts
.endproc

; ---- the exposed column: the cell offsets of one screen column (col = 0-39) -----------------------------------------
; colcells + 2 * row = the offset into `cells` of the cell of screen row `row` (0-24) in that column.
.proc prepare_column
        .a16
        .i16
        lda     cam_x
        clc
        adc     col             ; world cell column
        pha
        and     #3
        asl     a
        sta     cell_ofs        ; (cell column within the tile) * 2
        pla
        lsr     a
        lsr     a               ; tile column
        asl     a
        asl     a
        asl     a               ; * 8 rows
        clc
        adc     level_ofs
        sta     col_ofs
        stz     row
nextrow:
        lda     cam_y
        clc
        adc     row             ; world cell row
        pha
        and     #3
        asl     a
        asl     a
        asl     a               ; * 8: (cell row within the tile) * 4 words * 2 bytes
        clc
        adc     cell_ofs
        sta     yf4             ; byte offset of this cell's word within the tile's 16
        pla
        lsr     a
        lsr     a               ; tile row
        clc
        adc     col_ofs
        tax
        sep     #$20
        lda     f:levels,x      ; tile number
        rep     #$20
        and     #$00ff
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a
        clc
        adc     yf4
        tax
        lda     f:tiles,x       ; cell index
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a               ; * 32 bytes a cell
        pha
        lda     row
        asl     a
        tax
        pla
        sta     colcells,x
        inc     row
        lda     row
        cmp     #25
        bne     nextrow
        rts
.endproc

; the 4 bytes of screen line `ln` (0-199) in the prepared column, to the word pair at Y (data bank $E1)
.macro edge_bytes
        lda     ln
        lsr     a
        lsr     a
        lsr     a
        asl     a
        tax
        lda     colcells,x      ; the cell of this line's row
        sta     cell_ofs
        lda     ln
        and     #7
        asl     a
        asl     a               ; * 4 bytes a line of the cell
        clc
        adc     cell_ofs
        tax
        lda     f:cells,x
        sta     a:$0000,y
        lda     f:cells + 2,x
        sta     a:$0002,y
.endmacro

; ---- scrolling ----------------------------------------------------------------------------------------------
; Horizontal: line by line, each line shifted by 4 bytes with a block move and its 4 edge bytes written at once, so a
; line is never visible with wrapped-around bytes in the exposed column (only the beam passing mid-scroll shows a seam).
.proc scroll_right
        .a16
        .i16
        lda     cam_x
        cmp     #CAM_X_MAX
        bcc     ok
        sec
        rts
ok:     inc     cam_x
        set_bank_e1
        lda     #39
        sta     col
        jsr     prepare_column
        stz     ln
        lda     #SCREEN
        sta     dstp
nextline:
        lda     dstp
        clc
        adc     #4
        tax                     ; the line's byte 4 ...
        ldy     dstp            ; ... to its byte 0
        lda     #LINE - 4 - 1
        mvn     $e10000,$e10000
        edge_bytes              ; Y has moved on to the line's byte 156
        lda     dstp
        clc
        adc     #LINE
        sta     dstp
        inc     ln
        lda     ln
        cmp     #200
        beq     done
        jmp     nextline
done:   plb
        clc
        rts
.endproc

.proc scroll_left
        .a16
        .i16
        lda     cam_x
        bne     ok
        sec
        rts
ok:     dec     cam_x
        set_bank_e1
        stz     col
        jsr     prepare_column
        stz     ln
        lda     #SCREEN
        sta     dstp
nextline:
        lda     dstp
        clc
        adc     #LINE - 4 - 1
        tax                     ; the line's byte 155 (the last that moves) ...
        lda     dstp
        clc
        adc     #LINE - 1
        tay                     ; ... to its byte 159, last byte first
        lda     #LINE - 4 - 1
        mvp     $e10000,$e10000
        ldy     dstp            ; the line's edge: bytes 0 - 3
        edge_bytes
        lda     dstp
        clc
        adc     #LINE
        sta     dstp
        inc     ln
        lda     ln
        cmp     #200
        beq     done
        jmp     nextline
done:   plb
        clc
        rts
.endproc

.proc scroll_down
        .a16
        .i16
        lda     cam_y
        cmp     #CAM_Y_MAX
        bcc     ok
        sec
        rts
ok:     inc     cam_y
        set_bank_e1
        ldx     #SCREEN + CELL_ROW
        ldy     #SCREEN
        lda     #32000 - CELL_ROW - 1
        mvn     $e10000,$e10000
        lda     #24
        sta     row
        jsr     draw_row
        plb
        clc
        rts
.endproc

.proc scroll_up
        .a16
        .i16
        lda     cam_y
        bne     ok
        sec
        rts
ok:     dec     cam_y
        set_bank_e1
        ldx     #SCREEN + 32000 - CELL_ROW - 1
        ldy     #SCREEN + 32000 - 1
        lda     #32000 - CELL_ROW - 1
        mvp     $e10000,$e10000
        stz     row
        jsr     draw_row
        plb
        clc
        rts
.endproc
