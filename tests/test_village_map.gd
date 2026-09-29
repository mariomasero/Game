extends SceneTree

## El pueblo pintado a mano (docs/decisions/013-mapa-autorado-con-gridmap.md):
## que lo que se pinta en los GridMap del editor es lo que sale en el juego.
##
## Pinta por codigo en village.tscn, sin guardar nada, y comprueba el suelo, los
## muros, la colision y los objetos VillageProp. Tambien vigila que village.tscn
## guardada no contenga lo que solo debe existir en ejecucion.
##
##   godot --headless --path . --script tests/test_village_map.gd
##
## En --headless puede salir al final un 'ERROR: Parameter "material" is null'
## de servers/rendering/dummy. Es del servidor de render vacio: con ventana, bajo
## Forward+, la misma prueba no lo da (comprobado el 23 de septiembre de 2026).

const ESCENA := "res://scenes/world/village.tscn"
const LIB_TERRENO := "res://assets/game/tilesets/paint_terrain.meshlib.tres"
const LIB_BLOQUES := "res://assets/game/tilesets/paint_blocks.meshlib.tres"
const LIB_ZONAS := "res://assets/game/tilesets/paint_zones.meshlib.tres"
const BLOQUE_EJEMPLO := "res://scenes/village/props/bloque_cesped.tscn"
const FAROLA := "res://scenes/village/props/farola.tscn"
const VALLA := "res://scenes/village/props/metal_fence.tscn"
const Atlas := preload("res://scripts/domain/ground_atlas.gd")
const VIEWPORT := Vector2(960.0, 540.0)

const TOL := 0.001

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
	_bibliotecas()
	_escena_guardada_limpia()
	await _pueblo_pintado()
	await _objeto()
	await _farola()
	await _valla()
	await _parcela_y_muebles()
	await _objetos_que_flotan()
	await _camara_y_fundido()
	print("RESULTADO PUEBLO: %d comprobaciones, %d fallos" % [checks, failures])
	quit(1 if failures else 0)

func _celda() -> Vector3:
	return VillageMetrics.block_scale(VillageMetrics.DEFAULT_PITCH_DEGREES)

func _item(lib: MeshLibrary, nombre: String) -> int:
	for id in lib.get_item_list():
		if lib.get_item_name(id) == nombre:
			return id
	return -1

func _bibliotecas() -> void:
	var terreno: MeshLibrary = load(LIB_TERRENO)
	_check(terreno != null, "Existe la biblioteca de terreno")
	if terreno == null:
		return
	var nombres: Array[StringName] = []
	for id in terreno.get_item_list():
		nombres.append(StringName(terreno.get_item_name(id)))
	nombres.sort()
	var esperados := Atlas.TERRAIN_IDS.duplicate()
	esperados.append(WaterSurface.ITEM)
	esperados.sort()
	_check(nombres == esperados,
		"Los items de terreno se llaman como TERRAIN_IDS mas el agua (%s)" % str(nombres))
	for id in terreno.get_item_list():
		_check(terreno.get_item_shapes(id).is_empty(),
			"El marcador %s no tiene colision" % terreno.get_item_name(id))

	var bloques: MeshLibrary = load(LIB_BLOQUES)
	_check(bloques != null and not bloques.get_item_list().is_empty(),
		"Existe la biblioteca de bloques y tiene items")
	if bloques == null:
		return
	for id in bloques.get_item_list():
		var nombre := bloques.get_item_name(id)
		var malla := bloques.get_item_mesh(id)
		# BaseMaterial3D los de atlas de PixZels; ShaderMaterial los que leen el
		# relleno por la posicion en el mundo, como la losa de acera.
		var material := malla.surface_get_material(0) if malla != null else null
		_check(material is BaseMaterial3D or material is ShaderMaterial,
			"El bloque %s trae malla y material" % nombre)
		var escala := bloques.get_item_mesh_transform(id).basis.get_scale()
		_check(escala.is_equal_approx(_celda()),
			"El bloque %s lleva horneada la escala de VillageMetrics (%s)" % [nombre, escala])

	var zonas: MeshLibrary = load(LIB_ZONAS)
	_check(zonas != null and _item(zonas, String(PlotLayout.ITEM_PARCELA)) != -1,
		"Existe la biblioteca de zonas con el marcador de parcela")
	if zonas != null:
		for id in zonas.get_item_list():
			_check(zonas.get_item_shapes(id).is_empty(),
				"El marcador %s no tiene colision" % zonas.get_item_name(id))

