shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_draw_never;
uniform vec4 atmosphere_color : source_color = vec4(0.05, 0.55, 0.98, 1.0);
void fragment() {
    float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.3);
    ALBEDO = atmosphere_color.rgb * (1.0 + rim * 1.6);
    ALPHA = clamp(rim * 0.62, 0.0, 0.64);
}
