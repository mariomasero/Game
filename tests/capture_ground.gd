extends SceneTree

## Captura la sala de pruebas con la camara real, para juzgar el suelo.
##
## NO se ejecuta con --headless: el controlador nulo no dibuja y la imagen sale
## vacia. Eso no significa abrir el editor; es el mismo patron que
## tests/capture_player_animation.gd, un SceneTree que instancia la escena y
## guarda el framebuffer.
##
##   Godot_v4.7.2-stable_win64_console.exe --path . --script tests/capture_ground.gd -- \
##       --out=docs/captures/h6-suelo-base.png [--base]
##
## Banderas:
##   --out=<ruta>  destino del PNG. Obligatoria.
##   --llano       vacia las tres listas de zonas: campo de un solo terreno.
##   --debug       captura para comprobar la SELECCION de tesela, no el arte:
##                 material del suelo sin luz y muros ocultos, para que cada
##                 celda logica quede como un bloque de 32x32 px plano.
##   --sun=off     apaga las sombras del sol.
##   --bias=0      pone shadow_bias y shadow_normal_bias del sol a cero.
##                 Las dos ultimas existen para remedir bajo Forward+ las cifras
##                 que la decision 010 midio bajo GL Compatibility.
##
## Determinismo: el personaje se oculta (el fotograma de reposo varia entre
## ejecuciones) y el fundido de paredes se acelera para que haya convergido.

const ESCENA := "res://scenes/world/test_room.tscn"
const VIEWPORT := Vector2i(960, 540)

var _banderas: Dictionary = {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var partes := arg.substr(2).split("=", true, 1)
		_banderas[partes[0]] = partes[1] if partes.size() > 1 else "1"
	_captura.call_deferred()

func _captura() -> void:
	var destino: String = _banderas.get("out", "")
	if destino.is_empty():
		printerr("Falta --out=<ruta>.")
		quit(1)
		return

	var escena: PackedScene = load(ESCENA)
	if escena == null:
		printerr("No se pudo cargar %s" % ESCENA)
		quit(1)
		return
	var sala := escena.instantiate()

	# Los @export se escriben ANTES de add_child, para que _ready use los valores
	# nuevos y no haya que reconstruir el suelo.
	if _banderas.has("llano"):
		for zona in ["dirt_patches", "cobblestone_patches", "grass_holes"]:
			sala.set(zona, [] as Array[Rect2i])
	sala.set("occluder_fade_time", 0.001)
	root.add_child(sala)

	var jugador := sala.get_node_or_null("Player")
	if jugador != null:
		jugador.visible = false

	if _banderas.has("debug"):
		# Sin luz, la comparacion contra la paleta de depuracion es exacta y no
		# hay que dar margen por el sombreado. Y sin muros no hay nada dibujado
		# por encima del suelo que tape una celda.
		var suelo := sala.get_node_or_null("Ground") as MeshInstance3D
		if suelo != null and suelo.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = suelo.material_override.duplicate()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			suelo.material_override = mat
		for nombre in ["WallsShadow", "WallsSolid", "WallsFaded"]:
			var muro := sala.get_node_or_null(nombre) as Node3D
			if muro != null:
				muro.visible = false

	var sol := sala.get_node_or_null("Sun") as DirectionalLight3D
	if sol != null:
		if _banderas.get("sun", "") == "off":
			sol.shadow_enabled = false
		if _banderas.get("bias", "") == "0":
			sol.shadow_bias = 0.0
			sol.shadow_normal_bias = 0.0

	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw

	var textura := root.get_texture()
	var img: Image = textura.get_image() if textura != null else null
	if img == null or img.get_size() != VIEWPORT:
		printerr(("Imagen %s en vez de %s. Esta captura necesita GPU: " +
			"no pases --headless.") % [
			"nula" if img == null else str(img.get_size()), str(VIEWPORT)])
		quit(1)
		return

	# Con el controlador nulo el tamano puede salir bien y el contenido vacio, asi
	# que hay que mirar el contenido. Se muestrea una rejilla en vez de unos pocos
	# puntos: con un campo de cesped uniforme cuatro sondas sueltas caen todas en
	# el mismo color y darian un falso negativo.
	var colores := {}
	for y in range(0, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			colores[img.get_pixel(x, y)] = true
	if colores.size() < 3:
		printerr("Solo %d colores en la rejilla de muestreo: no se ha dibujado nada." %
			colores.size())
		img.save_png(destino + ".vacia.png")
		quit(1)
		return

	var error := img.save_png(destino)
	if error != OK:
		printerr("save_png(%s) devolvio %d" % [destino, error])
		quit(1)
		return
	print("%s  %s  %d colores distintos en la rejilla de muestreo" % [
		destino, str(img.get_size()), colores.size()])
	quit(0)
