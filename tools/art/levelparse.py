"""Parses levels/level_XX.tscn into simple geometry dicts (read-only)."""
import re, os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

def _vec(s):
    m = re.match(r"Vector2\(([-\d.e]+),\s*([-\d.e]+)\)", s.strip())
    return (float(m.group(1)), float(m.group(2)))

def parse_level(n):
    path = os.path.join(ROOT, "levels", "level_%02d.tscn" % n)
    txt = open(path, encoding="utf-8").read()
    ext = {}
    for m in re.finditer(r'\[ext_resource[^\]]*path="([^"]+)"[^\]]*id="([^"]+)"', txt):
        ext[m.group(2)] = m.group(1)
    nodes = []
    cur = None
    for line in txt.splitlines():
        if line.startswith("[node"):
            name = re.search(r'name="([^"]+)"', line).group(1)
            parent = re.search(r'parent="([^"]+)"', line)
            inst = re.search(r'instance=ExtResource\("([^"]+)"\)', line)
            typ = re.search(r'type="([^"]+)"', line)
            cur = {"name": name, "parent": parent.group(1) if parent else None,
                   "scene": ext.get(inst.group(1)) if inst else None,
                   "type": typ.group(1) if typ else None, "props": {}}
            nodes.append(cur)
        elif line.startswith("[") :
            cur = None
        elif cur is not None and "=" in line:
            k, v = line.split("=", 1)
            cur["props"][k.strip()] = v.strip()
    lvl = {"n": n, "name": "", "blocks": [], "zones": [], "hints": [], "player": None}
    root = nodes[0]
    lvl["name"] = root["props"].get("level_name", "").strip('"')
    for nd in nodes:
        p = nd["props"]
        if nd["parent"] == "Blocks" and nd["scene"]:
            kind = os.path.basename(nd["scene"]).replace(".tscn", "")
            pos = _vec(p.get("position", "Vector2(0, 0)"))
            size = _vec(p.get("size", "Vector2(64, 64)"))
            lvl["blocks"].append({"name": nd["name"], "kind": kind, "x": pos[0], "y": pos[1], "w": size[0], "h": size[1]})
        elif nd["parent"] == "Zones" and nd["scene"]:
            kind = os.path.basename(nd["scene"]).replace(".tscn", "")
            pos = _vec(p.get("position", "Vector2(0, 0)"))
            size = _vec(p.get("size", "Vector2(64, 32)"))
            d = {"name": nd["name"], "kind": kind, "x": pos[0], "y": pos[1], "w": size[0], "h": size[1]}
            if "push_direction" in p:
                d["push"] = _vec(p["push_direction"])
            lvl["zones"].append(d)
        elif nd["parent"] == "Hints":
            x0 = float(p.get("offset_left", 0)); y0 = float(p.get("offset_top", 0))
            x1 = float(p.get("offset_right", x0 + 400)); y1 = float(p.get("offset_bottom", y0 + 28))
            lvl["hints"].append({"x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0})
        elif nd["name"] == "Player" and nd["parent"] == ".":
            lvl["player"] = _vec(p.get("position", "Vector2(0, 0)"))
    # interactive file (other people may add things there) -> keep-out rects
    lvl["interactive"] = []
    ipath = os.path.join(ROOT, "levels", "interactive", "level_%02d_interactive.tscn" % n)
    if os.path.exists(ipath):
        # Interactive/ambient props from the gameplay team become keep-out rects so
        # the dressing never stacks on top of them.
        itxt = open(ipath, encoding="utf-8").read()
        iext = {m.group(2): os.path.basename(m.group(1)).replace(".tscn", "")
                for m in re.finditer(r'\[ext_resource[^\]]*path="([^"]+)"[^\]]*id="([^"]+)"', itxt)}
        cur = None
        nodes_i = []
        for line in itxt.splitlines():
            if line.startswith("[node"):
                inst = re.search(r'instance=ExtResource\("([^"]+)"\)', line)
                par = re.search(r'parent="([^"]+)"', line)
                cur = {"_scene": iext.get(inst.group(1), "") if inst else "", "_parent": par.group(1) if par else ""}
                nodes_i.append(cur)
            elif line.startswith("["):
                cur = None
            elif cur is not None and " = " in line:
                k, v = line.split(" = ", 1)
                cur[k.strip()] = v.strip()
        for nd in nodes_i:
            if "position" not in nd:
                continue
            x, y = _vec(nd["position"])
            sc = nd["_scene"]
            w = float(nd.get("width", 0) or 0)
            L = float(nd.get("length", nd.get("pipe_length", 0)) or 0)
            if "size" in nd and nd["size"].startswith("Vector2"):
                sw, sh = _vec(nd["size"])
                r = (x - 24, y - 24, sw + 48, sh + 48)
            elif sc in ("debris", "puddle"):
                continue  # floor litter: harmless to overlap
            elif sc in ("swing_lamp", "spark_wire", "drip_pipe"):
                r = (x - 20, y - 4, 40, L + 40)
            elif sc == "flask_shelf":
                r = (x - w / 2 - 12, y - 40, w + 24, 56)
            elif sc in ("turbine",):
                r = (x - 64, y - 64, 128, 128)
            elif sc == "steam_vent":
                r = (x - 24, y - 64, 48, 72)
            elif w:
                r = (x - 24, y - 24, w + 48, 48)
            else:
                r = (x - 28, y - 28, 56, 56)
            lvl["interactive"].append({"x": r[0], "y": r[1], "w": r[2], "h": r[3]})
    bs = lvl["blocks"]
    x0 = min(b["x"] for b in bs); y0 = min(b["y"] for b in bs)
    x1 = max(b["x"] + b["w"] for b in bs); y1 = max(b["y"] + b["h"] for b in bs)
    lvl["bounds"] = (x0, y0, x1, y1)
    return lvl

if __name__ == "__main__":
    for n in range(1, 13):
        L = parse_level(n)
        print("L%02d %s bounds=%s player=%s" % (n, L["name"], L["bounds"], L["player"]))
        for b in L["blocks"]:
            print("   B %-10s %-14s %5d %5d %5d %5d" % (b["kind"], b["name"], b["x"], b["y"], b["w"], b["h"]))
        for z in L["zones"]:
            print("   Z %-10s %-14s %5d %5d %5d %5d %s" % (z["kind"], z["name"], z["x"], z["y"], z["w"], z["h"], z.get("push", "")))
        print("   hints", len(L["hints"]), "interactive", len(L["interactive"]))
