// Landing marker under the 3D blob (CameraRig3D): a soft shadow disc with a bright
// ring on the ground, and (line = true) a dashed vertical drop line from the blob.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform bool line = false;
uniform float line_length = 1.0;
uniform float strength = 1.0;
uniform vec4 ring_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);

void fragment() {
	if (line) {
		if (fract(UV.y * line_length * 4.0) > 0.55) {
			discard;
		}
		ALBEDO = ring_color.rgb;
		ALPHA = 0.6 * strength;
	} else {
		float r = length(UV - vec2(0.5)) * 2.0;
		if (r > 1.0) {
			discard;
		}
		float shadow = smoothstep(1.0, 0.2, r) * 0.55;
		float ring = smoothstep(0.08, 0.0, abs(r - 0.82));
		ALBEDO = ring_color.rgb * ring;
		ALPHA = max(shadow, ring * 0.85) * strength;
	}
}
