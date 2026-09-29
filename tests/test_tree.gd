extends SceneTree

## Arboles del pueblo (scenes/village/props/arbol.tscn y abeto.tscn), su shader
## de viento y la copa que se funde al tapar al personaje.
##
## El movimiento solo se juzga mirandolo; esto ata lo que lo hace posible sin
## romper el pixel: que el quad mide lo mismo que el rectangulo del shader, que
## sus bordes caen entre pixeles con el pie del tronco en la raiz, que el
## rectangulo deja sitio a lo que puede viajar la copa, que los destellos solo
## cambian un tono de la copa por otro que ya tiene, y que solo el tronco ocupa
## casilla y frena al personaje. Del fundido: que la copa tapa justo donde tiene
## texeles, que al fundirse la sombra sigue y que en el pueblo se funde con el
## personaje detras y no delante.
##
##   godot --headless --path . --script tests/test_tree.gd

const ESCENAS := ["res://scenes/village/props/arbol.tscn",
	"res://scenes/village/props/abeto.tscn"]
const PUEBLO := "res://scenes/world/village.tscn"
const INCLUDE := "res://assets/game/shaders/tree_sway.gdshaderinc"

var checks := 0
var failures := 0
var _nombre := ""

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
	for ruta: String in ESCENAS:
		_nombre = ruta.get_file()
		_arbol(ruta)
	_nombre = "pueblo"
	await _pueblo()
	_fin()

func _arbol(ruta: String) -> void:
	var escena := load(ruta) as PackedScene
	_check(escena != null, "Se carga la escena")
	if escena == null:
		return
	var arbol := escena.instantiate() as VillageTree
	_check(arbol != null, "Es un VillageTree")
	if arbol == null:
		return
	root.add_child(arbol)
	var lienzo := arbol.get_node_or_null("Modelo/Lienzo") as MeshInstance3D
	_check(lienzo != null, "Tiene Modelo/Lienzo")
	var mat: ShaderMaterial = null
	if lienzo != null:
		mat = lienzo.get_surface_override_material(0) as ShaderMaterial
	_check(mat != null and mat.shader != null, "El lienzo lleva el material del shader")
	if mat == null or mat.shader == null:
		arbol.free()
		return
	var copa := _imagen(mat, "canopy_texture")
	var tronco := _imagen(mat, "trunk_texture")
	_check(copa != null and tronco != null and copa.get_size() == tronco.get_size(),
		"Copa y tronco se leen y miden lo mismo")
	if copa != null and tronco != null:
		_rectangulo(arbol, lienzo, mat, copa, tronco)
		_margen(mat, copa)
		_destellos(mat, copa)
		_tapa(arbol, mat, copa)
	_fundido(arbol, lienzo)
	_casilla(arbol)
	arbol.free()

func _imagen(mat: ShaderMaterial, nombre: String) -> Image:
	var textura := mat.get_shader_parameter(nombre) as Texture2D
	if textura == null:
		return null
	return Image.load_from_file(ProjectSettings.globalize_path(textura.resource_path))

func _fin() -> void:
	print("RESULTADO ARBOL: %d comprobaciones, %d fallos" % [checks, failures])
	quit(1 if failures else 0)

## Valor de un uniforme: el del material o, si no lo cambia, el de su linea en el
## shader. Con --headless el servidor de render es nulo y no sabe los valores
## por defecto, asi que se leen del codigo.
func _param(mat: ShaderMaterial, nombre: String) -> Variant:
	var valor: Variant = mat.get_shader_parameter(nombre)
	if valor == null:
		var patron := RegEx.create_from_string(
			"uniform\\s+\\w+\\s+" + nombre + "\\s*(?::[^=;]*)?=\\s*([^;]+);")
		var codigo := mat.shader.code
		if codigo.contains("#include"):
			codigo += FileAccess.get_file_as_string(INCLUDE)
		var hallado := patron.search(codigo)
		if hallado != null:
			valor = str_to_var(hallado.get_string(1).strip_edges() \
				.replace("vec2(", "Vector2(").replace("vec3(", "Vector3("))
	if valor == null:
		_check(false, "Se lee el uniforme %s" % nombre)
		valor = 0.0
	return valor

## Caja de lo opaco de una imagen, en texeles.
func _opaco(imagen: Image) -> Rect2i:
	return imagen.get_used_rect()

