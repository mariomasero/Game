extends "res://tests/test_laboratory_3d.gd"

var save_path: String

func _open_lab() -> Node3D:
	var lab: Node3D = load("res://scenes/world/laboratory_3d.tscn").instantiate()
	lab.get_node("Persistence").save_path = save_path
	root.add_child(lab)
	await process_frame
	return lab

func _run() -> void:
	var scene: PackedScene = load("res://scenes/world/laboratory_3d.tscn")
	var probe := scene.instantiate()
	_check(probe.has_node("Persistence"), "La sala integra guardado y carga")
	probe.free()
	if failures:
		quit(1)
		return
	save_path = "user://test_saved_lab_%d/slot.json" % Time.get_ticks_usec()
	var lab: Node3D = await _open_lab()
	var state: Node = lab.get_node("Session")
	for index in range(3):
		if not state.order_active:
			state.request_order()
		state.buy(&"matrix")
		state.buy(&"catalyst")
		state.start_batch()
		state.advance(12.0)
		state.collect_batch()
		state.deliver_order(state.order_id)
	var player: CharacterBody3D = lab.get_node("Player")
	player.position = Vector3(2.6, 0, -2.45)
	await _frames(5)
	await _action(&"interact")
	var content: VBoxContainer = lab.get_node("HUD/Overlay/Panel/Margin/Content")
	await _click(content.get_node("Actions/Upgrade"))
	_check(state.upgrade_owned and state.money == 65, "La mejora se compra desde la máquina")
	state.request_order()
	state.buy(&"matrix")
	state.buy(&"catalyst")
	await _click(content.get_node("Actions/Start"))
	_check(state.remaining_seconds > 7 and state.remaining_seconds <= 8, "La mejora acelera el lote real")
	await create_timer(5.1).timeout
	var periodic: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	_check(periodic.batch.remaining_seconds < 3.1 and periodic.batch.remaining_seconds > 0, "El autoguardado periódico conserva el progreso sin una nueva transacción")
	await _action(&"ui_cancel")
	await _action(&"ui_cancel")
	var paused_remaining: float = state.remaining_seconds
	_check(FileAccess.file_exists(save_path), "Las transacciones crean una partida en la ruta aislada")
	lab.queue_free()
	await process_frame
	await create_timer(0.2, true).timeout
	lab = await _open_lab()
	state = lab.get_node("Session")
	_check(state.money == 45 and state.upgrade_owned, "Reabrir conserva saldo y mejora")
	_check(is_equal_approx(state.remaining_seconds, paused_remaining), "Reabrir conserva el tiempo sin producción offline")
	_check(state.count_item(&"matrix") == 0 and state.completed_orders == 3, "Reabrir conserva consumos e historial")
	paused = false
	state.advance(20.0)
	state.collect_batch()
	state.deliver_order(4)
	lab.queue_free()
	await process_frame
	lab = await _open_lab()
	state = lab.get_node("Session")
	_check(state.money == 80 and not state.order_active and state.count_item(&"lumen") == 0, "Reabrir tras cobrar no duplica muestra ni pago")
	lab.queue_free()
	await process_frame
	var broken := FileAccess.open(save_path, FileAccess.WRITE)
	broken.store_string("partida dañada de prueba")
	broken.close()
	lab = await _open_lab()
	_check(paused and lab.get_node("Persistence").blocked, "Un archivo dañado abre recuperación sin jugar una partida vacía")
	await _action(&"ui_cancel")
	_check(paused and FileAccess.get_file_as_string(save_path) == "partida dañada de prueba", "Escape no sobrescribe ni esquiva la recuperación")
	var pause_ui: VBoxContainer = lab.get_node("HUD/PauseOverlay/Panel/Content")
	await _click(pause_ui.get_node("Recover"))
	_check(not lab.get_node("Persistence").blocked, "Recuperar copia restaura una partida válida")
	await _click(pause_ui.get_node("NewGame"))
	_check(pause_ui.get_node("ConfirmNew").visible, "Nueva partida exige confirmación dentro del juego")
	await _click(pause_ui.get_node("ConfirmNew/Cancel"))
	_check(not pause_ui.get_node("ConfirmNew").visible, "Cancelar conserva la partida actual")
	await _click(pause_ui.get_node("NewGame"))
	await _click(pause_ui.get_node("ConfirmNew/Confirm"))
	state = lab.get_node("Session")
	_check(state.money == 120 and state.completed_orders == 0 and not state.upgrade_owned, "Confirmar inicia una partida nueva coherente")
	lab.queue_free()
	await process_frame
	paused = false
	print("RESULTADO PARTIDA: %d comprobaciones, %d fallos" % [checks, failures])
	quit(1 if failures else 0)
