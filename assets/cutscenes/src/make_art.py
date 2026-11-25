"""Pixel art for the State Shift cutscenes.

Everything is drawn at 1x (panels are 480x270) and shown at 2x in Godot.
Run from anywhere:   python -I assets/cutscenes/src/make_art.py
Writes PNGs into assets/cutscenes/.
"""
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, ".."))


def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# --- palette -------------------------------------------------------------------
NAVY = C("0D1426")
NIGHT = C("070B18")
DEEP = C("15203A")
WALL = C("1B2A3D")
WALL_D = C("16233A")
WALL_L = C("22344A")
SLATE = C("2A3A4C")
SLATE_M = C("40566C")
SLATE_L = C("5D7B93")
STEEL = C("8FA9BE")
STEEL_L = C("C9D9E6")
ICE = C("B8E6FF")
ICE_D = C("7FC3EC")
WATER = C("3F8CFF")
WATER_D = C("2A62D0")
WATER_DD = C("1E46A0")
WATER_L = C("8EC4FF")
STEAM = C("F2F7FF")
STEAM_D = C("C9D6E6")
STEAM_DD = C("9FB2C8")
HEAT = C("FF5A1A")
HEAT_L = C("FFB04A")
HEAT_D = C("B8350C")
GREEN = C("66FF99")
GREEN_D = C("2FB56A")
WHITE = C("FFFFFF")
SKIN = C("F2C29B")
SKIN_D = C("D3967A")
BLUSH = C("F29A9A")
HAIR = C("8A4B2F")
HAIR_D = C("5E301E")
HAIR_L = C("B0683F")
COAT = C("E3EAF2")
COAT_D = C("AEBFD3")
COAT_DD = C("7F93AB")
PANTS = C("2E3B55")
SHOE = C("1B2233")
MUG = C("D8504A")
MUG_D = C("9C3434")
AMBER = C("FFC24A")
PAPER = C("E9EEF4")
PAPER_D = C("BFCAD8")
INK = C("23315A")
WOOD = C("6B4A3A")
CLEAR = (0, 0, 0, 0)

random.seed(47)

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def new(w, h, col=CLEAR):
    return Image.new("RGBA", (w, h), col)


def save(img, name):
    path = os.path.join(OUT, name)
    img.save(path)
    print("wrote", name, img.size)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4))


def outline(img, col=NAVY, diag=False):
    """1px outline around every opaque pixel (4-neighbour by default)."""
    w, h = img.size
    pad = new(w + 2, h + 2)
    pad.paste(img, (1, 1))
    a = pad.split()[3].point(lambda v: 255 if v > 0 else 0)
    dil = a.copy()
    offs = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    if diag:
        offs += [(1, 1), (1, -1), (-1, 1), (-1, -1)]
    for dx, dy in offs:
        dil = ImageChops.lighter(dil, ImageChops.offset(a, dx, dy))
    ring = ImageChops.subtract(dil, a)
    out = new(w + 2, h + 2)
    out.paste(col, (0, 0, w + 2, h + 2), ring)
    out.alpha_composite(pad)
    return out.crop((1, 1, w + 1, h + 1))


def dither_fill(img, box, stops, vertical=True):
    """Ordered-dither gradient. stops: list of colours (evenly spaced)."""
    x0, y0, x1, y1 = box
    px = img.load()
    n = len(stops) - 1
    span = (y1 - y0) if vertical else (x1 - x0)
    for y in range(y0, y1):
        for x in range(x0, x1):
            t = ((y - y0) if vertical else (x - x0)) / max(1, span - 1)
            f = t * n
            i = min(int(f), n - 1)
            frac = f - i
            th = (BAYER[y % 4][x % 4] + 0.5) / 16.0
            px[x, y] = stops[i + 1] if frac > th else stops[i]


def dither_blend(img, box, col, amount):
    """Paints `col` over box with ordered-dither coverage `amount` (0..1)."""
    x0, y0, x1, y1 = box
    px = img.load()
    for y in range(max(0, y0), min(img.size[1], y1)):
        for x in range(max(0, x0), min(img.size[0], x1)):
            a = amount(x, y) if callable(amount) else amount
            if a > (BAYER[y % 4][x % 4] + 0.5) / 16.0:
                px[x, y] = col


