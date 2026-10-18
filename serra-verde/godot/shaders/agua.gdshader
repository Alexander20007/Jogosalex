shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;
uniform sampler2D ondas : filter_linear_mipmap, repeat_enable;
uniform vec3 cor_rasa : source_color = vec3(0.1, 0.4, 0.5);
uniform vec3 cor_funda : source_color = vec3(0.01, 0.12, 0.2);
uniform float escala = 0.02;
uniform float velocidade = 0.01;
varying vec3 pos_mundo;

void vertex() { pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 uv = pos_mundo.xz * escala;
	vec3 n1 = texture(ondas, uv + vec2(TIME * velocidade, TIME * velocidade * 0.6)).rgb * 2.0 - 1.0;
	vec3 n2 = texture(ondas, uv * 2.3 - vec2(TIME * velocidade * 0.7, -TIME * velocidade)).rgb * 2.0 - 1.0;
	vec3 nd = normalize(vec3(0.0, 1.0, 0.0) + vec3(n1.x + n2.x, 0.0, n1.y + n2.y) * 0.35);
	NORMAL = normalize((VIEW_MATRIX * vec4(nd, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 cor = mix(cor_rasa, cor_funda, clamp(fres * 0.6 + 0.35, 0.0, 1.0));
	ALBEDO = cor;
	ALPHA = clamp(0.80 + fres * 0.18, 0.0, 1.0);
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.9;
}
