// Faceted ice cube (chamfered ArrayMesh built by PlayerVisual3D): the 2D ice body art
// on every face (object space, 32 px = 1 m), translucent with a bright frosty rim,
// glinting chamfer edges, crack overlay and a pulsing frost rim when locked.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_always, specular_schlick_ggx;

uniform sampler2D body_tex : source_color, filter_nearest;
uniform sampler2D crack_tex : source_color, filter_nearest;
uniform sampler2D rim_tex : source_color, filter_nearest;
uniform float half_size = 0.47;
uniform float crack = 0.0;
uniform float frost = 0.0;
uniform float alpha = 0.9;
// 0..1 shift morph fade (PlayerVisual3D).
uniform float fade = 1.0;
// Travelling glint across the facets (phase, advanced with slide speed).
uniform float glint = 0.0;
uniform vec4 rim_color : source_color = vec4(0.85, 0.97, 1.0, 1.0);

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	vec3 a = abs(ln);
	float m = max(a.x, max(a.y, a.z));
	vec2 uv;
	if (a.y >= a.x && a.y >= a.z) {
		uv = lp.xz;
	} else if (a.x >= a.z) {
		uv = vec2(lp.z * sign(ln.x), -lp.y);
	} else {
		uv = vec2(-lp.x * sign(ln.z), -lp.y);
	}
	uv = clamp(uv / (half_size * 2.0) + 0.5, 0.0, 0.999);
	vec4 c = texture(body_tex, uv);
	vec4 k = texture(crack_tex, uv);
	c.rgb = mix(c.rgb, k.rgb, k.a * crack);
	vec4 r = texture(rim_tex, uv);
	c.rgb = mix(c.rgb, r.rgb, r.a * frost);
	// Chamfer facets (normal off the axes) catch the light like cut glass.
	float bevel = step(m, 0.95);
	float up = clamp(ln.y * 0.5 + 0.5, 0.0, 1.0);
	c.rgb = mix(c.rgb, rim_color.rgb, bevel * (0.35 + up * 0.45));
	// A pixel-stepped diagonal glint band sweeping over the body.
	float d = floor((lp.x + lp.y * 1.3 + lp.z * 0.7) * 32.0) / 32.0;
	float g = step(0.92, fract(d * 0.8 - glint)) * 0.18;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(c.rgb, rim_color.rgb, fres * 0.5) + vec3(g);
	ALPHA = clamp((max(c.a, 0.6) * alpha + fres * 0.2 + bevel * 0.08) * fade, 0.0, 1.0);
	ROUGHNESS = 0.12;
	SPECULAR = 0.8;
	EMISSION = c.rgb * 0.12 + rim_color.rgb * (fres * 0.25 + bevel * 0.1 + g * 0.5);
}
