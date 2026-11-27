"""Scaffolds scenes/cutscenes/intro.tscn and ending.tscn (nodes + AnimationPlayer tracks).

    python -I assets/cutscenes/src/build_scenes.py

The .tscn files are normal Godot scenes: once you start editing them in the
editor, treat them as the source of truth (re-running this overwrites them).

NOTE: the scenes have moved on since this scaffold. Experiment 47 is now an
instance of scenes/cutscenes/cutscene_blob.tscn (CutsceneBlob: the in-game
water/ice AnimatedSprite2Ds, steam pixel cloud and player eyes; tracks key
`Blob:pose` / `Blob:expression` instead of `Blob:frame` / `Blob/Eyes:frame`),
standalone eyes are CutsceneFace nodes (`expression`), Poof uses the in-game
shift burst, and P7 has a DrainFront floor patch. Don't re-run this over them.

Coordinates: art space is 480x270 (each panel's Art/Fx nodes are scaled 2x);
cameras live in screen space (960x540).
"""
import os

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
A = "res://assets/cutscenes/"


# --- value formatting -------------------------------------------------------------

class Raw(str):
    pass


def q(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def fmt(v):
    if isinstance(v, Raw):
        return str(v)
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return ("%.4f" % v).rstrip("0").rstrip(".") if v != int(v) else "%d.0" % int(v)
    if isinstance(v, str):
        return q(v)
    if isinstance(v, tuple):
        if len(v) == 2:
            return "Vector2(%s, %s)" % (fmt(float(v[0])), fmt(float(v[1])))
        if len(v) == 4:
            return "Color(%s, %s, %s, %s)" % tuple(fmt(float(x)) for x in v)
    if isinstance(v, list):
        return "[" + ", ".join(fmt(x) for x in v) + "]"
    raise ValueError(v)


def V(x, y):
    return (float(x), float(y))


def Col(r, g, b, a=1.0):
    return (float(r), float(g), float(b), float(a))


def Rect(x, y, w, h):
    return Raw("Rect2(%s, %s, %s, %s)" % tuple(fmt(float(t)) for t in (x, y, w, h)))


# --- scene writer ------------------------------------------------------------------

class Scene:
    def __init__(self):
        self.ext = []  # (type, path, id)
        self.sub = []  # (type, id, lines)
        self.nodes = []  # text blocks
        self._ext_ids = {}
        self._n = 0

    def res(self, path, typ="Texture2D"):
        if path not in self._ext_ids:
            i = "%d" % (len(self.ext) + 1)
            self.ext.append((typ, path, i))
            self._ext_ids[path] = i
        return Raw('ExtResource("%s")' % self._ext_ids[path])

    def tex(self, name):
        return self.res(A + name)

    def subres(self, typ, props, sid=None):
        self._n += 1
        sid = sid or "%s_%d" % (typ, self._n)
        lines = []
        for k, v in props.items():
            lines.append("%s = %s" % (k, v if isinstance(v, Raw) else fmt(v)))
        self.sub.append((typ, sid, lines))
        return Raw('SubResource("%s")' % sid)

    def node(self, name, typ, parent=None, props=None, instance=None):
        head = '[node name="%s"' % name
        if typ:
            head += ' type="%s"' % typ
        if parent is not None:
            head += ' parent="%s"' % parent
        if instance:
            head += " instance=%s" % instance
        head += "]"
        lines = [head]
        for k, v in (props or {}).items():
            lines.append("%s = %s" % (k, v if isinstance(v, Raw) else fmt(v)))
        self.nodes.append("\n".join(lines))

    def write(self, path):
        out = ["[gd_scene format=3]", ""]
        for typ, p, i in self.ext:
            out.append('[ext_resource type="%s" path="%s" id="%s"]' % (typ, p, i))
        out.append("")
        for typ, sid, lines in self.sub:
            out.append('[sub_resource type="%s" id="%s"]' % (typ, sid))
            out += lines
            out.append("")
        out.append("\n\n".join(self.nodes))
        out.append("")
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(out))
        print("wrote", os.path.relpath(path, ROOT))


# --- animation ---------------------------------------------------------------------

class Anim:
    def __init__(self, length):
        self.length = length
        self.tracks = []  # dict(path, kind, keys[(t, v, trans)], update)
        self._by_path = {}

    def key(self, path, t, v, trans=1.0, discrete=None):
        tr = self._by_path.get(path)
        if tr is None:
            if discrete is None:
                discrete = isinstance(v, (bool, int)) and not isinstance(v, float) or isinstance(v, Raw) and "Rect2" not in v
                if path.endswith(":frame") or path.endswith(":visible") or path.endswith(":emitting") or path.endswith(":flip_h"):
                    discrete = True
            tr = {"path": path, "kind": "value", "keys": [], "update": 1 if discrete else 0}
            self.tracks.append(tr)
            self._by_path[path] = tr
        tr["keys"].append((t, v, trans))
        return self

    def keys(self, path, pairs, trans=1.0):
        for p in pairs:
            if len(p) == 3:
                self.key(path, p[0], p[1], p[2])
            else:
                self.key(path, p[0], p[1], trans)
        return self

    def call(self, t, method, *args, path="."):
        k = "call:" + path
        tr = self._by_path.get(k)
        if tr is None:
            tr = {"path": path, "kind": "method", "keys": []}
            self.tracks.append(tr)
            self._by_path[k] = tr
        tr["keys"].append((t, (method, list(args)), 1.0))
        return self

    # sugar
    def say(self, t, who, line):
        return self.call(t, "say", who, line)

    def narrate(self, t, line):
        return self.call(t, "narrate", line)

    def sfx(self, t, name):
        return self.call(t, "sfx", name)

    def shake(self, t, amount, time):
        return self.call(t, "shake", float(amount), float(time))

    def flash(self, t, time=0.25):
        return self.call(t, "flash", float(time))

    def clear(self, t):
        return self.call(t, "clear")

    def lines(self):
        out = ['resource_name = "main"', "length = %s" % fmt(float(self.length))]
        for i, tr in enumerate(self.tracks):
            keys = sorted(tr["keys"], key=lambda k: k[0])
            # Godot merges keys at identical times: nudge method calls apart, keep the last value key.
            fixed = []
            for k in keys:
                if fixed and k[0] < fixed[-1][0] + 1e-4:
                    if tr["kind"] == "method":
                        k = (round(fixed[-1][0] + 0.01, 3), k[1], k[2])
                    else:
                        fixed.pop()
                fixed.append(k)
            keys = fixed
            p = "tracks/%d/" % i
            out.append(p + 'type = "%s"' % tr["kind"])
            out.append(p + "imported = false")
            out.append(p + "enabled = true")
            out.append(p + 'path = NodePath("%s")' % tr["path"])
            out.append(p + "interp = 1")
            out.append(p + "loop_wrap = true")
            times = ", ".join(fmt(float(k[0])) for k in keys)
            trans = ", ".join(fmt(float(k[2])) for k in keys)
            if tr["kind"] == "value":
                vals = ", ".join(fmt(k[1]) for k in keys)
                out.append(p + 'keys = {\n"times": PackedFloat32Array(%s),\n"transitions": PackedFloat32Array(%s),\n"update": %d,\n"values": [%s]\n}'
                           % (times, trans, tr["update"], vals))
            else:
                vals = ", ".join('{\n"args": [%s],\n"method": &"%s"\n}' % (", ".join(fmt(a) for a in k[1][1]), k[1][0]) for k in keys)
                out.append(p + 'keys = {\n"times": PackedFloat32Array(%s),\n"transitions": PackedFloat32Array(%s),\n"values": [%s]\n}'
                           % (times, trans, vals))
        return out


