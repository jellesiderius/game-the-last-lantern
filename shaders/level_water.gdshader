shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Depth absorption/intersection technique inspired by Malido (CC0), Godot Shaders.
// Reconstructed world depth supports both orthographic and perspective cameras.
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear_mipmap;
group_uniforms Color;
uniform vec4 shallow_color : source_color = vec4(0.10, 0.70, 0.78, 1.0);
uniform vec4 deep_color : source_color = vec4(0.025, 0.17, 0.56, 1.0);
uniform float absorption : hint_range(0.05, 5.0) = 0.8;
uniform float shallow_tint : hint_range(0.0, 1.0) = 0.42;
uniform float depth_range : hint_range(0.2, 20.0) = 3.4;
group_uniforms Foam;
uniform vec4 foam_color : source_color = vec4(0.86, 0.99, 0.97, 1.0);
uniform float foam_depth : hint_range(0.02, 2.0) = 0.24;
uniform float foam_strength : hint_range(0.0, 1.0) = 0.9;
uniform float foam_noise_scale : hint_range(0.2, 12.0) = 3.8;
group_uniforms Waves;
uniform vec2 flow_direction = vec2(0.8, 0.3);
uniform float wave_speed : hint_range(0.0, 3.0) = 0.5;
uniform float wave_scale : hint_range(0.1, 8.0) = 1.6;
uniform float refraction_strength : hint_range(0.0, 0.04) = 0.006;
uniform float glint_strength : hint_range(0.0, 0.4) = 0.055;
uniform float caustic_strength : hint_range(0.0, 0.5) = 0.09;
group_uniforms Interaction;
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.28;
// Supplied per water instance by LevelWater, never shared between worlds.
// Up to four wading actors: xyz = position, w = motion (0 still .. 1 moving).
uniform vec4 actors[4];
group_uniforms;
varying vec3 surface_world;

float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise2(vec2 p) {
 vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
 return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
vec3 world_at(vec2 uv, mat4 inv_projection, mat4 inv_view) {
 float depth = textureLod(scene_depth,uv,0.0).r;
 #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
 vec3 ndc = vec3(uv,depth)*2.0-1.0;
 #else
 vec3 ndc = vec3(uv*2.0-1.0,depth);
 #endif
 vec4 p = inv_view*inv_projection*vec4(ndc,1.0);
 return p.xyz/(abs(p.w)<0.000001 ? 0.000001 : p.w);
}
void vertex() { surface_world = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec3 floor_world = world_at(SCREEN_UV,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX);
 float raw_depth = surface_world.y-floor_world.y;
 float depth = clamp(raw_depth,0.0,50.0);
 vec2 drift = flow_direction*TIME*wave_speed;
 vec2 p = surface_world.xz*wave_scale;
 float n = noise2(p+drift);
 vec2 wave = vec2(sin(p.x*1.7+p.y*.6+TIME*wave_speed*1.8+n*2.0),cos(p.y*1.4-p.x*.4-TIME*wave_speed*1.2+n*2.0));
 // Fade distortion at intersections. Reject samples of objects above the surface.
 vec2 refracted_uv = SCREEN_UV+wave*refraction_strength*smoothstep(0.02,0.55,depth);
 bool inside = all(greaterThan(refracted_uv,vec2(0.001))) && all(lessThan(refracted_uv,vec2(0.999)));
 vec3 refracted_floor = world_at(clamp(refracted_uv,vec2(0.001),vec2(0.999)),INV_PROJECTION_MATRIX,INV_VIEW_MATRIX);
 if (!inside || refracted_floor.y>surface_world.y-0.025) { refracted_uv=SCREEN_UV; refracted_floor=floor_world; }
 vec3 background = textureLod(scene_color,refracted_uv,0.0).rgb;
 float refracted_depth = clamp(surface_world.y-refracted_floor.y,0.0,50.0);
 float density = 1.0-exp(-absorption*refracted_depth);
 vec3 tint = mix(shallow_color.rgb,deep_color.rgb,1.0-exp(-depth/max(0.1,depth_range*0.45)));
 vec3 color = mix(background,tint,shallow_tint+(1.0-shallow_tint)*density);
 // Animated light on the submerged geometry, rather than painted onto the plane.
 vec2 q = refracted_floor.xz*2.6;
 float caustic = pow(max(0.0,1.0-abs(sin(q.x+sin(q.y*.8+TIME*.6)) + sin(q.y-TIME*.45))),14.0);
 color += caustic*caustic_strength*exp(-refracted_depth*.75)*smoothstep(0.03,.3,depth)*vec3(.50,.92,.78);
 float foam_noise = noise2(surface_world.xz*foam_noise_scale-drift*.65);
 float foam_width = foam_depth*(.65+foam_noise*.65);
 float contact = 1.0-smoothstep(foam_width*.25,foam_width,max(0.0,raw_depth));
 float foam_breakup = .65+.35*smoothstep(.24,.64,foam_noise);
 float foam = contact*foam_breakup*foam_strength;
 // Motion-driven rings around every wading actor; they fade out when it stops or leaves.
 float rings = 0.0;
 for (int i = 0; i < 4; i++) {
  float d = length(surface_world.xz-actors[i].xz);
  float ring = pow(max(0.0,sin(d*16.0-TIME*5.2)),10.0);
  rings += ring*(1.0-smoothstep(.25,1.8,d))*smoothstep(.15,.42,d)*actors[i].w*ripple_strength;
 }
 float glint = pow(max(0.0,wave.x*wave.y),24.0)*glint_strength;
 color += (glint+rings)*vec3(.60,.90,1.0);
 ALBEDO = mix(color,foam_color.rgb,clamp(foam,0.0,1.0));
 // Forces the transparent pass, after opaque depth/color have been captured.
 // Color already includes the refracted background, so do not blend it a second time.
 ALPHA = 1.0;
}
