shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
uniform vec4 slash_color : source_color = vec4(1., .004, .024, 1.);
uniform vec4 hot_color : source_color = vec4(1., .94, .64, 1.);
uniform float progress : hint_range(0.,1.) = 0.;
uniform bool charging = false;
uniform float impact_radius = 1.5;
varying vec2 p;
void vertex() { p = VERTEX.xz; }
void fragment() {
    float r = length(p);
    float angle = atan(p.x, -p.y);
    float mask;
    float hot;
    if (charging) {
        float radius = mix(.9, .65, progress);
        float ring = 1. - smoothstep(.014, .037, abs(r-radius));
        float dashes = smoothstep(.15, .65, sin(angle*8. + progress*9.));
        float pulse = smoothstep(.75, 1., progress)*pow(.5+.5*sin(progress*55.), 6.);
        mask = ring*dashes*(.35+progress*.60) + (1.-smoothstep(.02,.055,abs(r-.52)))*pulse*.6;
        hot = progress*.35;
    } else {
        float sector = 1.-smoothstep(1.12,1.34,abs(angle));
        float radius = mix(.32,impact_radius,1.-pow(1.-progress,3.));
        float ring = 1.-smoothstep(.025,.16,abs(r-radius));
        float rays = pow(max(0.,sin(angle*23.+.7)),18.);
        rays *= smoothstep(.25,.5,r)*(1.-smoothstep(radius-.22,radius,r));
        float fade = (1.-smoothstep(.35,1.,progress))*smoothstep(0.,.035,progress);
        float crack_angle=angle+sin(r*19.)*.024;
        float cracks=pow(max(0.,cos(crack_angle*12.)),38.);
        cracks*=smoothstep(.3,.65,r)*(1.-smoothstep(radius-.2,radius,r));
        float inner_wave=1.-smoothstep(.018,.07,abs(r-radius*.74));
        mask = max(max(ring*.9,rays*.6),max(cracks*.7,inner_wave*.5))*sector*fade;
        hot = ring*.55;
    }
    vec3 tint = mix(slash_color.rgb,hot_color.rgb,hot);
    ALBEDO = tint;
    EMISSION = tint*(charging ? 2.4 : 5.5);
    ALPHA = clamp(mask,0.,.94);
}
