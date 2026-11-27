// Pixel-art box material: picks the dominant axis of the (world or object) normal
// and maps the texture 1 texel = 1/px_per_unit metres, NEAREST filtered, so blocks
// read like the 2D tiles. Tops (normal up) use top_tex, everything else side_tex.
uniform sampler2D side_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D top_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 top_tint : source_color = vec4(1.0);
uniform float px_per_unit = 32.0;
uniform bool local_space = false;
// Darkens faces towards the bottom of the world (cheap fake AO / depth cue).
uniform float floor_shade = 0.0;
uniform float floor_y = 0.0;
// Cutaway (isometric): fragments above this world height are discarded.
uniform float cut_y = 100000.0;
// Pixel bevel along box edges (meshes from V3D.box_mesh(): UV = face metres from the
// face's top-left, UV2 = face size). Other meshes have UV2 = 0 and get no bevel.
uniform float bevel = 1.0;
uniform float metal = 0.0;
uniform float rough = 0.85;

varying vec3 v_pos;
varying vec3 v_nrm;
varying float v_wy;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wy = wp.y;
	if (local_space) {
		v_pos = VERTEX;
		v_nrm = NORMAL;
	} else {
		v_pos = wp;
		v_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	}
}

vec4 pixel_sample(bool front) {
	vec3 n = front ? v_nrm : -v_nrm;
	vec3 a = abs(n);
	vec2 uv;
	bool top = false;
	if (a.y >= a.x && a.y >= a.z) {
		uv = v_pos.xz;
		top = n.y > 0.0;
	} else if (a.x >= a.z) {
		uv = vec2(v_pos.z * sign(n.x), -v_pos.y);
	} else {
		uv = vec2(-v_pos.x * sign(n.z), -v_pos.y);
	}
	vec4 c;
	if (top) {
		vec2 ts = vec2(textureSize(top_tex, 0));
		c = texture(top_tex, uv * px_per_unit / ts) * top_tint;
	} else {
		vec2 ts = vec2(textureSize(side_tex, 0));
		c = texture(side_tex, uv * px_per_unit / ts) * tint;
		if (a.y >= a.x && a.y >= a.z) {
			c.rgb *= 0.7; // undersides
		}
	}
	// Slightly darker towards the room's floor (floor_y) for depth.
	c.rgb *= mix(1.0 - floor_shade, 1.0, smoothstep(floor_y, floor_y + 3.0, v_wy));
	return c;
}

// Brightness multiplier for the 1-2 texel rim along the face edges: top edges and the
// rim of top faces catch the light, bottom/side edges are shaded. Snapped to texels.
float bevel_shade(vec2 uv, vec2 uv2, bool top) {
	if (bevel <= 0.0 || uv2.x <= 0.0) {
		return 1.0;
	}
	vec2 t = floor(uv * px_per_unit);
	vec2 n = floor(uv2 * px_per_unit);
	float l = t.x;
	float r = n.x - 1.0 - t.x;
	float u = t.y;
	float d = n.y - 1.0 - t.y;
	float k = 1.0;
	if (top) {
		if (min(min(l, r), min(u, d)) < 1.0) {
			k = 1.28;
		}
	} else {
		if (u < 1.0) {
			k = 1.3;
		} else if (d < 1.0) {
			k = 0.62;
		} else if (min(l, r) < 1.0) {
			k = 0.8;
		} else if (u < 2.0) {
			k = 0.86;
		}
	}
	return mix(1.0, k, bevel);
}
