// Theme surfaces of the 3D chapters (hand-made 64 px = 2 m tiles, 32 px per metre,
// world space, NEAREST): tops = floor A with floor B patches (hash per 2 m cell),
// sides = wall A with wall B rows/blocks, undersides = ceiling. Box meshes from
// V3D.box_mesh() carry trim flags in COLOR (r < 0.5: base trim band along the bottom
// 0.5 m of the sides; g < 0.5: edge trim along the top 0.25 m - ledge/drop edges).
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;
#include "res://shaders/v3d/pixel_world.gdshaderinc"

uniform sampler2D floor_a : source_color, filter_nearest, repeat_enable;
uniform sampler2D floor_b : source_color, filter_nearest, repeat_enable;
uniform sampler2D wall_a : source_color, filter_nearest, repeat_enable;
uniform sampler2D wall_b : source_color, filter_nearest, repeat_enable;
uniform sampler2D ceil_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D base_trim : source_color, filter_nearest, repeat_enable;
uniform sampler2D edge_trim : source_color, filter_nearest, repeat_enable;
uniform vec4 ceil_tint : source_color = vec4(1.0);
// Share of 2x2 m floor cells drawn with floor B.
uniform float floor_b_chance = 0.3;
// Chance that a 2 m row of a block's sides uses wall B (pipes run the whole row).
uniform float wall_b_rows = 0.25;
// Chance that a whole block uses wall B on its sides.
uniform float wall_b_blocks = 0.0;
uniform bool trims = true;

void fragment() {
	if (v_wy > cut_y) {
		discard;
	}
	vec3 n = v_nrm;
	vec3 a = abs(n);
	vec3 bp = NODE_POSITION_WORLD;
	bool top = false;
	vec4 c;
	if (a.y >= a.x && a.y >= a.z) {
		vec2 m = v_pos.xz;
		if (n.y > 0.0) {
			top = true;
			float pick = step(hash12(floor(m / 2.0) + vec2(0.37, 0.71)), floor_b_chance);
			c = mix(px_fetch(floor_a, m, 1, 0), px_fetch(floor_b, m, 1, 0), pick) * top_tint;
		} else {
			c = px_fetch(ceil_tex, m, 1, 0) * ceil_tint;
		}
	} else {
		float hz = a.x >= a.z ? v_pos.z * sign(n.x) : -v_pos.x * sign(n.z);
		vec2 m = vec2(hz, -v_pos.y);
		float row = floor(v_pos.y / 2.0);
		float blk = hash12(bp.xz * 1.37 + vec2(bp.y * 2.11, 5.3));
		float pick = max(step(hash12(vec2(blk * 97.0 + row * 7.13, row * 3.31 + 1.7)), wall_b_rows),
				step(hash12(vec2(blk * 53.0, 11.0)), wall_b_blocks));
		c = mix(px_fetch(wall_a, m, 1, 0), px_fetch(wall_b, m, 1, 0), pick) * tint;
		if (trims && UV2.x > 0.0) {
			float hx = floor(hz * px_per_unit);
			float hab = floor((UV2.y - UV.y) * px_per_unit); // texels above the face bottom
			float fromtop = floor(UV.y * px_per_unit);
			ivec2 bs = textureSize(base_trim, 0);
			ivec2 es = textureSize(edge_trim, 0);
			if (COLOR.r < 0.5 && hab < float(bs.y)) {
				c = px_at(base_trim, vec2(hx, float(bs.y) - 1.0 - hab)) * tint;
			} else if (COLOR.g < 0.5 && fromtop < float(es.y)) {
				c = px_at(edge_trim, vec2(hx, fromtop)) * tint;
			}
		}
	}
	c.rgb *= mix(1.0 - floor_shade, 1.0, smoothstep(floor_y, floor_y + 3.0, v_wy));
	ALBEDO = c.rgb * bevel_shade(UV, UV2, top);
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = mix(0.2, 0.5, metal);
}
