shader_type canvas_item;
// Scene transition for Overlay/Fade: the ColorRect's alpha is the progress (0..1).
// Water rises from the bottom (fade out) and drains down (fade in) with a wavy,
// pixel-snapped surface, a bright meniscus and a lighter shallow band.

uniform bool plain = false;
uniform vec2 res = vec2(960.0, 540.0);
uniform vec3 meniscus : source_color = vec3(0.62, 0.84, 1.0);
uniform vec3 shallow : source_color = vec3(0.16, 0.36, 0.62);

void fragment() {
	float p = COLOR.a;
	vec3 base = COLOR.rgb;
	if (plain) {
		COLOR = vec4(base, p);
	} else {
		vec2 px = floor(UV * res);
		float wave = sin(px.x * 0.045 + TIME * 5.0) * 4.0 + sin(px.x * 0.13 - TIME * 3.1) * 2.0;
		float level = mix(res.y + 16.0, -16.0, p);
		float d = px.y - floor(level + wave);
		vec3 col = mix(shallow, base, clamp(d / 14.0, 0.0, 1.0));
		if (d < 2.0) {
			col = meniscus;
		}
		// A few rising bubbles in the shallow band.
		float bx = mod(px.x, 37.0);
		float by = mod(px.y + TIME * 40.0 + floor(px.x / 37.0) * 11.0, 23.0);
		if (d > 4.0 && d < 40.0 && bx < 1.0 && by < 1.0) {
			col = mix(col, meniscus, 0.7);
		}
		COLOR = vec4(col, step(0.0, d) * step(0.001, p));
	}
}
