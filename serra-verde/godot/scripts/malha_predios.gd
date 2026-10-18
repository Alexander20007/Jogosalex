class_name MalhaPredios
extends RefCounted
## Acumula geometria de prédios/chão. Vertex COLOR.a = 1 -> fachada com janelas. UV = metros. UV2 = (semente, tipo).

var v := PackedVector3Array()
var n := PackedVector3Array()
var uv := PackedVector2Array()
var uv2 := PackedVector2Array()
var c := PackedColorArray()
var idx := PackedInt32Array()

func quad(p: Array, cor: Color, uvs: Array, sem: Vector2, interior: Vector3) -> void:
	var nn: Vector3 = (p[1] - p[0]).cross(p[3] - p[0])
	if nn.length() < 0.00001: return
	nn = nn.normalized()
	var cen: Vector3 = (p[0] + p[1] + p[2] + p[3]) * 0.25
	if nn.dot(cen - interior) < 0.0: nn = -nn
	var b := v.size()
	for i in 4:
		v.append(p[i]); n.append(nn); uv.append(uvs[i]); uv2.append(sem); c.append(cor)
	idx.append_array(PackedInt32Array([b, b + 1, b + 2, b, b + 2, b + 3]))

func tri(p: Array, cor: Color, sem: Vector2, interior: Vector3) -> void:
	var nn: Vector3 = (p[1] - p[0]).cross(p[2] - p[0])
	if nn.length() < 0.00001: return
	nn = nn.normalized()
	var cen: Vector3 = (p[0] + p[1] + p[2]) / 3.0
	if nn.dot(cen - interior) < 0.0: nn = -nn
	var b := v.size()
	for i in 3:
		v.append(p[i]); n.append(nn); uv.append(Vector2.ZERO); uv2.append(sem); c.append(cor)
	idx.append_array(PackedInt32Array([b, b + 1, b + 2]))

## Caixa com base em 'centro' (y = nível do piso). Retorna y do topo.
func caixa(centro: Vector3, w: float, d: float, h: float, yaw: float, cor: Color, sem: Vector2, fachada: bool, fundo := 0.0, cor_topo := Color(-1, 0, 0)) -> float:
	if cor_topo.r < 0.0: cor_topo = cor * 0.8
	var rot := Basis(Vector3.UP, yaw)
	var lc := [Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, 0, -d / 2), Vector3(w / 2, 0, d / 2), Vector3(-w / 2, 0, d / 2)]
	var pc: Array = []
	for q in lc: pc.append(centro + rot * q)
	var yb := -fundo; var yt := h
	var inter := centro + Vector3(0, h * 0.5, 0)
	var corf := Color(cor.r, cor.g, cor.b, 1.0 if fachada else 0.0)
	for i in 4:
		var p0: Vector3 = pc[i]; var p1: Vector3 = pc[(i + 1) % 4]
		var L := Vector2(p1.x - p0.x, p1.z - p0.z).length()
		var q0 := p0 + Vector3(0, yb, 0); var q1 := p1 + Vector3(0, yb, 0)
		var q2 := p1 + Vector3(0, yt, 0); var q3 := p0 + Vector3(0, yt, 0)
		quad([q0, q1, q2, q3], corf, [Vector2(0, yb), Vector2(L, yb), Vector2(L, yt), Vector2(0, yt)], sem, inter)
	var top: Array = []
	for q in pc: top.append(q + Vector3(0, yt, 0))
	quad(top, Color(cor_topo.r, cor_topo.g, cor_topo.b, 0.0), [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], sem, inter)
	return centro.y + h

## Telhado de duas águas. 'centro' = ponto no topo das paredes.
func telhado(centro: Vector3, w: float, d: float, h: float, yaw: float, cor_tel: Color, cor_par: Color, sem: Vector2, beiral := 0.5) -> void:
	var ao_x := w >= d
	var L := (w if ao_x else d) + beiral * 2.0
	var D := (d if ao_x else w) + beiral * 2.0
	var rot := Basis(Vector3.UP, yaw + (0.0 if ao_x else PI * 0.5))
	var e0 := centro + rot * Vector3(-L / 2, 0, -D / 2)
	var e1 := centro + rot * Vector3(L / 2, 0, -D / 2)
	var e2 := centro + rot * Vector3(L / 2, 0, D / 2)
	var e3 := centro + rot * Vector3(-L / 2, 0, D / 2)
	var r0 := centro + rot * Vector3(-L / 2, h, 0)
	var r1 := centro + rot * Vector3(L / 2, h, 0)
	var inter := centro + Vector3(0, -2.0, 0)
	var ct := Color(cor_tel.r, cor_tel.g, cor_tel.b, 0.0)
	var z4 := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	quad([e0, e1, r1, r0], ct, z4, sem, inter)
	quad([e3, e2, r1, r0], ct, z4, sem, inter)
	var cp := Color(cor_par.r, cor_par.g, cor_par.b, 0.0)
	tri([e0, e3, r0], cp, sem, inter)
	tri([e1, e2, r1], cp, sem, inter)

## Superfície amostrada no terreno (n x n) entre 4 cantos (mundo, y ignorado).
func grade(cantos: Array, nn: int, dy: float, cor: Color) -> void:
	var b := v.size()
	for j in nn + 1:
		for i in nn + 1:
			var fu := float(i) / nn; var fv := float(j) / nn
			var a: Vector3 = (cantos[0] as Vector3).lerp(cantos[1], fu)
			var d: Vector3 = (cantos[3] as Vector3).lerp(cantos[2], fu)
			var p: Vector3 = a.lerp(d, fv)
			p.y = Mundo.altura_em(p.x, p.z) + dy
			v.append(p); n.append(Vector3.UP); uv.append(Vector2.ZERO); uv2.append(Vector2.ZERO); c.append(cor)
	for j in nn:
		for i in nn:
			var k := b + j * (nn + 1) + i
			idx.append_array(PackedInt32Array([k, k + 1, k + nn + 1, k + 1, k + nn + 2, k + nn + 1]))

func para_malha(mat: Material = null) -> ArrayMesh:
	var m := ArrayMesh.new()
	if v.is_empty(): return m
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_NORMAL] = n; arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2; arr[Mesh.ARRAY_COLOR] = c; arr[Mesh.ARRAY_INDEX] = idx
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	if mat: m.surface_set_material(0, mat)
	return m
