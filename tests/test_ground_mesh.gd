extends SceneTree

## Estructura de la malla del suelo, sin dibujar nada.
##
## Comprueba la malla real que construye la escena, no una reimplementacion, y
## ademas recalcula la seleccion de tesela por su cuenta para contrastarla. Ese
## contraste es lo que caza un % en vez de un posmod sin tocar una GPU: la fase
## de la mitad oeste del mapa saldria con indice negativo.
##
##   godot --headless --path . --script tests/test_ground_mesh.gd

const ESCENA := "res://scenes/world/test_room.tscn"
const Atlas := preload("res://scripts/domain/ground_atlas.gd")

## Margen para la cuantizacion de atributos al recuperarlos de la malla. En
## posicion es del orden de 0,0005 unidades y en UV de 1/65536 del atlas, que
## con 1024 de ancho son 0,016 texeles. 0,05 deja dos ordenes de holgura.
const TOL_TEXEL := 0.05
const TOL_POS := 0.01

## Cuantizacion de normales: ver el comentario de _geometria.
const TOL_NORMAL := 0.0001

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
	var escena: PackedScene = load(ESCENA)
	var sala := escena.instantiate()
	root.add_child(sala)
	await process_frame

	var suelo := sala.get_node_or_null("Ground") as MeshInstance3D
	_check(suelo != null, "La escena tiene un MeshInstance3D llamado Ground")
	if suelo == null:
		quit(1)
		return

	var malla := suelo.mesh as ArrayMesh
	_check(malla != null and malla.get_surface_count() == 1,
		"El suelo es una ArrayMesh de una sola superficie")
	_check(malla.surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLES,
		"La superficie es de triangulos")

	var arrays := malla.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	var rango: Rect2i = sala.call("_ground_tile_range")
	var teselas := rango.size.x * rango.size.y
	_check(verts.size() == 4 * teselas,
		"Hay 4 vertices por tesela (%d para %d teselas)" % [verts.size(), teselas])
	_check(idx.size() == 6 * teselas,
		"Hay 6 indices por tesela (%d para %d teselas)" % [idx.size(), teselas])
	_check(uvs.size() == verts.size(), "Hay una UV por vertice")

	_geometria(verts, norms, idx)
	_uvs(uvs, verts)
	_seleccion(sala, uvs, rango)
	_colision(sala, suelo)
	_cobertura(sala)

	sala.queue_free()
	await process_frame
	print("RESULTADO MALLA SUELO: %d comprobaciones, %d fallos" % [checks, failures])
	quit(1 if failures else 0)

func _geometria(verts: PackedVector3Array, norms: PackedVector3Array,
		idx: PackedInt32Array) -> void:
	var y_maxima := 0.0
	for v in verts:
		y_maxima = maxf(y_maxima, absf(v.y))
	_check(y_maxima < TOL_POS, "Todo el suelo esta en y=0 (maximo %.5f)" % y_maxima)

	# Godot cuantiza las normales al guardarlas en la malla, asi que recuperarlas
	# no devuelve exactamente Vector3.UP. Medido en esta malla: desviacion maxima
	# 1,53e-5, es decir (0, 1, -0,000015), que es del orden de 1/65536 y por eso
	# se pasa por poco del epsilon de is_equal_approx. La tolerancia de abajo es
	# seis veces la desviacion medida, no un numero elegido a ojo.
	var peor_normal := 0.0
	for n in norms:
		peor_normal = maxf(peor_normal, (n - Vector3.UP).length())
	_check(peor_normal < TOL_NORMAL,
		"Todas las normales apuntan a +Y (desviacion maxima %.7f)" % peor_normal)

	# El bobinado decide si la cara se ve. Con el orden del .obj copiado literal
	# el suelo sale invisible, porque Wavefront declara antihorario y el
	# importador lo invierte al traer el modelo.
	var mal := 0
	for t in range(0, idx.size(), 3):
		var p0 := verts[idx[t]]
		var p1 := verts[idx[t + 1]]
		var p2 := verts[idx[t + 2]]
		if (p1 - p0).cross(p2 - p0).y >= 0.0:
			mal += 1
	_check(mal == 0, "Los %d triangulos miran hacia arriba (%d al reves)" % [
		idx.size() / 3, mal])

