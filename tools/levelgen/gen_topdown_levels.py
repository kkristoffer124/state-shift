"""Writes levels/level_02_topdown.tscn and levels/level_07_topdown.tscn (real nodes)."""
import os

ROOT = r"C:/Users/krist/OneDrive/Documents/state-shift/"
C = 32


class Scene:
    def __init__(self):
        self.ext = {}      # path -> (id, type)
        self.subs = []
        self.nodes = []

    def res(self, path, typ):
        if path not in self.ext:
            self.ext[path] = ("r%d" % (len(self.ext) + 1), typ)
        return 'ExtResource("%s")' % self.ext[path][0]

    def sub(self, text):
        sid = "s%d" % (len(self.subs) + 1)
        self.subs.append('[sub_resource type="%s" id="%s"]\n' % (text[0], sid) + text[1])
        return 'SubResource("%s")' % sid

    def node(self, name, typ=None, parent=".", instance=None, props=None):
        head = '[node name="%s"' % name
        if typ:
            head += ' type="%s"' % typ
        if parent is not None:
            head += ' parent="%s"' % parent
        if instance:
            head += ' instance=%s' % self.res(instance, "PackedScene")
        head += "]"
        lines = [head]
        for k, v in (props or {}).items():
            lines.append("%s = %s" % (k, v))
        self.nodes.append("\n".join(lines))

    def text(self):
        out = ["[gd_scene format=3]", ""]
        for path, (rid, typ) in self.ext.items():
            out.append('[ext_resource type="%s" path="%s" id="%s"]' % (typ, path, rid))
        out.append("")
        for s in self.subs:
            out.append(s)
        for n in self.nodes:
            out.append(n)
            out.append("")
        return "\n".join(out)


def v2(x, y):
    return "Vector2(%g, %g)" % (x, y)


def col(r, g, b, a=1.0):
    return "Color(%g, %g, %g, %g)" % (r, g, b, a)


def gstr(s):
    return '"%s"' % s.replace('"', '\\"')


HINT_PROPS = {
    "theme_override_colors/font_color": col(0.88, 0.95, 1, 0.95),
    "theme_override_colors/font_outline_color": col(0.03, 0.05, 0.08, 0.9),
    "theme_override_constants/outline_size": "4",
    "theme_override_font_sizes/font_size": "13",
}


def base(level_name, theme, rows, flow=(1, 0)):
    s = Scene()
    s.node("Level", "Node2D", parent=None, props={
        "script": s.res("res://scripts/topdown/td_level.gd", "Script"),
        "level_name": gstr(level_name), "theme": gstr(theme)})
    s.node("Blocks", "Node2D")
    s.node("Terrain", "Node2D", "Blocks", props={
        "script": s.res("res://scripts/topdown/td_terrain.gd", "Script"),
        "rows": "PackedStringArray(%s)" % ", ".join(gstr(r) for r in rows),
        "flow": v2(*flow)})
    s.node("Zones", "Node2D")
    s.node("Props", "Node2D")
    s.node("Decor", "Node2D")
    return s


def hint(s, name, x, y, w, text, align=0):
    p = {"offset_left": x, "offset_top": y, "offset_right": x + w, "offset_bottom": y + 20}
    p.update(HINT_PROPS)
    if align:
        p["horizontal_alignment"] = str(align)
    p["text"] = gstr(text)
    s.node(name, "Label", "Hints", props=p)


def sprite(s, name, tex, x, y, parent="Decor", extra=None):
    p = {"position": v2(x, y), "texture": s.res(tex, "Texture2D")}
    if extra:
        p.update(extra)
    s.node(name, "Sprite2D", parent, props=p)


def glow(s, name, x, y, color, scale=1.5, parent="Decor"):
    mat = s.sub(("CanvasItemMaterial", "blend_mode = 1\n"))
    sprite(s, name, "res://assets/interactive/ix_glow.png", x, y, parent, {
        "modulate": color, "scale": v2(scale, scale), "texture_filter": "2", "material": mat,
        "z_index": "3"})


def pipe_h(s, name, x, y, length, parent="Decor"):
    """Horizontal run of the 8x8 vertical pipe tile, rotated."""
    sprite(s, name, "res://assets/interactive/ix_pipe_v.png", x, y, parent, {
        "rotation": "1.5708", "centered": "false", "region_enabled": "true",
        "region_rect": "Rect2(0, 0, 8, %d)" % length, "texture_repeat": "2", "z_index": "1"})


