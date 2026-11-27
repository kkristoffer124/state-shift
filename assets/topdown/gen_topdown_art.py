"""Generates the pixel art for the top-down chapters (assets/topdown/).
   python -I assets/topdown/gen_topdown_art.py
Floors (4 variants of 32x32 per theme), south wall faces, spikes, drain, plate,
blob shadow, steam puffs and a vignette. Deterministic (fixed seeds)."""
import os, random
from PIL import Image

OUT = os.path.dirname(os.path.abspath(__file__))


def save(img, name):
    img.save(os.path.join(OUT, name))


def clamp(c):
    return tuple(max(0, min(255, int(v))) for v in c)


def shade(c, f):
    out = [c[0] * f, c[1] * f, c[2] * f]
    if len(c) > 3:
        out.append(c[3])
    return clamp(out)


def mix(a, b, t):
    return clamp(tuple(a[i] + (b[i] - a[i]) * t for i in range(len(a))))


# ---------------------------------------------------------------- floors
def floor_lab():
    rng = random.Random(7)
    img = Image.new("RGBA", (128, 32))
    base = (84, 100, 122, 255)
    grout = (46, 56, 72, 255)
    hi = (106, 124, 148, 255)
    for v in range(4):
        ox = v * 32
        for y in range(32):
            for x in range(32):
                c = base
                n = rng.random()
                if n < 0.10:
                    c = shade(base, 0.93)
                elif n > 0.95:
                    c = shade(base, 1.06)
                img.putpixel((ox + x, y), c)
        for i in range(32):
            img.putpixel((ox + 31, i), grout)
            img.putpixel((ox + i, 31), grout)
            img.putpixel((ox + i, 0), hi)
            img.putpixel((ox, i), hi)
        img.putpixel((ox, 31), grout)
        img.putpixel((ox + 31, 0), grout)
        for (bx, by) in [(3, 3), (27, 3), (3, 27), (27, 27)]:
            img.putpixel((ox + bx, by), (128, 146, 170, 255))
            img.putpixel((ox + bx + 1, by + 1), (52, 62, 78, 255))
        if v == 1:  # diamond plate
            for y in range(6, 26, 4):
                for x in range(6, 26, 4):
                    dx = 2 if (y // 4) % 2 else 0
                    px, py = ox + x + dx, y
                    if px < ox + 27:
                        img.putpixel((px, py), (86, 104, 128, 255))
                        img.putpixel((px + 1, py + 1), (44, 54, 69, 255))
        if v == 2:  # vent slots
            for y in (11, 15, 19):
                for x in range(9, 23):
                    img.putpixel((ox + x, y), (24, 30, 40, 255))
                    img.putpixel((ox + x, y + 1), (70, 86, 108, 255))
        if v == 3:  # scuffs
            for i in range(26):
                x = int(16 + rng.gauss(0, 5))
                y = int(16 + rng.gauss(0, 4))
                if 2 < x < 29 and 2 < y < 29:
                    img.putpixel((ox + x, y), shade(base, 0.85))
            for x in range(8, 20):
                img.putpixel((ox + x, 9 + (x % 3 == 0)), (52, 64, 82, 255))
    save(img, "td_floor_lab.png")


def floor_sewer():
    rng = random.Random(11)
    img = Image.new("RGBA", (128, 32))
    base = (76, 90, 82, 255)
    grout = (36, 46, 42, 255)
    hi = (96, 112, 102, 255)
    moss = [(52, 96, 74, 255), (64, 118, 86, 255), (44, 80, 64, 255)]
    for v in range(4):
        ox = v * 32
        for y in range(32):
            for x in range(32):
                n = rng.random()
                c = base
                if n < 0.14:
                    c = shade(base, 0.9)
                elif n > 0.94:
                    c = shade(base, 1.1)
                img.putpixel((ox + x, y), c)
        for y in (0, 16):
            for x in range(32):
                img.putpixel((ox + x, y), grout)
                img.putpixel((ox + x, y + 1), hi)
        for (x, y0) in [(0, 0), (16, 16)]:
            for y in range(y0, y0 + 16):
                img.putpixel((ox + x, y), grout)
                if x + 1 < 32:
                    img.putpixel((ox + x + 1, y), hi)
        if v in (1, 3):  # moss creeping along the grout
            for i in range(30 if v == 1 else 55):
                x = rng.randint(0, 31)
                y = rng.choice([0, 1, 2, 15, 16, 17]) if rng.random() < 0.7 else rng.randint(0, 31)
                img.putpixel((ox + x, y), rng.choice(moss))
        if v == 2:  # wet glints
            for i in range(10):
                x, y = rng.randint(3, 28), rng.randint(3, 28)
                img.putpixel((ox + x, y), (96, 132, 124, 255))
                img.putpixel((ox + x + 1, y), (80, 112, 104, 255))
        if v == 3:
            for i in range(12):
                x, y = rng.randint(4, 27), rng.randint(4, 27)
                img.putpixel((ox + x, y), (40, 52, 46, 255))
    save(img, "td_floor_sewer.png")


# ---------------------------------------------------------------- wall faces (south side, 32x12)
def face(name, base, line, hi, accent=None):
    rng = random.Random(len(name))
    img = Image.new("RGBA", (32, 12))
    for y in range(12):
        t = y / 11.0
        for x in range(32):
            c = mix(base, shade(base, 0.62), t)
            if rng.random() < 0.08:
                c = shade(c, 0.9)
            img.putpixel((x, y), c)
    for x in range(32):
        img.putpixel((x, 0), hi)
        img.putpixel((x, 11), (12, 16, 20, 255))
    for x in (0, 16):
        for y in range(1, 11):
            img.putpixel((x, y), line)
    if accent:
        accent(img, rng)
    save(img, name)


def lab_accent(img, rng):
    for x in (4, 20):
        img.putpixel((x, 4), (110, 130, 155, 255))
        img.putpixel((x + 1, 4), (40, 50, 62, 255))
    for x in range(8, 13):
        img.putpixel((x, 6), (22, 28, 36, 255))


def sewer_accent(img, rng):
    for y in (4, 8):
        for x in range(32):
            img.putpixel((x, y), shade(img.getpixel((x, y)), 0.8))
    for i in range(6):  # moss drips
        x = rng.randint(1, 30)
        for y in range(1, rng.randint(2, 6)):
            img.putpixel((x, y), (56, 104, 78, 255))


# ---------------------------------------------------------------- props
def spikes():
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    plate = (52, 60, 72, 255)
    for y in range(32):
        for x in range(32):
            img.putpixel((x, y), plate if (x + y) % 7 else shade(plate, 0.9))
    for i in range(32):
        img.putpixel((i, 0), (80, 92, 108, 255))
        img.putpixel((0, i), (80, 92, 108, 255))
        img.putpixel((i, 31), (24, 28, 34, 255))
        img.putpixel((31, i), (24, 28, 34, 255))
    for cy in (7, 16, 25):
        for cx in (6, 16, 26):
            for x in range(-3, 4):
                img.putpixel((cx + x, cy + 4), (20, 24, 30, 255))
            for y in range(-4, 4):
                w = (y + 5) // 2
                for x in range(-w, w + 1):
                    c = (176, 190, 205, 255) if x < 0 else (120, 134, 150, 255)
                    if y == -4:
                        c = (236, 244, 250, 255)
                    img.putpixel((cx + x, cy + y), c)
    save(img, "td_spikes.png")


def drain():
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    cx, cy = 15.5, 15.5
    for y in range(32):
        for x in range(32):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= 14.5:
                if d > 12.5:
                    c = (126, 140, 150, 255) if y < cy else (70, 80, 88, 255)
                elif d > 11.5:
                    c = (34, 40, 46, 255)
                else:
                    c = (10, 14, 18, 255)
                    if (x + y) % 5 in (0, 1):
                        c = (92, 104, 114, 255) if (x + y) % 5 == 0 else (54, 62, 70, 255)
                img.putpixel((x, y), c)
    save(img, "td_drain.png")


def plate():
    img = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    for f in range(2):
        ox = f * 32
        for y in range(2, 30):
            for x in range(2, 30):
                img.putpixel((ox + x, y), (40, 48, 58, 255))
        for i in range(2, 30):
            img.putpixel((ox + i, 2), (96, 110, 126, 255))
            img.putpixel((ox + 2, i), (96, 110, 126, 255))
            img.putpixel((ox + i, 29), (18, 22, 28, 255))
            img.putpixel((ox + 29, i), (18, 22, 28, 255))
        sink = 2 if f else 0
        pad = (120, 196, 232, 255) if f == 0 else (96, 230, 150, 255)
        pad_hi = (184, 236, 255, 255) if f == 0 else (170, 255, 200, 255)
        pad_lo = (60, 110, 140, 255) if f == 0 else (40, 130, 80, 255)
        top = 6 + sink
        for y in range(top, 25):
            for x in range(6, 26):
                img.putpixel((ox + x, y), pad)
        for x in range(6, 26):
            img.putpixel((ox + x, top), pad_hi)
        for y in range(top, 25):
            img.putpixel((ox + 6, y), pad_hi)
        if not f:
            for x in range(6, 26):
                for y in (25, 26):
                    img.putpixel((ox + x, y), pad_lo)
        gx, gy = ox + 16, 15 + sink
        ink = (30, 60, 80, 255) if f == 0 else (20, 80, 50, 255)
        for d in range(-4, 5):
            img.putpixel((gx + d, gy), ink)
            img.putpixel((gx, gy + d), ink)
            if abs(d) <= 3:
                img.putpixel((gx + d, gy + d), ink)
                img.putpixel((gx + d, gy - d), ink)
    save(img, "td_plate.png")


def shadow():
    img = Image.new("RGBA", (32, 14), (0, 0, 0, 0))
    for y in range(14):
        for x in range(32):
            d = ((x - 15.5) / 15.5) ** 2 + ((y - 6.5) / 6.5) ** 2
            if d < 1.0:
                a = 120 if d < 0.55 else 70
                img.putpixel((x, y), (0, 0, 8, a))
    save(img, "td_shadow.png")


def puff(r, name):
    s = r * 2 + 2
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    c0 = (r + 0.5, r + 0.5)
    for y in range(s):
        for x in range(s):
            d = ((x - c0[0]) ** 2 + (y - c0[1]) ** 2) ** 0.5
            if d <= r:
                t = (y - (c0[1] - r)) / (2 * r)
                if t > 0.72:
                    c = (197, 211, 230, 235)
                    if (x + y) % 2 and t < 0.8:
                        c = (232, 240, 250, 240)
                elif t < 0.3 and x < c0[0]:
                    c = (255, 255, 255, 245)
                else:
                    c = (240, 246, 255, 240)
                if d > r - 1:
                    c = c[:3] + (150,)
                img.putpixel((x, y), c)
    save(img, name)


def vignette():
    w, h = 96, 54
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            dx = (x - w / 2 + 0.5) / (w / 2)
            dy = (y - h / 2 + 0.5) / (h / 2)
            d = (dx * dx * 0.8 + dy * dy) ** 0.5
            a = max(0.0, min(1.0, (d - 0.55) / 0.6))
            img.putpixel((x, y), (4, 6, 12, int(170 * a * a)))
    save(img, "td_vignette.png")


if __name__ == "__main__":
    floor_lab()
    floor_sewer()
    face("td_face_lab.png", (40, 52, 68, 255), (26, 34, 45, 255), (110, 132, 158, 255), lab_accent)
    face("td_face_sewer.png", (46, 58, 54, 255), (28, 36, 33, 255), (98, 124, 112, 255), sewer_accent)
    spikes()
    drain()
    plate()
    shadow()
    puff(11, "td_puff_l.png")
    puff(8, "td_puff_m.png")
    puff(5, "td_puff_s.png")
    vignette()
    print("ok")
