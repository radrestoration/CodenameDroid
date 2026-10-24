#!/usr/bin/env python3
"""The title screen as the C64 shows it (the 40-column build): a wider, shorter arrangement of the game's own title.

The game draws its title into the ring, 32 cells wide and 32 rows high (a frame of 4 x 4 cell squares: a bar along the top
and the bottom, a column down each side, diagonal corner pieces inside, and in the middle the text, the logo, the player
and a music icon). The C64's screen is 40 cells wide and shows 24 rows of 8 lines, so the title is shown through a map from
screen cells to ring cells instead of as the ring is:
  - 8 columns wider, in the middle: the squares of each side stay one column and the corner pieces stay by them, the top and
    bottom bars get two more squares between, and the middle has the 8 columns more room, so the frame fills the screen's width;
  - 8 rows shorter: two square rows of the frame are left out, so that the whole of it fits the screen's 24 rows;
  - the middle is re-arranged to fit: SUPERIOR and PRESENTS on one line, blank rows taken out, the music icon moved right so
    that HIT SPACE has the bottom row, and a gap between the player and HIT SPACE.
The map is a list of segments (a run of cells of one ring row to a run of cells of one screen row) in screen order, for the C64's
code to copy the picture from (src/cells.s, title_remap).
   make_title_map.py   prints the layout
"""
import sys

W = 40                      # the ring's cells a row (the 40-column build)
SCREEN_COLS = 40
SHOWN = list(range(0, 25))  # the screen rows the matrix has (its 25 rows): the 24-row picture, and a blank one under the border

# the ring's frame
def is_frame(r, c):
    """Ring cell (r, c), of the 32 columns the title uses: part of the frame (bars, squares, the diagonal corner pieces)."""
    if r < 4 or r >= 28 or c < 4 or c >= 28:
        return True
    if 4 <= r < 8:                               # the corner pieces: 4 cells wide at the frame's top, one fewer each row down
        k = r - 4
        return c <= 7 - k or c >= 24 + k
    if 24 <= r < 28:                             # and at the bottom, one more each row down
        k = r - 24
        return c <= 4 + k or c >= 27 - k
    return False


def frame_row(d):
    """The frame's ring row for picture row d (24 rows): the third and fourth square rows (ring rows 12-19) are left out."""
    return d if d < 12 else d + 8


BLANK_ROW = 22              # (a ring row with nothing in its middle, for the blank cells)

# the middle, picture row -> ring row (None: blank)
CONTENT_ROW = {4: None, 5: "line", 6: 11, 7: 12, 8: 13, 9: 14, 10: 15, 11: 16, 12: 17,
               13: 18, 14: 19, 15: 20, 16: 21, 17: None, 18: None, 19: 23}
STEREO = {17: 25, 18: 26, 19: 27}       # (the music icon: ring rows 25-27, moved to screen columns 28-31)


def source(d, c):
    """The ring cell (row, column) shown at picture row d, screen column c; the ring's blank row's cell for nothing."""
    if d >= 24:                                  # (the matrix's last row, which the border hides)
        return BLANK_ROW, 8 + c % 16
    bar = d < 4 or d >= 20
    fr = frame_row(d)
    # the frame: the outer 8 columns each side are the ring's (the squares or the end of a bar, and the corner pieces)
    if c < 8 or c >= 32:
        fc = c if c < 8 else c - 8
        if is_frame(fr, fc):
            return fr, fc
        return BLANK_ROW, 8 + c % 16
    # the middle, 24 columns (the ring's 16 and 8 more): the bars have squares across it
    if bar:
        return fr, 8 + (c - 8) % 4
    if d == 5:                                   # SUPERIOR and PRESENTS on one line (each is ring columns 12-19)
        if 12 <= c <= 19:
            return 7, c
        if 21 <= c <= 28:
            return 9, c - 9
        return BLANK_ROW, c - 4
    if d in STEREO and 28 <= c <= 31:
        return STEREO[d], c - 8
    row = CONTENT_ROW.get(d)
    if row is None or not 12 <= c <= 28:         # (the text is ring columns 8-24, shown 4 columns on)
        return BLANK_ROW, c - 4
    return row, c - 4


def segments():
    """[(length, ring cell offset from the window's top left)] in screen order (row by row), covering the matrix's 1000
    cells: a run of cells of one screen row that are consecutive cells of one ring row is one segment."""
    segs = []
    for d in SHOWN:
        c = 0
        while c < SCREEN_COLS:
            r, rc = source(d, c)
            n = 1
            while c + n < SCREEN_COLS:
                r2, rc2 = source(d, c + n)
                if r2 != r or rc2 != rc + n:
                    break
                n += 1
            segs.append((n, r * W + rc))
            c += n
    return segs


def tables():
    """The segments as bytes: length, ring offset low and high; ended by a length of 0. (The screen cell of a segment is the
    total length before it.)"""
    raw = bytearray()
    for n, off in segments():
        raw += bytes([n, off & 255, off >> 8])
    raw.append(0)
    return bytes(raw)


def forward():
    """{screen cell index: ring cell offset} as the segments give it."""
    out, dst = {}, 0
    for n, off in segments():
        for i in range(n):
            out[dst + i] = off + i
        dst += n
    assert dst == len(SHOWN) * SCREEN_COLS
    return out


def main():
    segs = segments()
    print(len(segs), "segments")
    fw = forward()
    for m_row in range(25):
        line = ""
        for c in range(SCREEN_COLS):
            off = fw[m_row * SCREEN_COLS + c]
            line += "#" if off // W != BLANK_ROW else "."
        print("%2d %s" % (m_row + 2, line))


if __name__ == "__main__":
    main()
