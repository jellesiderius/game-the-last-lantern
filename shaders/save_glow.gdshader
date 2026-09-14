shader_type canvas_item;
uniform float strength = 1.0;
void fragment() {
	float glow = exp(-dot(UV - .5, UV - .5) * 17.0);
	COLOR = vec4(1.0, .57, .12, glow * .24 * strength);
}
