shader_type canvas_item;
render_mode unshaded;
uniform float reveal : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	VERTEX.y += (1.0 - reveal) * 4.0;
}

void fragment() {
	COLOR.a *= reveal;
}
