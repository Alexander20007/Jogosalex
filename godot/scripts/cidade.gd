class_name Cidade
extends Node3D
## Cidades procedurais (Vice Shores, Porto Bahia, Vila Palmeira, aeroporto), geradas em células
## de 320 m só perto do jogador, em threads.

const CEL := 320.0
const ALCANCE := 1150.0
const MAX_TAREFAS := 2

const CONCRETO := [Color(0.78, 0.74, 0.68), Color(0.86, 0.84, 0.80), Color(0.66, 0.64, 0.60), Color(0.82, 0.72, 0.58), Color(0.70, 0.74, 0.76), Color(0.88, 0.80, 0.70)]
const VIDRO := [Color(0.20, 0.34, 0.42), Color(0.16, 0.26, 0.34), Color(0.28, 0.40, 0.38), Color(0.34, 0.30, 0.24)]
const CASA := [Color(0.92, 0.86, 0.74), Color(0.86, 0.62, 0.46), Color(0.74, 0.82, 0.80), Color(0.93, 0.90, 0.85), Color(0.84, 0.74, 0.50), Color(0.80, 0.55, 0.50)]
const TELHA := [Color(0.62, 0.28, 0.18), Color(0.50, 0.24, 0.16), Color(0.30, 0.30, 0.32), Color(0.42, 0.38, 0.34)]
const METAL := [Color(0.55, 0.58, 0.60), Color(0.46, 0.50, 0.54), Color(0.68, 0.66, 0.60)]
const CONT := [Color(0.72, 0.18, 0.14), Color(0.15, 0.33, 0.60), Color(0.20, 0.50, 0.28), Color(0.85, 0.62, 0.15), Color(0.60, 0.62, 0.64)]
const CARROS := [Color(0.75, 0.10, 0.10), Color(0.10, 0.18, 0.45), Color(0.85, 0.85, 0.86), Color(0.08, 0.08, 0.09), Color(0.55, 0.57, 0.60), Color(0.80, 0.68, 0.20)]

var alvo := Vector3.ZERO
var mat_predio: ShaderMaterial
var mat_chao: StandardMaterial3D
var _celulas := {}      # Vector2i -> Array de dicionários (blocos/especiais)
var _vivos := {}        # Vector2i -> Node3D
var _pedidos := {}
var _resultados: Array = []
var _mutex := Mutex.new()
var _ativas := 0
var _t := 0.0

func construir() -> void:
	mat_predio = ShaderMaterial.new(); mat_predio.shader = load("res://shaders/predio.gdshader")
	mat_chao = StandardMaterial3D.new(); mat_chao.vertex_color_use_as_albedo = true; mat_chao.roughness = 0.92
	mat_chao.cull_mode = BaseMaterial3D.CULL_DISABLED
	var id := 0
	for z in Mundo.dados["zonas"]:
		var tipo: String = z["tipo"]
		if tipo == "aeroporto": _aeroporto(z, id); id += 1000; continue
		if not (tipo in ["cidade", "porto", "vila"]): continue
		var bw := 108.0; var bd := 84.0; var rua := 16.0; var yaw := deg_to_rad(-14.0)
		if tipo == "porto": bw = 120.0; bd = 90.0; rua = 18.0
		if tipo == "vila": bw = 74.0; bd = 60.0; rua = 11.0; yaw = deg_to_rad(8.0)
		var cx: float = z["x"]; var cz: float = z["z"]; var rx: float = z["rx"]; var rz: float = z["rz"]
		var bs := Basis(Vector3.UP, yaw)
		var nx := int(rx / bw) + 2; var nz := int(rz / bd) + 2
		for gj in range(-nz, nz + 1):
			for gi in range(-nx, nx + 1):
				var loc := bs * Vector3(gi * bw, 0, gj * bd)
				var wx := cx + loc.x; var wz := cz + loc.z
				var e := pow(loc.x / rx, 2.0) + pow(loc.z / rz, 2.0)
				if e > 0.82: continue
				if Mundo.altura_em(wx, wz) < 1.3: continue
				if Mundo.agua_em(wx, wz) > Mundo.SEM_AGUA * 0.5: continue
				if Mundo.dist_estrada(wx, wz) < 36.0: continue
				var perto_mar := false
				for dx in [-1, 1]:
					for dz in [-1, 1]:
						if Mundo.altura_em(wx + dx * bw * 0.5, wz + dz * bd * 0.5) < 1.3: perto_mar = true
				id += 1
				var b := {"id": id, "tipo": tipo, "c": Vector2(wx, wz), "yaw": yaw, "bw": bw, "bd": bd, "rua": rua,
					"r": sqrt(e), "costa": perto_mar, "centro": (gi == 0 and gj == 0)}
				_registrar(b)

