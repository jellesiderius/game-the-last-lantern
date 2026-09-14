shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
uniform vec4 slash_color : source_color = vec4(1.0, 0.65, 0.075, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.94, 0.64, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.9;
uniform float emission_strength : hint_range(0.0, 3.0) = 2.1;

void fragment() {
    // UV.x is remaining lifetime, UV.y crosses the real blade then its extension.
    // A soft amber thread replaces the opaque fan and its white radial outline.
    float tail = smoothstep(0.0, 0.75, UV.x) * (1.0 - smoothstep(0.975, 1.0, UV.x));
    float blade = exp(-pow((UV.y - 0.4) / 0.22, 2.0));
    float rim = smoothstep(0.86, 0.955, UV.y) * (1.0 - smoothstep(0.98, 1.0, UV.y));
    float veil = smoothstep(0.03, 0.25, UV.y) * (1.0 - smoothstep(0.86, 1.0, UV.y));
    float head = smoothstep(0.85, 1.0, UV.x) * veil;
    float mask = max(max(blade * 0.9, rim), max(veil * 0.23, head * 0.7));
    float core = max(rim * 0.9, blade * 0.6);
    vec3 tint = mix(slash_color.rgb, hot_color.rgb, core);
    ALBEDO = tint;
    EMISSION = tint * emission_strength * mix(0.35, 1.0, core);
    ALPHA = mask * tail * opacity * slash_color.a;
}
