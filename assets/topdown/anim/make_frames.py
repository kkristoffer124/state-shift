"""Builds the top-down blob SpriteFrames from the strips in this folder (run with `python -I`).

Reads manifest.txt (frame count / fps / loop per strip) and writes:
  td_ice_frames.tres    idle, slide_n/e/s/w, impact_n/e/s/w
  td_water_frames.tres  idle, move_n/e/s/w
  td_steam_frames.tres  idle, drift_n/e/s/w
  td_shift_frames.tres  melt, freeze, boil, condense   (played between states)
Each resource also carries per-frame metadata (offsets from the frame centre, read by
td_player_visual.gd): `body` = centroid of the blob's main shape (ignores trailing drops /
spray), `eye` = where the procedural eyes sit (the art has no eyes).
Re-run after replacing a strip; the .tres files are plain Godot resources.
"""
import os
import re
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RES = "res://assets/topdown/anim/"

# manifest line: "<file>  <w>x<h>  <fw>x<fh> frames, <fps> fps, loop|once"
MANIFEST = {}
with open(os.path.join(HERE, "manifest.txt"), encoding="utf-8") as f:
    for line in f:
        m = re.match(r"(\S+\.png)\s+\d+x\d+\s+(\d+)x\d+ frames, (\d+) fps, (loop|once)", line.strip())
        if m:
            MANIFEST[m.group(1)] = (int(m.group(2)), int(m.group(3)), m.group(4) == "loop")

SETS = {
    # out file: [(animation name, strip file)]
    "td_ice_frames.tres": [("idle", "t1_ice_idle_6f.png")]
    + [("slide_" + d, f"t1_ice_slide_{d}_4f.png") for d in "nesw"]
    + [("impact_" + d, f"t1_ice_impact_{d}_6f.png") for d in "nesw"],
    "td_water_frames.tres": [("idle", "t2_water_idle_8f.png")]
    + [("move_" + d, f"t2_water_move_{d}_8f.png") for d in "nesw"],
    "td_steam_frames.tres": [("idle", "t3_steam_idle_8f.png")]
    + [("drift_" + d, f"t3_steam_drift_{d}_6f.png") for d in "nesw"],
    "td_shift_frames.tres": [(n, f"t4_shift_{n}_8f.png") for n in ("melt", "freeze", "boil", "condense")],
}

# eye height above the body centroid per resource
EYE_LIFT = {"td_ice_frames.tres": 2, "td_water_frames.tres": 3, "td_steam_frames.tres": 1, "td_shift_frames.tres": 2}


def main_shape(frame):
    """Centroid of the largest 4-connected opaque blob, relative to the frame centre."""
    w, h = frame.size
    a = frame.getchannel("A").load()
    seen = set()
    best = []
    for y in range(h):
        for x in range(w):
            if a[x, y] < 128 or (x, y) in seen:
                continue
            comp, stack = [], [(x, y)]
            seen.add((x, y))
            while stack:
                cx, cy = stack.pop()
                comp.append((cx, cy))
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and a[nx, ny] >= 128:
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            if len(comp) > len(best):
                best = comp
    if not best:
        return 0, 0
    mx = sum(p[0] for p in best) / len(best) + 0.5 - w / 2
    my = sum(p[1] for p in best) / len(best) + 0.5 - h / 2
    return round(mx), round(my)


def vec_array(pts):
    return "PackedVector2Array(" + ", ".join(f"{x}, {y}" for x, y in pts) + ")"


for out, anims in SETS.items():
    ext, subs, blocks = [], [], []
    body_meta, eye_meta = [], []
    for ai, (name, path) in enumerate(anims):
        fw, fps, loop = MANIFEST[path]
        strip = Image.open(os.path.join(HERE, path)).convert("RGBA")
        w, h = strip.size
        n = w // fw
        centres = [main_shape(strip.crop((i * fw, 0, i * fw + fw, h))) for i in range(n)]
        body_meta.append(f'"{name}": {vec_array(centres)}')
        eye_meta.append(f'"{name}": {vec_array([(x, y - EYE_LIFT[out]) for x, y in centres])}')
        rid = f"t{ai}"
        ext.append(f'[ext_resource type="Texture2D" path="{RES}{path}" id="{rid}"]')
        frames = []
        for i in range(n):
            sid = f"{name}_{i}"
            subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{rid}")\nregion = Rect2({i * fw}, 0, {fw}, {h})\n')
            frames.append(f'{{"duration": 1.0, "texture": SubResource("{sid}")}}')
        blocks.append('{\n"frames": [' + ", ".join(frames) + f'],\n"loop": {"true" if loop else "false"},\n"name": &"{name}",\n"speed": {float(fps)}\n}}')
    text = "[gd_resource type=\"SpriteFrames\" format=3]\n\n" + "\n".join(ext) + "\n\n" + "\n".join(subs) + "\n[resource]\nanimations = [" + ", ".join(blocks) + "]\n"
    text += "metadata/body = {" + ", ".join(body_meta) + "}\n"
    text += "metadata/eye = {" + ", ".join(eye_meta) + "}\n"
    with open(os.path.join(HERE, out), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("wrote", out, len(anims), "animations")
