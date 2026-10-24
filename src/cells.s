; The cell store: turns the game's own screen buffer (the ring at $6000, 1024 cells of 8 bytes in
; BBC MODE 5 format) into the character matrix the VIC-II shows.
;
; The game plots and reads the ring exactly as on the BBC. Whatever it changes is reported here
; (mark_cell / mark_rect, called from the hooks in platform.s); c64_present then looks at each
; changed cell's 8 bytes, finds the character that has that pattern (or makes one), and
; updates CELLCHAR and, if the cell is on screen, the matrix. Scrolling changes no pixels at all:
; it is the matrix being re-read from CELLCHAR at a different start (full_remap).
;
; A character is shared by every cell with the same pattern, so there is a reference count per
; character (16 bit); a character with none is freed. Character 0 is blank and never freed.

.segment "CODE"

; WRAP_CELL hi, lo: reduce the cell index (hi:lo, hi in A or memory) modulo RING_CELLS after adding something small.
; For a ring of 32 columns that is a mask; otherwise a compare and subtract. Used as WRAP_CELL var (zero page, 2 bytes).
.macro WRAP_CELL var
.if RING_W = 32
    lda var+1
    and #3
    sta var+1
.else
    lda var+1                   ; (anonymous labels: a macro's named ones would end the scope of the @ labels)
    cmp #>RING_CELLS
    bcc :++
    bne :+
    lda var
    cmp #<RING_CELLS
    bcc :++
:   lda var                     ; subtract RING_CELLS
    sec
    sbc #<RING_CELLS
    sta var
    lda var+1
    sbc #>RING_CELLS
    sta var+1
:
.endif
.endmacro


; ------------------------------------------------------------------------------------------------
; cells_init: everything empty. (cells_reset is the same; used by clear_screen)
cells_init:
cells_reset:
    lda #0
    tax
@zero:
    sta CELLCHAR,x
    sta CELLCHAR+$100,x
    sta CELLCHAR+$200,x
    sta CELLCHAR+$300,x
    sta CELLCHAR+$400,x
.if RING_W <> 32
    sta CELLCHAR+$500,x
    sta DFLAG+$400,x
.endif
    sta DFLAG,x
    sta DFLAG+$100,x
    sta DFLAG+$200,x
    sta DFLAG+$300,x
    sta NXT,x
    sta HASHV,x
    sta REFL,x
    sta REFH,x
    sta BPAT0,x
    sta BPAT1,x
    sta BPAT2,x
    sta BPAT3,x
    sta BPAT4,x
    sta BPAT5,x
    sta BPAT6,x
    sta BPAT7,x
    inx
    bne @zero
    lda #$ff
@head:
    sta HEAD,x
    inx
    bne @head
    ; char 0 is the blank pattern: hash 0, pinned
    lda #0
    sta HEAD+0
    lda #$ff
    sta NXT+0
    lda #$80
    sta REFH+0
    ; free list: 255 down to 1, so 1 is allocated first
    ldx #0
@free:
    txa
    eor #$ff                    ; 255 - x
    sta FREELIST,x
    inx
    cpx #255
    bne @free
    lda #255
    sta zp_fc
    lda #0
    sta zp_dc
    sta zp_dc+1
    ; blank character in the charset
    ldx #7
@cs0:
    sta CHARSET,x
    dex
    bpl @cs0
    ; the ring cell -> view mapping starts as "nothing shown yet"
    lda #$ff
    sta zp_vb+1
    lda #0
    sta zp_remap
    sta zp_ev
.if RING_W <> 32
    jsr make_row_col_tables
.endif
    rts

.if RING_W <> 32
; ROWTAB[d] = d / RING_W and COLTAB[d] = d mod RING_W for d = 0 .. RING_CELLS-1
make_row_col_tables:
    lda #<ROWTAB
    sta zp_u
    lda #>ROWTAB
    sta zp_u+1
    lda #<COLTAB
    sta zp_p1
    lda #>COLTAB
    sta zp_p1+1
    ldx #0                      ; row
@row:
    lda #0
    sta zp_t                    ; column
@col:
    ldy #0
    txa
    sta (zp_u),y
    lda zp_t
    sta (zp_p1),y
    inc zp_u
    bne @u
    inc zp_u+1
@u:
    inc zp_p1
    bne @p
    inc zp_p1+1
@p:
    inc zp_t
    lda zp_t
    cmp #RING_W
    bne @col
    inx
    cpx #32
    bne @row
    rts
.endif

; ------------------------------------------------------------------------------------------------
; matrix_clear: the whole 40x25 matrix = character 0
matrix_clear:
    lda #0
    tax
@m:
    sta MATRIX,x
    sta MATRIX+$100,x
    sta MATRIX+$200,x
    sta MATRIX+$300,x
    sta MATRIX2,x
    sta MATRIX2+$100,x
    sta MATRIX2+$200,x
    sta MATRIX2+$300,x
    inx
    bne @m
    rts

; ------------------------------------------------------------------------------------------------
; addr_to_cell: ring byte address (A = high, X = low) -> zp_ci. Clobbers A, zp_t.
addr_to_cell:
    sec
    sbc #>RING
.if RING_W = 32
    and #$1f                    ; wrap inside the ring
.else
    bcs @pos                    ; wrap inside the ring
    adc #RING_SZ_HI
    jmp @in
@pos:
    cmp #RING_SZ_HI
    bcc @in
    sbc #RING_SZ_HI
@in:
.endif
    sta zp_t
    lsr
    lsr
    lsr
    sta zp_ci+1
    lda zp_t
    and #7
    asl
    asl
    asl
    asl
    asl
    sta zp_ci
    txa
    lsr
    lsr
    lsr
    ora zp_ci
    sta zp_ci
    rts

; ------------------------------------------------------------------------------------------------
; mark_cell: put the cell zp_ci on the dirty list (once). Clobbers A, Y, zp_u.
mark_cell:
    lda zp_ci+1
    clc
    adc #>DFLAG
    sta zp_u+1
    lda #0
    sta zp_u
    ldy zp_ci
    lda (zp_u),y
    bne @done
    lda #1
    sta (zp_u),y
    lda zp_dc+1
    clc
    adc #>DLO
    sta zp_u+1
    ldy zp_dc
    lda zp_ci
    sta (zp_u),y
    lda zp_dc+1
    clc
    adc #>DHI
    sta zp_u+1
    lda zp_ci+1
    sta (zp_u),y
    inc zp_dc
    bne @done
    inc zp_dc+1
@done:
    rts

; ------------------------------------------------------------------------------------------------
; mark_rect: mark zp_rx columns by zp_ry rows of cells starting at zp_ci. Cells follow the
; ring's own order (+1 per column, +32 per row, both wrapping at 1024). Clobbers A, X, Y, zp_ci.
mark_rect:
    lda zp_ci
    sta zp_rs
    lda zp_ci+1
    sta zp_rs+1
@row:
    ldx zp_rx
    lda zp_rs
    sta zp_ci
    lda zp_rs+1
    sta zp_ci+1
@col:
    jsr mark_cell
    inc zp_ci
    bne @nc
    inc zp_ci+1
@nc:
    WRAP_CELL zp_ci
    dex
    bne @col
    clc
    lda zp_rs
    adc #RING_W
    sta zp_rs
    bcc @nr
    inc zp_rs+1
@nr:
    WRAP_CELL zp_rs
    dec zp_ry
    bne @row
    rts

; ------------------------------------------------------------------------------------------------
; process_dirty: bring every dirty cell's character up to date
process_dirty:
@next:
    lda zp_dc
    ora zp_dc+1
    bne @pop
    rts
@pop:
    lda zp_dc
    bne @nb
    dec zp_dc+1
@nb:
    dec zp_dc
    ; entry zp_dc: its cell index
    lda zp_dc+1
    clc
    adc #>DLO
    sta zp_u+1
    lda #0
    sta zp_u
    ldy zp_dc
    lda (zp_u),y
    sta zp_ci
    lda zp_dc+1
    clc
    adc #>DHI
    sta zp_u+1
    lda (zp_u),y
    sta zp_ci+1
    ; clear its dirty flag
    lda zp_ci+1
    clc
    adc #>DFLAG
    sta zp_u+1
    ldy zp_ci
    lda #0
    sta (zp_u),y
    jsr update_cell
    jmp @next

; update_cell: zp_ci = cell. Find or make the character for its current bytes.
update_cell:
    ; zp_p1 = RING + cell*8
    lda zp_ci
    sta zp_p1
    lda zp_ci+1
    sta zp_p1+1
    asl zp_p1
    rol zp_p1+1
    asl zp_p1
    rol zp_p1+1
    asl zp_p1
    rol zp_p1+1
    lda zp_p1+1
    clc
    adc #>RING
    sta zp_p1+1
    ; unchanged? (a rectangle often covers cells the game did not actually change)
    lda zp_ci+1
    clc
    adc #>CELLCHAR
    sta zp_u+1
    lda #0
    sta zp_u
    ldy zp_ci
    lda (zp_u),y
    tax
    ldy #0
    lda (zp_p1),y
    cmp BPAT0,x
    bne @changed
    iny
    lda (zp_p1),y
    cmp BPAT1,x
    bne @changed
    iny
    lda (zp_p1),y
    cmp BPAT2,x
    bne @changed
    iny
    lda (zp_p1),y
    cmp BPAT3,x
    bne @changed
    iny
    lda (zp_p1),y
    cmp BPAT4,x
    bne @changed
    iny
    lda (zp_p1),y
    cmp BPAT5,x
    bne @changed
    iny
    lda (zp_p1),y
    cmp BPAT6,x
    bne @changed
    iny
    lda (zp_p1),y
    cmp BPAT7,x
    bne @changed
    rts
@changed:
    ; hash of the 8 bytes
    ldy #7
    lda #0
@hash:
    eor (zp_p1),y
    tax
    lda hash_tab,x
    dey
    bpl @hash
    sta zp_h
    tax
    lda HEAD,x
@chain:
    cmp #$ff
    beq @miss
    sta zp_c
    tax
    ldy #0
    lda (zp_p1),y
    cmp BPAT0,x
    bne @other
    iny
    lda (zp_p1),y
    cmp BPAT1,x
    bne @other
    iny
    lda (zp_p1),y
    cmp BPAT2,x
    bne @other
    iny
    lda (zp_p1),y
    cmp BPAT3,x
    bne @other
    iny
    lda (zp_p1),y
    cmp BPAT4,x
    bne @other
    iny
    lda (zp_p1),y
    cmp BPAT5,x
    bne @other
    iny
    lda (zp_p1),y
    cmp BPAT6,x
    bne @other
    iny
    lda (zp_p1),y
    cmp BPAT7,x
    bne @other
    jmp @have
@other:
    lda NXT,x
    jmp @chain

@miss:
    ; a new pattern: take a never-used character, or reclaim an unreferenced one
    jsr alloc_char
    bcc @alloc
    rts                         ; out of characters: keep whatever the cell shows (a glitch, but safe)
@alloc:
    ; zp_u = CHARSET + c*8
    lda #0
    sta zp_u+1
    lda zp_c
    sta zp_u
    asl zp_u
    rol zp_u+1
    asl zp_u
    rol zp_u+1
    asl zp_u
    rol zp_u+1
    lda zp_u+1
    clc
    adc #>CHARSET
    sta zp_u+1
    ldx zp_c
    ; line 0..7: BBC byte -> BPATk[c], converted byte -> charset
    ldy #0
    lda (zp_p1),y
    sta BPAT0,x
    tay
    lda bbc_to_c64,y
    ldy #0
    sta (zp_u),y
    ldy #1
    lda (zp_p1),y
    sta BPAT1,x
    tay
    lda bbc_to_c64,y
    ldy #1
    sta (zp_u),y
    ldy #2
    lda (zp_p1),y
    sta BPAT2,x
    tay
    lda bbc_to_c64,y
    ldy #2
    sta (zp_u),y
    ldy #3
    lda (zp_p1),y
    sta BPAT3,x
    tay
    lda bbc_to_c64,y
    ldy #3
    sta (zp_u),y
    ldy #4
    lda (zp_p1),y
    sta BPAT4,x
    tay
    lda bbc_to_c64,y
    ldy #4
    sta (zp_u),y
    ldy #5
    lda (zp_p1),y
    sta BPAT5,x
    tay
    lda bbc_to_c64,y
    ldy #5
    sta (zp_u),y
    ldy #6
    lda (zp_p1),y
    sta BPAT6,x
    tay
    lda bbc_to_c64,y
    ldy #6
    sta (zp_u),y
    ldy #7
    lda (zp_p1),y
    sta BPAT7,x
    tay
    lda bbc_to_c64,y
    ldy #7
    sta (zp_u),y
    ; link into its bucket; no references yet
    ldx zp_h
    lda HEAD,x
    ldy zp_c
    sta NXT,y
    tya
    sta HEAD,x
    lda zp_h
    sta HASHV,y
    lda #0
    sta REFL,y
    sta REFH,y

@have:
    ; zp_c is the character for the cell now. What did the cell have?
    lda zp_ci+1
    clc
    adc #>CELLCHAR
    sta zp_u+1
    lda #0
    sta zp_u
    ldy zp_ci
    lda (zp_u),y
    sta zp_oc
    cmp zp_c
    beq @unchanged
    ; take a reference on the new one, store it (and its mirror), drop the old one
    ldx zp_c
    inc REFL,x
    bne @r1
    inc REFH,x
@r1:
    lda zp_c
    sta (zp_u),y
    lda zp_ci+1
    bne @nomirror
    lda zp_ci
    cmp #RING_W
    bcs @nomirror
    tax
    lda zp_c
    sta CELLCHAR+RING_CELLS,x
@nomirror:
    ldx zp_oc
    beq @shown                  ; character 0 is pinned
    lda REFL,x
    bne @dec
    dec REFH,x
@dec:
    dec REFL,x
@shown:                         ; (an unreferenced character stays in its bucket: if the pattern comes back it is
                                ; found again without being converted; it is reclaimed only when one is needed)
    jsr show_cell
@unchanged:
    rts

; alloc_char: a character for a new pattern -> zp_c, carry clear; carry set if there is none.
; Never-used characters first; then any character nobody references (found from the hand zp_ev
; round the table), which is taken out of its bucket.
alloc_char:
    ldx zp_fc
    beq @evict
    dex
    stx zp_fc
    lda FREELIST,x
    sta zp_c
    clc
    rts
@evict:
    ldx zp_ev
@scan:
    inx
    lda REFL,x
    ora REFH,x
    beq @found
    cpx zp_ev
    bne @scan
    sec
    rts
@found:
    stx zp_ev
    stx zp_c
    ; remove it from its bucket's chain
    lda HASHV,x
    tay                         ; Y = bucket
    txa
    cmp HEAD,y
    bne @find
    lda NXT,x                   ; it was first
    sta HEAD,y
    clc
    rts
@find:
    lda HEAD,y
    tay                         ; Y = a character in the chain
@walk:
    lda NXT,y
    cmp zp_c
    beq @unlink
    tay
    jmp @walk
@unlink:
    lda NXT,x
    sta NXT,y
    clc
    rts

; show_cell: if the cell zp_ci is in the matrix window, put zp_c there
show_cell:
    lda zp_remap
    bne @out                    ; the matrix is about to be rebuilt anyway
.if RING_W <> 32
    lda c64_tmap
    beq @notitle
    lda #1                      ; (the title map: a cell's place is not worked out: the whole matrix is made again, which the
    sta zp_remap                ; title screen, which hardly changes, can afford)
    rts