def stars(img, box, n, cols=(STEAM, ICE, STEEL)):
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = box
    for _ in range(n):
        x, y = random.randrange(x0, x1), random.randrange(y0, y1)
        c = random.choice(cols)
        if random.random() < 0.08:
            d.point([(x, y), (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], fill=lerp(c, NAVY, 0.4))
            d.point((x, y), fill=STEAM)
        else:
            d.point((x, y), fill=lerp(c, NAVY, random.uniform(0.0, 0.6)))


# --- tiny 3x5 font ----------------------------------------------------------------
FONT = {
    "A": ["010", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"],
    "C": ["011", "100", "100", "100", "011"], "D": ["110", "101", "101", "101", "110"],
    "E": ["111", "100", "110", "100", "111"], "F": ["111", "100", "110", "100", "100"],
    "G": ["011", "100", "101", "101", "011"], "H": ["101", "101", "111", "101", "101"],
    "I": ["111", "010", "010", "010", "111"], "K": ["101", "101", "110", "101", "101"],
    "L": ["100", "100", "100", "100", "111"], "M": ["101", "111", "111", "101", "101"],
    "N": ["110", "101", "101", "101", "101"], "O": ["010", "101", "101", "101", "010"],
    "P": ["110", "101", "110", "100", "100"], "R": ["110", "101", "110", "101", "101"],
    "S": ["011", "100", "010", "001", "110"], "T": ["111", "010", "010", "010", "010"],
    "U": ["101", "101", "101", "101", "111"], "V": ["101", "101", "101", "101", "010"],
    "W": ["101", "101", "111", "111", "101"], "X": ["101", "101", "010", "101", "101"],
    "Y": ["101", "101", "010", "010", "010"], "Z": ["111", "001", "010", "100", "111"],
    "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
    "2": ["110", "001", "010", "100", "111"], "3": ["110", "001", "010", "001", "110"],
    "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "110", "001", "110"],
    "6": ["011", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "110"],
    " ": ["0", "0", "0", "0", "0"], "-": ["000", "000", "111", "000", "000"],
    "!": ["1", "1", "1", "0", "1"], "?": ["110", "001", "010", "000", "010"],
    ":": ["0", "1", "0", "1", "0"], ".": ["0", "0", "0", "0", "1"],
    "O2": ["010", "101", "101", "101", "010"],
}


def text(img, xy, s, col):
    px = img.load()
    x, y = xy
    for ch in s:
        g = FONT.get(ch.upper(), FONT["?"])
        for gy, row in enumerate(g):
            for gx, b in enumerate(row):
                if b == "1" and 0 <= x + gx < img.size[0] and 0 <= y + gy < img.size[1]:
                    px[x + gx, y + gy] = col
        x += len(g[0]) + 1
    return x


def text_w(s):
    return sum(len(FONT.get(c.upper(), FONT["?"])[0]) + 1 for c in s) - 1


# --- shared shapes ----------------------------------------------------------------

def shaded_ellipse(d, box, base, light=None, dark=None):
    x0, y0, x1, y1 = box
    d.ellipse(box, fill=base)
    if dark:
        d.chord((x0, y0, x1, y1), 20, 160, fill=dark)
        d.ellipse((x0 + 1, y0, x1 - 1, y1 - 2), fill=base)
    if light:
        w, h = x1 - x0, y1 - y0
        d.ellipse((x0 + w * 0.18, y0 + h * 0.14, x0 + w * 0.42, y0 + h * 0.36), fill=light)


def glow(size, col, rings=5, power=1.6, maxa=170):
    """Banded radial glow (use with additive blend)."""
    img = new(size, size)
    px = img.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            r = math.hypot(x - c, y - c) / (size / 2)
            if r >= 1:
                continue
            v = (1 - r) ** power
            band = math.ceil(v * rings) / rings
            px[x, y] = (col[0], col[1], col[2], int(maxa * band))
    return img


# =================================================================================
# Lab, wide shot
# =================================================================================

def clock(img, cx, cy, hh, mm):
    d = ImageDraw.Draw(img)
    d.ellipse((cx - 11, cy - 11, cx + 11, cy + 11), fill=SLATE_M, outline=NAVY)
    d.ellipse((cx - 9, cy - 9, cx + 9, cy + 9), fill=C("D9E6F2"))
    d.arc((cx - 9, cy - 9, cx + 9, cy + 9), 20, 200, fill=STEAM_D)
    for i in range(12):
        a = i / 12 * math.tau
        d.point((cx + round(math.sin(a) * 7), cy - round(math.cos(a) * 7)), fill=SLATE_L)
    am = mm / 60 * math.tau
    ah = (hh % 12 + mm / 60) / 12 * math.tau
    d.line((cx, cy, cx + round(math.sin(am) * 7), cy - round(math.cos(am) * 7)), fill=NAVY)
    d.line((cx, cy, cx + round(math.sin(ah) * 4), cy - round(math.cos(ah) * 4)), fill=HEAT_D, width=1)
    d.point((cx, cy), fill=HEAT)


def small_flask(col, w=10, h=14, kind="erl"):
    img = new(w, h)
    d = ImageDraw.Draw(img)
    glass = lerp(ICE, CLEAR, 0.55)
    if kind == "erl":
        nw = max(2, w // 3)
        nx = (w - nw) // 2
        d.rectangle((nx, 0, nx + nw - 1, h // 3), fill=glass)
        d.polygon([(nx, h // 3), (nx + nw - 1, h // 3), (w - 1, h - 1), (0, h - 1)], fill=glass)
        d.polygon([(nx - 1, h // 2 + 1), (nx + nw, h // 2 + 1), (w - 1, h - 1), (0, h - 1)], fill=col)
    elif kind == "round":
        d.rectangle((w // 2 - 1, 0, w // 2, h // 3), fill=glass)
        d.ellipse((0, h // 3 - 1, w - 1, h - 1), fill=glass)
        d.chord((0, h // 3 - 1, w - 1, h - 1), 0, 180, fill=col)
    else:  # jar / tube
        d.rectangle((0, 0, w - 1, h - 1), fill=glass)
        d.rectangle((0, h // 3, w - 1, h - 1), fill=col)
        d.rectangle((0, 0, w - 1, 1), fill=SLATE_L)
    d.point((1, h - 3), fill=STEAM)
    return outline(img)


def lab_bg(day=False):
    W, H = 480, 270
    img = new(W, H, WALL)
    d = ImageDraw.Draw(img)
    wall_l = WALL_L if not day else C("2B4058")
    if day:
        d.rectangle((0, 0, W, H), fill=C("223349"))
    # tiles
    for y in range(0, 230, 16):
        d.line((0, y, W, y), fill=WALL_D)
        d.line((0, y + 1, W, y + 1), fill=wall_l)
    for x in range(0, W, 16):
        d.line((x, 0, x, 230), fill=WALL_D)
        d.line((x + 1, 0, x + 1, 230), fill=wall_l)
    for _ in range(260):
        x, y = random.randrange(W), random.randrange(230)
        d.point((x, y), fill=WALL_D if random.random() < 0.6 else wall_l)
    # ceiling shadow
    dither_blend(img, (0, 0, W, 70), NAVY, lambda x, y: 0.75 * (1 - y / 70) ** 1.5)
    d.rectangle((0, 0, W, 7), fill=NAVY)
    # pipes
    for (py, ph) in ((10, 7), (21, 4)):
        d.rectangle((0, py, W, py + ph), fill=SLATE)
        d.line((0, py, W, py), fill=NAVY)
        d.line((0, py + 1, W, py + 1), fill=SLATE_L)
        d.line((0, py + ph, W, py + ph), fill=NAVY)
    for x in range(20, W, 64):
        d.rectangle((x, 8, x + 4, 19), fill=SLATE_M, outline=NAVY)
        d.point((x + 2, 11), fill=STEEL)
    # vertical pipe on the left with valve
    d.rectangle((6, 25, 11, 230), fill=SLATE)
    d.line((6, 25, 6, 230), fill=NAVY)
    d.line((7, 25, 7, 230), fill=SLATE_L)
    d.line((11, 25, 11, 230), fill=NAVY)
    d.ellipse((2, 140, 15, 153), fill=HEAT_D, outline=NAVY)
    d.line((4, 146, 13, 146), fill=HEAT)
    d.line((8, 142, 8, 151), fill=HEAT)
    # window
    wx0, wy0, wx1, wy1 = 30, 40, 102, 118
    d.rectangle((wx0 - 4, wy0 - 4, wx1 + 4, wy1 + 4), fill=SLATE, outline=NAVY)
    d.line((wx0 - 3, wy0 - 3, wx1 + 3, wy0 - 3), fill=SLATE_L)
    if day:
        dither_fill(img, (wx0, wy0, wx1 + 1, wy1 + 1), [C("5B7896"), C("7F9CB8"), C("A9C0D3")])
        for _ in range(42):
            x, y = random.randrange(wx0, wx1), random.randrange(wy0, wy1 - 4)
            d.line((x, y, x - 1, y + 4), fill=C("D6E4F0"))
        dither_blend(img, (wx0, wy1 - 18, wx1 + 1, wy1 + 1), C("4E6782"), lambda x, y: (y - (wy1 - 18)) / 22)
    else:
        dither_fill(img, (wx0, wy0, wx1 + 1, wy1 + 1), [NIGHT, NAVY, C("1C2F55")])
        stars(img, (wx0, wy0, wx1, wy1 - 20), 26)
        d.ellipse((72, 50, 90, 68), fill=C("DCE8F5"))
        d.ellipse((77, 54, 82, 59), fill=C("B9CBDD"))
        d.ellipse((83, 60, 86, 63), fill=C("B9CBDD"))
        d.chord((72, 50, 90, 68), 300, 120, fill=C("F2F7FF"))
        d.ellipse((77, 54, 82, 59), fill=C("B9CBDD"))
        # far skyline
        for i, x in enumerate(range(wx0, wx1, 9)):
            hh = 8 + (i * 7) % 13
            d.rectangle((x, wy1 - hh, x + 7, wy1), fill=C("0E1830"))
            if i % 2:
                d.point((x + 2, wy1 - hh + 3), fill=AMBER)
    d.rectangle((wx0 + 35, wy0, wx0 + 37, wy1), fill=SLATE)
    d.rectangle((wx0, wy0 + 38, wx1, wy0 + 40), fill=SLATE)
    d.rectangle((wx0 - 6, wy1 + 4, wx1 + 6, wy1 + 8), fill=SLATE_M, outline=NAVY)
    d.line((wx0 - 5, wy1 + 5, wx1 + 5, wy1 + 5), fill=STEEL)
    # plant on the sill
    d.rectangle((40, wy1 - 2, 48, wy1 + 4), fill=MUG_D, outline=NAVY)
    for lx, ly in ((44, wy1 - 9), (40, wy1 - 6), (48, wy1 - 6), (42, wy1 - 12), (46, wy1 - 11)):
        d.ellipse((lx - 2, ly - 2, lx + 2, ly + 2), fill=GREEN_D, outline=NAVY)
    # clock
    clock(img, 150, 58, 7 if day else 2, 15 if day else 47)
    # poster: phase diagram
    d.rectangle((124, 84, 176, 120), fill=PAPER_D, outline=NAVY)
    d.rectangle((126, 86, 174, 118), fill=PAPER)
    d.line((130, 114, 150, 100, 170, 90), fill=WATER)
    d.line((150, 100, 152, 116), fill=HEAT)
    d.line((130, 92, 150, 100), fill=ICE_D)
    text(img, (130, 88), "H2O", INK)
    d.rectangle((158, 108, 162, 112), fill=GREEN)
    # shelves with jars
    for sy in (78, 112):
        d.rectangle((246, sy, 364, sy + 3), fill=SLATE_L, outline=NAVY)
        d.line((247, sy + 1, 363, sy + 1), fill=STEEL)
        for bx in (254, 352):
            d.polygon([(bx, sy + 4), (bx + 6, sy + 4), (bx, sy + 10)], fill=SLATE, outline=NAVY)
    items = [(250, 78, ICE, "erl", 10, 14), (262, 78, GREEN, "jar", 8, 12), (272, 78, HEAT, "round", 11, 13),
             (290, 78, WATER, "jar", 7, 16), (300, 78, STEAM_D, "erl", 12, 15), (318, 78, GREEN, "round", 10, 12),
             (334, 78, ICE, "jar", 9, 10), (346, 78, HEAT_L, "erl", 9, 13),
             (252, 112, WATER, "round", 12, 14), (268, 112, ICE, "jar", 7, 11), (280, 112, HEAT, "erl", 10, 12),
             (296, 112, GREEN, "jar", 9, 15), (314, 112, STEAM_D, "round", 10, 12), (330, 112, WATER_L, "erl", 11, 14),
             (346, 112, GREEN_D, "jar", 8, 9)]
    for (x, sy, col, kind, w, h) in items:
        f = small_flask(col, w, h, kind)
        img.alpha_composite(f, (x, sy - h))
    # door frame (doorway dark, the shutter is a separate sprite)
    dx0, dy0, dx1, dy1 = 392, 112, 462, 230
    d.rectangle((dx0, dy0, dx1, dy1), fill=SLATE, outline=NAVY)
    d.rectangle((dx0 + 4, dy0 + 6, dx1 - 4, dy1), fill=NIGHT, outline=NAVY)
    dither_fill(img, (dx0 + 5, dy0 + 7, dx1 - 4, dy1), [C("0A1222"), C("101C33"), C("18284A")])
    d.line((dx0 + 5, dy0 + 7, dx1 - 5, dy0 + 7), fill=C("2E4A6E"))
    # hazard stripes on the header
    for i in range(dx0 + 1, dx1, 6):
        d.polygon([(i, dy0 + 5), (i + 3, dy0 + 1), (i + 6, dy0 + 1), (i + 3, dy0 + 5)], fill=AMBER)
    d.line((dx0, dy0, dx1, dy0), fill=NAVY)
    d.line((dx0 + 1, dy0 + 6, dx1 - 1, dy0 + 6), fill=NAVY)
    d.line((dx0 + 1, dy0 + 7, dx0 + 1, dy1), fill=SLATE_L)
    # sign
    s = "CONTAINMENT"
    tw = text_w(s)
    sx = (dx0 + dx1) // 2 - tw // 2
    d.rectangle((sx - 3, 98, sx + tw + 2, 106), fill=SLATE_M, outline=NAVY)
    text(img, (sx, 100), s, ICE)
    # alarm lamp base
    d.rectangle((420, 92, 434, 96), fill=SLATE_L, outline=NAVY)
    # keypad
    d.rectangle((466, 160, 474, 174), fill=SLATE_M, outline=NAVY)
    d.point((470, 164), fill=GREEN)
    d.line((468, 168, 472, 168), fill=SLATE_L)
    d.line((468, 170, 472, 170), fill=SLATE_L)
    # wall plate "LAB 3"
    d.rectangle((196, 124, 222, 132), fill=SLATE_M, outline=NAVY)
    text(img, (199, 126), "LAB 3", STEEL_L)
    # socket + cable to the regulator
    d.rectangle((318, 150, 326, 158), fill=SLATE_M, outline=NAVY)
    d.point((320, 154), fill=NAVY)
    d.point((324, 154), fill=NAVY)
    # floor
    d.rectangle((0, 230, W, H), fill=C("121C2C"))
    d.line((0, 230, W, 230), fill=SLATE_L)
    d.line((0, 231, W, 231), fill=SLATE)
    for y in (240, 254):
        d.line((0, y, W, y), fill=C("0F1726"))
    for x in range(-200, W + 200, 40):
        d.line((240 + (x - 240) * 0.55, 232, 240 + (x - 240) * 1.2, H), fill=C("0F1726"))
    dither_blend(img, (0, 232, W, H), NAVY, lambda x, y: (y - 232) / 60)
    # drain grate
    d.ellipse((224, 238, 258, 248), fill=SLATE, outline=NAVY)
    d.ellipse((227, 240, 255, 246), fill=NIGHT)
    for gx in range(230, 254, 4):
        d.line((gx, 240, gx, 246), fill=SLATE_L)
    d.arc((224, 238, 258, 248), 200, 340, fill=STEEL)
    return img


def lamp_sprites():
    # hanging lamp + cone (additive)
    lamp = new(24, 40)
    d = ImageDraw.Draw(lamp)
    d.line((12, 0, 12, 28), fill=NAVY)
    d.polygon([(4, 36), (20, 36), (16, 28), (8, 28)], fill=SLATE_M)
    d.line((8, 29, 16, 29), fill=STEEL)
    d.rectangle((9, 36, 15, 38), fill=AMBER)
    lamp = outline(lamp)
    save(lamp, "lamp.png")
    cone = new(150, 160)
    px = cone.load()
    for y in range(160):
        half = 6 + y * 0.42
        for x in range(150):
            dx = abs(x - 75)
            if dx < half:
                v = (1 - y / 160) * (1 - (dx / half) ** 2)
                band = math.ceil(v * 4) / 4
                if band > 0:
                    px[x, y] = (255, 214, 150, int(60 * band))
    save(cone, "lamp_cone.png")


def bench():
    w, h = 190, 40
    img = new(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, w - 1, 5), fill=SLATE_L)
    d.line((0, 1, w - 1, 1), fill=STEEL)
    d.line((0, 5, w - 1, 5), fill=SLATE)
    d.rectangle((3, 6, w - 4, h - 1), fill=SLATE)
    for i, x in enumerate(range(6, w - 8, 46)):
        d.rectangle((x, 9, x + 42, h - 4), fill=SLATE_M if i % 2 == 0 else SLATE, outline=NAVY)
        d.line((x + 1, 10, x + 41, 10), fill=SLATE_L)
        d.rectangle((x + 17, 14, x + 25, 15), fill=STEEL)
    d.rectangle((3, h - 3, w - 4, h - 1), fill=NAVY)
    return outline(img)


def regulator(charged=False):
    w, h = 46, 56
    img = new(w, h)
    d = ImageDraw.Draw(img)
    # body
    d.rectangle((3, 22, 42, 55), fill=SLATE_M)
    d.line((3, 22, 42, 22), fill=STEEL)
    d.line((42, 23, 42, 55), fill=SLATE)
    d.rectangle((8, 27, 22, 37), fill=NIGHT, outline=NAVY)
    # screen waveform
    pts = [(9 + i, 32 + round(math.sin(i * 0.9) * (3 if charged else 1.5))) for i in range(13)]
    d.line(pts, fill=HEAT if charged else GREEN)
    for i, cx in enumerate((29, 37)):
        d.ellipse((cx - 4, 27, cx + 4, 35), fill=STEEL_L, outline=NAVY)
        a = (0.8 if charged else -0.6) + i
        d.line((cx, 31, cx + round(math.cos(a) * 3), 31 + round(math.sin(a) * 3)), fill=HEAT_D)
    for i, x in enumerate(range(8, 40, 6)):
        d.rectangle((x, 42, x + 3, 45), fill=(HEAT if charged and i % 2 else GREEN_D) if i < 4 else SLATE)
    d.rectangle((8, 49, 37, 51), fill=SLATE)
    # coil tower
    d.rectangle((19, 10, 26, 22), fill=SLATE)
    for y in range(11, 22, 2):
        d.line((18, y, 27, y), fill=HEAT_D if not charged else HEAT_L)
    d.ellipse((14, 0, 31, 12), fill=STEEL if not charged else ICE)
    d.ellipse((17, 2, 22, 6), fill=STEEL_L if not charged else STEAM)
    img = outline(img)
    # cable
    d = ImageDraw.Draw(img)
    return img


# =================================================================================
# Scientist (Dr. Kettle), 40x72 frames
# =================================================================================

def sci_base(d, img, hair_wild=False, bandage=False):
    # legs + shoes
    d.rectangle((14, 58, 18, 67), fill=PANTS)
    d.rectangle((22, 58, 26, 67), fill=PANTS)
    d.rectangle((12, 67, 18, 70), fill=SHOE)
    d.rectangle((22, 67, 28, 70), fill=SHOE)
    d.line((13, 67, 17, 67), fill=SLATE_L)
    d.line((23, 67, 27, 67), fill=SLATE_L)
    # coat
    d.polygon([(12, 27), (28, 27), (31, 59), (9, 59)], fill=COAT)
    d.polygon([(26, 27), (28, 27), (31, 59), (27, 59)], fill=COAT_D)
    d.line((20, 44, 20, 59), fill=COAT_D)
    d.polygon([(17, 27), (23, 27), (20, 34)], fill=WATER)
    d.line((16, 27, 20, 38), fill=COAT_D)
    d.line((24, 27, 20, 38), fill=COAT_D)
    d.point((20, 41), fill=COAT_DD)
    d.point((20, 47), fill=COAT_DD)
    d.rectangle((11, 48, 16, 52), outline=COAT_D)
    d.rectangle((24, 48, 29, 52), outline=COAT_D)
    d.line((26, 30, 26, 33), fill=HEAT)  # pen in chest pocket
    d.rectangle((23, 33, 28, 36), outline=COAT_D)
    # neck + head
    d.rectangle((18, 23, 22, 27), fill=SKIN_D)
    d.ellipse((11, 6, 29, 25), fill=SKIN)
    d.chord((11, 6, 29, 25), 30, 150, fill=SKIN_D)
    d.ellipse((12, 6, 28, 23), fill=SKIN)
    # hair
    d.ellipse((10, 2, 30, 17), fill=HAIR)
    d.rectangle((10, 10, 13, 19), fill=HAIR)
    d.rectangle((27, 10, 30, 19), fill=HAIR)
    d.polygon([(14, 12), (26, 12), (25, 15), (20, 13), (15, 15)], fill=HAIR)
    d.line((14, 4, 20, 3), fill=HAIR_L)
    tufts = [(13, 1), (16, 0), (22, 1), (26, 2), (29, 4)]
    if hair_wild:
        tufts += [(9, 0), (11, -1), (19, -2), (24, -1), (31, 1), (32, 6), (8, 5)]
    for tx, ty in tufts:
        d.polygon([(tx - 2, ty + 4), (tx, max(0, ty)), (tx + 2, ty + 4)], fill=HAIR)
    d.line((11, 8, 11, 17), fill=HAIR_D)
    # goggles pushed up on the forehead
    d.line((10, 8, 30, 8), fill=SLATE)
    d.line((10, 9, 30, 9), fill=SLATE)
    for gx in (13, 22):
        d.rectangle((gx, 6, gx + 5, 10), fill=AMBER, outline=SLATE)
        d.point((gx + 1, 7), fill=STEAM)
    if bandage:
        d.rectangle((24, 3, 29, 5), fill=STEAM)
        d.rectangle((25, 2, 27, 6), fill=STEAM)
        d.point((26, 4), fill=STEAM_D)


def sci_face(d, kind="normal"):
    if kind == "normal":
        for ex in (16, 23):
            d.rectangle((ex, 16, ex + 1, 18), fill=NAVY)
            d.point((ex, 16), fill=WHITE)
        d.line((19, 21, 21, 21), fill=MUG_D)
    elif kind == "closed":
        d.line((15, 17, 17, 17), fill=NAVY)
        d.line((23, 17, 25, 17), fill=NAVY)
        d.line((19, 21, 21, 21), fill=MUG_D)
    elif kind == "happy":
        for ex in (15, 22):
            d.point((ex, 18), fill=NAVY)
            d.line((ex + 1, 17, ex + 2, 17), fill=NAVY)
            d.point((ex + 3, 18), fill=NAVY)
        d.line((18, 20, 22, 20), fill=MUG_D)
        d.line((19, 21, 21, 21), fill=MUG_D)
    elif kind == "shock":
        for ex in (15, 22):
            d.rectangle((ex, 15, ex + 2, 18), fill=WHITE, outline=NAVY)
            d.point((ex + 1, 16), fill=NAVY)
        d.ellipse((18, 20, 21, 23), fill=NAVY)
    elif kind == "dizzy":
        for ex in (15, 22):
            d.line((ex, 15, ex + 2, 18), fill=NAVY)
            d.line((ex + 2, 15, ex, 18), fill=NAVY)
        d.line((18, 21, 22, 21), fill=MUG_D)
    elif kind == "tired":
        for ex in (16, 23):
            d.rectangle((ex, 17, ex + 1, 18), fill=NAVY)
            d.line((ex - 1, 16, ex + 2, 16), fill=HAIR_D)
        d.line((19, 21, 21, 21), fill=MUG_D)
    d.point((14, 20), fill=BLUSH)
    d.point((26, 20), fill=BLUSH)


def mug(d, x, y):
    d.rectangle((x, y, x + 6, y + 7), fill=MUG)
    d.line((x + 5, y + 1, x + 5, y + 6), fill=MUG_D)
    d.rectangle((x - 2, y + 2, x - 1, y + 5), outline=MUG_D)
    d.line((x + 1, y, x + 4, y), fill=C("4A2A1E"))
    d.point((x + 1, y + 2), fill=C("F5B7B0"))


def scientist(pose):
    img = new(40, 72)
    d = ImageDraw.Draw(img)
    if pose in ("idle", "sip", "morning", "morning_smile", "limp"):
        # left arm hanging
        d.polygon([(12, 28), (9, 30), (8, 50), (12, 50), (13, 32)], fill=COAT)
        d.line((9, 32, 9, 49), fill=COAT_D)
        d.rectangle((8, 50, 11, 53), fill=SKIN)
    sci_base(d, img, hair_wild=(pose == "shock"), bandage=pose.startswith("morning"))
    if pose == "idle":
        d.polygon([(28, 28), (31, 31), (31, 42), (27, 42)], fill=COAT_D)
        d.rectangle((20, 38, 30, 42), fill=COAT)
        d.line((20, 42, 30, 42), fill=COAT_D)
        d.rectangle((18, 37, 21, 41), fill=SKIN)
        mug(d, 13, 33)
        sci_face(d, "normal")
    elif pose == "sip":
        d.polygon([(28, 28), (31, 31), (31, 40), (27, 40)], fill=COAT_D)
        d.polygon([(27, 36), (31, 38), (27, 26), (24, 26)], fill=COAT)
        d.rectangle((23, 22, 27, 26), fill=SKIN)
        mug(d, 21, 15)
        sci_face(d, "closed")
    elif pose == "shock":
        for side in (-1, 1):
            sx = 20 + side * 8
            d.polygon([(sx, 28), (sx + side * 4, 28), (sx + side * 13, 12), (sx + side * 9, 10)], fill=COAT)
            hx = 20 + side * 18
            d.rectangle((hx - 2, 6, hx + 1, 10), fill=SKIN)
        d.line((28, 28, 37, 13), fill=COAT_D)
        sci_face(d, "shock")
    elif pose in ("morning", "morning_smile"):
        d.polygon([(28, 28), (31, 31), (31, 42), (27, 42)], fill=COAT_D)
        d.rectangle((20, 38, 30, 42), fill=COAT)
        d.rectangle((17, 37, 21, 41), fill=SKIN)
        # empty flask in hand
        fl = small_flask(lerp(ICE, CLEAR, 0.7), 9, 13)
        img.alpha_composite(fl, (11, 28))
        d = ImageDraw.Draw(img)
        d.rectangle((17, 37, 20, 40), fill=SKIN)
        sci_face(d, "happy" if pose == "morning_smile" else "tired")
    elif pose == "limp":
        d.polygon([(28, 28), (31, 31), (32, 50), (28, 50)], fill=COAT_D)
        d.rectangle((28, 50, 31, 53), fill=SKIN)
        sci_face(d, "dizzy")
    return outline(img)


def scientist_sheet():
    poses = ["idle", "sip", "shock", "morning", "morning_smile"]
    sheet = new(40 * len(poses), 72)
    for i, p in enumerate(poses):
        sheet.alpha_composite(scientist(p), (i * 40, 0))
    save(sheet, "scientist.png")
    lying = scientist("limp").rotate(90, expand=True)  # head on the left
    canvas = new(76, 44)
    canvas.alpha_composite(lying, (2, 2))
    d = ImageDraw.Draw(canvas)
    # spilled mug + puddle of coffee
    d.ellipse((50, 38, 74, 43), fill=C("4A2A1E"))
    mugi = new(12, 10)
    md = ImageDraw.Draw(mugi)
    md.rectangle((1, 2, 8, 8), fill=MUG)
    md.line((1, 8, 8, 8), fill=MUG_D)
    mugi = outline(mugi.rotate(-90, expand=True))
    canvas.alpha_composite(mugi, (62, 28))
    save(canvas, "scientist_fainted.png")
    # dizzy stars, 3 frames 20x10
    sh = new(60, 10)
    d = ImageDraw.Draw(sh)
    for f in range(3):
        for k in range(3):
            a = (f / 3 + k / 3) * math.tau
            x = f * 20 + 10 + round(math.cos(a) * 7)
            y = 5 + round(math.sin(a) * 3)
            d.point([(x, y - 1), (x - 1, y), (x, y), (x + 1, y), (x, y + 1)], fill=AMBER)
            d.point((x, y), fill=STEAM)
    save(sh, "dizzy.png")


# =================================================================================
# Blob (H2O) + eyes
# =================================================================================

def blob_water(w, h, kind="normal"):
    img = new(w, h)
    d = ImageDraw.Draw(img)
    if kind == "squash":
        bw, bh = w - 2, int(h * 0.62)
    elif kind == "stretch":
        bw, bh = int(w * 0.66), h - 1
    else:
        bw, bh = int(w * 0.86), int(h * 0.8)
    x0 = (w - bw) // 2
    y0 = h - bh
    # dome: wide base + round top + side bumps
    d.ellipse((x0, y0 + bh * 0.35, x0 + bw - 1, h - 1), fill=WATER)
    d.ellipse((x0 + bw * 0.14, y0, x0 + bw * 0.86, y0 + bh * 0.85), fill=WATER)
    d.ellipse((x0 - 1, y0 + bh * 0.45, x0 + bw * 0.35, h - 2), fill=WATER)
    d.ellipse((x0 + bw * 0.65, y0 + bh * 0.45, x0 + bw, h - 2), fill=WATER)
    # shading
    m = img.split()[3]
    sh = new(w, h)
    sd = ImageDraw.Draw(sh)
    sd.ellipse((x0 - bw * 0.2, y0 + bh * 0.62, x0 + bw * 1.2, h + bh * 0.5), fill=WATER_D)
    sd.rectangle((0, h - 2, w, h), fill=WATER_DD)
    img.paste(sh, (0, 0), ImageChops.multiply(m, sh.split()[3]))
    d = ImageDraw.Draw(img)
    # highlight
    hx, hy = x0 + bw * 0.26, y0 + bh * 0.14
    d.ellipse((hx, hy, hx + max(3, bw * 0.2), hy + max(2, bh * 0.16)), fill=WATER_L)
    d.point((hx + 1, hy + 1), fill=STEAM)
    d.arc((x0 + bw * 0.14 + 1, y0 + 1, x0 + bw * 0.86 - 1, y0 + bh * 0.85), 200, 250, fill=WATER_L)
    return outline(img)


def blob_ice(w, h):
    img = new(w, h)
    d = ImageDraw.Draw(img)
    s = min(w, h) - 2
    x0, y0 = (w - s) // 2, h - s
    d.rounded_rectangle((x0, y0, x0 + s - 1, h - 1), radius=max(2, s // 7), fill=ICE)
    d.rectangle((x0 + 2, y0 + 2, x0 + s - 3, y0 + s // 4), fill=C("DDF3FF"))
    d.polygon([(x0 + s - 4, y0 + 3), (x0 + s - 3, y0 + 3), (x0 + s - 3, h - 3), (x0 + s - 6, h - 3)], fill=ICE_D)
    d.rectangle((x0 + 2, h - 4, x0 + s - 3, h - 3), fill=ICE_D)
    d.line((x0 + 3, y0 + 3, x0 + 3 + s // 5, y0 + 3), fill=WHITE)
    d.line((x0 + 3, y0 + 4, x0 + 3, y0 + 4 + s // 6), fill=WHITE)
    d.line((x0 + s * 0.7, h - s * 0.3, x0 + s * 0.8, h - s * 0.18), fill=WHITE)
    return outline(img, C("2B5A86"))


def blob_steam(w, h):
    img = new(w, h)
    d = ImageDraw.Draw(img)
    puffs = [(0.30, 0.55, 0.26), (0.55, 0.42, 0.30), (0.78, 0.6, 0.22), (0.18, 0.72, 0.18), (0.5, 0.72, 0.28)]
    for (px_, py_, r) in puffs:
        cx, cy, rr = px_ * w, py_ * h, r * w
        d.ellipse((cx - rr, cy - rr * 0.85, cx + rr, cy + rr * 0.85), fill=STEAM)
    m = img.split()[3]
    sh = new(w, h)
    sd = ImageDraw.Draw(sh)
    sd.ellipse((-w * 0.2, h * 0.68, w * 1.2, h * 1.5), fill=STEAM_D)
    img.paste(sh, (0, 0), ImageChops.multiply(m, sh.split()[3]))
    d = ImageDraw.Draw(img)
    d.ellipse((w * 0.42, h * 0.2, w * 0.55, h * 0.3), fill=WHITE)
    return outline(img, C("6D7F99"))


def blob_sheet(w, h, name):
    frames = [blob_water(w, h), blob_water(w, h, "squash"), blob_water(w, h, "stretch"), blob_ice(w, h), blob_steam(w, h)]
    sheet = new(w * len(frames), h)
    for i, f in enumerate(frames):
        sheet.alpha_composite(f, (i * w, 0))
    save(sheet, name)


def eyes_sheet(ew, eh, gap, name):
    """Frames: 0 open, 1 half, 2 closed, 3 look left, 4 look right, 5 happy, 6 determined, 7 scared, 8 look up."""
    fw = ew * 2 + gap + 2
    fh = eh + 4
    n = 9
    sheet = new(fw * n, fh)
    for f in range(n):
        fr = new(fw, fh)
        d = ImageDraw.Draw(fr)
        for k in range(2):
            x0 = 1 + k * (ew + gap)
            y0 = 3
            box = (x0, y0, x0 + ew - 1, y0 + eh - 1)
            pw, ph = max(2, ew // 2), max(2, eh // 2 + 1)
            cx, cy = x0 + (ew - pw) // 2, y0 + (eh - ph) // 2 + 1
            if f in (0, 3, 4, 7, 8, 6):
                d.ellipse(box, fill=WHITE, outline=NAVY)
                if f == 3:
                    cx -= max(1, ew // 5)
                if f == 4:
                    cx += max(1, ew // 5)
                if f == 8:
                    cy -= max(1, eh // 4)
                if f == 7:
                    pw, ph = max(1, pw - 1), max(1, ph - 2)
                    cx, cy = x0 + (ew - pw) // 2, y0 + (eh - ph) // 2
                d.rectangle((cx, cy, cx + pw - 1, cy + ph - 1), fill=NAVY)
                if pw >= 2:
                    d.point((cx + pw - 1, cy), fill=WHITE)
                if f == 6:  # determined brows
                    if k == 0:
                        d.line((x0 - 1, y0 - 2, x0 + ew - 1, y0), fill=NAVY)
                    else:
                        d.line((x0, y0, x0 + ew, y0 - 2), fill=NAVY)
                    d.rectangle((x0 + 1, y0, x0 + ew - 2, y0 + 1), fill=NAVY)
                if f == 7:  # little sweat drop
                    if k == 1:
                        d.point((x0 + ew + 1, y0 - 1), fill=ICE)
                        d.point((x0 + ew + 1, y0), fill=ICE)
            elif f == 1:
                d.ellipse(box, fill=WHITE, outline=NAVY)
                d.rectangle((x0, y0, x0 + ew - 1, y0 + eh // 2 - 1), fill=CLEAR)
                d.line((x0, y0 + eh // 2, x0 + ew - 1, y0 + eh // 2), fill=NAVY)
                d.rectangle((cx, y0 + eh // 2 + 1, cx + pw - 1, y0 + eh - 2), fill=NAVY)
            elif f == 2:
                d.line((x0, y0 + eh // 2 + 1, x0 + ew - 1, y0 + eh // 2 + 1), fill=NAVY)
                d.line((x0 + 1, y0 + eh // 2 + 2, x0 + ew - 2, y0 + eh // 2 + 2), fill=NAVY)
            elif f == 5:
                my = y0 + eh // 2
                d.arc((x0, my - 1, x0 + ew - 1, my + eh // 2 + 2), 190, 350, fill=NAVY, width=2 if ew >= 7 else 1)
        sheet.alpha_composite(fr, (f * fw, 0))
    save(sheet, name)
    return fw, fh


# =================================================================================
# Close-up bench + big flask
# =================================================================================

def flask_shape(w=80, h=104):
    """Mask of an Erlenmeyer flask."""
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    d.rectangle((28, 0, 51, 5), fill=255)
    d.rectangle((31, 5, 48, 34), fill=255)
    d.polygon([(31, 34), (48, 34), (w - 3, h - 10), (2, h - 10)], fill=255)
    d.rounded_rectangle((2, h - 22, w - 3, h - 1), radius=6, fill=255)
    return m


def flask_layers():
    w, h = 80, 104
    m = flask_shape(w, h)
    back = new(w, h)
    back.paste(lerp(ICE, CLEAR, 0.82), (0, 0, w, h), m)
    save(back, "flask_back.png")
    # liquid frames
    level = 50
    inner = Image.new("L", (w, h), 0)
    inner.paste(m, (0, 0))
    # erode by 2
    from PIL import ImageFilter
    inner = inner.filter(ImageFilter.MinFilter(5))
    liq = Image.new("L", (w, h), 0)
    liq.paste(inner, (0, 0))
    ImageDraw.Draw(liq).rectangle((0, 0, w, level - 1), fill=0)
    frames = []
    specs = [("calm", WATER, WATER_D, WATER_L), ("teal", C("3FC7D9"), C("2A8FB0"), C("9AF0F0")),
             ("bub1", C("3FC7D9"), C("2A8FB0"), C("9AF0F0")), ("bub2", C("3FC7D9"), C("2A8FB0"), C("9AF0F0")),
             ("glow", C("A8F0FF"), C("5EC8FF"), STEAM), ("awake", WATER, WATER_D, WATER_L), ("empty", None, None, None)]
    for name, base, dark, light in specs:
        f = new(w, h)
        if base:
            f.paste(base, (0, 0, w, h), liq)
            d = ImageDraw.Draw(f)
            sh = new(w, h)
            ImageDraw.Draw(sh).ellipse((-10, h - 30, w + 10, h + 30), fill=dark)
            f.paste(sh, (0, 0), ImageChops.multiply(liq, sh.split()[3]))
            d = ImageDraw.Draw(f)
            # surface line
            xs = [x for x in range(w) if liq.getpixel((x, level + 1)) > 0]
            if xs:
                d.line((xs[0], level, xs[-1], level), fill=light)
                d.line((xs[0], level + 1, xs[-1], level + 1), fill=lerp(light, base, 0.5))
            if name.startswith("bub") or name == "teal":
                rnd = random.Random({"teal": 1, "bub1": 2, "bub2": 3}[name])
                for _ in range(16 if name != "teal" else 5):
                    bx = rnd.randrange(14, 66)
                    by = rnd.randrange(level + 4, h - 8)
                    if liq.getpixel((bx, by)) and liq.getpixel((bx + 3, by + 3)):
                        r = rnd.choice((1, 1, 2))
                        d.ellipse((bx, by, bx + r * 2, by + r * 2), outline=light)
                if name != "teal":
                    # surface froth
                    for x in range(xs[0], xs[-1], 3):
                        d.ellipse((x, level - 2 - (x * 7 + len(name)) % 3, x + 3, level + 1), fill=light)
            if name == "glow":
                for _ in range(20):
                    bx, by = random.randrange(10, 70), random.randrange(level + 3, h - 6)
                    if liq.getpixel((bx, by)):
                        d.point((bx, by), fill=WHITE)
            if name == "awake":
                d.arc((14, level + 8, 30, level + 14), 200, 340, fill=light)
            # a few droplets clinging to the empty space above
        else:
            d = ImageDraw.Draw(f)
            residue = Image.new("L", (w, h), 0)
            residue.paste(inner, (0, 0))
            ImageDraw.Draw(residue).rectangle((0, 0, w, h - 9), fill=0)
            f.paste(lerp(WATER, CLEAR, 0.4), (0, 0, w, h), residue)
            for (x, y) in ((24, 70), (52, 62), (40, 80), (60, 84)):
                d.point((x, y), fill=lerp(WATER_L, CLEAR, 0.3))
                d.point((x, y + 1), fill=lerp(WATER, CLEAR, 0.3))
        frames.append(f)
    sheet = new(w * len(frames), h)
    for i, f in enumerate(frames):
        sheet.alpha_composite(f, (i * w, 0))
    save(sheet, "flask_liquid.png")
    # front: outline, highlights, label
    front = new(w, h)
    edge = ImageChops.subtract(m, m.filter(__import__("PIL.ImageFilter", fromlist=["MinFilter"]).MinFilter(3)))
    front.paste(STEEL_L, (0, 0, w, h), edge)
    front = outline(front)
    d = ImageDraw.Draw(front)
    d.line((34, 7, 34, 30), fill=lerp(WHITE, CLEAR, 0.2))
    d.line((26, 44, 12, 74), fill=lerp(WHITE, CLEAR, 0.25))
    d.line((25, 44, 11, 74), fill=lerp(WHITE, CLEAR, 0.6))
    d.line((14, 86, 18, 86), fill=lerp(WHITE, CLEAR, 0.4))
    d.rectangle((27, 0, 52, 4), outline=NAVY)
    d.line((29, 1, 50, 1), fill=STEAM)
    # sticker label
    d.rectangle((48, 74, 66, 86), fill=PAPER, outline=NAVY)
    d.line((49, 85, 65, 85), fill=PAPER_D)
    text(front, (50, 76), "NO", INK)
    text(front, (58, 76), "47", HEAT_D)
    d.line((50, 82, 64, 82), fill=PAPER_D)
    save(front, "flask_front.png")


def bench_close():
    W, H = 480, 270
    img = new(W, H, WALL)
    d = ImageDraw.Draw(img)
    for y in range(-8, 200, 32):
        d.line((0, y, W, y), fill=WALL_D)
        d.line((0, y + 1, W, y + 1), fill=WALL_L)
    for x in range(-16, W, 32):
        d.line((x, 0, x, 200), fill=WALL_D)
        d.line((x + 1, 0, x + 1, 200), fill=WALL_L)
    for _ in range(300):
        d.point((random.randrange(W), random.randrange(200)), fill=WALL_D)
    # banded pool of lamp light behind the flask
    for k, col in enumerate((C("1F3045"), C("23364C"), C("283C53"))):
        rx, ry = 230 - k * 55, 150 - k * 35
        d.ellipse((240 - rx, 200 - ry, 240 + rx, 200 + ry), fill=col)
    for y in range(-8, 200, 32):
        d.line((0, y, W, y), fill=WALL_D)
    for x in range(-16, W, 32):
        d.line((x, 0, x, 200), fill=WALL_D)
    dither_blend(img, (0, 0, W, 90), NAVY, lambda x, y: 0.6 * (1 - y / 90) ** 1.5)
    # wall shelf, blurry silhouettes of jars
    d.rectangle((20, 70, 150, 73), fill=SLATE, outline=NAVY)
    for i, x in enumerate(range(28, 140, 22)):
        hh = 18 + (i * 5) % 10
        col = [ICE_D, GREEN_D, HEAT_D, WATER_D, SLATE_L][i % 5]
        d.rounded_rectangle((x, 70 - hh, x + 14, 70), radius=3, fill=lerp(col, WALL, 0.55), outline=lerp(NAVY, WALL, 0.3))
    # cable from the coil machine
    d.line([(480, 150), (440, 170), (420, 200)], fill=NAVY, width=3)
    # counter
    d.rectangle((0, 200, W, 214), fill=SLATE_L)
    d.line((0, 200, W, 200), fill=STEEL)
    d.line((0, 201, W, 201), fill=STEEL_L)
    dither_blend(img, (0, 202, W, 214), STEEL, lambda x, y: 0.5 - abs(x - 240) / 480)
    d.rectangle((0, 214, W, H), fill=SLATE)
    d.line((0, 214, W, 214), fill=NAVY)
    d.line((0, 215, W, 215), fill=SLATE_M)
    for x in range(10, W, 120):
        d.rectangle((x, 224, x + 110, H + 2), fill=SLATE_M, outline=NAVY)
        d.line((x + 1, 225, x + 109, 225), fill=SLATE_L)
        d.rectangle((x + 45, 236, x + 65, 239), fill=STEEL, outline=NAVY)
    dither_blend(img, (0, 216, W, H), NAVY, lambda x, y: (y - 216) / 70)
    # notebook
    d.polygon([(92, 206), (170, 206), (176, 198), (98, 198)], fill=PAPER, outline=NAVY)
    d.line((134, 198, 133, 206), fill=PAPER_D)
    for k in range(3):
        d.line((102 + k * 2, 200 + k * 2, 128 + k * 2, 200 + k * 2), fill=PAPER_D)
        d.line((140 + k, 200 + k * 2, 166 + k, 200 + k * 2), fill=PAPER_D)
    d.line((92, 207, 170, 207), fill=PAPER_D)
    d.line((150, 196, 168, 203), fill=HEAT, width=2)
    # test-tube rack
    d.rectangle((330, 190, 400, 194), fill=WOOD, outline=NAVY)
    d.rectangle((332, 202, 398, 206), fill=WOOD, outline=NAVY)
    for i, x in enumerate(range(338, 396, 12)):
        col = [ICE, GREEN, HEAT_L, WATER_L, STEAM_D][i % 5]
        d.rounded_rectangle((x, 172, x + 6, 200), radius=3, fill=lerp(ICE, WALL, 0.6), outline=NAVY)
        d.rounded_rectangle((x + 1, 186 - i * 2, x + 5, 199), radius=2, fill=col)
        d.point((x + 2, 175), fill=STEAM)
    d.line((334, 194, 334, 206), fill=NAVY)
    d.line((396, 194, 396, 206), fill=NAVY)
    return img


def coffee_mug_big():
    img = new(30, 30)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((2, 4, 22, 29), radius=3, fill=MUG)
    d.rectangle((17, 5, 21, 28), fill=MUG_D)
    d.ellipse((18, 9, 29, 22), outline=MUG, width=3)
    d.ellipse((2, 2, 22, 8), fill=MUG_D)
    d.ellipse((4, 3, 20, 7), fill=C("4A2A1E"))
    d.line((5, 10, 5, 24), fill=C("F5B7B0"))
    text(img, (6, 14), "H2O", STEAM)
    save(outline(img), "mug.png")


def coil_machine(charged):
    w, h = 72, 130
    img = new(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle((14, 60, 70, 129), fill=SLATE_M)
    d.line((14, 60, 70, 60), fill=STEEL)
    d.rectangle((22, 70, 50, 90), fill=NIGHT, outline=NAVY)
    pts = [(23 + i, 80 + round(math.sin(i * 0.7) * (6 if charged else 2))) for i in range(27)]
    d.line(pts, fill=HEAT if charged else GREEN)
    for i in range(4):
        d.rectangle((22 + i * 8, 98, 26 + i * 8, 102), fill=(HEAT if charged else GREEN_D) if i % 2 == 0 else SLATE)
    d.ellipse((54, 70, 66, 82), fill=STEEL_L, outline=NAVY)
    d.line((60, 76, 64 if charged else 56, 72), fill=HEAT_D)
    text(img, (22, 110), "THERMO", ICE if not charged else HEAT_L)
    text(img, (22, 117), "REG 9000", STEEL)
    d.rectangle((32, 22, 46, 60), fill=SLATE)
    for y in range(24, 60, 3):
        d.line((30, y, 48, y), fill=HEAT_L if charged else HEAT_D)
        d.line((30, y + 1, 48, y + 1), fill=lerp(HEAT_D, NAVY, 0.4))
    d.ellipse((24, 0, 54, 26), fill=ICE if charged else STEEL)
    d.ellipse((28, 3, 38, 10), fill=STEAM if charged else STEEL_L)
    d.arc((24, 0, 54, 26), 20, 160, fill=SLATE_L if not charged else ICE_D)
    return outline(img)


def hand_vial():
    fw, fh = 90, 70
    sheet = new(fw * 2, fh)
    for i, col in enumerate((ICE_D, HEAT)):
        f = new(fw, fh)
        d = ImageDraw.Draw(f)
        d.polygon([(0, 0), (26, 0), (52, 30), (40, 42)], fill=COAT)
        d.line((14, 4, 44, 38), fill=COAT_D, width=2)
        d.polygon([(40, 42), (52, 30), (54, 34), (44, 44)], fill=COAT_D)
        d.ellipse((44, 30, 60, 46), fill=SKIN)
        d.ellipse((46, 38, 60, 46), fill=SKIN_D)
        # tilted tube
        d.line((52, 26, 80, 54), fill=lerp(ICE, CLEAR, 0.3), width=7)
        d.line((70, 44, 80, 54), fill=col, width=5)
        d.line((53, 25, 57, 29), fill=STEEL, width=7)
        d.line((54, 26, 76, 48), fill=WHITE)
        d.rectangle((48, 32, 56, 40), fill=SKIN)
        d.line((48, 36, 56, 36), fill=SKIN_D)
        f = outline(f)
        sheet.alpha_composite(f, (i * fw, 0))
    save(sheet, "hand_vial.png")
    drops = new(16, 7)
    d = ImageDraw.Draw(drops)
    for i, col in enumerate((ICE_D, HEAT)):
        d.ellipse((i * 8 + 1, 2, i * 8 + 5, 6), fill=col)
        d.point((i * 8 + 3, 1), fill=col)
        d.point((i * 8 + 2, 3), fill=WHITE)
    save(outline(drops), "drops.png")


def bolt(p0, p1, seed, branch=True):
    rnd = random.Random(seed)
    x0 = min(p0[0], p1[0]) - 12
    y0 = min(p0[1], p1[1]) - 12
    w = abs(p1[0] - p0[0]) + 25
    h = abs(p1[1] - p0[1]) + 25
    img = new(w, h)
    d = ImageDraw.Draw(img)

    def path(a, b, n, jit):
        pts = [a]
        for i in range(1, n):
            t = i / n
            pts.append((a[0] + (b[0] - a[0]) * t + rnd.uniform(-jit, jit), a[1] + (b[1] - a[1]) * t + rnd.uniform(-jit, jit)))
        pts.append(b)
        return [(round(x - x0), round(y - y0)) for x, y in pts]

    main = path(p0, p1, 9, 7)
    d.line(main, fill=lerp(WATER, CLEAR, 0.3), width=5)
    d.line(main, fill=ICE, width=3)
    d.line(main, fill=WHITE, width=1)
    if branch:
        for _ in range(3):
            i = rnd.randrange(2, len(main) - 2)
            a = (main[i][0] + x0, main[i][1] + y0)
            b = (a[0] + rnd.uniform(-20, 20), a[1] + rnd.uniform(6, 20))
            br = path(a, b, 4, 4)
            d.line(br, fill=ICE, width=1)
    return img, (x0, y0)


# =================================================================================
# Misc FX
# =================================================================================

def fx_sprites():
    save(glow(64, (150, 220, 255), rings=7, power=2.0, maxa=115), "glow_ice.png")
    save(glow(64, (255, 120, 60)), "glow_heat.png")
    save(glow(96, (220, 235, 255), rings=6, power=2.2, maxa=120), "glow_moon.png")
    s = new(3, 3)
    ImageDraw.Draw(s).point([(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)], fill=WHITE)
    save(s, "spark.png")
    r = new(1, 5)
    ImageDraw.Draw(r).line((0, 0, 0, 4), fill=ICE)
    r.putpixel((0, 0), lerp(ICE, CLEAR, 0.5))
    save(r, "raindrop.png")
    b = new(5, 5)
    ImageDraw.Draw(b).ellipse((0, 0, 4, 4), outline=STEAM)
    b.putpixel((1, 1), WHITE)
    save(b, "bubble.png")
    sm = new(7, 7)
    ImageDraw.Draw(sm).ellipse((0, 0, 6, 6), fill=lerp(STEAM, CLEAR, 0.3))
    save(sm, "steam_puff.png")
    # emote bubbles: ! ? note ... heart  (18x18)
    em = new(18 * 5, 18)
    for i in range(5):
        f = new(18, 18)
        d = ImageDraw.Draw(f)
        d.rounded_rectangle((1, 1, 16, 13), radius=4, fill=STEAM)
        d.polygon([(6, 13), (10, 13), (7, 16)], fill=STEAM)
        d.line((3, 12, 14, 12), fill=STEAM_D)
        if i == 0:
            d.rectangle((8, 3, 9, 8), fill=HEAT)
            d.rectangle((8, 10, 9, 11), fill=HEAT)
        elif i == 1:
            d.line((6, 4, 7, 3), fill=WATER)
            d.line((7, 3, 10, 3), fill=WATER)
            d.line((11, 4, 11, 5), fill=WATER)
            d.line((10, 6, 9, 7), fill=WATER)
            d.point((9, 8), fill=WATER)
            d.rectangle((9, 10, 9, 11), fill=WATER)
        elif i == 2:
            d.line((10, 3, 10, 9), fill=GREEN_D)
            d.line((10, 3, 12, 4), fill=GREEN_D)
            d.ellipse((7, 8, 10, 11), fill=GREEN_D)
        elif i == 3:
            for x in (5, 8, 11):
                d.rectangle((x, 8, x + 1, 9), fill=SLATE_L)
        else:
            d.polygon([(8, 11), (4, 7), (4, 5), (6, 3), (8, 5), (10, 3), (12, 5), (12, 7)], fill=HEAT)
            d.point((5, 5), fill=WHITE)
        em.alpha_composite(outline(f), (i * 18, 0))
    save(em, "emotes.png")
    # transformation poof: 4 frames 40x40
    pf = new(40 * 4, 40)
    for i in range(4):
        f = new(40, 40)
        d = ImageDraw.Draw(f)
        r = 6 + i * 5
        for k in range(8):
            a = k / 8 * math.tau + i * 0.2
            x, y = 20 + math.cos(a) * r, 20 + math.sin(a) * r
            rr = max(1, 4 - i)
            d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=STEAM if k % 2 else ICE)
        if i < 2:
            d.ellipse((20 - 5 + i * 2, 20 - 5 + i * 2, 20 + 5 - i * 2, 20 + 5 - i * 2), fill=WHITE)
        pf.alpha_composite(f, (i * 40, 0))
    save(pf, "poof.png")
    # alarm lamp: off / on (14x10)
    al = new(28, 12)
    for i in range(2):
        f = new(14, 12)
        d = ImageDraw.Draw(f)
        d.chord((1, 1, 12, 20), 180, 360, fill=HEAT if i else C("6E2A1E"))
        d.point((4, 4), fill=STEAM if i else C("A0503A"))
        d.rectangle((0, 9, 13, 11), fill=SLATE_L)
        al.alpha_composite(outline(f), (i * 14, 0))
    save(al, "alarm_lamp.png")
    # red alarm beam (additive)
    beam = new(160, 60)
    px = beam.load()
    for y in range(60):
        for x in range(160):
            v = 1 - abs(y - 30) / (6 + x * 0.17)
            if v > 0:
                band = math.ceil(v * (1 - x / 160) * 4) / 4
                px[x, y] = (255, 60, 30, int(110 * band))
    save(beam, "alarm_beam.png")


def door_panel():
    w, h = 54, 112
    img = new(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, w - 1, h - 1), fill=SLATE_M)
    for y in range(0, h, 14):
        d.line((0, y, w, y), fill=SLATE)
        d.line((0, y + 1, w, y + 1), fill=SLATE_L)
    d.rectangle((0, h - 10, w - 1, h - 1), fill=SLATE)
    for i in range(-10, w, 8):
        d.polygon([(i, h - 1), (i + 4, h - 9), (i + 8, h - 9), (i + 4, h - 1)], fill=AMBER)
    d.rectangle((14, 30, 40, 48), fill=NIGHT, outline=NAVY)
    d.line((16, 32, 22, 32), fill=ICE_D)
    text(img, (19, 56), "47", HEAT)
    return outline(img)


# =================================================================================
# Ending: night sky, rooftop, landscape, note
# =================================================================================

def moon(d, cx, cy, r):
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=C("DCE8F5"))
    d.chord((cx - r, cy - r, cx + r, cy + r), 120, 300, fill=C("C3D3E4"))
    d.ellipse((cx - r + 2, cy - r + 1, cx + r - 3, cy + r - 3), fill=C("E8F0F9"))
    for (ox, oy, rr) in ((-0.35, -0.2, 0.22), (0.25, 0.1, 0.3), (-0.05, 0.45, 0.15), (0.4, -0.45, 0.12)):
        x, y, q = cx + ox * r, cy + oy * r, rr * r
        d.ellipse((x - q, y - q, x + q, y + q), fill=C("B9CBDD"))
        d.arc((x - q, y - q, x + q, y + q), 200, 330, fill=C("9FB2C8"))
    d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=C("9FB2C8"))


def sky_tall():
    W, H = 480, 540
    img = new(W, H)
    dither_fill(img, (0, 0, W, H), [NIGHT, NAVY, C("12203F"), C("1B2E52"), C("2A4470")])
    stars(img, (0, 0, W, 470), 260)
    d = ImageDraw.Draw(img)
    moon(d, 372, 330, 22)
    return img


def cloud(w, h, seed, rain=False):
    rnd = random.Random(seed)
    img = new(w, h)
    d = ImageDraw.Draw(img)
    base = C("3B4F6E") if rain else C("4A5F80")
    mid = C("566E92") if rain else C("6A84A8")
    top = C("8EA6C6") if rain else C("A9C0DC")
    n = max(4, w // 16)
    puffs = []
    for i in range(n):
        cx = w * (0.16 + 0.68 * i / (n - 1))
        mid_bias = 1 - abs(i / (n - 1) - 0.5) * 1.2
        r = h * (0.2 + 0.2 * mid_bias + rnd.uniform(-0.03, 0.06)) * (0.82 if i % 2 else 1.0)
        cy = h * 0.66 - r * 0.55 - h * 0.12 * mid_bias + (h * 0.08 if i % 2 else 0)
        puffs.append((cx, cy, r))
    bottom = (w * 0.05, h * 0.5, w * 0.95, h - 1)
    for layer, col, dy in ((0, base, 0), (1, mid, -2), (2, top, -4)):
        for cx, cy, r in puffs:
            rr = r - layer * 2.5
            if rr > 1:
                ox = -layer * 1.5
                d.ellipse((cx - rr + ox, cy - rr + dy * 0.5, cx + rr + ox, cy + rr * 0.8 + dy), fill=col)
        if layer == 0:
            d.rounded_rectangle(bottom, radius=int(h * 0.22), fill=base)
    # re-darken the underside so the layers read as a lit top
    d.rounded_rectangle((w * 0.07, h * 0.72, w * 0.93, h - 1), radius=int(h * 0.12), fill=base)
    d.line((w * 0.12, h - 3, w * 0.88, h - 3), fill=lerp(base, NAVY, 0.35))
    for cx, cy, r in puffs[1:-1]:
        d.point((cx - r * 0.4, cy - r * 0.55), fill=C("D6E4F2"))
    return outline(img)


def rooftop():
    W, H = 480, 270
    img = new(W, H)
    d = ImageDraw.Draw(img)
    # far hills + trees
    pts = [(0, 150)]
    for x in range(0, W + 20, 20):
        pts.append((x, 140 + 14 * math.sin(x * 0.018) + 6 * math.sin(x * 0.07)))
    pts += [(W, H), (0, H)]
    d.polygon(pts, fill=C("13213B"))
    for x in range(0, W, 7):
        base = 146 + 14 * math.sin(x * 0.018) + 6 * math.sin(x * 0.07)
        th = 6 + (x * 13) % 9
        d.polygon([(x - 3, base + 4), (x, base - th), (x + 3, base + 4)], fill=C("0F1A30"))
    # lake strip
    d.rectangle((0, 168, W, 200), fill=C("12223F"))
    for _ in range(40):
        x, y = random.randrange(300, 440), random.randrange(170, 198)
        d.line((x, y, x + random.randrange(2, 6), y), fill=C("6F87A8"))
    # roof parapet
    d.rectangle((0, 196, W, H), fill=C("1A2638"))
    d.rectangle((0, 196, W, 203), fill=SLATE)
    d.line((0, 196, W, 196), fill=STEEL)
    d.line((0, 197, W, 197), fill=SLATE_L)
    for x in range(0, W, 24):
        d.line((x, 198, x, 203), fill=C("1A2638"))
    d.rectangle((0, 204, W, H), fill=C("162133"))
    for y in range(212, H, 10):
        d.line((0, y, W, y), fill=C("131C2C"))
    dither_blend(img, (0, 204, W, H), NAVY, lambda x, y: (y - 204) / 80)
    # railing
    d.line((0, 178, W, 178), fill=SLATE_L)
    for x in range(10, W, 30):
        d.line((x, 178, x, 196), fill=SLATE_L)
    d.line((0, 179, W, 179), fill=NAVY)
    # AC unit
    d.rectangle((330, 170, 384, 198), fill=SLATE_M, outline=NAVY)
    d.line((331, 171, 383, 171), fill=STEEL)
    d.ellipse((340, 175, 360, 195), fill=SLATE, outline=NAVY)
    for a in range(0, 360, 60):
        d.line((350, 185, 350 + round(math.cos(math.radians(a)) * 8), 185 + round(math.sin(math.radians(a)) * 8)), fill=SLATE_L)
    # antenna
    d.line((430, 120, 430, 196), fill=SLATE_L)
    d.line((424, 132, 436, 132), fill=SLATE_L)
    d.line((426, 144, 434, 144), fill=SLATE_L)
    d.point((430, 119), fill=HEAT)
    # flue pipe (ch. 11)
    px0, px1 = 108, 140
    d.rectangle((px0, 110, px1, 198), fill=STEEL)
    d.rectangle((px0, 110, px0 + 4, 198), fill=STEEL_L)
    d.rectangle((px1 - 7, 110, px1, 198), fill=SLATE_L)
    d.line((px0 + 6, 110, px0 + 6, 198), fill=WHITE)
    for y in (130, 168):
        d.rectangle((px0 - 3, y, px1 + 3, y + 5), fill=STEEL_L, outline=NAVY)
        for rx in range(px0, px1 + 1, 6):
            d.point((rx, y + 2), fill=SLATE)
    d.rectangle((px0 - 4, 104, px1 + 4, 112), fill=STEEL_L, outline=NAVY)
    d.ellipse((px0 - 2, 102, px1 + 2, 110), fill=NIGHT, outline=NAVY)
    d.rectangle((px0, 110, px1, 198), outline=NAVY)
    d.line((px0 - 4, 112, px1 + 4, 112), fill=NAVY)
    # moonlight rim on parapet
    for _ in range(20):
        d.point((random.randrange(W), 204 + random.randrange(4)), fill=SLATE_M)
    return img


def landscape():
    W, H = 480, 270
    img = new(W, H)
    dither_fill(img, (0, 0, W, 190), [NIGHT, NAVY, C("1B2E52"), C("2A4470")])
    stars(img, (0, 0, W, 150), 140)
    d = ImageDraw.Draw(img)
    moon(d, 404, 46, 18)
    # hills
    for (yb, amp, col, ph) in ((150, 20, C("1A2B4A"), 0.0), (168, 14, C("13213B"), 1.7)):
        pts = [(0, H)]
        for x in range(0, W + 10, 10):
            pts.append((x, yb - amp * (0.5 + 0.5 * math.sin(x * 0.013 + ph)) - 5 * math.sin(x * 0.05)))
        pts.append((W, H))
        d.polygon(pts, fill=col)
    for x in range(140, W, 6):
        b = 168 - 14 * (0.5 + 0.5 * math.sin(x * 0.013 + 1.7)) - 5 * math.sin(x * 0.05)
        d.polygon([(x - 3, b + 3), (x, b - 6 - (x * 7) % 6), (x + 3, b + 3)], fill=C("0E182C"))
    # lake
    dither_fill(img, (0, 182, W, H), [C("1E3256"), C("12223F"), NAVY])
    d = ImageDraw.Draw(img)
    for y in range(186, H, 3):
        n = int(8 - (y - 186) / 14)
        for _ in range(max(1, n)):
            x = 404 + random.randint(-10 - (y - 186) // 4, 10 + (y - 186) // 4)
            d.line((x, y, x + random.randrange(2, 7), y), fill=C("B9CBDD") if random.random() < 0.5 else C("6F87A8"))
    # lab building on the left with its pipe
    d.rectangle((24, 96, 112, 186), fill=C("1D2A40"), outline=NAVY)
    d.rectangle((18, 90, 118, 96), fill=SLATE, outline=NAVY)
    for wy in range(104, 180, 16):
        for wx in range(32, 104, 18):
            lit = (wx * 3 + wy) % 5 == 0
            d.rectangle((wx, wy, wx + 9, wy + 8), fill=AMBER if lit else C("2B3F5A"), outline=NAVY)
    d.rectangle((60, 60, 70, 90), fill=SLATE_L, outline=NAVY)
    d.rectangle((58, 56, 72, 60), fill=STEEL, outline=NAVY)
    d.rectangle((112, 150, 150, 156), fill=STEEL, outline=NAVY)
    d.line((113, 151, 149, 151), fill=STEEL_L)
    # shoreline
    d.line((0, 182, W, 182), fill=C("2B4470"))
    return img


def big_cloud():
    img = cloud(150, 64, 11, rain=True)
    save(img, "cloud_big.png")
    for i, (w, h, s) in enumerate(((96, 34, 3), (120, 40, 5), (70, 26, 8), (110, 36, 9))):
        save(cloud(w, h, s, rain=(i % 2 == 1)), "cloud_%d.png" % (i + 1))


def note_close():
    W, H = 480, 270
    img = new(W, H, C("23344A"))
    d = ImageDraw.Draw(img)
    # counter (top-down-ish)
    dither_fill(img, (0, 0, W, H), [C("2E4258"), SLATE, C("223144")])
    d = ImageDraw.Draw(img)
    for y in range(0, H, 34):
        d.line((0, y, W, y + 6), fill=C("26374B"))
    # window light shapes on the counter (rainy morning)
    for k in range(2):
        x0 = 300 + k * 70
        d.polygon([(x0, 0), (x0 + 50, 0), (x0 + 10, H), (x0 - 40, H)], fill=C("34495F"))
    # clipboard
    d.rounded_rectangle((70, 24, 300, 262), radius=6, fill=WOOD, outline=NAVY)
    d.line((76, 26, 294, 26), fill=C("8C654F"))
    d.rectangle((82, 40, 288, 256), fill=PAPER, outline=NAVY)
    d.line((84, 254, 286, 254), fill=PAPER_D)
    d.line((286, 42, 286, 254), fill=PAPER_D)
    for y in range(76, 250, 14):
        d.line((96, y, 278, y), fill=C("C6D6EA"))
    d.line((94, 42, 94, 252), fill=C("F2B8B8"))
    d.rectangle((150, 16, 220, 34), fill=STEEL, outline=NAVY)
    d.line((152, 18, 218, 18), fill=STEEL_L)
    d.rectangle((170, 26, 200, 30), fill=SLATE)
    # pencil
    d.line((300, 230, 360, 200), fill=AMBER, width=4)
    d.line((300, 230, 293, 234), fill=SKIN_D, width=3)
    d.line((360, 200, 366, 197), fill=MUG, width=4)
    return img


def smiley():
    img = new(22, 22)
    d = ImageDraw.Draw(img)
    # a little water-drop doodle in ink
    d.polygon([(11, 1), (4, 12), (18, 12)], outline=INK)
    d.arc((3, 6, 19, 21), 0, 180, fill=INK)
    d.line((4, 12, 3, 14), fill=INK)
    d.line((18, 12, 19, 14), fill=INK)
    d.point([(8, 13), (14, 13)], fill=INK)
    d.arc((8, 13, 14, 18), 20, 160, fill=INK)
    save(img, "doodle.png")


def trail():
    """Wet trail from the bench edge down to the floor drain (morning scene)."""
    img = new(480, 270)
    d = ImageDraw.Draw(img)
    # drips running down the bench front
    for (x, y0, y1) in ((208, 191, 204), (212, 191, 199), (209, 210, 222)):
        d.line((x, y0, x, y1), fill=WATER_L)
        d.ellipse((x - 1, y1 - 1, x + 1, y1 + 2), fill=WATER)
    # puddle dots across the floor to the drain
    for i, (x, y, r) in enumerate(((210, 233, 3), (215, 236, 2), (221, 238, 3), (228, 240, 2), (233, 241, 2))):
        d.ellipse((x - r - 1, y - r * 0.5, x + r + 1, y + r * 0.5 + 1), fill=WATER)
        d.line((x - r, y - 1, x, y - 1), fill=WATER_L)
    img = outline(img, lerp(NAVY, CLEAR, 0.2))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    save(lab_bg(False), "lab_night.png")
    random.seed(48)
    save(lab_bg(True), "lab_day.png")
    lamp_sprites()
    save(bench(), "bench.png")
    reg = new(92, 56)
    reg.alpha_composite(regulator(False), (0, 0))
    reg.alpha_composite(regulator(True), (46, 0))
    save(reg, "regulator.png")
    scientist_sheet()
    blob_sheet(48, 40, "blob_big.png")
    blob_sheet(24, 20, "blob_small.png")
    print("eyes_big frame", eyes_sheet(8, 10, 5, "eyes_big.png"))
    print("eyes_small frame", eyes_sheet(4, 5, 3, "eyes_small.png"))
    flask_layers()
    random.seed(49)
    save(bench_close(), "bench_close.png")
    coffee_mug_big()
    cm = new(144, 130)
    cm.alpha_composite(coil_machine(False), (0, 0))
    cm.alpha_composite(coil_machine(True), (72, 0))
    save(cm, "coil_machine.png")
    hand_vial()
    # bolts: close-up (coil top -> flask neck), wide (regulator coil -> small flask)
    for name, p0, p1 in (("bolt_close", (440, 96), (282, 118)), ("bolt_wide", (292, 140), (210, 170))):
        frames = []
        for s in range(3):
            b, org = bolt(p0, p1, s * 17 + len(name))
            frames.append(b)
        w, h = frames[0].size
        sheet = new(w * 3, h)
        for i, f in enumerate(frames):
            sheet.alpha_composite(f, (i * w, 0))
        save(sheet, name + ".png")
        print(name, "origin", org, "frame", (w, h))
    fx_sprites()
    save(door_panel(), "door_panel.png")
    # small flask on the bench (wide): frames calm / glow / empty
    sf = new(36, 20)
    for i, col in enumerate((WATER, C("A8F0FF"), lerp(ICE, CLEAR, 0.7))):
        sf.alpha_composite(small_flask(col, 12, 20), (i * 12, 0))
    save(sf, "flask_small.png")
    random.seed(50)
    save(sky_tall(), "sky_tall.png")
    random.seed(51)
    save(rooftop(), "rooftop.png")
    random.seed(52)
    save(landscape(), "landscape.png")
    big_cloud()
    random.seed(53)
    save(note_close(), "note_close.png")
    smiley()
    save(trail(), "trail.png")


if __name__ == "__main__":
    main()
