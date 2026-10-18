extends Node3D
## Cena principal: monta o mundo inteiro por código.

var terreno: Terreno
var agua: Agua
var estradas: Estradas
var cidade: Cidade
var ceu: Ceu
var jogador: Jogador
var hud: Hud
var _carga: CanvasLayer

func _ready() -> void:
	Engine.max_fps = 60
	_tela_carga()
	await get_tree().process_frame
	await get_tree().process_frame
	Mundo.carregar()
	terreno = Terreno.new(); terreno.name = "Terreno"; add_child(terreno); terreno.iniciar()
	agua = Agua.new(); agua.name = "Agua"; add_child(agua); agua.construir()
	estradas = Estradas.new(); estradas.name = "Estradas"; add_child(estradas); estradas.construir()
	cidade = Cidade.new(); cidade.name = "Cidade"; add_child(cidade); cidade.construir()
	ceu = Ceu.new(); ceu.name = "Ceu"; add_child(ceu); ceu.construir()
	# ponto de partida: beira da rodovia perto da Vila Palmeira
	var vila := _poi("Vila Palmeira")
	var pts: Array = Mundo.dados["estradas"][0]["pontos"]
	var bi := 0; var bd := 1.0e12
	for i in pts.size():
		var d := Vector2(pts[i][0], pts[i][2]).distance_squared_to(Vector2(vila.x, vila.z))
		if d < bd: bd = d; bi = i
	var p := Vector3(pts[bi][0], 0, pts[bi][2])
	var n := Vector3(pts[mini(bi + 1, pts.size() - 1)][0], 0, pts[mini(bi + 1, pts.size() - 1)][2])
	var rd := (n - p).normalized()
	var lado := Vector3(-rd.z, 0, rd.x)
	var inicio := p + lado * 9.0
	inicio.y = Mundo.altura_em(inicio.x, inicio.z) + 0.6
	terreno.alvo = inicio; terreno.atualizar_colisao(inicio, true)
	jogador = Jogador.new(); jogador.name = "Jogador"; add_child(jogador)
	jogador.global_position = inicio
	jogador.yaw = atan2(-rd.x, -rd.z)
	_criar_veiculos(pts, bi, lado)
	var cl := CanvasLayer.new(); cl.layer = 5; add_child(cl)
	hud = Hud.new(); hud.jogador = jogador; hud.ceu = ceu; cl.add_child(hud)
	ceu.noite_mudou.connect(_on_noite)
	_on_noite(ceu.noite)
	_carga.queue_free()

var _t_veic := 0.0

func _process(dt: float) -> void:
	if jogador == null: return
	var p := jogador.global_position
	terreno.alvo = p; cidade.alvo = p
	_t_veic -= dt
	if _t_veic <= 0.0:
		_t_veic = 0.5
		# carros longe do jogador ficam parados no chão (sem colisão de terreno lá)
		for v in get_tree().get_nodes_in_group("veiculos"):
			var perto: bool = v.global_position.distance_to(p) < 420.0 or v.motorista != null
			v.set_physics_process(perto)
			if not perto: v.global_position.y = Mundo.altura_em(v.global_position.x, v.global_position.z) + 0.9

func _on_noite(f: float) -> void:
	cidade.definir_noite(f)
	for v in get_tree().get_nodes_in_group("veiculos"): v.definir_noite(f)

func _poi(nome: String) -> Vector3:
	for p in Mundo.dados["pois"]:
		if p["nome"] == nome: return Vector3(p["x"], p["y"], p["z"])
	return Vector3(Mundo.tamanho.x * 0.5, 0, Mundo.tamanho.y * 0.5)

func _criar_veiculos(pts_sr: Array, bi: int, lado: Vector3) -> void:
	var cores := [Color(0.75, 0.10, 0.10), Color(0.12, 0.22, 0.50), Color(0.88, 0.88, 0.9), Color(0.08, 0.08, 0.09), Color(0.55, 0.58, 0.60), Color(0.82, 0.68, 0.2), Color(0.15, 0.40, 0.25)]
	var ci := 0
	# um carro ao lado do jogador
	var p := Vector3(pts_sr[bi][0], 0, pts_sr[bi][2])
	var nx := Vector3(pts_sr[mini(bi + 1, pts_sr.size() - 1)][0], 0, pts_sr[mini(bi + 1, pts_sr.size() - 1)][2])
	var rd := (nx - p).normalized()
	_carro(p + lado * 8.0 + rd * 7.0, atan2(-rd.x, -rd.z), cores[ci % cores.size()]); ci += 1
	# carros espalhados pelas rodovias
	for nome in ["Rodovia SR-77", "Avenida da Costa", "Via Aeroporto"]:
		for e in Mundo.dados["estradas"]:
			if e["nome"] != nome: continue
			var pts: Array = e["pontos"]
			for t in [0.15, 0.35, 0.55, 0.75, 0.9]:
				var i := clampi(int(pts.size() * t), 0, pts.size() - 2)
				var a := Vector3(pts[i][0], 0, pts[i][2]); var b := Vector3(pts[i + 1][0], 0, pts[i + 1][2])
				var d := (b - a).normalized(); var s := Vector3(-d.z, 0, d.x)
				_carro(a + s * 4.2, atan2(-d.x, -d.z), cores[ci % cores.size()]); ci += 1

func _carro(pos: Vector3, yaw: float, cor: Color) -> void:
	pos.y = Mundo.altura_em(pos.x, pos.z) + 1.3
	var v := Veiculo.new(); v.name = "Carro%d" % get_tree().get_nodes_in_group("veiculos").size()
	add_child(v); v.iniciar(pos, yaw, cor)

func _tela_carga() -> void:
	_carga = CanvasLayer.new(); _carga.layer = 100; add_child(_carga)
	var fundo := ColorRect.new(); fundo.color = Color(0.05, 0.08, 0.07); fundo.set_anchors_preset(Control.PRESET_FULL_RECT); _carga.add_child(fundo)
	var l := Label.new(); l.text = "Estado de Serra Verde\nCarregando o mundo…"; l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.add_theme_font_size_override("font_size", 34); _carga.add_child(l)
