"""Writes levels/dressing/level_XX_dressing.tscn from each level's Blocks/Zones
(python -I tools/art/gen_dressing.py [level numbers...]).

Purely visual: no collision anywhere. Re-running overwrites the dressing files,
so hand edits should go into the generator (THEMES) or be made after the last run.

Layer stack inside Dressing (drawn before Blocks):
  Deep       Parallax2D 0.12  another wing's skyline, half dissolved in fog
  Far        Parallax2D 0.25  tiling silhouette backdrop + ceiling band
  Mid        Parallax2D 0.5   tiling machinery strip, extra animated bits
  BackWall   world            pipes / cables / signs / lamps on the back wall
  Room       world            floor props (tanks, racks, desks...)
  Lights     world            additive glows (heat, frost, goal, beacons)
  Edges      z 1              trims, grime, hazard stripes, frost, scorch on walls
  Foreground Parallax2D 1.3x  sparse near-black silhouettes, z 10
"""
import os, sys, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from levelparse import parse_level, ROOT  # noqa
from footprints import FOOT  # noqa
from tscn import Scene, v2, col, rect2  # noqa

G = 16
VIEW_W, VIEW_H = 960, 540
DEEP_S, FAR_S, MID_S = 0.12, 0.25, 0.5
FAR_H, MID_H, CEIL_FAR_H, CEIL_MID_H = 640, 512, 128, 160

# sign atlas frames
HAZ, CRYO, HOT, EXIT, ARROW, BIO, VOLT, LAB1, B07, F12, RX0, WIND = range(12)

LAMP_WARM = col(1, 0.88, 0.65, 0.15)
LAMP_COLD = col(0.6, 0.85, 1, 0.15)
LAMP_GREEN = col(0.55, 1, 0.75, 0.13)
LAMP_RED = col(1, 0.5, 0.35, 0.15)

THEMES = {
    1: dict(wing="lab", grime=0, lamp=LAMP_WARM, signs=[LAB1, BIO, ARROW], tint=col(1, 1, 1),
            floor={"tank_specimen": 4, "terminal": 3, "lab_desk": 3, "shelf_jars": 2, "server_rack": 1, "tank_plain": 1},
            wall={"whiteboard": 2, "poster": 2, "sign": 3, "monitor_wall": 1, "vent": 2, "wall_panel": 1}),
    2: dict(wing="lab", grime=4, lamp=LAMP_COLD, signs=[CRYO, CRYO, HAZ, LAB1], tint=col(0.85, 0.95, 1.1), frost=True,
            floor={"tank_plain": 3, "tank_big": 2, "terminal": 2, "server_rack": 2, "locker": 2, "barrel": 1},
            wall={"sign": 4, "poster": 2, "vent": 2, "monitor_wall": 1, "gauge": 1, "wall_panel": 1}),
    3: dict(wing="lab", grime=0, lamp=LAMP_WARM, signs=[ARROW, LAB1, HAZ], tint=col(0.95, 1, 1.05), shaft=True,
            floor={"tank_big": 2, "tank_specimen": 2, "server_rack": 3, "lab_desk": 1, "terminal": 2},
            wall={"vent": 3, "sign": 2, "monitor_wall": 1, "wall_fan": 1, "wall_panel": 2}),
    4: dict(wing="storage", grime=1, lamp=LAMP_WARM, signs=[B07, HAZ, ARROW], tint=col(1, 1, 1), chains=True,
            floor={"crate": 5, "crate_small": 2, "barrel": 3, "shelf_jars": 2, "locker": 2},
            wall={"sign": 3, "wall_panel": 2, "vent": 1, "poster": 1}),
    5: dict(wing="storage", grime=2, lamp=LAMP_WARM, signs=[HAZ, HOT, CRYO, B07], tint=col(1.05, 1, 0.95), gauges=True,
            floor={"tank_big": 2, "barrel": 3, "crate": 2, "boiler": 1, "server_rack": 1},
            wall={"gauge": 3, "valve": 2, "sign": 2, "wall_panel": 1, "vent": 1}),
    6: dict(wing="storage", grime=1, lamp=LAMP_COLD, signs=[WIND, HAZ, WIND], tint=col(0.95, 1, 1.05), fans=True,
            floor={"crate": 3, "barrel": 2, "locker": 1, "server_rack": 1},
            wall={"wall_fan": 3, "vent": 3, "sign": 2, "wall_panel": 1}),
    7: dict(wing="plant", grime=2, lamp=LAMP_GREEN, signs=[F12, HAZ, BIO], tint=col(1, 1, 1), drippy=True,
            floor={"tank_algae": 3, "tank_plain": 2, "barrel": 2, "server_rack": 1},
            wall={"gauge": 2, "valve": 2, "sign": 2, "vent": 2, "wall_panel": 1}),
    8: dict(wing="plant", grime=1, lamp=LAMP_GREEN, signs=[F12, HAZ, ARROW], tint=col(0.95, 1.05, 1), shaft=True, chains=True,
            floor={"tank_algae": 2, "tank_big": 2, "barrel": 2, "crate": 1},
            wall={"gauge": 2, "valve": 2, "sign": 2, "vent": 2, "wall_panel": 1}),
    9: dict(wing="plant", grime=2, lamp=LAMP_WARM, signs=[HOT, CRYO, HAZ], tint=col(1.05, 1, 0.95), steamy=True,
            floor={"boiler": 3, "tank_hot": 2, "tank_algae": 1, "barrel": 1},
            wall={"gauge": 3, "valve": 2, "sign": 2, "vent": 1}),
    10: dict(wing="reactor", grime=3, lamp=LAMP_RED, signs=[RX0, VOLT, HAZ], tint=col(1, 1, 1), sparky=True,
             floor={"coil": 3, "server_rack": 2, "terminal_amber": 2, "boiler": 1},
             wall={"sign": 3, "monitor_wall": 1, "gauge": 2, "wall_panel": 2, "vent": 1}),
    11: dict(wing="reactor", grime=3, lamp=LAMP_RED, signs=[HOT, RX0, HAZ], tint=col(1.05, 0.95, 0.95), shaft=True, steamy=True,
             floor={"boiler": 2, "coil": 1, "barrel": 2, "tank_hot": 1},
             wall={"vent": 3, "gauge": 2, "sign": 2, "wall_panel": 1}),
    12: dict(wing="reactor", grime=3, lamp=LAMP_RED, signs=[VOLT, HAZ, RX0, HOT], tint=col(1.1, 0.95, 0.9), sparky=True, steamy=True,
             floor={"coil": 3, "tank_hot": 2, "terminal_amber": 1, "server_rack": 2, "boiler": 1},
             wall={"sign": 3, "monitor_wall": 1, "gauge": 2, "wall_panel": 1, "vent": 1}),
}