func _registrar(b: Dictionary) -> void:
	var k := Vector2i(int(b["c"].x / CEL), int(b["c"].y / CEL))
	if not _celulas.has(k): _celulas[k] = []
	_celulas[k].append(b)

func _aeroporto(z: Dictionary, id: int) -> void:
	var cx: float = z["x"]; var cz: float = z["z"]
	var yaw := -0.136
	_registrar({"id": id + 1, "tipo": "terminal", "c": Vector2(cx, cz), "yaw": yaw})
	_registrar({"id": id + 2, "tipo": "torre", "c": Vector2(cx + 160, cz - 40), "yaw": yaw})
	for i in 3:
		_registrar({"id": id + 3 + i, "tipo": "hangar", "c": Vector2(cx - 220 - i * 70, cz + 20 + i * 8), "yaw": yaw})

func definir_noite(f: float) -> void:
	mat_predio.set_shader_parameter("noite", f)

func _process(dt: float) -> void:
	_t += dt
	if _t > 0.4:
		_t = 0.0
		_planejar()
	for _k in 1:
		_mutex.lock()
		var r = _resultados.pop_front() if _resultados.size() > 0 else null
		_mutex.unlock()
		if r == null: break
		_ativas -= 1
		_montar(r)

func _planejar() -> void:
	var ck := Vector2i(int(alvo.x / CEL), int(alvo.z / CEL))
	var rr := int(ALCANCE / CEL) + 1
	var cand := []
	for dz in range(-rr, rr + 1):
		for dx in range(-rr, rr + 1):
			var k := Vector2i(ck.x + dx, ck.y + dz)
			if not _celulas.has(k) or _vivos.has(k) or _pedidos.has(k): continue
			var cen := Vector2((k.x + 0.5) * CEL, (k.y + 0.5) * CEL)
			var d := cen.distance_to(Vector2(alvo.x, alvo.z))
			if d < ALCANCE: cand.append([d, k])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	for e in cand:
		if _ativas >= MAX_TAREFAS: break
		_pedidos[e[1]] = true; _ativas += 1
		WorkerThreadPool.add_task(_tarefa.bind(e[1]))
	for k in _vivos.keys():
		var cen := Vector2((k.x + 0.5) * CEL, (k.y + 0.5) * CEL)
		if cen.distance_to(Vector2(alvo.x, alvo.z)) > ALCANCE + CEL * 1.5:
			_vivos[k].queue_free(); _vivos.erase(k); _pedidos.erase(k)

func _montar(r: Array) -> void:
	var k: Vector2i = r[0]
	var raiz := Node3D.new(); raiz.name = "Celula_%d_%d" % [k.x, k.y]
	var mesh := ArrayMesh.new()
	var mp: MalhaPredios = r[1]; var mg: MalhaPredios = r[2]
	var sp := mp.para_malha(mat_predio); var sg := mg.para_malha(mat_chao)
	var final := ArrayMesh.new()
	for s in [sg, sp]:
		if s.get_surface_count() > 0:
			var arr := s.surface_get_arrays(0)
			final.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			final.surface_set_material(final.get_surface_count() - 1, mat_predio if s == sp else mat_chao)
	mesh = final
	var mi := MeshInstance3D.new(); mi.mesh = mesh; raiz.add_child(mi)
	var corpo := StaticBody3D.new(); raiz.add_child(corpo)
	for cx in r[3]:
		var cs := CollisionShape3D.new(); var bx := BoxShape3D.new(); bx.size = cx[1]
		cs.shape = bx; cs.transform = cx[0]; corpo.add_child(cs)
	add_child(raiz)
	_vivos[k] = raiz

