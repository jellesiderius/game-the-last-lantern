shader_type spatial;
uniform vec4 ground_color : source_color = vec4(.3,.4,.25,1.);
uniform vec4 path_color : source_color = vec4(.7,.6,.4,1.);
uniform sampler2D ground_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D path_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_ground_texture = false;
uniform bool has_path_texture = false;
uniform sampler2D path_mask : filter_linear_mipmap, repeat_disable;
uniform bool has_path_mask = false;
uniform int ground_pattern = 0;
void fragment() {
    vec3 ground = ground_color.rgb;
    vec3 path = path_color.rgb;
    if (has_ground_texture) ground *= texture(ground_texture, UV).rgb;
    if (has_path_texture) path *= texture(path_texture, UV).rgb;
    if (!has_ground_texture && ground_pattern == 1) {
        ground *= .97 + .03 * sin(UV.x * 17.0 + sin(UV.y * 11.0));
    } else if (!has_ground_texture && ground_pattern == 2) {
        vec2 tiled = UV * vec2(1.0, 1.6);
        tiled.x += mod(floor(tiled.y), 2.0) * .5;
        vec2 edge = min(fract(tiled), 1.0 - fract(tiled));
        float width = max(fwidth(tiled.x), fwidth(tiled.y));
        float slab = smoothstep(.018 - width, .035 + width, min(edge.x, edge.y));
        ground *= mix(.65, 1.0, slab);
    } else if (!has_ground_texture && ground_pattern == 3) {
        ground *= .97 + .03 * sin(UV.x * 7.3 + sin(UV.y * 9.1));
    }
    float variation = .97 + .03 * sin(UV.x * 5.1 + sin(UV.y * 3.7));
    float coverage = has_path_mask ? texture(path_mask, UV2).r : COLOR.r;
    ALBEDO = mix(ground, path, coverage) * variation;
    ROUGHNESS = .96;
}
