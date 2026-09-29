extends SceneTree

## El agua (WaterSurface): que el suelo cede a la orilla las teselas que tocan
## agua, que la orilla sale redondeada y empalma entre teselas, que la lamina y
## la orilla van a pixel exacto, que no se puede entrar andando y que el pueblo
## lee el agua pintada en Terreno.
##
##   godot --headless --path . --script tests/test_water.gd
##
## Como test_village_map, en --headless puede terminar con un 'ERROR: Parameter
## "material" is null' del servidor de render vacio.

const SALA := "res://scenes/world/test_room.tscn"
const PUEBLO := "res://scenes/world/village.tscn"
const SUELO := "res://assets/game/materials/ground_pixel.tres"
const Atlas := preload("res://scripts/domain/ground_atlas.gd")

## Estanque de la prueba: en medio del camino de tierra de la sala, justo al
## norte de donde aparece el personaje (z = 3, celda j = 2).
const ESTANQUE := Rect2i(-1, -1, 3, 2)

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
	var sala: Node3D = (load(SALA) as PackedScene).instantiate()
	sala.set("water_patches", [ESTANQUE] as Array[Rect2i])
	root.add_child(sala)
	await physics_frame
	await physics_frame

	_esquinas_secas(sala)
	_hueco_en_el_suelo(sala)
	_forma_de_la_orilla()
	_lamina_y_orilla(sala)
	_sin_hierba(sala)
	await _no_se_entra(sala)
	sala.queue_free()
	await process_frame

	await _pueblo()
	print("RESULTADO AGUA: %d comprobaciones, %d fallos" % [checks, failures])
	quit(1 if failures else 0)

func _esquinas_secas(sala: Node3D) -> void:
	var T := Atlas.Terrain
	# Orilla norte recta: las dos de abajo son agua y copian la de su columna.
	var e: PackedInt32Array = sala.call("_dry_corners",
		PackedInt32Array([T.DIRT, T.GRASS, T.GRASS, T.GRASS]),
		Atlas.BIT_SW | Atlas.BIT_SE)
	_check(e == PackedInt32Array([T.DIRT, T.GRASS, T.DIRT, T.GRASS]),
		"Una esquina mojada copia la seca de su columna (%s)" % str(e))
	# Tres mojadas: todas copian la unica seca.
	e = sala.call("_dry_corners",
		PackedInt32Array([T.GRASS, T.GRASS, T.GRASS, T.COBBLESTONE]),
		Atlas.MASK_ALL & ~Atlas.BIT_SE)
	_check(e == PackedInt32Array([T.COBBLESTONE, T.COBBLESTONE, T.COBBLESTONE,
		T.COBBLESTONE]), "Con una sola esquina seca, todas copian esa (%s)" % str(e))