## Lo construido en ejecucion no tiene owner, pero si alguna vez se colara en el
## .tscn -- por ejemplo, porque alguien le pusiera owner para verlo en el arbol --
## el juego lo duplicaria encima al arrancar.
func _escena_guardada_limpia() -> void:
	var texto := FileAccess.get_file_as_string(ESCENA)
	for nombre in ["Ground", "GroundBody", "WallBodies", "WallsShadow", "WallsSolid",
			"WallsFaded", "Water", "WaterBodies"]:
		_check(not texto.contains('name="%s"' % nombre),
			"village.tscn no guarda el nodo de ejecucion %s" % nombre)

func _pueblo_pintado() -> void:
	var pueblo := (load(ESCENA) as PackedScene).instantiate()
	var terreno := pueblo.get_node("Terreno") as GridMap
	var bloques := pueblo.get_node("Bloques") as GridMap
	var tierra := _item(terreno.mesh_library, "dirt")
	var adoquin := _item(terreno.mesh_library, "cobblestone")
	var piedra := _item(bloques.mesh_library, "cobblestone")
	var barro := _item(bloques.mesh_library, "dirt")

	# Un camino de tierra de 4x4 con un adoquin dentro, una casilla muy lejos
	# para la extension, un item que no existe y una casilla fuera de planta.
	for j in range(0, 4):
		for i in range(-3, 1):
			terreno.set_cell_item(Vector3i(i, 0, j), tierra)
	terreno.set_cell_item(Vector3i(-2, 0, 1), adoquin)
	terreno.set_cell_item(Vector3i(40, 0, 0), tierra)
	terreno.set_cell_item(Vector3i(6, 0, -3), 99)
	terreno.set_cell_item(Vector3i(7, 1, -3), tierra)

	# Una columna de dos bloques de piedra, uno al lado y uno de tierra.
	bloques.set_cell_item(Vector3i(5, 0, 5), piedra)
	bloques.set_cell_item(Vector3i(5, 1, 5), piedra)
	bloques.set_cell_item(Vector3i(6, 0, 5), piedra)
	bloques.set_cell_item(Vector3i(8, 0, 5), barro)

	root.add_child(pueblo)
	await physics_frame
	await physics_frame

	_check(pueblo.call("_terrain_at", -3, 0) == Atlas.Terrain.DIRT,
		"Una casilla pintada de tierra es tierra")
	_check(pueblo.call("_terrain_at", -2, 1) == Atlas.Terrain.COBBLESTONE,
		"Una casilla pintada de adoquin es adoquin")
	_check(pueblo.call("_terrain_at", 10, 10) == Atlas.Terrain.GRASS,
		"Lo que no se pinta es hierba")
	_check(pueblo.call("_terrain_at", 6, -3) == Atlas.Terrain.GRASS,
		"Un item sin terreno conocido cuenta como hierba")
	_check(pueblo.call("_terrain_at", 7, -3) == Atlas.Terrain.GRASS,
		"Lo pintado fuera de la planta 0 no cuenta")

	var rango: Rect2i = pueblo.call("_ground_cell_range")
	_check(rango.has_point(Vector2i(40 + 2, 0)),
		"El suelo llega a lo pintado lejos, con su margen (%s)" % str(rango))

	var suelo := pueblo.get_node_or_null("Ground") as MeshInstance3D
	_check(suelo != null, "Se construye el suelo en ejecucion")

	_check(not terreno.visible and not bloques.visible,
		"Los GridMap del editor se ocultan en el juego")
	_check(terreno.collision_layer == 0 and bloques.collision_layer == 0,
		"Los GridMap del editor no chocan en el juego")

	var instancias := 0
	var tipos := 0
	for hijo in pueblo.get_children():
		if hijo is MultiMeshInstance3D and String(hijo.name).begins_with("WallsSolid"):
			instancias += (hijo as MultiMeshInstance3D).multimesh.instance_count
			tipos += 1
	_check(instancias == 4, "Hay un bloque de muro por casilla pintada (%d)" % instancias)
	_check(tipos == 2, "Un trio de muros por material (%d)" % tipos)
	var cuerpos := pueblo.get_node_or_null("WallBodies")
	_check(cuerpos != null and cuerpos.get_child_count() == 4,
		"Cada bloque tiene su caja de colision")

	# Del estado del muro y no de la MultiMesh: el servidor de render vacio de
	# --headless no guarda las transformaciones de instancia.
	var celda := _celda()
	var centros: Array[Vector3] = pueblo.get("_wall_centers")
	var tipos_muro: Array[Dictionary] = pueblo.get("_wall_kinds")
	var esperado: Vector3 = pueblo.call("_cell_center", 5, 5, 0)
	var local: Transform3D = tipos_muro[0]["local"]
	_check(centros[0].is_equal_approx(esperado)
		and local.basis.get_scale().is_equal_approx(celda),
		"El bloque sale donde lo pone el GridMap y a escala (%s)" % str(centros[0]))
	_check(esperado.is_equal_approx(bloques.map_to_local(Vector3i(5, 0, 5))),
		"El centro de celda del muro coincide con el del GridMap")

	# La columna de dos bloques tiene su techo a dos alturas de celda.
	var estado := (pueblo as Node3D).get_world_3d().direct_space_state
	var arriba := Vector3(5.5 * celda.x, 10.0, 5.5 * celda.z)
	var golpe := estado.intersect_ray(PhysicsRayQueryParameters3D.create(
		arriba, arriba + Vector3.DOWN * 20.0))
	_check(not golpe.is_empty() and absf(golpe["position"].y - 2.0 * celda.y) < TOL,
		"Se choca con lo alto de una columna de dos bloques")

	pueblo.queue_free()
	await process_frame

