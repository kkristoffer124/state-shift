// Steam cloud: a cluster of low-poly lobes merged into one mesh (PlayerVisual3D builds
// it; COLOR.rgb = lobe centre * 0.5 + 0.5, COLOR.a = lobe phase). Every lobe breathes
// on its own beat, lobes trail behind the motion (`drag`, a spring) and the cloud sways.
// Depth prepass so only the outer hull shows (no doubled alpha where lobes overlap).
shader_type spatial;
render_mode blend_mix, cull_back, depth_prepass_alpha, unshaded;

uniform vec4 color : source_color = vec4(0.96, 0.98, 1.0, 1.0);
uniform vec4 shade_color : source_color = vec4(0.66, 0.74, 0.88, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.97, 0.88, 1.0);
uniform float alpha = 0.86;
uniform float fade = 1.0;
uniform float breathe = 1.0;
// World-space lag of the lobes (m), set from a spring on the velocity.
uniform vec3 drag = vec3(0.0);

void vertex() {
	vec3 c = COLOR.rgb * 2.0 - 1.0;
	float ph = COLOR.a * 6.2832;
	float s = 1.0 + sin(TIME * 2.3 + ph) * 0.07 * breathe + sin(TIME * 3.7 + ph * 2.0) * 0.03 * breathe;
	vec3 d = VERTEX - c;
	vec3 drift = vec3(sin(TIME * 1.3 + ph), sin(TIME * 1.7 + ph * 1.5) * 0.6, cos(TIME * 1.1 + ph)) * 0.025 * breathe;
	// Outer lobes lag more than the core.
	float lag = 0.35 + length(c) * 1.6 + COLOR.a * 0.4;
	VERTEX = c + d * s + drift + drag * lag;
}

void fragment() {
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	// Three-tone toon shading from the world "sky" direction.
	float l = clamp(wn.y * 0.6 + 0.45 + wn.x * 0.15, 0.0, 1.0);
	l = floor(l * 3.0 + 0.5) / 3.0;
	vec3 col = mix(shade_color.rgb, color.rgb, l);
	col = mix(col, core_color.rgb, smoothstep(0.75, 1.0, ndv) * 0.35);
	ALBEDO = col;
	ALPHA = clamp(alpha * (1.0 - pow(1.0 - ndv, 3.0) * 0.55) * fade, 0.0, 1.0);
}