## El suelo pierde entera cada tesela que toca agua (la dibuja la orilla), y
## ninguna otra: no hay agujeros ni solapes.
func _hueco_en_el_suelo(sala: Node3D) -> void:
	var suelo := sala.get_node("Ground") as MeshInstance3D
	var arrays := (suelo.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var agua: Dictionary = sala.call("water_cells")
	_check(agua.size() == ESTANQUE.get_area(),
		"water_cells ve las %d casillas del estanque (%d)" % [ESTANQUE.get_area(), agua.size()])
	var mojadas := WaterSurface.tile_masks(agua)
	# Un estanque de 3x2 toca las teselas de un rectangulo de 4x3.
	var tocadas := (ESTANQUE.size.x + 1) * (ESTANQUE.size.y + 1)
	_check(mojadas.size() == tocadas,
		"El estanque toca %d teselas (%d)" % [tocadas, mojadas.size()])
	var teselas: Rect2i = sala.call("_ground_tile_range")
	var atlas := Vector2(Atlas.atlas_size())
	var area := 0.0
	var mojados := 0
	var descuadrados := 0
	for q in range(0, verts.size(), 4):
		# A y C son esquinas opuestas del quad.
		var a := verts[q]
		var c := verts[q + 2]
		var lado := Vector2(c.x - a.x, c.z - a.z)
		area += lado.x * lado.y
		# La tesela (i, j) va centrada en el vertice (i, j).
		var centro := Vector2(a.x + c.x, a.z + c.z) * 0.5
		if mojadas.has(Vector2i(roundi(centro.x), roundi(centro.y))):
			mojados += 1
		# Las normales se guardan comprimidas: (0,0,1) vuelve con un error de 1e-5.
		var texeles := (uvs[q + 2] - uvs[q]) * atlas
		if not texeles.is_equal_approx(lado * Atlas.CELL_TEXELS):
			descuadrados += 1
	var esperada := float(teselas.get_area() - mojadas.size())
	_check(absf(area - esperada) < TOL,
		"El suelo cubre todo menos las teselas del agua (area %.3f, esperada %.3f)" % [
			area, esperada])
	_check(mojados == 0, "Ninguna tesela del suelo toca el agua (%d)" % mojados)
	_check(descuadrados == 0,
		"Cada quad lleva tantos texeles como pixeles mide (%d descuadrados)" % descuadrados)

## La forma del agua, sin escena: esquinas redondeadas, bordes cerca del borde
## de las casillas y teselas vecinas que empalman.
func _forma_de_la_orilla() -> void:
	var lado := Atlas.CELL_TEXELS
	var fleco := WaterSurface.SHORE_FRINGE
	_check(WaterSurface.SHORE_RADIUS <= lado and fleco < lado * 0.5,
		"La curva cabe en su casilla y la ondulacion no sale de las teselas con agua")
	# Lo que puede moverse un borde por la ondulacion, en diagonal.
	var holgura := fleco * sqrt(2.0)

	# Una casilla suelta es redonda.
	var celda := Vector2i(5, 5)
	var forma := _mascara({celda: true})
	var origen: Vector2i = forma.origen
	var img: Image = forma.img
	_check(forma.rect == Rect2i(5, 5, 2, 2), "Una casilla de agua toca sus cuatro teselas")
	_check(img.get_size() == forma.rect.size * lado, "La mascara cubre esas teselas a texel")
	_check(origen == celda * lado - Vector2i.ONE * (lado / 2),
		"La mascara empieza media celda al noroeste (%s)" % origen)
	var c0 := celda * lado
	_check(_es_agua(forma, c0 + Vector2i(16, 16)), "El centro de la casilla es agua")
	var romas := true
	for e: Vector2i in [Vector2i(1, 1), Vector2i(30, 1), Vector2i(1, 30), Vector2i(30, 30)]:
		romas = romas and not _es_agua(forma, c0 + e)
	_check(romas, "Las cuatro esquinas de la casilla estan redondeadas")
	var bordes := true
	var margen := ceili(fleco) + 1
	for m in [15, 16]:
		bordes = bordes and _es_agua(forma, c0 + Vector2i(margen, m)) \
			and not _es_agua(forma, c0 + Vector2i(-margen - 1, m))
		bordes = bordes and _es_agua(forma, c0 + Vector2i(31 - margen, m)) \
			and not _es_agua(forma, c0 + Vector2i(32 + margen, m))
		bordes = bordes and _es_agua(forma, c0 + Vector2i(m, margen)) \
			and not _es_agua(forma, c0 + Vector2i(m, -margen - 1))
		bordes = bordes and _es_agua(forma, c0 + Vector2i(m, 31 - margen)) \
			and not _es_agua(forma, c0 + Vector2i(m, 32 + margen))
	_check(bordes, "En medio de cada lado el borde cae a menos de %d texeles del de la casilla" %
		margen)

	# Una charca grande de 8x3 lleva esquinas de una casilla de radio.
	var charca := {}
	for i in range(-3, 5):
		for j in range(0, 3):
			charca[Vector2i(i, j)] = true
	forma = _mascara(charca)
	var r := WaterSurface.SHORE_RADIUS
	# Texel a `d` texeles en diagonal de la esquina noroeste, y el primero que
	# deberia ser agua segun el radio.
	var d := int(r - r / sqrt(2.0) - holgura) - 1
	var dentro := int(r - r / sqrt(2.0) + holgura) + 1
	_check(not _es_agua(forma, Vector2i(-3, 0) * lado + Vector2i(d, d)) and
		_es_agua(forma, Vector2i(-3, 0) * lado + Vector2i(dentro, dentro)),
		"Las esquinas de un estanque grande tienen %d texeles de radio" % int(r))
	_check(_limpia(forma), "La charca no tiene agua fuera de sus teselas ni tierra en las llenas")

	# La primera fila de agua de cada columna del borde norte no salta mas de
	# un texel, tampoco entre dos teselas: si una tesela leyera la ondulacion con
	# otra fase, el borde daria un escalon justo en la junta. Solo entre las dos
	# esquinas, que ocupan su casilla.
	var saltos := 0
	var previa := -1000
	for x in range(-2 * lado, 4 * lado):
		var fila := -1000
		for y in range(-lado / 2, lado / 2):
			if _es_agua(forma, Vector2i(x, y)):
				fila = y
				break
		if fila == -1000 or (previa != -1000 and absi(fila - previa) > 1):
			saltos += 1
		previa = fila
	_check(saltos == 0, "El borde norte de una charca no da escalones (%d)" % saltos)

	# Una L de 3x3 sin la casilla noreste: la esquina de dentro tambien se
	# redondea, con medio lado de radio porque sus lados miden una casilla.
	var ele := {}
	for i in 3:
		for j in 3:
			if not (i == 2 and j == 0):
				ele[Vector2i(i, j)] = true
	forma = _mascara(ele)
	var vertice := Vector2i(2, 1) * lado
	_check(_es_agua(forma, vertice + Vector2i(1, -2)),
		"La esquina de dentro de una L se redondea hacia la tierra")
	_check(not _es_agua(forma, vertice + Vector2i(12, -12)),
		"...sin comerse la casilla seca")
	_check(_limpia(forma), "La L no tiene agua fuera de sus teselas ni tierra en las llenas")

	# Dos casillas que se tocan por la esquina quedan separadas por tierra.
	forma = _mascara({Vector2i(0, 0): true, Vector2i(1, 1): true})
	var paso := false
	for e in range(-2, 2):
		for f in range(-2, 2):
			paso = paso or _es_agua(forma, Vector2i(lado + e, lado + f))
	_check(not paso, "Dos casillas en diagonal no se unen por la esquina")

## Mascara de orilla de un conjunto de casillas, con lo que hace falta para
## leerla por texel de mundo.
func _mascara(agua: Dictionary) -> Dictionary:
	var teselas := WaterSurface.tile_masks(agua)
	var rect := WaterSurface.mask_tiles(teselas)
	return {
		"teselas": teselas,
		"rect": rect,
		"origen": WaterSurface.mask_origin(rect),
		"img": WaterSurface.shore_mask(teselas, rect),
	}

func _es_agua(forma: Dictionary, texel: Vector2i) -> bool:
	var p: Vector2i = texel - forma.origen
	var img: Image = forma.img
	if p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height():
		return false
	return img.get_pixel(p.x, p.y).r > 0.5

## true si las teselas sin agua en sus casillas no tienen agua y las que tienen
## agua en las cuatro son agua enteras: lo que permite que el suelo dibuje las
## unas normales y se salte las otras.
func _limpia(forma: Dictionary) -> bool:
	var teselas: Dictionary = forma.teselas
	var rect: Rect2i = forma.rect
	var lado := Atlas.CELL_TEXELS
	for j in range(rect.position.y, rect.end.y):
		for i in range(rect.position.x, rect.end.x):
			var mask: int = teselas.get(Vector2i(i, j), 0)
			if mask != 0 and mask != Atlas.MASK_ALL:
				continue
			for v in lado:
				for u in lado:
					var texel := Vector2i(i, j) * lado - Vector2i.ONE * (lado / 2) + Vector2i(u, v)
					if _es_agua(forma, texel) != (mask == Atlas.MASK_ALL):
						return false
	return true

func _lamina_y_orilla(sala: Node3D) -> void:
	var nodo := sala.get_node_or_null("Water") as MeshInstance3D
	_check(nodo != null, "Se construye el nodo Water")
	if nodo == null:
		return
	var celda: Vector3 = sala.call("_cell_size")
	var pitch: float = sala.get("pitch_degrees")
	var hondo_px: int = sala.get("water_depth_texels")
	var malla := nodo.mesh as ArrayMesh
	_check(malla.get_surface_count() == 2, "El agua lleva lamina y orilla")
	_check(nodo.scale.is_equal_approx(Vector3(celda.x, 1.0, celda.z)),
		"El nodo del agua lleva la misma escala que el suelo")
	_check(nodo.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"El agua no proyecta sombra")
	if malla.get_surface_count() != 2:
		return

	var atlas_suelo: Texture2D = (load(SUELO) as StandardMaterial3D).albedo_texture
	var mat := malla.surface_get_material(0) as ShaderMaterial
	var orilla := malla.surface_get_material(1) as ShaderMaterial
	_check(mat != null and mat.shader == WaterSurface.SHADER,
		"La lamina usa water_pixel.gdshader")
	_check(orilla != null and orilla.shader == WaterSurface.SHORE_SHADER,
		"La orilla usa water_shore.gdshader")
	if mat == null or orilla == null:
		return
	_check(mat.get_shader_parameter(&"water_texture") == WaterSurface.TEXTURE
		and Vector2i(WaterSurface.TEXTURE.get_size()) == Vector2i.ONE * 4 * Atlas.CELL_TEXELS,
		"La textura del agua mide 4 celdas, 128 texeles a 32 por celda")
	_check(is_equal_approx(mat.get_shader_parameter(&"ripple_speed"),
		sala.get("water_ripple_speed")), "Las ondas derivan a la velocidad del inspector")
	_paleta(mat)
	_check(orilla.get_shader_parameter(&"ground_atlas") == atlas_suelo
		and mat.get_shader_parameter(&"ground_atlas") == atlas_suelo,
		"La orilla y el escalon leen el atlas del suelo")
	_check(mat.get_shader_parameter(&"depth_texels") == hondo_px,
		"El escalon mide lo que se hunde el agua (%s)" %
			mat.get_shader_parameter(&"depth_texels"))
	_check(mat.get_shader_parameter(&"bank_page") ==
		Atlas.fill_page(WaterSurface.BANK_TERRAIN).position,
		"El escalon es el relleno de tierra")
	var mascara: Texture2D = mat.get_shader_parameter(&"shore_mask")
	_check(mascara != null and mascara == orilla.get_shader_parameter(&"shore_mask")
		and mat.get_shader_parameter(&"mask_origin") ==
			orilla.get_shader_parameter(&"mask_origin"),
		"Lamina y orilla leen la misma mascara")

	var lamina: PackedVector3Array = malla.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	# Las teselas con agua (4x3) mas la fila de al norte (4).
	var cubiertas := (ESTANQUE.size.x + 1) * (ESTANQUE.size.y + 2)
	_check(lamina.size() == 4 * cubiertas,
		"La lamina cubre las teselas con agua y la fila del norte (%d quads)" %
			(lamina.size() / 4))
	var y := lamina[0].y
	var hundido := -y * cos(deg_to_rad(pitch)) * VillageMetrics.PIXELS_PER_UNIT
	_check(absf(hundido - hondo_px) < TOL,
		"El agua se ve %d pixeles por debajo del suelo (%.4f)" % [hondo_px, hundido])

	var mojadas := WaterSurface.tile_masks(sala.call("water_cells"))
	var parciales := 0
	for t: Vector2i in mojadas:
		if mojadas[t] != Atlas.MASK_ALL:
			parciales += 1
	var trozos := malla.surface_get_arrays(1)
	var overts: PackedVector3Array = trozos[Mesh.ARRAY_VERTEX]
	var ouvs: PackedVector2Array = trozos[Mesh.ARRAY_TEX_UV]
	_check(overts.size() == 4 * parciales,
		"Una tesela de orilla por cada una que toca agua sin estar llena (%d de %d)" % [
			overts.size() / 4, parciales])
	var a_ras := true
	var enteras := true
	var atlas := Vector2(Atlas.atlas_size())
	for q in range(0, overts.size(), 4):
		a_ras = a_ras and is_zero_approx(overts[q].y) and is_zero_approx(overts[q + 2].y)
		var lado := Vector2(overts[q + 2].x - overts[q].x, overts[q + 2].z - overts[q].z)
		var texeles := (ouvs[q + 2] - ouvs[q]) * atlas
		enteras = enteras and lado.is_equal_approx(Vector2.ONE) \
			and texeles.is_equal_approx(Vector2.ONE * Atlas.CELL_TEXELS)
	_check(a_ras, "La orilla va a ras del suelo")
	_check(enteras, "Cada tesela de orilla es entera, 32 texeles en 32 pixeles")

func _sin_hierba(sala: Node3D) -> void:
	var cesped: Dictionary = sala.call("grass_cells")
	var dentro := 0
	for c: Vector2i in cesped:
		if ESTANQUE.has_point(c):
			dentro += 1
	_check(dentro == 0, "No crece hierba en el agua (%d)" % dentro)

## El personaje aparece dos filas al sur del estanque y anda al norte: se para en
## la orilla.
func _no_se_entra(sala: Node3D) -> void:
	var cuerpos := sala.get_node_or_null("WaterBodies")
	_check(cuerpos != null and cuerpos.get_child_count() == ESTANQUE.get_area(),
		"Cada casilla de agua tiene su caja de colision")
	var celda: Vector3 = sala.call("_cell_size")
	var jugador := sala.get_node("Player") as CharacterBody3D
	Input.action_press(&"move_up")
	for _paso in 180:
		await physics_frame
	Input.action_release(&"move_up")
	var orilla_sur := float(ESTANQUE.end.y) * celda.z
	_check(jugador.global_position.z > orilla_sur,
		"El personaje se para en la orilla (z %.3f, orilla %.3f)" % [
			jugador.global_position.z, orilla_sur])
	_check(jugador.global_position.z < orilla_sur + 0.6,
		"...despues de haber llegado hasta ella (z %.3f)" % jugador.global_position.z)

func _pueblo() -> void:
	var pueblo := (load(PUEBLO) as PackedScene).instantiate()
	var terreno := pueblo.get_node("Terreno") as GridMap
	var parcela := pueblo.get_node("Parcela") as GridMap
	var lib := terreno.mesh_library
	var agua := -1
	for id in lib.get_item_list():
		if lib.get_item_name(id) == String(WaterSurface.ITEM):
			agua = id
	_check(agua != -1, "La biblioteca de terreno tiene el marcador de agua")
	if agua == -1:
		pueblo.free()
		return
	# Lejos de lo que haya pintado, para no depender del mapa guardado.
	for j in range(60, 62):
		for i in range(60, 63):
			terreno.set_cell_item(Vector3i(i, 0, j), agua)
	parcela.set_cell_item(Vector3i(60, 0, 60), 0)
	root.add_child(pueblo)
	await physics_frame

	_check(pueblo.call("_is_water", 61, 61), "Una casilla pintada de agua es agua")
	_check(not pueblo.call("_is_water", 59, 60), "La de al lado no")
	_check(pueblo.call("_terrain_at", 61, 61) == Atlas.Terrain.GRASS,
		"El agua no se cuenta como terreno desconocido")
	var rango: Rect2i = pueblo.call("_ground_cell_range")
	_check(rango.has_point(Vector2i(62, 61)), "El suelo llega hasta el agua pintada")
	var nodo := pueblo.get_node_or_null("Water") as MeshInstance3D
	_check(nodo != null and nodo.mesh.get_surface_count() == 2,
		"El pueblo construye el agua pintada")
	var cuerpos := pueblo.get_node_or_null("WaterBodies")
	# Las 6 de la prueba mas las que haya pintadas en el mapa.
	var casillas: int = pueblo.call("water_cells").size()
	_check(casillas >= 6 and cuerpos != null and cuerpos.get_child_count() == casillas,
		"El agua del pueblo tiene colision (%d cajas, %d casillas)" % [
			cuerpos.get_child_count() if cuerpos else 0, casillas])
	var layout: PlotLayout = pueblo.get("layout")
	_check(layout.bloqueadas.has(Vector2i(60, 60)),
		"El agua dentro de la parcela no admite muebles")
	pueblo.queue_free()
	await process_frame

## El shader separa las capas del agua por los cinco colores de la textura. Si
## la textura cambia de paleta, hay que cambiar tambien WaterSurface.PALETTE: si
## no, cada texel caeria en el color mas parecido y el dibujo cambiaria sin
## avisar.
func _paleta(mat: ShaderMaterial) -> void:
	var img := WaterSurface.TEXTURE.get_image()
	if img.is_compressed():
		img.decompress()
	var vistos := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			vistos[Color8(c.r8, c.g8, c.b8)] = true
	var iguales := vistos.size() == WaterSurface.PALETTE.size()
	for c: Color in vistos:
		iguales = iguales and WaterSurface.PALETTE.has(c)
	_check(iguales, "WaterSurface.PALETTE son los colores de water_128.png (%d en la textura)" %
		vistos.size())
	var tonos := WaterSurface.tone_texels()
	var bien := true
	for k in WaterSurface.TONES.size():
		var p: Vector2i = mat.get_shader_parameter(WaterSurface.TONES[k])
		var c := img.get_pixel(p.x, p.y) if p.x >= 0 else Color.BLACK
		bien = bien and p == tonos[k] and Color8(c.r8, c.g8, c.b8) == WaterSurface.PALETTE[k]
	_check(bien, "El shader lee cada color de un texel de la textura que lo tiene")
