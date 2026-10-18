class_name Agua
extends Node3D
## Mar, lagos, rio e pântano.

var mat_mar: ShaderMaterial
var mat_doce: ShaderMaterial

func construir() -> void:
	var rn := FastNoiseLite.new(); rn.frequency = 0.03; rn.fractal_octaves = 3
	var tex := NoiseTexture2D.new(); tex.noise = rn; tex.seamless = true; tex.as_normal_map = true; tex.bump_strength = 8.0
	tex.width = 512; tex.height = 512
	var sh: Shader = load("res://shaders/agua.gdshader")
	mat_mar = ShaderMaterial.new(); mat_mar.shader = sh
	mat_mar.set_shader_parameter("ondas", tex)
	mat_mar.set_shader_parameter("cor_rasa", Color(0.10, 0.42, 0.50))
	mat_mar.set_shader_parameter("cor_funda", Color(0.01, 0.12, 0.20))
	mat_mar.set_shader_parameter("escala", 0.012)
	mat_mar.set_shader_parameter("velocidade", 0.012)
	mat_doce = ShaderMaterial.new(); mat_doce.shader = sh
	mat_doce.set_shader_parameter("ondas", tex)
	mat_doce.set_shader_parameter("cor_rasa", Color(0.14, 0.36, 0.34))
	mat_doce.set_shader_parameter("cor_funda", Color(0.04, 0.17, 0.20))
	mat_doce.set_shader_parameter("escala", 0.03)
	mat_doce.set_shader_parameter("velocidade", 0.006)
	_mar(); _lagos(); _rio(); _pantano()

func _instancia(mesh: Mesh, mat: Material, nome: String) -> void:
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = mat; mi.name = nome
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _mar() -> void:
	var pl := PlaneMesh.new(); pl.size = Vector2(60000, 60000); pl.subdivide_width = 1; pl.subdivide_depth = 1
	var mi := MeshInstance3D.new(); mi.mesh = pl; mi.material_override = mat_mar; mi.name = "Mar"
	mi.position = Vector3(Mundo.tamanho.x * 0.5, 0.0, Mundo.tamanho.y * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _poligono(pts: Array, nivel: float) -> ArrayMesh:
	var p2 := PackedVector2Array()
	for q in pts: p2.append(Vector2(q[0], q[1]))
	var tri := Geometry2D.triangulate_polygon(p2)
	var v := PackedVector3Array(); var n := PackedVector3Array()
	for q in p2: v.append(Vector3(q.x, nivel, q.y)); n.append(Vector3.UP)
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_NORMAL] = n; arr[Mesh.ARRAY_INDEX] = tri
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

func _lagos() -> void:
	for lg in Mundo.dados["lagos"]:
		_instancia(_poligono(lg["poligono"], lg["nivel"]), mat_doce, lg["nome"])

func _pantano() -> void:
	var s: Dictionary = Mundo.dados["pantano"]
	_instancia(_poligono(s["poligono"], s["nivel"]), mat_doce, "Pantano")

func _rio() -> void:
	var pts: Array = Mundo.dados["rio"]["pontos"]
	var v := PackedVector3Array(); var n := PackedVector3Array(); var idx := PackedInt32Array()
	for i in pts.size():
		var p := Vector3(pts[i][0], pts[i][1], pts[i][2])
		var a: Vector3 = Vector3(pts[maxi(i - 1, 0)][0], 0, pts[maxi(i - 1, 0)][2])
		var b: Vector3 = Vector3(pts[mini(i + 1, pts.size() - 1)][0], 0, pts[mini(i + 1, pts.size() - 1)][2])
		var dir := (b - a).normalized()
		var lado := Vector3(-dir.z, 0, dir.x) * float(pts[i][3]) * 0.6
		v.append(p - lado); v.append(p + lado); n.append(Vector3.UP); n.append(Vector3.UP)
		if i > 0:
			var k := (i - 1) * 2
			idx.append_array(PackedInt32Array([k, k + 1, k + 2, k + 1, k + 3, k + 2]))
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_NORMAL] = n; arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_instancia(m, mat_doce, "Rio")