@notitle:
.endif
    sec
    lda zp_ci
    sbc zp_vb
    sta zp_d
    lda zp_ci+1
    sbc zp_vb+1
.if RING_W = 32
    and #3
    sta zp_d+1                  ; d = (cell - vb) mod 1024
    cmp #3
    bcc @in
    lda zp_d
    cmp #(VIEW_ROWS * 32) - $300
    bcs @out
@in:
    lda zp_d
    lsr
    lsr
    lsr
    lsr
    lsr
    sta zp_t
    lda zp_d+1
    asl
    asl
    asl
    ora zp_t
    tax                         ; X = row
    lda zp_d
    and #31                     ; column
.else
    sta zp_d+1                  ; d = cell - vb, mod the ring's cells
    bpl @nowrap
    clc
    lda zp_d
    adc #<RING_CELLS
    sta zp_d
    lda zp_d+1
    adc #>RING_CELLS
    sta zp_d+1
@nowrap:
    cmp #>(VIEW_ROWS * RING_W)  ; in the matrix's rows? (25 rows of RING_W cells)
    bcc @in
    bne @out
    lda zp_d
    cmp #<(VIEW_ROWS * RING_W)
    bcs @out
@in:
    lda zp_d                    ; row and column of d by table
    sta zp_u
    lda zp_d+1
    clc
    adc #>ROWTAB
    sta zp_u+1
    ldy #0
    lda (zp_u),y
    tax                         ; X = row
    lda zp_d+1
    clc
    adc #>COLTAB
    sta zp_u+1
    lda (zp_u),y                ; column
    cmp c64_vcols
    bcs @out                    ; (the leftmost c64_vcols columns are shown)
