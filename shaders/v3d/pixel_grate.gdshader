shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;
#include "res://shaders/v3d/pixel_world.gdshaderinc"

void fragment() {
	if (v_wy > cut_y) {
		discard;
	}
	vec4 c = pixel_sample(FRONT_FACING);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.6;
	SPECULAR = 0.4;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