EASE = -2.0  # in-out
OUT = 0.5  # ease out
IN = 2.0  # ease in


# --- panel helpers ------------------------------------------------------------------

class Panel:
    def __init__(self, sc, name, length, visible=False, caption_top=False):
        self.sc = sc
        self.name = name
        self.path = "Panels/" + name
        self.anim = Anim(length)
        props = {"visible": visible, "script": sc.res("res://scripts/cutscenes/cutscene_panel.gd", "Script")}
        if caption_top:
            props["caption_top"] = True
        sc.node(name, "Node2D", "Panels", props)
        sc.node("Art", "Node2D", self.path, {"scale": V(2, 2)})
        sc.node("Fx", "Node2D", self.path, {"scale": V(2, 2)})
        self._cam_props = {}

    def p(self, sub=""):
        return self.path + ("/" + sub if sub else "")

    def sprite(self, name, tex, pos, parent="Art", frames=1, frame=0, centered=False, offset=None, props=None, script=True):
        pr = {"texture": self.sc.tex(tex) if not tex.startswith("res://") else self.sc.res(tex)}
        if script:
            pr["script"] = self.sc.res("res://scripts/cutscenes/cutscene_sprite.gd", "Script")
        pr["position"] = V(*pos)
        if not centered:
            pr["centered"] = False
        if offset:
            pr["offset"] = V(*offset)
        if frames > 1:
            pr["hframes"] = frames
        if frame:
            pr["frame"] = frame
        pr.update(props or {})
        # Node property order matters little, but keep `script` last-ish for readability.
        scr = pr.pop("script", None)
        if scr is not None:
            pr["script"] = scr
        self.sc.node(name, "Sprite2D", self.p(parent), pr)
        return (parent + "/" + name)

    def additive(self):
        if not hasattr(self.sc, "_add_mat"):
            self.sc._add_mat = self.sc.subres("CanvasItemMaterial", {"blend_mode": 1}, "add_mat")
        return self.sc._add_mat

    def rect(self, name, parent, pos, size, color, props=None):
        pr = {"offset_left": float(pos[0]), "offset_top": float(pos[1]),
              "offset_right": float(pos[0] + size[0]), "offset_bottom": float(pos[1] + size[1]),
              "mouse_filter": 2, "color": color}
        pr.update(props or {})
        self.sc.node(name, "ColorRect", self.p(parent), pr)
        return parent + "/" + name

    def particles(self, name, parent, pos, props):
        pr = {"position": V(*pos), "emitting": False, "local_coords": True}
        pr.update(props)
        self.sc.node(name, "CPUParticles2D", self.p(parent), pr)
        return parent + "/" + name

    def label(self, name, pos, size, text, props=None):
        pr = {"offset_left": float(pos[0]), "offset_top": float(pos[1]),
              "offset_right": float(pos[0] + size[0]), "offset_bottom": float(pos[1] + size[1]),
              "theme": self.sc.res("res://scenes/ui/theme.tres", "Theme"), "text": text}
        pr.update(props or {})
        self.sc.node(name, "Label", self.p(), pr)
        return name

    def camera(self, pos=(480, 270), zoom=1.0, limits=(0, 0, 960, 540)):
        self._cam = {"position": V(*pos), "zoom": V(zoom, zoom),
                     "limit_left": limits[0], "limit_top": limits[1], "limit_right": limits[2], "limit_bottom": limits[3]}

    def finish(self):
        sc = self.sc
        sc.node("Camera", "Camera2D", self.path, getattr(self, "_cam", {"position": V(480, 270)}))
        a = sc.subres("Animation", {}, "anim_" + self.name)
        # fill animation lines
        typ, sid, _ = sc.sub[-1]
        sc.sub[-1] = (typ, sid, self.anim.lines())
        lib = sc.subres("AnimationLibrary", {"_data": Raw("{\n&\"main\": %s\n}" % a)}, "lib_" + self.name)
        sc.node("Anim", "AnimationPlayer", self.path, {"libraries": Raw("{\n&\"\": %s\n}" % lib)})


def cam(pn, pairs, trans=EASE):
    """pairs: (t, (x, y), zoom)"""
    for t, pos, z in pairs:
        pn.anim.key("Camera:position", t, V(*pos), trans)
        pn.anim.key("Camera:zoom", t, V(z, z), trans)


def flick(anim, path, t0, t1, values, step):
    """Alternates `values` on a discrete track every `step` seconds."""
    t, i = t0, 0
    while t < t1 - 1e-6:
        anim.key(path, round(t, 3), values[i % len(values)])
        t += step
        i += 1


def emote(pn, name, pos, frame):
    return pn.sprite(name, "emotes.png", pos, parent="Fx", frames=5, frame=frame, offset=(-9, -18),
                     props={"visible": False, "scale": V(1, 1)})


def pop_emote(anim, path, t, dur=1.4):
    anim.key(path + ":visible", 0.0, False)
    anim.key(path + ":visible", t, True)
    anim.key(path + ":scale", 0.0, V(0.2, 0.2))
    anim.key(path + ":scale", t, V(0.2, 0.2), OUT)
    anim.key(path + ":scale", t + 0.15, V(1, 1))
    anim.key(path + ":visible", t + dur, False)


def poof(pn, name, pos):
    return pn.sprite(name, "poof.png", pos, parent="Fx", frames=4, centered=True, props={"visible": False})


def do_poof(anim, path, t):
    anim.key(path + ":visible", 0.0, False)
    anim.key(path + ":frame", 0.0, 0)
    anim.key(path + ":visible", t, True)
    for i in range(4):
        anim.key(path + ":frame", t + i * 0.07, i)
    anim.key(path + ":visible", t + 0.3, False)


