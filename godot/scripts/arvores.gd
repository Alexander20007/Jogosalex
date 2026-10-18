class_name Arvores
extends Node3D
## Árvores instanciadas (MultiMesh) por bloco do terreno, só perto do jogador.

const ESPACO := 12.0
const ALCANCE := 1700.0
var _mats: ShaderMaterial
var _malhas: Array[ArrayMesh] = []
var _vivos := {}          # Vector2i -> Array[MultiMeshInstance3D]
var _fila: Array = []

func _ready() -> void:
	_mats = ShaderMaterial.new()
	_mats.shader = load("res://shaders/vegetacao.gdshader")
	_malhas = [_malha_conifera(), _malha_folhosa()]

func chunk_lod(k: Vector2i, lod: int, origem: Vector3) -> void:
	if lod <= 1:
		if not _vivos.has(k) and not _fila.has(k): _fila.append(k)
	else:
		_fila.erase(k)
		if _vivos.has(k):
			for n in _vivos[k]: n.queue_free()
			_vivos.erase(k)

func _process(_dt: float) -> void:
	if _fila.is_empty(): return
	var k: Vector2i = _fila.pop_front()
	if _vivos.has(k): return
	_vivos[k] = _povoar(k)

func _povoar(k: Vector2i) -> Array:
	var mpp := Mundo.mpp
	var tam := 64.0 * mpp
	var ox := k.x * tam; var oz := k.y * tam
	var rng := RandomNumberGenerator.new(); rng.seed = hash(k) + 1337
	var lista: Array = [[], []]
	var n := int(tam / ESPACO)
	for j in n:
		for i in n:
			var x := ox + (i + rng.randf()) * ESPACO
			var z := oz + (j + rng.randf()) * ESPACO
			var dens := Mundo.zona_em(x, z, 0)
			if rng.randf() > dens: continue
			var y := Mundo.altura_em(x, z)
			if y < 1.5: continue
			var tipo := 0 if (y > 300.0 or rng.randf() < 0.25) else 1
			var s := rng.randf_range(0.8, 1.5) * (0.7 if y > 700.0 else 1.0)
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.25), s))
			lista[tipo].append(Transform3D(b, Vector3(x - ox, y - 0.3, z - oz)))
	var nos: Array = []
	for t in 2:
		if lista[t].is_empty(): continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _malhas[t]
		mm.instance_count = lista[t].size()
		for q in lista[t].size(): mm.set_instance_transform(q, lista[t][q])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm; mi.material_override = _mats
		mi.position = Vector3(ox, 0, oz)
		mi.visibility_range_end = ALCANCE
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi); nos.append(mi)
	return nos

# ---------- malhas procedurais ----------
static func _tronco(st: SurfaceTool, y0: float, h: float, r0: float, r1: float, lados: int, cor: Color) -> void:
	_tronco_cone(st, y0, h, r0, r1, lados, cor)

static func _tronco_cone(st: SurfaceTool, y0: float, h: float, r0: float, r1: float, lados: int, cor: Color, cor_topo := Color(-1, 0, 0)) -> void:
	if cor_topo.r < 0: cor_topo = cor
	var inc := (r0 - r1) / maxf(h, 0.001)
	for i in lados:
		var a0 := TAU * i / lados; var a1 := TAU * (i + 1) / lados
		var d0 := Vector3(cos(a0), 0, sin(a0)); var d1 := Vector3(cos(a1), 0, sin(a1))
		var n0 := (d0 + Vector3.UP * inc).normalized(); var n1 := (d1 + Vector3.UP * inc).normalized()
		var p := [d0 * r0 + Vector3(0, y0, 0), d1 * r0 + Vector3(0, y0, 0), d0 * r1 + Vector3(0, y0 + h, 0), d1 * r1 + Vector3(0, y0 + h, 0)]
		var ns := [n0, n1, n0, n1]; var cs := [cor, cor, cor_topo, cor_topo]
		for q in [0, 1, 2, 1, 3, 2]:
			st.set_color(cs[q]); st.set_normal(ns[q]); st.add_vertex(p[q])

func _malha_conifera() -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var marrom := Color(0.26, 0.17, 0.10)
	_tronco_cone(st, 0.0, 2.4, 0.28, 0.2, 5, marrom)
	_tronco_cone(st, 1.2, 3.6, 2.3, 0.15, 7, Color(0.08, 0.20, 0.10), Color(0.12, 0.28, 0.13))
	_tronco_cone(st, 3.2, 3.2, 1.8, 0.1, 7, Color(0.09, 0.22, 0.11), Color(0.14, 0.30, 0.14))
	_tronco_cone(st, 5.0, 2.8, 1.2, 0.0, 7, Color(0.10, 0.24, 0.12), Color(0.16, 0.34, 0.15))
	return st.commit()

func _malha_folhosa() -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tronco_cone(st, 0.0, 3.6, 0.32, 0.2, 5, Color(0.30, 0.21, 0.13))
	var v1 := Color(0.17, 0.33, 0.10); var v2 := Color(0.26, 0.42, 0.13)
	_tronco_cone(st, 2.8, 2.2, 0.5, 2.7, 8, v1, v1)
	_tronco_cone(st, 5.0, 2.4, 2.7, 0.0, 8, v1, v2)
	_tronco_cone(st, 4.2, 1.6, 0.5, 1.9, 6, v2, v2)
	_tronco_cone(st, 5.8, 1.8, 1.9, 0.0, 6, v2, Color(0.34, 0.50, 0.16))
	return st.commit()