func _rectangulo(arbol: VillageProp, lienzo: MeshInstance3D, mat: ShaderMaterial,
		copa: Image, tronco: Image) -> void:
	var rmin: Vector2 = _param(mat, "rect_min")
	var rsize: Vector2 = _param(mat, "rect_size")
	var quad := lienzo.mesh as QuadMesh
	_check(quad != null and quad.size.is_equal_approx(rsize * VillageMetrics.TEXEL),
		"El QuadMesh mide rect_size texeles (%s frente a %s)" % [
			quad.size if quad else Vector2.ZERO, rsize * VillageMetrics.TEXEL])
	_check(rmin == rmin.round() and rsize == rsize.round(),
		"El rectangulo cae en texeles enteros")
	_check(int(rsize.x) % 2 == 0,
		"Ancho par: con el centro en la raiz, los bordes caen entre pixeles")

	var pitch := VillageMetrics.DEFAULT_PITCH_DEGREES
	var paso: Vector3 = _param(mat, "pixel_step")
	var esperado := Vector3(VillageMetrics.TEXEL,
		VillageMetrics.TEXEL * VillageMetrics.sprite_scale_y(pitch),
		VillageMetrics.TEXEL * VillageMetrics.cell_depth(pitch))
	_check(paso.is_equal_approx(esperado),
		"pixel_step es el de VillageMetrics a %d grados" % int(pitch))

	# Fila del suelo: la de debajo del ultimo texel del tronco.
	var suelo := _opaco(tronco).end.y
	_check(int(rmin.y + rsize.y) == suelo,
		"El rectangulo acaba en la fila del suelo (%d)" % suelo)
	# Pie del tronco: la raiz (centro del rectangulo) cae dentro de lo que el
	# tronco apoya en las ultimas filas.
	var centro := rmin.x + rsize.x * 0.5
	var pie := Rect2i()
	for y in range(suelo - 8, suelo):
		for x in tronco.get_width():
			if tronco.get_pixel(x, y).a > 0.5:
				pie = Rect2i(x, y, 1, 1) if pie.size == Vector2i.ZERO \
					else pie.merge(Rect2i(x, y, 1, 1))
	_check(centro > pie.position.x + 4 and centro < pie.end.x - 4,
		"La raiz cae bajo el pie del tronco (%.1f en %d..%d)" % [centro, pie.position.x, pie.end.x])

	# Colocado por VillageProp, el lienzo apoya en el suelo y centrado en la raiz.
	var caja := lienzo.global_transform * lienzo.get_aabb()
	_check(absf(caja.position.y) < 0.0001, "El lienzo apoya en y = 0")
	_check(absf(caja.get_center().x - arbol.global_position.x) < 0.0001,
		"El lienzo esta centrado en la raiz")
	var alto := rsize.y * paso.y
	_check(absf(caja.size.y - alto) < 0.0001,
		"El lienzo mide rect_size.y pixeles de alto en pantalla")

	var top: float = _param(mat, "top_row")
	_check(int(top) == _opaco(copa).position.y, "top_row es la punta de la copa")

## Lo mas que puede viajar la copa con los valores del material, en texeles. Es
## la cota de fragment(): flexion (inclinacion + oscilacion de dos senos, con
## viento entero) mas agitacion (ruido de -1 a 1 con todo a favor, por
## rustle_axes).
func _viaje_maximo(mat: ShaderMaterial) -> Vector2:
	var fuerza: float = _param(mat, "wind_strength")
	var flexion: float = fuerza * float(_param(mat, "bend_texels")) \
		+ 1.35 * float(_param(mat, "sway_texels")) * (0.3 + 0.7 * fuerza)
	var agita: float = float(_param(mat, "rustle_texels")) * fuerza
	var ejes: Vector2 = _param(mat, "rustle_axes")
	return Vector2(roundf(flexion + agita * ejes.x), roundf(agita * ejes.y))

func _margen(mat: ShaderMaterial, copa: Image) -> void:
	var rmin: Vector2 = _param(mat, "rect_min")
	var rsize: Vector2 = _param(mat, "rect_size")
	var viaje := _viaje_maximo(mat)
	var dibujo := _opaco(copa)
	var izquierda := dibujo.position.x - rmin.x
	var derecha := rmin.x + rsize.x - dibujo.end.x
	var arriba := dibujo.position.y - rmin.y
	_check(izquierda >= viaje.x and derecha >= viaje.x,
		"Cabe lo que viaja la copa a los lados (%d texeles; margen %d y %d)" % [
			int(viaje.x), int(izquierda), int(derecha)])
	_check(arriba >= viaje.y,
		"Cabe lo que viaja la copa hacia arriba (%d; margen %d)" % [int(viaje.y), int(arriba)])

