// Glass (tanks, partitions, pod fronts): the hand-made translucent glass tile mapped in
// world space (32 px per metre), alpha from the texture, a little brighter at grazing
// angles. Same cutaway as pixel_world.
shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_lambert, specular_schlick_ggx;
#include "res://shaders/v3d/pixel_world.gdshaderinc"

uniform float alpha_scale = 0.42;

void fragment() {
	if (v_wy > cut_y) {
		discard;
	}
	vec4 c = pixel_sample(FRONT_FACING);
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = c.rgb;
	ALPHA = clamp(c.a * alpha_scale + rim * 0.2, 0.0, 0.8);
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
