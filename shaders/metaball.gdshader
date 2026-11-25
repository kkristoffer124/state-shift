shader_type canvas_item;
// Used on the Water CanvasGroup: the soft droplet sprites drawn inside it are
// blended together, then thresholded here into one glossy liquid surface.
// Swap the colours for the art-brief ramp (P2b) by setting use_ramp + ramp.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float threshold : hint_range(0.05, 0.95) = 0.42;
uniform float softness : hint_range(0.0, 0.2) = 0.04;
uniform vec4 rim_color : source_color = vec4(0.12, 0.35, 0.8, 1.0);
uniform vec4 body_color : source_color = vec4(0.25, 0.56, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.48, 0.74, 1.0, 1.0);
uniform bool use_ramp = false;
uniform sampler2D ramp : source_color, filter_linear;

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	float a = c.a;
	float edge = smoothstep(threshold - softness, threshold + softness, a);
	float depth = clamp((a - threshold) / (1.0 - threshold), 0.0, 1.0);
	vec3 col;
	if (use_ramp) {
		col = texture(ramp, vec2(depth, 0.5)).rgb;
	} else {
		col = mix(rim_color.rgb, body_color.rgb, smoothstep(0.0, 0.18, depth));
		col = mix(col, core_color.rgb, smoothstep(0.55, 1.0, depth) * 0.6);
	}
	COLOR = vec4(col, edge * 0.94);
}