func _destellos(mat: ShaderMaterial, copa: Image) -> void:
	var tonos := {}
	for y in copa.get_height():
		for x in copa.get_width():
			var c := copa.get_pixel(x, y)
			if c.a > 0.5:
				tonos[Vector3i(c.r8, c.g8, c.b8)] = true
	# Cada lit_texel es un texel opaco de la copa, de tonos distintos y de oscuro
	# a claro: el destello solo cambia un color de la copa por otro que ya tiene.
	var vistos := {}
	var previo := -1.0
	var orden := true
	for i in 4:
		var t: Vector2 = _param(mat, "lit_texel_%d" % i)
		var p := Vector2i(t)
		var dentro := Rect2i(Vector2i.ZERO, copa.get_size()).has_point(p)
		var c := copa.get_pixel(p.x, p.y) if dentro else Color(0, 0, 0, 0)
		_check(dentro and c.a > 0.5, "lit_texel_%d es un texel de la copa (%s)" % [i, p])
		vistos[c.to_rgba32()] = true
		orden = orden and c.get_luminance() > previo
		previo = c.get_luminance()
	_check(vistos.size() == 4 and orden, "Los lit_texel son cuatro tonos, de oscuro a claro")
	_check(float(_param(mat, "time_step")) > 0.0, "El tiempo avanza a saltos")
	_check(mat.shader.code.contains("shadows_disabled")
		and VillageTree.SHADER_FUNDIDO.code.contains("shadows_disabled"),
		"El arbol no recibe sombra, tampoco fundido (su propia penumbra lo salpicaba)")

func _casilla(arbol: VillageProp) -> void:
	_check(arbol.huella() == Vector2i.ONE, "Solo el tronco ocupa casilla")
	arbol.rotation.y = PI * 0.5
	_check(arbol.huella() == Vector2i.ONE, "Girado sigue ocupando una casilla")
	arbol.rotation.y = 0.0
	var forma := arbol.get_node_or_null("Colision/Forma") as CollisionShape3D
	var caja := forma.shape as BoxShape3D if forma != null else null
	_check(caja != null, "Tiene caja de colision")
	if caja == null:
		return
	var celda := VillageMetrics.block_scale(VillageMetrics.DEFAULT_PITCH_DEGREES)
	_check(caja.size.x <= celda.x and caja.size.z <= celda.z,
		"La colision abarca solo el tronco, no la copa")
	_check(absf(forma.position.x) < 0.0001 and absf(forma.position.z) < 0.0001,
		"La colision esta centrada en la raiz")

## tapa() con el arbol en el origen: un punto sobre un texel opaco de la copa
## tapa; uno en un hueco (mas ancho que el margen) o fuera del dibujo, no.
func _tapa(arbol: VillageTree, mat: ShaderMaterial, copa: Image) -> void:
	var pitch := VillageMetrics.DEFAULT_PITCH_DEGREES
	var rmin: Vector2 = _param(mat, "rect_min")
	var rsize: Vector2 = _param(mat, "rect_size")
	var raiz := VillageMetrics.screen_point(arbol.global_position, pitch)
	var origen := raiz - Vector2(rmin.x + rsize.x * 0.5, rmin.y + rsize.y)
	var lleno := Vector2i(-1, -1)
	var hueco := Vector2i(-1, -1)
	var m := int(ceilf(arbol.margen_px)) + 1
	for y in range(m, copa.get_height() - m):
		for x in range(m, copa.get_width() - m):
			if lleno.x < 0 and copa.get_pixel(x, y).a > 0.5:
				lleno = Vector2i(x, y)
			if hueco.x < 0 and _vacio(copa, x, y, m) and _dentro(copa, x, y):
				hueco = Vector2i(x, y)
	var punto := Vector2(0.5, 0.5)
	_check(lleno.x >= 0 and arbol.tapa(Rect2(origen + Vector2(lleno) + Vector2(0.25, 0.25),
		punto), pitch), "Tapa donde la copa tiene un texel (%s)" % lleno)
	_check(hueco.x >= 0 and not arbol.tapa(Rect2(origen + Vector2(hueco) + Vector2(0.25, 0.25),
		punto), pitch), "No tapa en un hueco de la copa (%s)" % hueco)
	_check(not arbol.tapa(Rect2(origen + Vector2(copa.get_width() + 20, 0), Vector2(10, 10)),
		pitch), "No tapa fuera del dibujo")

