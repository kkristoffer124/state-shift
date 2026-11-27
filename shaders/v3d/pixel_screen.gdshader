// Emissive pixel screens and lamps on V3D.box_mesh() faces: one square frame of a
// horizontal strip atlas fills the face height and repeats across its width (a row
// of panels), NEAREST. Faces thinner than 0.15 m draw as the dark casing.
//   monitors: frames = 4, fps = 4 (each panel/prop offset so they don't sync)
//   warning lights: frames = 2, cutout, still_frame 0 = off / 1 = on, blink > 0 flashes
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;
#include "res://shaders/v3d/pixel_world.gdshaderinc"

uniform sampler2D screen_tex : source_color, filter_nearest;
uniform int screen_frames = 4;
uniform float fps = 4.0;
uniform int still_frame = -1;
uniform float blink = 0.0;
uniform float energy = 1.6;
uniform bool cutout = false;
// a > 0: recolours the image (keeps its brightness pattern), e.g. a green "open" lamp.
uniform vec4 recolor_to : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 casing : source_color = vec4(0.06, 0.07, 0.09, 1.0);

void fragment() {
	if (v_wy > cut_y) {
		discard;
	}
	vec2 face = UV2;
	vec2 uv = UV;
	if (face.x <= 0.0) {
		face = vec2(1.0);
		uv = fract(UV);
	}
	if (min(face.x, face.y) < 0.15) {
		if (cutout) {
			discard;
		}
		ALBEDO = casing.rgb;
		ROUGHNESS = 0.5;
	} else {
		ivec2 ts = textureSize(screen_tex, 0);
		float fw = float(ts.x / screen_frames);
		float fh = float(ts.y);
		float s = face.y;
		float count = max(1.0, floor(face.x / s + 0.5));
		float cw = face.x / count;
		float tile = floor(uv.x / cw);
		vec2 f = vec2(fract(uv.x / cw), uv.y / s);
		vec2 p = clamp(floor(f * vec2(fw, fh)), vec2(0.0), vec2(fw - 1.0, fh - 1.0));
		float seed = floor(hash12(NODE_POSITION_WORLD.xz * 3.7 + NODE_POSITION_WORLD.y) * 4.0);
		float fr;
		if (blink > 0.0) {
			fr = mod(floor(TIME * blink * 2.0), 2.0);
		} else if (still_frame >= 0) {
			fr = float(still_frame);
		} else {
			fr = mod(floor(TIME * fps) + tile + seed, float(screen_frames));
		}
		vec4 c = texelFetch(screen_tex, ivec2(int(p.x + fr * fw), int(p.y)), 0);
		if (cutout && c.a < 0.5) {
			discard;
		}
		if (recolor_to.a > 0.0) {
			c.rgb = mix(c.rgb, vec3(luma(c.rgb)) * recolor_to.rgb * 1.6, recolor_to.a);
		}
		ALBEDO = c.rgb * 0.3;
		EMISSION = c.rgb * energy;
		ROUGHNESS = 0.35;
		SPECULAR = 0.5;
	}
}
