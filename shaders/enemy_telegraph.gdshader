shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
// The AI supplies its windup fraction. No independent TIME-driven countdown.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float reach = 1.32;
uniform float half_angle = 1.13;
uniform bool active = false;
varying vec2 position_on_plane;
void vertex() { position_on_plane = VERTEX.xz; }
void fragment() {
    float radius = length(position_on_plane);
    float angle = abs(atan(position_on_plane.x, -position_on_plane.y));
    float sector = 1.0 - smoothstep(half_angle - .02, half_angle + .02, angle);
    float disk = 1.0 - smoothstep(reach - .02, reach + .01, radius);
    float boundary = smoothstep(reach - .045, reach - .018, radius) * disk;
    float sides = smoothstep(half_angle - .025, half_angle - .008, angle) * disk;
    float amount = active ? 1.0 : clamp(progress, 0.0, 1.0);
    // Local -Z is the leading edge: fill travels from that edge back to the actor.
    float depth = clamp((position_on_plane.y + reach) / reach, 0.0, 1.0);
    float filled = (1.0 - smoothstep(amount - .008, amount + .008, depth)) * step(.001, amount);
    float front = (1.0 - smoothstep(.007, .023, abs(depth - amount))) * step(.001, amount) * (1.0 - step(.999, amount));
    vec3 orange = vec3(1.0, .28, .018);
    vec3 red = vec3(1.0, .012, .025);
    float urgency = smoothstep(.72, 1.0, amount) * .52;
    float final_phase = clamp((amount - .84) / .16, 0.0, 1.0);
    float flash = active ? 0.0 : pow(sin(final_phase * 3.14159265), 6.0);
    vec3 warning = active ? red : mix(orange, red, urgency);
    warning = mix(warning, vec3(1.0, .77, .32), flash * .38);
    ALBEDO = warning;
    EMISSION = warning * (active ? 1.35 : .32 + .25 * front + flash * .65);
    ALPHA = sector * max(max(boundary, sides) * .76, disk * (.045 + filled * .39 + front * .22));
}
