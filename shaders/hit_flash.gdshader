shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;
uniform float flash = 0.0;
uniform vec4 hit_color : source_color = vec4(1.0,.7,.2,1.0);
void fragment() {
    // Contact frame and weapon-colored fade share the paused gameplay clock.
    vec3 tint = mix(hit_color.rgb, vec3(1.0), smoothstep(.045,.1,flash));
    ALBEDO = tint;
    EMISSION = tint * (flash > .065 ? 1.1 : .25);
    ALPHA = smoothstep(0.0,.045,flash)*.8;
}
