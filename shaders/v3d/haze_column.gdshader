// Unshaded glowing column for heat / freeze / fan volumes: fades towards the top
// (heat) or bottom (freeze), with soft scrolling bands. Additive, no depth write.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.4, 0.1, 0.5);
uniform float direction = 1.0; // 1: strong at the bottom, -1: strong at the top
uniform float scroll = 0.6;
uniform float bands = 3.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float h = UV.y; // QuadMesh / box side: 0 top .. 1 bottom
	float g = direction > 0.0 ? h : 1.0 - h;
	float band = 0.75 + 0.25 * sin((h * bands + TIME * scroll * direction) * 6.2831);
	float edge = smoothstep(0.0, 0.25, UV.x) * smoothstep(1.0, 0.75, UV.x);
	float a = color.a * pow(g, 1.6) * band * edge;
	ALBEDO = color.rgb * a;
	ALPHA = 1.0;
}
