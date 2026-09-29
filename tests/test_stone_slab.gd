extends SceneTree

## La losa de acera: un bloque de 8 texeles de alto, un cuarto de celda, que se
## pinta en el GridMap Bloques como cualquier otro y se sube andando.
##
## Comprueba la biblioteca, que choca y tapa a su altura y no a la de una celda,
## que su cara superior sube 8 px justos en pantalla, que no crece hierba encima
## y que el personaje sube el bordillo, lo cruza y vuelve a bajar, mientras un
## bloque entero le sigue parando. La fisica funciona con --headless; el dibujo
## del relleno lo hace el shader y hay que mirarlo con ventana.
##
##   godot --headless --path . --script tests/test_stone_slab.gd

const ESCENA := "res://scenes/world/village.tscn"
const LIB_BLOQUES := "res://assets/game/tilesets/paint_blocks.meshlib.tres"
const SHADER := "res://assets/game/shaders/block_world_fill.gdshader"
const ALTO_TEXELES := 8

const TOL := 0.001

## Fila de losas de este a oeste y un bloque entero de adoquin en la misma fila,
## mas al este. Muy lejos de lo pintado en village.tscn, que cambia al pintar:
## una casilla de agua tiene colision de una celda de alto y taparia la losa.
const FILA_Z := -60
const FILA_X := Vector2i(80, 87)
const MURO_X := 91

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
	else:
		print("PASS: " + message)

func _run() -> void:
	_biblioteca()
	await _en_el_pueblo()
	print("RESULTADO LOSA: %d comprobaciones, %d fallos" % [checks, failures])
	quit(1 if failures else 0)

func _celda() -> Vector3:
	return VillageMetrics.block_scale(VillageMetrics.DEFAULT_PITCH_DEGREES)

func _alto() -> float:
	return _celda().y * float(ALTO_TEXELES) / float(VillageMetrics.TEXELS_PER_CELL)

func _item(lib: MeshLibrary, nombre: String) -> int:
	for id in lib.get_item_list():
		if lib.get_item_name(id) == nombre:
			return id
	return -1

func _biblioteca() -> void:
	var lib: MeshLibrary = load(LIB_BLOQUES)
	var id := _item(lib, "stone_slab")
	_check(id != -1, "La biblioteca de bloques tiene stone_slab")
	if id == -1:
		return
	_check(id == Array(lib.get_item_list()).max(),
		"stone_slab es el ultimo item: no le quita el id a ningun bloque ya pintado")
	var malla := lib.get_item_mesh(id)
	var material := malla.surface_get_material(0) as ShaderMaterial
	_check(material != null and material.shader != null
		and material.shader.resource_path == SHADER,
		"La losa usa block_world_fill.gdshader")
	if material != null:
		var arriba := material.get_shader_parameter(&"top_fill") as Texture2D
		var canto := material.get_shader_parameter(&"side_fill") as Texture2D
		_check(arriba != null and arriba.get_size() == Vector2(128, 128),
			"La cara superior es el relleno de 128x128")
		_check(canto != null and canto.get_size() == Vector2(128, ALTO_TEXELES),
			"El canto mide 128 de ancho y lo mismo de alto que la losa")

	var caja: AABB = lib.get_item_mesh_transform(id) * malla.get_aabb()
	var celda := _celda()
	_check(absf(caja.size.y - _alto()) < TOL,
		"La losa mide 8 texeles de alto en mundo (%.4f)" % caja.size.y)
	_check(caja.size.x > celda.x - TOL and caja.size.z > celda.z - TOL,
		"La losa ocupa la planta entera de la celda (%s)" % str(caja.size))
	_check(absf(caja.position.y + celda.y * 0.5) < TOL,
		"La losa apoya en el suelo de su casilla, no flota en medio")

	# Lo que se ve: la cara vertical mide 8 px y la superior 32, y subir la losa
	# desplaza su cara superior 8 px enteros, asi que cae texel a pixel.
	var pitch := VillageMetrics.DEFAULT_PITCH_DEGREES
	var subida := VillageMetrics.screen_point(Vector3(0.0, _alto(), 0.0), pitch) \
		- VillageMetrics.screen_point(Vector3.ZERO, pitch)
	_check(absf(subida.y + ALTO_TEXELES) < TOL and absf(subida.x) < TOL,
		"La cara superior de la losa sube 8 px exactos en pantalla (%s)" % subida)

