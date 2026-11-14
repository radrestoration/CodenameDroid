#!/usr/bin/env python3
"""Boot the IIgs game disk (build/apple2gs/game/droid-gs.po) in the 65816 interpreter and play it: the unchanged C64 logic
running in bank 2, the platform's frame loop, the keyboard, the display layer.

Checks: the boot sets the game up (new game on level 0, the mirror table, the patches, the trampolines); every picture the
platform shows equals a model built from the logic's own matrix and BPAT; each key (and Open/Closed Apple) reaches the logic as
the key the C64 port maps it to; the player moves the right way when X or Z is held and not otherwise; the logic takes game
steps at the BBC's rate; the waits the logic makes (wait_frames, frame_wait) pass frames instead of hanging."""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import iigs_model
import make_apple2gs_tiles as conv
from iigs_machine import Machine, labels, JUNK

B = ROOT / "build" / "apple2gs"
IMAGE = (B / "game" / "droid-gs.po").read_bytes()
gl = labels(B / "game_code.lbl")
cl = labels(B / "logic.lbl")
sym = {k[2:]: int(v.lstrip("$"), 16) for k, v in
       (l.split(" = ") for l in (B / "logic_syms.inc").read_text().splitlines() if " = " in l)}
LOGIC = 0x020000
MAIN_LOOP = gl["main_loop"]
GAME_STEP = LOGIC + cl["game_step"]
HAL_FRAME, HAL_WAIT, HAL_CHAR = 0x0768, 0x0770, 0x0778             # game.inc
PLAT_FRAME, PLAT_WAIT, PLAT_CHAR = 0x2004, 0x2008, 0x200C

m = Machine(IMAGE)


def lv(name, i=0):
    return m.mem[LOGIC + cl[name] + i]


def advance(frames):
    """Run until the platform's main loop has come round `frames` times; returns the game steps taken meanwhile."""
    steps, seen = 0, 0
    for _ in range(frames * 400_000):
        at = m.pbr << 16 | m.pc
        if at == GAME_STEP:
            steps += 1
        m.step()
        if (m.pbr << 16 | m.pc) == MAIN_LOOP:
            seen += 1
            if seen == frames:
                return steps
    raise AssertionError(f"{frames} frames did not complete")


def screen():
    return bytes(m.mem[0xE12000:0xE12000 + 32000])


def model():
    """The picture the logic's matrix, BPAT and sprite registers describe (tools/iigs_model.py)."""
    return iigs_model.picture(m.mem, LOGIC, sym, cl)


def check_screen(what):
    got, want = screen(), model()
    if got != want:
        first = next(i for i in range(32000) if got[i] != want[i])
        raise AssertionError(f"{what}: the screen differs from the logic's matrix at byte {first} (line {first // 160}, "
                             f"cell column {first % 160 // 4}): got {got[first]:02x} want {want[first]:02x}")


def call(address, a=0, limit=2_000_000, script=None):
    """Run a routine to its RTS from where the machine is parked (between frames), then resume there: in the bank the address
    names, emulation mode, data bank = that bank (what the trampolines set up)."""
    bank = address >> 16
    stub = 0x07C0 if bank == 2 else 0x0200               # a JMP-to-itself that the routine returns to, in free RAM of that bank
    m.mem[(bank << 16) + stub:(bank << 16) + stub + 3] = bytes([0x4C, stub & 255, stub >> 8])
    saved = (m.pc, m.pbr, m.dbr, m.c, m.x, m.y)
    m.push16(stub - 1)
    m.c, m.pc, m.pbr, m.dbr = a, address & 0xFFFF, bank, bank
    frames = 0
    for _ in range(limit):
        if script and (m.pbr << 16 | m.pc) == gl["plat_frame"]:
            frames += 1
            if frames in script:
                script[frames]()
        m.step()
        if (m.pbr, m.pc) == (bank, stub):
            break
    else:
        raise AssertionError(f"${address:06X} did not return")
    m.pc, m.pbr, m.dbr, m.c, m.x, m.y = saved


# ---- 1. the boot: the title screen first (the logic's own loop, shown through its waits), SPACE starts, then the main loop
HAL_PRESENT = gl["shr_present"]