# ===================== geração (thread) =====================
func _tarefa(k: Vector2i) -> void:
	var mp := MalhaPredios.new(); var mg := MalhaPredios.new(); var caixas: Array = []
	for b in _celulas[k]:
		var rng := RandomNumberGenerator.new(); rng.seed = int(b["id"]) * 7919 + 13
		match b["tipo"]:
			"terminal": _terminal(mp, mg, caixas, b)
			"torre": _torre_controle(mp, caixas, b)
			"hangar": _hangar(mp, caixas, b, rng)
			_: _bloco(mp, mg, caixas, b, rng)
	_mutex.lock()
	_resultados.append([k, mp, mg, caixas])
	_mutex.unlock()

func _cantos(c: Vector2, bs: Basis, w: float, d: float) -> Array:
	var o := Vector3(c.x, 0, c.y)
	return [o + bs * Vector3(-w / 2, 0, -d / 2), o + bs * Vector3(w / 2, 0, -d / 2), o + bs * Vector3(w / 2, 0, d / 2), o + bs * Vector3(-w / 2, 0, d / 2)]

func _nivel(p: Vector3, w: float, d: float, yaw: float) -> float:
	var bs := Basis(Vector3.UP, yaw); var y := -1.0e9
	for q in [Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, 0, -d / 2), Vector3(w / 2, 0, d / 2), Vector3(-w / 2, 0, d / 2)]:
		var pp: Vector3 = p + bs * q
		y = maxf(y, Mundo.altura_em(pp.x, pp.z))
	return y

func _col(caixas: Array, centro: Vector3, tam: Vector3, yaw: float) -> void:
	caixas.append([Transform3D(Basis(Vector3.UP, yaw), centro + Vector3(0, tam.y * 0.5, 0)), tam])

func _bloco(mp: MalhaPredios, mg: MalhaPredios, caixas: Array, b: Dictionary, rng: RandomNumberGenerator) -> void:
	var c2: Vector2 = b["c"]; var yaw: float = b["yaw"]; var bs := Basis(Vector3.UP, yaw)
	var bw: float = b["bw"]; var bd: float = b["bd"]; var rua: float = b["rua"]
	var iw := bw - rua; var idp := bd - rua
	var tipo: String = b["tipo"]; var r: float = b["r"]
	mg.grade(_cantos(c2, bs, bw, bd), 3, 0.10, Color(0.11, 0.11, 0.12))
	var parque := (tipo == "cidade" and r > 0.35 and rng.randf() < 0.08)
	var cor_calc := Color(0.24, 0.38, 0.15) if parque else Color(0.60, 0.59, 0.56)
	mg.grade(_cantos(c2, bs, iw, idp), 3, 0.28, cor_calc)
	_postes_e_carros(mp, b, rng, bs, iw, idp)
	if parque: return
	var ax := iw - 6.0; var ad := idp - 6.0
	var o := Vector3(c2.x, 0, c2.y)
	var lote_med := 20.0 if tipo == "cidade" else (24.0 if tipo == "porto" else 17.0)
	var n := maxi(1, int(ax / lote_med))
	var lw := ax / n
	for row in 2:
		if tipo == "vila" and row == 1 and rng.randf() < 0.25: continue
		var lz := (-ad / 4.0 if row == 0 else ad / 4.0)
		var ld := ad / 2.0 - 1.0
		for i in n:
			var lx := -ax / 2.0 + lw * (i + 0.5)
			var pos := o + bs * Vector3(lx, 0, lz)
			var w := lw - rng.randf_range(0.8, 2.5); var d := ld - rng.randf_range(0.5, 3.0)
			var y0 := _nivel(pos, w, d, yaw) + 0.28
			pos.y = y0
			if b["centro"] and tipo == "vila" and i == n / 2 and row == 0:
				_igreja(mp, caixas, pos, yaw, rng); continue
			_lote(mp, caixas, b, pos, w, d, yaw, rng)

