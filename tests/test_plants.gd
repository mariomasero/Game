extends SceneTree

## Plantas del pueblo (scenes/village/props/plantas/, generadas por
## tools/build_plants.gd) y su shader, plant_sway.gdshader.
##
## El movimiento solo se juzga mirandolo; esto ata lo que lo hace posible sin
## romper el pixel: que hay una escena por planta de la ficha, que el quad mide lo
## mismo que el rectangulo del shader, que el rectangulo esta centrado en el pie y
## deja sitio a lo que viaja la punta, que la planta se apoya en el suelo, que
## solo lo que estorba lleva colision, y que los dibujos no tienen
## semitransparencias ni colores fuera de la paleta del proyecto.
##
##   godot --headless --path . --script tests/test_plants.gd

const FICHA := "res://assets/source/props/plantas/plantas.json"
const ESCENAS := "res://scenes/village/props/plantas/"
const SHADER := "res://assets/game/shaders/plant_sway.gdshader"
const PALETA := "res://assets/source/palettes/apollo_proyecto.gpl"

var checks := 0
var failures := 0
var _nombre := ""
var _paleta := {}

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: %s: %s" % [_nombre, message])
	else:
		print("PASS: %s: %s" % [_nombre, message])

func _run() -> void:
	_paleta = _leer_paleta()
	_nombre = "ficha"
	_check(_paleta.size() >= 58, "Se lee la paleta del proyecto")
	var fichas: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHA))
	_check(fichas is Array and not (fichas as Array).is_empty(), "Se lee plantas.json")
	if not fichas is Array:
		_fin()
		return
	var escenas := DirAccess.get_files_at(ESCENAS)
	var tscn := Array(escenas).filter(func(f: String) -> bool: return f.ends_with(".tscn"))
	_check(tscn.size() == (fichas as Array).size(),
		"Una escena por planta de la ficha (%d)" % tscn.size())
	for ficha: Dictionary in fichas:
		_nombre = ficha["nombre"]
		_planta(ficha)
	_fin()

func _planta(ficha: Dictionary) -> void:
	var escena := load(ESCENAS + _nombre + ".tscn") as PackedScene
	_check(escena != null, "Se carga la escena")
	if escena == null:
		return
	var planta := escena.instantiate() as VillageProp
	_check(planta != null, "Es un VillageProp")
	if planta == null:
		return
	root.add_child(planta)
	var lienzo := planta.get_node_or_null("Modelo/Lienzo") as MeshInstance3D
	var mat: ShaderMaterial = null
	if lienzo != null:
		mat = lienzo.get_surface_override_material(0) as ShaderMaterial
	_check(mat != null and mat.shader != null and mat.shader.resource_path == SHADER,
		"El lienzo lleva el material de plant_sway.gdshader")
	var textura: Texture2D = null
	if mat != null:
		textura = mat.get_shader_parameter(&"plant_texture") as Texture2D
	_check(textura != null, "El material lleva su textura")
	if textura == null:
		planta.free()
		return
	# Con --headless el servidor de render no guarda la imagen: se lee el PNG.
	var imagen := Image.load_from_file(ProjectSettings.globalize_path(textura.resource_path))
	_check(imagen.get_size() == Vector2i(int(ficha["lienzo"][0]), int(ficha["lienzo"][1])),
		"La textura mide lo que dice la ficha")
	_rectangulo(lienzo, mat, imagen)
	_suelo(planta, lienzo, mat)
	_colision(planta, ficha)
	_colores(imagen)
	planta.free()