.endif
    clc
    adc c64_mcol0
    adc mrow_lo,x
    sta zp_u
    lda mrow_hi,x
    adc #0
    sta zp_u+1
    ldy #0
    lda zp_c
    sta (zp_u),y
    lda zp_u+1                  ; (and in the other matrix: it is shown or built next)
    clc
    adc #>(MATRIX2 - MATRIX)
    sta zp_u+1
    lda zp_c
    sta (zp_u),y
@out:
    rts

; ------------------------------------------------------------------------------------------------
; view_prepare: work out the view base the matrix should have (the display start plus the camera);
; zp_remap is set if that is not what the matrix shows now
view_prepare:
    lda c64_crtc_high
    sec
    sbc #(RING_HI / 8)          ; the CRTC start address is in cells: $0c00-$0fff -> 0-3 (32 columns), $0b00-$0fff -> 0-4
.if RING_W = 32
    and #3
.endif
    sta zp_nv+1
    lda c64_crtc_low
    sta zp_nv                   ; S, the ring cell at the display's top left
    lda c64_cam                 ; + RING_W * camera row
    asl
    asl
    asl
    asl
    asl
    clc
    adc zp_nv
    sta zp_nv
    lda zp_nv+1
    adc #0                      ; the carry (32 * camera <= 224 fits in the low byte)
