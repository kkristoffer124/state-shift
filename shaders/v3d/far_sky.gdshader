// Far sky band (inside of a big open cylinder around the camera): the cutscene
// night sky art wrapped 3x around, nearest filtered, unaffected by fog.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_front, depth_draw_never, shadows_disabled;

uniform sampler2D sky_tex : source_color, filter_nearest, repeat_enable;
uniform float wraps = 3.0;

void fragment() {
	vec2 uv = vec2(UV.x * wraps, UV.y);
	ALBEDO = texture(sky_tex, uv).rgb;
}
