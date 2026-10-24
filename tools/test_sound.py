#!/usr/bin/env python3
"""The sound driver (src/sound.s), run for real in the 6502 simulator with the SID's registers logged:
  - the frequency for every BBC pitch 0-255, PAL and NTSC, against the model in make_sound_tables.py
  - OSWORD 7 / OSBYTE 128 / flush: the queue (four deep, the free count the game's tune waits on), flushing
  - a note's registers and timing (1/20 s units on the 100 Hz clock), volume and envelope notes, the pitch slide
  - the noise rates, channel 3 / noise sharing a voice, the suppression variable."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_sound_tables as mst  # noqa: E402
from c64sim import C64  # noqa: E402

fails = []


def check(ok, what):
    print("%s %s" % ("ok " if ok else "BAD", what))
    if not ok:
        fails.append(what)


def setup(pal):
    c = C64()
    c.run_frames(1)
    c.m[0x205] = pal
    c.call("snd_init")
    log = []
    c.cpu.write_hooks.append(lambda a, v: log.append((tick[0], a, v)) if 0xd400 <= a <= 0xd418 else None)
    return c, log


tick = [0]


SND = 0xed00
VARS = {"qcnt": SND + 52, "cpit": SND + 68, "snd_acc": SND + 88, "c64_pal": 0x205, "os_sound_suppression": 0x262}


def sym(c, name):
    return VARS[name]


def osword(c, block, addr=0x0340):
    c.m[addr:addr + 8] = bytes(block)
    c.cpu.a, c.cpu.x, c.cpu.y = 7, addr & 255, addr >> 8
    c.call("snd_osword")


def note(c, chan, amp_lo, amp_hi, pitch, dur):
    osword(c, [chan, 0, amp_lo, amp_hi, pitch, 0, dur, 0])


def osbyte_space(c, ch):
    c.cpu.a, c.cpu.x, c.cpu.y = 0x80, 0xfb + ch, 0xff
    c.call("c64_osbyte")
    return c.cpu.x


def ticks(c, n):
    for _ in range(n):
        tick[0] += 1
        c.call("snd_tick")


def regs(log, lo, hi=None):
    return [(t, a, v) for (t, a, v) in log if lo <= a <= (hi or lo)]


def freq_of(c, voice):
    return c.m[0xd400 + voice] | c.m[0xd401 + voice] << 8


def test_frequencies(pal):
    c, log = setup(pal)
    clock = mst.PAL_CLOCK if pal else mst.NTSC_CLOCK
    bad = []
    for p in range(256):
        c.m[sym(c, "cpit") + 1] = p
        c.cpu.x = 1
        c.call("snd_setfreq")
        got = freq_of(c, 0)
        want = mst.sid_freq(p, clock)
        if abs(got - want) > 1:                  # (the table is rounded once, the model shifts the same value)
            bad.append((p, got, want))
    check(not bad, "frequency for pitches 0-255, %s%s" % ("PAL" if pal else "NTSC", " %s" % bad[:3] if bad else ""))
    a440 = 0x1d44 if pal else 0x1c31
    c.m[sym(c, "cpit") + 1] = 89
    c.cpu.x = 1
    c.call("snd_setfreq")
    check(freq_of(c, 0) == a440, "A 440 is %04x (is %04x)" % (a440, freq_of(c, 0)))


def test_queue():
    c, log = setup(1)
    q = sym(c, "qcnt")
    check(osbyte_space(c, 0) == 4, "an empty queue has 4 spaces")
    for i in range(5):
        note(c, 2, 0xf4, 0xff, 89, 10)
    check(c.m[q + 2] == 4 and osbyte_space(c, 2) == 0, "five notes queued: four held, none free")
    check(osbyte_space(c, 1) == 4, "other channels are untouched")
    note(c, 0x12, 0xf1, 0xff, 100, 4)             # flush channel 2 and queue one
    check(c.m[q + 2] == 1, "a flushing note empties the queue first")
    c.cpu.a, c.cpu.x = 0x0f, 0
    c.call("c64_osbyte")
    check(all(c.m[q + i] == 0 for i in range(4)), "OSBYTE 15 flushes every queue")


def test_note(pal):
    c, log = setup(pal)
    hz = 50 if pal else 60
    note(c, 1, 0xf4, 0xff, 89, 3)                 # channel 1, volume -12, A 440, 3/20 s
    ticks(c, 1)
    t = {a: v for (_, a, v) in log if a in (0xd404, 0xd405, 0xd406)}
    check(c.m[0xd404] == 0x41 and c.m[0xd406] == 0xc0 and c.m[0xd405] == 0, "volume -12: pulse, gate on, sustain 12")
    check(freq_of(c, 0) == (0x1d44 if pal else 0x1c31), "note frequency")
    ticks(c, 14)
    check(c.m[0xd404] == 0x41, "still on after 14/100 s")
    ticks(c, 1)
    check(c.m[0xd404] == 0x40, "gate off 15 ticks (3/20 s) after the start")
    ticks(c, 1)
    # the frame clock: 100 ticks a second from the 50 / 60 Hz interrupt
    c.call("snd_init")
    c.m[sym(c, "snd_acc")] = 0
    n = 0
    orig = c.syms["snd_tick"]
    count = [0]
    c.cpu.traps[orig] = lambda cpu: count.__setitem__(0, count[0] + 1)
    for _ in range(hz):
        c.call("snd_frame")
    del c.cpu.traps[orig]
    check(abs(count[0] - 100) <= 1, "%d interrupts a second give %d ticks" % (hz, count[0]))


def test_envelope():
    c, log = setup(1)
    env = mst.envelopes()
    for n in (1, 4):
        c.call("snd_init")
        note(c, 1, n, 0, 89, 4)
        ticks(c, 1)
        want = mst.sid_envelope(env[n - 1])
        check(c.m[0xd405] == want[0] and c.m[0xd406] == want[1], "envelope %d -> AD/SR %02x%02x" % (n, c.m[0xd405], c.m[0xd406]))
    c.call("snd_init")
    note(c, 1, 0, 0, 89, 4)
    ticks(c, 1)
    check(c.m[0xd406] == 0, "amplitude 0 is silent")
    # envelope 2 slides the pitch down 4 units for 12 steps, then 3 for 12, then 2 for 12
    c, log = setup(1)
    note(c, 2, 2, 0, 120, 6)
    ticks(c, 1)
    p, seq = 120, [mst.sid_freq(120, mst.PAL_CLOCK)]
    for _ in range(12):
        ticks(c, 1)
        p -= 4
        seq.append(freq_of(c, 7))
    want = [mst.sid_freq(120 - 4 * i, mst.PAL_CLOCK) for i in range(13)]
    check(all(abs(a - b) <= 1 for a, b in zip(seq, want)), "envelope 2: the first 12 steps fall 4 units each")
    ticks(c, 1)                                    # (a section change takes a tick)
    ticks(c, 12)
    check(abs(freq_of(c, 7) - mst.sid_freq(120 - 48 - 36, mst.PAL_CLOCK)) <= 1, "then 12 steps of 3")


def test_gun():
    """The player's blaster: envelope 2, pitch 101, 1/20 s. The pitch keeps falling in the release, after the gate is off
    (it was a chime when the slide stopped with the note)."""
    c, log = setup(1)
    note(c, 3, 2, 0, 101, 1)
    ticks(c, 1)
    f0 = freq_of(c, 14)
    ticks(c, 8)
    check(c.m[0xd412] == 0x40, "the gate is off after 5 ticks")
    f1 = freq_of(c, 14)
    ticks(c, 20)
    f2 = freq_of(c, 14)
    check(f0 > f1 > f2, "the pitch falls on through the release (%04x %04x %04x)" % (f0, f1, f2))
    want = mst.sid_freq(101 - 4 * 12 - 3 * 12 - 2 * 2, mst.PAL_CLOCK)
    check(abs(f2 - want) <= 2, "and follows the envelope (%04x, want %04x)" % (f2, want))


def test_voices():
    c, log = setup(1)
    note(c, 0, 4, 0, 1, 3)                         # noise, envelope 4, rate 1
    ticks(c, 1)
    check(c.m[0xd412] & 0x81 == 0x81 and c.m[0xd40f] == 0x34, "noise: voice 3, noise waveform, rate 1")
    note(c, 3, 0xf4, 0xff, 89, 3)                  # channel 3 takes the voice
    ticks(c, 1)
    check(c.m[0xd412] == 0x41, "channel 3 takes the shared voice")
    ticks(c, 20)
    check(c.m[0xd412] == 0x40, "and releases it")
    c.m[sym(c, "os_sound_suppression")] = 1
    c.call("snd_frame")
    check(c.m[0xd418] == 0, "suppression silences the SID")
    c.m[sym(c, "os_sound_suppression")] = 0
    c.call("snd_frame")
    check(c.m[0xd418] == 0x0f, "and releasing it brings the volume back")


def main():
    for pal in (1, 0):
        test_frequencies(pal)
    test_queue()
    for pal in (1, 0):
        test_note(pal)
    test_envelope()
    test_gun()
    test_voices()
    print("PASS" if not fails else "FAIL: %d" % len(fails))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
