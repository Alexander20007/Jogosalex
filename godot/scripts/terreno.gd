class_name Terreno
extends Node3D
## Terreno em blocos (chunks) de 64x64 quadrados com 4 níveis de detalhe, gerados em threads.
## Mantém também uma janela de colisão (HeightMapShape3D) em volta do alvo.

const CH := 64
const PASSOS := [1, 2, 4, 8]
const DIST_LOD := [650.0, 1300.0, 2600.0]
const JANELA := 129
const MAX_TAREFAS := 3

var cols := 0
var lins := 0
var mat: ShaderMaterial
var chunks := {}                  # Vector2i -> {no, lod, pedido}
var alvo := Vector3.ZERO
var arvores: Arvores
var _resultados: Array = []
var _mutex := Mutex.new()
var _ativas := 0
var _t := 0.0
var _corpo: StaticBody3D
var _forma: HeightMapShape3D
var _col_centro := Vector2i(-99999, -99999)

func iniciar() -> void:
	cols = ceili((Mundo.largura - 1) / float(CH))
	lins = ceili((Mundo.altura - 1) / float(CH))
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/terreno.gdshader")
	mat.set_shader_parameter("splat", Mundo.splat_tex)
	mat.set_shader_parameter("tamanho_mundo", Mundo.tamanho)
	var rn := FastNoiseLite.new(); rn.frequency = 0.02; rn.fractal_octaves = 4
	var tex := NoiseTexture2D.new(); tex.noise = rn; tex.seamless = true; tex.width = 512; tex.height = 512
	mat.set_shader_parameter("ruido", tex)
	var rn2 := FastNoiseLite.new(); rn2.frequency = 0.05; rn2.fractal_octaves = 3
	var tex2 := NoiseTexture2D.new(); tex2.noise = rn2; tex2.seamless = true; tex2.as_normal_map = true; tex2.bump_strength = 6.0; tex2.width = 512; tex2.height = 512
	mat.set_shader_parameter("ruido_normal", tex2)
	arvores = Arvores.new(); arvores.name = "Arvores"; add_child(arvores)
	for cz in lins:
		for cx in cols:
			var no := MeshInstance3D.new()
			no.position = Vector3(cx * CH * Mundo.mpp, 0, cz * CH * Mundo.mpp)
			no.material_override = mat
			no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(no)
			chunks[Vector2i(cx, cz)] = {"no": no, "lod": -1, "pedido": -1}
	_corpo = StaticBody3D.new(); _corpo.name = "ColisaoTerreno"
	var cs := CollisionShape3D.new(); _forma = HeightMapShape3D.new()
	_forma.map_width = JANELA; _forma.map_depth = JANELA
	var zero := PackedFloat32Array(); zero.resize(JANELA * JANELA)
	_forma.map_data = zero
	cs.shape = _forma; cs.scale = Vector3(Mundo.mpp, 1.0, Mundo.mpp)
	_corpo.add_child(cs); add_child(_corpo)

func atualizar_colisao(pos: Vector3, forcar := false) -> void:
	var ix := roundi(pos.x / Mundo.mpp); var iz := roundi(pos.z / Mundo.mpp)
	if not forcar and absi(ix - _col_centro.x) < 20 and absi(iz - _col_centro.y) < 20: return
	_col_centro = Vector2i(ix, iz)
	var d := PackedFloat32Array(); d.resize(JANELA * JANELA)
	var m := JANELA / 2
	for j in JANELA:
		for i in JANELA:
			d[j * JANELA + i] = Mundo.alt_idx(ix - m + i, iz - m + j)
	_forma.map_data = d
	_corpo.global_position = Vector3(ix * Mundo.mpp, 0.0, iz * Mundo.mpp)

func _process(dt: float) -> void:
	_t += dt
	if _t > 0.25:
		_t = 0.0
		_planejar()
		atualizar_colisao(alvo)
	# aplica resultados prontos (até 2 por quadro)
	for _k in 2:
		_mutex.lock()
		var r = _resultados.pop_front() if _resultados.size() > 0 else null
		_mutex.unlock()
		if r == null: break
		_ativas -= 1
		var c: Dictionary = chunks[Vector2i(r[0], r[1])]
		var arr := []; arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = r[3]; arr[Mesh.ARRAY_NORMAL] = r[4]; arr[Mesh.ARRAY_INDEX] = r[5]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		c["no"].mesh = mesh
		c["lod"] = r[2]
		arvores.chunk_lod(Vector2i(r[0], r[1]), r[2], c["no"].position)

func _lod_para(dist: float) -> int:
	for i in DIST_LOD.size():
		if dist < DIST_LOD[i]: return i
	return 3

func _planejar() -> void:
	if _ativas >= MAX_TAREFAS: return
	var cand := []
	var meio := CH * Mundo.mpp * 0.5
	for k in chunks:
		var c: Dictionary = chunks[k]
		var cen := Vector2(k.x * CH * Mundo.mpp + meio, k.y * CH * Mundo.mpp + meio)
		var d := cen.distance_to(Vector2(alvo.x, alvo.z))
		var want := _lod_para(maxf(d - meio, 0.0))
		if c["pedido"] != want: cand.append([d, k, want])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	for e in cand:
		if _ativas >= MAX_TAREFAS: break
		var k: Vector2i = e[1]
		chunks[k]["pedido"] = e[2]
		_ativas += 1
		WorkerThreadPool.add_task(_tarefa.bind(k.x, k.y, e[2]))

func _tarefa(cx: int, cz: int, lod: int) -> void:
	var step: int = PASSOS[lod]
	var n := CH / step
	var nv := n + 1
	var mpp := Mundo.mpp
	var bx := cx * CH; var bz := cz * CH
	var verts := PackedVector3Array(); var norms := PackedVector3Array()
	var total := nv * nv + 4 * nv
	verts.resize(total); norms.resize(total)
	for j in nv:
		for i in nv:
			var ix := bx + i * step; var iz := bz + j * step
			var h := Mundo.alt_idx(ix, iz)
			var hl := Mundo.alt_idx(ix - step, iz); var hr := Mundo.alt_idx(ix + step, iz)
			var hu := Mundo.alt_idx(ix, iz - step); var hd := Mundo.alt_idx(ix, iz + step)
			var k := j * nv + i
			verts[k] = Vector3(i * step * mpp, h, j * step * mpp)
			norms[k] = Vector3(hl - hr, 2.0 * step * mpp, hu - hd).normalized()
	# saias nas bordas para esconder rachaduras entre níveis de detalhe
	var saia := 5.0 * step
	var base := nv * nv
	var idx := PackedInt32Array()
	for j in n:
		for i in n:
			var a := j * nv + i; var b := a + 1; var c := a + nv; var d := c + 1
			idx.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var bordas := []
	for i in nv: bordas.append(i)                       # topo
	for i in nv: bordas.append((nv - 1) * nv + i)       # base
	for j in nv: bordas.append(j * nv)                  # esquerda
	for j in nv: bordas.append(j * nv + nv - 1)         # direita
	for q in bordas.size():
		var v: int = bordas[q]
		verts[base + q] = verts[v] + Vector3(0, -saia, 0)
		norms[base + q] = norms[v]
	for lado in 4:
		for s in n:
			var o := lado * nv
			var a1: int = bordas[o + s]; var a2: int = bordas[o + s + 1]
			var b1 := base + o + s; var b2 := base + o + s + 1
			idx.append_array(PackedInt32Array([a1, a2, b1, a2, b2, b1]))
	_mutex.lock()
	_resultados.append([cx, cz, lod, verts, norms, idx])
	_mutex.unlock()
