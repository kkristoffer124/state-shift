// Wobbly water blob: a low-poly sphere whose vertices ripple along the normal and
// whose bottom flattens into a puddle-ish base. Compatibility-safe (no screen reads).
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_always, specular_schlick_ggx;

uniform vec4 color : source_color = vec4(0.22, 0.52, 1.0, 0.82);
uniform vec4 deep_color : source_color = vec4(0.08, 0.22, 0.65, 0.9);
uniform vec4 rim_color : source_color = vec4(0.75, 0.92, 1.0, 1.0);
uniform float wobble = 1.0;
uniform float speed = 1.0;
uniform float base_y = -0.24;
uniform float time_offset = 0.0;

void vertex() {
	float t = TIME * speed + time_offset;
	vec3 v = VERTEX;
	float w = sin(t * 4.1 + v.y * 9.0 + v.x * 5.0) * 0.022
		+ sin(t * 6.3 + v.z * 8.0 - v.x * 4.0) * 0.018
		+ sin(t * 2.7 + v.x * 3.0 + v.z * 3.0) * 0.012;
	VERTEX += NORMAL * w * wobble;
	if (VERTEX.y < base_y) {
		VERTEX.y = base_y + (VERTEX.y - base_y) * 0.3;
		VERTEX.xz *= 1.06;
	}
}

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 2.2);
	vec3 body = mix(deep_color.rgb, color.rgb, smoothstep(-0.3, 0.6, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y * 0.5 + 0.5));
	ALBEDO = mix(body, rim_color.rgb, fres * 0.55);
	ALPHA = clamp(mix(color.a, 1.0, fres * 0.6), 0.0, 1.0);
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	EMISSION = rim_color.rgb * fres * 0.35 + color.rgb * 0.08;
}
