extends SceneTree

## Casa del laboratorio viejo (scenes/village/props/laboratorio_viejo.tscn).
##
## Ata lo que la deja a pixel exacto: que mide 8 x 6 x 4 celdas con la base en el
## suelo y centrada en la raiz, que ocupa 8 x 4 casillas (4 x 8 girada), que la
## colision es su caja, que cada vertice cae en un texel entero, y que el atlas
## rehecho por tools/build_old_lab_atlas.gd solo usa colores de
## casa_laboratorio.gpl con filtrado nearest.
##
##   godot --headless --path . --script tests/test_old_lab.gd

const ESCENA := "res://scenes/village/props/laboratorio_viejo.tscn"
const PALETA := "res://assets/source/props/old_laboratory/casa_laboratorio.gpl"
## Celdas del .obj: 256 x 192 x 128 voxeles a 32 por celda.
const CELDAS := Vector3(8, 6, 4)

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: %s" % message)
	else:
		print("PASS: %s" % message)

func _run() -> void:
	var escena := load(ESCENA) as PackedScene
	_check(escena != null, "Se carga la escena")
	if escena == null:
		_fin()
		return
	var casa := escena.instantiate() as VillageProp
	_check(casa != null, "Es un VillageProp")
	if casa == null:
		_fin()
		return
	root.add_child(casa)
	var celda := VillageMetrics.block_scale(VillageMetrics.DEFAULT_PITCH_DEGREES)
	var esperada := CELDAS * celda
	_check(casa.caja.size.is_equal_approx(esperada),
		"Mide 8 x 6 x 4 celdas (%s, se espera %s)" % [str(casa.caja.size), str(esperada)])
	_check(is_zero_approx(casa.caja.position.y), "Apoya en el suelo")
	_check(casa.caja.get_center().x == 0.0 or is_zero_approx(casa.caja.get_center().x),
		"Centrada en X sobre la raiz")
	_check(is_zero_approx(casa.caja.get_center().z), "Centrada en Z sobre la raiz")
	_check(casa.huella() == Vector2i(8, 4), "Ocupa 8 x 4 casillas (%s)" % str(casa.huella()))

	var forma := casa.get_node("Colision/Forma") as CollisionShape3D
	var box := forma.shape as BoxShape3D
	_check(box != null and box.size.is_equal_approx(casa.caja.size),
		"La colision es la caja de la casa")
	_check(forma.position.is_equal_approx(casa.caja.get_center()),
		"La colision va centrada en la caja")

	var malla := casa.get_node("Modelo/Malla") as MeshInstance3D
	_vertices(malla.mesh)
	_material(malla)

	casa.rotation = Vector3(0.0, PI * 0.5, 0.0)
	casa.call("_reajustar")
	_check(casa.huella() == Vector2i(4, 8), "Girada ocupa 4 x 8 (%s)" % str(casa.huella()))
	casa.queue_free()
	_fin()

## Cada vertice del .obj en un texel entero: si no, alguna arista caeria entre
## pixeles y la cara mediria uno de mas o de menos. Se miran los vertices que se
## dibujan: get_faces() lee la malla de sombras, que Godot comprime aunque la
## importacion lleve force_disable_mesh_compression (desvio medido: 0,0016 texeles).
func _vertices(mesh: Mesh) -> void:
	var fuera := 0
	var caras: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for p in caras:
		var t := p * float(VillageMetrics.TEXELS_PER_CELL)
		if not t.is_equal_approx(t.round()):
			fuera += 1
	_check(caras.size() > 0 and fuera == 0,
		"Los %d vertices caen en texeles enteros (%d fuera)" % [caras.size(), fuera])

func _material(malla: MeshInstance3D) -> void:
	var mat := malla.get_surface_override_material(0) as StandardMaterial3D
	_check(mat != null, "Lleva material propio")
	if mat == null:
		return
	_check(mat.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST,
		"Filtrado nearest")
	var textura := mat.albedo_texture
	_check(textura != null and textura.get_size() == Vector2(1024, 512),
		"El atlas mide 1024 x 512")
	if textura == null:
		return
	var imagen := textura.get_image()
	if imagen.is_compressed():
		imagen.decompress()
	imagen.convert(Image.FORMAT_RGBA8)
	var paleta := {}
	var texto := FileAccess.get_file_as_string(PALETA)
	for linea in texto.split("\n"):
		var p := linea.replace("\t", " ").strip_edges().split(" ", false)
		if p.size() >= 3 and p[0].is_valid_int() and p[1].is_valid_int() \
				and p[2].is_valid_int():
			paleta[Color8(p[0].to_int(), p[1].to_int(), p[2].to_int()).to_rgba32()] = true
	var opacos := 0
	var fuera := 0
	for y in imagen.get_height():
		for x in imagen.get_width():
			var c := imagen.get_pixel(x, y)
			if c.a8 == 0:
				continue
			opacos += 1
			if not paleta.has(c.to_rgba32() | 0xff):
				fuera += 1
	_check(paleta.size() == 41, "La paleta tiene sus 41 colores (%d)" % paleta.size())
	# 224 108: el area de todas las caras del .obj, medida al rehacer el atlas.
	_check(opacos == 224108, "El atlas pinta un texel por cada texel de cara (%d)" % opacos)
	_check(fuera == 0, "Solo colores de casa_laboratorio.gpl (%d fuera)" % fuera)

func _fin() -> void:
	print("RESULTADO LABORATORIO VIEJO: %d comprobaciones, %d fallos" % [checks, failures])
	quit(1 if failures else 0)
