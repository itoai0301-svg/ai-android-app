shader_type spatial;
render_mode diffuse_burley;
uniform vec4 soil : source_color = vec4(0.10, 0.16, 0.045, 1.0);
uniform vec4 moss : source_color = vec4(0.24, 0.33, 0.10, 1.0);
varying vec2 ground_pos;
void vertex() { ground_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz; }
float line_dist(vec2 p,vec2 a,vec2 b) {
	vec2 v=b-a; return length(p-a-v*clamp(dot(p-a,v)/dot(v,v),0.0,1.0));
}
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
	vec2 p=UV*42.0;
	float n=noise(p)*0.55+noise(p*3.2)*0.28+noise(p*12.0)*0.17;
	vec3 lawn = mix(soil.rgb,moss.rgb,n);
	float d=min(line_dist(ground_pos,vec2(-7.5,2.7),vec2(-1.0,1.0)),line_dist(ground_pos,vec2(-1.0,1.0),vec2(7.0,4.0)));
	d=min(d,line_dist(ground_pos,vec2(-1.0,1.0),vec2(-2.0,-5.5)));
	float trail=1.0-smoothstep(0.32,0.9,d+noise(ground_pos*5.0)*0.3);
	ALBEDO = mix(lawn,vec3(0.26,0.205,0.11)*(0.82+n*0.35),trail*0.65);
	ROUGHNESS=0.95;
}

