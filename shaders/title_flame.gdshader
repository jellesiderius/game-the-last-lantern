shader_type canvas_item;
render_mode unshaded;
uniform float animation_time = 0.0;

void fragment() {
	float t = animation_time;
	float height = (1.0 - UV.y - .04) / (.90 + .025 * sin(t * 1.6) + .018 * sin(t * 2.7 + .8));
	float h = clamp(height, .001, .999);
	float sway = h * h * (.070 * sin(t * 1.7 + h * 2.8) + .025 * sin(t * 3.1 + h * 6.0));
	float center = .50 + sway;
	float width = .34 * pow(sin(h * 3.14159265), .78) * (1.0 - h * .55);
	width *= 1.0 + .06 * sin(t * 2.4 - h * 9.0);
	float distance = abs(UV.x - center) / max(.001, width);
	float shape = 1.0 - smoothstep(.74, 1.04, distance);
	shape *= smoothstep(0.0, .035, height) * (1.0 - smoothstep(.96, 1.0, height));
	float inner = (1.0 - smoothstep(.12, .74, distance)) * (1.0 - smoothstep(.26, .86, h));
	vec3 color = mix(vec3(1.0, .40, .025), vec3(1.0, .74, .19), 1.0 - distance * .65);
	color = mix(color, vec3(1.0, .96, .70), inner * .85);
	COLOR = vec4(color, shape * .95);
}