func _objeto() -> void:
	var celda := _celda()
	var objeto := (load(BLOQUE_EJEMPLO) as PackedScene).instantiate() as Node3D
	objeto.position = Vector3(3.5, 0.0, 2.0 * celda.z)
	root.add_child(objeto)
	await physics_frame
	await physics_frame

	var modelo := objeto.get_node("Modelo") as Node3D
	_check(modelo.basis.get_scale().is_equal_approx(celda),
		"El Modelo recibe la escala de VillageMetrics (%s)" % modelo.basis.get_scale())
	var caja: AABB = objeto.get("caja")
	_check(caja.size.is_equal_approx(celda) and absf(caja.position.y) < TOL,
		"El modelo mide una celda y apoya en el suelo (%s)" % str(caja))
	var forma := objeto.get_node("Colision/Forma") as CollisionShape3D
	_check((forma.shape as BoxShape3D).size.is_equal_approx(celda),
		"La colision automatica cubre el modelo")

	var estado := objeto.get_world_3d().direct_space_state
	var arriba := objeto.position + Vector3(0.0, 10.0, 0.0)
	var golpe := estado.intersect_ray(PhysicsRayQueryParameters3D.create(
		arriba, arriba + Vector3.DOWN * 20.0))
	_check(not golpe.is_empty() and absf(golpe["position"].y - celda.y) < TOL,
		"El objeto de ejemplo tiene colision")

	var encajada: Vector3 = objeto.call("posicion_encajada", Vector3(3.2, 0.4, 2.3 * celda.z))
	_check(encajada.is_equal_approx(Vector3(3.5, 0.0, 2.5 * celda.z)),
		"Un objeto de una celda encaja en el centro de la celda (%s)" % encajada)
	objeto.set("anclaje", 2)
	encajada = objeto.call("posicion_encajada", Vector3(3.2, 1.0, 2.3 * celda.z))
	_check(encajada.is_equal_approx(Vector3(3.0, celda.y, 2.0 * celda.z)),
		"Con anclaje en esquina encaja en la esquina y en la planta (%s)" % encajada)

	# Girado 90 grados, el estiramiento sigue en los ejes del mundo.
	objeto.rotation = Vector3(0.0, PI * 0.5, 0.0)
	objeto.call("_reajustar")
	var mundo := modelo.global_basis
	var ancho := (mundo * Vector3(1, 0, 0)).length()
	_check(absf(mundo.get_scale().y - celda.y) < TOL
		and (mundo.inverse() * Basis.from_scale(celda) * objeto.basis)
			.is_equal_approx(Basis.IDENTITY),
		"Girado 90 grados el pixel sigue cuadrado (ancho %.4f)" % ancho)

	objeto.queue_free()
	await process_frame

