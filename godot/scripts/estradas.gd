class_name Estradas
extends Node3D
## Constrói as estradas (fitas desenhadas sobre o terreno) e as pistas do aeroporto.

var _mat: ShaderMaterial

func construir() -> void:
	_mat = ShaderMaterial.new(); _mat.shader = load("res://shaders/estrada.gdshader")
	for e in Mundo.dados["estradas"]:
		_fita(e["pontos"], float(e["largura_m"]), _tipo(e["tipo"]), e["nome"])
	for p in Mundo.dados["pistas"]:
		var a: Array = p["a"]; var b: Array = p["b"]
		var pts := []
		var comp := Vector2(a[0], a[1]).distance_to(Vector2(b[0], b[1]))
		var n := int(comp / 40.0) + 1
		for i in n + 1:
			var t := float(i) / n
			pts.append([lerpf(a[0], b[0], t), p["y"], lerpf(a[1], b[1], t)])
		_fita(pts, float(p["largura_m"]), 3.0, "Pista")

func _tipo(t: String) -> float:
	match t:
		"rodovia": return 0.0
		"principal": return 0.0
		"secundaria": return 1.0
		_: return 2.0

func _fita(pts: Array, larg: float, tipo: float, nome: String) -> void:
	if pts.size() < 2: return
	var v := PackedVector3Array(); var n := PackedVector3Array(); var uv := PackedVector2Array(); var cor := PackedColorArray()
	var idx := PackedInt32Array()
	var ombro := 2.2 if tipo < 3.0 else 0.5
	var comp := 0.0
	for i in pts.size():
		var p := Vector3(pts[i][0], pts[i][1], pts[i][2])
		var a := Vector3(pts[maxi(i - 1, 0)][0], 0, pts[maxi(i - 1, 0)][2])
		var b := Vector3(pts[mini(i + 1, pts.size() - 1)][0], 0, pts[mini(i + 1, pts.size() - 1)][2])
		var dir := (b - a).normalized()
		var lado := Vector3(-dir.z, 0, dir.x)
		if i > 0: comp += Vector3(pts[i][0], 0, pts[i][2]).distance_to(Vector3(pts[i - 1][0], 0, pts[i - 1][2]))
		var meia := larg * 0.5
		# 4 vértices por seção: ombro E, borda E, borda D, ombro D
		var xs := [-(meia + ombro), -meia, meia, meia + ombro]
		var ys := [-1.4, 0.0, 0.0, -1.4]
		var ux := [-1.0 - ombro / meia, -1.0, 1.0, 1.0 + ombro / meia]
		for q in 4:
			v.append(p + lado * xs[q] + Vector3(0, ys[q] + 0.25, 0))
			n.append(Vector3.UP)
			uv.append(Vector2(ux[q], comp))
			cor.append(Color(tipo / 3.0, 0, 0, 1))
		if i > 0:
			var k := (i - 1) * 4
			for q in 3:
				idx.append_array(PackedInt32Array([k + q, k + q + 1, k + q + 4, k + q + 1, k + q + 5, k + q + 4]))
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_NORMAL] = n; arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_COLOR] = cor; arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new(); mi.mesh = m; mi.material_override = _mat; mi.name = nome
	mi.visibility_range_end = 2600.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