.if RING_W = 32
    and #3
    sta zp_nv+1
.else
    sta zp_nv+1
    lda c64_cam                 ; + 8 * camera row (40 = 32 + 8)
    asl
    asl
    asl
    clc
    adc zp_nv
    sta zp_nv
    lda zp_nv+1
    adc #0
    sta zp_nv+1
    WRAP_CELL zp_nv
.endif
    lda #0
    sta zp_remap
    lda zp_nv
    cmp zp_vb
    bne @changed
    lda zp_nv+1
    cmp zp_vb+1
    beq @same
@changed:
    lda #1
    sta zp_remap
@same:
    rts

; view_apply: if the view moved, rebuild the matrix
view_apply:
    lda zp_remap
    beq @r
    lda zp_nv
    sta zp_vb
    lda zp_nv+1
    sta zp_vb+1
    lda #0
    sta zp_remap
    lda #1
    sta c64_busy                ; the swap must not happen while the back matrix is half built
    jsr full_remap
    lda #1
    sta c64_flip
    lda #0
    sta c64_busy
@r:
    rts

; full_remap: matrix row r (columns c64_mcol0 on, c64_vcols of them) := CELLCHAR[(vb + RING_W r) mod RING_CELLS ...]
full_remap:
.if RING_W <> 32
    lda c64_tmap
    beq @std
    jmp title_remap
