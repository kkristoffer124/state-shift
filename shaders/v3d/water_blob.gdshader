// Wobbly water blob: a sphere whose vertices ripple along the normal, whose bottom
// flattens into a puddle-ish base, and which leans / stretches into a teardrop along its
// horizontal motion (lean + stretch are springs driven by PlayerVisual3D, world axes).
// Compatibility-safe (no screen reads).
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_always, specular_schlick_ggx;

uniform vec4 color : source_color = vec4(0.22, 0.52, 1.0, 0.82);
uniform vec4 deep_color : source_color = vec4(0.08, 0.22, 0.65, 0.9);
uniform vec4 rim_color : source_color = vec4(0.75, 0.92, 1.0, 1.0);
uniform float wobble = 1.0;
uniform float speed = 1.0;
uniform float base_y = -0.24;
uniform float top_y = 0.37;
uniform float time_offset = 0.0;
// Offset (m) of the top of the blob relative to its base (jelly lean).
uniform vec3 lean = vec3(0.0);
// Horizontal motion direction (unit, xz) and how much to stretch along it.
uniform vec2 stretch_dir = vec2(1.0, 0.0);
uniform float stretch = 0.0;
// 0..1 shift morph fade.
uniform float fade = 1.0;

varying float hgt;

void vertex() {
	float t = TIME * speed + time_offset;
	vec3 v = VERTEX;
	float h = clamp((v.y - base_y) / (top_y - base_y), 0.0, 1.0);
	hgt = h;
	float w = sin(t * 4.1 + v.y * 9.0 + v.x * 5.0) * 0.022
		+ sin(t * 6.3 + v.z * 8.0 - v.x * 4.0) * 0.018
		+ sin(t * 2.7 + v.x * 3.0 + v.z * 3.0) * 0.012;
	VERTEX += NORMAL * w * wobble;
	if (VERTEX.y < base_y) {
		VERTEX.y = base_y + (VERTEX.y - base_y) * 0.3;
		VERTEX.xz *= 1.06;
	}
	// Teardrop: longer along the motion (more so behind), thinner across it.
	float along = dot(VERTEX.xz, stretch_dir);
	vec2 across = VERTEX.xz - stretch_dir * along;
	VERTEX.xz = stretch_dir * (along * (1.0 + stretch * 0.6) + min(along, 0.0) * stretch * 0.9)
		+ across * (1.0 - stretch * 0.3);
	VERTEX.y *= 1.0 - stretch * 0.12;
	// Jelly lean: the top trails / leads the base.
	VERTEX.xz += lean.xz * h * h;
	VERTEX.y += lean.y * h;
}

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 2.2);
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 body = mix(deep_color.rgb, color.rgb, smoothstep(-0.3, 0.6, wn.y * 0.5 + 0.5));
	// Cartoon glint: a crisp highlight up-left in view space plus a soft bounce below.
	float hl = step(0.985, dot(NORMAL, normalize(vec3(-0.66, 0.6, 0.45))));
	float bounce = smoothstep(0.75, 0.95, dot(NORMAL, normalize(vec3(0.5, -0.55, 0.65)))) * 0.25;
	ALBEDO = mix(body, rim_color.rgb, fres * 0.55) + vec3(hl * 0.6 + bounce * 0.4);
	ALPHA = clamp(mix(color.a, 1.0, max(fres * 0.6, hl)) * fade, 0.0, 1.0);
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	EMISSION = rim_color.rgb * (fres * 0.35 + hl * 0.8 + bounce * 0.3) + color.rgb * 0.08;
}
