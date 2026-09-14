shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
uniform float flame_time = 0.0;
uniform float phase = 0.0;
varying float height;
void vertex() {
	height = clamp(VERTEX.y / .88, 0.0, 1.0);
	float bend = height * height;
	float rising = sin(height * 13.0 - flame_time * 5.8 + phase);
	VERTEX.xz *= 1.0 + rising * .12 * sin(height * 3.14159);
	VERTEX.x += (sin(flame_time * 3.1 + height * 5.0 + phase) * .10 + sin(flame_time * 5.3 + phase) * .025) * bend;
	VERTEX.z += sin(flame_time * 2.6 + height * 4.0 + phase) * .037 * bend;
	VERTEX.y *= 1.0 + sin(flame_time * 3.7 + phase) * .08 * height;
}
void fragment() {
	float face = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rise = sin(height * 15.0 - flame_time * 5.8 + phase);
	float core = smoothstep(.36, .88, face) * (1.0 - smoothstep(.28 + rise * .045, .84, height));
	vec3 edge = mix(vec3(1.0, .055, .001), vec3(1.0, .27, .006), face);
	vec3 warm = mix(edge, vec3(1.0, .88, .23), core);
	ALBEDO = warm;
	EMISSION = warm * (.55 + core * 1.35);
	ALPHA = .93;
}
