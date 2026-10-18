class_name Hud
extends Control
## HUD de toque multitoque: joystick flutuante à esquerda, olhar à direita, botões, mapa e status.

var jogador: Jogador
var ceu: Ceu
var _dedos := {}                 # índice -> papel ("stick", "olhar", "btn:xxx")
var _stick_id := -1
var _stick_centro := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _mapa := false
var _tex_mapa: Texture2D
var _local := ""
var _t_local := 0.0
var _freio_seg := false
const R_STICK := 95.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/ui/mapa_referencia.jpg"):
		_tex_mapa = load("res://assets/ui/mapa_referencia.jpg")

func _botoes() -> Dictionary:
	var s := size
	var em_carro := jogador.veiculo != null
	var d := {}
	d["pular"] = {"p": Vector2(s.x - 120, s.y - 120), "r": 62.0, "t": "FREIO" if em_carro else "PULAR"}
	if not em_carro:
		d["correr"] = {"p": Vector2(s.x - 255, s.y - 78), "r": 42.0, "t": "CORRER", "on": jogador.correndo}
	d["camera"] = {"p": Vector2(s.x - 60, s.y * 0.42), "r": 36.0, "t": "CÂM."}
	d["mapa"] = {"p": Vector2(s.x - 60, 66), "r": 36.0, "t": "MAPA"}
	if jogador.veiculo_proximo():
		d["interagir"] = {"p": Vector2(s.x - 255, s.y - 185), "r": 50.0, "t": "SAIR" if em_carro else "ENTRAR"}
	return d

func _input(ev: InputEvent) -> void:
	if jogador == null: return
	var tq := ev as InputEventScreenTouch
	if tq != null:
		if tq.pressed: _toque(tq.index, tq.position)
		else: _solto(tq.index)
		return
	var dr := ev as InputEventScreenDrag
	if dr != null:
		_arrasto(dr.index, dr.position, dr.relative)

func _toque(i: int, p: Vector2) -> void:
	if _mapa:
		_mapa = false; return
	var b := _botoes()
	for k in b:
		if p.distance_to(b[k]["p"]) <= b[k]["r"] * 1.2:
			_dedos[i] = "btn:" + k
			_acao(k, true)
			return
	if p.x < size.x * 0.45 and _stick_id == -1:
		_stick_id = i; _stick_centro = p; _stick_pos = p; _dedos[i] = "stick"
	else:
		_dedos[i] = "olhar"

func _solto(i: int) -> void:
	var papel: String = _dedos.get(i, "")
	if papel == "stick":
		_stick_id = -1; jogador.mov = Vector2.ZERO
	elif papel.begins_with("btn:"):
		_acao(papel.substr(4), false)
	_dedos.erase(i)

func _arrasto(i: int, p: Vector2, rel: Vector2) -> void:
	var papel: String = _dedos.get(i, "")
	if papel == "stick":
		_stick_pos = p
		var v := (p - _stick_centro) / R_STICK
		if v.length() > 1.0: v = v.normalized()
		jogador.mov = v if v.length() > 0.12 else Vector2.ZERO
	elif papel == "olhar":
		jogador.olhar += rel

func _acao(k: String, pressionou: bool) -> void:
	match k:
		"pular":
			_freio_seg = pressionou
			if pressionou: jogador.pular_pedido = true
		"correr": if pressionou: jogador.correndo = not jogador.correndo
		"camera": if pressionou: jogador.alternar_camera()
		"mapa": if pressionou: _mapa = true
		"interagir": if pressionou: jogador.entrar_ou_sair()

func _process(dt: float) -> void:
	if jogador == null: return
	if _freio_seg and jogador.veiculo != null: jogador.pular_pedido = true
	if Input.is_action_just_pressed("camera"): jogador.alternar_camera()
	if Input.is_action_just_pressed("interagir"): jogador.entrar_ou_sair()
	if Input.is_action_just_pressed("mapa"): _mapa = not _mapa
	_t_local -= dt
	if _t_local <= 0.0:
		_t_local = 0.6; _local = _poi_perto()
	queue_redraw()

func _poi_perto() -> String:
	var p := jogador.global_position; var melhor := ""; var dmin := 420.0
	for poi in Mundo.dados["pois"]:
		var d := Vector2(p.x, p.z).distance_to(Vector2(poi["x"], poi["z"]))
		if d < dmin: dmin = d; melhor = poi["nome"]
	return melhor

func _draw() -> void:
	if jogador == null: return
	var f := ThemeDB.fallback_font
	if _mapa:
		_desenhar_mapa(f); return
	# status
	var txt := "%s   %d km/h   %d FPS" % [ceu.hora_texto() if ceu else "", int(jogador.velocidade_kmh()), Engine.get_frames_per_second()]
	draw_string(f, Vector2(22, 36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.9))
	if _local != "":
		draw_string(f, Vector2(0, 74), _local, HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Color(1, 0.95, 0.75, 0.95))
	# joystick
	if _stick_id != -1:
		draw_circle(_stick_centro, R_STICK, Color(1, 1, 1, 0.12))
		draw_arc(_stick_centro, R_STICK, 0, TAU, 48, Color(1, 1, 1, 0.4), 3.0)
		var k := _stick_centro + (_stick_pos - _stick_centro).limit_length(R_STICK)
		draw_circle(k, 38.0, Color(1, 1, 1, 0.45))
	else:
		var c := Vector2(170, size.y - 150)
		draw_arc(c, R_STICK, 0, TAU, 48, Color(1, 1, 1, 0.18), 2.0)
		draw_circle(c, 30.0, Color(1, 1, 1, 0.12))
	# botões
	var b := _botoes()
	for k in b:
		var e: Dictionary = b[k]
		var ativo: bool = e.get("on", false)
		draw_circle(e["p"], e["r"], Color(0.1, 0.12, 0.12, 0.45) if not ativo else Color(0.9, 0.7, 0.2, 0.55))
		draw_arc(e["p"], e["r"], 0, TAU, 40, Color(1, 1, 1, 0.55), 2.5)
		draw_string(f, Vector2(e["p"].x - e["r"], e["p"].y + 6), e["t"], HORIZONTAL_ALIGNMENT_CENTER, e["r"] * 2.0, 17, Color(1, 1, 1, 0.95))

func _desenhar_mapa(f: Font) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.88))
	if _tex_mapa == null:
		draw_string(f, Vector2(0, size.y * 0.5), "Mapa indisponível", HORIZONTAL_ALIGNMENT_CENTER, size.x, 28); return
	var ts := _tex_mapa.get_size()
	var esc := minf(size.x / ts.x, size.y / ts.y) * 0.96
	var sz := ts * esc; var off := (size - sz) * 0.5
	draw_texture_rect(_tex_mapa, Rect2(off, sz), false)
	var wp := jogador.global_position
	var ix := wp.x / Mundo.tamanho.x * 1920.0
	var iy := 120.0 + wp.z / Mundo.tamanho.y * 1110.0
	var mp := off + Vector2(ix / ts.x * sz.x, iy / ts.y * sz.y)
	draw_circle(mp, 11.0, Color(1, 0.2, 0.15))
	draw_arc(mp, 16.0, 0, TAU, 32, Color(1, 1, 1), 3.0)
	var ang := jogador.yaw if jogador.veiculo == null else jogador.veiculo.yaw
	var ponta := mp + Vector2(-sin(ang), -cos(ang)) * 30.0
	draw_line(mp, ponta, Color(1, 1, 1), 4.0)
	draw_string(f, Vector2(0, size.y - 14), "Toque para fechar", HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color(1, 1, 1, 0.8))
