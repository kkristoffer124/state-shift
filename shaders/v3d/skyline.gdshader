// Night city tower blocks: dark facades with a grid of windows, some lit (warm or
// cool), dimmer and hazier with distance. Unshaded, one MultiMesh for all towers.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;

uniform vec4 facade : source_color = vec4(0.05, 0.06, 0.12, 1.0);
uniform vec4 haze : source_color = vec4(0.16, 0.17, 0.32, 1.0);
uniform vec4 lit_warm : source_color = vec4(1.0, 0.78, 0.4, 1.0);
uniform vec4 lit_cool : source_color = vec4(0.55, 0.75, 1.0, 1.0);
uniform float cell = 1.6;

varying vec3 wp;
varying vec3 wn;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = facade.rgb;
	if (abs(wn.y) < 0.5) {
		vec2 uv = abs(wn.x) > abs(wn.z) ? vec2(wp.z, wp.y) : vec2(wp.x, wp.y);
		vec2 g = uv / cell;
		vec2 id = floor(g);
		vec2 f = fract(g);
		float win = step(0.25, f.x) * step(f.x, 0.75) * step(0.3, f.y) * step(f.y, 0.75);
		float r = hash(vec3(id, floor(wp.x * 0.05) + floor(wp.z * 0.05) * 7.0));
		vec3 lc = r > 0.93 ? lit_cool.rgb : lit_warm.rgb;
		float on = step(0.78, r);
		c = mix(c, mix(c * 1.6, lc, on), win);
	} else {
		c *= 0.7;
	}
	float dist = length(wp - CAMERA_POSITION_WORLD);
	float h = smoothstep(30.0, 120.0, dist) * 0.65 + smoothstep(10.0, -30.0, wp.y) * 0.35;
	ALBEDO = mix(c, haze.rgb, clamp(h, 0.0, 0.85));
}
