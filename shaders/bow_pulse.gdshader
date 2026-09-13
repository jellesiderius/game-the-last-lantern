shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
uniform float intensity = 0.0;
uniform float phase = 0.0;
uniform vec4 energy_color : source_color = vec4(1.0,.004,.024,1.0);
uniform vec4 glow_color : source_color = vec4(1.0,.018,.15,1.0);
uniform vec4 hot_color : source_color = vec4(1.0,.65,.72,1.0);
varying vec2 plane_position;
void vertex() { plane_position = VERTEX.xz; }
void fragment() {
    vec2 p=plane_position;
    float r=length(p);
    float radius=.10+.20*clamp(phase,0.0,1.0);
    float ring=(1.0-smoothstep(.008,.027,abs(r-radius)));
    float star=pow(max(0.0,1.0-abs(p.x*p.y)*190.0),4.0)*(1.0-smoothstep(.02,.25,r));
    float core=1.0-smoothstep(.01,.075,r);
    ALBEDO=energy_color.rgb;
    EMISSION=glow_color.rgb*5.5+hot_color.rgb*core*3.0;
    ALPHA=(ring*.45+star*.6+core)*intensity;
}
