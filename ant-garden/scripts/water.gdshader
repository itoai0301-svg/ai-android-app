shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley;
uniform vec4 water : source_color = vec4(0.13,0.55,0.56,1.0);
varying vec3 world_pos;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	VERTEX.y += sin(VERTEX.x*3.5+TIME*1.1)*0.012+cos(VERTEX.z*4.2+TIME)*0.009;
}
void fragment() {
	float ripple=sin(world_pos.x*5.0+world_pos.z*3.0+TIME*1.7)*sin(world_pos.z*4.0-TIME);
	ALBEDO=water.rgb + vec3(0.09,0.13,0.11)*ripple;
	ROUGHNESS=0.2;
	SPECULAR=0.8;
	METALLIC=0.18;
}

