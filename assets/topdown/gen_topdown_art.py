"""Generates the pixel art for the top-down chapters (assets/topdown/).
   python -I assets/topdown/gen_topdown_art.py
Only the pieces the hand-made art (assets/topdown/tex, assets/topdown/anim) doesn't
cover: floor spikes, steam puffs (wisps / puff rings / cold mist) and the vignette.
Deterministic (fixed seeds)."""
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
    spikes()
    puff(11, "td_puff_l.png")
    puff(8, "td_puff_m.png")
    puff(5, "td_puff_s.png")
    vignette()
    print("ok")
