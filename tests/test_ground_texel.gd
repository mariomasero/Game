extends SceneTree

## Exactitud de texel del suelo, sin GPU.
##
## unproject_position es matematica pura y funciona headless, asi que la
## correspondencia de un texel con un pixel se puede afirmar sin dibujar nada.
##
## De la camara de _place_camera (ortografica, size = 540/32, rotacion -p,
## posicion (0, 24 sin p, 24 cos p)) sale, para un punto del plano y=0:
##
##     pantalla_x = 480 + 32 * x_mundo
##     pantalla_y = 270 + 32 * sin(p) * z_mundo
##
## La posicion de la camara se cancela entera. Y como la profundidad de celda es
## 1/sin(p), la tesela T(i,j) -- que va media celda al noroeste de la logica --
## ocupa siempre Rect2(480 + 32i - 16, 270 + 32j - 16, 32, 32), sea cual sea la
## inclinacion. Ahi esta la demostracion de que la compensacion anisotropa
## sobrevive al cambio de arquitectura y de que el desplazamiento de media celda
## cae en 16 pixeles enteros.
##
##   godot --headless --path . --script tests/test_ground_texel.gd

const ESCENA := "res://scenes/world/test_room.tscn"
const VIEWPORT := Vector2(960.0, 540.0)
const INCLINACIONES: Array[float] = [45.0, 55.0, 65.0, 75.0]

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
	else:
		print("PASS: " + message)

func _run() -> void:
	# Con stretch/mode="viewport" esto es lo que ve unproject_position. Si no
	# mide lo que creemos, todo lo demas miente.
	_check(root.get_visible_rect().size.is_equal_approx(VIEWPORT),
		"El viewport mide %s" % VIEWPORT)

	for pitch in INCLINACIONES:
		await _comprueba_inclinacion(pitch)

	print("RESULTADO TEXEL SUELO: %d comprobaciones, %d fallos" % [checks, failures])
	quit(1 if failures else 0)

func _comprueba_inclinacion(pitch: float) -> void:
	var escena: PackedScene = load(ESCENA)
	var sala := escena.instantiate()
	# Antes de add_child, para que _ready construya con este valor.
	sala.set("pitch_degrees", pitch)
	root.add_child(sala)
	await process_frame

	var camara: Camera3D = sala.get_node("Camera3D")
	var suelo: MeshInstance3D = sala.get_node("Ground")
	var escala := suelo.global_transform.basis

	# Teselas con i y j negativos y positivos, y de los cuatro bordes del rango.
	var muestras: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(-7, -5), Vector2i(6, 4),
		Vector2i(-12, 3), Vector2i(11, -6),
	]
	var maximo := 0.0
	var enteras := true
	for t in muestras:
		var rect := _rect_en_pantalla(camara, escala, t)
		var esperado := Rect2(480.0 + 32.0 * t.x - 16.0, 270.0 + 32.0 * t.y - 16.0,
			32.0, 32.0)
		maximo = maxf(maximo, (rect.position - esperado.position).length())
		maximo = maxf(maximo, (rect.size - esperado.size).length())
		for v in [rect.position.x, rect.position.y, rect.size.x, rect.size.y]:
			if absf(v - roundf(v)) > 0.001:
				enteras = false
	_check(maximo < 0.01,
		"A %.0f grados cada tesela cae donde toca (desvio maximo %.4f px)" % [
			pitch, maximo])
	_check(enteras,
		"A %.0f grados las coordenadas de pantalla son enteras" % pitch)

	# Un paso de tesela son 32 px exactos en los dos ejes. Una tesela aislada no
	# detectaria una escala mal puesta; la diferencia entre dos vecinas si.
	var a := _rect_en_pantalla(camara, escala, Vector2i(0, 0))
	var dx := _rect_en_pantalla(camara, escala, Vector2i(1, 0)).position - a.position
	var dz := _rect_en_pantalla(camara, escala, Vector2i(0, 1)).position - a.position
	_check(dx.is_equal_approx(Vector2(32.0, 0.0)),
		"A %.0f grados el paso en i es (32, 0) y vale %s" % [pitch, dx])
	_check(dz.is_equal_approx(Vector2(0.0, 32.0)),
		"A %.0f grados el paso en j es (0, 32) y vale %s" % [pitch, dz])

	sala.queue_free()
	await process_frame

## Rectangulo en pantalla de la tesela (i,j), proyectando sus cuatro esquinas
## reales de la malla, no una formula reimplementada.
func _rect_en_pantalla(camara: Camera3D, escala: Basis, t: Vector2i) -> Rect2:
	var esquinas := [
		Vector3(t.x - 0.5, 0.0, t.y - 0.5), Vector3(t.x - 0.5, 0.0, t.y + 0.5),
		Vector3(t.x + 0.5, 0.0, t.y + 0.5), Vector3(t.x + 0.5, 0.0, t.y - 0.5),
	]
	var minimo := Vector2.INF
	var maximo := -Vector2.INF
	for e in esquinas:
		var p := camara.unproject_position(escala * e)
		minimo = minimo.min(p)
		maximo = maximo.max(p)
	return Rect2(minimo, maximo - minimo)
