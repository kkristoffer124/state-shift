shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;
#include "res://shaders/v3d/pixel_world.gdshaderinc"

// Frame band (gates): texels within frame_w metres of a box face's edge draw frame_tex
// (hazard stripes) instead, so moving shutters read as framed, marked parts.
uniform sampler2D frame_tex : source_color, filter_nearest, repeat_enable;
uniform float frame_w = 0.0;

void fragment() {
	if (v_wy > cut_y) {
		discard;
	}
	vec4 c = pixel_sample(true);
	bool top = v_nrm.y > 0.7;
	if (frame_w > 0.0 && UV2.x > 0.0) {
		vec2 t = floor(UV * px_per_unit);
		vec2 n = floor(UV2 * px_per_unit);
		float e = min(min(t.x, n.x - 1.0 - t.x), min(t.y, n.y - 1.0 - t.y));
		if (e < frame_w * px_per_unit && min(n.x, n.y) > frame_w * px_per_unit * 2.5) {
			c = px_at(frame_tex, t);
		}
	}
	ALBEDO = c.rgb * bevel_shade(UV, UV2, top);
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = mix(0.2, 0.5, metal);
}