def blob(pn, name, pos, small=False, parent="Art", visible=True, frame=0, eyes_frame=0, z=0):
    tex = "blob_small.png" if small else "blob_big.png"
    off = (-12, -20) if small else (-24, -40)
    props = {"visible": visible, "z_index": z} if z else {"visible": visible}
    path = pn.sprite(name, tex, pos, parent=parent, frames=5, frame=frame, offset=off, props=props)
    eyes_pos = (-6, -14) if small else (-11, -28)
    pn.sprite("Eyes", "eyes_small.png" if small else "eyes_big.png", eyes_pos, parent=path, frames=9, frame=eyes_frame)
    return path


def particles_tex(pn, name):
    return pn.sc.tex(name)


def gradient(sc, colors, offsets=None):
    offsets = offsets or [i / (len(colors) - 1) for i in range(len(colors))]
    return sc.subres("Gradient", {
        "offsets": Raw("PackedFloat32Array(%s)" % ", ".join(fmt(float(o)) for o in offsets)),
        "colors": Raw("PackedColorArray(%s)" % ", ".join(", ".join(fmt(float(c)) for c in col) for col in colors)),
    })


# --- wide lab layout (shared by several panels) -------------------------------------

def lab_wide(pn, day=False, lamp_on=True, sci_frame=0, sci_visible=True):
    pn.sprite("BG", "lab_day.png" if day else "lab_night.png", (0, 0), script=False)
    pn.sprite("Lamp", "lamp.png", (203, 0), script=False)
    pn.sprite("Regulator", "regulator.png", (270, 134), frames=2)
    pn.sprite("Bench", "bench.png", (150, 190), script=False)
    pn.sprite("Flask", "flask_small.png", (200, 170), frames=3, frame=2 if day else 0)
    pn.sprite("Scientist", "scientist.png", (92, 158), frames=5, frame=sci_frame, props={"visible": sci_visible})
    if lamp_on:
        pn.sprite("LampCone", "lamp_cone.png", (140, 38), parent="Fx",
                  props={"material": pn.additive(), "flicker": 0.08})
    pn.sprite("FlaskGlow", "glow_ice.png", (206, 180), parent="Fx", centered=True,
              props={"material": pn.additive(), "modulate": Col(1, 1, 1, 0)})


def mug_steam(pn, pos, emitting=True):
    return pn.particles("MugSteam", "Art", pos, {
        "emitting": emitting, "amount": 5, "lifetime": 1.6, "texture": pn.sc.tex("steam_puff.png"),
        "emission_shape": 3, "emission_rect_extents": V(2, 1), "direction": V(0, -1), "spread": 12.0,
        "gravity": V(0, -6), "initial_velocity_min": 4.0, "initial_velocity_max": 8.0,
        "scale_amount_min": 0.4, "scale_amount_max": 0.8,
        "color_ramp": gradient(pn.sc, [(1, 1, 1, 0.0), (1, 1, 1, 0.55), (1, 1, 1, 0.0)], [0, 0.3, 1]),
    })


# =====================================================================================
# INTRO
# =====================================================================================

