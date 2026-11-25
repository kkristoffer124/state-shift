"""Builds SpriteFrames resources from the animation strips (run with `python -I`).

Writes assets/anim/water_frames.tres and assets/anim/ice_frames.tres.
Re-run after replacing a strip; the .tres files are plain Godot resources.
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))

SETS = {
    "water_frames.tres": [
        # name, file, frames, fps, loop
        ("idle", "water/p2_water_idle_8f.png", 8, 8, True),
        ("move", "water/p2_water_move_8f.png", 8, 12, True),
        ("jump", "water/p2_water_jump_7f.png", 7, 16, False),
        ("land", "water/p2_water_land_7f.png", 7, 16, False),
        ("grate", "water/p2_water_grate_12f.png", 12, 12, False),
    ],
    "ice_frames.tres": [
        ("idle", "ice/p1_ice_idle_8f.png", 8, 8, True),
        ("fall", "ice/p1_ice_fall_4f.png", 4, 12, True),
        ("land", "ice/p1_ice_land_6f.png", 6, 16, False),
        ("slide", "ice/p1_ice_slide_6f.png", 6, 12, True),
        ("stop", "ice/p1_ice_stop_5f.png", 5, 12, False),
    ],
}

for out, anims in SETS.items():
    ext, subs, blocks = [], [], []
    for ai, (name, path, n, fps, loop) in enumerate(anims):
        w, h = Image.open(os.path.join(HERE, path)).size
        fw = w // n
        rid = f"t{ai}"
        ext.append(f'[ext_resource type="Texture2D" path="res://assets/anim/{path}" id="{rid}"]')
        frames = []
        for i in range(n):
            sid = f"{name}_{i}"
            subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{rid}")\nregion = Rect2({i * fw}, 0, {fw}, {h})\n')
            frames.append(f'{{"duration": 1.0, "texture": SubResource("{sid}")}}')
        blocks.append('{\n"frames": [' + ", ".join(frames) + f'],\n"loop": {"true" if loop else "false"},\n"name": &"{name}",\n"speed": {float(fps)}\n}}')
    text = "[gd_resource type=\"SpriteFrames\" format=3]\n\n" + "\n".join(ext) + "\n\n" + "\n".join(subs) + "\n[resource]\nanimations = [" + ", ".join(blocks) + "]\n"
    with open(os.path.join(HERE, out), "w", encoding="utf-8") as f:
        f.write(text)
    print("wrote", out)
