class_name DisplayMode
extends RefCounted

## Alterna entre ventana y pantalla completa sin tocar la imagen interna.
##
## El viewport se mantiene en 960x540, que es 16:9 igual que 1920x1080 y
## 3840x2160. Con el escalado entero del proyecto el motor amplia esa imagen
## x2 en Full HD y x4 en 4K, sin deformarla ni dejar barras.

const FULLSCREEN_MODES: Array[DisplayServer.WindowMode] = [
	DisplayServer.WINDOW_MODE_FULLSCREEN,
	DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
]

static func is_available() -> bool:
	return DisplayServer.get_name() != "headless"

static func is_fullscreen() -> bool:
	if not is_available():
		return false
	return DisplayServer.window_get_mode() in FULLSCREEN_MODES

static func toggle_fullscreen() -> void:
	if not is_available():
		return
	var target: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(target)
