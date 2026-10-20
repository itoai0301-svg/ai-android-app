shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform int planet_kind = 0;
uniform float time_phase = 0.0;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}
float noise2(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float fbm(vec2 p) {
    float s = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        s += a * noise2(p);
        p = p * 2.03 + vec2(8.1, 4.7);
        a *= 0.5;
    }
    return s;
}
void fragment() {
    vec2 uv = UV;
    float latitude = abs(uv.y - 0.5) * 2.0;
    float n = fbm(uv * vec2(7.0, 4.2) + vec2(0.0, sin(uv.y * 12.0) * 0.15));
    float details = fbm(uv * vec2(46.0, 25.0));
    vec3 c = vec3(0.02, 0.09, 0.18);
    float metal = 0.0;
    float rough = 0.88;
    if (planet_kind == 0) {
        float land = fbm(uv * vec2(5.8, 4.8) + vec2(sin(uv.y * 16.0) * 0.34, 0.0));
        land += 0.13 * (details - 0.5);
        float coast = smoothstep(0.46, 0.53, land);
        vec3 ocean = mix(vec3(0.003, 0.02, 0.07), vec3(0.005, 0.25, 0.33), smoothstep(0.33, 0.68, n));
        vec3 green = mix(vec3(0.04, 0.18, 0.09), vec3(0.25, 0.29, 0.10), n);
        vec3 dry = mix(vec3(0.36, 0.27, 0.10), vec3(0.43, 0.34, 0.19), details);
        vec3 terrain = mix(green, dry, smoothstep(0.48, 0.78, n + latitude * 0.16));
        c = mix(ocean, terrain, coast);
        float snow = smoothstep(0.79, 0.96, latitude + 0.09 * details);
        c = mix(c, vec3(0.79, 0.90, 0.92), snow);
        float cloud = smoothstep(0.66, 0.79, fbm(uv * vec2(22.0, 13.0) + vec2(time_phase * 0.008, 0.0)));
        c = mix(c, vec3(0.82, 0.92, 1.0), cloud * 0.52);
        metal = 0.03;
        rough = mix(0.16, 0.95, coast);
    } else if (planet_kind == 1 || planet_kind == 4) {
        float latitude_band = uv.y * (planet_kind == 4 ? 66.0 : 88.0);
        float w = fbm(vec2(uv.x * 8.0, uv.y * 4.0));
        float swirls = sin(latitude_band + 3.5 * n + 0.85 * sin(uv.x * 23.0 + uv.y * 34.0));
        float stripe = 0.5 + 0.5 * swirls;
        if (planet_kind == 1) {
            c = mix(vec3(0.19, 0.075, 0.045), vec3(0.79, 0.52, 0.26), stripe);
            c = mix(c, vec3(0.94, 0.78, 0.52), smoothstep(0.60, 0.91, stripe));
        } else {
            c = mix(vec3(0.26, 0.19, 0.14), vec3(0.66, 0.57, 0.40), stripe);
            c = mix(c, vec3(0.88, 0.75, 0.53), smoothstep(0.65, 0.96, stripe));
        }
        c *= mix(0.79, 1.12, w);
    } else if (planet_kind == 2) {
        float dirt = fbm(uv * vec2(17.0, 9.0));
        float craters = smoothstep(0.45, 0.58, fbm(uv * vec2(76.0, 38.0)));
        c = mix(vec3(0.16, 0.061, 0.033), vec3(0.68, 0.24, 0.12), n);
        c *= mix(0.68, 1.18, dirt);
        c = mix(c, vec3(0.83, 0.57, 0.34), craters * 0.21);
        c = mix(c, vec3(0.8, 0.76, 0.70), smoothstep(0.90, 0.985, latitude) * 0.7);
    } else {
        float turbulent = fbm(uv * vec2(10.0, 5.0) + vec2(sin(uv.y * 46.0) * 0.19, 0.0));
        float b = 0.5 + 0.5 * sin(uv.y * 65.0 + turbulent * 4.0);
        c = mix(vec3(0.008, 0.055, 0.24), vec3(0.04, 0.45, 0.75), b);
        c = mix(c, vec3(0.62, 0.87, 0.94), smoothstep(0.73, 0.91, b) * 0.4);
    }
    ALBEDO = max(c, vec3(0.0));
    ROUGHNESS = rough;
    METALLIC = metal;
}
