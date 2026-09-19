extends "res://tests/test_laboratory_3d.gd"

const OUTPUT := "res://.local/captures/h2"

func _save(capture_name: String) -> void:
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUTPUT + "/" + capture_name + ".png")
	_check(result == OK, "Captura " + capture_name)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var lab: Node3D = load("res://scenes/world/laboratory_3d.tscn").instantiate()
	lab.get_node("Persistence").enabled = false
	root.add_child(lab)
	await _frames(5)
	var player: CharacterBody3D = lab.get_node("Player")
	var session: Node = lab.get_node("Session")
	var content: VBoxContainer = lab.get_node("HUD/Overlay/Panel/Margin/Content")
	await _save("room")
	player.position = Vector3(-1.8, 0, 0.5)
	await _frames(5)
	await _action(&"interact")
	await _save("terminal")
	await _click(content.get_node("Actions/BuyMatrix"))
	await _click(content.get_node("Actions/BuyCatalyst"))
	await _action(&"ui_cancel")
	player.position = Vector3(2.6, 0, -2.45)
	await _frames(5)
	await _action(&"interact")
	await _click(content.get_node("Actions/Start"))
	await _save("production")
	await _action(&"ui_cancel")
	await _action(&"ui_cancel")
	await _save("pause")
	await _action(&"ui_cancel")
	await _walk([&"move_down"], 25)
	await _save("working-room")
	await _await_until(func() -> bool: return session.batch_state == &"ready", 900)
	player.position = Vector3(2.6, 0, -2.45)
	await _frames(5)
	await _action(&"interact")
	await _save("ready")
	await _click(content.get_node("Actions/Collect"))
	await _action(&"ui_cancel")
	player.position = Vector3(-1.8, 0, 0.5)
	await _frames(5)
	await _action(&"interact")
	await _click(content.get_node("Actions/Deliver"))
	await _save("delivered")
	root.size = Vector2i(960, 720)
	await _save("delivered-960x720")
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