@std:
.endif
    lda c64_back
    sec
    sbc #>MATRIX
    sta zp_t                    ; 0 or 4: the back matrix's page offset
    lda zp_vb
    sta zp_idx
    lda zp_vb+1
    sta zp_idx+1
    ldx #0
@row:
    lda zp_idx
    clc
    adc #<CELLCHAR
    sta @ld+1
    lda zp_idx+1
    adc #>CELLCHAR
    sta @ld+2
    lda mrow_lo,x
    clc
    adc c64_mcol0
    sta @st+1
    lda mrow_hi,x
    adc zp_t
    sta @st+2
    ldy c64_vcols
    dey
@ld:
    lda $ffff,y
@st:
    sta $ffff,y
    dey
    bpl @ld
    clc
    lda zp_idx
    adc #RING_W
    sta zp_idx
    bcc @nx
    inc zp_idx+1
@nx:
    WRAP_CELL zp_idx
    inx
    cpx #VIEW_ROWS
    bne @row
    rts

; ------------------------------------------------------------------------------------------------
; c64_present: called at every vertical blank
c64_present:
    jsr mark_blasters
    jsr camera_update
    jsr view_prepare
    jsr process_dirty
    jmp view_apply

; Blasters are 4x3 pixels written one byte at a time; rather than hook those writes, mark the
; cells around each active slot's address and its previous one on every present.
; Slots: ZP $36 + 4k: address lo, hi, direction, ttl ($ff = unused), k = 0-5.
; bl_prev (2 bytes per slot) remembers where each was, hi = $ff for none.
mark_blasters:
    ldx #0                      ; ZP offset of the slot (0, 4, ... 20)
    ldy #0                      ; offset in bl_prev (0, 2, ... 10)
