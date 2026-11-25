"""Tiny pixel-art helpers shared by the deco generators (PIL only, 1x pixels)."""
import math, random
from PIL import Image, ImageDraw

# --- palettes -------------------------------------------------------------
# Room props sit on the back wall, behind gameplay: darker than the slate walls
# (wall fill is ~#2A3A4C) so they never read as solid platforms.
OUT = (12, 18, 28, 255)
SH = (22, 31, 43, 255)
MID = (30, 42, 57, 255)
HI = (43, 59, 77, 255)
HI2 = (60, 80, 101, 255)
STEEL = (88, 110, 134, 255)

FROST = (128, 217, 255, 255)
HEAT = (255, 90, 26, 255)
GOAL = (102, 255, 153, 255)
AMBER = (230, 160, 60, 255)
RED = (230, 60, 50, 255)
LEDG = (70, 210, 130, 255)
LEDB = (100, 190, 240, 255)

GLASS = (22, 50, 62, 255)
GLASS_HI = (40, 84, 98, 255)
FLUID = (26, 70, 78, 255)
FLUID_HI = (46, 112, 118, 255)
SCREEN = (12, 34, 44, 255)
SCREEN_TXT = (70, 170, 190, 255)

T = (0, 0, 0, 0)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


def new(w, h):
    return Image.new("RGBA", (w, h), T)


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((int(x), int(y)), c)


def rect(im, x, y, w, h, c):
    if w <= 0 or h <= 0:
        return
    ImageDraw.Draw(im).rectangle([x, y, x + w - 1, y + h - 1], fill=c)


def hline(im, x, y, w, c):
    rect(im, x, y, w, 1, c)


def vline(im, x, y, h, c):
    rect(im, x, y, 1, h, c)


def box(im, x, y, w, h, fill=MID, out=OUT, hi=HI, sh=SH):
    """Outlined panel with a 1px highlight (top/left) and shadow (bottom/right)."""
    rect(im, x, y, w, h, out)
    rect(im, x + 1, y + 1, w - 2, h - 2, fill)
    if hi:
        hline(im, x + 1, y + 1, w - 2, hi)
        vline(im, x + 1, y + 1, h - 2, hi)
    if sh:
        hline(im, x + 1, y + h - 2, w - 2, sh)
        vline(im, x + w - 2, y + 2, h - 3, sh)


def cyl_v(im, x, y, w, h, fill=MID, out=OUT, hi=HI, sh=SH, outline=True):
    """Vertical cylinder shading (light from the left)."""
    for i in range(w):
        t = i / max(w - 1, 1)
        c = hi if t < 0.28 else (fill if t < 0.68 else sh)
        vline(im, x + i, y, h, c)
    if outline:
        vline(im, x, y, h, out)
        vline(im, x + w - 1, y, h, out)


def cyl_h(im, x, y, w, h, fill=MID, out=OUT, hi=HI, sh=SH, outline=True):
    for j in range(h):
        t = j / max(h - 1, 1)
        c = hi if t < 0.3 else (fill if t < 0.7 else sh)
        hline(im, x, y + j, w, c)
    if outline:
        hline(im, x, y, w, out)
        hline(im, x, y + h - 1, w, out)


def disc(im, cx, cy, r, c):
    for y in range(-r, r + 1):
        for x in range(-r, r + 1):
            if x * x + y * y <= r * r + r * 0.6:
                px(im, cx + x, cy + y, c)


def ring(im, cx, cy, r, c):
    for a in range(0, 360, 3):
        px(im, round(cx + math.cos(math.radians(a)) * r), round(cy + math.sin(math.radians(a)) * r), c)


def line(im, x0, y0, x1, y1, c):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        px(im, round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)


def outline_alpha(im, c=OUT):
    """Adds a 1px outline around opaque pixels (in place on a copy)."""
    w, h = im.size
    src = im.copy()
    for y in range(h):
        for x in range(w):
            if src.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < w and 0 <= yy < h and src.getpixel((xx, yy))[3] > 200:
                        im.putpixel((x, y), c)
                        break
    return im


# 3x5 pixel font for labels.
FONT = {
    "A": ["111", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"],
    "C": ["111", "100", "100", "100", "111"], "D": ["110", "101", "101", "101", "110"],
    "E": ["111", "100", "110", "100", "111"], "F": ["111", "100", "110", "100", "100"],
    "G": ["111", "100", "101", "101", "111"], "H": ["101", "101", "111", "101", "101"],
    "I": ["111", "010", "010", "010", "111"], "K": ["101", "101", "110", "101", "101"],
    "L": ["100", "100", "100", "100", "111"], "M": ["101", "111", "111", "101", "101"],
    "N": ["111", "101", "101", "101", "101"], "O": ["111", "101", "101", "101", "111"],
    "P": ["111", "101", "111", "100", "100"], "R": ["110", "101", "110", "101", "101"],
    "S": ["111", "100", "111", "001", "111"], "T": ["111", "010", "010", "010", "010"],
    "U": ["101", "101", "101", "101", "111"], "V": ["101", "101", "101", "101", "010"],
    "W": ["101", "101", "111", "111", "101"], "X": ["101", "101", "010", "101", "101"],
    "Y": ["101", "101", "010", "010", "010"], "Z": ["111", "001", "010", "100", "111"],
    "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
    "2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "011", "001", "111"],
    "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
    "6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
    "-": ["000", "000", "111", "000", "000"], " ": ["000", "000", "000", "000", "000"],
    "!": ["010", "010", "010", "000", "010"], ".": ["000", "000", "000", "000", "010"],
    "/": ["001", "001", "010", "100", "100"],
}


def text(im, x, y, s, c):
    for ch in s.upper():
        g = FONT.get(ch, FONT[" "])
        for j, row in enumerate(g):
            for i, b in enumerate(row):
                if b == "1":
                    px(im, x + i, y + j, c)
        x += 4


def text_w(s):
    return len(s) * 4 - 1


def strip(frames):
    """Concatenates equally sized frames horizontally."""
    w, h = frames[0].size
    out = new(w * len(frames), h)
    for i, f in enumerate(frames):
        out.paste(f, (i * w, 0))
    return out


def vstack(frames):
    w, h = frames[0].size
    out = new(w, h * len(frames))
    for i, f in enumerate(frames):
        out.paste(f, (0, i * h))
    return out


def radial(size, power=2.0, dither=False, steps=0):
    """White radial falloff (alpha) for additive glows."""
    im = new(size, size)
    c = (size - 1) / 2.0
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) / (size / 2.0)
            a = max(0.0, 1.0 - d) ** power
            if steps:
                a = math.floor(a * steps) / steps
            im.putpixel((x, y), (255, 255, 255, int(a * 255)))
    return im


class Wrap:
    """Draws into a horizontally tiling canvas (shapes wrap across the seam)."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = new(w * 3, h)

    def _do(self, fn, x, *a, **k):
        for dx in (0, self.w, 2 * self.w):
            fn(self.im, x + dx, *a, **k)

    def rect(self, x, y, w, h, c):
        self._do(lambda im, xx: rect(im, xx, y, w, h, c), x)

    def call(self, fn, x, *a, **k):
        """fn(im, x, *a) drawn at the three copies."""
        self._do(fn, x, *a, **k)

    def result(self):
        return self.im.crop((self.w, 0, 2 * self.w, self.h))
