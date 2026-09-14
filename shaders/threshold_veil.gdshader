shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;
uniform bool completed = false;
uniform float game_time = 0.0;

void fragment() {
    vec2 p = vec2(UV.x, 1.0-UV.y);
    float top_width = sqrt(max(0.0, 1.0 - pow(max(0.0, (p.y - 0.58) / 0.42), 2.0)));
    if (abs(p.x-.5) > top_width*.5) { discard; }
    float wave = .5 + .34*sin(p.y*7.0-game_time*.65);
    float ribbon = exp(-pow((p.x-wave)/.024,2.0));
    ribbon *= smoothstep(.02,.22,p.y)*(1.0-smoothstep(.7,.98,p.y));
    float mist = .6+.4*sin(p.y*9.0 + p.x*4.0 - game_time*.32);
    vec3 tint = completed ? vec3(.76,.30,.025) : vec3(.22,.25,.27);
    vec3 highlight = completed ? vec3(1.0,.77,.28) : vec3(.47,.51,.53);
    ALBEDO = mix(tint, highlight, .18*mist + ribbon*.65);
    EMISSION = completed ? ALBEDO*(.25+ribbon*.8) : vec3(0.0);
}