func _lote(mp: MalhaPredios, caixas: Array, b: Dictionary, pos: Vector3, w: float, d: float, yaw: float, rng: RandomNumberGenerator) -> void:
	var tipo: String = b["tipo"]; var r: float = b["r"]
	var sem := rng.randf() * 100.0
	var q := rng.randf()
	var cls := "casa"
	if tipo == "cidade":
		if r < 0.28: cls = "torre" if q < 0.7 else "predio"
		elif r < 0.6: cls = "predio" if q < 0.65 else ("loja" if q < 0.85 else ("torre" if q < 0.9 else "casa"))
		else: cls = "casa" if q < 0.55 else ("predio" if q < 0.85 else "loja")
	elif tipo == "porto":
		if b["costa"]: cls = "container" if q < 0.55 else ("galpao" if q < 0.9 else "predio")
		else: cls = "galpao" if q < 0.35 else ("predio" if q < 0.75 else "casa")
	else:
		cls = "casa" if q < 0.86 else "predio"
	match cls:
		"torre":
			var andares := int(lerpf(30.0, 12.0, r / 0.3)) + rng.randi_range(-3, 5)
			var H := andares * 3.6
			var vidro := rng.randf() < 0.65
			var cor: Color = VIDRO[rng.randi() % VIDRO.size()] if vidro else CONCRETO[rng.randi() % CONCRETO.size()]
			var sm := Vector2(sem, 1.0 if vidro else 0.0)
			var f := [1.0, 0.8, 0.55]; var alt := [0.55, 0.3, 0.15]
			var base := pos
			for t in 3:
				var tw: float = w * f[t]; var td: float = d * f[t]; var th: float = H * alt[t]
				var topo := mp.caixa(base, tw, td, th, yaw, cor, sm, true, 4.0 if t == 0 else 0.0)
				_col(caixas, base, Vector3(tw, th, td), yaw)
				base = Vector3(base.x, topo, base.z)
			_props_teto(mp, base, w * 0.55, d * 0.55, yaw, rng)
		"predio":
			var andares := rng.randi_range(4, 7) if r > 0.45 else rng.randi_range(6, 12)
			var H := andares * 3.3
			var cor: Color = CONCRETO[rng.randi() % CONCRETO.size()]
			var topo := mp.caixa(pos, w, d, H, yaw, cor, Vector2(sem, 0.0), true, 4.0)
			_col(caixas, pos, Vector3(w, H, d), yaw)
			_props_teto(mp, Vector3(pos.x, topo, pos.z), w, d, yaw, rng)
		"loja":
			var H := rng.randi_range(1, 2) * 3.8
			var cor := Color.from_hsv(rng.randf(), rng.randf_range(0.15, 0.45), rng.randf_range(0.7, 0.92))
			var topo := mp.caixa(pos, w, d, H, yaw, cor, Vector2(sem, 0.0), true, 3.0)
			_col(caixas, pos, Vector3(w, H, d), yaw)
			_props_teto(mp, Vector3(pos.x, topo, pos.z), w, d, yaw, rng)
		"casa":
			var hw := minf(w, rng.randf_range(10.0, 14.0)); var hd := minf(d, rng.randf_range(8.0, 11.0))
			var andares := rng.randi_range(1, 2)
			var H := andares * 3.1
			var cor: Color = CASA[rng.randi() % CASA.size()]
			var topo := mp.caixa(pos, hw, hd, H, yaw, cor, Vector2(sem, 3.0), true, 2.0)
			mp.telhado(Vector3(pos.x, topo, pos.z), hw, hd, 2.4, yaw, TELHA[rng.randi() % TELHA.size()], cor, Vector2(sem, 3.0))
			_col(caixas, pos, Vector3(hw, H + 2.0, hd), yaw)
		"galpao":
			var gw := minf(w, rng.randf_range(30.0, 44.0)); var gd := minf(d, rng.randf_range(18.0, 26.0))
			var H := rng.randf_range(8.0, 11.0)
			var cor: Color = METAL[rng.randi() % METAL.size()]
			var topo := mp.caixa(pos, gw, gd, H, yaw, cor, Vector2(sem, 2.0), true, 2.0)
			mp.telhado(Vector3(pos.x, topo, pos.z), gw, gd, 2.4, yaw, cor * 0.8, cor, Vector2(sem, 2.0), 0.4)
			_col(caixas, pos, Vector3(gw, H + 2.0, gd), yaw)
		"container":
			var bs := Basis(Vector3.UP, yaw)
			var cols := int(w / 2.6); var fil := int(d / 12.6)
			for ci in cols:
				for fi in maxi(fil, 1):
					var pp := pos + bs * Vector3(-w / 2 + 1.3 + ci * 2.6, 0, -d / 2 + 6.3 + fi * 12.6)
					var altura := rng.randi_range(1, 3)
					for a in altura:
						var cor: Color = CONT[rng.randi() % CONT.size()]
						mp.caixa(Vector3(pp.x, pos.y + a * 2.6, pp.z), 2.44, 12.2, 2.6, yaw, cor, Vector2(sem, 2.0), false)
					_col(caixas, pp, Vector3(2.44, altura * 2.6, 12.2), yaw)

