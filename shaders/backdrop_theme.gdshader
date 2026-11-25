shader_type canvas_item;
// Palette treatment for the lab backdrop loops (scripts/backdrop.gd) so one set of
// art can read as other wings: gradient-map recolour of the art, a procedural fill
// behind it (brick / frosted panels / night skyline), a bottom glow and optional
// sewer water. All maths is in art pixels (UV / TEXTURE_PIXEL_SIZE) so it stays
// crisp and scrolls with the layer. Lab uses no material at all.

uniform vec3 dark_col : source_color = vec3(0.05, 0.1, 0.15);
uniform vec3 light_col : source_color = vec3(0.6, 0.8, 0.9);
uniform float ramp_gain = 2.6;
uniform float tint = 0.8;       // 0 = original colours, 1 = pure gradient map
uniform float keep_art = 1.0;   // 0 = hide the art (fill only)
uniform int fill = 0;           // 0 none, 1 brick, 2 frosted panels, 3 night skyline
uniform vec3 fill_a : source_color = vec3(0.2);
uniform vec3 fill_b : source_color = vec3(0.1);
uniform vec3 glow_col : source_color = vec3(1.0, 0.5, 0.2);
uniform float glow = 0.0;
uniform float glow_height = 0.4;
uniform float flicker = 0.0;
uniform float water_line = 0.0; // art-pixel y where murky water starts (0 = off)
uniform vec3 water_col : source_color = vec3(0.08, 0.22, 0.2);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 brick(vec2 px) {
	float row = floor(px.y / 8.0);
	float x = px.x + mod(row, 2.0) * 8.0;
	vec2 cell = vec2(floor(x / 16.0), row);
	if (mod(px.y, 8.0) < 1.0 || mod(x, 16.0) < 1.0) {
		return fill_b;
	}
	float v = 0.82 + hash(cell) * 0.3;
	v *= 0.94 + hash(px) * 0.08;
	// Lit top edge of each brick.
	if (mod(px.y, 8.0) < 2.0) v *= 1.12;
	return fill_a * v;
}

vec3 panels(vec2 px) {
	vec2 cell = floor(px / vec2(64.0, 48.0));
	vec2 l = mod(px, vec2(64.0, 48.0));
	if (l.x < 1.0 || l.y < 1.0) return fill_b;
	vec3 c = fill_a * (0.9 + hash(cell) * 0.15);
	if (l.y < 2.0 || l.x < 2.0) c *= 1.25;                         // bevel highlight
	if ((l.x == 4.0 || l.x == 59.0) && (l.y == 4.0 || l.y == 43.0)) c *= 1.6; // rivets
	float frost = hash(px);
	if (frost > 0.985) c = mix(c, vec3(0.85, 0.95, 1.0), 0.5);   // frost speckle
	// Frost creeping up from each panel's lower edge.
	if (l.y > 40.0 && hash(vec2(px.x, cell.y)) > 0.55) c = mix(c, vec3(0.7, 0.85, 0.95), 0.25);
	return c;
}

vec3 skyline(vec2 px) {
	float y = px.y / 540.0;
	vec3 c = mix(fill_a, fill_b, smoothstep(0.1, 0.85, y));
	// Twinkling stars in the upper sky.
	float s = hash(px);
	if (s > 0.9965 && y < 0.6) {
		float tw = 0.55 + 0.45 * sin(TIME * (1.5 + s * 40.0) + s * 300.0);
		c = mix(c, vec3(0.9, 0.93, 1.0), tw * (1.0 - y));
	}
	float x = mod(px.x, 960.0);
	// Crescent moon with a soft halo.
	float md = length(vec2(x, px.y) - vec2(150.0, 82.0));
	if (md < 34.0) c = mix(c, vec3(0.25, 0.3, 0.5), (1.0 - md / 34.0) * 0.35);
	if (md < 15.0 && length(vec2(x, px.y) - vec2(157.0, 76.0)) >= 13.0) c = vec3(0.93, 0.94, 0.86);
	// Far row: hazy, lighter silhouettes.
	float fi = floor(x / 20.0);
	float fh = 190.0 + hash(vec2(fi, 3.0)) * 170.0;
	if (px.y > 470.0 - fh) {
		c = mix(fill_b, vec3(0.05, 0.06, 0.13), 0.55);
		vec2 w = mod(vec2(x, px.y), vec2(4.0, 6.0));
		if (w.x < 2.0 && w.y < 3.0 && hash(floor(vec2(x / 4.0, px.y / 6.0)) + fi) > 0.86) {
			c = mix(c, vec3(0.55, 0.75, 0.95), 0.45);
		}
	}
	// Near row: dark blocks with lit windows.
	float ni = floor((x + 11.0) / 36.0);
	float nh = 110.0 + hash(vec2(ni, 7.0)) * 190.0;
	float lx = mod(x + 11.0, 36.0);
	if (px.y > 470.0 - nh && lx > 2.0) {
		c = vec3(0.025, 0.03, 0.07);
		if (px.y < 472.0 - nh) c = vec3(0.07, 0.08, 0.15); // roof edge
		vec2 w = mod(vec2(lx - 5.0, px.y - (470.0 - nh) - 6.0), vec2(5.0, 7.0));
		if (lx > 5.0 && lx < 33.0 && px.y > 476.0 - nh && w.x < 3.0 && w.y < 3.0) {
			float h = hash(floor(vec2((lx - 5.0) / 5.0, px.y / 7.0)) + vec2(ni * 13.0, 0.0));
			if (h > 0.78) c = vec3(0.95, 0.78, 0.42);
			else if (h > 0.7) c = vec3(0.45, 0.8, 0.95);
		}
	}
	// Rooftop ledge at the bottom.
	if (px.y >= 470.0) c = vec3(0.05, 0.055, 0.09) * (0.9 + hash(px) * 0.15);
	return c;
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	vec2 px = floor(UV / TEXTURE_PIXEL_SIZE);
	float a = src.a * keep_art;
	float lum = dot(src.rgb, vec3(0.299, 0.587, 0.114));
	vec3 ramp = mix(dark_col, light_col, clamp(lum * ramp_gain, 0.0, 1.0));
	vec3 col = mix(src.rgb, ramp, tint);
	if (fill > 0 && a < 0.999) {
		vec3 bg = fill == 1 ? brick(px) : (fill == 2 ? panels(px) : skyline(px));
		if (fill != 3) bg *= mix(0.65, 1.0, clamp(px.y / 400.0, 0.0, 1.0)); // darker up top
		col = mix(bg, col, a);
		a = 1.0;
	}
	if (water_line > 0.0 && px.y >= water_line && a > 0.0) {
		col = mix(col, water_col, 0.75);
		float wave = sin(px.x * 0.11 + TIME * 1.6 + floor(px.y / 3.0) * 2.1);
		if (wave > 0.93 && mod(px.y, 3.0) < 1.0) col += water_col * 0.9;
		if (px.y < water_line + 1.0) col += water_col * 0.8;   // surface line
	}
	if (glow > 0.0) {
		float g = clamp((px.y / 540.0 - (1.0 - glow_height)) / glow_height, 0.0, 1.0);
		g = floor(g * 12.0) / 12.0; // banded, pixel-art friendly
		float f = 1.0 + flicker * (sin(TIME * 7.0 + px.x * 0.021) * 0.5 + sin(TIME * 12.7 + px.x * 0.047) * 0.35);
		col += glow_col * glow * g * g * f * a;
	}
	COLOR = vec4(col, a);
}