## La farola sobresale hacia +X por el brazo: con centrar_por_la_base el poste
## queda en el centro de su casilla, no el centro de la caja entera.
func _farola() -> void:
	var celda := _celda()
	var farola := (load(FAROLA) as PackedScene).instantiate() as Node3D
	root.add_child(farola)
	await process_frame

	var caja: AABB = farola.get("caja")
	# 48 texeles de alto a 16 por unidad (assets/source/props/street_lamp/LEEME.md).
	_check(absf(caja.size.y - 3.0 * celda.y) < TOL and absf(caja.position.y) < TOL,
		"La farola mide tres celdas de alto y apoya en el suelo (%s)" % str(caja))
	var base: AABB = farola.call("_base_de", farola, Transform3D.IDENTITY, 0.0)
	_check(absf(base.get_center().x) < TOL and absf(base.get_center().z) < TOL
		and absf(base.size.x - 0.625) < TOL,
		"La base de la farola queda centrada sobre la raiz (%s)" % str(base))
	_check(caja.end.x > 0.8 and absf(caja.position.x + 0.3125) < TOL,
		"La caja sobresale hacia el brazo en vez de centrarse (%s)" % str(caja))
	_check(farola.call("huella") == Vector2i.ONE, "La farola ocupa una casilla")
	var forma := farola.get_node("Colision/Forma") as CollisionShape3D
	_check(absf((forma.shape as BoxShape3D).size.x - 0.625) < TOL,
		"La colision de la farola es solo la base, no el brazo")

	farola.rotation = Vector3(0.0, PI * 0.5, 0.0)
	farola.call("_reajustar")
	base = farola.call("_base_de", farola, Transform3D.IDENTITY, 0.0)
	_check(absf(base.get_center().x) < TOL and absf(base.get_center().z) < TOL,
		"Girada 90 grados la base sigue centrada (%s)" % str(base))

	farola.queue_free()
	await process_frame

## La valla de hierro (scenes/village/props/village_fence.gd): suelta es solo el
## poste, de 32 texeles de alto en una casilla; con vecinas a los lados le salen
## tramos que llegan al borde de la casilla y se juntan con los de la vecina.
func _valla() -> void:
	var celda := _celda()
	var padre := Node3D.new()
	root.add_child(padre)
	var escena: PackedScene = load(VALLA)
	var a := _poner_valla(padre, escena, Vector2i(0, 0))
	await process_frame

	var caja: AABB = a.get("caja")
	_check(absf(caja.size.y - celda.y) < TOL and absf(caja.position.y) < TOL
		and absf(caja.get_center().x) < TOL and absf(caja.get_center().z) < TOL,
		"El poste mide 32 texeles de alto, centrado y en el suelo (%s)" % str(caja))
	_check(a.call("huella") == Vector2i.ONE, "La valla ocupa una casilla")
	_check(_lados_unidos(a) == [false, false, false, false],
		"Una valla suelta es solo el poste")

	var b := _poner_valla(padre, escena, Vector2i(1, 0))
	await process_frame
	_check(_lados_unidos(a) == [true, false, false, false]
		and _lados_unidos(b) == [false, false, true, false],
		"Dos vallas juntas en X sacan un tramo cada una hacia la otra")
	var tramo_a: MeshInstance3D = (a.get("tramos") as Array)[0]
	var tramo_b: MeshInstance3D = (b.get("tramos") as Array)[2]
	var fin_a := (tramo_a.global_transform * tramo_a.get_aabb()).end.x
	var inicio_b := (tramo_b.global_transform * tramo_b.get_aabb()).position.x
	_check(absf(fin_a - celda.x) < TOL and absf(inicio_b - celda.x) < TOL,
		"Los dos tramos se tocan justo en el borde de la casilla (%.4f, %.4f)"
			% [fin_a, inicio_b])
	var choque := (a.get("choques") as Array)[0] as CollisionShape3D
	var lado := (choque.shape as BoxShape3D).size
	var caja_choque := choque.global_transform * AABB(-0.5 * lado, lado)
	_check(not choque.disabled and absf(caja_choque.end.x - celda.x) < TOL,
		"El tramo choca hasta el borde (%s)" % str(caja_choque))

	var c := _poner_valla(padre, escena, Vector2i(0, 1))
	var diagonal := _poner_valla(padre, escena, Vector2i(1, 1))
	await process_frame
	_check(_lados_unidos(a) == [true, true, false, false],
		"Una tercera al sur saca el tramo hacia +Z")
	_check(_lados_unidos(diagonal) == [false, false, true, true],
		"En diagonal no se unen: la de (1, 1) se une a sus vecinas en X y Z")

	b.free()
	await process_frame
	_check(_lados_unidos(a) == [false, true, false, false],
		"Al quitar la vecina se quita su tramo")

	# Girada, cada tramo sigue saliendo hacia la casilla de su vecina.
	a.rotation = Vector3(0.0, PI * 0.5, 0.0)
	a.call("_reajustar")
	a.call("unir")
	var abiertos := 0
	for t: MeshInstance3D in a.get("tramos"):
		if t.visible:
			abiertos += 1
			var centro := (t.global_transform * t.get_aabb()).get_center()
			_check(centro.z > a.position.z and absf(centro.x - a.position.x) < TOL,
				"Girada 90 grados el tramo sigue hacia la vecina del sur (%s)" % str(centro))
	_check(abiertos == 1, "Girada, un solo tramo abierto (%d)" % abiertos)

	padre.free()
	await process_frame

