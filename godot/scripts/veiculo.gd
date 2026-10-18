class_name Veiculo
extends CharacterBody3D
## Carro arcade (CharacterBody3D): previsível, usa a colisão do terreno e dos prédios.

const VEL_MAX := 38.0
const VEL_RE := 8.0
var acel := 0.0
var dir := 0.0
var freio := false
var motorista: Node = null
var vel := 0.0
var yaw := 0.0
var _up := Vector3.UP
var _giro := 0.0
var _esterco := 0.0
var _rodas_frente: Array[Node3D] = []
var _giros: Array[Node3D] = []
var _farois: Array[SpotLight3D] = []
var _farois_mesh: Array[MeshInstance3D] = []
var _noite := 0.0

func iniciar(pos: Vector3, yaw0: float, cor: Color) -> void:
	add_to_group("veiculos")
	collision_layer = 4; collision_mask = 1 | 4
	floor_max_angle = deg_to_rad(52.0); floor_snap_length = 1.2
	yaw = yaw0; global_position = pos
	global_transform.basis = Basis(Vector3.UP, yaw)
	var cs := CollisionShape3D.new(); var bx := BoxShape3D.new(); bx.size = Vector3(1.9, 1.25, 4.3)
	cs.shape = bx; cs.position = Vector3(0, 0.9, 0); add_child(cs)
	var tinta := StandardMaterial3D.new(); tinta.albedo_color = cor; tinta.metallic = 0.55; tinta.roughness = 0.32
	var vidro := StandardMaterial3D.new(); vidro.albedo_color = Color(0.05, 0.07, 0.09); vidro.metallic = 0.7; vidro.roughness = 0.05
	var preto := StandardMaterial3D.new(); preto.albedo_color = Color(0.04, 0.04, 0.045); preto.roughness = 0.9
	_caixa(Vector3(1.9, 0.62, 4.3), Vector3(0, 0.66, 0), tinta)
	_caixa(Vector3(1.68, 0.58, 2.1), Vector3(0, 1.26, 0.35), vidro)
	_caixa(Vector3(1.6, 0.06, 1.9), Vector3(0, 1.57, 0.35), tinta)
	_caixa(Vector3(1.95, 0.22, 0.14), Vector3(0, 0.42, -2.18), preto)
	_caixa(Vector3(1.95, 0.22, 0.14), Vector3(0, 0.42, 2.18), preto)
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(1, 1, 0.9); fm.emission_enabled = true; fm.emission = Color(1, 0.95, 0.8); fm.emission_energy_multiplier = 0.2
	var lm := StandardMaterial3D.new(); lm.albedo_color = Color(0.6, 0.02, 0.02); lm.emission_enabled = true; lm.emission = Color(1, 0.05, 0.03); lm.emission_energy_multiplier = 0.4
	for lado in [-0.7, 0.7]:
		_farois_mesh.append(_caixa(Vector3(0.38, 0.16, 0.06), Vector3(lado, 0.74, -2.16), fm))
		_caixa(Vector3(0.38, 0.14, 0.06), Vector3(lado, 0.76, 2.16), lm)
		var sp := SpotLight3D.new(); sp.position = Vector3(lado, 0.8, -2.3); sp.rotation_degrees = Vector3(-4, 0, 0)
		sp.spot_range = 55.0; sp.spot_angle = 38.0; sp.light_energy = 0.0; sp.visible = false
		add_child(sp); _farois.append(sp)
	for q in [[-0.95, -1.4, true], [0.95, -1.4, true], [-0.95, 1.4, false], [0.95, 1.4, false]]:
		var piv := Node3D.new(); piv.position = Vector3(q[0], 0.38, q[1]); add_child(piv)
		var giro := Node3D.new(); piv.add_child(giro)
		var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.38; cm.bottom_radius = 0.38; cm.height = 0.3
		mi.mesh = cm; mi.rotation = Vector3(0, 0, PI * 0.5); mi.material_override = preto; giro.add_child(mi)
		var aro := MeshInstance3D.new(); var cm2 := CylinderMesh.new(); cm2.top_radius = 0.22; cm2.bottom_radius = 0.22; cm2.height = 0.32
		aro.mesh = cm2; aro.rotation = Vector3(0, 0, PI * 0.5)
		var am := StandardMaterial3D.new(); am.albedo_color = Color(0.7, 0.7, 0.72); am.metallic = 0.8; am.roughness = 0.3
		aro.material_override = am; giro.add_child(aro)
		_giros.append(giro)
		if q[2]: _rodas_frente.append(piv)

func _caixa(tam: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = tam; mi.mesh = bm; mi.position = pos
	mi.material_override = m; add_child(mi); return mi

func definir_noite(f: float) -> void:
	_noite = f

func _physics_process(dt: float) -> void:
	var th := acel if motorista != null else 0.0
	var st := dir if motorista != null else 0.0
	var pos := global_position
	var estrada := Mundo.dist_estrada(pos.x, pos.z) < 11.0 or Mundo.zona_em(pos.x, pos.z, 1) > 0.25
	var vmax := VEL_MAX * (1.0 if estrada else 0.55)
	if th > 0.05:
		if vel >= -0.5: vel = move_toward(vel, vmax * th, 11.0 * dt) if vel < vmax * th else move_toward(vel, vmax * th, 14.0 * dt)
		else: vel = move_toward(vel, 0.0, 30.0 * dt)
	elif th < -0.05:
		if vel > 0.6: vel = move_toward(vel, 0.0, 28.0 * dt)
		else: vel = move_toward(vel, VEL_RE * th, 9.0 * dt)
	else:
		vel = move_toward(vel, 0.0, 4.5 * dt)
	if freio: vel = move_toward(vel, 0.0, 36.0 * dt)
	var fator := clampf(absf(vel) / 5.0, 0.0, 1.0) * (1.0 - clampf(absf(vel) / 60.0, 0.0, 0.5))
	_esterco = lerpf(_esterco, st, clampf(7.0 * dt, 0.0, 1.0))
	yaw -= _esterco * 1.45 * fator * signf(vel) * dt
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	velocity.x = fwd.x * vel; velocity.z = fwd.z * vel
	if is_on_floor(): velocity.y = -2.0
	else: velocity.y -= 24.0 * dt
	move_and_slide()
	# colisões frontais reduzem a velocidade real
	vel = Vector3(velocity.x, 0, velocity.z).dot(fwd)
	var alvo_up := get_floor_normal() if is_on_floor() else Vector3.UP
	_up = _up.slerp(alvo_up, clampf(7.0 * dt, 0.0, 1.0)).normalized()
	var dir_f := (fwd - _up * fwd.dot(_up)).normalized()
	var direita := dir_f.cross(_up).normalized()
	global_transform.basis = Basis(direita, _up, -_up.cross(direita).normalized())
	_giro += vel * dt / 0.38
	for g in _giros: g.rotation.x = _giro
	for r in _rodas_frente: r.rotation.y = -_esterco * 0.42
	var luz := motorista != null and _noite > 0.5
	for f in _farois:
		f.visible = luz; f.light_energy = 3.5 if luz else 0.0
	for fm in _farois_mesh:
		(fm.material_override as StandardMaterial3D).emission_energy_multiplier = 3.0 if luz else 0.2
