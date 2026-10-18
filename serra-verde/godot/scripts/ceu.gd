class_name Ceu
extends Node3D
## Ciclo dia/noite: sol/lua, céu procedural, névoa e luz ambiente.

signal noite_mudou(fator: float)
var hora := 9.5
var duracao_dia := 1200.0     # segundos reais por dia de jogo
var noite := 0.0
var sol: DirectionalLight3D
var env: Environment
var _mat: ProceduralSkyMaterial
var _ult_noite := -1.0

func construir() -> void:
	sol = DirectionalLight3D.new(); sol.shadow_enabled = true
	sol.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sol.directional_shadow_max_distance = 220.0
	sol.shadow_bias = 0.06
	add_child(sol)
	_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new(); sky.sky_material = _mat
	env = Environment.new(); env.background_mode = Environment.BG_SKY; env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.fog_enabled = true; env.fog_density = 0.00012; env.fog_sky_affect = 0.35
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	_atualizar()

func _process(dt: float) -> void:
	hora = fposmod(hora + dt / duracao_dia * 24.0, 24.0)
	_atualizar()

func hora_texto() -> String:
	return "%02d:%02d" % [int(hora), int((hora - int(hora)) * 60.0)]

func _atualizar() -> void:
	var ang := fposmod((hora - 6.0) / 24.0 * TAU, TAU)
	var elev := sin(ang)
	var dia := smoothstep(-0.06, 0.28, elev)
	var crep := 1.0 - smoothstep(0.0, 0.38, absf(elev))
	crep *= 1.0 - 0.3 * (1.0 - dia)
	var pitch := -ang if elev >= 0.0 else -(ang - PI)
	sol.rotation = Vector3(pitch, deg_to_rad(-38.0), 0.0)
	var cor_sol := Color(1.0, 0.96, 0.86).lerp(Color(1.0, 0.58, 0.30), crep)
	sol.light_color = cor_sol.lerp(Color(0.45, 0.55, 0.85), 1.0 - dia)
	sol.light_energy = lerpf(0.14, 1.25, dia)
	var topo := Color(0.02, 0.03, 0.07).lerp(Color(0.22, 0.42, 0.78), dia)
	var hor := Color(0.04, 0.05, 0.10).lerp(Color(0.64, 0.76, 0.88), dia).lerp(Color(0.96, 0.52, 0.28), crep * 0.8)
	_mat.sky_top_color = topo; _mat.sky_horizon_color = hor
	_mat.ground_horizon_color = hor.lerp(Color(0.2, 0.22, 0.2), 0.4)
	_mat.ground_bottom_color = Color(0.05, 0.06, 0.05)
	_mat.sun_angle_max = 30.0; _mat.sun_curve = 0.1
	env.ambient_light_energy = lerpf(0.35, 0.95, dia)
	env.fog_light_color = hor
	noite = 1.0 - smoothstep(-0.10, 0.10, elev)
	if absf(noite - _ult_noite) > 0.02:
		_ult_noite = noite
		noite_mudou.emit(noite)
