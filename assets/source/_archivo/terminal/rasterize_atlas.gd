extends SceneTree

# Authoring only. Run with Godot --headless --path . --script <this file>.
func _initialize() -> void:
	var source := FileAccess.get_file_as_string("res://assets/source/terminal/terminal_atlas.svg")
	var texture := Image.new()
	var error := texture.load_svg_from_string(source)
	if error == OK:
		error = texture.save_png("res://assets/source/terminal/terminal_atlas.png")
	if error != OK:
		printerr("No se pudo rasterizar el atlas: ", error)
	quit(0 if error == OK else 1)
