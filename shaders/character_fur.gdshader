shader_type spatial;
render_mode cull_back;
// Object-space micrograin fades below pixel size. Vertex colours preserve the authored coat regions.
varying vec3 coat_position;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float grain(vec3 p) {
    vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.0-2.0*f);
    return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { coat_position=VERTEX; }
void fragment() {
    vec3 frequency=coat_position*vec3(220.0,220.0,24.0);
    float detail=1.0-smoothstep(.4,1.2,length(fwidth(frequency)));
    float surface=grain(frequency);
    ALBEDO=COLOR.rgb*(1.0+(surface-.5)*.14*detail);
    ROUGHNESS=.84;
    SPECULAR=.22;
    vec3 x=dFdx(VERTEX);vec3 y=dFdy(VERTEX);
    vec3 r1=cross(y,NORMAL);vec3 r2=cross(NORMAL,x);
    float determinant=dot(x,r1);
    vec3 gradient=sign(determinant)*(dFdx(surface)*r1+dFdy(surface)*r2);
    NORMAL=normalize(NORMAL-gradient/max(abs(determinant),.000001)*.0006*detail);
}
