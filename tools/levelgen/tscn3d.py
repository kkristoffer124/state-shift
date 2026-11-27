"""Tiny helper to emit Godot 4 .tscn files for State Shift 3D levels (real nodes)."""
import math

EXT = {
    "level": ("Script", "res://scripts/v3d/level_3d.gd"),
    "block": ("Script", "res://scripts/v3d/block_3d.gd"),
    "zone": ("Script", "res://scripts/v3d/zone_3d.gd"),
    "turbine": ("Script", "res://scripts/v3d/turbine_3d.gd"),
    "gate": ("Script", "res://scripts/v3d/gate_3d.gd"),
    "plate": ("Script", "res://scripts/v3d/plate_3d.gd"),
    "hint": ("Script", "res://scripts/v3d/hint_3d.gd"),
    "lamp": ("Script", "res://scripts/v3d/lamp_3d.gd"),
    "pipe": ("Script", "res://scripts/v3d/pipe_3d.gd"),
    "jet": ("Script", "res://scripts/v3d/steam_jet_3d.gd"),
    "player": ("PackedScene", "res://scenes/v3d/player_3d.tscn"),
    "rig": ("PackedScene", "res://scenes/v3d/camera_rig_3d.tscn"),
}

KIND = {"wall": 0, "grate": 1, "breakable": 2, "glass": 3, "decor": 4}
LOOK = {"auto": 0, "wall": 1, "fill": 2, "dark": 3, "metal": 4, "glow": 5}
ZKIND = {"spikes": 0, "heat": 1, "freeze": 2, "fan": 3, "goal": 4}


def f(v):
    s = ("%.4f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def v3(v):
    return "Vector3(%s, %s, %s)" % (f(v[0]), f(v[1]), f(v[2]))


def col(c):
    return "Color(%s, %s, %s, %s)" % tuple(f(x) for x in (list(c) + [1.0])[:4])


def basis_rot(rx=0.0, ry=0.0, rz=0.0):
    """Euler YXZ like Godot (rotation in radians)."""
    cx, sx = math.cos(rx), math.sin(rx)
    cy, sy = math.cos(ry), math.sin(ry)
    cz, sz = math.cos(rz), math.sin(rz)
    X = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    Y = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    Z = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]

    def mul(a, b):
        return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    return mul(mul(Y, X), Z)


def xform(pos, rot=(0, 0, 0)):
    b = basis_rot(*rot)
    # Godot Transform3D(xx, xy, xz, yx, yy, yz, zx, zy, zz, ox, oy, oz) lists basis COLUMNS
    # Godot writes Transform3D(...) basis ROW by row.
    cols = [b[0][0], b[0][1], b[0][2], b[1][0], b[1][1], b[1][2], b[2][0], b[2][1], b[2][2]]
    return "Transform3D(%s, %s)" % (", ".join(f(x) for x in cols), ", ".join(f(x) for x in pos))


