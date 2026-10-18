shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform float vento = 1.0;
varying vec4 cor;
varying float variacao;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	cor = COLOR;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float fase = h21(floor(MODEL_MATRIX[3].xz));
	variacao = fase;
	float k = clamp(VERTEX.y / 8.0, 0.0, 1.0);
	VERTEX.x += sin(TIME * 1.3 + wp.x * 0.05 + fase * 6.28) * 0.14 * k * vento;
	VERTEX.z += cos(TIME * 1.1 + wp.z * 0.05 + fase * 6.28) * 0.10 * k * vento;
}

void fragment() {
	ALBEDO = cor.rgb * (0.8 + 0.4 * variacao);
	ROUGHNESS = 0.92;
}
