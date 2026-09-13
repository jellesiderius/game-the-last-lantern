shader_type canvas_item;
render_mode unshaded;
uniform float animation_time = 0.0;
void fragment() {
 float end_fade = smoothstep(0.0, .12, UV.x) * (1.0 - smoothstep(.88, 1.0, UV.x));
 float x = .5 - .42 * cos(animation_time * 1.8);
 float glow = exp(-pow((UV.x - x) * 12.0, 2.0));
 COLOR = vec4(mix(vec3(.47, .37, .21), vec3(.98, .82, .48), glow), end_fade * (.2 + .8 * glow));
}
