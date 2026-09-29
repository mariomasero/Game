extends SceneTree

## Que el suelo se pueda andar. La fisica funciona con --headless.
##
## Cubre el criterio de salida de H6 "el personaje cruza uniones sin engancharse
## ni caer" (DEVELOPMENT_PLAN.md:249), y es la prueba que habria gritado con el
## desfase de media celda que arrastraba el colisionador: al sur faltaba suelo
## solido debajo de suelo pintado, asi que el personaje se caia por un borde que
## en pantalla se veia macizo.
##
##   godot --headless --path . --script tests/test_ground_walk.gd

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
	var sala := (load(ESCENA) as PackedScene).instantiate()
	root.add_child(sala)
	await physics_frame
	await physics_frame

	await _hay_suelo_solido(sala)
	await _cruza_la_union(sala)

	sala.queue_free()
	await process_frame
	print("RESULTADO ANDAR SUELO: %d comprobaciones, %d fallos" % [checks, failures])
	quit(1 if failures else 0)

## Un rayo hacia abajo en el centro de cada celda dibujada tiene que encontrar
## suelo en y=0. Es la comprobacion que ata el colisionador a lo que se ve.
func _hay_suelo_solido(sala: Node3D) -> void:
	var estado := sala.get_world_3d().direct_space_state
	var size: Vector3 = sala.call("_cell_size")
	var teselas: Rect2i = sala.call("_ground_tile_range")
	# Los muros se excluyen: un rayo vertical sobre una celda con muro encima
	# golpea su techo a una altura de celda y no dice nada del suelo.
	var excluir: Array[RID] = []
	var muros := sala.get_node_or_null("WallBodies") as StaticBody3D
	if muros != null:
		excluir.append(muros.get_rid())
	# Celdas que caen enteras dentro de la losa dibujada.
	var sin_suelo: Array[Vector2i] = []
	var y_peor := 0.0
	for j in range(teselas.position.y, teselas.end.y - 1):
		for i in range(teselas.position.x, teselas.end.x - 1):
			var centro := Vector3((i + 0.5) * size.x, 2.0, (j + 0.5) * size.z)
			var consulta := PhysicsRayQueryParameters3D.create(
				centro, centro + Vector3.DOWN * 4.0)
			consulta.exclude = excluir
			var golpe := estado.intersect_ray(consulta)
			if golpe.is_empty():
				sin_suelo.append(Vector2i(i, j))
			else:
				y_peor = maxf(y_peor, absf(golpe["position"].y))
	_check(sin_suelo.is_empty(),
		"Toda celda dibujada tiene suelo solido debajo (%d sin: %s)" % [
			sin_suelo.size(), str(sin_suelo.slice(0, 6))])
	_check(y_peor < 0.01,
		"El suelo solido esta en y=0 (desvio maximo %.5f)" % y_peor)

## El personaje camina hacia el norte desde donde aparece, cruzando la union
## entre el camino y el patio, sin despegarse del suelo ni caerse.
func _cruza_la_union(sala: Node3D) -> void:
	var jugador := sala.get_node("Player") as CharacterBody3D
	var z_inicial := jugador.global_position.z
	Input.action_press(&"move_up")
	var suelto := 0
	var y_peor := 0.0
	for _paso in 240:
		await physics_frame
		if not jugador.is_on_floor():
			suelto += 1
		y_peor = maxf(y_peor, absf(jugador.global_position.y))
	Input.action_release(&"move_up")
	var recorrido := z_inicial - jugador.global_position.z
	_check(recorrido > 2.0,
		"El personaje avanza al norte (%.2f unidades)" % recorrido)
	_check(suelto == 0,
		"No se despega del suelo en ningun fotograma (%d fotogramas en el aire)" % suelto)
	_check(y_peor < 0.05,
		"No se hunde ni sube al cruzar la union (y maxima %.4f)" % y_peor)
