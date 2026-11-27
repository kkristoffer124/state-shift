// Pixel-art box material: picks the dominant axis of the (world or object) normal
// and maps the texture 1 texel = 1/px_per_unit metres, NEAREST (texelFetch), so blocks
// read like hand-made pixel tiles. Tops (normal up) use top_tex, everything else side_tex.
uniform sampler2D side_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D top_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 top_tint : source_color = vec4(1.0);
uniform float px_per_unit = 32.0;
uniform bool local_space = false;
// Darkens faces towards the bottom of the world (cheap fake AO / depth cue).
uniform float floor_shade = 0.0;
uniform float floor_y = 0.0;
// Cutaway (isometric): fragments above this world height are discarded.
uniform float cut_y = 100000.0;
// Pixel bevel along box edges (meshes from V3D.box_mesh(): UV = face metres from the
// face's top-left, UV2 = face size). Other meshes have UV2 = 0 and get no bevel.
uniform float bevel = 1.0;
uniform float metal = 0.0;
uniform float rough = 0.85;
// Horizontal strip atlas (e.g. the cracked block): `atlas_frames` square frames side
// by side, `atlas_frame` is drawn.
uniform int atlas_frames = 1;
uniform int atlas_frame = 0;
// 0..1: replaces the texture's hue by `tint` (keeps its light/dark pattern), so one
// steel texture serves every tinted metal prop.
uniform float recolor = 0.0;
// 1 = cylinder mapping (pipes, local space, axis = local Y): texture x runs along the
// pipe, texture y wraps exactly once around it.
uniform int uv_mode = 0;

varying vec3 v_pos;
varying vec3 v_nrm;
varying float v_wy;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wy = wp.y;
	if (local_space) {
		v_pos = VERTEX;
		v_nrm = NORMAL;
	} else {
		v_pos = wp;
		v_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	}
}

// Texel of `t` (one frame of a strip atlas) at `m` metres, wrapped, NEAREST.
vec4 px_fetch(sampler2D t, vec2 m, int nframes, int fr) {
	ivec2 ts = textureSize(t, 0);
	float fw = float(ts.x / nframes);
	vec2 p = mod(floor(m * px_per_unit), vec2(fw, float(ts.y)));
	return texelFetch(t, ivec2(int(p.x) + int(fw) * fr, int(p.y)), 0);
}

// Texel at integer pixel coords (wrapped) of a single-frame texture.
vec4 px_at(sampler2D t, vec2 p) {
	vec2 ts = vec2(textureSize(t, 0));
	return texelFetch(t, ivec2(mod(p, ts)), 0);
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// Hash (Dave Hoskins' hash12): stable 0..1 value per 2D cell.
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec4 pixel_sample(bool front) {
	vec3 n = front ? v_nrm : -v_nrm;
	vec3 a = abs(n);
	vec2 uv;
	bool top = false;
	bool under = false;
	if (uv_mode == 1) {
		ivec2 ts = textureSize(side_tex, 0);
		float around = atan(v_pos.z, v_pos.x) / 6.2831853 + 0.5;
		float wrap = float(ts.y) / px_per_unit;
		uv = a.y > 0.7 ? vec2(length(v_pos.xz), around * wrap) : vec2(v_pos.y, around * wrap);
	} else if (a.y >= a.x && a.y >= a.z) {
		uv = v_pos.xz;
		top = n.y > 0.0;
		under = !top;
	} else if (a.x >= a.z) {
		uv = vec2(v_pos.z * sign(n.x), -v_pos.y);
	} else {
		uv = vec2(-v_pos.x * sign(n.z), -v_pos.y);
	}
	vec4 c;
	if (top) {
		c = px_fetch(top_tex, uv, atlas_frames, atlas_frame);
	} else {
		c = px_fetch(side_tex, uv, atlas_frames, atlas_frame);
	}
	if (recolor > 0.0) {
		c.rgb = mix(c.rgb, vec3(luma(c.rgb)), recolor);
	}
	c *= top ? top_tint : tint;
	if (under) {
		c.rgb *= 0.7; // undersides
	}
	// Slightly darker towards the room's floor (floor_y) for depth.
	c.rgb *= mix(1.0 - floor_shade, 1.0, smoothstep(floor_y, floor_y + 3.0, v_wy));
	return c;
}

// Brightness multiplier for the 1-2 texel rim along the face edges: top edges and the
// rim of top faces catch the light, bottom/side edges are shaded. Snapped to texels.
float bevel_shade(vec2 uv, vec2 uv2, bool top) {
	if (bevel <= 0.0 || uv2.x <= 0.0) {
		return 1.0;
	}
	vec2 t = floor(uv * px_per_unit);
	vec2 n = floor(uv2 * px_per_unit);
	float l = t.x;
	float r = n.x - 1.0 - t.x;
	float u = t.y;
	float d = n.y - 1.0 - t.y;
	float k = 1.0;
	if (top) {
		if (min(min(l, r), min(u, d)) < 1.0) {
			k = 1.28;
		}
	} else {
		if (u < 1.0) {
			k = 1.3;
		} else if (d < 1.0) {
			k = 0.62;
		} else if (min(l, r) < 1.0) {
			k = 0.8;
		} else if (u < 2.0) {
			k = 0.86;
		}
	}
	return mix(1.0, k, bevel);
}
