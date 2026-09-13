shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
// Gameplay supplies the moving head and radius. The crescent behind it is a fading trail.
uniform float progress = 0.0;
uniform float blade_angle = 0.0;
uniform float direction = -1.0;
uniform float power = 0.0;
uniform float radius = 1.5;
uniform float half_angle = 1.309;
uniform float energy_extension = 0.0;
uniform float width_scale = 1.0;
uniform vec4 slash_color : source_color = vec4(1.0, 0.65, 0.075, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.94, 0.64, 1.0);
uniform float emission_strength = 3.0;
varying vec2 plane_position;
void vertex() { plane_position = VERTEX.xz; }
void fragment() {
    float r = length(plane_position);
    float angle = atan(plane_position.x, -plane_position.y);
    float behind = (blade_angle-angle)*direction;
    float sector = 1.0-smoothstep(half_angle,half_angle+.04,abs(angle));
    float tail = smoothstep(-.055,.035,behind)*(1.0-smoothstep(1.2,1.85,behind));
    float width = (.55+.42*power)*width_scale*sin(clamp((behind+.06)/1.9,0.0,1.0)*3.14159265);
    float inner = radius-width;
    float body = smoothstep(inner,inner+.045,r)*(1.0-smoothstep(radius-.02,radius+.02,r));
    float rim = (1.0-smoothstep(.018,.065,abs(r-radius)))*tail;
    // A radial flash visibly connects the full active energy edge to the actual weapon.
    float head = (1.0-smoothstep(.018,.055,abs(behind)))*energy_extension;
    head *= smoothstep(.22,.35,r)*(1.0-smoothstep(radius-.02,radius+.02,r));
    float echo_radius = radius-.25-.08*sin(behind*2.0-progress*8.0);
    float echo = (1.0-smoothstep(.015,.035,abs(r-echo_radius)))*.45;
    echo *= smoothstep(.25,.45,behind)*(1.0-smoothstep(1.1,1.6,behind));
    float streaks = pow(max(0.0,sin(angle*19.0-direction*progress*15.0)),14.0);
    streaks *= smoothstep(radius*.45,radius*.7,r)*(1.0-smoothstep(radius*.78,radius*.92,r))*.27*tail;
    float fade = 1.0-smoothstep(.92,1.55,progress);
    float mask = max(max(body*tail,rim*.9),max(head,echo+streaks))*sector*fade;
    vec3 tint = mix(slash_color.rgb,hot_color.rgb,clamp(rim*.8+head*.6,0.0,1.0));
    ALBEDO = tint;
    EMISSION = tint*(emission_strength+power*1.3);
    ALPHA = clamp(mask,0.0,.96)*slash_color.a;
}
