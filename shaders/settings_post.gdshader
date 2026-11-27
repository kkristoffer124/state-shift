shader_type canvas_item;
// Full-screen post-process for the Settings (scenes/settings_fx.tscn, PostFX layer):
// brightness / contrast / saturation / gamma, colour-blind correction, CRT scanlines,
// vignette, bloom, film grain and chromatic aberration. Compatibility-renderer safe.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float brightness = 1.0;
uniform float contrast = 1.0;
uniform float saturation = 1.0;
uniform float gamma = 1.0;
uniform float scanlines = 0.0;
uniform float vignette = 0.0;
uniform float bloom = 0.0;
uniform float grain = 0.0;
uniform float aberration = 0.0;
// 0 off, 1 protanopia, 2 deuteranopia, 3 tritanopia, 4 greyscale
uniform int cb_mode = 0;
// 0 freezes grain (reduce motion)
uniform float motion = 1.0;
// Game-pixel height of the picture (scanline spacing).
uniform float lines = 270.0;

float rand(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 daltonize(vec3 c, int mode) {
	// RGB -> LMS
	mat3 to_lms = mat3(vec3(17.8824, 3.45565, 0.0299566), vec3(43.5161, 27.1554, 0.184309), vec3(4.11935, 3.86714, 1.46709));
	mat3 to_rgb = mat3(vec3(0.0809444479, -0.0102485335, -0.000365296938), vec3(-0.130504409, 0.0540193266, -0.00412161469), vec3(0.116721066, -0.113614708, 0.693511405));
	vec3 lms = to_lms * c;
	vec3 sim = lms;
	if (mode == 1) {
		sim = vec3(2.02344 * lms.y - 2.52581 * lms.z, lms.y, lms.z);
	} else if (mode == 2) {
		sim = vec3(lms.x, 0.494207 * lms.x + 1.24827 * lms.z, lms.z);
	} else {
		sim = vec3(lms.x, lms.y, -0.395913 * lms.x + 0.801109 * lms.y);
	}
	vec3 err = c - to_rgb * sim;
	// Shift the information the viewer can't see into channels they can.
	vec3 shift = vec3(0.0, err.r * 0.7 + err.g, err.r * 0.7 + err.b);
	return clamp(c + shift, 0.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c;
	if (aberration > 0.0) {
		vec2 d = (uv - 0.5) * aberration * 0.012;
		c = vec3(texture(screen_tex, uv + d).r, texture(screen_tex, uv).g, texture(screen_tex, uv - d).b);
	} else {
		c = texture(screen_tex, uv).rgb;
	}
	if (bloom > 0.0) {
		vec3 b = vec3(0.0);
		vec2 px = SCREEN_PIXEL_SIZE;
		for (int i = 0; i < 12; i++) {
			float a = float(i) * 0.5236;
			float r = (i % 2 == 0) ? 4.0 : 9.0;
			vec3 s = texture(screen_tex, uv + vec2(cos(a), sin(a)) * px * r).rgb;
			b += max(s - 0.55, 0.0);
		}
		c += b / 12.0 * bloom * 3.0;
	}
	c = pow(max(c, vec3(0.0)), vec3(1.0 / gamma));
	c *= brightness;
	c = (c - 0.5) * contrast + 0.5;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = clamp(c, 0.0, 1.0);
	if (cb_mode == 4) {
		c = vec3(dot(c, vec3(0.299, 0.587, 0.114)));
	} else if (cb_mode > 0) {
		c = daltonize(c, cb_mode);
	}
	if (scanlines > 0.0) {
		float s = 0.5 + 0.5 * cos(uv.y * lines * 6.2831853);
		c *= 1.0 - scanlines * 0.45 * s;
	}
	if (vignette > 0.0) {
		vec2 v = uv - 0.5;
		float d = dot(v, v) * 2.6;
		c *= 1.0 - vignette * smoothstep(0.15, 1.0, d);
	}
	if (grain > 0.0) {
		float t = floor(TIME * 24.0) * motion;
		c += (rand(uv * 731.0 + t) - 0.5) * grain * 0.22;
	}
	COLOR = vec4(c, 1.0);
}