func _uvs(uvs: PackedVector2Array, verts: PackedVector3Array) -> void:
	var atlas := Atlas.atlas_size()
	var no_enteras := 0
	for uv in uvs:
		var t := Vector2(uv.x * atlas.x, uv.y * atlas.y)
		if absf(t.x - roundf(t.x)) > TOL_TEXEL or absf(t.y - roundf(t.y)) > TOL_TEXEL:
			no_enteras += 1
	_check(no_enteras == 0,
		"Todas las UV caen en bordes enteros de texel (%d fuera)" % no_enteras)

	var lado_mal := 0
	var fuera := 0
	var orientacion_mal := 0
	for q in range(0, verts.size(), 4):
		var u_min := INF
		var u_max := -INF
		var v_min := INF
		var v_max := -INF
		for k in 4:
			u_min = minf(u_min, uvs[q + k].x * atlas.x)
			u_max = maxf(u_max, uvs[q + k].x * atlas.x)
			v_min = minf(v_min, uvs[q + k].y * atlas.y)
			v_max = maxf(v_max, uvs[q + k].y * atlas.y)
		if absf((u_max - u_min) - Atlas.CELL_TEXELS) > TOL_TEXEL \
				or absf((v_max - v_min) - Atlas.CELL_TEXELS) > TOL_TEXEL:
			lado_mal += 1
		if u_min < -TOL_TEXEL or v_min < -TOL_TEXEL \
				or u_max > atlas.x + TOL_TEXEL or v_max > atlas.y + TOL_TEXEL:
			fuera += 1
		# El vertice de min x, min z tiene que llevar min u, min v: u crece con
		# el mundo +X y v con el mundo +Z, sin transponer ni voltear.
		var mejor := 0
		for k in 4:
			if verts[q + k].x <= verts[q + mejor].x and verts[q + k].z <= verts[q + mejor].z:
				mejor = k
		if absf(uvs[q + mejor].x * atlas.x - u_min) > TOL_TEXEL \
				or absf(uvs[q + mejor].y * atlas.y - v_min) > TOL_TEXEL:
			orientacion_mal += 1
	_check(lado_mal == 0, "Toda tesela mide 32x32 texeles (%d mal)" % lado_mal)
	_check(fuera == 0, "Toda tesela cae dentro del atlas (%d fuera)" % fuera)
	_check(orientacion_mal == 0,
		"u crece con +X y v con +Z en todas las teselas (%d mal)" % orientacion_mal)

## Recalcula por su cuenta el rectangulo de atlas de cada tesela y lo contrasta
## con el que lleva la malla.
func _seleccion(sala: Node, uvs: PackedVector2Array, rango: Rect2i) -> void:
	var atlas := Atlas.atlas_size()
	var distintos := 0
	var q := 0
	for j in range(rango.position.y, rango.end.y):
		for i in range(rango.position.x, rango.end.x):
			var esperado := _rect_esperado(sala, i, j)
			var u_min := INF
			var v_min := INF
			for k in 4:
				u_min = minf(u_min, uvs[q + k].x * atlas.x)
				v_min = minf(v_min, uvs[q + k].y * atlas.y)
			if absf(u_min - esperado.position.x) > TOL_TEXEL \
					or absf(v_min - esperado.position.y) > TOL_TEXEL:
				distintos += 1
			q += 4
	_check(distintos == 0,
		"La seleccion de tesela coincide con el recalculo independiente (%d distintas)"
		% distintos)