def intro():
    sc = Scene()
    sc.node("Intro", "Node", None, {"script": sc.res("res://scripts/cutscenes/cutscene.gd", "Script"), "next": 0})
    sc.node("Panels", "Node", ".")

    # ---- 1. Late night in Lab 3 ------------------------------------------------------
    pn = Panel(sc, "P1_Night", 6.6, visible=True)
    lab_wide(pn)
    mug_steam(pn, (108, 190))
    pn.camera((330, 190), 1.7)
    a = pn.anim
    cam(pn, [(0, (330, 190), 1.7), (2.2, (330, 230), 1.6), (6.6, (450, 320), 1.18)])
    a.keys("Art/Scientist:frame", [(0, 0), (2.4, 1), (3.6, 0)])
    a.keys("Art/MugSteam:position", [(0, V(108, 190)), (2.4, V(117, 172)), (3.6, V(108, 190))])
    a.narrate(0.35, "Lab 3. 2:47 AM. One lamp still on.")
    a.say(3.0, "DR. KETTLE", "Experiment 47: thermo-responsive water. Tonight's the night.")
    a.sfx(2.4, "bubble")
    pn.finish()

    # ---- 2. Mixing ---------------------------------------------------------------------
    pn = Panel(sc, "P2_Mix", 7.0)
    pn.sprite("BG", "bench_close.png", (0, 0), script=False)
    pn.sprite("Coil", "coil_machine.png", (408, 76), frames=2)
    pn.sprite("Mug", "mug.png", (40, 176), script=False)
    pn.sprite("FlaskBack", "flask_back.png", (200, 102), script=False)
    pn.sprite("Liquid", "flask_liquid.png", (200, 102), frames=7)
    pn.sprite("FlaskFront", "flask_front.png", (200, 102), script=False)
    pn.sprite("Drop", "drops.png", (237, 98), frames=2, props={"visible": False})
    # offset = make_art.SLEEVE_EXT: the sleeve continues off-screen up-left
    pn.sprite("Hand", "hand_vial.png", (100, -80), frames=2, offset=(-70, -70))
    pn.particles("Bubbles", "Fx", (240, 168), {
        "amount": 10, "lifetime": 0.9, "texture": sc.tex("bubble.png"), "emission_shape": 3,
        "emission_rect_extents": V(26, 12), "direction": V(0, -1), "spread": 10.0, "gravity": V(0, -30),
        "initial_velocity_min": 6.0, "initial_velocity_max": 14.0,
        "color_ramp": gradient(sc, [(1, 1, 1, 1), (1, 1, 1, 0)]),
    })
    pn.sprite("FlaskGlow", "glow_ice.png", (240, 160), parent="Fx", centered=True,
              props={"material": pn.additive(), "modulate": Col(1, 1, 1, 0), "scale": V(2, 2)})
    pn.camera((480, 300), 1.0)
    a = pn.anim
    cam(pn, [(0, (480, 290), 1.0), (7.4, (470, 300), 1.12)])
    a.keys("Art/Hand:position", [(0, V(100, -80)), (0.3, V(100, -80), OUT), (0.9, V(160, 46)),
                                  (2.1, V(160, 46), IN), (2.6, V(100, -80)),
                                  (2.8, V(100, -80), OUT), (3.3, V(160, 46)), (4.5, V(160, 46), IN), (5.0, V(100, -80))])
    a.keys("Art/Hand:frame", [(0, 0), (2.7, 1)])
    a.keys("Art/Drop:visible", [(0, False), (1.2, True), (1.55, False), (3.6, True), (3.95, False)])
    a.keys("Art/Drop:frame", [(0, 0), (3.0, 1)])
    a.keys("Art/Drop:position", [(0, V(237, 98)), (1.2, V(237, 98), IN), (1.55, V(237, 148)),
                                  (3.6, V(237, 98), IN), (3.95, V(237, 148))])
    a.keys("Art/Liquid:frame", [(0, 0), (1.55, 1)])
    flick(a, "Art/Liquid:frame", 3.95, 7.4, [2, 3], 0.22)
    a.keys("Fx/Bubbles:emitting", [(0, False), (3.95, True)])
    a.keys("Fx/FlaskGlow:modulate", [(0, Col(1, 1, 1, 0)), (3.95, Col(1, 1, 1, 0)), (4.6, Col(0.6, 1, 0.9, 0.5))])
    a.keys("Art/Coil:frame", [(0, 0), (6.2, 1), (6.4, 0), (6.6, 1)])
    a.say(0.3, "DR. KETTLE", "A pinch of cryo-salt...")
    a.sfx(1.55, "bubble")
    a.say(2.8, "DR. KETTLE", "...a splash of thermal catalyst...")
    a.sfx(3.95, "bubble")
    a.sfx(4.3, "bubble")
    a.say(5.1, "DR. KETTLE", "...and one teeny little zap to wake it up.")
    a.sfx(6.2, "hum")
    pn.finish()

    # ---- 3. Power surge --------------------------------------------------------------
    pn = Panel(sc, "P3_Surge", 6.4, caption_top=True)
    lab_wide(pn)
    pn.sprite("Bolt", "bolt_wide.png", (198, 128), parent="Fx", frames=3, props={"visible": False})
    pn.particles("Sparks", "Fx", (292, 140), {
        "amount": 24, "lifetime": 0.5, "texture": sc.tex("spark.png"), "direction": V(0, -1), "spread": 80.0,
        "gravity": V(0, 220), "initial_velocity_min": 50.0, "initial_velocity_max": 110.0,
        "color_ramp": gradient(sc, [(1, 1, 1, 1), (1, 0.7, 0.3, 1), (1, 0.35, 0.1, 0)]),
    })
    pn.camera((470, 330), 1.25)
    a = pn.anim
    cam(pn, [(0, (440, 320), 1.3), (2.4, (470, 330), 1.4), (2.5, (470, 300), 1.15), (6.4, (470, 300), 1.1)])
    a.keys("Art/Regulator:frame", [(0, 0)])
    flick(a, "Art/Regulator:frame", 1.0, 6.4, [1, 0, 1, 1, 0], 0.12)
    a.keys("Fx/Sparks:emitting", [(0, False), (1.4, True), (4.6, False)])
    a.keys("Fx/Bolt:visible", [(0, False), (2.45, True), (4.4, False)])
    flick(a, "Fx/Bolt:frame", 2.45, 4.4, [0, 1, 2], 0.06)
    a.keys("Art/Scientist:frame", [(0, 0), (2.5, 2)])
    a.keys("Art/Scientist:position", [(0, V(92, 158)), (2.5, V(92, 158), OUT), (2.65, V(88, 150), IN), (2.85, V(86, 158))])
    a.keys("Art/Flask:frame", [(0, 0), (2.5, 1)])
    a.keys("Fx/FlaskGlow:modulate", [(0, Col(1, 1, 1, 0)), (2.5, Col(1, 1, 1, 1)), (6.4, Col(1, 1, 1, 0.8))])
    a.keys("Fx/FlaskGlow:scale", [(0, V(1, 1)), (2.5, V(2.4, 2.4), OUT), (3.5, V(1.5, 1.5))])
    a.keys("Fx/LampCone:visible", [(0, True)])
    flick(a, "Fx/LampCone:visible", 2.5, 4.6, [False, True, False, False, True], 0.09)
    a.keys("Fx/LampCone:visible", [(4.6, False)])
    a.keys("Art:modulate", [(0, Col(1, 1, 1)), (2.5, Col(1, 1, 1)), (2.6, Col(0.55, 0.6, 0.8)), (2.8, Col(1, 1, 1)),
                            (3.0, Col(0.5, 0.55, 0.75)), (4.6, Col(0.45, 0.5, 0.72))])
    a.sfx(0.1, "hum")
    a.say(0.3, "DR. KETTLE", "Hm. Is it supposed to hum like that?")
    a.sfx(1.4, "hum")
    a.flash(2.45, 0.35)
    a.shake(2.45, 9.0, 1.4)
    a.sfx(2.45, "zap")
    a.sfx(2.9, "zap")
    a.say(3.6, "PA", "WARNING: POWER SURGE IN LAB 3.")
    a.sfx(3.5, "chime")
    pn.finish()

    # ---- 4. Lights out ------------------------------------------------------------------
    pn = Panel(sc, "P4_Dark", 4.8, caption_top=True)
    lab_wide(pn, lamp_on=False, sci_visible=False)
    pn.sprite("Fainted", "scientist_fainted.png", (64, 196))
    pn.sprite("Dizzy", "dizzy.png", (58, 190), frames=3, props={"fps": 6.0})
    pn.particles("Smoke", "Art", (292, 136), {
        "emitting": True, "amount": 8, "lifetime": 2.2, "texture": sc.tex("steam_puff.png"), "direction": V(0, -1),
        "spread": 25.0, "gravity": V(4, -8), "initial_velocity_min": 6.0, "initial_velocity_max": 12.0,
        "scale_amount_min": 0.8, "scale_amount_max": 1.6,
        "color_ramp": gradient(sc, [(0.6, 0.65, 0.75, 0), (0.6, 0.65, 0.75, 0.6), (0.6, 0.65, 0.75, 0)], [0, 0.2, 1]),
    })
    pn.camera((330, 380), 1.5)
    a = pn.anim
    a.keys("Art:modulate", [(0, Col(0.42, 0.47, 0.7))])
    a.keys("Art/Flask:frame", [(0, 1)])
    a.keys("Fx/FlaskGlow:modulate", [(0, Col(1, 1, 1, 0.9)), (1.4, Col(1, 1, 1, 0.45)), (2.8, Col(1, 1, 1, 0.95)),
                                      (4.2, Col(1, 1, 1, 0.45)), (5.6, Col(1, 1, 1, 0.9))])
    a.keys("Fx/FlaskGlow:scale", [(0, V(1.6, 1.6))])
    cam(pn, [(0, (300, 400), 1.6), (5.6, (360, 370), 1.45)])
    a.sfx(0.05, "thud")
    a.shake(0.05, 4.0, 0.4)
    a.say(0.6, "DR. KETTLE", "...five more minutes...")
    a.narrate(2.2, "The lab went very, very quiet.")
    pn.finish()

    # ---- 5. The first thought ------------------------------------------------------------
    pn = Panel(sc, "P5_Awake", 7.0)
    pn.sprite("BG", "bench_close.png", (0, 0), script=False)
    pn.sprite("Coil", "coil_machine.png", (408, 76), frames=2)
    pn.sprite("Mug", "mug.png", (40, 176), script=False)
    pn.rect("Dark", "Art", (0, 0), (480, 270), Col(0.03, 0.05, 0.12, 0.55))
    pn.sprite("FlaskBack", "flask_back.png", (200, 102), script=False)
    pn.sprite("Liquid", "flask_liquid.png", (200, 102), frames=7, frame=4)
    pn.sprite("Eyes", "eyes_big.png", (229, 160), frames=9, frame=2, props={"visible": False})
    pn.sprite("FlaskFront", "flask_front.png", (200, 102), script=False)
    pn.sprite("FlaskGlow", "glow_ice.png", (240, 165), parent="Fx", centered=True,
              props={"material": pn.additive(), "scale": V(2.5, 2.5)})
    emote(pn, "Emote", (252, 96), 1)
    pn.camera((480, 300), 1.0)
    a = pn.anim
    cam(pn, [(0, (480, 290), 1.0), (5.0, (480, 320), 1.7), (7.0, (480, 322), 1.75)])
    a.keys("Art/Liquid:frame", [(0, 4), (1.6, 5)])
    a.keys("Fx/FlaskGlow:modulate", [(0, Col(1, 1, 1, 1)), (1.6, Col(1, 1, 1, 0.9)), (2.6, Col(1, 1, 1, 0.15))])
    a.keys("Art/Eyes:visible", [(0, False), (2.3, True)])
    a.keys("Art/Eyes:frame", [(0, 2), (2.3, 2), (2.8, 1), (3.0, 0), (3.6, 3), (4.1, 4), (4.6, 0), (4.8, 2), (4.9, 0),
                              (6.3, 2), (6.4, 0)])
    pop_emote(a, "Fx/Emote", 5.2, 1.6)
    a.narrate(0.4, "In the dark, the water in flask 47 had its very first thought.")
    a.sfx(2.8, "pop")
    a.sfx(5.2, "select")
    a.narrate(5.0, "It was: \"...huh?\"")
    pn.finish()

    # ---- 6. Freeze, float, splash -------------------------------------------------------
    pn = Panel(sc, "P6_Shift", 8.6)
    pn.sprite("BG", "bench_close.png", (0, 0), script=False)
    pn.sprite("Coil", "coil_machine.png", (408, 76), frames=2)
    pn.sprite("Mug", "mug.png", (40, 176), script=False)
    pn.rect("Dark", "Art", (0, 0), (480, 270), Col(0.03, 0.05, 0.12, 0.35))
    pn.sprite("FlaskBack", "flask_back.png", (200, 102), script=False)
    pn.sprite("Liquid", "flask_liquid.png", (200, 102), frames=7, frame=5)
    pn.sprite("FlaskEyes", "eyes_big.png", (229, 160), frames=9)
    pn.sprite("FlaskFront", "flask_front.png", (200, 102), script=False)
    blob(pn, "Blob", (240, 110), visible=False, frame=2, z=1)
    poof(pn, "Poof", (330, 186))
    emote(pn, "Emote", (342, 150), 2)
    emote(pn, "Emote2", (342, 150), 0)
    emote(pn, "Emote3", (342, 150), 4)
    pn.camera((560, 330), 1.3)
    a = pn.anim
    cam(pn, [(0, (500, 320), 1.45), (1.4, (580, 330), 1.35), (8.6, (590, 340), 1.42)])
    B = "Art/Blob"
    a.keys("Art/FlaskEyes:visible", [(0, True), (0.55, False)])
    a.keys("Art/FlaskEyes:frame", [(0, 6)])
    a.keys("Art/Liquid:frame", [(0, 5), (0.55, 6)])
    a.keys(B + ":visible", [(0, False), (0.55, True)])
    a.keys(B + ":position", [(0, V(240, 112)), (0.55, V(240, 112), OUT), (0.95, V(290, 64), IN), (1.35, V(330, 206)),
                             (5.0, V(330, 206), OUT), (5.6, V(330, 182)), (6.8, V(330, 182), IN), (7.05, V(330, 206))])
    a.keys(B + ":frame", [(0, 2), (1.35, 1), (1.5, 0), (3.25, 3), (5.05, 4), (6.85, 2), (7.05, 1), (7.2, 0)])
    a.keys(B + "/Eyes:position", [(0, V(-11, -28)), (3.25, V(-11, -27)), (5.05, V(-12, -25)), (6.85, V(-11, -28))])
    a.keys(B + "/Eyes:frame", [(0, 7), (1.5, 2), (1.65, 0), (2.0, 3), (2.4, 4), (2.8, 5), (3.25, 7), (3.9, 0),
                               (5.05, 8), (5.6, 5), (7.05, 2), (7.25, 6), (7.8, 5)])
    a.keys(B + ":scale", [(0, V(1, 1)), (1.35, V(1.15, 0.85), OUT), (1.6, V(1, 1))])
    a.keys(B + ":offset", [(0, V(-24, -40))])
    do_poof(a, "Fx/Poof", 3.2)
    a.keys("Fx/Poof:position", [(0, V(330, 186)), (5.0, V(330, 186)), (6.8, V(330, 164))])
    for t in (5.0, 6.8):
        a.key("Fx/Poof:visible", t, True)
        for i in range(4):
            a.key("Fx/Poof:frame", t + i * 0.07, i)
        a.key("Fx/Poof:visible", t + 0.3, False)
    pop_emote(a, "Fx/Emote", 2.85, 1.0)
    pop_emote(a, "Fx/Emote2", 3.5, 0.9)
    pop_emote(a, "Fx/Emote3", 7.85, 0.75)
    a.sfx(0.55, "pop")
    a.sfx(1.35, "land")
    a.narrate(1.6, "It could wobble.")
    a.sfx(3.2, "cool")
    a.sfx(3.3, "land_ice")
    a.narrate(3.3, "It could freeze...")
    a.sfx(5.0, "heat")
    a.narrate(5.1, "...it could float...")
    a.sfx(6.8, "poof")
    a.sfx(7.05, "land")
    a.narrate(7.0, "...it could SPLASH!")
    pn.finish()

    # ---- 7. Containment breach --------------------------------------------------------
    pn = Panel(sc, "P7_Alarm", 8.2, caption_top=True)
    lab_wide(pn, lamp_on=False, sci_visible=False)
    pn.sprite("Fainted", "scientist_fainted.png", (64, 196))
    pn.sprite("Door", "door_panel.png", (396, 118), props={"region_enabled": True, "region_rect": Rect(0, 112, 54, 0)})
    pn.sprite("Alarm", "alarm_lamp.png", (420, 82), frames=2)
    blob(pn, "Blob", (318, 238), small=True, eyes_frame=7)
    pn.rect("RedWash", "Fx", (0, 0), (480, 270), Col(1, 0.12, 0.05, 0))
    pn.sprite("Beam", "alarm_beam.png", (427, 88), parent="Fx",
              props={"material": pn.additive(), "offset": V(0, -30), "centered": False, "visible": True})
    emote(pn, "Emote", (322, 212), 0)
    pn.particles("Splash", "Fx", (241, 242), {
        "amount": 10, "lifetime": 0.6, "one_shot": True, "explosiveness": 0.9, "texture": sc.tex("spark.png"),
        "direction": V(0, -1), "spread": 50.0, "gravity": V(0, 160), "initial_velocity_min": 30.0,
        "initial_velocity_max": 60.0, "scale_amount_min": 0.6, "scale_amount_max": 1.0, "color": Col(0.55, 0.77, 1, 1),
    })
    pn.camera((640, 400), 1.5)
    a = pn.anim
    cam(pn, [(0, (660, 400), 1.6), (4.0, (630, 400), 1.6), (8.2, (560, 410), 1.8)])
    a.keys("Art:modulate", [(0, Col(0.5, 0.55, 0.78))])
    a.keys("Art/Flask:frame", [(0, 2)])
    flick(a, "Art/Alarm:frame", 0.0, 8.4, [1, 0], 0.3)
    for k in range(14):
        t = k * 0.6
        a.key("Fx/RedWash:color", round(t, 2), Col(1, 0.12, 0.05, 0.22), OUT)
        a.key("Fx/RedWash:color", round(t + 0.3, 2), Col(1, 0.12, 0.05, 0.02), IN)
    a.keys("Fx/Beam:rotation", [(0, 0.0), (8.4, 6.283 * 6)])
    a.keys("Art/Door:region_rect", [(0, Rect(0, 112, 54, 0)), (1.4, Rect(0, 112, 54, 0)), (3.8, Rect(0, 0, 54, 112))])
    B = "Art/Blob"
    a.keys(B + "/Eyes:frame", [(0, 7), (1.0, 4), (2.6, 7), (4.0, 2), (4.15, 3), (5.4, 6), (6.2, 6)])
    pop_emote(a, "Fx/Emote", 4.3, 1.0)
    a.keys(B + ":position", [(0, V(318, 238)), (6.0, V(318, 238), OUT), (6.25, V(298, 230), IN), (6.5, V(280, 240), OUT),
                             (6.75, V(262, 232), IN), (7.0, V(244, 242))])
    a.keys(B + ":frame", [(0, 0), (6.0, 1), (6.05, 2), (6.5, 1), (6.55, 2), (7.0, 1), (7.2, 0)])
    a.keys(B + ":scale", [(0, V(1, 1)), (7.0, V(1, 1)), (7.2, V(1.3, 0.7)), (7.7, V(1.5, 0.05))])
    a.keys(B + ":modulate", [(0, Col(1, 1, 1, 1)), (7.4, Col(1, 1, 1, 1)), (7.75, Col(1, 1, 1, 0))])
    a.keys("Fx/Splash:emitting", [(0, False), (7.0, True)])
    for k in range(7):
        a.sfx(k * 1.2, "alarm")
    a.say(0.3, "PA", "CONTAINMENT BREACH. SEALING LAB 3.")
    a.sfx(1.4, "door")
    a.sfx(3.8, "thud")
    a.shake(3.8, 3.0, 0.3)
    a.narrate(4.4, "Every door was locking. But water doesn't need doors.")
    a.sfx(6.05, "jump")
    a.sfx(6.55, "jump")
    a.sfx(7.0, "land")
    a.sfx(7.4, "bubble")
    pn.finish()

    # ---- 8. Title --------------------------------------------------------------------
    pn = Panel(sc, "P8_Title", 3.8)
    pn.rect("Black", "Art", (-10, -10), (500, 290), Col(0.0275, 0.0431, 0.0941, 1))
    sc.node("Logo", "Sprite2D", pn.p(), {"position": V(480, 236), "scale": V(0.6, 0.6),
                                         "texture": sc.res("res://assets/ui/u1_logo.png"), "modulate": Col(1, 1, 1, 0)})
    pn.label("Sub", (180, 330), (600, 30), "Chapter 1  —  Drip",
             {"horizontal_alignment": 1, "theme_type_variation": "DimLabel", "modulate": Col(1, 1, 1, 0),
              "theme_override_font_sizes/font_size": 20})
    a = pn.anim
    a.keys("Logo:modulate", [(0, Col(1, 1, 1, 0)), (0.3, Col(1, 1, 1, 0)), (1.2, Col(1, 1, 1, 1))])
    a.keys("Logo:position", [(0, V(480, 250)), (0.3, V(480, 250), OUT), (1.2, V(480, 236))])
    a.keys("Sub:modulate", [(0, Col(1, 1, 1, 0)), (1.4, Col(1, 1, 1, 0)), (2.1, Col(1, 1, 1, 1))])
    a.sfx(0.4, "chime")
    a.clear(0.0)
    pn.finish()

    sc.node("UI", None, ".", {}, instance=sc.res("res://scenes/cutscenes/cutscene_ui.tscn", "PackedScene"))
    sc.write(os.path.join(ROOT, "scenes", "cutscenes", "intro.tscn"))