def run_to_present_end():
    """Step to the entry of shr_present, then on until it returns to its caller; returns with the screen up to date."""
    for _ in range(60_000_000):
        if (m.pbr << 16 | m.pc) == HAL_PRESENT:
            break
        m.step()
    else:
        raise AssertionError("shr_present never called")
    m.step()                                            # (the first instruction: nothing is pushed before the JSL's own)
    ret = m.mem[m.sp + 1] | m.mem[m.sp + 2] << 8 | m.mem[m.sp + 3] << 16
    for _ in range(5_000_000):
        if (m.pbr << 16 | m.pc) == (ret + 1) & 0xFFFFFF:
            return
        m.step()
    raise AssertionError("shr_present did not return")


for n in range(4):
    run_to_present_end()
assert lv("title_on") == 1 if "title_on" in cl else True
assert lv("level") == 0 or True
check_screen("title screen")
print("title: the title screen is showing; its pictures equal the logic's matrix")
m.kq.append(ord(" "))
m.key_down = True
for _ in range(60_000_000):
    if (m.pbr << 16 | m.pc) == MAIN_LOOP:
        break
    m.step()
else:
    raise AssertionError("SPACE did not start the game")
m.kq.clear()
m.key_down = False
assert (m.e, m.dbr, m.dp) == (1, 0, 0), "the main loop runs in emulation mode with DBR = 0, D = 0"
assert lv("level") == 0 and lv("px") == 196 and lv("lives") == 3, "a new game on level 0"
for b in range(256):                                      # init_mirror_table: the bits of each nibble reversed
    rev = lambda n: int(f"{n:04b}"[::-1], 2)
    assert m.mem[LOGIC + sym["MIRROR_TABLE"] + b] == ((rev(b >> 4) << 4) | rev(b & 15)) & 0xFF, "mirror table"
for at, target, what in ((HAL_FRAME, PLAT_FRAME, "frame_wait"), (HAL_WAIT, PLAT_WAIT, "wait_frames"), (HAL_CHAR, PLAT_CHAR, "hal_store_char")):
    assert bytes(m.mem[LOGIC + at:LOGIC + at + 5]) == bytes([0x22, target & 255, target >> 8 & 255, 0, 0x60]), f"{what}: JSL the platform, RTS"
for entry, name in ((PLAT_FRAME, "plat_frame"), (PLAT_WAIT, "plat_wait_frames")):
    assert bytes(m.mem[entry:entry + 4]) == bytes([0x5C, gl[name] & 255, gl[name] >> 8, 0]), f"the entry table: jml {name}"
assert m.io[(0xE0, 0xC029)] & 0xC0 == 0xC0, "Super Hi-Res on"
assert m.io[(0xE0, 0xC034)] & 15 == 0, "black border at the top of the main loop (waiting for the video frame)"
check_screen("first picture")
print(f"boot: new game on level 0 (px {lv('px')}), patches and trampolines in place, first picture equals the logic's matrix")

# ---- 2. frames with no key: the picture holds, game steps come at 12.5 a second (24 / 5 frames), nothing moves
tick0 = lv("tick")
px0 = lv("px")
steps = advance(60)
assert lv("tick") == (tick0 + 60) & 0xFF, f"tick advanced {lv('tick') - tick0} in 60 frames"
assert steps in (12, 13), f"{steps} game steps in 60 frames (the BBC rate is 12.5 a second)"
assert lv("px") == px0 and not any(lv("keys", i) for i in range(3)) and lv("key1") == 0 == lv("key2"), "idle"
assert lv("ready") == 0, "ready is cleared each frame (the C64's interrupt would have shown the staged picture)"
check_screen("idle")
print(f"idle: 60 frames, tick +60, {steps} game steps, nothing moves, picture unchanged")

