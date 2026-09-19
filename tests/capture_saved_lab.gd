extends "res://tests/test_laboratory_3d.gd"

const OUTPUT := "res://.local/captures/h3"

func _save(capture_name: String) -> void:
	await create_timer(0.15, true).timeout
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUTPUT + "/" + capture_name + ".png")
	_check(result == OK, "Captura " + capture_name)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var save_path := "user://test_capture_h3_%d/slot.json" % Time.get_ticks_usec()
	var packed: PackedScene = load("res://scenes/world/laboratory_3d.tscn")
	var lab: Node3D = packed.instantiate()
	lab.get_node("Persistence").save_path = save_path
	root.add_child(lab)
	var state: Node = lab.get_node("Session")
	var player: CharacterBody3D = lab.get_node("Player")
	player.position = Vector3(2.6, 0, -2.45)
	await _frames(5)
	await _action(&"interact")
	await _save("upgrade-locked")
	await _action(&"ui_cancel")
	for cycle in range(3):
		if not state.order_active:
			state.request_order()
		state.buy(&"matrix")
		state.buy(&"catalyst")
		state.start_batch()
		state.advance(12.0)
		state.collect_batch()
		state.deliver_order(state.order_id)
	await _action(&"interact")
	var content: VBoxContainer = lab.get_node("HUD/Overlay/Panel/Margin/Content")
	await _save("upgrade-available")
	await _click(content.get_node("Actions/Upgrade"))
	await _save("upgraded")
	state.request_order()
	state.buy(&"matrix")
	state.buy(&"catalyst")
	await _click(content.get_node("Actions/Start"))
	await _save("upgraded-production")
	await _action(&"ui_cancel")
	await _action(&"ui_cancel")
	await _save("saved-pause")
	await _click(lab.get_node("HUD/PauseOverlay/Panel/Content/NewGame"))
	await _save("new-game-confirm")
	lab.queue_free()
	await process_frame
	var corrupt := FileAccess.open(save_path, FileAccess.WRITE)
	corrupt.store_string("test broken")
	corrupt.close()
	lab = packed.instantiate()
	lab.get_node("Persistence").save_path = save_path
	root.add_child(lab)
	await _save("recovery")
	await _click(lab.get_node("HUD/PauseOverlay/Panel/Content/Recover"))
	await _save("recovered")
	lab.queue_free()
	await process_frame
	paused = false
	quit(1 if failures else 0)
