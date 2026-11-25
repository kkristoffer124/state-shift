"""Generates the decoration sprite library into assets/deco/ (run: python -I tools/art/gen_props.py).
Everything is 1x pixel art: 1px dark outlines, one highlight + one shadow tone."""
import os, sys, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pix import *  # noqa

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUTDIR = os.path.join(ROOT, "assets", "deco")
os.makedirs(OUTDIR, exist_ok=True)


def save(im, name):
    im.save(os.path.join(OUTDIR, name + ".png"))


# ---------------------------------------------------------------- tanks
def specimen_tank(frame, seed, w=32, h=64, specimen=True):
    im = new(w, h)
    # cap + base
    box(im, 2, 0, w - 4, 8)
    hline(im, 4, 3, w - 8, SH)
    box(im, 0, h - 10, w, 10)
    for i in range(3):
        px(im, 4 + i * 12, h - 6, HI2)
    # glass
    gx, gy, gw, gh = 4, 8, w - 8, h - 18
    rect(im, gx, gy, gw, gh, OUT)
    rect(im, gx + 1, gy, gw - 2, gh, FLUID)
    rect(im, gx + 1, gy, gw - 2, 4, GLASS)  # air gap at top
    vline(im, gx + 2, gy + 1, gh - 2, FLUID_HI)
    vline(im, gx + 3, gy + 6, gh - 14, GLASS_HI)
    vline(im, gx + gw - 3, gy + 1, gh - 2, SH)
    # specimen silhouette: a little sleeping blob with one eye (eerie but cute)
    if specimen:
        cx, cy = w // 2, gy + gh // 2 + 4 + int(round(math.sin(frame / 6 * math.tau) * 1))
        for y in range(-6, 7):
            for x in range(-6, 7):
                if (x * x) / 36 + (y * y) / 30 <= 1:
                    px(im, cx + x, cy + y, (18, 46, 52, 255))
        px(im, cx - 2, cy - 1, (120, 220, 200, 255))
        px(im, cx + 2, cy - 1, (18, 46, 52, 255))
        hline(im, cx - 1, cy + 3, 3, (14, 36, 42, 255))
    # bubbles (animated)
    rnd = random.Random(seed)
    cols = [gx + 4 + rnd.randrange(gw - 8) for _ in range(4)]
    for i, bx in enumerate(cols):
        period = gh - 6
        yy = gy + gh - 2 - ((frame * 7 + i * 13) % period)
        c = (110, 200, 210, 255) if i % 2 == 0 else (80, 160, 175, 255)
        px(im, bx + (1 if (frame + i) % 3 == 0 else 0), yy, c)
        if i == 0:
            px(im, bx + 1, yy - 1, c)
    return im


save(strip([specimen_tank(f, 3) for f in range(6)]), "tank_specimen_6f")
save(strip([specimen_tank(f, 9, specimen=False) for f in range(6)]), "tank_plain_6f")


