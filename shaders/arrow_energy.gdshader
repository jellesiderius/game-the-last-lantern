shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
// A readable hot streak inside the same crimson/rose palette as the melee crescent.
uniform float age = 0.0;
uniform float power = 1.0;
uniform vec4 energy_color : source_color = vec4(1.0,.004,.024,1.0);
uniform vec4 glow_color : source_color = vec4(1.0,.018,.15,1.0);
uniform vec4 hot_color : source_color = vec4(1.0,.65,.72,1.0);
varying vec2 plane_position;
void vertex() { plane_position = VERTEX.xz; }
void fragment() {
    float t = clamp((plane_position.y + .575) / 1.15, 0.0, 1.0);
    float bend = sin(t * 17.0 - age * 36.0) * .007 * t;
    float width = .15 * pow(1.0 - t, .8) * smoothstep(0.0,.08,t);
    float d = abs(plane_position.x - bend);
    float aa = max(fwidth(d), .002);
    float body = 1.0 - smoothstep(width-aa,width+aa,d);
    float core = 1.0 - smoothstep(.018,.045,d);
    float fade = (1.0 - smoothstep(.68,1.0,t)) * smoothstep(0.0,.035,t);
    vec3 red = energy_color.rgb;
    vec3 hot = hot_color.rgb;
    ALBEDO = mix(red,hot,core*.85);
    EMISSION = mix(red*5.5,hot*7.5,core) * power;
    ALPHA = body*fade*.94;
}
