import sys,os; sys.path.insert(0,'/home/peter/retro/ports/CodeNameDroid/c64/tools')
from c64sim import C64, render_screen
from bbcsim import BBC, KEYS
c=C64(); b=BBC()
c.m[0xf9]=1; b.m[0xf9]=1
b.m[0xe400:0xe500]=bytes(__import__('make_tables').star_table())
def hold(names):
    c.held=[KEYS[k] for k in names]; c.apply_keys(); b.set_keys(*names)
for f in range(700):
    hold(['J'] if 140<=f<146 else (['Z'] if 450<=f<600 else []))
    c.run_frames(1); b.run_frames(1)
    if f in (300,449,520,599): 
        m=c.m; print(f'f{f}: level {m[0x9f]} x {m[0x93]} | C64 cycles/vsync {c.frame_cycles[-1]}  BBC {b.frame_cycles[-1]}')
        render_screen(c,2).save(f'/home/peter/retro/ports/CodeNameDroid/build/c64/shots/shrine_{f}.png')
fc=c.frame_cycles; fb=b.frame_cycles
for a,z,label in ((300,450,'idle'),(450,600,'walking left (scrolling)')):
    srt=lambda v: sorted(v)
    med=lambda v: sorted(v)[len(v)//2]; p90=lambda v: sorted(v)[int(len(v)*0.9)]
    print(f'   median: C64 {med(fc[a:z])} BBC {med(fb[a:z])};  90th percentile: C64 {p90(fc[a:z])} BBC {p90(fb[a:z])}')
    print(f'{label:26s} C64 avg {sum(fc[a:z])//(z-a):6d} max {max(fc[a:z]):6d} | BBC avg {sum(fb[a:z])//(z-a):6d} max {max(fb[a:z]):6d}   (per vsync interval; NTSC frame = 17095, PAL 19656)')
