shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform float noite = 0.0;
varying vec2 uv_m;
varying vec4 cor;
varying vec2 sem;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() { uv_m = UV; cor = COLOR; sem = UV2; }

void fragment() {
	int tipo = int(sem.y + 0.5);
	float semente = sem.x;
	float fachada = cor.a;
	float vao = 3.0; float andar = 3.3;
	vec2 jmin = vec2(0.20, 0.30); vec2 jmax = vec2(0.80, 0.78);
	if (tipo == 1) { vao = 2.2; andar = 3.6; jmin = vec2(0.03, 0.10); jmax = vec2(0.97, 0.88); }   // cortina de vidro
	if (tipo == 3) { vao = 3.6; andar = 3.0; jmin = vec2(0.28, 0.25); jmax = vec2(0.62, 0.78); }   // casa
	if (tipo == 2) { vao = 5.0; andar = 9.0; jmin = vec2(0.10, 0.80); jmax = vec2(0.90, 0.92); }   // galpão: faixa alta
	vec2 cel = vec2(uv_m.x / vao, uv_m.y / andar);
	vec2 id = floor(cel); vec2 f = fract(cel);
	float jx = smoothstep(jmin.x, jmin.x + 0.03, f.x) * (1.0 - smoothstep(jmax.x - 0.03, jmax.x, f.x));
	float jy = smoothstep(jmin.y, jmin.y + 0.03, f.y) * (1.0 - smoothstep(jmax.y - 0.03, jmax.y, f.y));
	float jan = jx * jy * fachada * step(0.0, uv_m.y);
	float r = h21(id + vec2(semente * 17.0, semente * 5.0));
	float acesa = step(0.58, r) * noite;
	// reflexo do céu no vidro
	vec3 vidro = mix(vec3(0.07, 0.11, 0.15), vec3(0.38, 0.52, 0.62), r * 0.6 + 0.2 * f.y);
	if (tipo == 1) vidro = mix(cor.rgb * 0.5, vec3(0.45, 0.62, 0.74), 0.45 + 0.3 * r);
	// sujeira e manchas na fachada
	float mancha = 0.88 + 0.12 * h21(floor(uv_m * vec2(0.7, 0.5)) + semente);
	float faixa = smoothstep(0.0, 0.06, f.y) * 0.1 + 0.9;
	vec3 parede = cor.rgb * mancha * mix(1.0, faixa, fachada);
	if (tipo == 2) parede *= 0.92 + 0.08 * sin(uv_m.x * 9.0); // chapa trapezoidal
	ALBEDO = mix(parede, vidro, jan);
	ROUGHNESS = mix(0.85, 0.12, jan);
	METALLIC = jan * 0.25;
	EMISSION = vec3(1.0, 0.80, 0.48) * jan * acesa * 1.5;
}
