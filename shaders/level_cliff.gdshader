shader_type spatial;
render_mode cull_disabled;
// Cliff walls and their top lip. COLOR = base tint (cliff or lip colour per vertex).
// UV2.x = 1 on the lip, 0 on the block wall.
uniform sampler2D cliff_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_cliff_texture = false;
uniform float cliff_texture_scale = 2.0;
// Procedural chunky stone blocks, used until a real cliff texture is assigned.
uniform float block_height = 0.5;
uniform float block_length = 1.0;
// 0 = stone blocks, 1 = smooth plaster (interiors), 2 = faceted natural rock.
uniform int cliff_pattern = 0;
varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Nearest and second-nearest cell point: irregular rock faces and their cracks.
vec4 voronoi(vec2 p) {
	vec2 cell = floor(p);
	float first = 8.0;
	float second = 8.0;
	vec2 id = cell;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbour = cell + vec2(float(x), float(y));
			vec2 point = neighbour + vec2(hash(neighbour + 0.7), hash(neighbour + 3.9)) * 0.8 + 0.1;
			float d = distance(p, point);
			if (d < first) {
				second = first;
				first = d;
				id = neighbour;
			} else if (d < second) {
				second = d;
			}
		}
	}
	return vec4(id, first, second);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec3 n = abs(world_normal);
	// Distance along the wall itself, whatever its direction: the pattern keeps its
	// size on diagonal walls instead of stretching between the x and z axes.
	vec2 flat_normal = world_normal.xz;
	vec2 tangent = length(flat_normal) > 0.0001 ? normalize(vec2(-flat_normal.y, flat_normal.x)) : vec2(1.0, 0.0);
	float along = dot(world_pos.xz, tangent);
	vec3 color = COLOR.rgb;
	if (UV2.x < 0.5) {
		if (cliff_pattern == 2 && !has_cliff_texture) {
			// Natural rock like the original forest banks: large flat facets of uneven
			// size, each tilted towards the sun differently, with soft dark cracks.
			vec2 rock = vec2(along * 0.45, world_pos.y * 0.7);
			vec4 v = voronoi(rock);
			float crack = smoothstep(0.0, 0.05 + fwidth(v.w - v.z) * 1.5, v.w - v.z);
			vec3 lean = vec3(hash(v.xy + 1.3), hash(v.xy + 7.1) * 0.5, hash(v.xy + 4.2)) - 0.5;
			NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(lean * 0.35, 0.0)).xyz);
			color *= 0.94 + 0.12 * hash(v.xy + 9.4);
			color = mix(color * 0.88, color, crack);
		} else if (cliff_pattern == 1 && !has_cliff_texture) {
			color *= 0.96 + 0.05 * hash(floor(vec2(along, world_pos.y) * 3.0));
		} else if (has_cliff_texture) {
			color *= texture(cliff_texture, vec2(along, -world_pos.y) / cliff_texture_scale).rgb;
		} else {
			float row = floor(world_pos.y / block_height + 0.001);
			// Every row gets its own block length and offset, like stacked rough stone.
			float length_m = block_length * (0.6 + 0.9 * hash(vec2(row, 3.1)));
			vec2 cell = vec2(along / length_m + hash(vec2(row, 7.7)), world_pos.y / block_height + 0.001);
			vec2 f = fract(cell);
			vec2 id = floor(cell);
			vec2 edge_m = min(f, 1.0 - f) * vec2(length_m, block_height);
			float aa = max(fwidth(cell.x) * length_m, fwidth(cell.y) * block_height);
			float seam = smoothstep(0.012, 0.03 + aa, min(edge_m.x, edge_m.y));
			// Flat low-poly facets: each block leans a little, so the sun catches it
			// differently and the wall reads as chunky stone rather than a texture.
			vec3 lean = vec3(hash(id + 1.3), hash(id + 7.1), hash(id + 4.2)) - 0.5;
			NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(lean * 0.9, 0.0)).xyz);
			color *= 0.8 + 0.32 * hash(id + row * 3.1);
			// Chamfered underside of every block.
			color *= mix(0.62, 1.0, smoothstep(0.0, 0.25, f.y));
			color = mix(color * 0.4, color, seam);
		}
	} else {
		color *= 0.97 + 0.06 * hash(floor(vec2(along, world_pos.y) * 2.0));
	}
	ALBEDO = color;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
