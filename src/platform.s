; C64 platform layer for the BBC game: start-up, hardware set-up, the OS-call shims, and the
; hooks that tell cells.s which cells the game's screen routines changed.

.segment "LOADADDR"
    .word $0801

.segment "STUB"                 ; 10 SYS 32768 (or 34816: ENGINE)
    .word @next
    .word 10
    .byte $9e, .sprintf("%d", ENGINE), 0
@next:
    .word 0

; ------------------------------------------------------------------------------------------------
; start: loaded at ENGINE ($8000, or $8800 with the wide ring). Takes over the machine (no KERNAL/BASIC from here), moves the game's data
; blocks to the addresses the BBC code uses, sets up the display, and starts the game at new_game.
.segment "START"

.import __SOUNDC_LOAD__, __SOUNDC_RUN__, __SOUNDC_SIZE__
.import __D2_0400_LOAD__, __D2_03A0_LOAD__, __D2_0180_LOAD__, __D2_0380_LOAD__, __D2_0300_LOAD__

start:
    sei
    cld
    ldx #$ff
    txs
    lda #$35                    ; RAM everywhere except I/O
    sta $01
    lda #$7f                    ; no CIA interrupts
    sta $dc0d
    sta $dd0d
    lda $dc0d
    lda $dd0d
    lda #0
    sta $d011                   ; screen off while setting up
    sta $d01a
    sta $d015
    lda #<irq_rti               ; vectors (in RAM under the ROMs): NMI does nothing; IRQ is the raster interrupt
    sta $fffa
    lda #>irq_rti
    sta $fffb
    lda #<irq_frame
    sta $fffe
    lda #>irq_frame
    sta $ffff
    lda #<start
    sta $fffc
    lda #>start
    sta $fffd

    ; the game's data blocks, from where the PRG holds them to where the BBC code expects them
    lda #<__D2_0400_LOAD__
    sta zp_p1
    lda #>__D2_0400_LOAD__
    sta zp_p1+1
    lda #<$0400
    sta zp_u
    lda #>$0400
    sta zp_u+1
    ldx #$0d                    ; $0d00 bytes
    jsr copy_pages
    lda #<__D2_03A0_LOAD__
    sta zp_p1
    lda #>__D2_03A0_LOAD__
    sta zp_p1+1
    ldx #$03a0 & 255
    ldy #$03a0 >> 8
    jsr copy_small
    .byte $40                   ; (length, see copy_small)
    lda #<__D2_0180_LOAD__
    sta zp_p1
    lda #>__D2_0180_LOAD__
    sta zp_p1+1
    ldx #<$0180
    ldy #>$0180
    jsr copy_small
    .byte $40
    lda #<__D2_0380_LOAD__
    sta zp_p1
    lda #>__D2_0380_LOAD__
    sta zp_p1+1
    ldx #<$0380
    ldy #>$0380
    jsr copy_small
    .byte $20
    ; the BBC's own start-up wipes $0100-$017f, then moves the last block
    ldx #0
    txa
@wipe:
    sta $0100,x
    inx
    cpx #$80
    bne @wipe
    lda #<__D2_0300_LOAD__
    sta zp_p1
    lda #>__D2_0300_LOAD__
    sta zp_p1+1
    ldx #<$0300
    ldy #>$0300
    jsr copy_small
    .byte $60
    ldx #0                      ; the engine's variables ($0200-$025f) start at zero (RAM is not cleared on a C64)
    txa
@v:
    sta $0200,x
    inx
    cpx #$60
    bne @v
    ldx #8
@kz:
    sta kb_prev,x               ; (A = 0)
    dex
    bpl @kz
    ldx #11
    lda #$ff
@bp:
    sta bl_prev,x               ; no blaster seen yet
    dex
    bpl @bp
    lda #0
    sta level                   ; the BBC code does this too
    sta level_sprite_base
    sta os_sound_suppression    ; permit sound
    lda #$d4
    sta c64_via_ddr_b
    lda #4                      ; vertical camera: ring rows 4-28 (tile rows 1-6 and the top of the floor)
    sta c64_cam
    lda #>MATRIX2               ; the matrix at MATRIX is shown first; the other is built
    sta c64_back
    lda #32                     ; the view: 32 columns at matrix column 4 (until the game window is shown)
    sta c64_vcols
    lda #4
    sta c64_mcol0
    lda #$0c
    sta c64_crtc_high
    lda #0
    sta c64_crtc_low

    jsr detect_pal
    jsr intro_run               ; the loading screens (they use $c000-$ffff, so the sound driver is moved there after them)

    ; the sound driver, to where it runs
    lda #<__SOUNDC_LOAD__
    sta zp_p1
    lda #>__SOUNDC_LOAD__
    sta zp_p1+1
    lda #<__SOUNDC_RUN__
    sta zp_u
    lda #>__SOUNDC_RUN__
    sta zp_u+1
    ldx #>(__SOUNDC_SIZE__ + 255)
    jsr copy_pages
    jsr make_runtime_tables
.if INTRO_PRESENT
.if INTRO_TMAP
    lda #<intro_tmap_c          ; the title screen's map (the intro's unpacker and data are still in memory)
    sta zp_p1
    lda #>intro_tmap_c
    sta zp_p1+1
    lda #<TMAP_SEG
    sta zp_u
    lda #>TMAP_SEG
    sta zp_u+1
    lda #<(TMAP_SEG + INTRO_TMAP_SIZE)
    sta zp_ci
    lda #>(TMAP_SEG + INTRO_TMAP_SIZE)
    sta zp_ci+1
    jsr intro_unpack
    lda #1
    sta c64_tmap_ok