func _en_el_pueblo() -> void:
	var celda := _celda()
	var pueblo := (load(ESCENA) as PackedScene).instantiate() as Node3D
	var bloques := pueblo.get_node("Bloques") as GridMap
	var losa := _item(bloques.mesh_library, "stone_slab")
	var piedra := _item(bloques.mesh_library, "cobblestone")
	for i in range(FILA_X.x, FILA_X.y + 1):
		bloques.set_cell_item(Vector3i(i, 0, FILA_Z), losa)
	bloques.set_cell_item(Vector3i(MURO_X, 0, FILA_Z), piedra)
	# El suelo solo llega a dos casillas de lo pintado; con esta hay suelo de
	# sobra al norte, donde acaba el paseo.
	var terreno := pueblo.get_node("Terreno") as GridMap
	terreno.set_cell_item(Vector3i(FILA_X.x, 0, FILA_Z - 10), _item(terreno.mesh_library, "grass"))
	var jugador := pueblo.get_node("Player") as CharacterBody3D
	# Dos casillas al sur de la fila, en medio de ella.
	var medio := (FILA_X.x + FILA_X.y) / 2
	jugador.position = Vector3((medio + 0.5) * celda.x, 0.0, (FILA_Z + 2.5) * celda.z)
	root.add_child(pueblo)
	await physics_frame
	await physics_frame

	# Colision a la altura de la losa, no de una celda.
	var estado := pueblo.get_world_3d().direct_space_state
	var arriba := Vector3((FILA_X.x + 0.5) * celda.x, 10.0, (FILA_Z + 0.5) * celda.z)
	var golpe := estado.intersect_ray(PhysicsRayQueryParameters3D.create(
		arriba, arriba + Vector3.DOWN * 20.0))
	_check(not golpe.is_empty() and absf(golpe["position"].y - _alto()) < TOL,
		"Se choca con lo alto de la losa, a 8 texeles (%s)" % str(golpe.get("position")))

	# Lo que tapa en pantalla es su caja: 32 px de ancho y 32 + 8 de alto.
	var rects: Array[Rect2] = pueblo.get("_wall_rects")
	var centros: Array[Vector3] = pueblo.get("_wall_centers")
	var rect_losa := Rect2()
	for i in centros.size():
		if floori(centros[i].x / celda.x) == FILA_X.x:
			rect_losa = rects[i]
	_check(rect_losa.size.is_equal_approx(Vector2(32.0, 32.0 + ALTO_TEXELES)),
		"La losa tapa en pantalla lo que mide: 32x40 px (%s)" % str(rect_losa.size))

	var hierba: Dictionary = pueblo.call("grass_cells")
	_check(not hierba.has(Vector2i(FILA_X.x, FILA_Z)), "No crece hierba sobre la losa")

	await _cruzar_la_acera(jugador, celda)
	await _muro_para(jugador, celda)

	pueblo.queue_free()
	await process_frame

## Andando al norte: sube la losa, la cruza por encima y baja al otro lado.
func _cruzar_la_acera(jugador: CharacterBody3D, celda: Vector3) -> void:
	var z_inicial := jugador.global_position.z
	var alto := _alto()
	var y_max := 0.0
	var encima := 0
	var en_el_aire := 0
	Input.action_press(&"move_up")
	for _paso in 180:
		await physics_frame
		var y := jugador.global_position.y
		y_max = maxf(y_max, y)
		if absf(y - alto) < 0.02:
			encima += 1
		if not jugador.is_on_floor():
			en_el_aire += 1
	Input.action_release(&"move_up")
	await physics_frame
	var recorrido := z_inicial - jugador.global_position.z
	_check(recorrido > 4.0 * celda.z,
		"El personaje cruza la acera hacia el norte (%.2f unidades)" % recorrido)
	_check(encima > 0 and y_max < alto + 0.02,
		"Anda por encima de la losa, a su altura (y maxima %.4f, %d fotogramas encima)" % [
			y_max, encima])
	_check(absf(jugador.global_position.y) < 0.02,
		"Al otro lado vuelve a bajar al suelo (y %.4f)" % jugador.global_position.y)
	_check(en_el_aire <= 2,
		"Sube y baja el bordillo sin quedarse flotando (%d fotogramas en el aire)" % en_el_aire)

## Un bloque entero sigue siendo un muro: se choca y no se sube.
func _muro_para(jugador: CharacterBody3D, celda: Vector3) -> void:
	jugador.global_position = Vector3((MURO_X + 0.5) * celda.x, 0.0, (FILA_Z + 2.5) * celda.z)
	jugador.velocity = Vector3.ZERO
	await physics_frame
	Input.action_press(&"move_up")
	var y_max := 0.0
	for _paso in 120:
		await physics_frame
		y_max = maxf(y_max, jugador.global_position.y)
	Input.action_release(&"move_up")
	var muro_sur := (FILA_Z + 1) * celda.z
	_check(jugador.global_position.z > muro_sur,
		"Un bloque entero para al personaje (z %.3f, cara sur %.3f)" % [
			jugador.global_position.z, muro_sur])
	_check(y_max < 0.02, "Y no lo sube (y maxima %.4f)" % y_max)