func _props_teto(mp: MalhaPredios, topo: Vector3, w: float, d: float, yaw: float, rng: RandomNumberGenerator) -> void:
	var bs := Basis(Vector3.UP, yaw)
	for i in rng.randi_range(1, 4):
		var off := bs * Vector3(rng.randf_range(-w, w) * 0.3, 0, rng.randf_range(-d, d) * 0.3)
		var cor := Color(0.55, 0.57, 0.58) * rng.randf_range(0.8, 1.1)
		mp.caixa(topo + off, rng.randf_range(1.5, 3.5), rng.randf_range(1.5, 3.0), rng.randf_range(1.0, 2.4), yaw, cor, Vector2.ZERO, false)

func _postes_e_carros(mp: MalhaPredios, b: Dictionary, rng: RandomNumberGenerator, bs: Basis, iw: float, idp: float) -> void:
	var c2: Vector2 = b["c"]; var o := Vector3(c2.x, 0, c2.y); var yaw: float = b["yaw"]
	var cinza := Color(0.30, 0.31, 0.33)
	for lado in 4:
		var ao_x := (lado < 2)
		var comp := iw if ao_x else idp
		var sinal := -1.0 if (lado % 2 == 0) else 1.0
		var n := int(comp / 48.0)
		for i in n + 1:
			var t := -comp / 2.0 + 4.0 + i * ((comp - 8.0) / maxf(n, 1))
			var lp := Vector3(t, 0, sinal * (idp / 2.0 - 0.6)) if ao_x else Vector3(sinal * (iw / 2.0 - 0.6), 0, t)
			var pp := o + bs * lp
			pp.y = Mundo.altura_em(pp.x, pp.z) + 0.28
			mp.caixa(pp, 0.18, 0.18, 7.0, yaw, cinza, Vector2.ZERO, false)
		if b["tipo"] == "vila": continue
		var slots := int(comp / 14.0)
		for i in slots:
			if rng.randf() > 0.45: continue
			var t := -comp / 2.0 + 7.0 + i * 14.0
			var off := (idp / 2.0 + 2.6) if ao_x else (iw / 2.0 + 2.6)
			var lp := Vector3(t, 0, sinal * off) if ao_x else Vector3(sinal * off, 0, t)
			var pp := o + bs * lp
			pp.y = Mundo.altura_em(pp.x, pp.z) + 0.1
			var yc := yaw + (0.0 if not ao_x else PI * 0.5)
			var cor: Color = CARROS[rng.randi() % CARROS.size()]
			mp.caixa(pp + Vector3(0, 0.3, 0), 1.8, 4.2, 0.8, yc, cor, Vector2.ZERO, false)
			mp.caixa(pp + Vector3(0, 1.1, 0), 1.6, 2.2, 0.65, yc, Color(0.08, 0.1, 0.12), Vector2.ZERO, false)

