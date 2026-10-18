extends Node
## Autoload: carrega os dados gerados por tools/gerar_mundo.py e oferece consultas rápidas.

const PASTA := "res://assets/world/"
var largura := 0
var altura := 0
var mpp := 7.75
var tamanho := Vector2.ZERO
var alturas := PackedFloat32Array()
var zonas := PackedByteArray()      # RGBA: R=floresta G=urbano B=campos A=pradaria
var splat_tex: ImageTexture
var dados: Dictionary = {}
var carregado := false
var _estradas_grade := {}           # Vector2i -> Array[Vector3]
const CEL_EST := 200.0
const SEM_AGUA := -1.0e9

func _ready() -> void:
	_registrar_entradas()

func carregar() -> void:
	if carregado: return
	dados = JSON.parse_string(FileAccess.get_file_as_string(PASTA + "mundo.json"))
	largura = int(dados["largura"]); altura = int(dados["altura"])
	mpp = float(dados["metros_por_pixel"])
	tamanho = Vector2((largura - 1) * mpp, (altura - 1) * mpp)
	var f := FileAccess.open(PASTA + "heightmap.f32", FileAccess.READ)
	alturas = f.get_buffer(f.get_length()).to_float32_array()
	f.close()
	f = FileAccess.open(PASTA + "zonas.rgba", FileAccess.READ)
	zonas = f.get_buffer(f.get_length())
	f.close()
	f = FileAccess.open(PASTA + "splat.rgba", FileAccess.READ)
	var sp := f.get_buffer(f.get_length())
	f.close()
	splat_tex = ImageTexture.create_from_image(Image.create_from_data(largura, altura, false, Image.FORMAT_RGBA8, sp))
	_indexar_estradas()
	carregado = true

func alt_idx(ix: int, iz: int) -> float:
	ix = clampi(ix, 0, largura - 1); iz = clampi(iz, 0, altura - 1)
	return alturas[iz * largura + ix]

func altura_em(x: float, z: float) -> float:
	var gx := clampf(x / mpp, 0.0, largura - 1.001)
	var gz := clampf(z / mpp, 0.0, altura - 1.001)
	var ix := int(gx); var iz := int(gz)
	var fx := gx - ix; var fz := gz - iz
	var i := iz * largura + ix
	return lerpf(lerpf(alturas[i], alturas[i + 1], fx), lerpf(alturas[i + largura], alturas[i + largura + 1], fx), fz)

func normal_em(x: float, z: float) -> Vector3:
	var e := mpp
	return Vector3(altura_em(x - e, z) - altura_em(x + e, z), 2.0 * e, altura_em(x, z - e) - altura_em(x, z + e)).normalized()

func zona_em(x: float, z: float, canal: int) -> float:
	var ix := clampi(int(x / mpp), 0, largura - 1); var iz := clampi(int(z / mpp), 0, altura - 1)
	return zonas[(iz * largura + ix) * 4 + canal] / 255.0

func agua_em(x: float, z: float) -> float:
	## Nível da água naquele ponto, ou SEM_AGUA.
	var h := altura_em(x, z)
	if h < 0.0: return 0.0
	var p := Vector2(x, z)
	for lago in dados["lagos"]:
		var poly: PackedVector2Array = lago.get("_poly", PackedVector2Array())
		if poly.is_empty():
			for q in lago["poligono"]: poly.append(Vector2(q[0], q[1]))
			lago["_poly"] = poly
		if Geometry2D.is_point_in_polygon(p, poly) and h < lago["nivel"]: return lago["nivel"]
	var pts: Array = dados["rio"]["pontos"]
	for i in range(0, pts.size() - 1):
		var a := Vector2(pts[i][0], pts[i][2]); var b := Vector2(pts[i + 1][0], pts[i + 1][2])
		var c := Geometry2D.get_closest_point_to_segment(p, a, b)
		if p.distance_to(c) < pts[i][3] * 0.5 and h < pts[i][1]: return pts[i][1]
	return SEM_AGUA

func _indexar_estradas() -> void:
	_estradas_grade.clear()
	for e in dados["estradas"]:
		if e["tipo"] == "terra": continue
		for p in e["pontos"]:
			var k := Vector2i(int(p[0] / CEL_EST), int(p[2] / CEL_EST))
			if not _estradas_grade.has(k): _estradas_grade[k] = []
			_estradas_grade[k].append(Vector2(p[0], p[2]))

func dist_estrada(x: float, z: float) -> float:
	var k := Vector2i(int(x / CEL_EST), int(z / CEL_EST))
	var melhor := 1.0e9
	var p := Vector2(x, z)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var lst = _estradas_grade.get(Vector2i(k.x + dx, k.y + dz))
			if lst == null: continue
			for q in lst: melhor = minf(melhor, p.distance_to(q))
	return melhor

func _registrar_entradas() -> void:
	var mapa := {
		"frente": KEY_W, "tras": KEY_S, "esquerda": KEY_A, "direita": KEY_D,
		"pular": KEY_SPACE, "correr": KEY_SHIFT, "camera": KEY_V, "interagir": KEY_E, "mapa": KEY_M, "freio": KEY_CTRL,
	}
	for nome in mapa:
		if not InputMap.has_action(nome):
			InputMap.add_action(nome)
			var ev := InputEventKey.new(); ev.physical_keycode = mapa[nome]
			InputMap.action_add_event(nome, ev)
