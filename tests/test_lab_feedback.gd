extends "res://tests/test_laboratory_3d.gd"

func _run() -> void:
	var lab: Node3D = load("res://scenes/world/laboratory_3d.tscn").instantiate()
	lab.get_node("Persistence").enabled = false
	root.add_child(lab)
	await _frames(5)
	var hud: CanvasLayer = lab.get_node("HUD")
	_check(hud.has_node("Notifications"), "La sala incluye avisos de operaciones")
	if not hud.has_node("Notifications"):
		lab.queue_free()
		await process_frame
		quit(1)
		return
	var notices: Control = hud.get_node("Notifications")
	var cue_player: AudioStreamPlayer = notices.get_node("CuePlayer")
	var label: Label = notices.get_node("Toast/Margin/Text")
	var session: Node = lab.get_node("Session")
	var player: CharacterBody3D = lab.get_node("Player")
	var content: VBoxContainer = hud.get_node("Overlay/Panel/Margin/Content")
	player.position = Vector3(-1.8, 0, 0.5)
	await _frames(5)
	await _action(&"interact")
	await _click(content.get_node("Actions/BuyMatrix"))
	_check(label.text.contains("matriz") and cue_player.playing, "Comprar confirma el insumo con texto y sonido")
	_check(hud.get_node("Subtitle").text.contains("catalizador") and not hud.get_node("Subtitle").text.contains("matriz"), "La guía pide solo el ingrediente que falta")
	await _action(&"ui_cancel")
	_check(notices.get_node("Toast").visible, "El aviso permanece visible al volver a la sala")
	session.buy(&"catalyst")
	session.start_batch()
	session.advance(12.0)
	await process_frame
	_check(label.text.contains("Lote listo") and cue_player.playing, "La máquina avisa al terminar sin tener el panel abierto")
	var codec: Script = load("res://scripts/persistence/lab_snapshot.gd")
	var ready_snapshot: Dictionary = codec.capture(session)
	await create_timer(0.1).timeout
	var elapsed := cue_player.get_playback_position()
	session.changed.emit()
	await create_timer(0.08).timeout
	_check(elapsed > 0.03 and cue_player.get_playback_position() > elapsed, "Actualizar la UI no reinicia el aviso sonoro de lote listo")
	var settings_path := "user://test_feedback_%d/audio.cfg" % Time.get_ticks_usec()
	notices.configure_settings(settings_path)
	await _action(&"ui_cancel")
	await _click(hud.get_node("PauseOverlay/Panel/Content/Sound"))
	_check(notices.muted and not cue_player.playing, "Silenciar detiene el sonido actual")
	var stored := ConfigFile.new()
	_check(stored.load(settings_path) == OK and stored.get_value("audio", "muted") == true, "La preferencia se guarda separada de la partida")
	notices.muted = false
	notices.configure_settings(settings_path)
	_check(notices.muted, "Recargar ajustes conserva el silencio")
	await _action(&"ui_cancel")
	player.position = Vector3(-1.8, 0, 0.5)
	await _frames(5)
	await _action(&"interact")
	await _click(content.get_node("Actions/Deliver"))
	_check(not cue_player.playing and not content.get_node("Feedback").text.is_empty(), "Una operación inválida sigue explicándose al estar silenciado")
	await _action(&"ui_cancel")
	await _action(&"ui_cancel")
	await _click(hud.get_node("PauseOverlay/Panel/Content/Sound"))
	_check(not notices.muted, "El mismo control permite volver a activar el sonido")
	await _action(&"ui_cancel")
	session.collect_batch()
	session.deliver_order(1)
	session.request_order()
	session.money = 0
	session.inventory[&"matrix"] = 10
	await process_frame
	_check(hud.get_node("Subtitle").text.to_lower().contains("devuelve"), "La guía explica cómo recuperar una compra mal repartida")
	session.completed_orders = 3
	session.money = 20
	session.inventory[&"matrix"] = 0
	await process_frame
	_check(not hud.get_node("Subtitle").text.contains("Calibra"), "No recomienda una mejora inasequible")
	lab.queue_free()
	await process_frame
	var restored: Node3D = load("res://scenes/world/laboratory_3d.tscn").instantiate()
	restored.get_node("Persistence").enabled = false
	root.add_child(restored)
	codec.apply(restored.get_node("Session"), ready_snapshot)
	await process_frame
	_check(not restored.get_node("HUD/Notifications/CuePlayer").playing, "Cargar un lote ya listo no repite el sonido de finalización")
	restored.queue_free()
	await process_frame
	print("RESULTADO AVISOS: %d comprobaciones, %d fallos" % [checks, failures])
	quit(1 if failures else 0)
