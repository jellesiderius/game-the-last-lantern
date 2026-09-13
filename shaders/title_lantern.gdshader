shader_type canvas_item;
render_mode unshaded;

uniform float animation_time = 0.0;
uniform float flicker_strength : hint_range(0.0, 1.0) = 1.0;
uniform bool foreground_only = false;

float noise(float t) {
	float i = floor(t);
	float f = smoothstep(0.0, 1.0, fract(t));
	return mix(fract(sin(i * 127.1 + 13.4) * 43758.5453),
		fract(sin((i + 1.0) * 127.1 + 13.4) * 43758.5453), f);
}

void fragment() {
	vec4 plate = texture(TEXTURE, UV);
	float time = animation_time;
	float flicker = ((noise(time * 1.25) - .5) * .06
		+ (noise(time * 3.7) - .5) * .024
		+ (noise(time * .43) - .5) * .05) * flicker_strength;
	float lamp = (1.0 - smoothstep(.035, .047, abs(UV.x - .500)))
		* smoothstep(.548, .565, UV.y) * (1.0 - smoothstep(.796, .806, UV.y));
	float warm = smoothstep(.09, .24, plate.r - plate.b);
	float core = exp(-dot((UV - vec2(.500, .715)) / vec2(.021, .059),
		(UV - vec2(.500, .715)) / vec2(.021, .059)));
	float halo = exp(-dot((UV - vec2(.500, .704)) / vec2(.075, .128),
		(UV - vec2(.500, .704)) / vec2(.075, .128)));
	float pool = exp(-dot((UV - vec2(.504, .856)) / vec2(.208, .077),
		(UV - vec2(.504, .856)) / vec2(.208, .077)));
	vec3 lit = plate.rgb * (1.0 + flicker * (lamp * warm + pool * warm * .35));
	lit += vec3(1.0, .44, .055) * (core * .055 + halo * .013) * (1.0 + flicker * 3.0);
	float interior = step(.480, UV.x) * (1.0 - step(.521, UV.x))
		* step(.658, UV.y) * (1.0 - step(.778, UV.y));
	float foreground = max(lamp * smoothstep(.045, .10, plate.r - plate.b) * (1.0 - interior), step(.798, UV.y));
	COLOR = vec4(lit, foreground_only ? foreground : 1.0);
}