func _poner_valla(padre: Node3D, escena: PackedScene, c: Vector2i) -> Node3D:
	var celda := _celda()
	var valla := escena.instantiate() as Node3D
	valla.position = Vector3((c.x + 0.5) * celda.x, 0.0, (c.y + 0.5) * celda.z)
	padre.add_child(valla)
	return valla

func _lados_unidos(valla: Node3D) -> Array:
	var salida := []
	for t: MeshInstance3D in valla.get("tramos"):
		salida.append(t.visible)
	return salida

## Parcela pintada lejos del origen, con un bloque dentro, y tres muebles de
## ejemplo: uno bien puesto, otro encima del primero y otro fuera.
func _parcela_y_muebles() -> void:
	var celda := _celda()
	var pueblo := (load(ESCENA) as PackedScene).instantiate()
	var parcela := pueblo.get_node("Parcela") as GridMap
	var bloques := pueblo.get_node("Bloques") as GridMap
	var marca := _item(parcela.mesh_library, String(PlotLayout.ITEM_PARCELA))
	for j in range(0, 4):
		for i in range(30, 36):
			parcela.set_cell_item(Vector3i(i, 0, j), marca)
	parcela.set_cell_item(Vector3i(31, 1, 5), marca)
	bloques.set_cell_item(Vector3i(34, 0, 1), _item(bloques.mesh_library, "cobblestone"))

	var muebles := pueblo.get_node("Muebles")
	var escena: PackedScene = load(BLOQUE_EJEMPLO)
	var sitios := {
		"Bueno": Vector3(31.5 * celda.x, 0.0, 1.5 * celda.z),
		"Encima": Vector3(31.5 * celda.x, 0.0, 1.5 * celda.z),
		"Fuera": Vector3(40.5 * celda.x, 0.0, 1.5 * celda.z),
	}
	for nombre: String in sitios:
		var mueble := escena.instantiate() as Node3D
		mueble.name = nombre
		mueble.position = sitios[nombre]
		muebles.add_child(mueble)

	root.add_child(pueblo)
	await physics_frame

	_check(not parcela.visible and parcela.collision_layer == 0,
		"El GridMap de la parcela se oculta y no choca en el juego")
	var layout: PlotLayout = pueblo.get("layout")
	_check(layout.permitidas.size() == 24,
		"Se leen las 24 casillas de la parcela y no la de la planta 1 (%d)" % layout.permitidas.size())
	_check(layout.bloqueadas.has(Vector2i(34, 1)),
		"Un bloque pintado dentro de la parcela la bloquea")
	var ids := layout.ids()
	_check(ids.size() == 1 and layout.colocacion(ids[0])["origen"] == Vector2i(31, 1)
		and (layout.colocacion(ids[0])["def"] as PlaceableDefinition).id == &"bloque_cesped",
		"El mueble bien puesto se registra en su casilla")

	var problemas: PackedStringArray = pueblo.get("_problemas_muebles")
	var texto := "\n".join(problemas)
	_check(problemas.size() == 2 and texto.contains("Encima") and texto.contains("solapa")
		and texto.contains("Fuera") and texto.contains("parcela"),
		"El mueble solapado y el de fuera se avisan (%s)" % str(problemas))
	var avisos: PackedStringArray = pueblo.call("_get_configuration_warnings")
	_check(avisos.size() == 2,
		"Los avisos de los muebles salen en el nodo Pueblo (%s)" % str(avisos))

	var bueno := muebles.get_node("Bueno") as Node3D
	_check((bueno.call("posicion_encajada", bueno.position) as Vector3)
		.is_equal_approx(bueno.position),
		"La casilla de PlotLayout y el encaje de VillageProp coinciden")
	var rango: Rect2i = pueblo.call("_ground_cell_range")
	_check(rango.encloses(Rect2i(30, 0, 6, 4)),
		"El suelo cubre la parcela aunque no se haya pintado terreno (%s)" % str(rango))

	pueblo.queue_free()
	await process_frame

