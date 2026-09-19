extends SceneTree
## Escenario técnico automatizado sobre --main-pack. No mide diversión ni interacción humana.

var lab: Node
var start_usec: int
var last_usec: int
var samples: Array[float] = []
var memory_samples: Array[int] = []
var measuring: bool = false
var last_direction: StringName = &""
var last_report_second: int = -1
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _require(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var profile := OS.get_environment("BIOTECH_TEST_PROFILE").replace("\\", "/")
	if profile.is_empty() or not OS.get_user_data_dir().begins_with(profile + "/"):
		push_error("Se requiere un perfil de prueba aislado.")
		quit(1)
		return
	var output := OS.get_environment("BIOTECH_TEST_OUTPUT")
	if output.is_empty() or DisplayServer.get_name() == "headless":
		push_error("La medición requiere gráficos y un directorio de resultados.")
		quit(1)
		return
	lab = load("res://scenes/world/laboratory_3d.tscn").instantiate()
	root.add_child(lab)
	var state: Node = lab.get_node("Session")
	var persistence: Node = lab.get_node("Persistence")
	var hud: Node = lab.get_node("HUD")
	if state.completed_orders != 0 or persistence.blocked:
		push_error("La medición requiere una partida nueva.")
		quit(1)
		return
	await create_timer(2.0).timeout
	start_usec = Time.get_ticks_usec()
	last_usec = start_usec
	measuring = true
	process_frame.connect(_sample)
	while Time.get_ticks_usec() - start_usec < 180_000_000:
		hud.open_station(&"terminal")
		if not state.order_active:
			_press("Request")
		_press("BuyMatrix")
		_press("BuyCatalyst")
		await create_timer(0.3).timeout
		hud.open_station(&"machine")
		if state.completed_orders == 3 and not state.upgrade_owned:
			_press("Upgrade")
		_press("Start")
		hud.close_station()
		if state.completed_orders == 2:
			hud.show_pause()
			var remaining: float = state.remaining_seconds
			await create_timer(1.0, true).timeout
			_require(state.remaining_seconds == remaining, "La pausa debe detener la producción")
			hud.get_node("PauseOverlay/Panel/Content/Resume").pressed.emit()
		while state.batch_state == &"producing":
			await create_timer(0.1).timeout
		_require(state.batch_state == &"ready", "La producción debe terminar")
		hud.open_station(&"machine")
		_press("Collect")
		hud.open_station(&"terminal")
		_press("Deliver")
		await create_timer(0.3).timeout
		hud.close_station()
		if failures:
			break
	measuring = false
	_release_direction()
	_require(state.upgrade_owned and state.completed_orders >= 15, "La sesión debe completar al menos 15 pedidos y una mejora")
	_require(state.money == 120 + 15 * state.completed_orders - 100, "El saldo debe cuadrar con los pedidos y la mejora")
	_require(not persistence.write_failed and persistence.save_now().is_empty(), "El autoguardado debe seguir funcionando")
	samples.sort()
	var report := {
		"engine": Engine.get_version_info().string,
		"os": OS.get_name(), "cpu": OS.get_processor_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"window": str(DisplayServer.window_get_size()), "viewport": str(root.get_visible_rect().size),
		"renderer": RenderingServer.get_current_rendering_method(),
		"frame_cap": Engine.max_fps, "vsync": DisplayServer.window_get_vsync_mode(),
		"duration_seconds": (Time.get_ticks_usec() - start_usec) / 1_000_000.0,
		"sampled_frames": samples.size(), "frame_ms_p50": _percentile(0.50),
		"frame_ms_p95": _percentile(0.95), "frame_ms_p99": _percentile(0.99),
		"frame_ms_max": samples.back(), "static_memory_bytes_by_second": memory_samples,
		"completed_orders": state.completed_orders, "money": state.money, "failures": failures,
		"scope": "Motor con PCK release; UI por señales, movimiento por acciones; tiempos reales; sin telemetría remota."
	}
	var file := FileAccess.open(output.path_join("session.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("SESION: ", JSON.stringify(report))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("session-end.png"))
	var audio: AudioStreamPlayer = lab.get_node("HUD/Notifications/CuePlayer")
	var audio_ref: WeakRef = weakref(audio.stream) if audio.stream != null else null
	lab.queue_free()
	await process_frame
	var deadline := Time.get_ticks_msec() + 1000
	while audio_ref != null and audio_ref.get_ref() != null and Time.get_ticks_msec() < deadline:
		await create_timer(0.01).timeout
	quit(1 if failures else 0)

func _press(button: String) -> void:
	lab.get_node("HUD/Overlay/Panel/Margin/Content/Actions/" + button).pressed.emit()

func _sample() -> void:
	if not measuring:
		return
	var now := Time.get_ticks_usec()
	samples.append((now - last_usec) / 1000.0)
	last_usec = now
	var second := int((now - start_usec) / 1_000_000)
	if second != last_report_second:
		memory_samples.append(int(Performance.get_monitor(Performance.MEMORY_STATIC)))
		if second % 30 == 0:
			print("PROGRESO: %d s, %d pedidos" % [second, lab.get_node("Session").completed_orders])
		last_report_second = second
	var direction: StringName = [&"move_left", &"move_up", &"move_right", &"move_down"][second % 4]
	if paused or lab.get_node("HUD/Overlay").visible:
		direction = &""
	if direction != last_direction:
		_release_direction()
		last_direction = direction
		if not direction.is_empty():
			Input.action_press(direction)

func _release_direction() -> void:
	if not last_direction.is_empty():
		Input.action_release(last_direction)
	last_direction = &""

func _percentile(fraction: float) -> float:
	return samples[mini(int(ceil(samples.size() * fraction)) - 1, samples.size() - 1)]