.endif
.endif

    jsr hw_init
    jsr snd_init
    jsr cells_init
    jsr matrix_clear
    ldx #$ff
    txs
    ; the raster interrupt at line $fb: scans the keyboard and joystick every frame, like the BBC's OS,
    ; so the loops that wait for a key without waiting for the frame still see keys
    lda #32
    sta c64_acc                 ; (no frames owed to the 50 Hz yet)
    lda c64_frames
    sta c64_lastf
    lda #$fb
    sta $d012
    lda $d011
    and #$7f
    sta $d011
    lda #$ff
    sta $d019
    lda #$01
    sta $d01a
    cli
    jmp new_game

irq_rti:
    rti

irq_frame:
    pha
    txa
    pha
    tya
    pha
    lda #$ff                    ; acknowledge the VIC-II interrupt
    sta $d019
    inc c64_frames
    lda c64_flip                ; the back matrix is complete (and not being built): show it. The display has
    beq @noflip                 ; just ended (line $fb), so the picture changes between frames
    lda c64_busy
    bne @noflip
    lda c64_back                ; $a8 -> $d018 $a8, $ac -> $b8 (matrix at (high - $80) * 4, charset at $a000)
    asl
    asl
    ora #$08
    sta $d018
    lda c64_back
    eor #(>MATRIX) .bitxor (>MATRIX2) ; the other matrix
    sta c64_back
    lda #0
    sta c64_flip
@noflip:
    lda $d011                   ; the title is 24 rows (RSEL = 0, the window is lines 55-246) with the matrix started at
    and #$f0                    ; line 55 (YSCROLL 7): exactly ring rows 4-27, centred; the rest 25 rows, YSCROLL 3.
    ldx c64_title               ; (Changed after the display, so it takes effect cleanly in the next frame.)
    bne @rows
    ora #$0b
    bne @set
@rows:
    ora #$07
@set:
    sta $d011
    lda c64_frames              ; the keys are scanned every other frame (it takes 1,700 cycles of a 20,000 frame)
    and #1
    bne @noscan
    jsr c64_scan_keys
@noscan:
    jsr snd_frame
    pla
    tay
    pla
    tax
    pla
    rti

; copy_pages: X pages from zp_p1 to zp_u
copy_pages:
    ldy #0
@l:
    lda (zp_p1),y
    sta (zp_u),y
    iny
    bne @l
    inc zp_p1+1
    inc zp_u+1
    dex
    bne @l
    rts

; copy_small: copy the number of bytes in the byte after the JSR, from zp_p1 to Y:X
copy_small:
    stx zp_u
    sty zp_u+1
    pla
    sta zp_v
    pla
    sta zp_v+1                  ; return address - 1
    ldy #1
    lda (zp_v),y                ; the length
    sta zp_t
    ; return past the length byte
    clc
    lda zp_v
    adc #1
    sta zp_v
    bcc @r
    inc zp_v+1
@r:
    ldy #0
@c:
    lda (zp_p1),y
    sta (zp_u),y
    iny
    cpy zp_t
    bne @c
    lda zp_v+1
    pha
    lda zp_v
    pha
    rts

; hw_init: the VIC-II in multicolour character mode, bank 2, charset $a000, matrix $a800
hw_init:
    lda $dd02
    ora #3
    sta $dd02
    lda $dd00
    and #$fc
    ora #1                      ; bank 2 ($8000-$bfff)
    sta $dd00
    lda #$a8                    ; matrix at $a800, charset at $a000
    sta $d018
    lda #$18                    ; multicolour, 40 columns
    sta $d016
    lda #0
    sta $d020
    sta $d021                   ; BBC logical colour 0: black
    lda #2
    sta $d022                   ; 1: red
    lda #3
    sta $d023                   ; 2: cyan; 3 (white) is the character colour below
    ; colour RAM: multicolour on, colour 1 (white) for the fourth pixel value
    ldx #0
    lda #$09
@c:
    sta $d800,x
    sta $d900,x
    sta $da00,x
    sta $db00,x
    inx
    bne @c
    ; charset RAM
    lda #0
    tax
@z:
    sta CHARSET,x
    sta CHARSET+$100,x
    sta CHARSET+$200,x
    sta CHARSET+$300,x
    sta CHARSET+$400,x
    sta CHARSET+$500,x
    sta CHARSET+$600,x
    sta CHARSET+$700,x
    inx
    bne @z
    ; the CIA 1 timer A runs free: the game's source of random numbers
    lda #$ff
    sta $dc04
    sta $dc05
    lda #$01
    sta $dc0e
    lda #$1b                    ; display on
    sta $d011
    rts

.segment "CODE"

; ------------------------------------------------------------------------------------------------
; The OS calls the game makes.
c64_oswrch:
c64_oscli:
    rts

c64_osword:
    jmp snd_osword

c64_osbyte:
    cmp #$13
    beq @vsync
    cmp #$9b
    beq @palette_call
    cmp #$80
    beq @bufstat
    cmp #$0f
    beq @flush
    rts