## Un objeto en el aire se ve en el juego en otro sitio que en el editor (la
## camara del juego esta inclinada y la del editor no): se avisa. Encima de un
## bloque no flota.
func _objetos_que_flotan() -> void:
	var celda := _celda()
	var pueblo := (load(ESCENA) as PackedScene).instantiate()
	var bloques := pueblo.get_node("Bloques") as GridMap
	bloques.set_cell_item(Vector3i(40, 0, 20), _item(bloques.mesh_library, "cobblestone"))
	bloques.set_cell_item(Vector3i(46, 0, 20), _item(bloques.mesh_library, "stone_slab"))
	var objetos := pueblo.get_node("Objetos")
	var escena: PackedScene = load(BLOQUE_EJEMPLO)
	var sitios := {
		"EnElSuelo": Vector3(38.5 * celda.x, 0.0, 20.5 * celda.z),
		"SobreBloque": Vector3(40.5 * celda.x, celda.y, 20.5 * celda.z),
		"DosPlantas": Vector3(42.5 * celda.x, 2.0 * celda.y, 20.5 * celda.z),
		"UnPoco": Vector3(44.5 * celda.x, 0.3, 20.5 * celda.z),
		# La losa mide 8 texeles: un cuarto de planta.
		"SobreLosa": Vector3(46.5 * celda.x, 0.25 * celda.y, 20.5 * celda.z),
	}
	for nombre: String in sitios:
		var objeto := escena.instantiate() as Node3D
		objeto.name = nombre
		objeto.position = sitios[nombre]
		objetos.add_child(objeto)

	root.add_child(pueblo)
	await physics_frame

	var problemas: PackedStringArray = pueblo.get("_problemas_objetos")
	var texto := "
".join(problemas)
	_check(problemas.size() == 2 and texto.contains("DosPlantas") and texto.contains("UnPoco"),
		"Se avisa de los objetos en el aire y no del que esta en el suelo, sobre un bloque " +
		"o sobre una losa, " +
		"ni de ninguno del pueblo guardado (%s)" % str(problemas))
	var avisos: PackedStringArray = pueblo.call("_get_configuration_warnings")
	_check(Array(avisos).filter(func(a: String) -> bool: return a.begins_with("Objetos:")).size() == 2,
		"Los objetos en el aire salen en los avisos del nodo Pueblo (%s)" % str(avisos))

	pueblo.queue_free()
	await process_frame

