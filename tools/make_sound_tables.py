"""Tables for the SID sound driver (src/sound.s), and the model the tests check it against.

The BBC game makes sound with the OS's SOUND (OSWORD 7): per channel (0 = noise, 1-3 = tones) a note with an amplitude
(a volume, or one of four envelopes), a pitch (quarter semitones: 53 = middle C, 89 = A 440) and a duration (1/20 s),
queued four deep. The four envelopes the game uses are in its memory (os_envelope_storage, data.s). The C64's SID does
the amplitude shaping in hardware (ADSR per voice) and the driver does the pitch changes of an envelope, so each BBC
envelope is turned here into the nearest SID attack/decay/sustain/release.

  sound_f4                       the SID frequency of the pitches 192 + k (k = 0-47), the top octave that fits;
                                 the driver makes the other octaves by shifting
  sound_env                      per envelope 1-4, 16 bytes: AD, SR, flags (1 = silent, 2 = pitch slide), PI1-3, PN1-3
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "bbc", "src")

PAL_CLOCK, NTSC_CLOCK = 985248, 1022730
ATTACK_MS = [2, 8, 16, 24, 38, 56, 68, 80, 100, 250, 500, 800, 1000, 3000, 5000, 8000]
DECAY_MS = [6, 24, 48, 72, 114, 168, 204, 240, 300, 750, 1500, 2400, 3000, 9000, 15000, 24000]


def pitch_hz(p):
    """The BBC's pitch: 4 units a semitone, 53 = middle C (261.63 Hz), 89 = A (440 Hz)."""
    return 440.0 * 2 ** ((p - 89) / 48.0)


def sid_freq(p, clock):
    """The SID frequency register for BBC pitch p, as the driver makes it (the top octave from the table, others by shift)."""
    k, o = p % 48, p // 48
    f4 = min(65535, int(round(pitch_hz(192 + k) * 2 ** 24 / clock)))
    f = f4 >> (4 - o) if o <= 4 else min(65535, f4 << (o - 4))
    return f


def envelopes():
    """The four envelopes' parameters as the game's memory has them (16 bytes each)."""
    text = open(os.path.join(SRC, "data.s")).read()
    block = text[text.index("os_envelope_storage:"):]
    rows = []
    for line in block.split("\n")[1:5]:
        rows.append([int(x, 16) for x in re.findall(r"\$([0-9a-f]{2})", line.split(";")[0])])
    return rows


def signed(b):
    return b - 256 if b > 127 else b


def nearest(table, ms):
    return min(range(16), key=lambda i: abs(table[i] - ms))


def sid_envelope(e):
    """(AD, SR, flags, T, PI1-3, PN1-3) for the BBC envelope e = [T, PI1, PI2, PI3, PN1, PN2, PN3, AA, AD, AS, AR, ALA, ALD]."""
    T, pi, pn = e[0], e[1:4], e[4:7]
    AA, AD, AS, AR, ALA, ALD = e[7], signed(e[8]), signed(e[9]), signed(e[10]), e[11], e[12]
    assert T == 1, "the driver steps the envelopes once per 1/100 s"
    step = 10.0
    flags = 0
    if AA == 0 or ALA == 0:                      # the amplitude never rises: silent
        flags |= 1
        a = d = s = r = 0
    else:
        a = nearest(ATTACK_MS, ALA / float(AA) * step)
        s = int(round(ALD / 126.0 * 15))
        decay_ms = (ALA - ALD) / float(-AD) * step if AD < 0 else 0
        if AS < 0 and ALD / float(-AS) * step < 300:         # the level runs on down to nothing within a note
            s = 0
            decay_ms += ALD / float(-AS) * step
        sf = s / 15.0
        d = min(range(16), key=lambda i: abs((1 - sf) * DECAY_MS[i] - decay_ms))
        rel_ms = (ALD / float(-AR) * step) if AR < 0 else 0
        r = min(range(16), key=lambda i: abs(sf * DECAY_MS[i] - rel_ms)) if s else 3
    if any(pi) :
        flags |= 2
    return [a << 4 | d, s << 4 | r, flags] + list(pi) + list(pn)


def emit(f):
    f.write('\n.segment "SOUNDC"\n\n')
    f.write("sound_f4:                       ; PAL lo, PAL hi, NTSC lo, NTSC hi (48 each)\n")
    for clock in (PAL_CLOCK, NTSC_CLOCK):
        vals = [min(65535, int(round(pitch_hz(192 + k) * 2 ** 24 / clock))) for k in range(48)]
        f.write("    .byte " + ",".join("$%02x" % (v & 255) for v in vals) + "\n")
        f.write("    .byte " + ",".join("$%02x" % (v >> 8) for v in vals) + "\n")
    f.write("sound_env:                      ; 16 bytes each: AD, SR, flags (2 = pitch slide), PI1-3, PN1-3\n")
    for e in envelopes():
        row = sid_envelope(e)
        f.write("    .byte " + ",".join("$%02x" % v for v in row + [0] * (16 - len(row))) + "\n")


if __name__ == "__main__":
    for i, e in enumerate(envelopes(), 1):
        print(i, e[:13], "->", ["%02x" % v for v in sid_envelope(e)])
    print("pitch 89 (A 440): PAL %04x NTSC %04x" % (sid_freq(89, PAL_CLOCK), sid_freq(89, NTSC_CLOCK)))
