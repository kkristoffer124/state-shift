"""Generates the tiling parallax backdrops (python -I tools/art/gen_backdrops.py).
Four wings x (far, mid) strips + shared ceiling bands. All horizontally seamless.
far : scroll 0.25, silhouettes only slightly off the background gradient (fog)
mid : scroll 0.5, darker machinery with a few small lights
"""
import os, sys, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pix import *  # noqa

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUTDIR = os.path.join(ROOT, "assets", "deco", "backdrops")
os.makedirs(OUTDIR, exist_ok=True)

W = 1024
FAR_H = 640
MID_H = 512

WINGS = {
    # base, rim, shadow, lit window, accent
    "lab": dict(base=(17, 28, 46), rim=(25, 40, 60), sh=(12, 21, 36), lit=(38, 74, 92), acc=(70, 150, 170)),
    "storage": dict(base=(19, 27, 42), rim=(29, 39, 56), sh=(13, 20, 33), lit=(64, 60, 44), acc=(150, 120, 60)),
    "plant": dict(base=(15, 30, 42), rim=(23, 44, 56), sh=(10, 22, 32), lit=(36, 78, 70), acc=(70, 160, 120)),
    "reactor": dict(base=(22, 22, 38), rim=(34, 30, 48), sh=(15, 15, 28), lit=(84, 46, 34), acc=(220, 90, 40)),
}


def c4(c, a=255):
    return (c[0], c[1], c[2], a)


def darker(c, k):
    return tuple(max(0, int(v * k)) for v in c)


