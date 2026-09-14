shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
uniform vec4 slash_color : source_color = vec4(1.0, 0.65, 0.075, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.94, 0.64, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.9;
uniform float emission_strength : hint_range(0.0, 3.0) = 2.1;
// Arc mode: UV.x runs along the whole swing (0 start, 1 end), UV.y from the inner
// edge to the outer energy rim. `head` is the same eased progress that turns the
// sword, so the crescent is always filled exactly up to the blade.
uniform bool arc_mode = false;
uniform float head = 0.0;
uniform float age : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec3 tint;
    float alpha;
    float glow;
    if (arc_mode) {
        float u = UV.x;
        float v = UV.y;
        float h = max(head, 0.001);
        float revealed = 1.0 - smoothstep(h - 0.005, h + 0.01, u);
        // Crescent: thick at the sword, tapering toward where the cut began.
        float rel = clamp(u / h, 0.0, 1.0);
        float profile = mix(0.12, 1.0, pow(rel, 1.4)) * smoothstep(0.0, 0.05, u);
        // Once complete it retreats to the rim and erodes from the tail.
        float thickness = profile * (1.0 - 0.75 * smoothstep(0.0, 1.0, age));
        float inner_edge = 1.0 - thickness;
        float body = smoothstep(inner_edge - 0.03, inner_edge + 0.14, v) * (1.0 - smoothstep(0.965, 1.0, v));
        float rim = smoothstep(0.8, 0.93, v) * (1.0 - smoothstep(0.965, 1.0, v)) * smoothstep(0.02, 0.2, rel);
        float streaks = pow(max(0.0, sin(v * 36.0 + u * 5.0)), 10.0) * 0.25 * body;
        float erode = smoothstep(age * 1.25 - 0.25, age * 1.25 + 0.02, u);
        // Hot leading edge right behind the blade while it cuts.
        float lead = smoothstep(h - 0.18, h, u) * (1.0 - smoothstep(0.0, 0.35, age));
        float mask = max(body * mix(0.4, 0.9, v), rim) + streaks;
        tint = mix(slash_color.rgb, hot_color.rgb, clamp(rim * 0.8 + lead * 0.7, 0.0, 1.0));
        glow = mix(0.55, 1.0, rim) + lead * 0.9;
        alpha = clamp(mask * revealed * erode, 0.0, 1.0) * (1.0 - smoothstep(0.8, 1.0, age));
    } else {
        // Legacy ribbon: UV.x is remaining lifetime, UV.y crosses the real blade then its extension.
        float tail = smoothstep(0.0, 0.75, UV.x) * (1.0 - smoothstep(0.975, 1.0, UV.x));
        float blade = exp(-pow((UV.y - 0.4) / 0.22, 2.0));
        float rim = smoothstep(0.86, 0.955, UV.y) * (1.0 - smoothstep(0.98, 1.0, UV.y));
        float veil = smoothstep(0.03, 0.25, UV.y) * (1.0 - smoothstep(0.86, 1.0, UV.y));
        float head_glow = smoothstep(0.85, 1.0, UV.x) * veil;
        float mask = max(max(blade * 0.9, rim), max(veil * 0.23, head_glow * 0.7));
        float core = max(rim * 0.9, blade * 0.6);
        tint = mix(slash_color.rgb, hot_color.rgb, core);
        glow = mix(0.35, 1.0, core);
        alpha = mask * tail;
    }
    ALBEDO = tint;
    EMISSION = tint * emission_strength * glow;
    ALPHA = alpha * opacity * slash_color.a;
}
