; The game's zero page and variables, shared by every platform. (p_sx .. p_xexp are the display registers the logic stages each
; frame in the C64's form; a platform shows them however it can.)
.segment "ZEROPAGE"
p1:         .res 2
p2:         .res 2
p3:         .res 2
p4:         .res 2
p5:         .res 2
cb:         .res 8              ; a cell being made
zc:         .res 1
zl:         .res 1
zt:         .res 1
zk:         .res 1
zs:         .res 1
zm:         .res 1
zd:         .res 1
zv:         .res 1
zr:         .res 1
zf:         .res 1
zy:         .res 1
zx:         .res 1
sa_c:       .res 1              ; the BBC's screen_address, as a cell column and a line
sa_l:       .res 1

.segment "BSS"
tick:       .res 1
last_tick:  .res 1
dt:         .res 1
ready:      .res 1
acc:        .res 1
add:        .res 1
c64_pal:    .res 1
keys:       .res 3              ; the keys held: bit n - 1 of the three bytes is key n
key1:       .res 1              ; the most recently pressed key (0 none), key2 the first pressed that is still held
key2:       .res 1
nchars:     .res 1
level:      .res 1
cur_buf:    .res 1
cur_w:      .res 1
cur_cam:    .res 1
want_cam:   .res 1
mat_w:      .res 2              ; the window of each matrix
mat_c:      .res 2
t_w:        .res 1
t_xs:       .res 1
spos_l:     .res 1
spos_h:     .res 1
spx_l:      .res 1
spx_h:      .res 1
p_sx:       .res 8
p_sy:       .res 8
p_ptr:      .res 8
p_msb:      .res 1
p_en:       .res 1
p_d018:     .res 1
p_d016:     .res 1
p_dd00:     .res 1
p_spr_base: .res 1
p_d010x:    .res 1
p_xexp:     .res 1
overflow:   .res 1
charset_page: .res 1            ; the page of the character set new characters are made in (the C64's; other platforms ignore it)

.include "state.inc"
os_sound_suppression = sound_off