def pipe_v(s, name, x, y, length, parent="Decor"):
    sprite(s, name, "res://assets/interactive/ix_pipe_v.png", x, y, parent, {
        "centered": "false", "region_enabled": "true",
        "region_rect": "Rect2(0, 0, 8, %d)" % length, "texture_repeat": "2", "z_index": "1"})


def finish(s, player_cell, player_state, path):
    s.node("Vignette", "Sprite2D", props={
        "z_index": "20", "texture_filter": "2", "position": v2(480, 270), "scale": v2(10, 10),
        "texture": s.res("res://assets/topdown/td_vignette.png", "Texture2D")})
    s.node("Player", parent=".", instance="res://scenes/topdown/td_player.tscn", props={
        "position": v2(player_cell[0] * C + 16, player_cell[1] * C + 16), "state": str(player_state)})
    open(ROOT + path, "w", newline="\n").write(s.text())
    print("wrote", path)


# =============================================================================== chapter 2
CH2 = """
##############################
##############################
#.....#^^#.....##......#######
#.##..#^^#.o.......o...#######
#.##...^^#.............###...#
#......^^#..#...o......###...#
#......^^.........#...##..|..#
#.##...^^#.............#..|..#
#.##...^^#..o..#.......#..|..#
#......^^#.............###...#
#......^^#...o.........###...#
#.##...^^#.......#.....#######
#.##...^^#.............#######
#......^^#.##.......o..#######
#.....#^^#.......#.....#######
##############################
##############################
""".strip("\n").split("\n")


def ch2():
    rows = [list(r) for r in CH2]
    rows[7][23] = "."          # under the exit gate
    for y in (6, 7, 8):
        rows[y][26] = "."      # under the bars
    s = base("2 - Freeze", "lab", ["".join(r) for r in rows])
    # cold room: forced ICE
    s.node("ColdRoom", parent="Zones", instance="res://scenes/topdown/td_freeze.tscn", props={
        "position": v2(10 * C, 2 * C), "size": v2(13 * C, 13 * C)})
    s.node("Goal", parent="Zones", instance="res://scenes/topdown/td_goal.tscn", props={
        "position": v2(27 * C, 6 * C), "size": v2(64, 64)})
    s.node("ColdPlate", parent="Props", instance="res://scenes/topdown/td_plate.tscn", props={
        "position": v2(22 * C, 10 * C), "channel": '"exit"'})
    s.node("ExitGate", parent="Blocks", instance="res://scenes/topdown/td_gate.tscn", props={
        "position": v2(23 * C, 7 * C), "channel": '"exit"', "size": v2(32, 32)})
    s.node("ExitBars", parent="Blocks", instance="res://scenes/topdown/td_bars.tscn", props={
        "position": v2(26 * C, 6 * C), "size": v2(32, 96)})
    decor_ch2(s)
    s.node("Hints", "Node2D", props={"z_index": "30"})
    hint(s, "Hint1", 36, 20, 420, "Top-down: WASD to move.  ICE slides until it hits something.")
    hint(s, "Hint2", 36, 66, 200, "Q / CTRL  cool down", 0)
    hint(s, "Hint3", 40, 424, 180, "ICE doesn't mind spikes")
    hint(s, "Hint4", 560, 20, 300, "Plates need heavy ICE - stop on it", 0)
    hint(s, "Hint5", 760, 380, 190, "E / SHIFT  heat up\nWATER slips through bars", 0)
    finish(s, (3, 6), 1, "levels/level_02_topdown.tscn")


# =============================================================================== chapter 7
CH7 = """
##############################
##############################
#....#..o...#~~~..~~~~~#.....#
#....#......#~~~..~~~~~#.....#
#....#~~~.~~#~~~~~~~~~~#.....#
#....#~~~.~~#..~~~~~~~~#.....#
#....#..o...#..~~~~~~~~#.....#
#....#..o...#~~~~~~~~~~#.....#
######......#~##~~~~~~~#######
#.....#######~~~~~~~~~~~~~~~~#
#...........#~~~~~~~~~~~~~~~~#
#...~~~.....#~~...~~~~~~.....#
#...~~~.....#~~.o.~~~~~~.....#
#...........#~~~~~~~~~~~~~~~~#
#.....##....#~~~~~~~~~~~~~~~~#
##############################
##############################
""".strip("\n").split("\n")


