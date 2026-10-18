shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2D splat : filter_linear, repeat_disable;
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform sampler2D ruido_normal : filter_linear_mipmap, repeat_enable;
uniform vec2 tamanho_mundo = vec2(14880.0, 8600.0);
uniform float linha_neve = 1020.0;
uniform vec3 cor_grama : source_color = vec3(0.26, 0.36, 0.13);
uniform vec3 cor_mato : source_color = vec3(0.14, 0.24, 0.09);
uniform vec3 cor_rocha : source_color = vec3(0.40, 0.38, 0.35);
uniform vec3 cor_areia : source_color = vec3(0.72, 0.64, 0.46);
uniform vec3 cor_terra : source_color = vec3(0.36, 0.28, 0.17);
uniform vec3 cor_neve : source_color = vec3(0.93, 0.95, 0.98);

varying vec3 pos_mundo;
varying vec3 nrm_mundo;

void vertex() {
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	nrm_mundo = NORMAL;
}

void fragment() {
	vec2 uv = pos_mundo.xz / tamanho_mundo;
	vec4 w = texture(splat, uv);
	float n1 = texture(ruido, pos_mundo.xz * 0.0011).r;
	float n2 = texture(ruido, pos_mundo.xz * 0.0063).r;
	float n3 = texture(ruido, pos_mundo.xz * 0.045).r;
	float n4 = texture(ruido, pos_mundo.xz * 0.31).r;

	vec3 grama = mix(cor_grama, cor_mato, smoothstep(0.35, 0.65, n1 * 0.6 + n2 * 0.4));
	grama *= 0.85 + 0.3 * n3;
	vec3 rocha = cor_rocha * (0.7 + 0.5 * n3) * (0.85 + 0.3 * sin(pos_mundo.y * 0.35 + n2 * 6.0));
	vec3 areia = cor_areia * (0.9 + 0.2 * n4);
	vec3 terra = cor_terra * (0.8 + 0.4 * n3);

	vec3 cor = grama * w.r + rocha * w.g + areia * w.b + terra * w.a;
	cor *= 0.92 + 0.16 * n4;

	float inclinacao = 1.0 - clamp(normalize(nrm_mundo).y, 0.0, 1.0);
	float neve = smoothstep(linha_neve, linha_neve + 160.0, pos_mundo.y + n2 * 120.0) * (1.0 - smoothstep(0.35, 0.65, inclinacao));
	cor = mix(cor, cor_neve, neve);

	// detalhe de relevo sem tangentes: perturba a normal no espaço do mundo
	vec3 nm = texture(ruido_normal, pos_mundo.xz * 0.12).rgb * 2.0 - 1.0;
	vec3 nm2 = texture(ruido_normal, pos_mundo.xz * 0.013).rgb * 2.0 - 1.0;
	float forca = mix(0.7, 0.25, neve);
	vec3 nd = normalize(normalize(nrm_mundo) + vec3(nm.x + nm2.x * 0.6, 0.0, nm.y + nm2.y * 0.6) * forca);
	NORMAL = normalize((VIEW_MATRIX * vec4(nd, 0.0)).xyz);

	ALBEDO = cor;
	ROUGHNESS = mix(0.95, 0.55, w.b * 0.4 + neve * 0.6);
	SPECULAR = 0.2;
}
