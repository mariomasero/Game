extends SceneTree

# Integration checks: real input, scene geometry, physics and modal UI.
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
	else:
		print("PASS: " + message)

func _frames(count: int = 3) -> void:
	for index in range(count):
		await physics_frame
	await process_frame

func _action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = action
	Input.parse_input_event(event)
	await process_frame

func _walk(actions: Array[StringName], frames: int) -> void:
	for action in actions:
		Input.action_press(action)
	await _frames(frames)
	for action in actions:
		Input.action_release(action)

func _await_until(condition: Callable, frames: int = 90) -> bool:
	for index in range(frames):
		if condition.call():
			return true
		await _frames(1)
	return condition.call()

func _click(control: Control) -> void:
	var pointer := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = pointer
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func _run() -> void:
	if not ResourceLoader.exists("res://scenes/world/laboratory_3d.tscn"):
		_check(false, "Existe la sala 3D ejecutable")
		quit(1)
		return
	var scene: PackedScene = load("res://scenes/world/laboratory_3d.tscn")
	var lab: Node3D = scene.instantiate()
	lab.get_node("Persistence").enabled = false
	root.add_child(lab)
	await _frames(5)
	var player: CharacterBody3D = lab.get_node("Player")
	var terminal: Area3D = lab.get_node("Terminal")
	var panel: Control = lab.get_node("HUD/Overlay")
	var sprite: AnimatedSprite3D = player.get_node("AnimatedSprite3D")
	var camera: Camera3D = lab.get_node("Camera3D")
	var start := player.position
	await _walk([&"move_right"], 20)
	var cardinal_distance := player.position.distance_to(start)
	_check(cardinal_distance > 0.8, "Derecha desplaza al personaje en X")
	_check(camera.unproject_position(player.position).x > camera.unproject_position(start).x, "Derecha avanza hacia la derecha de pantalla")
	_check(sprite.animation == &"walk_side" and not sprite.flip_h, "Camina hacia la derecha")
	player.position = start
	await _frames()
	await _walk([&"move_right", &"move_up"], 20)
	_check(absf(player.position.distance_to(start) - cardinal_distance) < 0.08, "La diagonal mantiene la velocidad cardinal")
	_check(camera.unproject_position(player.position).y < camera.unproject_position(start).y, "Arriba avanza hacia arriba de pantalla")
	await _frames()
	_check(String(sprite.animation).begins_with("idle_"), "Al parar vuelve a reposo")
	for data in [{"action": &"move_left", "animation": &"walk_side", "flip": true}, {"action": &"move_up", "animation": &"walk_up", "flip": false}, {"action": &"move_down", "animation": &"walk_down", "flip": false}]:
		player.position = start
		await _frames()
		await _walk([data.action], 8)
		_check(sprite.animation == data.animation and sprite.flip_h == data.flip, "Animación de " + String(data.action))
		await _frames()
		_check(String(sprite.animation) == String(data.animation).replace("walk_", "idle_"), "Reposo conserva " + String(data.action))
	for data in [
		{"x": &"move_right", "y": &"move_down", "suffix": "down_side", "flip": false},
		{"x": &"move_left", "y": &"move_down", "suffix": "down_side", "flip": true},
		{"x": &"move_right", "y": &"move_up", "suffix": "up_side", "flip": false},
		{"x": &"move_left", "y": &"move_up", "suffix": "up_side", "flip": true},
	]:
		player.position = start
		await _frames()
		await _walk([data.x, data.y], 8)
		_check(sprite.animation == StringName("walk_" + data.suffix) and sprite.flip_h == data.flip,
			"Camina en diagonal %s + %s" % [data.x, data.y])
		await _frames()
		_check(sprite.animation == StringName("idle_" + data.suffix) and sprite.flip_h == data.flip,
			"Reposo conserva la diagonal %s + %s" % [data.x, data.y])
	for data in [{"position": Vector3(-4, 0, 2), "action": &"move_left", "axis": 0, "sign": -1}, {"position": Vector3(4, 0, 2), "action": &"move_right", "axis": 0, "sign": 1}, {"position": Vector3(0, 0, -4), "action": &"move_up", "axis": 2, "sign": -1}, {"position": Vector3(0, 0, 4), "action": &"move_down", "axis": 2, "sign": 1}]:
		player.position = data.position
		await _frames()
		Input.action_press(data.action)
		await _frames(45)
		var edge: float = player.position[data.axis] * data.sign
		_check(edge > 4.3 and edge < 4.9, "La pared detiene " + String(data.action))
		_check(absf(player.position.y) < 0.03 and player.is_on_floor(), "Permanece sobre el suelo en " + String(data.action))
		_check(String(sprite.animation).begins_with("idle_"), "No camina parado contra la pared")
		Input.action_release(data.action)
	player.position = start
	await _frames()
	await _action(&"interact")
	_check(not panel.visible, "E no abre desde lejos")
	player.position = terminal.position + Vector3(0, 0, 1.4)
	await _frames()
	await _action(&"interact")
	_check(panel.visible, "E abre el terminal cercano")
	start = player.position
	await _walk([&"move_down"], 20)
	_check(player.position.distance_to(start) < 0.01, "La UI bloquea el movimiento")
	await _action(&"interact")
	_check(panel.visible, "E repetida mantiene el panel abierto")
	await _action(&"ui_cancel")
	_check(not panel.visible, "Escape cierra el panel")
	await _walk([&"move_down"], 10)
	_check(player.position.z > start.z + 0.3, "Cerrar devuelve el control")
	player.position = start
	await _frames()
	await _action(&"interact")
	var close: Button = lab.get_node("HUD/Overlay/Panel/Margin/Content/Close")
	await _click(close)
	_check(not panel.visible, "El botón cierra el panel")
	# A real wall between the player and the console must block interaction.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 2, 0.12)
	shape.shape = box
	wall.add_child(shape)
	lab.add_child(wall)
	wall.position = terminal.position + Vector3(0, 1, 1.0)
	await _frames()
	await _action(&"interact")
	_check(not panel.visible, "La pared impide abrir el terminal aunque esté cerca")
	wall.queue_free()
	await _frames()
	await _action(&"interact")
	_check(panel.visible, "Quitar el obstáculo permite interactuar")
	await _action(&"ui_cancel")
	for side in [-1, 1]:
		player.position = terminal.position + Vector3(side * 2.0, 0, 0)
		await _frames()
		await _walk([&"move_right" if side < 0 else &"move_left"], 40)
		var distance := absf(player.position.x - terminal.position.x)
		_check(distance >= 0.85 and distance < 1.0, "El ordenador bloquea lateral %d sin margen excesivo" % side)
	for side in [-1, 1]:
		player.position = terminal.position + Vector3(0, 0, side * 1.8)
		await _frames()
		await _walk([&"move_down" if side < 0 else &"move_up"], 40)
		var distance := absf(player.position.z - terminal.position.z)
		_check(distance >= 0.68 and distance < 0.82, "El ordenador bloquea frente/reverso %d" % side)
	player.position = Vector3(2.6, 0, -1.5)
	await _frames()
	await _walk([&"move_up"], 40)
	_check(player.position.z > -2.75 and player.position.z < -2.5, "La máquina impide atravesar su frente")
	# Cartel flotante sobre el objeto interactuable.
	var hint: Node3D = terminal.get_node("InteractHint")
	var monitor_top := terminal.global_position + Vector3(0.2, 1.25, -0.2)
	player.position = Vector3(0, 0, 3.5)
	_check(await _await_until(func() -> bool: return not hint.visible), "El cartel no aparece lejos del terminal")
	player.position = terminal.position + Vector3(0, 0, 1.4)
	_check(await _await_until(func() -> bool: return hint.visible), "El cartel aparece al acercarse al terminal")
	_check(hint.global_position.y > monitor_top.y, "El cartel flota por encima del objeto")
	_check(camera.unproject_position(hint.global_position).y < camera.unproject_position(monitor_top).y,
		"El cartel queda sobre el objeto en pantalla")
	await _action(&"interact")
	_check(panel.visible, "E sigue abriendo el terminal con el cartel visible")
	_check(await _await_until(func() -> bool: return not hint.visible), "El cartel se retira mientras el panel está abierto")
	await _action(&"ui_cancel")
	_check(await _await_until(func() -> bool: return hint.visible), "El cartel vuelve al cerrar el panel")
	wall = StaticBody3D.new()
	shape = CollisionShape3D.new()
	box = BoxShape3D.new()
	box.size = Vector3(3, 2, 0.12)
	shape.shape = box
	wall.add_child(shape)
	lab.add_child(wall)
	wall.position = terminal.position + Vector3(0, 1, 1.0)
	_check(await _await_until(func() -> bool: return not hint.visible), "Una pared entre medias oculta el cartel")
	wall.queue_free()
	_check(await _await_until(func() -> bool: return hint.visible), "Quitar la pared devuelve el cartel")
	player.position = Vector3(0, 0, 3.5)
	_check(await _await_until(func() -> bool: return not hint.visible), "Alejarse retira el cartel")
	print("RESULTADO 3D: %d comprobaciones, %d fallos" % [checks, failures])
	lab.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
