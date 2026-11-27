// First-person "you are the blob" overlay: frost creeping in from the screen edges
// (ICE), droplets beading and sliding at the edges plus a wobbly meniscus (WATER),
// soft swirling haze (STEAM). `mix_*` weights cross-fade between states.
shader_type canvas_item;

uniform float mix_ice = 0.0;
uniform float mix_water = 1.0;
uniform float mix_steam = 0.0;
uniform float intensity = 1.0;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += noise(p) * a;
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec2 px = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = px.x / px.y;
	// Chunky pixels to match the art (4 screen px per "pixel" at 960x540).
	vec2 cell = floor(uv * vec2(240.0 * aspect / 1.7777, 135.0)) / vec2(240.0 * aspect / 1.7777, 135.0);
	vec2 c = cell - 0.5;
	c.x *= aspect;
	float edge = max(abs(c.x) / (0.5 * aspect), abs(c.y) / 0.5); // 0 centre .. 1 border
	float rad = length(c * vec2(1.0 / aspect, 1.0)) * 1.414;
	vec4 col = vec4(0.0);

	// ICE: crystalline frost from the corners/edges.
	if (mix_ice > 0.001) {
		float n = fbm(cell * vec2(28.0, 16.0));
		float crystals = step(0.55, fbm(cell * vec2(70.0, 40.0) + 3.0));
		float f = smoothstep(0.72, 1.05, edge + n * 0.3 + rad * 0.1);
		vec3 fc = mix(vec3(0.62, 0.86, 1.0), vec3(0.95, 1.0, 1.0), crystals);
		float a = f * (0.75 + 0.25 * crystals);
		col = mix(col, vec4(fc, a), mix_ice * step(0.001, a));
		col.a = max(col.a, mix_ice * 0.07);
		col.rgb = mix(col.rgb, vec3(0.7, 0.9, 1.0), mix_ice * 0.07 * (1.0 - f));
	}
	// WATER: beads near the edges sliding down, bluish lens at the bottom.
	if (mix_water > 0.001) {
		vec2 g = vec2(uv.x * 14.0 * aspect / 1.7777, uv.y * 8.0);
		vec2 id = floor(vec2(g.x, g.y + TIME * 0.15 * (0.5 + hash(vec2(floor(g.x), 2.0)))));
		vec2 gp = vec2(g.x, g.y + TIME * 0.15 * (0.5 + hash(vec2(floor(g.x), 2.0))));
		vec2 f = fract(gp) - 0.5;
		float r = 0.08 + 0.12 * hash(id);
		float exists = step(0.72, hash(id + 7.0)) * smoothstep(0.78, 0.95, edge);
		float d = length(f);
		float drop = step(d, r) * exists;
		float hl = step(length(f - vec2(-r * 0.35, -r * 0.35)), r * 0.35) * drop;
		vec4 dc = vec4(mix(vec3(0.35, 0.65, 1.0), vec3(0.9, 0.97, 1.0), hl), 0.4 * drop + 0.3 * hl);
		// meniscus: the blob's own surface curving across the bottom of the view
		float wav = sin(uv.x * 9.0 + TIME * 2.2) * 0.012 + sin(uv.x * 23.0 - TIME * 3.1) * 0.006;
		float surf = 1.0 - (0.955 + wav - 0.07 * pow(abs(uv.x - 0.5) * 2.0, 2.0));
		float lens = smoothstep(surf + 0.004, surf - 0.004, 1.0 - uv.y);
		float lip = smoothstep(0.012, 0.0, abs((1.0 - uv.y) - surf));
		vec4 lc = vec4(0.2, 0.5, 1.0, 0.3 * lens);
		lc = mix(lc, vec4(0.75, 0.92, 1.0, 0.85), lip);
		vec4 wc = dc.a > lc.a ? dc : lc;
		wc.a = max(wc.a, smoothstep(0.8, 1.05, edge) * 0.18);
		wc.rgb = wc.a > 0.0 ? wc.rgb : vec3(0.3, 0.6, 1.0);
		col = mix(col, wc, mix_water * step(0.001, wc.a));
	}
	// STEAM: soft white haze drifting around the borders.
	if (mix_steam > 0.001) {
		float n = fbm(cell * vec2(6.0, 4.0) + vec2(TIME * 0.12, -TIME * 0.25));
		float h = smoothstep(0.68, 1.15, edge + (n - 0.5) * 0.45) * 0.55 + 0.03;
		vec4 sc = vec4(vec3(0.93, 0.96, 1.0), h);
		col = mix(col, sc, mix_steam);
	}
	col.a *= intensity;
	col = mix(col, vec4(flash_color.rgb, max(col.a, flash_color.a)), flash);
	COLOR = col;
}
