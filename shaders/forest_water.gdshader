shader_type spatial;
render_mode cull_disabled;
uniform float game_time = 0.0;
uniform bool waterfall = false;
void fragment() {
 float ripple = sin(UV.x * 34. + sin(UV.y*23. + game_time*.8)*1.5 + game_time*1.1);
 vec3 base = mix(vec3(.025,.14,.17), vec3(.07,.27,.30), ripple*.15+.35);
 if (waterfall) {
  float strands = smoothstep(.25,.8,sin(UV.x*35. + sin(UV.y*12. - game_time*3.)*.35));
  base = mix(vec3(.08,.32,.35),vec3(.44,.68,.65),strands*.65);
 }
 ALBEDO=base; ROUGHNESS=.32; METALLIC=.08;
}
