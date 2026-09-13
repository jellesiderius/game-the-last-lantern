shader_type canvas_item;
render_mode unshaded;
uniform float animation_time = 0.0;
void fragment() {
 float d = length((UV - .5) * vec2(1.0, .88));
 float light = exp(-d * d * 18.0) * (1.0 - smoothstep(.3, .53, d));
 float flicker = .95 + .03 * sin(animation_time * 1.7) + .02 * sin(animation_time * 2.9 + .8);
 COLOR = vec4(.92, .57, .18, light * .2 * flicker);
}
