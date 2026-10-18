shader_type spatial;
render_mode cull_disabled, diffuse_burley;
varying vec2 uv_r;
varying float tipo;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ruido(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { uv_r = UV; tipo = COLOR.r * 3.0; }
void fragment() {
	float a = abs(uv_r.x);
	float ruidoso = ruido(uv_r * vec2(6.0, 0.7)) * 0.5 + ruido(uv_r * vec2(40.0, 4.0)) * 0.5;
	vec3 asfalto = mix(vec3(0.10, 0.10, 0.11), vec3(0.18, 0.18, 0.18), ruidoso);
	vec3 terra = mix(vec3(0.33, 0.25, 0.15), vec3(0.45, 0.36, 0.22), ruidoso);
	vec3 borda = mix(vec3(0.30, 0.26, 0.18), vec3(0.22, 0.28, 0.12), ruidoso);
	vec3 cor;
	if (a > 1.0) {
		cor = borda;
	} else if (tipo > 1.5 && tipo < 2.5) {
		cor = terra * (1.0 - 0.35 * smoothstep(0.15, 0.3, abs(abs(uv_r.x) - 0.45))); // sulcos de pneu
	} else {
		cor = asfalto;
		float larg_linha = (tipo < 0.5) ? 0.035 : 0.028;
		float tracejada = step(fract(uv_r.y / 14.0), 0.55);
		if (tipo < 2.5) {
			cor = mix(cor, vec3(0.9, 0.78, 0.25), step(a, larg_linha) * tracejada);
			cor = mix(cor, vec3(0.85), step(abs(a - 0.9), 0.02));
		}
		if (tipo > 2.5) { // pista de pouso
			float cab = step(fract(uv_r.y / 24.0), 0.5);
			cor = mix(cor, vec3(0.9), step(a, 0.02) * cab);
			cor = mix(cor, vec3(0.9), step(abs(a - 0.92), 0.015));
		}
	}
	ALBEDO = cor;
	ROUGHNESS = (a > 1.0 || (tipo > 1.5 && tipo < 2.5)) ? 0.95 : 0.7;
}
