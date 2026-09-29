extends SceneTree

## Reglas del reparto de hierba, sin escena: GrassScatter.
##
## Ata lo que el ojo no mide bien: que la fraccion en manchas es la pedida, que
## ninguna mata crece fuera del cesped ni en su borde, que el reparto es
## determinista y que las manchas de verdad estan mas apretadas que las sueltas.
## Tambien que la sala planta hierba solo en cesped libre de muros.
##
##   godot --headless --path . --script tests/test_grass_scatter.gd

const ESCENA := "res://scenes/world/test_room.tscn"

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
	_reparto()
	_bordes()
	_sala()
	print("RESULTADO HIERBA: %d comprobaciones, %d fallos" % [checks, failures])
	quit(1 if failures else 0)

## Prado de 30x30 con un camino de 4 de ancho en medio.
func _prado() -> Dictionary:
	var cesped := {}
	for j in 30:
		for i in 30:
			if i < 13 or i >= 17:
				cesped[Vector2i(i, j)] = true
	return cesped

func _reparto() -> void:
	var cesped := _prado()
	var matas := GrassScatter.scatter(cesped, 1.5, 0.7, 0.6, 7.0, 0.35, 42)
	var esperadas := roundi(cesped.size() * 1.5)
	_check(matas.size() >= int(esperadas * 0.97),
		"Se plantan casi todas las matas pedidas (%d de %d)" % [matas.size(), esperadas])

	var en_manchas := 0
	for m in matas:
		if m.z > 0.0:
			en_manchas += 1
	var fraccion := float(en_manchas) / float(matas.size())
	_check(absf(fraccion - 0.7) < 0.03,
		"El 70 %% de las matas va en manchas (%.3f)" % fraccion)

	var otra := GrassScatter.scatter(cesped, 1.5, 0.7, 0.6, 7.0, 0.35, 42)
	_check(otra == matas, "La misma semilla da la misma hierba")
	var distinta := GrassScatter.scatter(cesped, 1.5, 0.7, 0.6, 7.0, 0.35, 43)
	_check(distinta != matas, "Otra semilla da otra hierba")

	# Mas apretadas: la distancia media a la vecina mas cercana entre matas de
	# mancha tiene que quedar claramente por debajo de la de las sueltas.
	var agrupadas := PackedVector2Array()
	var sueltas := PackedVector2Array()
	for m in matas:
		(agrupadas if m.z > 0.0 else sueltas).append(Vector2(m.x, m.y))
	var d_agrupadas := _vecina_media(agrupadas)
	var d_sueltas := _vecina_media(sueltas)
	_check(d_agrupadas < d_sueltas * 0.6,
		"Las manchas estan mas apretadas que el reparto suelto (%.2f frente a %.2f)" % [
			d_agrupadas, d_sueltas])

	_check(GrassScatter.scatter({}, 1.5, 0.7, 0.6, 7.0, 0.35, 42).is_empty(),
		"Sin cesped no hay hierba")
	var todas_sueltas := GrassScatter.scatter(cesped, 1.5, 0.0, 0.6, 7.0, 0.35, 42)
	var alguna := false
	for m in todas_sueltas:
		alguna = alguna or m.z > 0.0
	_check(not alguna, "Con cluster_share = 0 no hay ninguna mancha")

func _bordes() -> void:
	var cesped := _prado()
	var margen := 0.35
	var matas := GrassScatter.scatter(cesped, 2.0, 0.7, 0.6, 7.0, margen, 7)
	var fuera := 0
	for m in matas:
		if not GrassScatter.is_on_grass(cesped, Vector2(m.x, m.y), margen):
			fuera += 1
		# El camino va de x = 13 a x = 17: ninguna mata a menos del margen.
		if m.x > 13.0 - margen and m.x < 17.0 + margen:
			fuera += 1
	_check(fuera == 0, "Ninguna mata en el camino ni a menos del margen de su borde")
	_check(not GrassScatter.is_on_grass(cesped, Vector2(12.8, 5.5), margen),
		"is_on_grass rechaza un pie a 0,2 celdas del camino")
	_check(GrassScatter.is_on_grass(cesped, Vector2(12.5, 5.5), margen),
		"is_on_grass acepta un pie a 0,5 celdas del camino")

func _sala() -> void:
	var sala: Node3D = (load(ESCENA) as PackedScene).instantiate()
	root.add_child(sala)
	var celdas: Dictionary = sala.grass_cells()
	_check(not celdas.is_empty(), "La sala tiene celdas de cesped")
	var mal := 0
	for celda: Vector2i in celdas:
		if sala._terrain_at(celda.x, celda.y) != GroundAtlas.Terrain.GRASS:
			mal += 1
	_check(mal == 0, "Solo hay hierba en celdas de cesped")
	# El muro en L de la sala ocupa la fila j = -5 de i = -6 a 2.
	_check(not celdas.has(Vector2i(0, -5)), "No crece hierba dentro de un muro")

	var hierba := sala.get_node_or_null("Grass") as MultiMeshInstance3D
	_check(hierba != null, "La sala construye el nodo Grass")
	if hierba != null:
		_check(hierba.multimesh.instance_count > 0, "La MultiMesh de hierba tiene matas")
		_check(hierba.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"La hierba no proyecta sombra")
		# Pie en la rejilla de pixeles: x en pasos de 1/32 y z en pasos de
		# 1/(32 sen p), que en pantalla son pixeles enteros.
		var fondo := VillageMetrics.cell_depth(VillageMetrics.DEFAULT_PITCH_DEGREES)
		var descuadradas := 0
		for k in hierba.multimesh.instance_count:
			var pie := hierba.multimesh.get_instance_transform(k).origin
			var px := pie.x * 32.0
			var pz := pie.z / fondo * 32.0
			if absf(px - roundf(px)) > 0.001 or absf(pz - roundf(pz)) > 0.001:
				descuadradas += 1
		_check(descuadradas == 0, "Todas las matas tienen el pie en un pixel entero")
	sala.queue_free()

func _vecina_media(puntos: PackedVector2Array) -> float:
	if puntos.size() < 2:
		return 0.0
	var suma := 0.0
	for a in puntos:
		var mejor := INF
		for b in puntos:
			if a != b:
				mejor = minf(mejor, a.distance_squared_to(b))
		suma += sqrt(mejor)
	return suma / float(puntos.size())