@vsync:                         ; the game may keep a counter in X or Y across the wait
    pha
    txa
    pha
    tya
    pha
    php
    jsr hw_wait_frame
    jsr c64_present
    jsr hw_after_frame
    plp
    pla
    tay
    pla
    tax
    pla
    rts
@flush:                         ; X = 0: flush all buffers (the sound queues are the ones that matter)
    txa
    bne @fl_rts
    jsr snd_flushall
@fl_rts:
    rts
@bufstat:                       ; X = $fb-$fe: sound channel 0-3: the spaces left in its queue of four
    txa
    clc
    adc #5
    and #3
    tax
    lda #4
    sec
    sbc qcnt,x
    tax
    ldy #0
    rts
@palette_call:                  ; (the game does not expect A, X or Y to change)
    pha
    txa
    pha
    tya
    pha
    jsr @palette
    pla
    tay
    pla
    tax
    pla
    rts
@palette:                       ; X = (palette entry << 4) | BBC colour
    txa
    and #$0f
    tay
    lda bbc_colour_to_c64,y
    sta zp_t
    txa
    lsr
    lsr
    lsr
    lsr                         ; entry 0-15
    tay
    lda palette_logical,y       ; its logical colour 0-3
    beq @l0
    cmp #1
    beq @l1
    cmp #2
    beq @l2
    lda zp_t                    ; logical 3: the colour RAM
    and #7
    ora #8
    ldx #0
@cr:
    sta $d800,x
    sta $d900,x
    sta $da00,x
    sta $db00,x
    inx
    bne @cr
    rts
@l0:
    lda zp_t
    sta $d021
    rts
@l1:
    lda zp_t
    sta $d022
    rts
@l2:
    lda zp_t
    sta $d023
    rts

; BBC physical colours 0-7: black red green yellow blue magenta cyan white
bbc_colour_to_c64:
    .byte 0, 2, 5, 7, 6, 4, 3, 1
; the ULA palette entry (0-15) -> the MODE 5 logical colour it belongs to
palette_logical:
    .byte 0,0,1,1,0,0,1,1,2,2,3,3,2,2,3,3

; ------------------------------------------------------------------------------------------------
; Keys. The game reads two OS variables, os_first_pressed_key ($ed: the oldest key still held) and
; os_most_recently_pressed_key ($ec), holding the BBC's key codes. c64_scan_keys reads the C64
; keyboard and joystick port 2 and keeps those two the same way.
;
;   BBC key   C64 keyboard    joystick 2     does
;   Z / X     Z / X           left / right   walk
;   *  /      ;  /            up / down      up (climb, lift) / down (kneel, crawl)
;   RETURN    RETURN          fire           jump (with Z or X held: sideways)
;   ]         =                              fire the blaster
;   A / J     A / J                          wrist terminal / jet pack screen
;   D / O     D / O                          drop a mine / leave the jet pack
;   COPY,DEL  P, DEL                         pause, resume
;   TAB       CTRL                           lose a life
;   ESCAPE    RUN/STOP                       give up
;   f0 / f1   F1 / F3                        sound off / on
;   S B M SPACE                              the terminal screen's own keys
; An entry is: keyboard column (the bit that is 0 in $dc00), row mask, the BBC code, the ASCII.
KEY_JOY_UP      = $c8
KEY_JOY_DOWN    = $e8
KEY_JOY_LEFT    = $e1
KEY_JOY_RIGHT   = $c2
KEY_JOY_FIRE    = $c9