def big_tank(frame, glow=FLUID, glow_hi=FLUID_HI, w=48, h=96):
    im = new(w, h)
    # dome top
    for y in range(10):
        hw = int((w / 2 - 2) * math.sqrt(1 - ((10 - y) / 10.0) ** 2))
        rect(im, w // 2 - hw, y, hw * 2, 1, MID if y > 3 else HI)
        px(im, w // 2 - hw - 1, y, OUT)
        px(im, w // 2 + hw, y, OUT)
    hline(im, w // 2 - 3, 0, 6, OUT)
    cyl_v(im, 1, 10, w - 2, h - 22)
    # window band with fluid
    wx, wy, ww, wh = 8, 20, w - 16, h - 44
    rect(im, wx - 1, wy - 1, ww + 2, wh + 2, OUT)
    rect(im, wx, wy, ww, wh, glow)
    vline(im, wx + 1, wy, wh, glow_hi)
    vline(im, wx + 2, wy + 4, wh - 8, glow_hi)
    lvl = 6 + int(round(math.sin(frame / 6 * math.tau)))
    rect(im, wx, wy, ww, lvl, GLASS)
    hline(im, wx, wy + lvl, ww, glow_hi)
    for i in range(6):
        bx = wx + 3 + (i * 7) % (ww - 5)
        by = wy + wh - 2 - ((frame * 5 + i * 11) % (wh - lvl - 3))
        px(im, bx, by, mix(glow_hi, (220, 255, 255, 255), 0.5))
    # rings + rivets
    for ry in (14, h - 18):
        hline(im, 1, ry, w - 2, OUT)
        for rx in range(4, w - 3, 6):
            px(im, rx, ry + 1, HI2)
    # legs
    box(im, 2, h - 12, w - 4, 6)
    rect(im, 5, h - 6, 4, 6, OUT)
    rect(im, w - 9, h - 6, 4, 6, OUT)
    # gauge
    disc(im, w - 10, 16, 3, OUT)
    disc(im, w - 10, 16, 2, (150, 170, 180, 255))
    px(im, w - 10 + (1 if frame % 2 else 0), 15, RED)
    return im


save(strip([big_tank(f) for f in range(6)]), "tank_big_6f")
save(strip([big_tank(f, (60, 40, 30, 255), (150, 70, 30, 255)) for f in range(6)]), "tank_hot_6f")
save(strip([big_tank(f, (28, 62, 50, 255), (60, 130, 90, 255)) for f in range(6)]), "tank_algae_6f")


# ---------------------------------------------------------------- electronics
def server_rack(frame, w=32, h=72):
    im = new(w, h)
    box(im, 0, 0, w, h)
    rnd = random.Random(frame * 31 + 7)
    for u in range(8):
        y = 4 + u * 8
        rect(im, 3, y, w - 6, 7, OUT)
        rect(im, 4, y + 1, w - 8, 5, SH)
        hline(im, 4, y + 1, w - 8, MID)
        for k in range(3):
            on = rnd.random() < 0.55
            c = [LEDG, AMBER, LEDB][(u + k) % 3] if on else (30, 40, 48, 255)
            px(im, 6 + k * 3, y + 3, c)
        for k in range(5):
            px(im, 17 + k * 2, y + 3, OUT)
    rect(im, 2, h - 4, 4, 4, OUT)
    rect(im, w - 6, h - 4, 4, 4, OUT)
    return im


save(strip([server_rack(f) for f in range(4)]), "server_rack_4f")


def terminal(frame, w=40, h=48, accent=SCREEN_TXT):
    im = new(w, h)
    # desk
    box(im, 0, 30, w, 6)
    rect(im, 2, 36, 3, h - 36, OUT)
    rect(im, w - 5, 36, 3, h - 36, OUT)
    box(im, w - 14, 36, 10, 10)
    hline(im, w - 12, 40, 6, OUT)
    # monitor
    box(im, 6, 4, 26, 22)
    rect(im, 9, 7, 20, 15, SCREEN)
    rnd = random.Random(1234)
    lines = [rnd.randrange(4, 18) for _ in range(12)]
    for i in range(4):
        L = lines[(i + frame) % 12]
        hline(im, 10, 8 + i * 3, L, mix(SCREEN, accent, 0.75))
    if frame % 2 == 0:
        rect(im, 10 + lines[(3 + frame) % 12] + 1, 17, 2, 2, accent)
    rect(im, 17, 26, 4, 4, OUT)
    hline(im, 13, 29, 12, OUT)
    # keyboard + mug
    rect(im, 8, 28, 18, 2, SH)
    hline(im, 8, 28, 18, HI)
    rect(im, 30, 25, 4, 5, (70, 80, 92, 255))
    px(im, 34, 26, (70, 80, 92, 255))
    if frame % 4 < 2:
        px(im, 31, 23, (90, 110, 125, 180))
    else:
        px(im, 32, 22, (90, 110, 125, 140))
    return im


save(strip([terminal(f) for f in range(4)]), "terminal_4f")
save(strip([terminal(f, accent=(230, 150, 70, 255)) for f in range(4)]), "terminal_amber_4f")


def monitor_wall(frame, w=48, h=32):
    im = new(w, h)
    for i in range(2):
        x = i * 24
        box(im, x, 0, 23, 18)
        rect(im, x + 3, 3, 17, 12, SCREEN)
        # waveform
        for k in range(17):
            yy = 9 + int(round(math.sin((k + frame * 3 + i * 5) * 0.6) * (3 if i == 0 else 2)))
            px(im, x + 3 + k, yy, SCREEN_TXT if i == 0 else LEDG)
    vline(im, 11, 18, 14, OUT)
    vline(im, 35, 18, 14, OUT)
    return im


save(strip([monitor_wall(f) for f in range(6)]), "monitor_wall_6f")


# ---------------------------------------------------------------- storage
def crate(variant):
    w, h = (32, 32) if variant < 2 else (24, 24)
    im = new(w, h)
    wood = [(56, 50, 46, 255), (44, 52, 60, 255), (50, 46, 44, 255)][variant]
    whi = mix(wood, (120, 120, 120, 255), 0.25)
    wsh = mix(wood, (0, 0, 0, 255), 0.35)
    box(im, 0, 0, w, h, wood, OUT, whi, wsh)
    rect(im, 3, 3, w - 6, h - 6, wsh)
    for k in range(3, h - 3, 5):
        hline(im, 3, k, w - 6, wood)
    line(im, 3, 3, w - 4, h - 4, whi)
    line(im, 3, 4, w - 5, h - 4, wood)
    if variant == 1:
        # stencil label
        rect(im, 6, h // 2 - 4, w - 12, 8, OUT)
        text(im, 8, h // 2 - 2, "H2O", (120, 130, 140, 255))
    return im


save(strip([crate(0), crate(1)]), "crate_2v")
save(crate(2), "crate_small")


def barrel(variant, w=20, h=28):
    im = new(w, h)
    col = [(50, 70, 86, 255), (80, 60, 30, 255), (40, 70, 60, 255)][variant]
    cyl_v(im, 0, 1, w, h - 2, col, OUT, mix(col, (200, 200, 200, 255), 0.2), mix(col, (0, 0, 0, 255), 0.4))
    hline(im, 1, 0, w - 2, OUT)
    hline(im, 1, h - 1, w - 2, OUT)
    for y in (6, h - 8):
        hline(im, 1, y, w - 2, OUT)
    if variant == 1:
        for k in range(0, w - 2, 4):
            rect(im, 1 + k, 12, 2, 3, (20, 20, 20, 255))
    if variant == 2:
        disc(im, w // 2, 14, 3, (150, 230, 180, 255))
        px(im, w // 2, 14, OUT)
    return im


save(strip([barrel(i) for i in range(3)]), "barrel_3v")


def shelf_jars(variant, w=64, h=48):
    im = new(w, h)
    rnd = random.Random(variant * 17 + 3)
    # uprights
    rect(im, 0, 0, 3, h, OUT)
    rect(im, w - 3, 0, 3, h, OUT)
    vline(im, 1, 0, h, SH)
    vline(im, w - 2, 0, h, SH)
    for sy in (15, 31, 46):
        rect(im, 0, sy, w, 2, OUT)
        hline(im, 2, sy, w - 4, HI)
    jar_cols = [(40, 110, 110), (60, 120, 70), (120, 90, 50), (90, 70, 120), (110, 50, 50), (60, 90, 130)]
    for sy in (15, 31, 46):
        x = 4
        while x < w - 10:
            jw = rnd.choice([5, 6, 7, 8])
            jh = rnd.choice([7, 8, 10, 11, 12])
            if rnd.random() < 0.18:
                x += jw
                continue
            if rnd.random() < 0.2:  # book stack / box instead
                bh = rnd.choice([6, 8])
                box(im, x, sy - bh, jw + 2, bh, (44, 50, 64, 255))
                x += jw + 3
                continue
            c = rnd.choice(jar_cols)
            fill = rgba(mix(c, (20, 30, 40), 0.45))
            fhi = rgba(mix(c, (200, 230, 230), 0.15))
            rect(im, x, sy - jh, jw, jh, OUT)
            rect(im, x + 1, sy - jh + 3, jw - 2, jh - 3, fill)
            rect(im, x + 1, sy - jh + 1, jw - 2, 2, GLASS)
            vline(im, x + 1, sy - jh + 3, jh - 4, fhi)
            hline(im, x + 1, sy - jh, jw - 2, (70, 80, 90, 255))  # lid
            if rnd.random() < 0.3:
                px(im, x + jw // 2, sy - jh // 2, (200, 240, 230, 255))
            x += jw + 1
    return im


save(strip([shelf_jars(i) for i in range(3)]), "shelf_jars_3v")


def locker(variant, w=24, h=56):
    im = new(w, h)
    box(im, 0, 0, w, h)
    vline(im, w // 2, 1, h - 2, OUT)
    for x0 in (2, w // 2 + 2):
        for k in range(3):
            hline(im, x0, 4 + k * 2, 7, OUT)
        px(im, x0 + 7 if x0 == 2 else x0, 28, HI2)
    if variant == 1:  # door ajar, dark inside
        rect(im, w // 2 + 1, 1, w // 2 - 2, h - 2, (8, 12, 18, 255))
        vline(im, w - 2, 1, h - 2, HI)
        px(im, w // 2 + 4, 20, (120, 220, 200, 255))  # something glints inside
    return im


save(strip([locker(0), locker(1)]), "locker_2v")


# ---------------------------------------------------------------- lights & signs
def lamp(frame, w=24, h=14):
    im = new(w, h)
    vline(im, w // 2, 0, 4, OUT)
    # shade
    for y in range(4, 10):
        hw = 3 + (y - 4) * 1.5
        rect(im, int(w / 2 - hw), y, int(hw * 2), 1, MID if y < 8 else HI)
        px(im, int(w / 2 - hw) - 1, y, OUT)
        px(im, int(w / 2 + hw), y, OUT)
    hline(im, 2, 10, w - 4, OUT)
    on = frame == 0
    bulb = (255, 236, 190, 255) if on else (90, 90, 80, 255)
    rect(im, w // 2 - 3, 11, 6, 2, bulb)
    hline(im, w // 2 - 2, 13, 4, mix(bulb, OUT, 0.3))
    return im


save(strip([lamp(0), lamp(1)]), "lamp_ceiling_2f")


def light_cone(w=96, h=160):
    im = new(w, h)
    for y in range(h):
        t = y / (h - 1)
        hw = 6 + (w / 2 - 6) * t
        for x in range(w):
            d = abs(x - (w - 1) / 2) / hw
            if d <= 1:
                a = (1 - t) ** 1.6 * (1 - d ** 2) ** 1.2
                im.putpixel((x, y), (255, 255, 255, int(255 * a)))
    return im


save(light_cone(), "light_cone")
save(radial(64, 2.2), "glow_soft")
save(radial(128, 1.8), "glow_big")
save(radial(16, 1.5), "glow_dot")


def sign(kind):
    w, h = 32, 24
    im = new(w, h)
    if kind == "hazard":  # yellow triangle
        bg = (180, 140, 40, 255)
        for y in range(18):
            hw = y * 0.75
            rect(im, int(16 - hw), 3 + y, int(hw * 2) + 1, 1, bg)
            px(im, int(16 - hw) - 1, 3 + y, OUT)
            px(im, int(16 + hw) + 1, 3 + y, OUT)
        hline(im, 2, 21, 29, OUT)
        vline(im, 16, 9, 7, OUT)
        px(im, 16, 18, OUT)
        return im
    if kind == "cryo":
        box(im, 2, 2, 28, 20, (30, 70, 96, 255), OUT, (60, 120, 150, 255), (20, 50, 70, 255))
        cx, cy = 10, 12
        for d in ((1, 0), (0, 1), (1, 1), (1, -1)):
            for k in range(-4, 5):
                px(im, cx + d[0] * k, cy + d[1] * k, (180, 230, 255, 255))
        text(im, 17, 6, "C", (180, 230, 255, 255))
        text(im, 21, 6, "R", (180, 230, 255, 255))
        text(im, 17, 13, "-9", (180, 230, 255, 255))
        return im
    if kind == "heat":
        box(im, 2, 2, 28, 20, (110, 44, 24, 255), OUT, (170, 70, 30, 255), (70, 26, 16, 255))
        for y in range(10):  # flame
            hw = int(3 * math.sin(math.pi * (y + 1) / 11))
            rect(im, 10 - hw, 6 + y, hw * 2 + 1, 1, (255, 170, 60, 255))
        px(im, 10, 5, (255, 170, 60, 255))
        rect(im, 9, 12, 3, 3, (255, 230, 150, 255))
        text(im, 17, 9, "HOT", (255, 200, 140, 255))
        return im
    if kind == "exit":
        box(im, 2, 6, 28, 12, (20, 70, 40, 255), OUT, (40, 120, 70, 255), (14, 50, 30, 255))
        text(im, 8, 9, "EXIT", GOAL)
        return im
    if kind == "arrow":
        box(im, 2, 6, 28, 12, (40, 54, 70, 255))
        for k in range(8):
            hline(im, 8, 11, 14, (200, 200, 190, 255))
        for k in range(4):
            vline(im, 22 + k, 9 + k, 5 - 2 * k if 5 - 2 * k > 0 else 1, (200, 200, 190, 255))
        return im
    if kind == "bio":
        box(im, 2, 2, 28, 20, (150, 130, 40, 255), OUT, (190, 170, 70, 255), (110, 90, 30, 255))
        ring(im, 16, 12, 6, OUT)
        disc(im, 16, 12, 2, OUT)
        for a in (90, 210, 330):
            px(im, round(16 + math.cos(math.radians(a)) * 4), round(12 - math.sin(math.radians(a)) * 4), OUT)
        return im
    if kind == "volt":
        box(im, 2, 2, 28, 20, (150, 130, 40, 255), OUT, (190, 170, 70, 255), (110, 90, 30, 255))
        pts = [(18, 4), (12, 12), (17, 12), (13, 20)]
        for i in range(3):
            line(im, *pts[i], *pts[i + 1], OUT)
        return im
    # lab plates with numbers
    box(im, 2, 6, 28, 12, (52, 66, 82, 255), OUT, (80, 98, 118, 255), (36, 48, 62, 255))
    text(im, 5, 10, kind, (170, 190, 205, 255))
    return im


SIGNS = ["hazard", "cryo", "heat", "exit", "arrow", "bio", "volt", "LAB-1", "B-07", "F-12", "RX-0", "WIND"]
save(strip([sign(k) for k in SIGNS]), "signs_12v")


def poster(kind):
    if kind == 0:  # whiteboard with scribbles + phase diagram
        im = new(56, 36)
        box(im, 0, 0, 56, 34, (150, 165, 175, 255), OUT, (180, 195, 205, 255), (120, 135, 145, 255))
        hline(im, 4, 33, 48, OUT)
        hline(im, 6, 34, 44, SH)
        line(im, 6, 26, 26, 26, (40, 60, 90, 255))
        line(im, 6, 6, 6, 26, (40, 60, 90, 255))
        line(im, 8, 24, 16, 14, (60, 120, 200, 255))
        line(im, 16, 14, 24, 8, (200, 70, 50, 255))
        line(im, 12, 18, 22, 24, (60, 160, 90, 255))
        text(im, 30, 5, "H2O", (40, 60, 90, 255))
        for k in range(4):
            hline(im, 30, 13 + k * 4, random.Random(k).randrange(8, 20), (90, 100, 120, 255))
        return im
    im = new(28, 36)
    if kind == 1:  # molecule poster
        box(im, 0, 0, 28, 36, (40, 60, 80, 255), OUT, (60, 84, 106, 255), (30, 44, 60, 255))
        disc(im, 14, 15, 4, (200, 70, 60, 255))
        disc(im, 7, 21, 3, (220, 225, 230, 255))
        disc(im, 21, 21, 3, (220, 225, 230, 255))
        px(im, 13, 13, (255, 170, 150, 255))
        hline(im, 5, 29, 18, (120, 150, 170, 255))
        hline(im, 7, 31, 14, (90, 110, 130, 255))
    else:  # "stay cool" safety poster
        box(im, 0, 0, 28, 36, (30, 70, 96, 255), OUT, (60, 110, 140, 255), (22, 50, 70, 255))
        disc(im, 14, 14, 6, (100, 170, 230, 255))
        px(im, 12, 13, OUT)
        px(im, 16, 13, OUT)
        hline(im, 12, 17, 5, OUT)
        text(im, 3, 25, "STAY", (200, 230, 250, 255))
        text(im, 3, 30, "COOL", (200, 230, 250, 255))
    return im


save(poster(0), "whiteboard")
save(strip([poster(1), poster(2)]), "poster_2v")


def beacon(frame, w=12, h=12):
    im = new(w, h)
    box(im, 1, 8, 10, 4)
    on = frame == 0
    c = (255, 80, 60, 255) if on else (100, 30, 30, 255)
    rect(im, 3, 2, 6, 6, OUT)
    rect(im, 4, 3, 4, 5, c)
    px(im, 4, 3, (255, 200, 180, 255) if on else (140, 60, 50, 255))
    return im


save(strip([beacon(0), beacon(1)]), "beacon_2f")


def exit_light(frame):
    im = sign("exit")
    if frame == 1:
        # one letter flickers off
        rect(im, 16, 9, 3, 5, (20, 70, 40, 255))
    return im


save(strip([exit_light(0), exit_light(1)]), "exit_sign_2f")

# ---------------------------------------------------------------- pipes, cables, structure


def pipe_h_tile(w=32, h=10, col=MID):
    im = new(w, h)
    cyl_h(im, 0, 0, w, h, col, OUT, HI, SH)
    # flange
    rect(im, w - 4, 0, 3, h, OUT)
    rect(im, w - 4, 0, 3, 1, OUT)
    vline(im, w - 3, 1, h - 2, HI2)
    return im


def pipe_v_tile(w=10, h=32, col=MID):
    return pipe_h_tile(h, w, col).rotate(90, expand=True)


save(pipe_h_tile(), "pipe_h")
save(pipe_v_tile(), "pipe_v")
save(pipe_h_tile(32, 6), "pipe_h_thin")
save(pipe_v_tile(6, 32), "pipe_v_thin")
save(pipe_h_tile(64, 16), "pipe_h_big")


def pipe_elbow(size=16, w=10):
    im = new(size, size)
    # horizontal arm from left to center, then down
    cyl_h(im, 0, 0, size - 2, w)
    cyl_v(im, size - w - 2 + 2, 0, w, size)
    rect(im, size - w, 0, w, w, MID)
    hline(im, size - w, 0, w, OUT)
    vline(im, size - 1, 0, size, OUT)
    vline(im, size - w, w, size - w, OUT)
    px(im, size - w + 1, 1, HI2)
    return im


save(pipe_elbow(), "pipe_elbow")


def valve(frame, s=16):
    im = new(s, s)
    c = (s - 1) / 2
    ring(im, c, c, 6, (150, 50, 40, 255))
    ring(im, c, c, 5, (110, 36, 30, 255))
    a0 = frame * 30
    for k in range(3):
        a = math.radians(a0 + k * 120)
        line(im, round(c), round(c), round(c + math.cos(a) * 5), round(c + math.sin(a) * 5), (150, 50, 40, 255))
    disc(im, round(c), round(c), 1, OUT)
    return im


save(valve(0), "valve")


def gauge(frame, s=14):
    im = new(s, s)
    disc(im, 7, 7, 6, OUT)
    disc(im, 7, 7, 5, (170, 180, 175, 255))
    px(im, 7, 3, RED)
    a = math.radians(-140 + 30 + frame * 6 + (3 if frame % 2 else 0))
    line(im, 7, 7, round(7 + math.cos(a) * 4), round(7 + math.sin(a) * 4), OUT)
    px(im, 7, 12, OUT)
    return im


save(strip([gauge(f) for f in range(4)]), "gauge_4f")


def cable_droop(w, sag, n=3, seed=0):
    h = sag + 4 + n * 2
    im = new(w, h)
    cols = [(14, 18, 26, 255), (40, 30, 30, 255), (24, 40, 46, 255), (50, 46, 24, 255)]
    rnd = random.Random(seed)
    for k in range(n):
        s = sag - k * rnd.randrange(2, 5)
        c = cols[(k + seed) % len(cols)]
        for x in range(w):
            t = x / (w - 1)
            y = 1 + k * 2 + s * 4 * t * (1 - t)
            px(im, x, round(y), c)
            px(im, x, round(y) + 1, mix(c, (0, 0, 0, 255), 0.4))
    # clamps at ends
    rect(im, 0, 0, 3, n * 2 + 2, OUT)
    rect(im, w - 3, 0, 3, n * 2 + 2, OUT)
    return im


save(cable_droop(64, 14, 2, 1), "cable_droop_64")
save(cable_droop(128, 26, 3, 2), "cable_droop_128")
save(cable_droop(192, 34, 3, 3), "cable_droop_192")


def cable_hang(length=56, seed=0):
    im = new(12, length)
    rnd = random.Random(seed)
    xs = [3, 6]
    for i, x0 in enumerate(xs):
        c = [(16, 20, 28, 255), (40, 30, 30, 255)][i]
        L = length - (0 if i == 0 else rnd.randrange(8, 20))
        for y in range(L):
            x = x0 + round(math.sin(y * 0.08 + i) * 1.2)
            px(im, x, y, c)
            px(im, x + 1, y, mix(c, (0, 0, 0, 255), 0.4))
        # frayed end
        px(im, x0 - 1, L, (200, 150, 60, 255))
        px(im, x0 + 2, L, (200, 150, 60, 255))
    rect(im, 1, 0, 9, 3, OUT)
    return im


save(cable_hang(56, 1), "cable_hang")
save(cable_hang(96, 2), "cable_hang_long")


def chain_tile(w=6, h=16):
    im = new(w, h)
    # two links
    rect(im, 1, 0, 4, 8, OUT)
    rect(im, 2, 1, 2, 6, T)
    vline(im, 1, 1, 6, (70, 80, 92, 255))
    rect(im, 2, 8, 2, 8, OUT)
    px(im, 2, 9, (70, 80, 92, 255))
    return im


save(chain_tile(), "chain_tile")


def hook():
    im = new(10, 12)
    rect(im, 4, 0, 2, 5, OUT)
    for a in range(0, 200, 10):
        r = math.radians(a)
        px(im, round(5 + math.cos(r) * 3), round(8 + math.sin(r) * 3), (80, 90, 100, 255))
    px(im, 2, 6, OUT)
    return im


save(hook(), "chain_hook")


def ladder_tile(w=16, h=16):
    im = new(w, h)
    rect(im, 1, 0, 2, h, OUT)
    rect(im, w - 3, 0, 2, h, OUT)
    vline(im, 2, 0, h, HI)
    vline(im, w - 2, 0, h, SH)
    for y in (3, 11):
        hline(im, 3, y, w - 6, MID)
        hline(im, 3, y + 1, w - 6, OUT)
    return im


save(ladder_tile(), "ladder_tile")


def rail_tile(w=32, h=16):
    im = new(w, h)
    hline(im, 0, 0, w, HI)
    hline(im, 0, 1, w, OUT)
    hline(im, 0, 7, w, OUT)
    rect(im, 0, 2, 2, h - 2, OUT)
    vline(im, 16, 2, h - 4, OUT)
    rect(im, 0, h - 3, w, 3, OUT)
    hline(im, 0, h - 3, w, MID)
    for x in range(2, w, 4):
        px(im, x, h - 2, SH)
    return im


save(rail_tile(), "rail_tile")


def girder_tile(w=32, h=16, c1=SH, c2=MID):
    im = new(w, h)
    rect(im, 0, 0, w, 3, OUT)
    hline(im, 0, 1, w, c2)
    rect(im, 0, h - 3, w, 3, OUT)
    hline(im, 0, h - 2, w, c1)
    line(im, 0, 3, 15, h - 4, OUT)
    line(im, 16, h - 4, 31, 3, OUT)
    line(im, 1, 3, 16, h - 4, c1)
    return im


save(girder_tile(), "girder_tile")


def vent(frame, w=32, h=20):
    im = new(w, h)
    box(im, 0, 0, w, h)
    rect(im, 3, 3, w - 6, h - 6, OUT)
    for k in range(4):
        hline(im, 4, 4 + k * 3, w - 8, MID if k != frame % 4 else HI)
    for c in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)):
        px(im, *c, HI2)
    return im


save(strip([vent(f) for f in range(4)]), "vent_4f")


def fan_housing(s=40):
    im = new(s, s)
    box(im, 0, 0, s, s)
    disc(im, s // 2, s // 2, s // 2 - 3, OUT)
    disc(im, s // 2, s // 2, s // 2 - 4, (10, 14, 22, 255))
    for c in ((3, 3), (s - 4, 3), (3, s - 4), (s - 4, s - 4)):
        px(im, *c, HI2)
    return im


def fan_blades(s=32, col=MID, n=4):
    im = new(s, s)
    c = (s - 1) / 2
    R = s / 2 - 1.5
    for y in range(s):
        for x in range(s):
            dx, dy = x - c, y - c
            r = math.hypot(dx, dy)
            if r > R or r < 1:
                continue
            a = (math.atan2(dy, dx) - r / R * 0.5) % (math.tau / n)
            half = 0.42 * math.sin(min(1.0, r / R) * math.pi * 0.9 + 0.15)
            if a < half * 2:
                im.putpixel((x, y), HI if a < half * 0.6 else col)
    im = outline_alpha(im)
    disc(im, round(c), round(c), max(2, s // 10), OUT)
    disc(im, round(c), round(c), max(1, s // 14), HI2)
    return im


save(fan_housing(), "fan_housing")
save(fan_blades(), "fan_blades")
save(fan_blades(96, (18, 26, 38, 255)), "fan_blades_big")


def gear(s, teeth, col=MID):
    im = new(s, s)
    c = (s - 1) / 2
    R = s / 2 - 3
    for y in range(s):
        for x in range(s):
            dx, dy = x - c, y - c
            d = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            tooth = (math.cos(a * teeth) > 0.2)
            if d <= R or (tooth and d <= R + 2.5):
                im.putpixel((x, y), col)
                if dx + dy < -R * 0.6:
                    im.putpixel((x, y), HI)
    disc(im, round(c), round(c), max(2, s // 6), OUT)
    for k in range(teeth // 2):
        a = k * 2 * math.pi / (teeth // 2)
        px(im, round(c + math.cos(a) * R * 0.55), round(c + math.sin(a) * R * 0.55), SH)
    return outline_alpha(im)


save(gear(32, 10), "gear_32")
save(gear(20, 8), "gear_20")
save(gear(64, 14, (20, 28, 40, 255)), "gear_64")


def coil(frame, w=32, h=80):
    im = new(w, h)
    box(im, 4, h - 10, w - 8, 10)
    cyl_v(im, 12, 6, 8, h - 16)
    pulse = [0.2, 0.55, 1.0, 0.55][frame]
    gc = mix((60, 30, 20, 255), (255, 120, 50, 255), pulse)
    for k in range(7):
        y = 10 + k * 9
        cyl_h(im, 5, y, w - 10, 6, (80, 54, 40, 255), OUT, (120, 80, 50, 255), (50, 34, 28, 255))
        hline(im, 7, y + 3, w - 14, gc)
    box(im, 8, 0, w - 16, 7)
    disc(im, w // 2, 3, 1, mix(gc, (255, 255, 255, 255), 0.3))
    return im


save(strip([coil(f) for f in range(4)]), "coil_4f")


def boiler(frame, w=48, h=64):
    im = new(w, h)
    cyl_v(im, 2, 6, w - 4, h - 14, (48, 46, 50, 255), OUT, (70, 66, 68, 255), (32, 30, 36, 255))
    for y in range(6):
        hw = int((w / 2 - 3) * math.sqrt(1 - ((6 - y) / 6.0) ** 2))
        rect(im, w // 2 - hw, y, hw * 2, 1, (70, 66, 68, 255))
        px(im, w // 2 - hw - 1, y, OUT)
        px(im, w // 2 + hw, y, OUT)
    # firebox window
    flick = [0.75, 1.0, 0.85, 0.65][frame]
    rect(im, 14, h - 28, 20, 12, OUT)
    for y in range(10):
        t = y / 9
        rect(im, 15, h - 27 + y, 18, 1, mix((60, 20, 10, 255), (255, 140, 40, 255), t * flick))
    for x in range(16, 33, 3):
        vline(im, x, h - 27, 10, OUT)
    # gauge
    disc(im, w // 2, 18, 5, OUT)
    disc(im, w // 2, 18, 4, (180, 180, 170, 255))
    a = math.radians(-60 + frame * 8)
    line(im, w // 2, 18, round(w / 2 + math.cos(a) * 3), round(18 + math.sin(a) * 3), RED)
    # rivets
    for y in (10, h - 12):
        hline(im, 2, y, w - 4, OUT)
    box(im, 0, h - 8, w, 8)
    return im


save(strip([boiler(f) for f in range(4)]), "boiler_4f")


def desk_clutter(variant):
    im = new(32, 16)
    if variant == 0:  # potted plant + mug (cozy)
        rect(im, 4, 10, 8, 6, (110, 70, 50, 255))
        hline(im, 4, 10, 8, (150, 100, 70, 255))
        for (x, y) in ((8, 9), (6, 6), (10, 5), (7, 3), (9, 2), (5, 8), (11, 7)):
            px(im, x, y, (60, 140, 90, 255))
            px(im, x + 1, y, (40, 100, 70, 255))
        vline(im, 8, 4, 6, (40, 100, 70, 255))
        rect(im, 18, 11, 5, 5, (150, 160, 170, 255))
        px(im, 23, 12, (150, 160, 170, 255))
        px(im, 23, 13, (150, 160, 170, 255))
    else:  # flasks + rack
        for i, c in enumerate(((60, 160, 140), (180, 80, 60), (90, 120, 200))):
            x = 3 + i * 10
            vline(im, x + 2, 4, 4, (120, 140, 150, 255))
            vline(im, x + 3, 4, 4, (120, 140, 150, 255))
            for y in range(8, 16):
                hw = (y - 8) // 2
                rect(im, x + 2 - hw, y, 2 + hw * 2, 1, rgba(c) if y > 10 else (60, 80, 90, 255))
            px(im, x + 2, 11, (220, 240, 240, 255))
    return im


save(strip([desk_clutter(0), desk_clutter(1)]), "desk_clutter_2v")


def bench(w=64, h=24):
    im = new(w, h)
    box(im, 0, 0, w, 5, HI, OUT, HI2, MID)
    rect(im, 3, 5, 3, h - 5, OUT)
    rect(im, w - 6, 5, 3, h - 5, OUT)
    box(im, 6, 8, 20, 10)
    hline(im, 10, 12, 12, OUT)
    hline(im, 6, h - 4, w - 12, OUT)
    return im


save(bench(), "lab_bench")


def puff(frame):
    im = new(16, 16)
    r = 3 + frame
    for y in range(16):
        for x in range(16):
            d = math.hypot(x - 7.5, y - 7.5)
            if d <= r:
                a = 1 - d / (r + 0.01)
                im.putpixel((x, y), (220, 235, 245, int(200 * min(1, a * 1.8))))
    return im


save(puff(4), "steam_puff")
spark = new(3, 3)
px(spark, 1, 1, (255, 255, 220, 255))
px(spark, 0, 1, (255, 200, 90, 255))
px(spark, 2, 1, (255, 200, 90, 255))
px(spark, 1, 0, (255, 200, 90, 255))
px(spark, 1, 2, (255, 200, 90, 255))
save(spark, "spark")
dropl = new(3, 4)
px(dropl, 1, 0, (140, 210, 240, 255))
rect(dropl, 0, 1, 3, 2, (100, 180, 230, 255))
px(dropl, 1, 3, (70, 140, 200, 255))
save(dropl, "drip_drop")


# ---------------------------------------------------------------- wall decals (z above walls)
def grime_strip(kind, w=64, h=16):
    im = new(w, h)
    rnd = random.Random(kind * 101 + 5)
    cols = {
        0: [(14, 20, 28, 150), (20, 28, 38, 110)],      # lab grime
        1: [(48, 92, 62, 170), (34, 70, 50, 150)],      # moss
        2: [(120, 62, 32, 160), (88, 46, 26, 150)],     # rust
        3: [(8, 8, 12, 190), (26, 18, 16, 160)],        # soot
        4: [(170, 225, 250, 210), (120, 190, 230, 170)],  # frost
    }[kind]
    for x in range(w):
        L = 1 + rnd.random() * 3
        if rnd.random() < 0.18:
            L += rnd.random() * (h - 4)
        for y in range(int(L)):
            c = cols[0] if y < 2 else cols[1]
            a = int(c[3] * (1 - y / h * 0.6))
            px(im, x, y, (c[0], c[1], c[2], a))
    if kind == 4:  # icicles
        for x in range(2, w, 5 + rnd.randrange(3)):
            L = rnd.randrange(3, h)
            for y in range(L):
                px(im, x, y, (200, 240, 255, 230))
                if y < L - 2:
                    px(im, x + 1, y, (150, 210, 240, 200))
    if kind == 1:
        for _ in range(10):
            x = rnd.randrange(w)
            px(im, x, 0, (90, 150, 90, 200))
    return im


save(vstack([grime_strip(k) for k in range(5)]), "grime_strip_5v")


def trim_strip(w=32, h=6):
    im = new(w, h)
    rect(im, 0, 0, w, h, (20, 28, 38, 255))
    hline(im, 0, 1, w, (62, 84, 106, 255))
    hline(im, 0, h - 1, w, (12, 18, 26, 255))
    for x in (4, 20):
        px(im, x, 3, (110, 135, 158, 255))
        px(im, x + 1, 4, (12, 18, 26, 255))
    return im


save(trim_strip(), "trim_rivets")


def hazard_strip(w=32, h=8):
    im = new(w, h)
    for y in range(h):
        for x in range(w):
            on = ((x + y) // 4) % 2 == 0
            im.putpixel((x, y), (170, 130, 40, 255) if on else (20, 22, 26, 255))
    hline(im, 0, 0, w, OUT)
    hline(im, 0, h - 1, w, OUT)
    return im


save(hazard_strip(), "hazard_strip")


def blob_decal(w, h, col, seed, density=0.55, edge=2):
    im = new(w, h)
    rnd = random.Random(seed)
    cx, cy = w / 2, h / 2
    for y in range(h):
        for x in range(w):
            d = math.hypot((x - cx) / (w / 2), (y - cy) / (h / 2))
            n = rnd.random()
            if d < 1 and n < density * (1.2 - d):
                a = int(col[3] * (1 - d * 0.7))
                im.putpixel((x, y), (col[0], col[1], col[2], a))
    return im


save(blob_decal(56, 28, (10, 8, 8, 200), 1, 0.9), "scorch")
save(blob_decal(40, 20, (180, 230, 255, 200), 2, 0.7), "frost_patch")
save(blob_decal(32, 16, (48, 92, 62, 190), 3, 0.8), "moss_patch")


def rust_drip(seed, w=16, h=32):
    im = new(w, h)
    rnd = random.Random(seed)
    rect(im, 5, 0, 6, 3, (110, 58, 30, 170))
    for x in range(4, 12):
        L = rnd.randrange(3, h)
        for y in range(L):
            px(im, x, y, (110, 58, 30, int(170 * (1 - y / L))))
    return im


save(strip([rust_drip(1), rust_drip(2)]), "rust_drip_2v")


def crack_decal(seed, s=24):
    im = new(s, s)
    rnd = random.Random(seed)
    for k in range(3):
        x, y = s // 2, s // 2
        a = rnd.random() * math.tau
        for i in range(14):
            px(im, round(x), round(y), (14, 20, 28, 255))
            px(im, round(x) + 1, round(y), (60, 80, 100, 200))
            a += rnd.uniform(-0.6, 0.6)
            x += math.cos(a)
            y += math.sin(a)
    return im


save(strip([crack_decal(s) for s in (1, 2, 3)]), "wall_crack_3v")


def panel_plate(variant):
    im = new(24, 32)
    if variant == 0:  # access hatch
        box(im, 0, 0, 24, 32, (36, 50, 66, 255), (18, 26, 36, 255), (66, 88, 110, 255), (26, 36, 48, 255))
        for c in ((2, 2), (21, 2), (2, 29), (21, 29)):
            px(im, *c, (110, 135, 158, 255))
        rect(im, 8, 13, 8, 2, (18, 26, 36, 255))
    else:  # fuse box with small leds
        box(im, 0, 0, 24, 32, (36, 50, 66, 255), (18, 26, 36, 255), (66, 88, 110, 255), (26, 36, 48, 255))
        for k in range(3):
            rect(im, 4, 5 + k * 8, 16, 5, (18, 26, 36, 255))
            px(im, 6, 7 + k * 8, LEDG if k != 1 else RED)
    return im


save(strip([panel_plate(0), panel_plate(1)]), "wall_panel_2v")


def big_label(s, w=None, col=(92, 118, 142, 255)):
    """Stenciled wall lettering (2x pixel font) used on big wall masses."""
    w = w or (len(s) * 8 + 2)
    im = new(w, 12)
    tmp = new(w // 2 + 1, 6)
    text(tmp, 0, 0, s, col)
    tmp = tmp.resize((tmp.width * 2, tmp.height * 2), Image.NEAREST)
    im.paste(tmp, (1, 1), tmp)
    return im


LABELS = ["LAB 1", "CRYO", "SHAFT", "STORE", "PRESS", "WIND", "FILTR", "SILO", "THERM", "CORE", "FLUE", "RX-12"]
lab_ims = [big_label(s, 48) for s in LABELS]
save(vstack(lab_ims), "wall_labels_12v")


# ---------------------------------------------------------------- foreground silhouettes (near-black)
FG = (6, 9, 16, 255)
FG_RIM = (20, 30, 44, 255)


def fg_pipe_v(w=24, h=64):
    im = new(w, h)
    rect(im, 0, 0, w, h, FG)
    vline(im, 2, 0, h, FG_RIM)
    rect(im, 0, h - 6, w, 4, (2, 4, 8, 255))
    hline(im, 0, h - 6, w, FG_RIM)
    return im


save(fg_pipe_v(), "fg_pipe_v")


def fg_cables(w=192, sag=48, seed=4):
    h = sag + 12
    im = new(w, h)
    rnd = random.Random(seed)
    for k in range(4):
        s = sag - k * rnd.randrange(4, 10)
        th = 2 + k % 2
        for x in range(w):
            t = x / (w - 1)
            y = 2 + k * 2 + s * 4 * t * (1 - t)
            for d in range(th):
                px(im, x, round(y) + d, FG)
    return im


save(fg_cables(), "fg_cables")


def fg_girder(w=64, h=24):
    im = new(w, h)
    rect(im, 0, 0, w, 4, FG)
    rect(im, 0, h - 4, w, 4, FG)
    for x0 in range(0, w, 32):
        for i in range(32):
            y = round(4 + (h - 8) * (i / 31 if (x0 // 32) % 2 == 0 else 1 - i / 31))
            rect(im, x0 + i, y - 1, 1, 3, FG)
    hline(im, 0, 0, w, FG_RIM)
    return im


save(fg_girder(), "fg_girder")


def fg_machine(seed, w=96, h=72):
    """Near-black machinery silhouette (tank, pipes, valve wheel) rising from the screen bottom."""
    im = new(w, h)
    rnd = random.Random(seed)
    rim = FG_RIM
    if seed % 2:
        # squat tank with dome + side pipe
        tw, th = 52, 50
        tx = 8
        rect(im, tx, h - th, tw, th, FG)
        for y in range(8):
            hw = int(tw / 2 * math.sqrt(1 - ((8 - y) / 8.0) ** 2))
            rect(im, tx + tw // 2 - hw, h - th - 8 + y, hw * 2, 1, FG)
        vline(im, tx + 3, h - th, th, rim)
        for ry in (h - th + 10, h - 14):
            hline(im, tx, ry, tw, rim)
        rect(im, tx + tw, h - 30, 30, 8, FG)
        hline(im, tx + tw, h - 30, 30, rim)
        rect(im, tx + tw + 24, h - 30, 8, 30, FG)
        ring(im, tx + tw + 12, h - 42, 7, FG)
        line(im, tx + tw + 5, h - 42, tx + tw + 19, h - 42, FG)
        vline(im, tx + tw + 12, h - 35, 5, FG)
    else:
        # pipe bundle with flanges and a gauge
        for i, (pw, ph) in enumerate(((14, 70), (10, 52), (18, 62), (8, 40), (12, 58))):
            x = 6 + i * 18
            rect(im, x, h - ph, pw, ph, FG)
            vline(im, x + 2, h - ph, ph, rim)
            rect(im, x - 2, h - ph, pw + 4, 4, FG)
            hline(im, x - 2, h - ph, pw + 4, rim)
            for fy in range(h - ph + 18, h, 20):
                rect(im, x - 1, fy, pw + 2, 3, FG)
        disc(im, 50, h - 34, 6, FG)
        ring(im, 50, h - 34, 6, rim)
    return im


save(strip([fg_machine(1), fg_machine(2)]), "fg_machine_2v")



def debris(variant):
    im = new(32, 8)
    if variant == 0:  # bolts, a paper sheet
        rect(im, 4, 6, 10, 2, (120, 130, 140, 200))
        hline(im, 4, 6, 10, (160, 170, 180, 220))
        for x in (18, 23, 27):
            rect(im, x, 6, 2, 2, (70, 80, 90, 255))
    elif variant == 1:  # broken tiles
        for x, w_, h_ in ((3, 6, 3), (10, 4, 2), (16, 7, 4), (25, 4, 2)):
            rect(im, x, 8 - h_, w_, h_, (40, 54, 70, 255))
            hline(im, x, 8 - h_, w_, (62, 82, 104, 255))
    elif variant == 2:  # puddle with highlight
        rect(im, 2, 6, 28, 2, (40, 90, 120, 170))
        hline(im, 5, 6, 8, (110, 180, 210, 200))
        hline(im, 18, 7, 5, (90, 160, 200, 180))
    else:  # cable coil
        for k in range(3):
            ring(im, 12 + k, 4, 3, (30, 34, 40, 255))
        line(im, 15, 7, 30, 7, (30, 34, 40, 255))
    return im


save(strip([debris(i) for i in range(4)]), "floor_debris_4v")
print("props done:", len([f for f in os.listdir(OUTDIR) if f.endswith(".png")]), "pngs")
