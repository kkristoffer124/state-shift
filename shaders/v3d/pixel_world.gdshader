shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;
#include "res://shaders/v3d/pixel_world.gdshaderinc"

void fragment() {
	if (v_wy > cut_y) {
		discard;
	}
	vec4 c = pixel_sample(true);
	ALBEDO = c.rgb;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
