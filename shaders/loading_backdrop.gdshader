shader_type canvas_item;
render_mode unshaded;
uniform float animation_time = 0.0;
void fragment() {
 vec2 p = (UV - vec2(.5, .43)) * vec2(TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x, 1.0);
 float halo = exp(-dot(p, p) * 12.0);
 float vignette = smoothstep(.8, .18, length(UV - .5));
 vec3 color = mix(vec3(.012, .035, .039), vec3(.031, .104, .112), vignette);
 color += vec3(.062, .049, .019) * halo;
 COLOR = vec4(color, 1.0);
}
