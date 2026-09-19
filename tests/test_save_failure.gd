extends "res://tests/test_laboratory_3d.gd"

func _run() -> void:
	var path := "user://test_save_failure_%d/save.json" % Time.get_ticks_usec()
	var lab: Node3D = load("res://scenes/world/laboratory_3d.tscn").instantiate()
	lab.get_node("Persistence").save_path = path
	root.add_child(lab)
	await _frames(3)
	var state: Node = lab.get_node("Session")
	var persistence: Node = lab.get_node("Persistence")
	var original := FileAccess.get_file_as_string(path)
	DirAccess.make_dir_absolute(path + ".tmp")
	state.buy(&"matrix")
	_check(paused and persistence.write_failed, "Una escritura fallida pausa y avisa")
	_check(FileAccess.get_file_as_string(path) == original, "El error conserva la última partida válida")
	_check(lab.get_node("HUD/PauseOverlay/Panel/Content/Retry").visible, "La interfaz permite reintentar")
	DirAccess.remove_absolute(path + ".tmp")
	# Let containers place the newly revealed retry button before physical input.
	await process_frame
	await process_frame
	await _click(lab.get_node("HUD/PauseOverlay/Panel/Content/Retry"))
	var recovered: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(not persistence.write_failed and recovered.money == 108 and recovered.inventory.matrix == 1, "Reintentar conserva también los cambios en memoria")
	await _action(&"ui_cancel")
	state.buy(&"catalyst")
	state.start_batch()
	state.advance(2.0)
	var remaining: float = state.remaining_seconds
	# Exercise the same Window signal as the OS close button. Quit is deferred
	# to the end of the frame, allowing us to inspect the save synchronously.
	root.close_requested.emit()
	var closing: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(is_equal_approx(closing.batch.remaining_seconds, remaining), "Cerrar la ventana guarda el tiempo más reciente")
	lab.free()
	print("RESULTADO FALLOS GUARDADO: %d comprobaciones, %d fallos" % [checks, failures])
	quit(1 if failures else 0)
