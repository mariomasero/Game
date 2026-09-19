extends "res://tests/test_laboratory_3d.gd"

const OUTPUT := "res://.local/captures/h4-feedback"

func _save(capture_name: String) -> void:
	await create_timer(0.15, true).timeout
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUTPUT + "/" + capture_name + ".png")
	_check(result == OK, "Captura " + capture_name)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var lab: Node3D = load("res://scenes/world/laboratory_3d.tscn").instantiate()
	lab.get_node("Persistence").enabled = false
	root.add_child(lab)
	var state: Node = lab.get_node("Session")
	state.buy(&"matrix")
	state.buy(&"catalyst")
	state.start_batch()
	await _frames(5)
	state.advance(12.0)
	await _save("batch-ready")
	await _action(&"ui_cancel")
	await _click(lab.get_node("HUD/PauseOverlay/Panel/Content/Sound"))
	await _save("sound-muted")
	# Exercise the largest pause layout without creating an actual disk problem.
	lab.get_node("Persistence").write_failed = true
	lab.get_node("Persistence").status_message = "No se pudo guardar. Reintenta antes de salir."
	lab.get_node("Persistence").status_changed.emit()
	await _save("save-error-controls")
	var cue_script: Script = load("res://scripts/presentation/lab_cues.gd")
	for kind: StringName in [&"success", &"start", &"cash", &"ready", &"upgrade", &"error"]:
		var cue: AudioStreamWAV = cue_script.make_cue(kind)
		_check(cue.save_to_wav(OUTPUT + "/" + String(kind) + ".wav") == OK, "Exporta muestra audible " + String(kind))
	lab.queue_free()
	await process_frame
	paused = false
	quit(1 if failures else 0)
