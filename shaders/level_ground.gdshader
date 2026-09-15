shader_type spatial;
// Stair treads and risers are real geometry, seen from any side.
render_mode cull_disabled;
uniform vec4 ground_color : source_color = vec4(.47, .6, .3, 1.);
uniform vec4 path_color : source_color = vec4(.83, .72, .5, 1.);
uniform sampler2D ground_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D path_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_ground_texture = false;
uniform bool has_path_texture = false;
// R = path coverage, G = soft shadow at the foot of cliffs.
uniform sampler2D path_mask : filter_linear_mipmap, repeat_disable;
uniform bool has_path_mask = false;
uniform int ground_pattern = 0;
uniform float texture_scale = 3.0;
uniform vec4 stair_color : source_color = vec4(.5, .52, .48, 1.);
varying vec4 ramp_data;

void vertex() {
	// r = stair geometry, g = 1 on a riser, 0 on a tread.
	ramp_data = CUSTOM0;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x),
		f.y
	);
}

void fragment() {
	vec2 pos = UV * texture_scale;
	vec3 ground = ground_color.rgb;
	vec3 path = path_color.rgb;
	// Flat, clean colour in the style of Tunic: only broad soft patches; the sun,
	// shadows and cliff contact shading provide the depth.
	float broad = noise(pos * .09) * .6 + noise(pos * .23) * .4;
	if (has_ground_texture) {
		// Like the original forest ground: the painted tile, tinted by the ground colour,
		// under a soft cloud of lighter and darker grass.
		ground *= texture(ground_texture, UV).rgb * mix(.82, 1.16, noise(UV * 2.4));
	} else if (ground_pattern == 1) {
		ground *= mix(.92, 1.07, broad);
		ground = mix(ground, ground * vec3(1.07, 1.05, .85), smoothstep(.55, .8, broad) * .45);
	} else if (ground_pattern == 2) {
		vec2 tiled = UV * vec2(1.0, 1.6);
		tiled.x += mod(floor(tiled.y), 2.0) * .5;
		vec2 edge = min(fract(tiled), 1.0 - fract(tiled));
		float width = max(fwidth(tiled.x), fwidth(tiled.y));
		float slab = smoothstep(.012 - width, .025 + width, min(edge.x, edge.y));
		ground *= mix(.78, 1.0, slab) * (.95 + .08 * hash(floor(tiled)));
	} else if (ground_pattern == 5) {
		// Grass like the original forest: warm yellow-green and cooler blue-green
		// drifting through each other, broken into irregular metre-sized patches with
		// a few lighter sunny spots, so a field never reads as one flat colour.
		vec2 p = UV * 0.85;
		vec2 cell = floor(p);
		float nearest = 8.0;
		vec2 id = cell;
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec2 n = cell + vec2(float(x), float(y));
				vec2 point = n + vec2(hash(n + .7), hash(n + 3.9)) * .8 + .1;
				float d = distance(p, point);
				if (d < nearest) {
					nearest = d;
					id = n;
				}
			}
		}
		float drift = noise(UV * .07) * .65 + noise(UV * .19 + 4.0) * .35;
		vec3 warm = ground * vec3(1.1, 1.06, .86);
		vec3 cool = ground * vec3(.9, 1.0, 1.05);
		ground = mix(cool, warm, smoothstep(.3, .72, drift));
		float patch = hash(id);
		ground *= .93 + .12 * patch;
		ground = mix(ground, ground * vec3(1.08, 1.06, .92), step(.88, patch) * .5);
	} else if (ground_pattern == 4) {
		// Floorboards like the Forest house: half-metre wide planks running the length
		// of the room in three alternating tones with a dark seam between them.
		float boards = pos.y * 2.0;
		float row = floor(boards);
		float f = fract(boards);
		float seam_w = fwidth(boards) * 1.5;
		float seam = smoothstep(0.0, .025 + seam_w, min(f, 1.0 - f));
		float tone = 1.0 + .046 * mod(row, 3.0);
		ground *= tone * mix(.45, 1.0, seam);
	} else {
		ground *= mix(.94, 1.04, broad);
	}
	if (has_path_texture) {
		// The painted sand blended halfway towards the path colour, as in the forest.
		path = mix(texture(path_texture, UV).rgb, path_color.rgb, .48) * mix(.94, 1.035, noise(UV * 6.0));
	} else {
		path *= mix(.95, 1.04, noise(pos * .35));
	}
	vec4 mask = has_path_mask ? texture(path_mask, UV2) : vec4(COLOR.r, 0.0, 0.0, 0.0);
	// A clean, gently wobbling border between grass and path.
	float value = clamp(mask.r + (noise(pos * 1.1) - .5) * .28, 0.0, 1.0);
	float soft = max(fwidth(value), .004);
	float on_path = smoothstep(.5 - soft, .5 + soft, value);
	vec3 color = mix(ground, path, on_path);
	if (ramp_data.r > .5) {
		color = ramp_data.g > .5 ? stair_color.rgb * .72 : stair_color.rgb;
	}
	// Contact shade where lower ground meets a cliff.
	color *= 1.0 - .4 * pow(mask.g, .8);
	ALBEDO = color;
	ROUGHNESS = 1.0;
	SPECULAR = .1;
}
