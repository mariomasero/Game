extends SceneTree
## Ejecutar con Godot --main-pack Biotech.pck, --script absoluto y APPDATA aislado.
## No se incluye en el PCK. No carga recursos desde el proyecto fuente.

var checks: int = 0
var failures: int = 0
var cue_refs: Array[WeakRef] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
	print("%s %s" % ["OK" if condition else "FALLO", message])

func _run() -> void:
	var profile := OS.get_environment("BIOTECH_TEST_PROFILE").replace("\\", "/")
	if profile.is_empty() or not OS.get_user_data_dir().begins_with(profile + "/"):
		push_error("Se requiere APPDATA aislado y BIOTECH_TEST_PROFILE coincidente.")
		quit(1)
		return
	_check(not DirAccess.dir_exists_absolute("res://tests"), "Las pruebas no se distribuyen en el PCK")
	_check(not DirAccess.dir_exists_absolute("res://assets/source"), "Las fuentes de autoría no se distribuyen")
	var scene: PackedScene = load("res://scenes/world/laboratory_3d.tscn")
	_check(scene != null, "La escena exportada carga sus dependencias")
	if scene == null:
		quit(1)
		return
	var lab := scene.instantiate()
	root.add_child(lab)
	# El arnés permanece vivo junto a la sala.
	await process_frame
	var state: Node = lab.get_node("Session")
	var persistence: Node = lab.get_node("Persistence")
	var hud: Node = lab.get_node("HUD")
	_check(not persistence.blocked and not persistence.write_failed, "La persistencia inicia correctamente")
	_check(lab.get_node("Terminal/Model").mesh != null, "La malla del ordenador está presente")
	var phase := OS.get_cmdline_user_args()[0]
	if phase == "prepare":
		_check(state.money == 120 and state.completed_orders == 0, "Partida de prueba nueva")
		var player: CharacterBody3D = lab.get_node("Player")
		var start := player.position
		Input.action_press("move_right")
		await create_timer(0.25).timeout
		Input.action_release("move_right")
		_check(player.position.x > start.x, "El personaje responde al movimiento")
		for index in range(3):
			hud.open_station(&"terminal")
			if not state.order_active:
				_press(lab, "Request")
			_press(lab, "BuyMatrix")
			_press(lab, "BuyCatalyst")
			hud.open_station(&"machine")
			_press(lab, "Start")
			if index == 0:
				hud.close_station()
				await create_timer(12.2).timeout
				_check(state.batch_state == &"ready", "La producción termina con tiempo real")
			else:
				state.advance(12.0)
			hud.open_station(&"machine")
			_press(lab, "Collect")
			hud.open_station(&"terminal")
			_press(lab, "Deliver")
		_check(state.money == 165 and state.completed_orders == 3, "Tres pedidos dejan 165 créditos")
		hud.open_station(&"machine")
		_press(lab, "Upgrade")
		_check(state.upgrade_owned and state.money == 65, "La mejora se compra desde la UI exportada")
		hud.open_station(&"terminal")
		_press(lab, "Request")
		_press(lab, "BuyMatrix")
		_press(lab, "BuyCatalyst")
		hud.open_station(&"machine")
		_press(lab, "Start")
		_check(state.batch_duration_seconds == 8.0, "La mejora reduce la duración")
		hud.show_pause()
		var remaining: float = state.remaining_seconds
		await create_timer(0.25, true).timeout
		_check(state.remaining_seconds == remaining, "La pausa conserva el tiempo")
		lab.get_node("HUD/Notifications").toggle_sound()
		await _capture("standalone-pause.png")
	elif phase == "resume":
		paused = true
		_check(state.money == 45 and state.upgrade_owned and state.completed_orders == 3, "Otro proceso recupera saldo, mejora e historial")
		_check(state.batch_state == &"producing" and state.remaining_seconds > 7.5, "El lote continúa sin producción offline")
		_check(lab.get_node("HUD/Notifications").muted, "Otro proceso recupera la preferencia de sonido")
		state.advance(8.0)
		hud.open_station(&"machine")
		_press(lab, "Collect")
		hud.open_station(&"terminal")
		_press(lab, "Deliver")
		_check(state.money == 80 and state.completed_orders == 4, "Se puede completar y cobrar el lote recuperado")
		await _capture("standalone-delivered.png")
	elif phase == "verify":
		_check(state.money == 80 and not state.order_active and state.count_item(&"lumen") == 0, "Un tercer proceso no duplica producto ni cobro")
		await _capture("standalone-room.png")
	else:
		_check(false, "Fase desconocida")
	_check(persistence.save_now().is_empty(), "Guardado final sin errores")
	_remember_audio(lab)
	lab.queue_free()
	await process_frame
	paused = false
	# AudioServer libera las reproducciones desde su propio hilo. No salir
	# hasta observar su liberación; un timeout detecta una retención real.
	var audio_deadline := Time.get_ticks_msec() + 1000
	while _audio_alive() and Time.get_ticks_msec() < audio_deadline:
		await create_timer(0.01).timeout
	_check(not _audio_alive(), "Los avisos de audio se liberan antes del cierre del arnés")
	print("RESULTADO EXPORTADO %s: %d comprobaciones, %d fallos" % [phase, checks, failures])
	quit(1 if failures else 0)

func _press(lab: Node, button: String) -> void:
	lab.get_node("HUD/Overlay/Panel/Margin/Content/Actions/" + button).pressed.emit()
	_remember_audio(lab)

func _remember_audio(lab: Node) -> void:
	var player: AudioStreamPlayer = lab.get_node("HUD/Notifications/CuePlayer")
	if player.stream != null:
		cue_refs.append(weakref(player.stream))

func _audio_alive() -> bool:
	for reference in cue_refs:
		if reference.get_ref() != null:
			return true
	return false

func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var folder := OS.get_environment("BIOTECH_TEST_OUTPUT")
	_check(root.get_texture().get_image().save_png(folder.path_join(filename)) == OK, "Captura real: " + filename)
