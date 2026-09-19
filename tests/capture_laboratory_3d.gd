extends SceneTree

# Render the real scene. Run without --headless. Output is deliberately ignored by Git.
const OUTPUT := "res://.local/captures/h1-3d"

func _initialize() -> void:
	_capture.call_deferred()

func _save(name: String) -> void:
	await create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png")
	if result != OK:
		printerr("No se pudo guardar " + name)
		quit(1)
	print("CAPTURA: " + name)

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var scene: PackedScene = load("res://scenes/world/laboratory_3d.tscn")
	var lab: Node3D = scene.instantiate()
	lab.get_node("Persistence").enabled = false
	root.add_child(lab)
	var player: CharacterBody3D = lab.get_node("Player")
	var terminal: Area3D = lab.get_node("Terminal")
	await _save("room")
	for view in [
		{"name": "down-right", "x": "move_right", "y": "move_down"},
		{"name": "down-left", "x": "move_left", "y": "move_down"},
		{"name": "up-right", "x": "move_right", "y": "move_up"},
		{"name": "up-left", "x": "move_left", "y": "move_up"},
	]:
		player.position = Vector3(0, 0, 2.5)
		Input.action_press(view.x)
		Input.action_press(view.y)
		await _save("walk-" + view.name)
		Input.action_release(view.x)
		Input.action_release(view.y)
		await _save("idle-" + view.name)
	for view in [{"name": "desk-front", "offset": Vector3(0, 0, 1.0)}, {"name": "desk-behind", "offset": Vector3(0, 0, -1.0)}, {"name": "desk-left", "offset": Vector3(-1.2, 0, 0)}, {"name": "desk-right", "offset": Vector3(1.2, 0, 0)}]:
		player.position = terminal.position + view.offset
		await _save(view.name)
	for view in [{"name": "edge-north", "position": Vector3(0, 0, -4.6)}, {"name": "edge-south", "position": Vector3(0, 0, 4.6)}, {"name": "edge-west", "position": Vector3(-4.6, 0, 2)}, {"name": "edge-east", "position": Vector3(4.6, 0, 2)}]:
		player.position = view.position
		await _save(view.name)
	player.position = terminal.position + Vector3(0, 0, 1.4)
	await create_timer(0.15).timeout
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	Input.parse_input_event(event)
	await _save("panel")
	# Viewport captures remain 640x360 under integer scaling. Print actual window
	# dimensions and transform so letterboxing can also be checked externally.
	for dimensions in [Vector2i(960, 720), Vector2i(1440, 900), Vector2i(640, 360)]:
		root.size = dimensions
		await _save("panel-%dx%d" % [dimensions.x, dimensions.y])
		print("WINDOW ", root.size, " CONTENT ", root.content_scale_size, " SCREEN_TRANSFORM ", root.get_screen_transform())
	lab.queue_free()
	await process_frame
	quit()