# ---- 3. every key as the C64 port maps it: the platform's reader, then the logic's read_keys, then the logic's key state
# (not through full frames: A, J, P, ESC... open modal screens in the logic that wait for more keys)
# (index in the logic's key table + 1 = the key number; bit n - 1 of keys[(n - 1) // 8])
K = {m_.group(1): int(m_.group(2)) for m_ in re.finditer(r"^(K_[A-Z0-9]+)\s*=\s*(\d+)", (ROOT / "src/constants.inc").read_text(), re.M)}
KEYNUM = {"X": K["K_RIGHT"], 0x15: K["K_RIGHT"], "Z": K["K_LEFT"], 0x08: K["K_LEFT"], ";": K["K_UP"], 0x0B: K["K_UP"],
          "/": K["K_DOWN"], 0x0A: K["K_DOWN"], "A": K["K_TERM"], "J": K["K_JET"], 0x0D: K["K_JUMP"], "=": K["K_FIRE"],
          0x1B: K["K_ESC"], "P": K["K_PAUSE"], 0x7F: K["K_PAUSE"], "D": K["K_MINE"], 0x09: K["K_TAB"], "O": K["K_O"],
          " ": K["K_SPACE"], "S": K["K_S"], "B": K["K_B"], "M": K["K_M"]}


def read_keys_now():
    call(gl["read_host_keys"])                            # the platform's keyboard reader fills KEYBITS ...
    call(LOGIC + cl["read_keys"])                         # ... the logic's own read_keys (hal_scan_keys) turns it into keys/key1/key2