func _rect_esperado(sala: Node, i: int, j: int) -> Rect2i:
	var esquinas := PackedInt32Array([
		sala.call("_terrain_at", i - 1, j - 1), sala.call("_terrain_at", i, j - 1),
		sala.call("_terrain_at", i - 1, j), sala.call("_terrain_at", i, j)])
	# Reduccion reimplementada aqui, no llamada a la de la sala.
	var presentes: Array[int] = []
	for t in esquinas:
		if not presentes.has(t):
			presentes.append(t)
	presentes.sort()
	while presentes.size() > 2 or (presentes.size() == 2
			and not Atlas.has_pair(presentes[0], presentes[1])):
		var bajo: int = presentes[0]
		var destino: int = presentes[1]
		for k in esquinas.size():
			if esquinas[k] == bajo:
				esquinas[k] = destino
		presentes.remove_at(0)
	# posmod a proposito: con % la mitad oeste del mapa daria indice negativo.
	var fase := Vector2i(posmod(i, Atlas.FILL_CELLS), posmod(j, Atlas.FILL_CELLS))
	if presentes.size() == 1:
		return Atlas.fill_cell(presentes[0], fase)
	var alto: int = presentes[1]
	var mask := 0
	for k in esquinas.size():
		if esquinas[k] == alto:
			mask |= 1 << k
	return Atlas.transition_cell(Atlas.pair_index(presentes[0], alto), mask, fase)

## El colisionador tiene que cubrir lo que se dibuja. Es la afirmacion que
## habria cazado el desfase de media celda que arrastraba la version anterior.
func _colision(sala: Node, suelo: MeshInstance3D) -> void:
	var cuerpo := sala.get_node_or_null("GroundBody") as StaticBody3D
	_check(cuerpo != null, "Existe el GroundBody")
	if cuerpo == null:
		return
	var forma := cuerpo.get_child(0) as CollisionShape3D
	var caja := forma.shape as BoxShape3D
	var centro := forma.position
	var malla_aabb := suelo.transform * suelo.mesh.get_aabb()
	var caja_min := centro - caja.size * 0.5
	var caja_max := centro + caja.size * 0.5
	_check(absf(caja_min.x - malla_aabb.position.x) < TOL_POS
			and absf(caja_max.x - malla_aabb.end.x) < TOL_POS,
		"El colisionador cubre la malla en X")
	_check(absf(caja_min.z - malla_aabb.position.z) < TOL_POS
			and absf(caja_max.z - malla_aabb.end.z) < TOL_POS,
		"El colisionador cubre la malla en Z")
	_check(absf(caja_max.y) < TOL_POS, "La cara superior del colisionador esta en y=0")

## Que la muestra ejercite de verdad las 16 mascaras. Sin esto, una muestra que
## solo tuviera rectangulos sueltos dejaria sin probar las cuatro esquinas
## interiores y las dos diagonales, que son la mitad del interes del sistema.
func _cobertura(sala: Node) -> void:
	var stats: Dictionary = sala.get("ground_stats")
	var mascaras: Dictionary = stats.get("masks", {})
	var pareja := Atlas.pair_index(Atlas.Terrain.GRASS, Atlas.Terrain.DIRT)
	var vistas: Dictionary = mascaras.get(pareja, {})
	var faltan: Array[int] = []
	for m in range(1, Atlas.MASK_COUNT - 1):
		if not vistas.has(m):
			faltan.append(m)
	_check(faltan.is_empty(),
		"Cesped/tierra ejercita las 14 mascaras de transicion (faltan %s)" % str(faltan))
	for m in Atlas.INNER_CORNER_MASKS:
		_check(vistas.has(m), "Aparece la esquina interior %d" % m)
	for m in Atlas.DIAGONAL_MASKS:
		_check(vistas.has(m), "Aparece la diagonal %d" % m)
	var degradadas: Array = stats.get("degraded", [])
	_check(degradadas.size() == 2,
		"La muestra tiene exactamente 2 teselas degradadas (tiene %d: %s)" % [
			degradadas.size(), str(degradadas)])