class Scene:
    def __init__(self, root_name="Level"):
        self.nodes = []
        self.used = set()
        self.subs = []
        self.root = root_name
        self.y_from = None   # optional: raise every y >= y_from by y_add
        self.y_add = 0.0

    def ys(self, p):
        p = list(p)
        if self.y_from is not None and p[1] >= self.y_from - 1e-6:
            p[1] += self.y_add
        return tuple(p)

    def node(self, name, typ, parent, props=None, script=None, instance=None):
        lines = []
        head = '[node name="%s"' % name
        if typ and not instance:
            head += ' type="%s"' % typ
        if parent is not None:
            head += ' parent="%s"' % parent
        if instance:
            self.used.add(instance)
            head += ' instance=ExtResource("%s")' % instance
        lines.append(head + "]")
        props = dict(props or {})
        if "transform" in props:
            lines.append("transform = %s" % props.pop("transform"))
        if script:
            self.used.add(script)
            lines.append('script = ExtResource("%s")' % script)
        for k, v in props.items():
            lines.append("%s = %s" % (k, v))
        self.nodes.append("\n".join(lines))
        return name

    def sub(self, sid, typ, props):
        lines = ['[sub_resource type="%s" id="%s"]' % (typ, sid)]
        for k, v in props.items():
            lines.append("%s = %s" % (k, v))
        self.subs.append("\n".join(lines))

    def text(self):
        out = ["[gd_scene format=3]", ""]
        for k in EXT:
            if k in self.used:
                out.append('[ext_resource type="%s" path="%s" id="%s"]' % (EXT[k][0], EXT[k][1], k))
        out.append("")
        for s in self.subs:
            out.append(s)
            out.append("")
        for n in self.nodes:
            out.append(n)
            out.append("")
        return "\n".join(out)

    # --- helpers --------------------------------------------------------------
    def block(self, name, a, b, kind="wall", look="auto", tint=None, parent="Blocks", shadow=True, rot=(0, 0, 0)):
        a, b = self.ys(a), self.ys(b)
        c = [(a[i] + b[i]) / 2.0 for i in range(3)]
        s = [abs(b[i] - a[i]) for i in range(3)]
        props = {"transform": xform(c, rot)}
        props["size"] = v3(s)
        if kind != "wall":
            props["kind"] = str(KIND[kind])
        if look != "auto":
            props["look"] = str(LOOK[look])
        if tint is not None:
            props["tint"] = col(tint)
        if not shadow:
            props["cast_shadow"] = "false"
        return self.node(name, "StaticBody3D", parent, props, script="block")

    def zone(self, name, center, size, kind, rot=(0, 0, 0), extra=None, parent="Zones"):
        center = self.ys(center)
        props = {"transform": xform(center, rot), "kind": str(ZKIND[kind]), "size": v3(size)}
        props.update(extra or {})
        return self.node(name, "Area3D", parent, props, script="zone")

    def hint(self, name, pos, text, parent="Hints", size=None):
        pos = self.ys(pos)
        props = {"transform": xform(pos), "text": '"%s"' % text}
        if size:
            props["font_size"] = str(size)
        return self.node(name, "Label3D", parent, props, script="hint")

    def lamp(self, name, pos, color, energy=1.0, rng=6.0, fitting=0, parent="Decor", flicker=0.0, tube=1.6, rot=(0, 0, 0)):
        pos = self.ys(pos)
        props = {"transform": xform(pos, rot), "light_color": col(color), "light_energy": f(energy), "omni_range": f(rng),
                 "omni_attenuation": "1.4"}
        if fitting:
            props["fitting"] = str(fitting)
        if fitting == 1:
            props["tube_length"] = f(tube)
        if flicker:
            props["flicker"] = f(flicker)
        return self.node(name, "OmniLight3D", parent, props, script="lamp")

    def pipe(self, name, pos, length, axis="x", radius=0.18, parent="Decor", color=None, flange=1.5):
        pos = self.ys(pos)
        props = {"transform": xform(pos), "length": f(length), "radius": f(radius),
                 "axis": str({"x": 0, "y": 1, "z": 2}[axis]), "flange_every": f(flange)}
        if color:
            props["color"] = col(color)
        return self.node(name, "MeshInstance3D", parent, props, script="pipe")

    def jet(self, name, pos, height=2.0, period=3.0, burst=1.0, phase=0.0, parent="Decor", rot=(0, 0, 0)):
        pos = self.ys(pos)
        props = {"transform": xform(pos, rot), "height": f(height), "period": f(period), "burst_time": f(burst), "phase": f(phase)}
        return self.node(name, "CPUParticles3D", parent, props, script="jet")


def level_header(sc, level_name, theme, mode, extra=None, sun_rot=(-0.9, 0.5, 0)):
    props = {"level_name": '"%s"' % level_name, "theme": '"%s"' % theme, "camera_mode": str(mode)}
    props.update(extra or {})
    sc.sub("Env", "Environment", {
        "background_mode": "1",
        "tonemap_mode": "2",
        "tonemap_white": "6.0",
        "glow_enabled": "true",
        "glow_intensity": "0.6",
        "glow_bloom": "0.05",
        "glow_hdr_threshold": "1.1",
        "fog_enabled": "true",
        "fog_density": "0.03",
    })
    sc.node("Level", "Node3D", None, props, script="level")
    sc.node("WorldEnvironment", "WorldEnvironment", ".", {"environment": 'SubResource("Env")'})
    sc.node("KeyLight", "DirectionalLight3D", ".", {"transform": xform((0, 10, 0), sun_rot)})
    for g in ("Blocks", "Zones", "Interactive", "Decor", "Hints"):
        sc.node(g, "Node3D", ".")