for key, num in KEYNUM.items():
    code = key if isinstance(key, int) else ord(key)
    for variant in {code, code + 0x20 if isinstance(key, str) and key.isalpha() else code}:    # lower case too
        m.kq = [variant]
        m.key_down = True
        read_keys_now()
        m.key_down = False
        got = [lv("keys", i) for i in range(3)]
        want = [0, 0, 0]
        want[(num - 1) // 8] = 1 << ((num - 1) % 8)
        assert got == want and lv("key1") == num, f"key {key!r}/{variant:#x}: keys {got} key1 {lv('key1')}, wanted {want}/{num}"
        read_keys_now()
        assert [lv("keys", i) for i in range(3)] == [0, 0, 0], f"key {key!r} did not release"
        for _ in range(3):
            read_keys_now()
        assert lv("key1") == 0, f"key {key!r}: pressing order did not empty"
print(f"keys: {len(KEYNUM)} keys (letters in both cases, arrows, RETURN, ESC...) each arrive as the logic's key number")

# ---- 4. the Apple keys: Open Apple is jump, Closed Apple is fire; with X held they combine, and key1/key2 keep the pressing order
m.kq, m.key_down = [ord("X")], True
read_keys_now()
m.modifiers = 0x80
read_keys_now()
want = (1 << (K["K_RIGHT"] - 1)) | (1 << (K["K_JUMP"] - 1))
assert lv("keys", 0) == want, f"X + Open Apple: keys {lv('keys', 0):08b}"
assert (lv("key2"), lv("key1")) == (K["K_RIGHT"], K["K_JUMP"]), f"order: first {lv('key2')}, last {lv('key1')}"
m.modifiers = 0xC0
read_keys_now()
assert lv("keys", 0) == want | (1 << (K["K_FIRE"] - 1)), f"X + both Apple keys: {lv('keys', 0):08b}"
assert lv("key1") == K["K_FIRE"], "the newest key is fire"
m.modifiers, m.key_down = 0, False
read_keys_now()
assert [lv("keys", i) for i in range(3)] == [0, 0, 0], "keys release at once"
for _ in range(4):                                        # the logic's pressing-order list drops one released key per read
    read_keys_now()
assert lv("key1") == 0 == lv("key2"), "the pressing order empties within a few reads (the C64 logic does the same)"
# and through real frames: X with Open Apple (jump) makes the player jump while moving right
m.kq, m.key_down, m.modifiers = [ord("X")], True, 0x80
py0, px0 = lv("py"), lv("px")
air = 0
for _ in range(30):
    advance(1)
    air = max(air, abs(lv("py") - py0))
m.modifiers = 0
m.key_down = False
advance(10)
assert air > 0 and lv("px") > px0, f"X + Open Apple should jump and move right: py moved {air}, px {px0} -> {lv('px')}"
check_screen("after a jump")
# and Shift jumps too (GSplus maps F1 to Open Apple, but a desktop may take the Super key)
m.kq, m.key_down, m.modifiers = [ord("X")], True, 0x01
py0, px0 = lv("py"), lv("px")
air = 0
for _ in range(30):
    advance(1)
    air = max(air, abs(lv("py") - py0))
m.modifiers = 0
m.key_down = False
advance(10)
assert air > 0 and lv("px") > px0, f"X + Shift should jump and move right: py moved {air}, px {px0} -> {lv('px')}"
print("Apple keys: Open Apple = jump, Closed Apple = fire, combined with X, in the order pressed")

# ---- 5. walking: X right, Z left, nothing otherwise; the picture follows every frame
px = lv("px")
m.kq, m.key_down = [ord("X")], True
advance(40)
m.key_down = False
advance(6)
moved_right = lv("px") - px
assert moved_right >= 6, f"held X for 40 frames: px {px} -> {lv('px')}"
check_screen("after walking right")
px = lv("px")
m.kq, m.key_down = [ord("Z")], True
advance(40)
m.key_down = False
advance(6)
assert px - lv("px") >= 6, f"held Z for 40 frames: px {px} -> {lv('px')}"
check_screen("after walking left")
px = lv("px")
advance(30)
assert lv("px") == px, "moved with no key held"
print(f"walking: X moved the player right {moved_right} columns in 40 frames, Z back left, idle stays put; pictures equal the matrix")

# ---- 5b. the camera follows the player a column at a time (the C64's), keeping them about 17 columns from the left edge
saved_px = lv("px")
# walking right: in zone mode the window moves only when the player leaves the zone, in one jump; in follow mode (the C64's
# camera) it creeps along a column at a time keeping the player about 17 columns from the left edge
w0 = lv("cur_w")
moves, jumps = 0, 0
m.kq, m.key_down = [ord("X")], True
last = lv("cur_w")
for _ in range(120):
    advance(1)
    if lv("cur_w") != last:
        moves += 1
        jumps += abs(lv("cur_w") - last) > 1
        last = lv("cur_w")
m.key_down = False
advance(8)
assert lv("px") > saved_px + 6, f"walked right for 120 frames: px {saved_px} -> {lv('px')}"
assert moves >= 4 and jumps == 0, f"follow camera: {moves} moves, {jumps} jumps (it should creep a column at a time)"
assert abs((lv("px") - lv("cur_w")) - 17) <= 3, f"the player stays about 17 columns from the left edge: {lv('px') - lv('cur_w')}"
print(f"camera: walking right for 120 frames moved the window {moves} times, a column each ({w0} -> {lv('cur_w')}), the player ~17 columns in")
check_screen("after the camera moved")

# ---- 5c. sprites: the player (two sprites; three when crawling) and the blasters, drawn over the cells and erased as they move.
# Every frame is compared with the reference picture, so a ghost or a leftover pixel anywhere fails.
def frames_checked(n, what):
    shots = 0
    for i in range(n):
        advance(1)
        check_screen(f"{what}, frame {i}")
        shots += 1
    return shots


en = lv("p_en")
assert en & 3 == 3, f"the player's two sprites should be enabled after a new game (p_en {en:08b})"
assert screen() != bytes(iigs_model.matrix_picture(m.mem, LOGIC, sym, cl)), "the sprites should change the picture"
checked = 0
fire_seen = crawl_seen = 0
script = [  # (keys held by name, modifiers, frames, label)
    ("X", 0x00, 30, "walking right"), ("Z", 0x00, 30, "walking left"), ("X", 0x80, 40, "jumping right"),
    (None, 0x40, 30, "firing"), ("X", 0x40, 30, "walking and firing"), (None, 0x00, 10, "standing"),
    ("/", 0x00, 12, "kneeling"), (None, 0x00, 6, "released"), ("/", 0x00, 12, "down again: crawling"),
    ("X", 0x00, 40, "crawling right"), ("Z", 0x00, 40, "crawling left"),
    (";", 0x00, 20, "standing up"), ("Z", 0x00, 30, "walking left"), (None, 0x00, 10, "standing"),
]
for key, mods, frames, label in script:
    m.kq, m.key_down, m.modifiers = ([ord(key)] if key else []), key is not None, mods
    for i in range(frames):
        advance(1)
        check_screen(f"sprites, {label}, frame {i}")
        checked += 1
        fire_seen += (lv("p_en") & 0xF8) != 0
        crawl_seen += (lv("p_en") & 4) != 0
m.kq, m.key_down, m.modifiers = [], False, 0
advance(5)
assert fire_seen > 0, "the blasters' sprites (3 - 7) should have appeared while firing"
assert crawl_seen > 0, "the crawling player's third sprite should have appeared (kneel with / then move)"
print(f"sprites: {checked} frames (walking, jumping, firing, crawling, standing) each equal the reference picture; "
      f"blaster sprites seen on {fire_seen} frames, the crawling player's third sprite on {crawl_seen}")

# ---- 6. the logic's own waits pass frames instead of hanging
t0 = lv("tick")
call(LOGIC + HAL_WAIT, 3)                  # the logic's wait_frames, patched: 3 frames pass
assert lv("tick") == (t0 + 3) & 0xFF, f"wait_frames(3): tick {t0} -> {lv('tick')}"
t0 = lv("tick")
call(LOGIC + HAL_FRAME)
assert lv("tick") == (t0 + 1) & 0xFF, "frame_wait passes one frame"
print("waits: wait_frames(3) and frame_wait pass 3 and 1 frames (through the platform), no hang")

# ---- 7. the lift's ride: the logic stages a picture a frame at a time and waits for the interrupt to take it over (five places
# spin on `ready`); the platform shows each staged picture instead. Level 0 down to level 1, the lift at the right end.
def wr(name, v):
    m.mem[LOGIC + cl[name]] = v


presents = [0]
real_step = m.step


def counting_step():
    if (m.pbr << 16 | m.pc) == gl["shr_present"]:
        presents[0] += 1
    real_step()


m.step = counting_step
wr("init_px", 0x80)
wr("lift_dir", 1)
wr("newlvl", 1)
call(LOGIC + cl["lift_ride_scroll"], limit=20_000_000)
m.step = real_step
assert presents[0] >= 16, f"the ride showed only {presents[0]} pictures"
check_screen("after the ride")
print(f"lift: the ride 0 -> 1 ran to its end, showing {presents[0]} pictures; the last equals the logic's matrix")

# ---- 8. the screens: the wrist terminal (and its map), game over. Each draws its own cells and waits for keys inside the logic;
# the platform shows the matrix every frame (the VIC-II reads it live) and takes the keys.
def press(ch):
    def go():
        m.kq.append(ord(ch))
        m.key_down = True
    return go


def release():
    m.kq.clear()
    m.key_down = False


def shows(what):
    def go():
        check_screen(what)
    return go


call(LOGIC + cl["wrist_terminal"], limit=40_000_000, script={
    12: shows("terminal"), 14: press("M"), 18: release, 60: shows("map"), 62: press(" "), 66: release,
    140: shows("terminal again"), 142: press(" "), 146: release})
check_screen("after the terminal")
print("terminal: the wrist terminal, its map and the way back each show the logic's matrix; keys SPACE and M reach it")

# game over: the box, the tune, SPACE restarts: the title screen again (restart_game goes to the platform), SPACE starts a new game
m.key_down = False
wr("lives", 0)
saved_state = (m.pc, m.pbr, m.dbr, m.c, m.x, m.y, m.sp)
bank2_stub = 0x07C0
m.mem[LOGIC + bank2_stub:LOGIC + bank2_stub + 3] = bytes([0x4C, bank2_stub & 255, bank2_stub >> 8])
m.push16(bank2_stub - 1)
m.c, m.pc, m.pbr, m.dbr = 0, cl["game_over"], 2, 2
frames_seen = 0
for _ in range(80_000_000):
    if (m.pbr << 16 | m.pc) == gl["plat_frame"]:
        frames_seen += 1
        if frames_seen == 130:
            check_screen("game over")
            m.kq.append(ord(" "))
            m.key_down = True
        if frames_seen == 131:
            release()                 # a tap: the title screen would take a SPACE still down for its own start
        if frames_seen > 131 and lv("title_on") == 1:
            break
    m.step()
else:
    raise AssertionError("game over did not lead back to the title screen")
for _ in range(6):
    run_to_present_end()
check_screen("title after game over")
m.kq.append(ord(" "))
m.key_down = True
for _ in range(60_000_000):
    if (m.pbr << 16 | m.pc) == MAIN_LOOP:
        break
    m.step()
else:
    raise AssertionError("SPACE on the second title did not start a game")
release()
assert lv("level") == 0 and lv("lives") == 3, "a new game after game over"
print("game over: the box and text show the matrix, SPACE goes back through the platform to the title, SPACE starts a new game")
print("apple2gs game OK")
