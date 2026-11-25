# Generates the pixel art for scenes/interactive/*.  Run:  python -I assets/interactive/gen_interactive_art.py
# Style: chunky 1x pixels, 1px dark outlines, palette shared with assets/env.
import math
import os
from PIL import Image

OUT = os.path.dirname(os.path.abspath(__file__))

def hexc(h, a=255):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

T = (0, 0, 0, 0)
INK = hexc('0e151d')
DARK = hexc('18222d')
SLATE = hexc('2a3a4c')
SLATE2 = hexc('3d4f60')
MID = hexc('5d7b93')
STEEL = hexc('9ebcdb')
HI = hexc('c6dbee')
WHITE = hexc('e8eef4')
HEAT = hexc('ff5a1a')
HEAT_D = hexc('a8350c')
FROST = hexc('80d9ff')
FROST_HI = hexc('cff1ff')
GOAL = hexc('66ff99')
GOAL_D = hexc('2fbf6a')
WARN = hexc('e8c547')
WARN_D = hexc('5a5236')
RED = hexc('ff4a5a')
PAPER = hexc('d8d2bd')
PAPER_D = hexc('a8a08a')
LEAF = hexc('6e9a4a')
LEAF_D = hexc('3f5f2a')
WATER = hexc('3f8cff')
WATER_HI = hexc('6fb0ff')


def img(w, h):
    return Image.new('RGBA', (w, h), T)


def rect(im, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < im.width and 0 <= y < im.height:
                im.putpixel((x, y), c)


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), c)


def box(im, x0, y0, x1, y1, fill, edge=INK, top=None):
    rect(im, x0, y0, x1, y1, edge)
    rect(im, x0 + 1, y0 + 1, x1 - 1, y1 - 1, fill)
    if top:
        rect(im, x0 + 1, y0 + 1, x1 - 1, y0 + 1, top)


def outline(im, c=INK):
    """1px outline around every opaque pixel."""
    src = im.copy()
    for y in range(im.height):
        for x in range(im.width):
            if src.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < im.width and 0 <= ny < im.height and src.getpixel((nx, ny))[3] > 0:
                        im.putpixel((x, y), c)
                        break
    return im


def disc(im, cx, cy, r, c):
    for y in range(im.height):
        for x in range(im.width):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                im.putpixel((x, y), c)


def line(im, x0, y0, x1, y1, c):
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(n + 1):
        t = i / max(n, 1)
        px(im, round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t), c)


def save(im, name):
    im.save(os.path.join(OUT, name))


# --- Pressure plate (ICE only) --------------------------------------------------
im = img(48, 6)
box(im, 0, 0, 47, 5, SLATE, top=MID)
for x in (3, 44):
    px(im, x, 3, STEEL)
save(im, 'ix_plate_base.png')

im = img(40, 6)
box(im, 0, 0, 39, 5, MID, top=STEEL)
# little ice-cube glyph in the middle
box(im, 17, 1, 22, 4, FROST, edge=SLATE)
px(im, 18, 2, FROST_HI)
for x in range(3, 37, 4):
    if not 15 <= x <= 24:
        px(im, x, 3, SLATE2)
save(im, 'ix_plate_pad.png')

