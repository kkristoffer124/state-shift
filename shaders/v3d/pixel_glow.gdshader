// Lit panel / screen / sign: emissive colour with pixel scanlines and a dark 1-2 texel
// bezel along the box edges (V3D.box_mesh UVs), so glowing props read as built
// objects instead of flat colour boxes. Same cutaway as pixel_world.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;
#include "res://shaders/v3d/pixel_world.gdshaderinc"

uniform vec4 glow_color : source_color = vec4(1.0);
uniform float energy = 2.0;
uniform float scanlines = 1.0;

void fragment() {
	if (v_wy > cut_y) {
		discard;
	}
	float k = 1.0;
	float frame = 0.0;
	if (UV2.x > 0.0) {
		vec2 t = floor(UV * px_per_unit);
		vec2 n = floor(UV2 * px_per_unit);
		float e = min(min(t.x, n.x - 1.0 - t.x), min(t.y, n.y - 1.0 - t.y));
		// Bezel only on faces big enough to be a panel (>= 4 texels both ways).
		if (min(n.x, n.y) >= 4.0 && e < 1.0) {
			frame = 1.0;
		}
		if (scanlines > 0.0 && abs(v_nrm.y) < 0.7 && mod(t.y, 2.0) < 1.0) {
			k = 1.0 - 0.18 * scanlines;
		}
		// Soft pixel hotspot towards the middle of the panel.
		vec2 c = (t + 0.5) / max(n, vec2(1.0)) - 0.5;
		k *= 1.12 - 0.35 * dot(c, c);
	}
	vec3 col = glow_color.rgb;
	ALBEDO = mix(col * 0.35, vec3(0.06, 0.07, 0.09), frame);
	EMISSION = col * energy * k * (1.0 - frame);
	ROUGHNESS = 0.4;
	SPECULAR = 0.5;
}