def ch7():
    rows = [list(r) for r in CH7]
    # bars (col 5 rows 3-5) and mesh (col 12 rows 11-13) stand on floor cells
    for y in (3, 4, 5):
        rows[y][5] = "."
    for y in (11, 12, 13):
        rows[y][12] = "."
    s = base("7 - Sieve", "sewer", ["".join(r) for r in rows])
    s.node("StartBars", parent="Blocks", instance="res://scenes/topdown/td_bars.tscn", props={
        "position": v2(5 * C, 3 * C), "size": v2(32, 96)})
    s.node("VentMesh", parent="Blocks", instance="res://scenes/topdown/td_mesh.tscn", props={
        "position": v2(12 * C, 11 * C), "size": v2(32, 96)})
    s.node("HotGrate", parent="Zones", instance="res://scenes/topdown/td_heat.tscn", props={
        "position": v2(9 * C, 11 * C), "size": v2(96, 96)})
    s.node("CryoLeak", parent="Zones", instance="res://scenes/topdown/td_freeze.tscn", props={
        "position": v2(17 * C, 2 * C), "size": v2(6 * C, 6 * C)})
    s.node("UpdraftFan", parent="Zones", instance="res://scenes/topdown/td_fan.tscn", props={
        "position": v2(19 * C, 9 * C), "size": v2(3 * C, 6 * C), "push_direction": v2(0, -1),
        "push_strength": "850.0"})
    s.node("Goal", parent="Zones", instance="res://scenes/topdown/td_goal.tscn", props={
        "position": v2(25 * C, 2 * C), "size": v2(96, 96)})
    s.node("DrainA", parent="Props", instance="res://scenes/topdown/td_drain.tscn", props={
        "position": v2(10 * C, 7 * C), "target": 'NodePath("../DrainA2")', "tint": col(0.4, 0.85, 1)})
    s.node("DrainA2", parent="Props", instance="res://scenes/topdown/td_drain.tscn", props={
        "position": v2(1 * C, 9 * C), "target": 'NodePath("../DrainA")', "tint": col(0.4, 0.85, 1)})
    s.node("DrainB", parent="Props", instance="res://scenes/topdown/td_drain.tscn", props={
        "position": v2(26 * C, 11 * C), "target": 'NodePath("../DrainB2")', "tint": col(1, 0.75, 0.3)})
    s.node("DrainB2", parent="Props", instance="res://scenes/topdown/td_drain.tscn", props={
        "position": v2(26 * C, 7 * C), "target": 'NodePath("../DrainB")', "tint": col(1, 0.75, 0.3)})
    decor_ch7(s)
    s.node("Hints", "Node2D", props={"z_index": "30"})
    hint(s, "Hint1", 20, 20, 260, "WATER slips through bars")
    hint(s, "Hint2", 196, 56, 200, "Drains connect - flow in!")
    hint(s, "Hint3", 128, 300, 250, "Hot grates force STEAM\nSTEAM drifts through vents")
    hint(s, "Hint4", 450, 20, 330, "STEAM floats over sewage. Mind the fan!")
    hint(s, "Hint5", 760, 456, 200, "Q  cool down on dry land", 0)
    finish(s, (2, 4), 1, "levels/level_07_topdown.tscn")


IX = "res://assets/interactive/"
LAB = "res://assets/env_lab/"
SEW = "res://assets/env_sewer/"


def ix(s, name, tex, x, y, z=2, extra=None):
    e = {"z_index": str(z)}
    if extra:
        e.update(extra)
    sprite(s, name, tex, x, y, "Decor", e)


