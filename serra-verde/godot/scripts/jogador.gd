class_name Jogador
extends CharacterBody3D
## Personagem: 3ª/1ª pessoa, corrida, pulo, nado, entrar/sair de veículos.

const VEL_ANDAR := 4.4
const VEL_CORRER := 8.2
const GRAV := 24.0
const PULO := 7.6

var yaw := 0.0
var pitch := -0.22
var mov := Vector2.ZERO          # x: direita, y: trás (frente = negativo)
var olhar := Vector2.ZERO
var correndo := false
var primeira := false
var pular_pedido := false
var veiculo: Veiculo = null
var nadando := false
var _pivo: Node3D
var _braco: SpringArm3D
var _cam: Camera3D
var _visual: Node3D
var _col: CollisionShape3D
var _pernas: Array[Node3D] = []
var _bracos: Array[Node3D] = []
var _fase := 0.0
var _dist := 4.6

func _ready() -> void:
	collision_layer = 2; collision_mask = 1 | 4
	floor_snap_length = 0.6
	_col = CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.34; cap.height = 1.76
	_col.shape = cap; _col.position.y = 0.88; add_child(_col)
	_visual = _criar_visual(); add_child(_visual)
	_pivo = Node3D.new(); _pivo.top_level = true; add_child(_pivo)
	_braco = SpringArm3D.new(); _braco.spring_length = _dist; _braco.margin = 0.25
	var esf := SphereShape3D.new(); esf.radius = 0.25; _braco.shape = esf; _braco.collision_mask = 1
	_pivo.add_child(_braco)
	_cam = Camera3D.new(); _cam.far = 12000.0; _cam.near = 0.12; _cam.fov = 72.0; _braco.add_child(_cam); _cam.current = true
	_pivo.global_position = global_position + Vector3(0, 1.6, 0)

func _criar_visual() -> Node3D:
	if ResourceLoader.exists("res://assets/models/personagem.glb"):
		var cena: PackedScene = load("res://assets/models/personagem.glb")
		return cena.instantiate()
	var raiz := Node3D.new()
	var pele := _mat(Color(0.80, 0.60, 0.45)); var camisa := _mat(Color(0.18, 0.32, 0.45)); var calca := _mat(Color(0.14, 0.14, 0.17))
	_caixa(raiz, Vector3(0.46, 0.62, 0.26), Vector3(0, 1.17, 0), camisa)
	_caixa(raiz, Vector3(0.20, 0.20, 0.20), Vector3(0, 1.62, 0), pele)
	_caixa(raiz, Vector3(0.22, 0.07, 0.22), Vector3(0, 1.74, 0), _mat(Color(0.12, 0.08, 0.05)))
	for lado in [-1.0, 1.0]:
		var perna := Node3D.new(); perna.position = Vector3(0.12 * lado, 0.86, 0); raiz.add_child(perna)
		_caixa(perna, Vector3(0.19, 0.84, 0.21), Vector3(0, -0.42, 0), calca)
		_pernas.append(perna)
		var braco := Node3D.new(); braco.position = Vector3(0.30 * lado, 1.44, 0); raiz.add_child(braco)
		_caixa(braco, Vector3(0.14, 0.58, 0.16), Vector3(0, -0.28, 0), camisa)
		_bracos.append(braco)
	return raiz

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 0.85; return m