@slot:
    lda bl_prev+1,y
    cmp #$ff
    beq @noprev
    sta hk_hi
    lda bl_prev,y
    sta hk_lo
    jsr mark_around
@noprev:
    lda $39,x
    cmp #$ff
    beq @off
    lda $37,x
    sta hk_hi
    sta bl_prev+1,y
    lda $36,x
    sta hk_lo
    sta bl_prev,y
    jsr mark_around
    jmp @next
@off:
    lda #$ff
    sta bl_prev+1,y
@next:
    inx
    inx
    inx
    inx
    iny
    iny
    cpx #24
    bne @slot
    rts

; mark_around: mark the cells holding the bytes just before and just after the ring address
; hk_hi:hk_lo (a blaster is three bytes tall). Preserves X and Y.
mark_around:
    stx zp_v
    sty zp_v+1
    lda hk_lo
    sec
    sbc #1
    tax
    lda hk_hi
    sbc #0
    cmp #>RING
    bcs @ok1
    lda #>RING+RING_SZ_HI-1     ; wrapped below the start of the ring
@ok1:
    jsr addr_to_cell
    jsr mark_cell
    lda hk_lo
    clc
    adc #1
    tax
    lda hk_hi
    adc #0
    jsr addr_to_cell            ; addr_to_cell masks to the ring
    jsr mark_cell
    ldx zp_v
    ldy zp_v+1
    rts

; ------------------------------------------------------------------------------------------------
; the matrix rows: where each row's game columns start
mrow_lo:
.repeat VIEW_ROWS, r
    .byte <(MATRIX + 40*r)
.endrepeat
mrow_hi:
.repeat VIEW_ROWS, r
    .byte >(MATRIX + 40*r)
.endrepeat

; ------------------------------------------------------------------------------------------------
; camera_update: which ring rows the 25-row matrix shows, c64_cam .. c64_cam+24 (cam 0-7). In gameplay the
; camera follows the player: normally cam = 4 (tile rows 1-6, the playing area between the ceiling and
; the floor), but it moves, a row a frame, to keep the player two rows from the top and not below the
; bottom row (so the levels that use the full height, and the lifts, work). Every other screen (title,
; status, game over: framed, with their content in rows 4-27) uses cam = 4.
camera_update:
    lda c64_gamemode
    bne @game
    lda #4