func _rectangulo(lienzo: MeshInstance3D, mat: ShaderMaterial, imagen: Image) -> void:
	var rect_min: Vector2 = mat.get_shader_parameter(&"rect_min")
	var rect_size: Vector2 = mat.get_shader_parameter(&"rect_size")
	var quad := lienzo.mesh as QuadMesh
	_check(quad != null and quad.size.is_equal_approx(rect_size * VillageMetrics.TEXEL),
		"El QuadMesh mide el rectangulo del shader")
	_check(rect_min.y == 0.0 and rect_size.y == imagen.get_height(),
		"El rectangulo acaba abajo en la fila del suelo")
	_check(int(rect_size.x) % 2 == 0, "El rectangulo tiene ancho par")
	_check(is_equal_approx(rect_min.x + rect_size.x * 0.5, imagen.get_width() * 0.5),
		"El rectangulo esta centrado en el pie")
	var bend: float = mat.get_shader_parameter(&"bend_texels")
	var sway: float = mat.get_shader_parameter(&"sway_texels")
	_check(-rect_min.x >= bend + 1.35 * sway,
		"El margen (%d) cubre lo que viaja la punta" % int(-rect_min.x))
	_check(mat.get_shader_parameter(&"top_row") == float(imagen.get_used_rect().position.y),
		"top_row es la primera fila del dibujo")
	var paso: Vector3 = mat.get_shader_parameter(&"pixel_step")
	_check(paso.is_equal_approx(VillageMetrics.block_scale(
		VillageMetrics.DEFAULT_PITCH_DEGREES) * VillageMetrics.TEXEL),
		"pixel_step es el de VillageMetrics")

## VillageProp tiene que dejar el centro del quad a media altura del rectangulo,
## que es donde el shader lo rehace: asi el pie cae justo en el suelo.
func _suelo(planta: VillageProp, lienzo: MeshInstance3D, mat: ShaderMaterial) -> void:
	var rect_size: Vector2 = mat.get_shader_parameter(&"rect_size")
	var paso: Vector3 = mat.get_shader_parameter(&"pixel_step")
	var centro := lienzo.global_position - planta.global_position
	_check(is_equal_approx(centro.y, rect_size.y * paso.y * 0.5)
		and is_zero_approx(centro.x) and is_zero_approx(centro.z),
		"El pie del dibujo cae en la raiz, a ras de suelo")

func _colision(planta: VillageProp, ficha: Dictionary) -> void:
	var forma := planta.get_node_or_null("Colision/Forma") as CollisionShape3D
	_check(planta.atravesable == (forma == null),
		"Solo lleva colision si no es atravesable")
	_check(planta._get_configuration_warnings().is_empty(), "Sin avisos en el editor")
	if forma == null:
		_check(planta.huella() == Vector2i.ONE, "Lo que se cruza ocupa una casilla")
		return
	var celda := VillageMetrics.block_scale(VillageMetrics.DEFAULT_PITCH_DEGREES)
	var ocupa := planta.huella()
	var caja := forma.shape as BoxShape3D
	_check(ocupa.x == maxi(1, roundi(float(ficha["objeto"][0]) / 32.0)) and ocupa.y == 1,
		"Ocupa las casillas de su ancho (%d x %d)" % [ocupa.x, ocupa.y])
	_check(caja != null and caja.size.x <= ocupa.x * celda.x + 0.001
		and caja.size.z <= celda.z + 0.001, "La colision cabe en su huella")
	_check(caja != null and is_equal_approx(forma.position.y - caja.size.y * 0.5, 0.0),
		"La colision empieza en el suelo")

func _colores(imagen: Image) -> void:
	var fuera := {}
	var semi := 0
	for y in imagen.get_height():
		for x in imagen.get_width():
			var c := imagen.get_pixel(x, y)
			if c.a8 == 0:
				continue
			if c.a8 < 255:
				semi += 1
			var rgb := (c.r8 << 16) | (c.g8 << 8) | c.b8
			if not _paleta.has(rgb):
				fuera[rgb] = true
	_check(semi == 0, "Sin pixeles semitransparentes")
	_check(fuera.is_empty(), "Solo colores de la paleta")

func _leer_paleta() -> Dictionary:
	var colores := {}
	var archivo := FileAccess.open(PALETA, FileAccess.READ)
	if archivo == null:
		return colores
	var patron := RegEx.create_from_string("^\\s*(\\d+)\\s+(\\d+)\\s+(\\d+)")
	while not archivo.eof_reached():
		var m := patron.search(archivo.get_line())
		if m != null:
			colores[(int(m.get_string(1)) << 16) | (int(m.get_string(2)) << 8)
				| int(m.get_string(3))] = true
	return colores

func _fin() -> void:
	print("RESULTADO PLANTAS: %d comprobaciones, %d fallos" % [checks, failures])
	quit(1 if failures else 0)
