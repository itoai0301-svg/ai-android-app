shader_type spatial;
render_mode cull_disabled, diffuse_burley;
void vertex() {
	float phase=MODEL_MATRIX[3].x*0.7+MODEL_MATRIX[3].z*0.5;
	VERTEX.x+=sin(TIME*1.5+phase)*UV.y*UV.y*0.07;
	VERTEX.z+=cos(TIME*1.2+phase)*UV.y*UV.y*0.04;
}
void fragment() {
	ALBEDO=mix(vec3(0.06,0.12,0.025),vec3(0.22,0.35,0.075),UV.y)*(0.85+COLOR.g*0.6);
	EMISSION=vec3(0.012,0.024,0.003)*UV.y;
	ROUGHNESS=0.92;
}