## Sin texeles opacos en m texeles a la redonda.
func _vacio(imagen: Image, x: int, y: int, m: int) -> bool:
	for j in range(y - m, y + m + 1):
		for i in range(x - m, x + m + 1):
			if imagen.get_pixel(i, j).a > 0.5:
				return false
	return true

## Con copa a los dos lados de la fila: un hueco de verdad y no el cielo de fuera.
func _dentro(imagen: Image, x: int, y: int) -> bool:
	var izquierda := false
	var derecha := false
	for i in imagen.get_width():
		if imagen.get_pixel(i, y).a > 0.5:
			if i < x:
				izquierda = true
			elif i > x:
				derecha = true
	return izquierda and derecha

## El fundido enciende la copia translucida, deja el lienzo solo en el mapa de
## sombras y vuelve a como estaba.
func _fundido(arbol: VillageTree, lienzo: MeshInstance3D) -> void:
	var copia := arbol.get_node_or_null("Modelo/Fundido") as MeshInstance3D
	_check(copia != null and not copia.visible, "Hay copia translucida, oculta al empezar")
	if copia == null or lienzo == null:
		return
	var mat := copia.material_override as ShaderMaterial
	_check(mat != null and mat.shader == VillageTree.SHADER_FUNDIDO,
		"La copia usa tree_sway_faded.gdshader")
	if mat == null:
		return
	var original := lienzo.get_surface_override_material(0) as ShaderMaterial
	var iguales := true
	for u in original.shader.get_shader_uniform_list():
		var valor: Variant = original.get_shader_parameter(u["name"])
		if valor != null and mat.get_shader_parameter(u["name"]) != valor:
			iguales = false
	_check(iguales, "La copia lleva los mismos parametros: se mueve igual")
	_check(copia.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"La copia translucida no proyecta sombra")
	arbol.fundir(true, 1.0)
	_check(copia.visible
		and lienzo.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,
		"Fundida: se ve la copia y el lienzo solo da sombra")
	_check(is_equal_approx(float(copia.get_instance_shader_parameter(&"canopy_opacity")),
		arbol.opacidad_al_tapar), "Fundida: la copa queda a opacidad_al_tapar")
	arbol.fundir(false, 1.0)
	_check(not copia.visible
		and lienzo.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
		"Al dejar de tapar vuelve el lienzo opaco")

## En el pueblo: con el personaje detras de la copa se funde; delante, no.
func _pueblo() -> void:
	var pueblo := (load(PUEBLO) as PackedScene).instantiate()
	var arbol := (load(ESCENAS[0]) as PackedScene).instantiate() as VillageTree
	var objetos := pueblo.get_node("Objetos") as Node3D
	objetos.add_child(arbol)
	root.add_child(pueblo)
	arbol.position = arbol.posicion_encajada(Vector3(3.5, 0.0, 0.5))
	var jugador := pueblo.get_node("Player") as Node3D
	var celda := VillageMetrics.block_scale(VillageMetrics.DEFAULT_PITCH_DEGREES)
	# Dos filas por detras: en pantalla queda a media copa, sobre el tronco.
	jugador.global_position = arbol.global_position - Vector3(0.0, 0.0, 2.0 * celda.z)
	for i in 30:
		await process_frame
	_check(arbol.fundido > 0.99,
		"Con el personaje detras, la copa se funde (%.2f)" % arbol.fundido)
	jugador.global_position = arbol.global_position + Vector3(0.0, 0.0, 1.0 * celda.z)
	for i in 30:
		await process_frame
	_check(arbol.fundido < 0.01,
		"Con el personaje delante, la copa vuelve (%.2f)" % arbol.fundido)
	jugador.global_position = arbol.global_position - Vector3(8.0, 0.0, 2.0 * celda.z)
	for i in 30:
		await process_frame
	_check(arbol.fundido < 0.01,
		"Detras pero lejos a un lado, no se funde (%.2f)" % arbol.fundido)
	pueblo.queue_free()
	await process_frame
