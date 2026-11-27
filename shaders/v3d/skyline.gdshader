// Night city tower blocks: the hand-made lit-window tiles (windows A-D, one style per
// tower) laid out from each tower's top edge in its own face space, with per-tile
// offsets and some windows switched off so towers don't repeat; dimmer and hazier
// with distance. Unshaded, one MultiMesh for all towers.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;

uniform sampler2D win_a : source_color, filter_nearest, repeat_enable;
uniform sampler2D win_b : source_color, filter_nearest, repeat_enable;
uniform sampler2D win_c : source_color, filter_nearest, repeat_enable;
uniform sampler2D win_d : source_color, filter_nearest, repeat_enable;
uniform vec4 haze : source_color = vec4(0.16, 0.17, 0.32, 1.0);
uniform vec4 roof : source_color = vec4(0.04, 0.045, 0.08, 1.0);
// Metres covered by one 32 px window tile.
uniform float tile_m = 6.4;
// Share of lit windows switched off.
uniform float lights_off = 0.35;

varying vec3 wp;
varying vec3 lp;
varying vec3 ln;
varying vec3 scl;
varying vec3 org;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	scl = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	lp = VERTEX * scl;
	ln = NORMAL;
	org = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
}

vec4 win(float style, ivec2 p) {
	if (style < 1.0) {
		return texelFetch(win_a, p, 0);
	} else if (style < 2.0) {
		return texelFetch(win_b, p, 0);
	} else if (style < 3.0) {
		return texelFetch(win_c, p, 0);
	}
	return texelFetch(win_d, p, 0);
}

void fragment() {
	vec3 c = roof.rgb;
	if (abs(ln.y) < 0.5) {
		float w = abs(ln.x) > abs(ln.z) ? scl.z : scl.x;
		float u = (abs(ln.x) > abs(ln.z) ? lp.z * sign(ln.x) : -lp.x * sign(ln.z)) + w * 0.5;
		float v = scl.y * 0.5 - lp.y;
		// Centre the window columns on the face.
		u -= mod(w, tile_m) * 0.5;
		float pxm = 32.0 / tile_m;
		vec2 px = floor(vec2(u, v) * pxm);
		vec2 tile = floor(px / 32.0);
		float tower = hash12(org.xz * 0.173);
		float style = floor(tower * 4.0);
		// Per-tile shift by whole 16 px window blocks keeps the grid but varies the lights.
		vec2 sh = floor(vec2(hash12(tile + org.xz), hash12(tile.yx + org.zx + 3.1)) * 2.0) * 16.0;
		ivec2 p = ivec2(mod(px + sh, 32.0));
		c = win(style, p).rgb;
		float lit = step(0.75, max(c.r, max(c.g, c.b))) * step(c.b + 0.05, c.r);
		if (lit > 0.5 && hash12(floor((px + sh) / 8.0) + org.xz * 1.7) < lights_off) {
			c = vec3(0.13, 0.15, 0.2);
		}
		if (u < 0.0 || u > w - mod(w, tile_m)) {
			c = win(style, ivec2(0, p.y)).rgb; // plain facade at the trimmed edges
		}
	}
	float dist = length(wp - CAMERA_POSITION_WORLD);
	float h = smoothstep(30.0, 120.0, dist) * 0.65 + smoothstep(10.0, -30.0, wp.y) * 0.35;
	ALBEDO = mix(c, haze.rgb, clamp(h, 0.0, 0.85));
}