# ------------------------------------------------------------ far elements
def far_tank(wr, x, base, w, h, P, rnd):
    def draw(im, xx):
        top = base - h
        for i in range(w):
            t = i / (w - 1)
            col = P["rim"] if t < 0.22 else (P["base"] if t < 0.7 else P["sh"])
            vline(im, xx + i, top + 8, h - 8, c4(col))
        for y in range(8):  # dome
            hw = int(w / 2 * math.sqrt(1 - ((8 - y) / 8.0) ** 2))
            rect(im, xx + w // 2 - hw, top + y, hw * 2, 1, c4(P["base"]))
        for ry in range(top + 20, base - 6, rnd_ring):
            hline(im, xx, ry, w, c4(P["sh"]))
        # portholes
        for k in range(nports):
            py = top + 30 + k * 34
            if py < base - 20:
                rect(im, xx + w // 2 - 3, py, 6, 6, c4(P["sh"]))
                if lit_ports[k]:
                    rect(im, xx + w // 2 - 2, py + 1, 4, 4, c4(P["lit"]))
    rnd_ring = rnd.choice([28, 36, 44])
    nports = rnd.randrange(1, 5)
    lit_ports = [rnd.random() < 0.5 for _ in range(nports)]
    wr.call(draw, x)


def far_tower(wr, x, base, w, h, P, rnd):
    wins = []
    for wy in range(base - h + 10, base - 12, 12):
        for wx in range(6, w - 8, 10):
            wins.append((wx, wy, rnd.random() < 0.16, rnd.random() < 0.05))

    def draw(im, xx):
        rect(im, xx, base - h, w, h, c4(P["base"]))
        vline(im, xx, base - h, h, c4(P["rim"]))
        hline(im, xx, base - h, w, c4(P["rim"]))
        for wx, wy, lit, acc in wins:
            col = P["acc"] if acc else (P["lit"] if lit else P["sh"])
            if acc:
                col = mix(P["lit"], P["acc"], 0.35)
            rect(im, xx + wx, wy, 5, 6, c4(col))
    wr.call(draw, x)


def far_catwalk(wr, y, P, rnd):
    def draw(im, xx):
        rect(im, xx, y, W, 3, c4(P["sh"]))
        hline(im, xx, y - 8, W, c4(P["sh"]))
        for k in range(0, W, 24):
            vline(im, xx + k, y - 8, 8, c4(P["sh"]))
        for k in range(40, W, 160):
            line(im, xx + k, y + 3, xx + k + 20, y + 26, c4(P["sh"]))
    wr.call(draw, 0)


def far_pipe_h(wr, y, th, P):
    def draw(im, xx):
        rect(im, xx, y, W, th, c4(P["base"]))
        hline(im, xx, y, W, c4(P["rim"]))
        hline(im, xx, y + th - 1, W, c4(P["sh"]))
        for k in range(0, W, 64):
            rect(im, xx + k, y - 1, 3, th + 2, c4(P["sh"]))
    wr.call(draw, 0)


def far_pipe_v(wr, x, top, base, w, P):
    def draw(im, xx):
        rect(im, xx, top, w, base - top, c4(P["base"]))
        vline(im, xx, top, base - top, c4(P["rim"]))
        vline(im, xx + w - 1, top, base - top, c4(P["sh"]))
        for k in range(top, base, 48):
            rect(im, xx - 1, k, w + 2, 3, c4(P["sh"]))
    wr.call(draw, x)


def far_coil(wr, x, base, h, P, rnd):
    w = 40

    def draw(im, xx):
        rect(im, xx + 14, base - h, 12, h, c4(P["base"]))
        vline(im, xx + 14, base - h, h, c4(P["rim"]))
        for k in range(base - h + 10, base - 20, 14):
            rect(im, xx, k, w, 8, c4(P["base"]))
            hline(im, xx, k, w, c4(P["rim"]))
            hline(im, xx + 2, k + 4, w - 4, c4(mix(P["lit"], P["acc"], 0.25)))
            hline(im, xx, k + 7, w, c4(P["sh"]))
    wr.call(draw, x)


def far_rack(wr, x, base, w, h, P, rnd):
    boxes = []
    for sy in range(base - h + 16, base, 28):
        bx = 3
        while bx < w - 10:
            bw = rnd.randrange(8, 20)
            bh = rnd.randrange(8, 22)
            if rnd.random() < 0.75:
                boxes.append((bx, sy, bw, bh, rnd.random() < 0.08))
            bx += bw + 2

    def draw(im, xx):
        rect(im, xx, base - h, 3, h, c4(P["base"]))
        rect(im, xx + w - 3, base - h, 3, h, c4(P["base"]))
        for sy in range(base - h + 16, base, 28):
            rect(im, xx, sy, w, 2, c4(P["base"]))
        for bx, sy, bw, bh, lit in boxes:
            rect(im, xx + bx, sy - bh, bw, bh, c4(P["sh"]))
            hline(im, xx + bx, sy - bh, bw, c4(P["rim"]))
            if lit:
                px(im, xx + bx + 2, sy - bh + 3, c4(P["lit"]))
    wr.call(draw, x)


def far_fan(wr, x, cy, r, P):
    def draw(im, xx):
        cx = xx + r
        for y in range(-r, r + 1):
            for xo in range(-r, r + 1):
                d = math.hypot(xo, y)
                if d <= r:
                    col = P["base"] if d > r - 4 else P["sh"]
                    a = math.atan2(y, xo)
                    if d < r - 5 and (math.sin(a * 3 + d * 0.06) > 0.55):
                        col = P["rim"]
                    px(im, cx + xo, cy + y, c4(col))
        rect(im, cx - 3, cy - 3, 6, 6, c4(P["rim"]))
    wr.call(draw, x)


def far_chimney(wr, x, base, w, h, P):
    def draw(im, xx):
        rect(im, xx, base - h, w, h, c4(P["base"]))
        vline(im, xx, base - h, h, c4(P["rim"]))
        for k in range(base - h + 6, base, 40):
            hline(im, xx, k, w, c4(P["sh"]))
        rect(im, xx - 2, base - h, w + 4, 5, c4(P["rim"]))
        # warning light on top
        px(im, xx + w // 2, base - h - 2, c4(P["acc"]))
    wr.call(draw, x)


def ground(wr, top, h, P):
    def draw(im, xx):
        for y in range(h):
            t = y / max(h - 1, 1)
            col = mix(P["sh"], darker(P["sh"], 0.7), t)
            hline(im, xx, top + y, W, c4(col))
        hline(im, xx, top, W, c4(P["rim"]))
    wr.call(draw, 0)


def far(wing, seed):
    P = WINGS[wing]
    rnd = random.Random(seed)
    wr = Wrap(W, FAR_H)
    base = FAR_H - 40
    # back row: catwalk band + horizontal pipes high up
    far_catwalk(wr, 150 + rnd.randrange(40), P, rnd)
    if wing in ("plant", "reactor", "lab"):
        far_pipe_h(wr, 90 + rnd.randrange(30), 8, P)
    x = 0
    while x < W:
        kind = rnd.random()
        if wing == "lab":
            if kind < 0.45:
                w = rnd.randrange(56, 110); far_tank(wr, x, base, w, rnd.randrange(220, 420), P, rnd)
            else:
                w = rnd.randrange(90, 170); far_tower(wr, x, base, w, rnd.randrange(160, 360), P, rnd)
        elif wing == "storage":
            if kind < 0.55:
                w = rnd.randrange(80, 140); far_rack(wr, x, base, w, rnd.randrange(200, 400), P, rnd)
            elif kind < 0.75:
                w = 2 * 70; far_fan(wr, x, base - 260 - rnd.randrange(80), 70, P)
            else:
                w = rnd.randrange(90, 150); far_tower(wr, x, base, w, rnd.randrange(160, 300), P, rnd)
        elif wing == "plant":
            if kind < 0.45:
                w = rnd.randrange(70, 130); far_tank(wr, x, base, w, rnd.randrange(200, 360), P, rnd)
            elif kind < 0.8:
                w = 0
                for k in range(rnd.randrange(3, 7)):
                    pw = rnd.randrange(8, 20)
                    far_pipe_v(wr, x + w, rnd.randrange(0, 200), base, pw, P)
                    w += pw + rnd.randrange(3, 10)
            else:
                w = rnd.randrange(26, 40); far_chimney(wr, x, base, w, rnd.randrange(380, 520), P)
        else:  # reactor
            if kind < 0.4:
                w = 40; far_coil(wr, x, base, rnd.randrange(240, 420), P, rnd)
            elif kind < 0.65:
                w = rnd.randrange(30, 44); far_chimney(wr, x, base, w, rnd.randrange(360, 560), P)
            else:
                w = rnd.randrange(90, 160); far_tower(wr, x, base, w, rnd.randrange(140, 300), P, rnd)
        x += w + rnd.randrange(14, 60)
    ground(wr, base, FAR_H - base, P)
    im = wr.result()
    # fade the very top so tall levels blend into the gradient
    return im


# ------------------------------------------------------------ mid elements
MIDP = dict(base=(11, 17, 29), rim=(22, 32, 48), sh=(7, 11, 20))


def mid_machine(wr, x, base, w, h, P, rnd):
    lights = [(rnd.randrange(4, w - 6), rnd.randrange(6, h - 6), rnd.choice([P["acc"], (70, 200, 120), (220, 70, 50), (90, 170, 230)]))
              for _ in range(rnd.randrange(1, 4))]
    panel = rnd.random() < 0.5
    stack = rnd.random() < 0.5
    sh = rnd.randrange(20, 60)

    def draw(im, xx):
        rect(im, xx, base - h, w, h, c4(MIDP["base"]))
        hline(im, xx, base - h, w, c4(MIDP["rim"]))
        vline(im, xx, base - h, h, c4(MIDP["rim"]))
        if panel:
            rect(im, xx + 4, base - h + 6, w - 8, min(16, h - 10), c4(MIDP["sh"]))
            for k in range(0, w - 12, 4):
                px(im, xx + 6 + k, base - h + 10, c4(mix(MIDP["rim"], P["acc"], 0.25)))
        if stack:
            rect(im, xx + w // 3, base - h - sh, 8, sh, c4(MIDP["base"]))
            vline(im, xx + w // 3, base - h - sh, sh, c4(MIDP["rim"]))
            rect(im, xx + w // 3 - 2, base - h - sh, 12, 3, c4(MIDP["rim"]))
        for lx, ly, col in lights:
            px(im, xx + lx, base - h + ly, c4(col))
            px(im, xx + lx + 1, base - h + ly, c4(darker(col, 0.5)))
    wr.call(draw, x)


def mid_shelf(wr, x, base, w, h, P, rnd):
    items = []
    for sy in range(base - h + 22, base, 24):
        bx = 4
        while bx < w - 8:
            fw = rnd.randrange(4, 9)
            fh = rnd.randrange(6, 16)
            if rnd.random() < 0.7:
                glint = rnd.random() < 0.25
                col = rnd.choice([P["acc"], (80, 170, 120), (170, 80, 60), (90, 130, 200)])
                items.append((bx, sy, fw, fh, glint, col))
            bx += fw + rnd.randrange(1, 4)

    def draw(im, xx):
        rect(im, xx, base - h, 3, h, c4(MIDP["base"]))
        rect(im, xx + w - 3, base - h, 3, h, c4(MIDP["base"]))
        for sy in range(base - h + 22, base, 24):
            rect(im, xx, sy, w, 2, c4(MIDP["rim"]))
        for bx, sy, fw, fh, glint, col in items:
            rect(im, xx + bx, sy - fh, fw, fh, c4(MIDP["sh"]))
            rect(im, xx + bx + 1, sy - fh // 2, fw - 2, fh // 2, c4(darker(col, 0.28)))
            if glint:
                px(im, xx + bx + 1, sy - fh // 2, c4(darker(col, 0.8)))
    wr.call(draw, x)


def mid_pipe_v(wr, x, base, w, P, rnd):
    valve_y = rnd.randrange(80, base - 60)

    def draw(im, xx):
        rect(im, xx, 0, w, base, c4(MIDP["base"]))
        vline(im, xx + 1, 0, base, c4(MIDP["rim"]))
        for k in range(16, base, 64):
            rect(im, xx - 2, k, w + 4, 4, c4(MIDP["sh"]))
            hline(im, xx - 2, k, w + 4, c4(MIDP["rim"]))
        ring(im, xx + w // 2, valve_y, 7, c4(mix(MIDP["rim"], (150, 50, 40), 0.35)))
        line(im, xx + w // 2 - 7, valve_y, xx + w // 2 + 7, valve_y, c4(MIDP["rim"]))
    wr.call(draw, x)


def mid_monitor(wr, x, base, P, rnd):
    h = rnd.randrange(50, 90)
    wave = rnd.random() < 0.5

    def draw(im, xx):
        vline(im, xx + 14, base - h, h, c4(MIDP["rim"]))
        rect(im, xx, base - h - 22, 30, 22, c4(MIDP["base"]))
        hline(im, xx, base - h - 22, 30, c4(MIDP["rim"]))
        rect(im, xx + 3, base - h - 19, 24, 15, c4(darker(P["acc"], 0.16)))
        for k in range(24):
            yy = base - h - 12 + (int(round(math.sin(k * 0.7) * 3)) if wave else (-3 if k % 6 < 3 else 2))
            px(im, xx + 3 + k, yy, c4(darker(P["acc"], 0.55)))
    wr.call(draw, x)


def mid_cables(wr, y0, P, rnd):
    spans = []
    x = 0
    while x < W:
        span = rnd.randrange(120, 260)
        sag = rnd.randrange(16, 50)
        spans.append((x, span, sag))
        x += span

    def draw(im, xx):
        for sx, span, sag in spans:
            for k in range(2):
                for i in range(span):
                    t = i / span
                    y = y0 + k * 3 + sag * 4 * t * (1 - t)
                    px(im, xx + sx + i, round(y), c4(MIDP["sh"] if k else MIDP["base"]))
            rect(im, xx + sx - 2, y0 - 2, 5, 6, c4(MIDP["rim"]))
    wr.call(draw, 0)


def mid_duct(wr, y, h, P):
    def draw(im, xx):
        rect(im, xx, y, W, h, c4(MIDP["base"]))
        hline(im, xx, y, W, c4(MIDP["rim"]))
        hline(im, xx, y + h - 1, W, c4(MIDP["sh"]))
        for k in range(0, W, 48):
            vline(im, xx + k, y, h, c4(MIDP["sh"]))
            px(im, xx + k + 3, y + 3, c4(MIDP["rim"]))
    wr.call(draw, 0)


def mid(wing, seed):
    P = WINGS[wing]
    rnd = random.Random(seed)
    wr = Wrap(W, MID_H)
    base = MID_H - 24
    mid_cables(wr, 40 + rnd.randrange(30), P, rnd)
    if wing in ("plant", "reactor"):
        mid_duct(wr, 110, 18, P)
    x = rnd.randrange(20)
    while x < W:
        k = rnd.random()
        if k < 0.3:
            w = rnd.randrange(60, 140); mid_machine(wr, x, base, w, rnd.randrange(40, 140), P, rnd)
        elif k < 0.5 and wing in ("lab", "storage"):
            w = rnd.randrange(60, 110); mid_shelf(wr, x, base, w, rnd.randrange(70, 170), P, rnd)
        elif k < 0.7:
            w = rnd.randrange(10, 22); mid_pipe_v(wr, x, base, w, P, rnd)
        elif k < 0.85:
            w = 30; mid_monitor(wr, x, base, P, rnd)
        else:
            w = rnd.randrange(60, 120); mid_machine(wr, x, base, w, rnd.randrange(30, 80), P, rnd)
        x += w + rnd.randrange(30, 120)

    def gnd(im, xx):
        rect(im, xx, base, W, MID_H - base, c4(MIDP["sh"]))
        hline(im, xx, base, W, c4(MIDP["rim"]))
        for k in range(0, W, 32):
            vline(im, xx + k, base + 1, 4, c4(MIDP["base"]))
    wr.call(gnd, 0)
    return wr.result()


# ------------------------------------------------------------ ceiling bands
def ceiling_band(h, P, rnd, colors):
    wr = Wrap(W, h)
    b, r, s = colors

    def draw(im, xx):
        rect(im, xx, 0, W, 14, c4(b))
        hline(im, xx, 13, W, c4(r))
        # girder truss
        for k in range(0, W, 32):
            line(im, xx + k, 14, xx + k + 16, 30, c4(s))
            line(im, xx + k + 16, 30, xx + k + 32, 14, c4(s))
        hline(im, xx, 30, W, c4(s))
        hline(im, xx, 31, W, c4(b))
    wr.call(draw, 0)
    # hanging ducts / lamps
    x = 0
    while x < W:
        kind = rnd.random()
        if kind < 0.4:
            L = rnd.randrange(20, h - 30)
            dw = rnd.randrange(16, 30)

            def dd(im, xx, L=L, dw=dw):
                rect(im, xx, 32, dw, L, c4(b))
                vline(im, xx, 32, L, c4(r))
                rect(im, xx - 3, 32 + L, dw + 6, 6, c4(b))
                hline(im, xx - 3, 32 + L, dw + 6, c4(r))
            wr.call(dd, x)
            x += dw + rnd.randrange(30, 90)
        else:
            L = rnd.randrange(10, h - 40)

            def lamp(im, xx, L=L):
                vline(im, xx + 6, 32, L, c4(s))
                rect(im, xx, 32 + L, 13, 4, c4(b))
                hline(im, xx + 3, 36 + L, 7, c4(mix(b, (180, 170, 130), 0.25)))
            wr.call(lamp, x)
            x += rnd.randrange(60, 140)
    return wr.result()


if __name__ == "__main__":
    for i, wing in enumerate(WINGS):
        far(wing, 10 + i).save(os.path.join(OUTDIR, "far_%s.png" % wing))
        mid(wing, 20 + i).save(os.path.join(OUTDIR, "mid_%s.png" % wing))
    rnd = random.Random(5)
    P = WINGS["lab"]
    ceiling_band(128, P, rnd, ((15, 24, 40), (22, 34, 52), (11, 18, 31))).save(os.path.join(OUTDIR, "ceiling_far.png"))
    ceiling_band(160, P, random.Random(6), (MIDP["base"], MIDP["rim"], MIDP["sh"])).save(os.path.join(OUTDIR, "ceiling_mid.png"))
    print("backdrops done")
