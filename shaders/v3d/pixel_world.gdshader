shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;
#include "res://shaders/v3d/pixel_world.gdshaderinc"

void fragment() {
	if (v_wy > cut_y) {
		discard;
	}
	vec4 c = pixel_sample(true);
	bool top = v_nrm.y > 0.7;
	ALBEDO = c.rgb * bevel_shade(UV, UV2, top);
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = mix(0.2, 0.5, metal);
}
