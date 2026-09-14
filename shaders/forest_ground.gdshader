shader_type spatial;
render_mode cull_back;
uniform sampler2D atlas : source_color, filter_linear_mipmap;
float soft_noise(vec2 p) {
 vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
 vec2 k=vec2(127.1,311.7);
 float a=fract(sin(dot(i,k))*43758.5453), b=fract(sin(dot(i+vec2(1,0),k))*43758.5453);
 float c=fract(sin(dot(i+vec2(0,1),k))*43758.5453),d=fract(sin(dot(i+vec2(1,1),k))*43758.5453);
 return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}
void fragment() {
 vec2 tile_uv = fract(UV) * .468 + .016;
 // Derivatives must precede fract: atlas wrap otherwise samples unrelated mip colours.
 vec2 dx = dFdx(UV) * .468, dy = dFdy(UV) * .468;
 vec3 grass = textureGrad(atlas, tile_uv + vec2(0., .5), dx, dy).rgb;
 vec3 sand = textureGrad(atlas, tile_uv + vec2(.5, .5), dx, dy).rgb;
 grass *= vec3(.82, 1.03, .82) * mix(.82,1.16,soft_noise(UV*2.4));
 sand = mix(sand, vec3(.76,.53,.31), .48) * mix(.94,1.035,soft_noise(UV*6.));
 ALBEDO = mix(grass, sand, smoothstep(0.,1.,COLOR.r));
 ROUGHNESS = .94;
}
