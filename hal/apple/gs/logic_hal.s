; The logic's side of the contract with the IIgs platform. The platform keeps the keys held in KEYBITS, shows what the logic stages
; and counts `tick` in its own frame loop; there is no sound yet.

; the routines the platform provides, as bank 2 stubs (tramp.s)
frame_wait  = HAL_FRAME         ; until the next frame
wait_frames = HAL_WAIT          ; A frames
hal_store_char = HAL_CHAR       ; character Y has its BBC bytes in BPAT: the display layer converts it
hal_main    = HAL_MAIN          ; the main loop

; hal_scan_keys: the keys held (read_keys has cleared `keys`)
hal_scan_keys:
    lda KEYBITS
    sta keys
    lda KEYBITS + 1
    sta keys + 1
    lda KEYBITS + 2
    sta keys + 2
    rts

; the sound driver's queue counts (sfx.s paces the tune by them); nothing is ever queued
qcnt        = SND + 52

screen_off:
screen_on:
hal_charset_reset:
hal_clear_charset:
snd_init:
snd_flushall:
snd_osword:
    rts

; logic_start: what the C64's `start` does after the hardware (the platform is up, the display layer initialised): the logic's
; tables, then the title screen and a new game (restart_game), then the main loop
logic_start:
    lda #0
    ldx #3
:   sta qcnt,x
    dex
    bpl :-
    jsr init_mirror_table
    lda #>ROWS
    sta rows_page
    lda #5                      ; game steps per 24 / 5 frames: the NTSC rate, 12.5 a second at 60 Hz
    sta add
    lda #0
    sta c64_pal
    jsr clear_buffers
    jsr copy_sprites
    jmp restart_game
