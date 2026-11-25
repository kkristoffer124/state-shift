"""Minimal .tscn text writer used by the deco generators."""


def v2(x, y):
    return "Vector2(%s, %s)" % (_n(x), _n(y))


def col(r, g, b, a=1.0):
    return "Color(%s, %s, %s, %s)" % (_n(r), _n(g), _n(b), _n(a))


def rect2(x, y, w, h):
    return "Rect2(%s, %s, %s, %s)" % (_n(x), _n(y), _n(w), _n(h))


def s(txt):
    return '"%s"' % txt


def _n(v):
    v = float(v)
    if v == int(v):
        return str(int(v))
    return ("%.4f" % v).rstrip("0").rstrip(".")


class Scene:
    def __init__(self):
        self.ext = []      # (type, path, id)
        self.subs = []     # (type, id, props)
        self.nodes = []    # (header, props)
        self._ext_ids = {}

    def ext_res(self, typ, path):
        if path in self._ext_ids:
            return 'ExtResource("%s")' % self._ext_ids[path]
        i = str(len(self.ext) + 1)
        self.ext.append((typ, path, i))
        self._ext_ids[path] = i
        return 'ExtResource("%s")' % i

    def sub(self, typ, props):
        i = "%s_%d" % (typ, len(self.subs) + 1)
        self.subs.append((typ, i, props))
        return 'SubResource("%s")' % i

    def node(self, name, typ=None, parent=None, props=None, instance=None):
        h = '[node name="%s"' % name
        if typ:
            h += ' type="%s"' % typ
        if parent is not None:
            h += ' parent="%s"' % parent
        if instance:
            h += " instance=%s" % instance
        h += "]"
        self.nodes.append((h, props or {}))

    def render(self):
        out = ["[gd_scene format=3]", ""]
        for typ, path, i in self.ext:
            out.append('[ext_resource type="%s" path="%s" id="%s"]' % (typ, path, i))
        if self.ext:
            out.append("")
        for typ, i, props in self.subs:
            out.append('[sub_resource type="%s" id="%s"]' % (typ, i))
            for k, v in props.items():
                out.append("%s = %s" % (k, v))
            out.append("")
        for h, props in self.nodes:
            out.append(h)
            for k, v in props.items():
                out.append("%s = %s" % (k, v))
            out.append("")
        return "\n".join(out)

    def save(self, path):
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(self.render())
