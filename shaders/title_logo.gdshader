shader_type canvas_item;
render_mode unshaded;
// The supplied gold lettering is isolated from its teal plate without redrawing the logo.
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	// Teal background has very little red; cream highlights must stay fully opaque.
	float lettering = smoothstep(.07, .23, source.r) * (1.0 - step(.286, UV.y));
	COLOR = vec4(source.rgb, lettering * COLOR.a);
}