def decor_ch2(s):
    # north wall: pipe runs, plates, vents
    pipe_h(s, "PipeN1", 920, 14, 880)
    for i, (x, tex) in enumerate([(96, "e1c_decal_number_plate"), (250, "e1c_decal_vent_slit"),
                                  (470, "e1c_decal_warning_stripe"), (690, "e1c_decal_vent_slit"),
                                  (860, "e1c_decal_number_plate")]):
        ix(s, "WallDecal%d" % i, LAB + tex + ".png", x, 42, 1)
    # bottom wall: pipes + cables
    pipe_h(s, "PipeS1", 940, 498, 900)
    ix(s, "CablesS1", LAB + "e1c_decal_cable_bundle.png", 130, 520, 1)
    ix(s, "CablesS2", LAB + "e1c_decal_cable_bundle.png", 830, 520, 1)
    # start area lab benches (2x2 wall blocks): monitors, flasks, papers
    ix(s, "Monitor1", IX + "ix_monitor.png", 96, 108)
    ix(s, "Flask1", IX + "ix_flask_1.png", 78, 240)
    ix(s, "Flask2", IX + "ix_flask_2.png", 94, 238)
    ix(s, "Flask3", IX + "ix_flask_3.png", 108, 242)
    ix(s, "Paper1", IX + "ix_paper_1.png", 84, 366)
    ix(s, "Paper2", IX + "ix_paper_2.png", 100, 372)
    ix(s, "Lamp1", IX + "ix_lamp_shade.png", 110, 364)
    ix(s, "Arrow", IX + "ix_sign_arrow.png", 214, 208, 1, {"flip_h": "true"})
    # cold room: frost on the pillars, cryo glows
    for i, (cx, cy) in enumerate([(12, 5), (18, 6), (15, 8), (17, 11), (12, 13)]):
        ix(s, "Frost%d" % i, LAB + "e1c_decal_frost_patch.png", cx * C + 16, cy * C + 12, 1)
    glow(s, "ColdGlow1", 430, 170, col(0.4, 0.75, 1, 0.35), 3.0)
    glow(s, "ColdGlow2", 640, 400, col(0.4, 0.75, 1, 0.3), 3.0)
    glow(s, "LabGlow", 110, 300, col(1, 0.9, 0.7, 0.18), 3.0)
    glow(s, "GoalGlow", 880, 224, col(0.4, 1, 0.6, 0.35), 2.5)
    glow(s, "PlateGlow", 720, 336, col(0.5, 0.85, 1, 0.3), 1.2)
    # exit block: control desk
    ix(s, "Monitor2", IX + "ix_monitor.png", 800, 102)
    ix(s, "Valve", IX + "ix_valve_wheel_2f.png", 880, 400, 2, {"hframes": "2"})
    ix(s, "Tube1", IX + "ix_tube_lamp.png", 880, 116, 2)
    ix(s, "Tube2", IX + "ix_tube_lamp.png", 816, 380, 2)


def decor_ch7(s):
    pipe_h(s, "PipeN1", 940, 12, 900)
    pipe_h(s, "PipeS1", 940, 500, 900)
    for i, (x, y, tex) in enumerate([(120, 44, "e1c_decal_moss"), (300, 40, "e1c_decal_number_plate"),
                                     (470, 44, "e1c_decal_drain"), (640, 40, "e1c_decal_moss"),
                                     (900, 42, "e1c_decal_vent_slit"), (200, 520, "e1c_decal_moss"),
                                     (560, 518, "e1c_decal_cable_bundle"), (720, 268, "e1c_decal_moss"),
                                     (400, 140, "e1c_decal_drain"), (400, 270, "e1c_decal_moss"),
                                     (80, 268, "e1c_decal_number_plate"), (868, 262, "e1c_decal_moss")]):
        ix(s, "WallDecal%d" % i, SEW + tex + ".png", x, y, 1)
    # outflow pipes spilling into the pool
    for i, x in enumerate([430, 530, 600]):
        ix(s, "Outflow%d" % i, IX + "ix_nozzle.png", x, 54, 2)
    # floor litter
    for i, (x, y, tex) in enumerate([(60, 120, "ix_leaf_1"), (130, 210, "ix_paper_2"), (230, 250, "ix_leaf_2"),
                                     (330, 100, "ix_leaf_1"), (90, 420, "ix_paper_3"), (250, 450, "ix_leaf_2"),
                                     (300, 330, "ix_leaf_1"), (870, 120, "ix_paper_1"), (900, 380, "ix_leaf_2")]):
        ix(s, "Litter%d" % i, IX + tex + ".png", x, y, 1)
    for i, (x, y) in enumerate([(60, 100), (380, 330), (880, 330)]):
        ix(s, "WallLamp%d" % i, IX + "ix_wall_lamp.png", x, y - 50 if y == 100 else y - 60, 2)
    glow(s, "Glow1", 90, 130, col(0.9, 0.95, 0.6, 0.22), 3.0)
    glow(s, "Glow2", 300, 380, col(1, 0.5, 0.2, 0.3), 2.5)
    glow(s, "Glow3", 620, 180, col(0.5, 0.85, 1, 0.3), 3.5)
    glow(s, "Glow4", 830, 120, col(0.4, 1, 0.6, 0.35), 3.0)
    glow(s, "Glow5", 600, 420, col(0.4, 0.9, 0.7, 0.15), 4.0)
    ix(s, "Valve", IX + "ix_valve_wheel_2f.png", 760, 264, 2, {"hframes": "2"})


if __name__ == "__main__":
    ch2()
    ch7()