# =====================================================================================
# ENDING
# =====================================================================================

def night_set(pn, clouds=True):
    pn.sprite("Sky", "sky_tall.png", (0, -270), script=False)
    pn.sprite("MoonGlow", "glow_moon.png", (372, 60), parent="Fx", centered=True,
              props={"material": pn.additive(), "scale": V(1.6, 1.6)})
    if clouds:
        pn.sprite("Cloud1", "cloud_1.png", (20, 20), props={"bob_px": 1.0, "bob_hz": 0.2})
        pn.sprite("Cloud3", "cloud_3.png", (250, 72), props={"bob_px": 1.0, "bob_hz": 0.25})
        pn.sprite("Cloud4", "cloud_4.png", (330, -150))
        pn.sprite("Cloud2", "cloud_2.png", (30, -200))
    pn.sprite("Roof", "rooftop.png", (0, 0), script=False)


def ending():
    sc = Scene()
    sc.node("Ending", "Node", None, {"script": sc.res("res://scripts/cutscenes/cutscene.gd", "Script"), "next": 1})
    sc.node("Panels", "Node", ".")
    LIM = (0, -540, 960, 540)

    # ---- 1. Out of the flue ----------------------------------------------------------
    pn = Panel(sc, "E1_Roof", 7.6, visible=True, caption_top=True)
    night_set(pn)
    blob(pn, "Blob", (124, 112), small=True, visible=False, frame=2, eyes_frame=0)
    # keep the flue in front of the blob while it's inside
    pn.sprite("FlueCap", "rooftop.png", (104, 100), props={"region_enabled": True, "region_rect": Rect(104, 100, 40, 100)}, script=False)
    pn.particles("Splash", "Fx", (124, 104), {
        "amount": 14, "lifetime": 0.7, "one_shot": True, "explosiveness": 0.9, "texture": sc.tex("spark.png"),
        "direction": V(0, -1), "spread": 40.0, "gravity": V(0, 160), "initial_velocity_min": 40.0,
        "initial_velocity_max": 80.0, "scale_amount_min": 0.6, "scale_amount_max": 1.0, "color": Col(0.55, 0.77, 1, 1),
    })
    emote(pn, "Emote", (196, 180), 4)
    emote(pn, "Emote2", (196, 180), 0)
    pn.camera((260, 260), 1.7, LIM)
    a = pn.anim
    cam(pn, [(0, (250, 250), 1.8), (2.6, (250, 240), 1.8), (3.6, (360, 280), 1.35), (7.6, (420, 250), 1.25)])
    a.keys("Art/Cloud1:position", [(0, V(20, 20)), (7.6, V(34, 20))])
    a.keys("Art/Cloud3:position", [(0, V(250, 72)), (7.6, V(262, 72))])
    B = "Art/Blob"
    a.keys(B + ":visible", [(0, False), (2.5, True)])
    a.keys(B + ":position", [(0, V(124, 112)), (2.5, V(124, 112), OUT), (2.95, V(150, 52), IN), (3.55, V(196, 204))])
    a.keys(B + ":frame", [(0, 2), (3.55, 1), (3.7, 0)])
    a.keys(B + ":scale", [(0, V(1, 1)), (3.55, V(1.25, 0.8), OUT), (3.8, V(1, 1))])
    a.keys(B + "/Eyes:frame", [(0, 7), (3.7, 2), (3.85, 0), (4.3, 3), (4.8, 4), (5.4, 8), (6.6, 5)])
    a.keys("Fx/Splash:emitting", [(0, False), (2.5, True)])
    pop_emote(a, "Fx/Emote2", 4.0, 0.8)
    pop_emote(a, "Fx/Emote", 6.6, 1.0)
    a.narrate(0.3, "Up the flue. Past the last fan. One final push...")
    a.sfx(1.4, "bubble")
    a.shake(1.6, 2.0, 0.8)
    a.sfx(2.5, "pop")
    a.sfx(3.55, "land")
    a.narrate(4.6, "...and then, for the very first time: no ceiling.")
    pn.finish()

    # ---- 2. Rising to the clouds -------------------------------------------------------
    pn = Panel(sc, "E2_Rise", 8.0, caption_top=True)
    night_set(pn)
    pn.sprite("CloudBig", "cloud_big.png", (164, -246), props={"bob_px": 1.0, "bob_hz": 0.3, "z_index": 1})
    pn.sprite("Eyes", "eyes_big.png", (64, 24), parent="Art/CloudBig", frames=9, frame=2, props={"visible": False})
    blob(pn, "Blob", (196, 204), small=True, eyes_frame=8)
    poof(pn, "Poof", (196, 194))
    emote(pn, "Emote", (262, -250), 2)
    pn.particles("Trail", "Art", (196, 200), {
        "emitting": False, "amount": 10, "lifetime": 1.2, "texture": sc.tex("steam_puff.png"), "local_coords": False,
        "direction": V(0, 1), "spread": 30.0, "gravity": V(0, 0), "initial_velocity_min": 2.0, "initial_velocity_max": 6.0,
        "scale_amount_min": 1.0, "scale_amount_max": 2.0,
        "color_ramp": gradient(sc, [(1, 1, 1, 0.7), (1, 1, 1, 0)]),
    })
    pn.camera((400, 300), 1.4, LIM)
    a = pn.anim
    cam(pn, [(0, (400, 330), 1.45), (1.4, (400, 330), 1.45), (5.6, (470, -380), 1.35), (8.0, (470, -390), 1.4)])
    B = "Art/Blob"
    a.keys(B + ":frame", [(0, 0), (1.35, 4)])
    a.keys(B + "/Eyes:frame", [(0, 8), (0.9, 5), (1.35, 8)])
    a.keys(B + "/Eyes:position", [(0, V(-6, -14)), (1.35, V(-6, -12))])
    a.keys(B + ":position", [(0, V(196, 204)), (1.6, V(196, 204), EASE), (2.8, V(214, 120), EASE), (4.0, V(196, 20), EASE),
                             (5.2, V(236, -110), EASE), (6.1, V(240, -196))])
    a.keys(B + ":visible", [(0, True), (6.1, False)])
    a.keys("Art/Trail:position", [(0, V(196, 200)), (1.6, V(196, 200), EASE), (2.8, V(214, 116), EASE), (4.0, V(196, 16), EASE),
                                  (5.2, V(236, -114), EASE), (6.1, V(240, -200))])
    a.keys("Art/Trail:emitting", [(0, False), (1.6, True), (6.1, False)])
    do_poof(a, "Fx/Poof", 1.3)
    a.keys("Art/CloudBig/Eyes:visible", [(0, False), (6.4, True)])
    a.keys("Art/CloudBig/Eyes:frame", [(0, 2), (6.4, 2), (6.7, 0), (7.2, 5)])
    a.keys("Art/CloudBig:scale", [(0, V(1, 1)), (6.1, V(1, 1), OUT), (6.25, V(1.06, 0.94)), (6.5, V(1, 1))])
    pop_emote(a, "Fx/Emote", 7.2, 0.8)
    a.narrate(0.3, "There were clouds up there. Big, slow, free ones.")
    a.sfx(1.3, "heat")
    a.narrate(3.4, "So it went up to say hello.")
    a.sfx(6.1, "pop")
    a.sfx(7.2, "select")
    pn.finish()

    # ---- 3. Rain -----------------------------------------------------------------------
    pn = Panel(sc, "E3_Rain", 7.2)
    pn.sprite("BG", "landscape.png", (0, 0), script=False)
    pn.sprite("MoonGlow", "glow_moon.png", (404, 46), parent="Fx", centered=True, props={"material": pn.additive(), "scale": V(1.3, 1.3)})
    pn.sprite("Cloud1", "cloud_1.png", (300, 14))
    pn.sprite("CloudBig", "cloud_big.png", (150, 26), props={"bob_px": 1.0, "bob_hz": 0.3})
    pn.sprite("Eyes", "eyes_big.png", (64, 24), parent="Art/CloudBig", frames=9, frame=5)
    pn.particles("Rain", "Art/CloudBig", (75, 60), {
        "emitting": True, "amount": 70, "lifetime": 0.75, "texture": sc.tex("raindrop.png"), "local_coords": False,
        "emission_shape": 3, "emission_rect_extents": V(124, 4), "direction": V(0.08, 1), "spread": 2.0,
        "gravity": V(0, 120), "initial_velocity_min": 250.0, "initial_velocity_max": 290.0,
        "scale_amount_min": 2.0, "scale_amount_max": 2.0, "preprocess": 1.0,
        "color_ramp": gradient(sc, [(1, 1, 1, 0.9), (1, 1, 1, 0.9), (1, 1, 1, 0)], [0, 0.8, 1]),
    })
    pn.particles("Rain2", "Art/Cloud1", (48, 30), {
        "emitting": True, "amount": 28, "lifetime": 0.7, "texture": sc.tex("raindrop.png"), "local_coords": False,
        "emission_shape": 3, "emission_rect_extents": V(72, 4), "direction": V(0.08, 1), "spread": 2.0,
        "gravity": V(0, 120), "initial_velocity_min": 250.0, "initial_velocity_max": 290.0,
        "scale_amount_min": 2.0, "scale_amount_max": 2.0, "preprocess": 1.0,
        "color_ramp": gradient(sc, [(1, 1, 1, 0.7), (1, 1, 1, 0.7), (1, 1, 1, 0)], [0, 0.8, 1]),
    })
    pn.camera((470, 200), 1.3)
    a = pn.anim
    cam(pn, [(0, (460, 190), 1.35), (7.2, (480, 270), 1.0)])
    a.keys("Art/CloudBig:position", [(0, V(150, 26)), (7.2, V(176, 26))])
    a.keys("Art/Cloud1:position", [(0, V(300, 14)), (7.2, V(312, 14))])
    a.keys("Art/CloudBig/Eyes:frame", [(0, 5), (3.0, 2), (3.12, 5)])
    a.sfx(0.1, "rain")
    a.sfx(1.9, "rain")
    a.sfx(3.7, "rain")
    a.sfx(5.5, "rain")
    a.narrate(0.4, "Then, gently, it came back down. Everywhere at once.")
    a.narrate(3.7, "On the hills, on the lake... and on one very quiet lab.")
    pn.finish()

    # ---- 4. Morning ----------------------------------------------------------------------
    pn = Panel(sc, "E4_Morning", 9.4, caption_top=True)
    lab_wide(pn, day=True, lamp_on=False, sci_frame=3)
    pn.sprite("Trail", "trail.png", (0, 0), props={"modulate": Col(1, 1, 1, 0)}, script=False)
    pn.sprite("Drip", "drops.png", (206, 188), frames=2, props={"visible": False})
    emote(pn, "Emote", (116, 156), 3)
    emote(pn, "Emote2", (116, 156), 4)
    pn.camera((260, 360), 1.6)
    a = pn.anim
    a.keys("Art/Flask:visible", [(0, False)])
    cam(pn, [(0, (240, 370), 1.7), (2.4, (250, 370), 1.65), (3.2, (440, 450), 1.7), (5.4, (440, 450), 1.7),
             (6.2, (250, 360), 1.75), (9.4, (250, 356), 1.8)])
    a.keys("Art/Scientist:frame", [(0, 3), (6.6, 4)])
    a.keys("Art/Trail:modulate", [(0, Col(1, 1, 1, 0)), (2.6, Col(1, 1, 1, 0)), (3.4, Col(1, 1, 1, 1))])
    a.keys("Art/Drip:visible", [(0, False), (3.6, True), (3.9, False)])
    a.keys("Art/Drip:position", [(0, V(206, 188)), (3.6, V(206, 188), IN), (3.9, V(208, 226))])
    pop_emote(a, "Fx/Emote", 1.6, 1.0)
    pop_emote(a, "Fx/Emote2", 7.8, 1.4)
    a.say(0.3, "DR. KETTLE", "Morning, forty-seven! Coffee first, then... wait. Empty?")
    a.say(3.4, "DR. KETTLE", "A little wet trail. Straight down the drain.")
    a.sfx(3.9, "bubble")
    a.say(6.3, "DR. KETTLE", "...and it rained all night. Huh.")
    pn.finish()

    # ---- 5. The lab log -------------------------------------------------------------------
    pn = Panel(sc, "E5_Log", 10.0)
    pn.sprite("BG", "note_close.png", (0, 0), script=False)
    pn.sprite("Mug", "mug.png", (330, 34), script=False)
    pn.sprite("FlaskBack", "flask_back.png", (370, 120), script=False)
    pn.sprite("Liquid", "flask_liquid.png", (370, 120), frames=7, frame=6)
    pn.sprite("FlaskFront", "flask_front.png", (370, 120), script=False)
    pn.sprite("Doodle", "doodle.png", (236, 222), centered=True, props={"visible": False})
    ink = Col(0.137, 0.192, 0.353, 1)
    lines = [
        ("Head", 92, "LAB LOG  —  EXPERIMENT 47", 22),
        ("L1", 150, "Subject: one flask of H2O.", 19),
        ("L2", 178, "Status: escaped. Drains, cryo wing,", 19),
        ("L3", 206, "sewers, boiler room, roof.", 19),
        ("L4", 234, "Result: rain. Quite a lot of it.", 19),
        ("L5", 290, "Conclusion:", 19),
        ("L6", 318, "Good for you, little one.", 24),
    ]
    a = pn.anim
    t = 0.4
    for name, y, text, size in lines:
        col = Col(0.15, 0.45, 1, 1) if name == "L6" else ink
        pn.label(name, (196, y - 6), (380, 30), text, {
            "theme_override_colors/font_color": col, "theme_override_colors/font_outline_color": Col(0, 0, 0, 0),
            "theme_override_constants/outline_size": 0, "theme_override_font_sizes/font_size": size,
            "visible_ratio": 0.0})
        dur = max(0.5, len(text) / 34.0)
        a.keys(name + ":visible_ratio", [(0, 0.0), (t, 0.0), (t + dur, 1.0)])
        for k in range(int(dur / 0.12)):
            a.sfx(round(t + k * 0.12, 2), "blip")
        t += dur + (0.9 if name in ("Head", "L4", "L5") else 0.25)
    a.keys("Art/Doodle:visible", [(0, False), (t + 0.1, True)])
    a.keys("Art/Doodle:scale", [(0, V(0.5, 0.5)), (t + 0.1, V(0.5, 0.5), OUT), (t + 0.3, V(2, 2))])
    a.sfx(t + 0.1, "chime")
    a.length = max(a.length, t + 2.4)
    pn.camera((440, 290), 1.0)
    cam(pn, [(0, (430, 260), 1.15), (a.length, (420, 300), 1.05)])
    pn.finish()

    sc.node("UI", None, ".", {}, instance=sc.res("res://scenes/cutscenes/cutscene_ui.tscn", "PackedScene"))
    sc.write(os.path.join(ROOT, "scenes", "cutscenes", "ending.tscn"))


if __name__ == "__main__":
    intro()
    ending()
