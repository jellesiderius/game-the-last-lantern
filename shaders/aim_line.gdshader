shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
uniform float charge = 0.0;
uniform float clock = 0.0;
uniform vec4 energy_color : source_color = vec4(1.0,.004,.024,1.0);
uniform vec4 glow_color : source_color = vec4(1.0,.018,.15,1.0);
uniform vec4 hot_color : source_color = vec4(1.0,.65,.72,1.0);
void fragment() {
    float pulse=.5+.5*sin(UV.y*45.0-clock*15.0);
    ALBEDO=mix(hot_color.rgb,energy_color.rgb,charge*.55);
    EMISSION=mix(glow_color.rgb,energy_color.rgb*3.0,charge)*(.8+pulse*.25);
    ALPHA=.32+charge*.24;
}