## Camara que sigue al personaje por un mapa mas grande que la pantalla, y muros
## que se funden lejos del origen.
func _camara_y_fundido() -> void:
	var celda := _celda()
	var pueblo := (load(ESCENA) as PackedScene).instantiate()
	var terreno := pueblo.get_node("Terreno") as GridMap
	var bloques := pueblo.get_node("Bloques") as GridMap
	var tierra := _item(terreno.mesh_library, "dirt")
	terreno.set_cell_item(Vector3i(-40, 0, -25), tierra)
	terreno.set_cell_item(Vector3i(40, 0, 25), tierra)
	var piedra := _item(bloques.mesh_library, "cobblestone")
	bloques.set_cell_item(Vector3i(30, 0, 12), piedra)
	bloques.set_cell_item(Vector3i(30, 1, 12), piedra)
	bloques.set_cell_item(Vector3i(-30, 0, -20), piedra)
	var player := pueblo.get_node("Player") as Node3D
	# Justo detras del muro: una casilla al norte de el.
	player.position = Vector3(30.5 * celda.x, 0.0, 11.5 * celda.z)
	root.add_child(pueblo)
	await physics_frame

	var camara := pueblo.get_node("Camera3D") as Camera3D
	var pitch: float = pueblo.get("pitch_degrees")
	var puntos: Array[Vector3] = [Vector3.ZERO, Vector3(3.2, 1.5, -2.1),
		Vector3(-7.0, 0.3, 4.4), Vector3(31.0, 2.0, 12.0)]

	# Del sitio que sea, la camara no se sale del suelo y cae en pixel entero.
	var teselas: Rect2i = pueblo.call("_ground_tile_range")
	var esquina_min := Vector3((teselas.position.x - 0.5) * celda.x, 0.0,
		(teselas.position.y - 0.5) * celda.z)
	var esquina_max := Vector3((teselas.end.x - 0.5) * celda.x, 0.0,
		(teselas.end.y - 0.5) * celda.z)
	var coincide := true
	var enteros := true
	for sitio: Vector3 in [Vector3(0.0, 0.0, 3.0), Vector3(13.37, 0.0, -7.71),
			Vector3(-1000.0, 0.0, -1000.0), Vector3(1000.0, 0.0, 1000.0)]:
		player.position = sitio
		pueblo.call("_move_camera")
		for p in puntos:
			var real := camara.unproject_position(p) - camara.unproject_position(puntos[0])
			var lineal := VillageMetrics.screen_point(p, pitch) \
				- VillageMetrics.screen_point(puntos[0], pitch)
			if (real - lineal).length() > 0.01:
				coincide = false
		var origen := camara.unproject_position(Vector3.ZERO)
		if absf(origen.x - roundf(origen.x)) > 0.01 or absf(origen.y - roundf(origen.y)) > 0.01:
			enteros = false
		if sitio.x < -100.0:
			var borde := camara.unproject_position(esquina_min)
			_check(borde.x <= 0.01 and borde.y <= 0.01,
				"En la esquina noroeste del mapa la camara no ensena fondo (%s)" % borde)
		if sitio.x > 100.0:
			var borde := camara.unproject_position(esquina_max)
			_check(borde.x >= VIEWPORT.x - 0.01 and borde.y >= VIEWPORT.y - 0.01,
				"En la esquina sureste del mapa la camara no ensena fondo (%s)" % borde)
	_check(coincide,
		"screen_point da lo mismo que la camara, este donde este la camara")
	_check(enteros,
		"La camara se mueve en pixeles enteros: el mundo no tiembla al seguir")
	_check(is_equal_approx(pueblo.call("_frenar", 5.0, 10.0, 0.0), 5.0),
		"Si el mapa es mas estrecho que la pantalla, la camara se queda en su centro")

	# Vuelta detras del muro, lejos del origen: la camara le sigue y el muro que
	# tapa al personaje se funde; el que esta lejos, no.
	player.position = Vector3(30.5 * celda.x, 0.0, 11.5 * celda.z)
	for _i in 20:
		await process_frame
	_check(camara.position.x > 20.0, "La camara ha seguido al personaje (%s)" % camara.position)
	var centros: Array[Vector3] = pueblo.get("_wall_centers")
	var fundido: PackedFloat32Array = pueblo.get("_wall_fade")
	var delante := true
	var lejos := true
	for i in centros.size():
		var columna := Vector2i(floori(centros[i].x / celda.x), floori(centros[i].z / celda.z))
		if columna == Vector2i(30, 12) and fundido[i] <= 0.0:
			delante = false
		if columna == Vector2i(-30, -20) and fundido[i] > 0.0:
			lejos = false
	_check(delante, "El muro delante del personaje se funde lejos del origen (%s)" % str(fundido))
	_check(lejos, "Un muro lejano no se funde")

	pueblo.queue_free()
	await process_frame