# --- Gate panel: 24 wide tile (repeats vertically), plus end cap ---------------------
im = img(24, 32)
box(im, 0, 0, 23, 31, SLATE2)
rect(im, 1, 0, 1, 31, MID)
rect(im, 22, 0, 22, 31, DARK)
rect(im, 4, 0, 19, 31, SLATE)
rect(im, 4, 0, 4, 31, DARK)
rect(im, 19, 0, 19, 31, MID)
# hazard chevrons
for y in range(32):
    for x in range(6, 18):
        if ((x + y) // 4) % 2 == 0 and 10 <= y <= 21:
            px(im, x, y, WARN)
        elif 10 <= y <= 21:
            px(im, x, y, WARN_D)
rect(im, 6, 9, 17, 9, INK)
rect(im, 6, 22, 17, 22, INK)
for y in (3, 28):
    px(im, 2, y, STEEL)
    px(im, 21, y, STEEL)
save(im, 'ix_gate_tile.png')

im = img(24, 8)
box(im, 0, 0, 23, 7, MID, top=STEEL)
rect(im, 9, 3, 14, 4, INK)
save(im, 'ix_gate_cap.png')

# --- Turbine: housing ring + 4-frame rotor -----------------------------------------------
im = img(40, 40)
disc(im, 20, 20, 19.5, INK)
disc(im, 20, 20, 18.5, SLATE2)
disc(im, 20, 20, 16.5, MID)
disc(im, 20, 20, 15.5, DARK)
for a in range(0, 360, 45):
    r = math.radians(a)
    px(im, round(20 + math.cos(r) * 17.5 - 0.5), round(20 + math.sin(r) * 17.5 - 0.5), STEEL)
save(im, 'ix_turbine_housing.png')

im = img(32 * 4, 32)
for f in range(4):
    fr = img(32, 32)
    for y in range(32):
        for x in range(32):
            dx, dy = x + 0.5 - 16, y + 0.5 - 16
            for b in range(4):
                a = math.radians(f * 22.5 + b * 90)
                t = dx * math.cos(a) + dy * math.sin(a)
                s = -dx * math.sin(a) + dy * math.cos(a)
                w = 2.8 - t * 0.1
                if 3 <= t <= 14 and -w <= s <= w * 0.6:
                    px(fr, x, y, STEEL if s < 0 else MID)
    outline(fr)
    disc(fr, 16, 16, 3.5, INK)
    disc(fr, 16, 16, 2.5, HEAT if f % 2 == 0 else HEAT_D)
    im.paste(fr, (f * 32, 0))
save(im, 'ix_turbine_rotor_4f.png')

# --- Pipes & nozzle ------------------------------------------------------------------------
im = img(8, 8)   # vertical pipe tile
rect(im, 1, 0, 6, 7, MID)
rect(im, 0, 0, 0, 7, INK)
rect(im, 7, 0, 7, 7, INK)
rect(im, 2, 0, 2, 7, STEEL)
rect(im, 5, 0, 5, 7, SLATE2)
save(im, 'ix_pipe_v.png')

im = img(16, 16)  # nozzle pointing down with a valve wheel
box(im, 3, 0, 12, 5, MID, top=STEEL)
rect(im, 5, 6, 10, 11, MID)
rect(im, 4, 6, 4, 11, INK)
rect(im, 11, 6, 11, 11, INK)
rect(im, 6, 6, 6, 11, STEEL)
box(im, 3, 11, 12, 14, SLATE2)
rect(im, 6, 14, 9, 15, INK)
rect(im, 7, 14, 8, 14, DARK)
save(im, 'ix_nozzle.png')

im = img(14 * 2, 14)  # valve wheel, 2 frames
for f in range(2):
    fr = img(14, 14)
    disc(fr, 7, 7, 6.5, INK)
    disc(fr, 7, 7, 5.5, HEAT if f == 0 else GOAL)
    disc(fr, 7, 7, 3.5, INK)
    disc(fr, 7, 7, 1.5, STEEL)
    for a in (0, 90, 180, 270):
        r = math.radians(a + f * 45)
        line(fr, 7, 7, 7 + math.cos(r) * 5, 7 + math.sin(r) * 5, STEEL)
    im.paste(fr, (f * 14, 0))
save(im, 'ix_valve_wheel_2f.png')

# --- Lever ------------------------------------------------------------------------------------
im = img(16, 8)
box(im, 0, 2, 15, 7, SLATE, top=MID)
rect(im, 6, 0, 9, 2, INK)
rect(im, 7, 1, 8, 2, STEEL)
save(im, 'ix_lever_base.png')

im = img(6, 18)
rect(im, 2, 4, 3, 17, STEEL)
rect(im, 1, 4, 1, 17, INK)
rect(im, 4, 4, 4, 17, INK)
disc(im, 3, 3, 3, INK)
disc(im, 3, 3, 2, HEAT)
px(im, 2, 2, hexc('ffb08a'))
save(im, 'ix_lever_handle.png')

# --- Steam vent grill ---------------------------------------------------------------------
im = img(32, 8)
box(im, 0, 0, 31, 7, SLATE, top=MID)
for x in range(3, 29, 4):
    rect(im, x, 2, x + 1, 5, INK)
px(im, 1, 4, STEEL)
px(im, 30, 4, STEEL)
save(im, 'ix_vent_grill.png')

# --- Lamps, chain, hook, sign, glow ------------------------------------------------------------
im = img(16, 10)
for y in range(10):
    half = 3 + y * 0.55
    for x in range(16):
        if abs(x + 0.5 - 8) <= half:
            px(im, x, y, MID if y < 8 else STEEL)
rect(im, 6, 0, 9, 1, SLATE)
outline(im)
rect(im, 5, 9, 10, 9, hexc('fff2c0'))
save(im, 'ix_lamp_shade.png')

im = img(64, 64)
for y in range(64):
    for x in range(64):
        d = math.hypot(x + 0.5 - 32, y + 0.5 - 32) / 32
        if d < 1:
            a = (1 - d) ** 2
            a = round(a * 6) / 6  # banded, pixel-art style falloff
            im.putpixel((x, y), (255, 255, 255, int(a * 150)))
save(im, 'ix_glow.png')

im = img(3, 5)
rect(im, 0, 0, 2, 4, INK)
px(im, 1, 1, STEEL)
px(im, 1, 3, MID)
save(im, 'ix_chain_link.png')

im = img(9, 11)
rect(im, 3, 0, 5, 5, STEEL)
line(im, 4, 5, 4, 8, STEEL)
line(im, 4, 8, 6, 10, STEEL)
line(im, 6, 10, 8, 8, STEEL)
line(im, 4, 8, 2, 9, STEEL)
outline(im)
save(im, 'ix_hook.png')

im = img(28, 14)  # hanging "EXIT"-style arrow sign
box(im, 0, 0, 27, 13, hexc('12301f'), top=GOAL_D)
for (x, y) in [(6, 6), (7, 5), (7, 7), (8, 4), (8, 8)]:
    px(im, x, y, GOAL)
rect(im, 7, 6, 21, 6, GOAL)
rect(im, 20, 4, 21, 8, GOAL)
px(im, 2, 2, STEEL)
px(im, 25, 2, STEEL)
save(im, 'ix_sign_arrow.png')

# --- Debris -------------------------------------------------------------------------------------
for i, (w, h) in enumerate([(7, 5), (6, 6), (8, 4)]):
    im = img(w, h)
    rect(im, 0, 0, w - 1, h - 1, PAPER)
    rect(im, 0, h - 1, w - 1, h - 1, PAPER_D)
    for yy in range(1, h - 1, 2):
        rect(im, 1, yy, w - 3, yy, PAPER_D)
    if i == 1:
        px(im, w - 1, 0, T)
    save(im, 'ix_paper_%d.png' % (i + 1))
for i in range(2):
    im = img(6, 4)
    pts = [(1, 1), (2, 1), (3, 1), (0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (2, 3), (3, 3), (4, 1)] if i == 0 else \
          [(1, 0), (2, 1), (3, 1), (1, 1), (2, 2), (3, 2), (4, 2), (4, 3), (5, 3), (0, 1)]
    for p in pts:
        px(im, p[0], p[1], LEAF)
    px(im, 2, 2, LEAF_D)
    px(im, 3, 2, LEAF_D)
    save(im, 'ix_leaf_%d.png' % (i + 1))

# --- Flasks & shelf --------------------------------------------------------------------------
def flask(kind, liquid, liquid_hi):
    if kind == 0:   # erlenmeyer
        im = img(10, 13)
        for y in range(13):
            if y < 4:
                hw = 1.5
            else:
                hw = 1.5 + (y - 4) * 0.42
            for x in range(10):
                if abs(x + 0.5 - 5) <= hw:
                    px(im, x, y, liquid if y >= 7 else hexc('bcd6ea', 110))
        rect(im, 3, 0, 6, 0, STEEL)
    elif kind == 1:  # round bottom
        im = img(10, 12)
        rect(im, 4, 0, 5, 4, hexc('bcd6ea', 110))
        disc(im, 5, 7.5, 4.4, hexc('bcd6ea', 110))
        for y in range(7, 12):
            for x in range(10):
                if im.getpixel((x, y))[3] > 0:
                    px(im, x, y, liquid)
        rect(im, 3, 0, 6, 0, STEEL)
    else:            # test tube / beaker
        im = img(7, 13)
        rect(im, 1, 0, 5, 12, hexc('bcd6ea', 110))
        rect(im, 1, 5, 5, 12, liquid)
        rect(im, 0, 0, 6, 0, STEEL)
    outline(im)
    # liquid surface highlight + glass shine
    for y in range(im.height):
        row = [x for x in range(im.width) if im.getpixel((x, y)) == liquid]
        if row:
            for x in row:
                px(im, x, y, liquid_hi)
            break
    for y in range(2, im.height - 2):
        for x in range(im.width):
            c = im.getpixel((x, y))
            if c[3] > 0 and c != INK:
                px(im, x, y, WHITE if y % 5 != 0 else c)
                break
    return im

save(flask(0, GOAL_D, GOAL), 'ix_flask_1.png')
save(flask(1, HEAT_D, HEAT), 'ix_flask_2.png')
save(flask(2, hexc('3a86b8'), FROST), 'ix_flask_3.png')

im = img(16, 5)
box(im, 0, 0, 15, 4, hexc('6e5c48'), top=hexc('a8927a'))
px(im, 4, 3, hexc('3f3428'))
px(im, 11, 2, hexc('3f3428'))
save(im, 'ix_shelf_plank.png')

im = img(6, 8)
line(im, 0, 0, 0, 7, MID)
line(im, 1, 0, 5, 0, MID)
line(im, 1, 5, 5, 0, MID)
outline(im)
save(im, 'ix_shelf_bracket.png')

# --- Fixtures: wall lamp, tube lamp -----------------------------------------------------------
im = img(12, 10)
box(im, 0, 0, 11, 4, SLATE, top=MID)
for y in range(5, 10):
    hw = 5 - (y - 5) * 0.6
    for x in range(12):
        if abs(x + 0.5 - 6) <= hw:
            px(im, x, y, hexc('fff2c0'))
outline(im)
save(im, 'ix_wall_lamp.png')

im = img(36, 7)
box(im, 0, 0, 35, 3, SLATE, top=MID)
rect(im, 2, 4, 33, 6, INK)
rect(im, 3, 4, 32, 5, hexc('e8f6ff'))
save(im, 'ix_tube_lamp.png')

# --- Sparks -------------------------------------------------------------------------------------
im = img(5 * 2, 5)
for (x, y) in [(2, 0), (2, 1), (0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (2, 3), (2, 4)]:
    px(im, x, y, hexc('ffe9a0'))
px(im, 2, 2, WHITE)
for (x, y) in [(5 + 1, 1), (5 + 3, 1), (5 + 2, 2), (5 + 1, 3), (5 + 3, 3)]:
    px(im, x, y, hexc('ffd35a'))
save(im, 'ix_spark_2f.png')

im = img(8, 6)  # cable clamp on the ceiling
box(im, 0, 0, 7, 3, SLATE, top=MID)
rect(im, 3, 4, 4, 5, INK)
save(im, 'ix_clamp.png')

# --- Security camera + monitor ------------------------------------------------------------------
im = img(20, 11)  # head, pivot at (4, 5), lens to the right
box(im, 0, 1, 15, 9, MID, top=STEEL)
rect(im, 1, 8, 14, 8, SLATE)
box(im, 15, 2, 19, 8, SLATE)
rect(im, 17, 4, 18, 6, INK)
px(im, 17, 4, FROST)
rect(im, 3, 3, 10, 3, SLATE2)
save(im, 'ix_camera_head.png')

im = img(10, 12)
box(im, 0, 0, 9, 4, SLATE, top=MID)
rect(im, 4, 5, 5, 11, INK)
rect(im, 4, 5, 4, 10, STEEL)
save(im, 'ix_camera_mount.png')

im = img(30, 24)
box(im, 0, 0, 29, 19, SLATE2, top=MID)
rect(im, 2, 2, 27, 16, INK)
rect(im, 12, 20, 17, 22, SLATE)
rect(im, 8, 22, 21, 23, INK)
rect(im, 9, 22, 20, 22, MID)
px(im, 26, 18, GOAL)
save(im, 'ix_monitor.png')

# --- Basin rim -------------------------------------------------------------------------------
im = img(6, 16)  # vertical glass wall tile
rect(im, 0, 0, 5, 15, INK)
rect(im, 1, 0, 4, 15, hexc('5d7b93'))
rect(im, 2, 0, 3, 15, hexc('9ebcdb', 120))
save(im, 'ix_basin_wall.png')

im = img(16, 6)  # basin floor/lip tile
box(im, 0, 0, 15, 5, SLATE, top=MID)
px(im, 7, 3, STEEL)
save(im, 'ix_basin_lip.png')

print('ok')
