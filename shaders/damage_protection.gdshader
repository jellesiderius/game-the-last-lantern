shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.87, 0.62, 1.0);
void fragment() {
    float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
    ALBEDO = tint.rgb;
    EMISSION = tint.rgb * strength * 0.35;
    ALPHA = strength * (0.35 + rim * 0.65);
}