.if RING_W <> 32
    ldx c64_tmap                ; (the title map's cells are counted from the ring window's top left)
    beq @cam
    lda #0
@cam:
.endif
    sta c64_cam
    rts
@game:
    lda $91                     ; player_screen_address: the player's top left
    ldx $90
    jsr addr_to_cell            ; zp_ci
    lda c64_crtc_high           ; S, the cell at the display's top left
    sec
    sbc #(RING_HI / 8)
.if RING_W = 32
    and #3
.endif
    sta zp_d+1
    lda c64_crtc_low
    sta zp_d
    sec
    lda zp_ci
    sbc zp_d
    sta zp_d
    lda zp_ci+1
    sbc zp_d+1
.if RING_W = 32
    and #3
    sta zp_d+1
    lda zp_d                    ; the player's displayed row = (cell - S) / 32
    lsr
    lsr
    lsr
    lsr
    lsr
    sta zp_t
    lda zp_d+1
    asl
    asl
    asl
    ora zp_t
.else
    sta zp_d+1                  ; (cell - S) mod RING_CELLS, then its row by table
    bpl @nowrap
    clc
    lda zp_d
    adc #<RING_CELLS
    sta zp_d
    lda zp_d+1
    adc #>RING_CELLS
    sta zp_d+1
@nowrap:
    lda zp_d
    sta zp_u
    lda zp_d+1
    clc
    adc #>ROWTAB
    sta zp_u+1
    ldy #0
    lda (zp_u),y
.endif
    sec
    sbc c64_cam                 ; row relative to the top of the view
    bcc @up
    cmp #2
    bcc @up                     ; closer than two rows to the top
    cmp #21
    bcs @down                   ; the row below its 4 rows would be off the bottom
    ldx c64_cam                 ; comfortable: drift back to the default
    cpx #4
    beq @done
    bcc @low
    cmp #20
    bcs @done
    dec c64_cam
    rts
@low:
    cmp #3
    bcc @done
    inc c64_cam
@done:
    rts
@up:
    lda c64_cam
    beq @done
    dec c64_cam
    rts
@down:
    lda c64_cam
    cmp #7
    bcs @done
    inc c64_cam
    rts

.if RING_W <> 32
; ------------------------------------------------------------------------------------------------
; The title screen's map (tools/make_title_map.py): the matrix shows the ring's title rearranged. TMAP_SEG has the segments in
; screen order: a length, and the offset (from the ring window's top left) of the first of the cells they are copied from. A
; change of any cell makes show_cell ask for the whole matrix to be made again.

; title_remap: the back matrix from the segments
title_remap:
    lda c64_back
    sta zp_d+1
    lda #0
    sta zp_d                    ; the matrix cell the segment goes to
    lda #<TMAP_SEG
    sta zp_p1
    lda #>TMAP_SEG
    sta zp_p1+1
@seg:
    ldy #0
    lda (zp_p1),y
    beq @done
    sta zp_rx                   ; its length
    iny
    lda (zp_p1),y
    clc
    adc zp_vb
    sta zp_idx
    iny
    lda (zp_p1),y
    adc zp_vb+1
    sta zp_idx+1
    WRAP_CELL zp_idx            ; the ring cell it starts at
    clc
    lda zp_idx
    adc #<CELLCHAR
    sta @ld+1
    lda zp_idx+1
    adc #>CELLCHAR
    sta @ld+2
    lda zp_d
    sta @st+1
    lda zp_d+1
    sta @st+2
    ldy zp_rx
    dey
@ld:
    lda $ffff,y
@st:
    sta $ffff,y
    dey
    bpl @ld
    lda zp_d
    clc
    adc zp_rx
    sta zp_d
    bcc @n1
    inc zp_d+1
@n1:
    lda zp_p1
    clc
    adc #3
    sta zp_p1
    bcc @seg
    inc zp_p1+1
    jmp @seg
@done:
    rts
.endif
