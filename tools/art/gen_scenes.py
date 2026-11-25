"""Builds the reusable decoration scenes in scenes/deco/ (python -I tools/art/gen_scenes.py).

Origin conventions (so props are easy to drag around in the editor):
  floor props   -> bottom-centre (drop the origin on a floor's top edge)
  wall props    -> centre
  ceiling props -> top-centre (drop on a ceiling's bottom edge)
  strips        -> top-left, root is a DecoStrip: set `length` (and `row` for grime)
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tscn import Scene, v2, col, rect2, s  # noqa
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SC = os.path.join(ROOT, "scenes", "deco")
os.makedirs(SC, exist_ok=True)

TEX = "res://assets/deco/%s.png"
S_STRIP = "res://scripts/deco/deco_strip.gd"
S_ANIM = "res://scripts/deco/deco_anim.gd"
S_MOTION = "res://scripts/deco/deco_motion.gd"
S_SPARKS = "res://scripts/deco/deco_sparks.gd"
ADD = "res://scenes/deco/additive.tres"


def tex_size(name):
    return Image.open(os.path.join(ROOT, "assets", "deco", name + ".png")).size


# name -> footprint used by gen_dressing (w, h, anchor)
FOOT = {}


def add_mat(sc):
    return sc.ext_res("Material", ADD)


def glow_child(sc, parent, name, color, pos=(0, 0), big=False, scale=1.0, pulse=None, flicker=0.0):
    p = {
        "material": add_mat(sc),
        "modulate": color,
        "position": v2(*pos),
        "texture": sc.ext_res("Texture2D", TEX % ("glow_big" if big else "glow_soft")),
        "texture_filter": "2",
    }
    if scale != 1.0:
        p["scale"] = v2(scale, scale)
    if pulse or flicker:
        p["script"] = sc.ext_res("Script", S_MOTION)
        if pulse:
            p["pulse_min"], p["pulse_max"], p["pulse_speed"] = str(pulse[0]), str(pulse[1]), str(pulse[2])
            p["modulate"] = color
        if flicker:
            p["flicker"] = str(flicker)
    sc.node(name, "Sprite2D", parent, p)


def sprite_scene(name, tex, frames=1, anchor="bottom", anim=None, variants=False, children=None, modulate=None):
    w, h = tex_size(tex)
    fw = w // frames
    sc = Scene()
    p = {"texture": sc.ext_res("Texture2D", TEX % tex)}
    if frames > 1:
        p["hframes"] = str(frames)
    p["centered"] = "false"
    if anchor == "bottom":
        p["offset"] = v2(-(fw // 2), -h)
    elif anchor == "top":
        p["offset"] = v2(-(fw // 2), 0)
    elif anchor == "center":
        p["offset"] = v2(-(fw // 2), -(h // 2))
    if modulate:
        p["modulate"] = modulate
    if anim:
        p["script"] = sc.ext_res("Script", S_ANIM)
        for k, v in anim.items():
            p[k] = v
    sc.node(name_to_node(name), "Sprite2D", None, p)
    if children:
        children(sc, fw, h)
    sc.save(os.path.join(SC, name + ".tscn"))
    FOOT[name] = (fw, h, anchor)


def name_to_node(n):
    return "".join(w.capitalize() for w in n.split("_"))


def strip_scene(name, tex, vertical=False, length=64, row_height=0, modulate=None, z=None):
    w, h = tex_size(tex)
    sc = Scene()
    p = {"texture": sc.ext_res("Texture2D", TEX % tex), "centered": "false",
         "texture_repeat": "2", "region_enabled": "true",
         "region_rect": rect2(0, 0, w if vertical else length, length if vertical else (row_height or h)),
         "script": sc.ext_res("Script", S_STRIP), "length": str(length)}
    if vertical:
        p["vertical"] = "true"
    if row_height:
        p["row_height"] = str(row_height)
    if modulate:
        p["modulate"] = modulate
    sc.node(name_to_node(name), "Sprite2D", None, p)
    sc.save(os.path.join(SC, name + ".tscn"))
    FOOT[name] = (w, h, "strip")


def write_additive():
    with open(os.path.join(SC, "additive.tres"), "w", newline="\n") as f:
        f.write('[gd_resource type="CanvasItemMaterial" format=3]\n\n[resource]\nblend_mode = 1\n')


def main():
    write_additive()
    # ---------------- floor props
    for t in ("tank_specimen", "tank_plain"):
        sprite_scene(t, t + "_6f", 6, "bottom", {"fps": "5.0"})
    for t, g in (("tank_big", col(0.3, 0.8, 0.85, 0.12)), ("tank_hot", col(1, 0.45, 0.15, 0.16)), ("tank_algae", col(0.35, 0.95, 0.6, 0.12))):
        def kids(sc, w, h, g=g):
            glow_child(sc, ".", "Glow", g, (0, -h // 2), scale=1.2, pulse=(0.7, 1.0, 1.3))
        sprite_scene(t, t + "_6f", 6, "bottom", {"fps": "4.0"}, children=kids)
    sprite_scene("server_rack", "server_rack_4f", 4, "bottom", {"fps": "2.5", "random_frames": "true"})
    for t in ("terminal", "terminal_amber"):
        gc = col(0.4, 0.85, 0.95, 0.12) if t == "terminal" else col(1, 0.6, 0.25, 0.12)

        def kids(sc, w, h, gc=gc):
            glow_child(sc, ".", "ScreenGlow", gc, (-1, -h + 15), scale=0.7, flicker=0.15)
        sprite_scene(t, t + "_4f", 4, "bottom", {"fps": "3.0"}, children=kids)
    sprite_scene("crate", "crate_2v", 2, "bottom")
    sprite_scene("crate_small", "crate_small", 1, "bottom")
    sprite_scene("barrel", "barrel_3v", 3, "bottom")
    sprite_scene("shelf_jars", "shelf_jars_3v", 3, "bottom")
    sprite_scene("locker", "locker_2v", 2, "bottom")
    sprite_scene("lab_bench", "lab_bench", 1, "bottom")
    sprite_scene("floor_debris", "floor_debris_4v", 4, "bottom")
    sprite_scene("desk_clutter", "desk_clutter_2v", 2, "bottom")

    def boiler_kids(sc, w, h):
        glow_child(sc, ".", "FireGlow", col(1, 0.45, 0.12, 0.3), (0, -22), scale=0.9, pulse=(0.6, 1.0, 5.0))
    sprite_scene("boiler", "boiler_4f", 4, "bottom", {"fps": "7.0", "random_frames": "true"}, children=boiler_kids)

    def coil_kids(sc, w, h):
        glow_child(sc, ".", "CoilGlow", col(1, 0.4, 0.12, 0.22), (0, -h // 2), big=True, scale=0.8, pulse=(0.5, 1.0, 3.0))
    sprite_scene("coil", "coil_4f", 4, "bottom", {"fps": "4.0"}, children=coil_kids)

    # ---------------- wall props (centre)
    sprite_scene("sign", "signs_12v", 12, "center")
    sprite_scene("poster", "poster_2v", 2, "center")
    sprite_scene("whiteboard", "whiteboard", 1, "center")

    def mon_kids(sc, w, h):
        glow_child(sc, ".", "Glow", col(0.4, 0.9, 0.9, 0.1), (0, -6), scale=0.9)
    sprite_scene("monitor_wall", "monitor_wall_6f", 6, "center", {"fps": "5.0"}, children=mon_kids)
    sprite_scene("vent", "vent_4f", 4, "center", {"fps": "1.5"})
    sprite_scene("gauge", "gauge_4f", 4, "center", {"fps": "5.0", "random_frames": "true"})
    sprite_scene("valve", "valve", 1, "center")
    sprite_scene("wall_panel", "wall_panel_2v", 2, "center")
    sprite_scene("wall_crack", "wall_crack_3v", 3, "center")
    sprite_scene("rust_drip", "rust_drip_2v", 2, "top")
    sprite_scene("scorch", "scorch", 1, "center")
    sprite_scene("frost_patch", "frost_patch", 1, "center")
    sprite_scene("moss_patch", "moss_patch", 1, "center")
    # wall label: 12 bands stacked vertically
    sc = Scene()
    sc.node("WallLabel", "Sprite2D", None, {"texture": sc.ext_res("Texture2D", TEX % "wall_labels_12v"), "vframes": "12"})
    sc.save(os.path.join(SC, "wall_label.tscn"))
    FOOT["wall_label"] = (48, 12, "center")

    # wall fan: housing + spinning blades
    sc = Scene()
    sc.node("WallFan", "Sprite2D", None, {"texture": sc.ext_res("Texture2D", TEX % "fan_housing")})
    sc.node("Blades", "Sprite2D", ".", {"texture": sc.ext_res("Texture2D", TEX % "fan_blades"),
                                        "script": sc.ext_res("Script", S_MOTION), "spin_speed": "7.0"})
    sc.save(os.path.join(SC, "wall_fan.tscn"))
    FOOT["wall_fan"] = (40, 40, "center")
    # big background fan (wind tunnels)
    sc = Scene()
    sc.node("BigFan", "Node2D", None, {})
    sc.node("Ring", "Sprite2D", ".", {"texture": sc.ext_res("Texture2D", TEX % "gear_64"), "scale": v2(1.6, 1.6), "modulate": col(0.55, 0.6, 0.7, 1)})
    sc.node("Blades", "Sprite2D", ".", {"texture": sc.ext_res("Texture2D", TEX % "fan_blades_big"),
                                        "script": sc.ext_res("Script", S_MOTION), "spin_speed": "2.5"})
    sc.save(os.path.join(SC, "big_fan.tscn"))
    FOOT["big_fan"] = (100, 100, "center")
    for g, spd in (("gear_20", 1.6), ("gear_32", -1.0), ("gear_64", 0.5)):
        sc = Scene()
        sc.node(name_to_node(g), "Sprite2D", None, {"texture": sc.ext_res("Texture2D", TEX % g),
                                                    "script": sc.ext_res("Script", S_MOTION), "spin_speed": str(spd)})
        sc.save(os.path.join(SC, g + ".tscn"))
        FOOT[g] = (int(g.split("_")[1]),) * 2 + ("center",)

    # exit sign (flickers) + green glow
    def exit_kids(sc, w, h):
        glow_child(sc, ".", "Glow", col(0.4, 1, 0.6, 0.35), (0, 0), scale=1.0)
    sprite_scene("exit_sign", "exit_sign_2f", 2, "center",
                 {"fps": "12.0", "hold_first": "4.0", "hold_jitter": "0.6", "linked": 'Array[NodePath]([NodePath("Glow")])'},
                 children=exit_kids)

    def beacon_kids(sc, w, h):
        glow_child(sc, ".", "Glow", col(1, 0.25, 0.15, 0.45), (0, -1), scale=1.1)
    sprite_scene("beacon", "beacon_2f", 2, "center",
                 {"fps": "1.6", "linked": 'Array[NodePath]([NodePath("Glow")])'}, children=beacon_kids)

    # generic glows (tint via modulate rgb on the instance; alpha pulses)
    for gname, tex, pulse in (("glow", "glow_soft", (0.8, 1.0, 1.5)), ("glow_big", "glow_big", (0.75, 1.0, 1.1))):
        sc = Scene()
        sc.node(name_to_node(gname), "Sprite2D", None, {
            "material": add_mat(sc), "texture": sc.ext_res("Texture2D", TEX % tex), "texture_filter": "2",
            "modulate": col(0.5, 0.85, 1, 0.2),
            "script": sc.ext_res("Script", S_MOTION),
            "pulse_min": str(pulse[0]), "pulse_max": str(pulse[1]), "pulse_speed": str(pulse[2])})
        sc.save(os.path.join(SC, gname + ".tscn"))
        FOOT[gname] = (64, 64, "center")

    # ---------------- ceiling props (top-centre)
    sc = Scene()
    sc.node("Lamp", "Node2D", None, {})
    sc.node("Cone", "Sprite2D", ".", {"material": add_mat(sc), "modulate": col(1, 0.9, 0.7, 0.16),
                                      "position": v2(0, 13), "texture": sc.ext_res("Texture2D", TEX % "light_cone"),
                                      "texture_filter": "2", "centered": "false", "offset": v2(-48, 0)})
    sc.node("Pool", "Sprite2D", ".", {"material": add_mat(sc), "modulate": col(1, 0.9, 0.7, 0.1),
                                      "position": v2(0, 14), "texture": sc.ext_res("Texture2D", TEX % "glow_soft"),
                                      "texture_filter": "2", "scale": v2(0.6, 0.35)})
    sc.node("Body", "Sprite2D", ".", {"texture": sc.ext_res("Texture2D", TEX % "lamp_ceiling_2f"), "hframes": "2",
                                      "centered": "false", "offset": v2(-12, 0),
                                      "script": sc.ext_res("Script", S_ANIM), "fps": "14.0", "hold_first": "6.0",
                                      "hold_jitter": "0.8",
                                      "linked": 'Array[NodePath]([NodePath("../Cone"), NodePath("../Pool")])'})
    sc.save(os.path.join(SC, "lamp.tscn"))
    FOOT["lamp"] = (24, 14, "top")
    for cname, tex in (("cable_hang", "cable_hang"), ("cable_hang_long", "cable_hang_long")):
        w, h = tex_size(tex)
        sc = Scene()
        sc.node(name_to_node(cname), "Sprite2D", None, {"texture": sc.ext_res("Texture2D", TEX % tex), "centered": "false",
                                                        "offset": v2(-6, 0), "script": sc.ext_res("Script", S_MOTION),
                                                        "sway_degrees": "2.5", "sway_speed": "0.9"})
        sc.save(os.path.join(SC, cname + ".tscn"))
        FOOT[cname] = (w, h, "top")
    for cname, L in (("chain", 48), ("chain_long", 112)):
        sc = Scene()
        sc.node(name_to_node(cname), "Node2D", None, {"script": sc.ext_res("Script", S_MOTION),
                                                      "sway_degrees": "1.5", "sway_speed": "0.7"})
        sc.node("Links", "Sprite2D", ".", {"texture": sc.ext_res("Texture2D", TEX % "chain_tile"), "centered": "false",
                                            "texture_repeat": "2", "region_enabled": "true",
                                            "region_rect": rect2(0, 0, 6, L), "position": v2(-3, 0),
                                            "script": sc.ext_res("Script", S_STRIP), "length": str(L), "vertical": "true"})
        sc.node("Hook", "Sprite2D", ".", {"texture": sc.ext_res("Texture2D", TEX % "chain_hook"), "centered": "false",
                                           "position": v2(-5, L)})
        sc.save(os.path.join(SC, cname + ".tscn"))
        FOOT[cname] = (10, L + 12, "top")
    for w in (64, 128, 192):
        n = "cable_droop_%d" % w
        sprite_scene(n, n, 1, "topleft")

    # ---------------- strips
    strip_scene("pipe_h", "pipe_h", length=128)
    strip_scene("pipe_v", "pipe_v", vertical=True, length=128)
    strip_scene("pipe_h_thin", "pipe_h_thin", length=128)
    strip_scene("pipe_v_thin", "pipe_v_thin", vertical=True, length=128)
    strip_scene("pipe_h_big", "pipe_h_big", length=192)
    strip_scene("ladder", "ladder_tile", vertical=True, length=96)
    strip_scene("rail", "rail_tile", length=128)
    strip_scene("girder", "girder_tile", length=128)
    strip_scene("trim", "trim_rivets", length=128)
    strip_scene("hazard_strip", "hazard_strip", length=128)
    strip_scene("grime_strip", "grime_strip_5v", length=128, row_height=16)
    strip_scene("fg_pipe_v", "fg_pipe_v", vertical=True, length=256)
    strip_scene("fg_girder", "fg_girder", length=256)
    sprite_scene("fg_cables", "fg_cables", 1, "topleft")
    sprite_scene("fg_machine", "fg_machine_2v", 2, "bottom")

    # ---------------- particle fx
    sc = Scene()
    grad = sc.sub("Gradient", {"offsets": "PackedFloat32Array(0, 0.25, 1)",
                               "colors": "PackedColorArray(0.85, 0.92, 1, 0, 0.85, 0.92, 1, 0.3, 0.85, 0.92, 1, 0)"})
    curve = sc.sub("Curve", {"_data": "[Vector2(0, 0.4), 0.0, 0.0, 0, 0, Vector2(1, 1), 0.0, 0.0, 0, 0]", "point_count": "2"})
    sc.node("SteamVent", "Node2D", None, {})
    sc.node("Pipe", "Sprite2D", ".", {"texture": sc.ext_res("Texture2D", TEX % "vent_4f"), "hframes": "4", "scale": v2(0.5, 0.5)})
    sc.node("Puffs", "CPUParticles2D", ".", {
        "amount": "7", "lifetime": "2.2", "preprocess": "2.0", "texture": sc.ext_res("Texture2D", TEX % "steam_puff"),
        "emission_shape": "3", "emission_rect_extents": v2(4, 1), "direction": v2(0, -1), "spread": "12.0",
        "gravity": v2(6, -18), "initial_velocity_min": "18.0", "initial_velocity_max": "32.0",
        "scale_amount_min": "1.0", "scale_amount_max": "2.0", "scale_amount_curve": curve, "color_ramp": grad})
    sc.save(os.path.join(SC, "steam_vent.tscn"))
    FOOT["steam_vent"] = (16, 10, "center")

    sc = Scene()
    grad = sc.sub("Gradient", {"offsets": "PackedFloat32Array(0, 0.7, 1)",
                               "colors": "PackedColorArray(1, 1, 0.8, 1, 1, 0.6, 0.2, 1, 1, 0.4, 0.1, 0)"})
    sc.node("Sparks", "Node2D", None, {})
    sc.node("Flash", "Sprite2D", ".", {"material": add_mat(sc), "modulate": col(1, 0.75, 0.35, 0.6),
                                       "texture": sc.ext_res("Texture2D", TEX % "glow_soft"), "texture_filter": "2",
                                       "visible": "false"})
    sc.node("Burst", "CPUParticles2D", ".", {
        "emitting": "false", "amount": "10", "lifetime": "0.55", "one_shot": "true", "explosiveness": "0.9",
        "texture": sc.ext_res("Texture2D", TEX % "spark"), "direction": v2(0, 1), "spread": "75.0",
        "gravity": v2(0, 420), "initial_velocity_min": "50.0", "initial_velocity_max": "130.0", "color_ramp": grad,
        "script": sc.ext_res("Script", S_SPARKS), "flash": 'NodePath("../Flash")'})
    sc.save(os.path.join(SC, "sparks.tscn"))
    FOOT["sparks"] = (8, 8, "center")

    sc = Scene()
    grad = sc.sub("Gradient", {"offsets": "PackedFloat32Array(0, 0.8, 1)",
                               "colors": "PackedColorArray(0.6, 0.85, 1, 0.9, 0.6, 0.85, 1, 0.8, 0.6, 0.85, 1, 0)"})
    sc.node("Drips", "CPUParticles2D", None, {
        "amount": "3", "lifetime": "1.1", "preprocess": "1.0", "texture": sc.ext_res("Texture2D", TEX % "drip_drop"),
        "emission_shape": "3", "emission_rect_extents": v2(48, 1), "direction": v2(0, 1), "spread": "0.0",
        "gravity": v2(0, 420), "initial_velocity_min": "0.0", "initial_velocity_max": "10.0", "color_ramp": grad})
    sc.save(os.path.join(SC, "drips.tscn"))
    FOOT["drips"] = (96, 2, "center")

    # composite: desk with clutter
    sc = Scene()
    sc.node("LabDesk", "Node2D", None, {})
    sc.node("Bench", "Sprite2D", ".", {"texture": sc.ext_res("Texture2D", TEX % "lab_bench"), "offset": v2(0, -12)})
    sc.node("Clutter", "Sprite2D", ".", {"texture": sc.ext_res("Texture2D", TEX % "desk_clutter_2v"), "hframes": "2",
                                         "position": v2(-12, -24), "offset": v2(0, -8)})
    sc.node("Clutter2", "Sprite2D", ".", {"texture": sc.ext_res("Texture2D", TEX % "desk_clutter_2v"), "hframes": "2",
                                          "frame": "1", "position": v2(16, -24), "offset": v2(0, -8)})
    sc.save(os.path.join(SC, "lab_desk.tscn"))
    FOOT["lab_desk"] = (64, 40, "bottom")

    # backdrop layer scenes are generated per level by gen_dressing.py
    with open(os.path.join(os.path.dirname(__file__), "footprints.py"), "w") as f:
        f.write("# generated by gen_scenes.py\nFOOT = %r\n" % FOOT)
    print("scenes:", len(FOOT))


if __name__ == "__main__":
    main()