FRAMES = {"crate": 2, "barrel": 3, "shelf_jars": 3, "locker": 2, "poster": 2, "wall_panel": 2}


class Grid:
    def __init__(self, L):
        self.x0, self.y0, self.x1, self.y1 = [int(v) for v in L["bounds"]]
        self.nx = (self.x1 - self.x0) // G
        self.ny = (self.y1 - self.y0) // G
        self.c = [[None] * self.nx for _ in range(self.ny)]
        for b in L["blocks"]:
            for cy in range(int(b["y"] - self.y0) // G, int(b["y"] + b["h"] - self.y0) // G):
                for cx in range(int(b["x"] - self.x0) // G, int(b["x"] + b["w"] - self.x0) // G):
                    if 0 <= cx < self.nx and 0 <= cy < self.ny:
                        self.c[cy][cx] = b["kind"]

    def at(self, x, y):
        cx, cy = int((x - self.x0) // G), int((y - self.y0) // G)
        if cx < 0 or cy < 0 or cx >= self.nx or cy >= self.ny:
            return "wall"
        return self.c[cy][cx]

    def air(self, x, y, w, h):
        xx = x
        while xx < x + w:
            yy = y
            while yy < y + h:
                if self.at(xx, yy) is not None:
                    return False
                yy += G
            if self.at(xx, y + h - 1) is not None:
                return False
            xx += G
        return self.at(x + w - 1, y) is None and self.at(x + w - 1, y + h - 1) is None

    def solid(self, x, y, w, h, kinds=("wall",)):
        xx = x
        while xx < x + w:
            yy = y
            while yy < y + h:
                if self.at(xx, yy) not in kinds:
                    return False
                yy += G
            xx += G
        return self.at(x + w - 1, y + h - 1) in kinds

    def runs(self, face):
        """Surface runs: list of (x_start, x_end, y) for 'top' / 'bottom' faces of WALL cells."""
        out = []
        for cy in range(self.ny):
            cur = None
            for cx in range(self.nx + 1):
                ok = False
                if cx < self.nx and self.c[cy][cx] == "wall":
                    ny = cy - 1 if face == "top" else cy + 1
                    ok = 0 <= ny < self.ny and self.c[ny][cx] is None
                if ok and cur is None:
                    cur = cx
                elif not ok and cur is not None:
                    y = self.y0 + (cy * G if face == "top" else (cy + 1) * G)
                    out.append((self.x0 + cur * G, self.x0 + cx * G, y))
                    cur = None
        return out

    def vruns(self, face):
        """Side faces: (x, y_start, y_end); face 'left' = wall whose left neighbour is air."""
        out = []
        for cx in range(self.nx):
            cur = None
            for cy in range(self.ny + 1):
                ok = False
                if cy < self.ny and self.c[cy][cx] == "wall":
                    nx = cx - 1 if face == "left" else cx + 1
                    ok = 0 <= nx < self.nx and self.c[cy][nx] is None
                if ok and cur is None:
                    cur = cy
                elif not ok and cur is not None:
                    x = self.x0 + (cx * G if face == "left" else (cx + 1) * G)
                    out.append((x, self.y0 + cur * G, self.y0 + cy * G))
                    cur = None
        return out

    def clearance_up(self, x, y):
        """Air height above floor point (x, y)."""
        h = 0
        while self.at(x, y - h - 1) is None and h < 2000:
            h += G
        return h

    def clearance_down(self, x, y):
        h = 0
        while self.at(x, y + h) is None and h < 2000:
            h += G
        return h


def overlaps(r, rects, m=0):
    x, y, w, h = r
    for (a, b, c, d) in rects:
        if x < a + c + m and x + w + m > a and y < b + d + m and y + h + m > b:
            return True
    return False


class Builder:
    def __init__(self, n):
        self.n = n
        self.L = parse_level(n)
        self.T = THEMES[n]
        self.g = Grid(self.L)
        self.rnd = random.Random(1000 + n)
        self.sc = Scene()
        self.items = {k: [] for k in ("Deep", "Far", "Mid", "BackWall", "Room", "Lights", "Edges", "FX", "Foreground")}
        self.names = {}
        z = self.L["zones"]
        # strict keep-outs (props never sit in front of these)
        self.hard = [(q["x"], q["y"], q["w"], q["h"]) for q in z if q["kind"] not in ("fan", "goal")]
        self.hard += [(q["x"] - 28, q["y"] - 28, q["w"] + 56, q["h"] + 28) for q in z if q["kind"] == "goal"]
        self.hard += [(h["x"] - 8, h["y"] - 8, h["w"] + 16, h["h"] + 16) for h in self.L["hints"]]
        self.hard += [(i["x"], i["y"], i["w"], i["h"]) for i in self.L["interactive"]]
        if self.L["player"]:
            px_, py_ = self.L["player"]
            self.hard.append((px_ - 40, py_ - 40, 80, 64))  # keep the spawn clear for readability
        self.used_floor = []
        self.used_wall = []

    # ------------------------------------------------------------ helpers
    def add(self, layer, scene, x, y, **props):
        base = scene.split("/")[-1]
        k = self.names.get(base, 0) + 1
        self.names[base] = k
        self.items[layer].append((scene, "%s%d" % ("".join(w.capitalize() for w in base.split("_")), k), x, y, props))

    def pick(self, weights):
        tot = sum(weights.values())
        r = self.rnd.random() * tot
        for k, w in weights.items():
            r -= w
            if r <= 0:
                return k
        return k

    def free(self, r, used, margin=6):
        return not overlaps(r, self.hard, 10) and not overlaps(r, used, margin)

    # ------------------------------------------------------------ parallax
    def cam_range(self):
        x0, y0, x1, y1 = self.L["bounds"]
        tl = (x0, y0)
        br = (max(x0, x1 - VIEW_W), max(y0, y1 - VIEW_H))
        return tl, br

    def backdrops(self):
        wing = self.T["wing"]
        (tx0, ty0), (tx1, ty1) = self.cam_range()
        r = self.rnd
        # DEEP: another wing's skyline, nearly dissolved into the fog, peeking above the far layer
        other = {"lab": "plant", "storage": "lab", "plant": "reactor", "reactor": "storage"}[wing]
        dy = ty1 * DEEP_S + VIEW_H - FAR_H + 30
        self.add("Deep", "@sprite:backdrops/far_%s" % other, r.randrange(1024), dy)
        # FAR: bottom of the strip meets the bottom of the screen when the camera is lowest
        fy = ty1 * FAR_S + VIEW_H - FAR_H + 24
        self.add("Far", "@sprite:backdrops/far_%s" % wing, r.randrange(1024), fy)
        self.add("Far", "@sprite:backdrops/ceiling_far", r.randrange(1024), ty0 * FAR_S + 36)
        # MID
        my = ty1 * MID_S + VIEW_H - MID_H + 12
        self.add("Mid", "@sprite:backdrops/mid_%s" % wing, r.randrange(1024), my)
        self.add("Mid", "@sprite:backdrops/ceiling_mid", r.randrange(1024), ty0 * MID_S + 40)
        span_top = ty0 * MID_S + 40 + CEIL_MID_H - 20
        if my - span_top > 64:
            # tall level: vertical mid pipes bridge the ceiling band and the machinery strip
            for k in range(3):
                self.add("Mid", "pipe_v", 120 + k * 340 + r.randrange(60), span_top,
                         length=int(my - span_top + 40), modulate=col(0.32, 0.36, 0.45))
            for k in range(2):
                self.add("Mid", "girder", 0 + k * 512, int(span_top + (my - span_top) * (0.35 + 0.3 * k)),
                         length=512, modulate=col(0.22, 0.26, 0.34, 0.6))
        for k in range(5):
            self.add("Mid", "glow", r.randrange(1024), my + r.randrange(200, MID_H - 40),
                     modulate=col(1, 0.35, 0.25, 0.5) if k % 2 else col(0.5, 1, 0.7, 0.45), scale=v2(0.2, 0.2))
        if self.T.get("fans"):
            for k in range(2):
                self.add("Mid", "big_fan", 260 + k * 512, my + 150 + k * 40, modulate=col(0.45, 0.5, 0.6))
        # a few slow far blinkers (aircraft-warning style lights on the far towers)
        acc = {"lab": col(0.5, 0.9, 1, 0.5), "storage": col(1, 0.75, 0.4, 0.5), "plant": col(0.5, 1, 0.75, 0.5),
               "reactor": col(1, 0.4, 0.2, 0.6)}[wing]
        for k in range(3):
            self.add("Far", "glow", r.randrange(1024), fy + r.randrange(120, 320), modulate=acc, scale=v2(0.25, 0.25))

    def foreground(self):
        x0, y0, x1, y1 = [int(v) for v in self.L["bounds"]]
        (tx0, _), (tx1, _) = self.cam_range()
        s = 1.3
        p0 = tx0 * s
        p1 = tx1 * s + VIEW_W
        # thickness of the bottom/top shells (so silhouettes stay inside wall mass)
        bot = min(self.g.clearance_up(x, y1) for x in range(x0 + 8, x1, G)) if False else None
        floor_th = 9999
        ceil_th = 9999
        for x in range(x0 + 8, x1 - 8, G):
            t = 0
            while self.g.at(x, y1 - 1 - t) is not None and t < 2000:
                t += G
            floor_th = min(floor_th, t)
            t = 0
            while self.g.at(x, y0 + t) is not None and t < 2000:
                t += G
            ceil_th = min(ceil_th, t)
        r = self.rnd
        x = p0 + r.randrange(80, 260)
        i = 0
        while x < p1:
            if i % 2 == 0:
                vis = max(16, min(72, floor_th - 6))
                self.add("Foreground", "fg_machine", x, y1 + 72 - vis, frame=r.randrange(2))
            else:
                self.add("Foreground", "fg_cables", x - 96, y0 + max(0, ceil_th - 44), flip_h=r.random() < 0.5)
            x += r.randrange(420, 700)
            i += 1

    # ------------------------------------------------------------ edges on walls
    def edges(self):
        T, g, r = self.T, self.g, self.rnd
        zones = self.L["zones"]
        spikes = [q for q in zones if q["kind"] == "spikes"]
        for (xa, xb, y) in g.runs("top"):
            # split around spike zones sitting on this floor -> hazard stripes there
            segs = [(xa, xb, False)]
            for q in spikes:
                if abs(q["y"] + q["h"] - y) <= 8:
                    ns = []
                    for (a, b, hz) in segs:
                        if hz or q["x"] >= b or q["x"] + q["w"] <= a:
                            ns.append((a, b, hz))
                            continue
                        qa, qb = max(a, int(q["x"])), min(b, int(q["x"] + q["w"]))
                        if qa > a:
                            ns.append((a, qa, False))
                        ns.append((qa, qb, True))
                        if qb < b:
                            ns.append((qb, b, False))
                    segs = ns
            for (a, b, hz) in segs:
                if b - a < 8:
                    continue
                if hz:
                    if g.solid(a, y, b - a, 16):
                        self.add("Edges", "hazard_strip", a, y + 3, length=b - a)
                else:
                    self.add("Edges", "grime_strip", a, y + 3, length=b - a, row=T["grime"])
        for (xa, xb, y) in g.runs("bottom"):
            if xb - xa >= 48 and g.solid(xa, y - 16, xb - xa, 16):
                self.add("Edges", "trim", xa, y - 10, length=xb - xa)
        # freeze zones: icicles under the ceiling they hang from + frost patches
        for q in zones:
            if q["kind"] == "freeze_zone":
                for (xa, xb, y) in g.runs("bottom"):
                    a, b = max(xa, int(q["x"]) - 32), min(xb, int(q["x"] + q["w"]) + 32)
                    if b - a > 16 and q["y"] - 8 <= y <= q["y"] + q["h"]:
                        # frost crust on the ceiling's face (flipped so it grows up into the wall)
                        self.add("Edges", "grime_strip", a, y, length=b - a, row=4, scale=v2(1, -1), modulate=col(1, 1, 1, 0.55))
                        za, zb = int(q["x"]), int(q["x"] + q["w"])
                        for (fa, fb) in ((a, min(b, za)), (max(a, zb), b)):
                            if fb - fa >= 8 and not overlaps((fa, y, fb - fa, 16), self.hard, 0):
                                self.add("Edges", "grime_strip", fa, y, length=fb - fa, row=4)
                for (x, ya, yb) in g.vruns("left") + g.vruns("right"):
                    if q["x"] - 24 <= x <= q["x"] + q["w"] + 24 and ya < q["y"] + q["h"] and yb > q["y"]:
                        yy = max(ya, int(q["y"])) + 24
                        self.add("Edges", "frost_patch", x + (-10 if x > q["x"] else 10), yy)
            if q["kind"] == "heat_zone":
                by = q["y"] + q["h"]
                if g.at(q["x"] + q["w"] / 2, by + 2) == "wall":
                    self.add("Edges", "scorch", int(q["x"] + q["w"] / 2), int(by + 10), scale=v2(max(1.0, q["w"] / 56.0), 1))
                for (x, ya, yb) in g.vruns("left") + g.vruns("right"):
                    if abs(x - q["x"]) <= 8 or abs(x - (q["x"] + q["w"])) <= 8:
                        if ya < by and yb > q["y"]:
                            self.add("Edges", "scorch", x + (8 if abs(x - q["x"]) <= 8 else -8), int(min(by, yb) - 24),
                                     rotation=1.5708, scale=v2(0.8, 0.8))
        # big wall masses: stencil label, conduit, access panels, cracks
        label_done = 0
        for b in sorted(self.L["blocks"], key=lambda b: -b["w"] * b["h"]):
            if b["kind"] != "wall":
                continue
            ix, iy, iw, ih = int(b["x"]) + 24, int(b["y"]) + 24, int(b["w"]) - 48, int(b["h"]) - 48
            if iw < 96 or ih < 48:
                continue
            if not g.solid(ix, iy, iw, ih):
                continue
            onscreen_y = iy  # prefer the band right under the walkable top
            if label_done < 2 and iw >= 160:
                lx = ix + r.randrange(0, max(1, iw - 120)) + 32
                if not overlaps((lx - 30, onscreen_y, 60, 20), [(z["x"], z["y"], z["w"], z["h"]) for z in zones]):
                    self.add("Edges", "wall_label", lx, onscreen_y + 6, frame=self.n - 1, modulate=col(1, 1, 1, 0.8))
                    label_done += 1
            if ih >= 64 and iw >= 192:
                py = iy + 24 + r.randrange(0, max(1, min(ih - 40, 64)))
                self.add("Edges", "pipe_h_thin", ix, py, length=iw, modulate=col(1.15, 1.2, 1.25))
                for k in range(iw // 220):
                    self.add("Edges", "valve", ix + 80 + k * 220 + r.randrange(40), py + 3)
            if ih >= 160 and r.random() < 0.7:
                cx_ = ix + r.randrange(iw)
                L = int(ih * r.uniform(0.4, 0.9))
                self.add("Edges", "pipe_v_thin", cx_, iy - 8, length=L, modulate=col(1.15, 1.2, 1.25))
            for k in range(1, ih // 180 + 1):
                if iw >= 160:
                    self.add("Edges", "trim", ix - 16, iy - 24 + k * 180, length=iw + 32, modulate=col(1, 1, 1, 0.75))
            for k in range(max(1, iw * ih // 30000)):
                px_ = ix + r.randrange(iw)
                py_ = iy + r.randrange(ih)
                kind = r.random()
                if kind < 0.15:
                    self.add("Edges", "vent", px_, py_, modulate=col(1.3, 1.35, 1.4))
                elif kind < 0.4:
                    self.add("Edges", "wall_panel", px_, py_, frame=r.randrange(2), modulate=col(1, 1, 1, 0.9))
                elif kind < 0.7:
                    self.add("Edges", "wall_crack", px_, py_, frame=r.randrange(3))
                elif T["grime"] in (1, 2):
                    self.add("Edges", "moss_patch" if T["grime"] == 1 else "rust_drip", px_, py_, frame=0)
        # cracks around breakables
        for b in self.L["blocks"]:
            if b["kind"] == "breakable":
                for (x, ya, yb) in g.vruns("left") + g.vruns("right"):
                    if (abs(x - b["x"]) <= 2 or abs(x - (b["x"] + b["w"])) <= 2) and ya <= b["y"] <= yb:
                        self.add("Edges", "wall_crack", x + (-12 if abs(x - b["x"]) <= 2 else 12), int(b["y"] + 14), frame=r.randrange(3))

    # ------------------------------------------------------------ back wall
    def backwall(self):
        T, g, r = self.T, self.g, self.rnd
        L = self.L
        x0, y0, x1, y1 = [int(v) for v in L["bounds"]]
        # ceiling furniture
        for (xa, xb, y) in g.runs("bottom"):
            if xb - xa < 64:
                continue
            below = lambda x: g.clearance_down(x, y)
            # thin conduit right under the ceiling
            if xb - xa >= 128 and r.random() < 0.8:
                self.add("BackWall", "pipe_h_thin", xa, y + 4, length=xb - xa, modulate=col(0.85, 0.9, 1))
            x = xa + r.randrange(40, 120)
            while x < xb - 40:
                c = below(x)
                rr = r.random()
                hz = overlaps((x - 50, y, 100, 170), self.hard, 0)
                if c >= 160 and rr < 0.45 and not hz:
                    self.add("BackWall", "lamp", x, y, modulate=col(1, 1, 1))
                    self.used_wall.append((x - 14, y, 28, 150))
                    x += r.randrange(180, 300)
                    continue
                if c >= 120 and rr < 0.6:
                    w = r.choice([64, 128, 192])
                    if x + w < xb and all(below(xx) >= 64 for xx in range(x, x + w, G)):
                        self.add("BackWall", "cable_droop_%d" % w, x, y + 2)
                        x += w + r.randrange(40, 120)
                        continue
                if c >= 128 and rr < 0.8:
                    if T.get("chains") and r.random() < 0.6:
                        self.add("BackWall", r.choice(["chain", "chain_long"]), x, y)
                    else:
                        self.add("BackWall", r.choice(["cable_hang", "cable_hang_long"]), x, y)
                        if T.get("sparky") and r.random() < 0.6:
                            self.add("FX", "sparks", x + 2, y + 50)
                x += r.randrange(50, 140)
            # rust stains under ceilings
            if T["grime"] in (2, 3):
                for k in range((xb - xa) // 260):
                    xx = xa + r.randrange(xb - xa)
                    if below(xx) >= 64:
                        self.add("BackWall", "rust_drip", xx, y + 2, frame=r.randrange(2),
                                 modulate=col(0.4, 0.4, 0.4, 0.7) if T["grime"] == 3 else col(1, 1, 1, 0.6))
        # vertical conduits hugging wall sides
        for face in ("left", "right"):
            for (x, ya, yb) in g.vruns(face):
                if yb - ya < 128 or r.random() < 0.45:
                    continue
                px_ = x - 12 if face == "left" else x + 4
                if g.air(px_, ya, 8, yb - ya) and not overlaps((px_, ya, 8, yb - ya), self.hard, 4):
                    self.add("BackWall", "pipe_v_thin", px_, ya, length=yb - ya, modulate=col(0.8, 0.85, 0.95))
                    if yb - ya > 200 and r.random() < 0.5:
                        self.add("BackWall", "gauge", px_ + 3, ya + r.randrange(48, yb - ya - 48))
        # free-standing vertical pipes / ladders in tall open columns
        cols = 0
        tries = 0
        n_cols = 4 if T.get("shaft") else 2
        while cols < n_cols and tries < 80:
            tries += 1
            x = (r.randrange(x0 + 48, x1 - 48) // 8) * 8
            # find a vertical air span from a ceiling to a floor
            y = y0 + 8
            while y < y1 and g.at(x, y) is not None:
                y += G
            ytop = y - (y - y0) % G if False else y
            ytop = ((ytop - y0) // G) * G + y0
            h = g.clearance_down(x, ytop)
            if h < 192:
                continue
            for xx in (x, x + 15):
                if g.clearance_down(xx, ytop) < h:
                    h = 0
            if h < 192:
                continue
            rr = (x, ytop, 16, h)
            if overlaps(rr, [q for q in self.hard], 12) or overlaps(rr, self.used_wall, 24):
                continue
            kind = "pipe_v" if (r.random() < 0.7 or not T.get("shaft")) else "ladder"
            self.add("BackWall", kind, x, ytop, length=h, modulate=col(0.62, 0.68, 0.8))
            self.used_wall.append(rr)
            cols += 1

        # wall-mounted props above floors
        for (xa, xb, y) in g.runs("top"):
            x = xa + r.randrange(24, 96)
            while x < xb - 24:
                k = self.pick(T["wall"])
                fw, fh, _ = FOOT[k]
                hy = y - r.randrange(60, 150)
                rect = (x - fw // 2 - 4, hy - fh // 2 - 4, fw + 8, fh + 8)
                if g.air(*rect) and self.free(rect, self.used_wall) and g.clearance_up(x, y) > (y - hy) + fh:
                    props = {}
                    if k == "sign":
                        props["frame"] = r.choice(T["signs"])
                    elif k in FRAMES:
                        props["frame"] = r.randrange(FRAMES[k])
                    self.add("BackWall", k, x, hy, **props)
                    self.used_wall.append(rect)
                    x += fw + r.randrange(40, 130)
                else:
                    x += 40

    # ------------------------------------------------------------ floor props
    def room(self):
        T, g, r = self.T, self.g, self.rnd
        for (xa, xb, y) in g.runs("top"):
            if xb - xa < 96:
                continue  # narrow pillar tops stay clean
            x = xa + r.randrange(16, 64)
            while x < xb - 16:
                k = self.pick(T["floor"])
                fw, fh, _ = FOOT[k]
                rect = (x - fw // 2, y - fh, fw, fh)
                head = min(g.clearance_up(xx, y) for xx in (x - fw // 2, x, x + fw // 2 - 1))
                ok = (x - fw // 2 >= xa and x + fw // 2 <= xb and g.air(*rect) and head >= fh + 40
                      and self.free(rect, self.used_floor, 4))
                if ok:
                    props = {}
                    if k in FRAMES:
                        props["frame"] = r.randrange(FRAMES[k])
                    if k in ("crate", "barrel", "locker", "terminal", "terminal_amber", "lab_desk") and r.random() < 0.4:
                        props["scale"] = v2(-1, 1)
                    self.add("Room", k, x, y, **props)
                    self.used_floor.append(rect)
                    if k == "crate" and r.random() < 0.5 and head > fh + 72:
                        self.add("Room", "crate_small", x + r.randrange(-4, 5), y - fh)
                    if k in ("boiler",) or (T.get("steamy") and k in ("tank_hot",)):
                        self.add("FX", "steam_vent", x + fw // 2 - 6, y - fh + 4)
                    x += fw + r.randrange(16, 96)
                else:
                    x += 24

    def debris(self):
        g, r = self.g, self.rnd
        for (xa, xb, y) in g.runs("top"):
            x = xa + r.randrange(8, 60)
            while x < xb - 24:
                rect = (x, y - 8, 32, 8)
                if g.air(*rect) and not overlaps(rect, self.hard, 6) and r.random() < 0.55:
                    self.add("Room", "floor_debris", x + 16, y, frame=r.randrange(4), scale=v2(r.choice([-1, 1]), 1))
                x += r.randrange(48, 128)

    # ------------------------------------------------------------ lights & zone flavour
    def lights(self):
        g, r, T = self.g, self.rnd, self.T
        for q in self.L["zones"]:
            cx, cy = q["x"] + q["w"] / 2, q["y"] + q["h"] / 2
            if q["kind"] == "heat_zone":
                sc = max(q["w"], q["h"]) / 110.0
                self.add("Lights", "glow_big", int(cx), int(q["y"] + q["h"] - 24), modulate=col(1, 0.4, 0.12, 0.28),
                         scale=v2(sc * 1.1, sc * 0.9))
                for side in (-1, 1):
                    sx = int(cx + side * (q["w"] / 2 + 14))
                    fy = int(q["y"] + q["h"])
                    if g.at(sx, fy + 2) == "wall" and g.air(sx - 8, fy - 24, 16, 20):
                        self.add("FX", "steam_vent", sx, fy - 4)
                # warning sign beside the vent
                sy = int(q["y"] + q["h"] - 80)
                for sx in (int(q["x"] - 30), int(q["x"] + q["w"] + 30)):
                    rect = (sx - 16, sy - 12, 32, 24)
                    if g.air(*rect) and not overlaps(rect, self.hard, 4) and not overlaps(rect, self.used_wall, 2):
                        self.add("BackWall", "sign", sx, sy, frame=HOT)
                        self.used_wall.append(rect)
                        break
            elif q["kind"] == "freeze_zone":
                sc = max(q["w"], q["h"]) / 110.0
                self.add("Lights", "glow_big", int(cx), int(cy), modulate=col(0.45, 0.8, 1, 0.22), scale=v2(sc, sc * 0.8))
            elif q["kind"] == "goal":
                self.add("Lights", "glow_big", int(cx), int(cy), modulate=col(0.4, 1, 0.6, 0.18), scale=v2(1.4, 1.4))
                for ex, ey in ((int(cx), int(q["y"] - 26)), (int(q["x"] - 26), int(cy - 20)), (int(q["x"] + q["w"] + 26), int(cy - 20))):
                    if g.air(ex - 16, ey - 8, 32, 16):
                        self.add("BackWall", "exit_sign", ex, ey)
                        self.add("Lights", "glow", ex, ey, modulate=col(0.4, 1, 0.6, 0.25), scale=v2(1.2, 0.7))
                        self.used_wall.append((ex - 16, ey - 8, 32, 16))
                        break
            elif q["kind"] == "spikes":
                # beacon on the back wall above the start of the spike run
                for bx in (int(q["x"] + 12), int(q["x"] + q["w"] - 12)):
                    by = int(q["y"] - 64)
                    rect = (bx - 8, by - 8, 16, 16)
                    if g.air(*rect) and not overlaps(rect, self.hard, 2) and not overlaps(rect, self.used_wall, 2):
                        self.add("BackWall", "beacon", bx, by)
                        self.used_wall.append(rect)
                        break
            elif q["kind"] == "fan":
                pass
        # drips under grates (water seeps through)
        for b in self.L["blocks"]:
            if b["kind"] == "grate" and b["w"] > b["h"]:
                yb = int(b["y"] + b["h"])
                if g.clearance_down(int(b["x"] + b["w"] / 2), yb) >= 64:
                    self.add("FX", "drips", int(b["x"] + b["w"] / 2), yb + 2,
                             emission_rect_extents=v2(b["w"] / 2 - 6, 1))
        if T.get("drippy"):
            for (xa, xb, y) in g.runs("bottom"):
                for k in range((xb - xa) // 400):
                    x = xa + r.randrange(xb - xa)
                    if g.clearance_down(x, y) >= 96 and not overlaps((x - 8, y, 16, 96), self.hard, 0):
                        self.add("FX", "drips", x, y + 2, emission_rect_extents=v2(2, 1), amount=1)

    # ------------------------------------------------------------ output
    def build(self):
        self.edges()
        self.lights()
        self.backwall()
        self.room()
        self.debris()
        self.backdrops()
        self.foreground()
        return self.write()

    def write(self):
        sc = self.sc
        sc.node("Dressing", "Node2D", None, {})
        layer_props = {
            "Deep": ("Parallax2D", {"modulate": col(0.62, 0.72, 0.85, 0.5), "scroll_scale": v2(DEEP_S, DEEP_S), "repeat_size": v2(1024, 0)}),
            "Far": ("Parallax2D", {"modulate": self.T["tint"], "scroll_scale": v2(FAR_S, FAR_S), "repeat_size": v2(1024, 0)}),
            "Mid": ("Parallax2D", {"scroll_scale": v2(MID_S, MID_S), "repeat_size": v2(1024, 0)}),
            "BackWall": ("Node2D", {"modulate": col(0.78, 0.82, 0.92)}),
            "Room": ("Node2D", {"modulate": col(0.86, 0.9, 0.98)}),
            "Lights": ("Node2D", {}),
            "Edges": ("Node2D", {"z_index": "1"}),
            "FX": ("Node2D", {"z_index": "1"}),
            "Foreground": ("Parallax2D", {"z_index": "10", "scroll_scale": v2(1.3, 1), "modulate": col(1, 1, 1, 0.92)}),
        }
        count = 0
        for layer, (typ, props) in layer_props.items():
            sc.node(layer, typ, ".", props)
            for scene, name, x, y, p in self.items[layer]:
                p = dict(p)
                p.pop("_lamp", None)
                out = {"position": v2(int(x), int(y))}
                for k, v in p.items():
                    if isinstance(v, bool):
                        out[k] = "true" if v else "false"
                    elif isinstance(v, (int, float)):
                        out[k] = str(v)
                    else:
                        out[k] = v
                if scene.startswith("@sprite:"):
                    tex = sc.ext_res("Texture2D", "res://assets/deco/%s.png" % scene[8:])
                    out.update({"texture": tex, "centered": "false"})
                    sc.node(name, "Sprite2D", layer, out)
                else:
                    inst = sc.ext_res("PackedScene", "res://scenes/deco/%s.tscn" % scene)
                    sc.node(name, None, layer, out, instance=inst)
                count += 1
        path = os.path.join(ROOT, "levels", "dressing", "level_%02d_dressing.tscn" % self.n)
        sc.save(path)
        return count


if __name__ == "__main__":
    levels = [int(a) for a in sys.argv[1:]] or list(range(1, 13))
    for n in levels:
        b = Builder(n)
        c = b.build()
        print("level %02d: %d dressing nodes (%s)" % (n, c, ", ".join("%s %d" % (k, len(v)) for k, v in b.items.items())))