func _caixa(pai: Node3D, tam: Vector3, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = tam; mi.mesh = bm; mi.position = pos
	mi.material_override = m; pai.add_child(mi)

func alternar_camera() -> void:
	primeira = not primeira

func _physics_process(dt: float) -> void:
	yaw -= olhar.x * 0.0034; pitch = clampf(pitch - olhar.y * 0.0030, -1.25, 0.75); olhar = Vector2.ZERO
	var kb := Input.get_vector("esquerda", "direita", "frente", "tras")
	var m := kb if kb.length() > 0.1 else mov
	if veiculo != null:
		veiculo.acel = -m.y; veiculo.dir = m.x; veiculo.freio = Input.is_action_pressed("freio") or pular_pedido
		pular_pedido = false
		global_position = veiculo.global_position
		_atualizar_camera(dt, veiculo.global_position + Vector3(0, 1.4, 0), 7.5, veiculo)
		return
	var dir_cam := Basis(Vector3.UP, yaw)
	var alvo := dir_cam * Vector3(m.x, 0.0, m.y)
	var vel := VEL_CORRER if (correndo or Input.is_action_pressed("correr")) else VEL_ANDAR
	if nadando: vel *= 0.55
	var h := Vector3(velocity.x, 0, velocity.z).lerp(alvo * vel, clampf(10.0 * dt, 0.0, 1.0))
	velocity.x = h.x; velocity.z = h.z
	var agua := Mundo.agua_em(global_position.x, global_position.z)
	nadando = agua > Mundo.SEM_AGUA * 0.5 and global_position.y < agua - 0.9
	if nadando:
		velocity.y = lerpf(velocity.y, (agua - 1.25 - global_position.y) * 2.5, clampf(6.0 * dt, 0.0, 1.0))
		if pular_pedido: velocity.y = 3.2
	elif is_on_floor():
		velocity.y = -1.0
		if pular_pedido or Input.is_action_just_pressed("pular"): velocity.y = PULO
	else:
		velocity.y -= GRAV * dt
	pular_pedido = false
	move_and_slide()
	global_position.y = maxf(global_position.y, Mundo.altura_em(global_position.x, global_position.z) - 3.0)
	_animar(h, dt)
	_atualizar_camera(dt, global_position + Vector3(0, 1.62, 0), 0.0 if primeira else _dist, null)

func _animar(h: Vector3, dt: float) -> void:
	_visual.visible = not primeira
	var v := h.length()
	if v > 0.4:
		var a := atan2(-h.x, -h.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, a, clampf(12.0 * dt, 0.0, 1.0))
	_fase += dt * v * 1.9
	var sw := sin(_fase) * clampf(v / 6.0, 0.0, 1.0) * 0.9
	if _pernas.size() == 2:
		_pernas[0].rotation.x = sw; _pernas[1].rotation.x = -sw
		_bracos[0].rotation.x = -sw * 0.8; _bracos[1].rotation.x = sw * 0.8

func _atualizar_camera(dt: float, alvo: Vector3, dist: float, seguir: CollisionObject3D) -> void:
	_pivo.global_position = _pivo.global_position.lerp(alvo, clampf(22.0 * dt, 0.0, 1.0))
	_pivo.rotation = Vector3(pitch, yaw, 0.0)
	_braco.spring_length = lerpf(_braco.spring_length, dist, clampf(8.0 * dt, 0.0, 1.0))
	_braco.add_excluded_object(get_rid())
	if seguir != null:
		_braco.add_excluded_object(seguir.get_rid())

func posicao_camera() -> Vector3:
	return _cam.global_position

func entrar_ou_sair() -> void:
	if veiculo != null:
		var v := veiculo
		veiculo.acel = 0.0; veiculo.dir = 0.0; veiculo.motorista = null; veiculo.freio = true
		veiculo = null
		global_position = v.global_position + v.global_transform.basis.x * -2.4 + Vector3(0, 0.6, 0)
		velocity = Vector3.ZERO
		_visual.visible = true; _col.disabled = false
		collision_layer = 2; collision_mask = 1 | 4
		return
	var melhor: Veiculo = null; var dmin := 5.0
	for n in get_tree().get_nodes_in_group("veiculos"):
		var d := global_position.distance_to(n.global_position)
		if d < dmin: dmin = d; melhor = n
	if melhor != null:
		veiculo = melhor; melhor.motorista = self
		_visual.visible = false; _col.disabled = true
		collision_layer = 0; collision_mask = 0
		yaw = melhor.yaw; pitch = -0.2

func veiculo_proximo() -> bool:
	if veiculo != null: return true
	for n in get_tree().get_nodes_in_group("veiculos"):
		if global_position.distance_to(n.global_position) < 5.0: return true
	return false

func velocidade_kmh() -> float:
	if veiculo != null: return absf(veiculo.vel) * 3.6
	return Vector3(velocity.x, 0, velocity.z).length() * 3.6
