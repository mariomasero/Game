extends SceneTree

# Render-only contact sheet for checking atlas crops, feet and mirrored views.
func _initialize() -> void:
	_capture.call_deferred()

func _label(text: String, position: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", 14)
	root.add_child(label)

func _capture() -> void:
	var frames: SpriteFrames = load("res://scenes/player/player_frames.tres")
	_label("REPOSO · 4 fotogramas", Vector2(160, 8))
	_label("CAMINAR · 4 fotogramas", Vector2(460, 8))
	_label("REFLEJO", Vector2(780, 8))
	var directions: Array[String] = ["down", "down_side", "side", "up_side", "up"]
	for row in range(directions.size()):
		_label(directions[row], Vector2(12, 64 + row * 96))
		for column in range(10):
			var sprite := AnimatedSprite2D.new()
			sprite.sprite_frames = frames
			sprite.animation = StringName(("idle_" if column < 4 else "walk_") + directions[row])
			sprite.frame = column % 4
			sprite.flip_h = column >= 8
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.scale = Vector2(2, 2)
			sprite.position = Vector2(145 + column * 76, 64 + row * 96)
			root.add_child(sprite)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://.godot/player-animation-preview.png")
	quit(0 if error == OK else 1)