func _igreja(mp: MalhaPredios, caixas: Array, pos: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	var cor := Color(0.92, 0.9, 0.84); var sem := Vector2(rng.randf() * 100.0, 3.0)
	var topo := mp.caixa(pos, 11.0, 24.0, 9.0, yaw, cor, sem, true, 2.0)
	mp.telhado(Vector3(pos.x, topo, pos.z), 11.0, 24.0, 4.5, yaw, Color(0.55, 0.25, 0.17), cor, sem)
	var bs := Basis(Vector3.UP, yaw)
	var tp := pos + bs * Vector3(0, 0, -13.0)
	var tt := mp.caixa(tp, 6.0, 6.0, 22.0, yaw, cor, sem, true, 2.0)
	mp.telhado(Vector3(tp.x, tt, tp.z), 6.0, 6.0, 6.0, yaw, Color(0.55, 0.25, 0.17), cor, sem, 0.3)
	_col(caixas, pos, Vector3(11, 12, 24), yaw); _col(caixas, tp, Vector3(6, 22, 6), yaw)

func _terminal(mp: MalhaPredios, mg: MalhaPredios, caixas: Array, b: Dictionary) -> void:
	var c2: Vector2 = b["c"]; var yaw: float = b["yaw"]; var bs := Basis(Vector3.UP, yaw)
	mg.grade(_cantos(c2 + Vector2(-60, 0), bs, 420.0, 170.0), 6, 0.1, Color(0.30, 0.30, 0.31))
	var pos := Vector3(c2.x, Mundo.altura_em(c2.x, c2.y) + 0.12, c2.y)
	var topo := mp.caixa(pos, 150.0, 32.0, 14.0, yaw, Color(0.25, 0.38, 0.46), Vector2(7.0, 1.0), true, 3.0, Color(0.85, 0.86, 0.88))
	mp.caixa(pos + bs * Vector3(0, 0, 18.0), 120.0, 5.0, 6.0, yaw, Color(0.82, 0.83, 0.85), Vector2.ZERO, false)
	_col(caixas, pos, Vector3(150, 14, 32), yaw)

func _torre_controle(mp: MalhaPredios, caixas: Array, b: Dictionary) -> void:
	var c2: Vector2 = b["c"]; var yaw: float = b["yaw"]
	var pos := Vector3(c2.x, Mundo.altura_em(c2.x, c2.y) + 0.12, c2.y)
	var t := mp.caixa(pos, 7.0, 7.0, 30.0, yaw, Color(0.80, 0.80, 0.78), Vector2(3.0, 0.0), true, 3.0)
	var t2 := mp.caixa(Vector3(pos.x, t, pos.z), 12.0, 12.0, 5.0, yaw, Color(0.20, 0.32, 0.40), Vector2(3.0, 1.0), true)
	_col(caixas, pos, Vector3(7, 30, 7), yaw)

func _hangar(mp: MalhaPredios, caixas: Array, b: Dictionary, rng: RandomNumberGenerator) -> void:
	var c2: Vector2 = b["c"]; var yaw: float = b["yaw"]
	var pos := Vector3(c2.x, Mundo.altura_em(c2.x, c2.y) + 0.12, c2.y)
	var cor: Color = METAL[rng.randi() % METAL.size()]
	var topo := mp.caixa(pos, 46.0, 34.0, 12.0, yaw, cor, Vector2(rng.randf() * 100.0, 2.0), true, 2.0)
	mp.telhado(Vector3(pos.x, topo, pos.z), 46.0, 34.0, 5.0, yaw, cor * 0.8, cor, Vector2.ZERO, 0.5)
	_col(caixas, pos, Vector3(46, 14, 34), yaw)