NKEYS = 21
keytab:
    .byte 1, $10, $e1, 'Z'      ; Z
    .byte 2, $80, $c2, 'X'      ; X
    .byte 6, $04, $c8, ';'      ; ; = up
    .byte 6, $80, $e8, '/'      ; /
    .byte 0, $02, $c9, $0d      ; RETURN
    .byte 6, $20, $d8, '='      ; = = fire the blaster
    .byte 7, $10, $e2, ' '      ; SPACE
    .byte 1, $04, $c1, 'A'      ; A
    .byte 4, $04, $c5, 'J'      ; J
    .byte 1, $20, $90, 'S'      ; S
    .byte 3, $10, $91, 'B'      ; B
    .byte 4, $10, $92, 'M'      ; M
    .byte 2, $04, $b2, 'D'      ; D
    .byte 4, $40, $b6, 'O'      ; O
    .byte 5, $02, $e9, 'P'      ; P = COPY
    .byte 0, $01, $d9, $14      ; DEL = DELETE
    .byte 7, $04, $e0, 0        ; CTRL = TAB
    .byte 7, $80, $f0, 3        ; RUN/STOP = ESCAPE
    .byte 0, $10, $a0, 0        ; F1 = f0
    .byte 0, $20, $f1, 0        ; F3 = f1
    .byte 3, $80, $e3, 'V'      ; V (the loading screens' controls page; the game has no use for the code)

colsel:
    .byte $fe, $fd, $fb, $f7, $ef, $df, $bf, $7f

c64_scan_keys:
    ; ---- joystick 2 (port A of CIA 1, read with the lines as inputs) ----
    lda #0
    sta $dc02
    lda $dc00
    sta kb_joy
    lda #$ff
    sta $dc02
    ; ---- keyboard: the rows for each column ----
    ldx #7
@col:
    lda colsel,x                ; a 0 bit in column X
    sta $dc00
    lda $dc01
    sta kb_rows,x
    dex
    bpl @col
    lda #$ff
    sta $dc00
    ; ---- nothing pressed or released since the last scan: the held keys are as they were (this is most scans:
    ; it saves 1,500 of the interrupt's cycles) ----
    ldx #7
@same:
    lda kb_rows,x
    cmp kb_prev,x
    bne @changed
    dex
    bpl @same
    lda kb_joy
    cmp kb_prev + 8
    bne @changed
    rts
@changed:
    ldx #7
@save:
    lda kb_rows,x
    sta kb_prev,x
    dex
    bpl @save
    lda kb_joy
    sta kb_prev + 8
    ; ---- which codes are down, in table order (kb_new) ----
    lda #0
    sta kb_nnew
    ldy #0                      ; table offset
@ent:
    ldx keytab,y                ; column
    lda kb_rows,x
    and keytab+1,y
    bne @next                   ; 1 = not pressed
    lda keytab+2,y
    jsr @add
@next:
    iny
    iny
    iny
    iny
    cpy #NKEYS*4
    bne @ent
    ; joystick: bits 0-4 = up, down, left, right, fire; 0 = pressed
    lda kb_joy
    and #$01
    bne @j1
    lda #KEY_JOY_UP
    jsr @add
@j1:
    lda kb_joy
    and #$02
    bne @j2
    lda #KEY_JOY_DOWN
    jsr @add
@j2:
    lda kb_joy
    and #$04
    bne @j3
    lda #KEY_JOY_LEFT
    jsr @add
@j3:
    lda kb_joy
    and #$08
    bne @j4
    lda #KEY_JOY_RIGHT
    jsr @add
@j4:
    lda kb_joy
    and #$10
    bne @merge
    lda #KEY_JOY_FIRE
    jsr @add
@merge:
    ; ---- the keys still held, oldest first, then the newly pressed ones ----
    ; (a new key's ASCII is kept for OSRDCH)
    ldx #0                      ; X = index into the old held list
    ldy #0                      ; Y = number kept (written back over the list)
@keep:
    cpx kb_nheld
    beq @addnew
    stx kb_tmp
    lda kb_held,x
    jsr @innew                  ; clobbers X
    bne @drop
    ldx kb_tmp
    lda kb_held,x
    sta kb_held,y
    iny
@drop:
    ldx kb_tmp
    inx
    jmp @keep
@addnew:
    sty kb_nheld
    ldx #0
@nl:
    cpx kb_nnew
    beq @done
    lda kb_new,x
    stx kb_tmp
    jsr @inheld                 ; Z set if it is already held
    bne @isnew
    ldx kb_tmp
    inx
    jmp @nl
@isnew:
    ldx kb_tmp
    lda kb_new,x
    ldy kb_nheld
    cpy #4
    bcs @full
    sta kb_held,y
    inc kb_nheld
    ; ASCII of the first newly pressed key, for OSRDCH
    lda kb_ascii
    bne @full
    lda kb_new,x
    jsr @ascii_of
    sta kb_ascii
@full:
    ldx kb_tmp
    inx
    jmp @nl
@done:
    ; ---- the two OS variables ----
    lda kb_nheld
    beq @none
    lda kb_held
    sta os_first_pressed_key
    ldx kb_nheld
    lda kb_held-1,x
    sta os_most_recently_pressed_key
    rts
@none:
    lda #0
    sta os_first_pressed_key
    sta os_most_recently_pressed_key
    rts

; @add: append the code in A to kb_new (at most 12)
@add:
    ldx kb_nnew
    cpx #12
    bcs @addret
    sta kb_new,x
    inc kb_nnew
@addret:
    rts
; @innew: is the code in A in kb_new? Z = 0 if not found... returns Z clear (bne) if NOT found
@innew:
    ldx #0
@in1:
    cpx kb_nnew
    beq @notfound
    cmp kb_new,x
    beq @found
    inx
    jmp @in1
@found:
    lda #0                      ; Z set: found
    rts
@notfound:
    lda #1                      ; Z clear: not found
    rts
; @inheld: is the code in A in kb_held? Z set if found
@inheld:
    ldx #0
@ih1:
    cpx kb_nheld
    beq @ihno
    cmp kb_held,x
    beq @ihyes
    inx
    jmp @ih1
@ihyes:
    lda #0
    rts
@ihno:
    lda #1
    rts
; @ascii_of: the ASCII for the BBC code in A (0 if none)
@ascii_of:
    ldy #0
@ao:
    cmp keytab+2,y
    beq @aofound
    iny
    iny
    iny
    iny
    cpy #NKEYS*4
    bne @ao
    lda #0
    rts
@aofound:
    lda keytab+3,y
    rts

; scrolling right (see make_game_source.py): wait for the frame as @vsync does, but leave the display update
; to c64_scroll_end
c64_wait_deferred:
    pha
    txa
    pha
    tya
    pha
    php
    jsr hw_wait_frame
    lda #1
    sta c64_defer
    plp
    pla
    tay
    pla
    tax
    pla
    rts

; what `delay` leaves behind (the title scroll's per-step busy-wait is not wanted here)
c64_scroll_delay:
    lda c64_hide_ok             ; the title's scroll (40-cell build): when the letters have gone by and the old frame starts to slide
    beq @shown                  ; in (the last 33 steps), the screen is blanked: the title that follows is arranged differently
    lda scroll_count
    cmp #34
    bcs @shown
    jsr c64_video_off
@shown:
.if RING_W <> 32
    lda scroll_count            ; The title scroll's last RING_W - 32 steps draw the columns beyond the 32 the title shows
    cmp #(RING_W - 32) + 1      ; (it crops the window): the first screen of the game starts with the leftmost of them,
    bcs @tile                   ; so they take the game's tile set (as the scroll after SPACE does) instead of the title's
    lda #0
    sta level_sprite_base
@tile:
.endif
    lda #3
    sta delay_length
    sta delay_high
    lda #0
    sta delay_low
    rts

c64_scroll_end:
    jsr update_jet_pack
    lda c64_defer
    beq @r
    lda #0
    sta c64_defer
    lda player_swapping_sides_on_rope ; the title's scroll (and the one onto the first level) is too heavy for a step a
    beq @show                   ; frame: update the display every other step (the cells of two steps are processed once,
    lda c64_skip                ; the matrix is rebuilt once)
    eor #1
    sta c64_skip
    bne @r
@show:
    jsr c64_present
    jsr hw_after_frame
@r:
    rts

; the wrist terminal waits for a key (ASCII), keeping the display running; the interrupt's scan latches
; the first newly pressed key's ASCII in kb_ascii
c64_osrdch:
@w:
    jsr hw_wait_frame
    jsr c64_present
    sei
    lda kb_ascii
    ldx #0
    stx kb_ascii
    cli
    cmp #0
    beq @w
    clc
    rts

; (nothing: the headless tests hook the end of a frame's work here)
hw_after_frame:
    rts

; Wait for the next vertical blank. The BBC runs at 50 Hz and the game counts vertical blanks, so on a
; 60 Hz (NTSC) C64 a wait sometimes takes an extra frame: 5 waits = 6 frames = 5/50 s. c64_acc keeps the
; account in fifths of a frame (plus 32, so that it never goes below zero): each wait adds 6 and each frame that really passed (the raster
; interrupt counts them) takes 5 off; while it stands at a whole frame or more, wait one more. A game loop that
; is already late (more than one frame between waits) therefore owes nothing, and never waits extra.
hw_wait_frame:
    lda c64_lastf               ; wait until a frame has passed since the last return: none to wait for if the work
@w1:                            ; since then took longer than a frame (the game never idles when it is late)
    cmp c64_frames
    beq @w1
    lda c64_pal
    bne @ret
    lda c64_frames              ; frames since the last return (0 if the interrupt is masked: count 1)
    sec
    sbc c64_lastf
    bne @f1
    lda #1
@f1:
    cmp #4
    bcc @f2
    lda #3
@f2:
    tax
    lda c64_acc
    clc
    adc #6
@sub:
    sec
    sbc #5
    dex
    bne @sub
    cmp #22                     ; (never more than 10 fifths behind: 22 = -10 + 32)
    bcs @ex
    lda #22
@ex:
    cmp #37                     ; 5 fifths = a whole frame owed (37 = 5 + 32)
    bcc @done
    sbc #5                      ; (carry is set)
    pha
    jsr @vblank                 ; (a whole extra frame, from now)
    pla
    jmp @ex
@done:
    sta c64_acc
@ret:
    lda c64_frames
    sta c64_lastf
    rts
@vblank:                        ; the next raster interrupt (line $fb) has run: its frame count moved. (Waiting for a raster
    lda c64_frames              ; line instead is a race: the interrupt, which takes longer than a line, can come
@w:                             ; while we wait for the line after it, and then the line has passed for good.)
    cmp c64_frames
    beq @w
    rts

; make_runtime_tables: the lookup tables, made rather than carried (about 1,000 bytes of the PRG; tools/make_tables.py
; has the same in Python and tools/test_tables.py compares them)
make_runtime_tables:
    ldx #0
@t:
    stx zp_t                    ; bbc_to_c64: the MODE 5 byte's pixels (bit 7-n and bit 3-n) as pairs of bits, leftmost first
    txa
    asl
    asl
    asl
    asl
    sta zp_v
    lda #0
    ldy #4
@k: asl zp_t
    rol
    asl zp_v
    rol
    dey
    bne @k
    sta bbc_to_c64,x
    lda #0                      ; chandelier_class: 1 = low nibble 8, 2 = high nibble 8
    sta zp_u
    txa
    and #$0f
    cmp #8
    bne @n1
    lda #1
    sta zp_u
@n1:
    txa
    and #$f0
    cmp #$80
    bne @n2
    lda zp_u
    ora #2
    sta zp_u
@n2:
    lda zp_u
    sta chandelier_class,x
    txa                         ; hash_tab: steps that are each a permutation, so it is one
    asl
    asl
    clc
    stx zp_u + 1
    adc zp_u + 1
    clc
    adc #17                     ; x * 5 + 17
    sta zp_u
    lsr
    lsr
    lsr
    eor zp_u                    ; y ^ y >> 3
    sta zp_u
    asl
    asl
    asl
    clc
    adc zp_u
    clc
    adc #101                    ; y * 9 + 101
    sta zp_u
    asl
    asl
    eor zp_u                    ; y ^ y << 2
    sta hash_tab,x
    sta zp_u                    ; star_random: the hash mixed with x rotated left 3
    txa
    asl
    asl
    asl
    sta zp_v
    txa
    lsr
    lsr
    lsr
    lsr
    lsr
    ora zp_v
    eor zp_u
    sta star_random,x
    inx
    beq @e
    jmp @t
@e: rts

; detect_pal: watch the raster for a few frames; a PAL machine reaches line $120 or more
detect_pal:
    lda #0
    sta c64_pal
    tax
    tay
@l:
    lda $d011
    bpl @n
    lda $d012
    cmp #$20
    bcc @n
    lda #1
    sta c64_pal
@n:
    inx
    bne @l
    iny
    cpy #$20
    bne @l
    rts

; (reading $d011 gives the raster line's bit 8 in bit 7, and writing it back sets the raster interrupt's compare line's bit 8: done
; while the beam was below line 255 it would move the interrupt to line $1fb, where it never comes: so bit 7 is cleared)
c64_video_off:
    lda $d011
    and #$6f
    sta $d011
    rts

c64_video_on:
    lda $d011
    ora #$10
    and #$7f
    sta $d011
    rts

; ------------------------------------------------------------------------------------------------
; The hooks. The BBC game draws by writing into its screen buffer; each of these replaces the first
; four bytes of a drawing routine (a JMP and a spare byte, so no address in the game moves), runs the
; instructions it displaced, calls the rest of the routine, and then tells cells.s which cells that
; covered. They return to the routine's own caller with A, X, Y and the flags as the routine left them.

; sprite-like routines are entered with X = width in cells, Y = height in lines, and the top left of
; the sprite in screen_address; rows are counted from the line within the cell
.macro SPRITE_HOOK name, body
name:
    stx width
    sty height
    jsr hook_prepare
    jsr body
    jmp hook_finish_sprite
.endmacro

SPRITE_HOOK c64_hook_sprite, plot_sprite_body
SPRITE_HOOK c64_hook_fenemy, plot_flipped_enemy_body
; (-D NOFASTPLAYER: the BBC's loops, to compare speeds)
.if .defined(NOFASTPLAYER) .or .defined(HOOKORIG)
SPRITE_HOOK c64_hook_uplayer, plot_unflipped_player_body
SPRITE_HOOK c64_hook_fplayer, plot_flipped_player_body
.else
SPRITE_HOOK c64_hook_uplayer, fast_uplayer_body
SPRITE_HOOK c64_hook_fplayer, fast_fplayer_body
.endif

; ------------------------------------------------------------------------------------------------
; The player's sprite, faster. plot_unflipped_player_body and plot_flipped_player_body (the BBC's loops, still in the game
; and used for other widths) take about 160 cycles for each pixel row of a 3-cell sprite, mostly in the address sums. These
; do the same writes a cell at a time: the three cells of a row are addressed by three self-modified absolute stores,
; the line within the cell is the index register, and the sums are made once per cell (every 8 rows). They leave
; what the originals leave behind - the screen addresses, $72, height, the self-modified sprite address - because the game
; (and the differential tests) can see it. Only width 3 is done here; anything else goes to the original.
;   FASTPLAYER flipped: in: width, height (1-85), screen_address ($70/1), $72/$73 the sprite
.macro FASTPLAYER flipped, orig, op_lo, op_hi
    .local L_o, L_go, L_adv, L_c1, L_c1w, L_c2, L_c2w, L_chunk, L_done, L_end, L_fl, L_nowrap, L_nxt, L_ok1, L_ok2, L_row, L_slow
    .local SA0, SA1, SA2, DC0, DC1, DC2
    lda width
    cmp #3
    bne L_o
    lda height
    beq L_o
    cmp #86
    bcc L_go
L_o:
    jmp orig
L_go:
    sta zp_h                    ; the height (the rows left are counted in zp_c)
    sta zp_c
    ; the sprite's three columns (the flipped plot writes them in the other order)
    lda $72
    sta SA0 + 1
    lda $73
    sta SA0 + 2
    clc
    lda $72
    adc #1
    sta SA1 + 1
    lda $73
    adc #0
    sta SA1 + 2
    clc
    lda $72
    adc #2
    sta SA2 + 1
    lda $73
    adc #0
    sta SA2 + 2
    lda screen_address_low      ; the first row's cell, and its line within the cell
    and #$f8
    sta zp_p1
    lda screen_address_high
    sta zp_p1+1
    lda screen_address_low
    and #7
.if flipped
    sta zp_oc
.else
    tax
.endif
    ldy #0
L_chunk:                         ; the cells of the rows from the line in zp_oc / X to the end of the cell, or the sprite
    lda zp_p1+1
    cmp #$7f
    beq L_slow                   ; (the cells could wrap round the end of the ring)
    sta DC0 + 2
    clc
    lda zp_p1
    sta DC0 + 1
    adc #8
    sta DC1 + 1
    lda zp_p1+1
    adc #0
    sta DC1 + 2
    clc
    lda zp_p1
    adc #16
    sta DC2 + 1
    lda zp_p1+1
    adc #0
    sta DC2 + 2
    jmp L_nowrap
L_slow:
    sta DC0 + 2
    lda zp_p1
    sta DC0 + 1
    clc
    adc #8
    sta DC1 + 1
    lda #$7f
    adc #0
    cmp #$80
    bcc L_c1w
    lda #RING_HI
L_c1w:
    sta DC1 + 2
    clc
    lda zp_p1
    adc #16
    sta DC2 + 1
    lda #$7f
    adc #0
    cmp #$80
    bcc L_c2w
    lda #RING_HI
L_c2w:
    sta DC2 + 2
L_nowrap:
    ; this chunk's rows: lines up to zp_t = min(8, line + rows left)
.if flipped
    lda zp_oc
.else
    txa
.endif
    clc
    adc zp_c
    cmp #8
    bcc L_fl
    lda #8
L_fl:
    sta zp_t
    sec
.if flipped
    sbc zp_oc
.else
    stx zp_u
    sbc zp_u
.endif
    sta zp_u                    ; the number of rows in the chunk
    lda zp_c
    sec
    sbc zp_u
    sta zp_c
L_row:
.if flipped
SA2:
    lda $ffff,y
    tax
    lda flip_table,x
    ldx zp_oc
DC0:
    sta $ffff,x
SA1:
    lda $ffff,y
    tax
    lda flip_table,x
    ldx zp_oc
DC1:
    sta $ffff,x
SA0:
    lda $ffff,y
    tax
    lda flip_table,x
    ldx zp_oc
DC2:
    sta $ffff,x
    iny
    iny
    iny
    inc zp_oc
    lda zp_oc
    cmp zp_t
    bne L_row
.else
SA0:
    lda $ffff,y
DC0:
    sta $ffff,x
SA1:
    lda $ffff,y
DC1:
    sta $ffff,x
SA2:
    lda $ffff,y
DC2:
    sta $ffff,x
    iny
    iny
    iny
    inx
    cpx zp_t
    bne L_row
.endif
    lda zp_c
    beq L_done
    clc                         ; the next row of cells
    lda zp_p1
    adc #<STRIDE
    sta zp_p1
    lda zp_p1+1
    adc #>STRIDE
    cmp #$80
    bcc L_ok1
    sec
    sbc #RING_SZ_HI
L_ok1:
    sta zp_p1+1
.if flipped
    lda #0
    sta zp_oc
.else
    ldx #0
.endif
    jmp L_chunk
L_done:
    ; what the BBC's loops leave behind: the last row's address, and the screen address after its three cells
.if flipped
    lda zp_oc
    sec
    sbc #1
.else
    txa
    sec
    sbc #1
.endif
    ora zp_p1
    sta column_screen_address_low
    clc
    adc #24
    sta screen_address_low
    lda zp_p1+1
    sta column_screen_address_high
    adc #0
    cmp #$80
    bcc L_ok2
    lda #RING_HI
L_ok2:
    sta screen_address_high
    lda #0
    sta height
    lda zp_h                    ; $72 + 3 * (height - 1), and the sprite address the loops had patched in
    sec
    sbc #1
    sta zp_u
    asl
    clc
    adc zp_u
    clc
    adc $72
    sta $72
    sta op_lo
    lda $73
    adc #0
    sta op_hi
    ldy #0
.if flipped
    ldx #0
.else
    ldx #3
.endif
    rts
.endmacro

.ifndef NOFASTPLAYER
fast_uplayer_body:
    FASTPLAYER 0, plot_unflipped_player_body, unflipped_player_sprite_address_low, unflipped_player_sprite_address_high

fast_fplayer_body:
    FASTPLAYER 1, plot_flipped_player_body, flipped_player_sprite_address_low, flipped_player_sprite_address_high
.endif

hook_prepare:
    stx hk_cols
    lda screen_address_low
    sta hk_lo
    lda screen_address_high
    sta hk_hi
    tya
    cmp #$ff                    ; plot_vertically_flipped_sprite: height $ff, the real one in sprite_offset
    bne @l
    lda sprite_offset
    clc
    adc #1
@l:
    sta hk_lines
    rts

hook_finish_sprite:
    php
    pha
    txa
    pha
    tya
    pha
    lda hk_hi
    ldx hk_lo
    jsr addr_to_cell
    lda hk_lo
    and #7
    clc
    adc hk_lines
    adc #7
    lsr
    lsr
    lsr
    beq @out                    ; no lines
    sta zp_ry
    lda hk_cols
    beq @out
    sta zp_rx
    jsr mark_rect
@out:
    pla
    tay
    pla
    tax
    pla
    plp
    rts

; plot_column_of_tiles: a column of 8 tiles = 32 cells down, from screen_address
c64_hook_column:
    lda screen_address_low
    sta hk_lo
    lda screen_address_high
    sta hk_hi
    lda #1
    sta hk_cols
    lda #32
    sta hk_lines
    lda #$00                    ; (displaced)
    sta $76                     ; tile_y
    jsr plot_column_of_tiles_loop
    jmp hook_finish_cells

; plot_row_of_tiles: a row of tiles across the window = RING_W cells
c64_hook_row:
    lda screen_address_high
    sta hk_hi
    lda screen_address_low
    and #$f8                    ; the row starts on a cell boundary
    sta hk_lo
    lda #RING_W
    sta hk_cols
    lda #1                      ; one cell row
    sta hk_lines
    lda #$00                    ; (displaced)
    sta $76                     ; tile_x
    jsr plot_row_of_tiles_loop
    jmp hook_finish_cells

; as hook_finish_sprite, but hk_lines is a number of cell rows (the area starts on a cell boundary)
hook_finish_cells:
    php
    pha
    txa
    pha
    tya
    pha
    lda hk_hi
    ldx hk_lo
    jsr addr_to_cell
    lda hk_lines
    sta zp_ry
    lda hk_cols
    sta zp_rx
    jsr mark_rect
    pla
    tay
    pla
    tax
    pla
    plp
    rts

; the star plot: lda #$88 / sta (screen_address),y with Y = 0
c64_star_store:
    lda #$88
    sta (screen_address),y
    lda screen_address_high
    ldx screen_address_low
    jsr addr_to_cell
    jmp mark_cell

; the BBC's initialise_variables wipes zero page from $00; here $00-$03 are $e4-$e7
c64_wipe_enemy_zp:
    lda #0
    sta $e4
    sta $e5
    sta $e6
    sta $e7
    tax
    rts

; clear_screen: wipe the ring, and everything derived from it
c64_clear_screen:
    lda #RING_HI
    sta screen_address_high
    lda #$00
    sta screen_address_low
    tay
@l:
    sta (screen_address),y
    iny
    bne @l
    inc screen_address_high
    bpl @l
    jsr cells_reset
    jsr matrix_clear
    lda #0
    tay
    rts

; ------------------------------------------------------------------------------------------------
; update_chandeliers, faster: the same scan of the level page (4 bytes a column, 64 columns; each byte holds
; two tiles, the low nibble the even tile_y), calling replot_tile with the same arguments in the same
; order for every chandelier (NIBBLE_SHRINE_CHANDELIER = 8), and ending in the same state ($e4-$e7 are
; tile_address low/high, tile_x and tile_y). zp_p1 keeps the index across replot_tile.
c64_update_chandeliers:
    lda left_edge_tile_address_high
    sta $e5                     ; tile_address_high
    lda #0
    sta $e4
    tay
@scan:
    lda ($e4),y
    tax
    lda chandelier_class,x
    bne @hit
@next:
    iny
    bne @scan
    lda #0                      ; as the original leaves it
    sta $e4
    sta $e7
    lda #$40
    sta $e6
    rts
@hit:
    sty zp_p1                   ; the index
    tya
    lsr
    lsr
    sta $e6                     ; tile_x = index / 4
    tya
    and #3
    asl
    sta $e7                     ; tile_y = 2 * (index mod 4)
    lda chandelier_class,x
    and #1                      ; the bottom (even) tile
    beq @top
    lda #8
    ldx $e6
    ldy $e7
    jsr replot_tile
@top:
    ldy zp_p1
    lda ($e4),y                 ; (the original reads the byte again here)
    tax
    lda chandelier_class,x
    and #2                      ; the top (odd) tile
    beq @resume
    ldy $e7
    iny
    sty $e7
    lda #8
    ldx $e6
    ldy $e7
    jsr replot_tile
@resume:
    ldy zp_p1
    jmp @next

; ------------------------------------------------------------------------------------------------
; Which screen is up (see cells.s camera_update). Each is entered by a patched instruction in the game.
c64_game_mode:                  ; at the top of main_game_loop; returns A = the BBC's VIA DDR value
    lda #1
    sta c64_gamemode
    lda #0
    sta c64_title
    sta c64_tmap
    txa
    pha
    tya
    pha
    jsr c64_view_full
    pla
    tay
    pla
    tax
    lda c64_via_ddr_b
    rts

; The view: c64_vcols columns of the ring's window in matrix columns c64_mcol0 on. Play shows the whole window (RING_W
; columns, centred); every other screen is drawn in the leftmost 32 columns, centred. A change forces a rebuild.
c64_view_crop:
    ldx #32
    ldy #4
    bne c64_set_view
c64_view_full:
    ldx #RING_W
    ldy #(40 - RING_W) / 2
c64_set_view:
    cpx c64_vcols
    bne @change
    cpy c64_mcol0
    beq @same
@change:
    stx c64_vcols
    sty c64_mcol0
    lda #$ff
    sta zp_vb+1                 ; (no view base is that: the matrix is rebuilt)
    jsr matrix_clear
@same:
    rts

.if RING_W <> 32
; the title screen, once its scroll is over: shown through the title map (see cells.s) if it was made
c64_title_static:
    lda c64_tmap_ok
    beq @show
    lda c64_tmap
    bne @show
    lda #1
    sta c64_tmap
    ldx #40                     ; the whole width, from matrix column 0
    ldy #0
    jsr c64_set_view
    lda #$ff
    sta zp_vb+1                 ; (rebuild the matrix, even if the view's size is what it was)
    jsr matrix_clear
    lda #$13                    ; the screen is still blank: a frame to make the matrix, one more for the interrupt to swap to it
    jsr c64_osbyte
    lda #$13
    jsr c64_osbyte
@show:
    lda #0
    sta c64_hide_ok
    jmp c64_video_on

; the space bar on the title screen (patched in for its call of flush_buffers): back to the ordinary view for the scroll onto
; the first level
c64_leave_title:
    lda c64_tmap
    beq @f
    lda #0
    sta c64_tmap
    jsr c64_view_crop
@f: jmp flush_buffers
.endif

c64_title_mode:
    lda #0
    sta c64_gamemode
    sta c64_tmap
    lda #1
    sta c64_title
    jsr c64_view_crop
    jmp reset_tiles

c64_status_mode:
    lda #0
    sta c64_gamemode
    sta c64_tmap
    sta c64_title
    jsr c64_view_crop
    jmp set_colour_zero_to_black

c64_gameover_mode:
    lda #0
    sta c64_gamemode
    sta c64_title
    sta c64_tmap
    jsr c64_view_crop
    jmp game_over_screen
