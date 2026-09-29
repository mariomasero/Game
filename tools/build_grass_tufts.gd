extends SceneTree

## Genera la hoja PROVISIONAL de matas de hierba, hasta que llegue la dibujada.
##
##   godot --headless --path . --script tools/build_grass_tufts.gd
##
## Escribe assets/game/textures/grass_tufts.png: VARIANTES matas de LADO x LADO
## texeles puestas en fila, con el pie de la mata en la ultima fila y fondo
## transparente. Las dos primeras son bajas y las dos ultimas altas, porque
## test_room.gd reparte las altas hacia el centro de cada mancha. Quien la
## sustituya por arte propio solo tiene que respetar ese formato.
##
## Los colores no se inventan: son verdes de la paleta del proyecto,
## assets/source/palettes/apollo_proyecto.gpl (AGENTS.md, «Arte y assets»),
## copiados aqui. Elegidos por Mario el 29 de septiembre de 2026 al pasar el
## cesped a esa paleta.

## De oscuro a claro: pie, cuerpo y punta de la hoja. El fondo del relleno de
## cesped (Verde 4, 75a743) queda entre el cuerpo y la punta, como antes con
## 78a44b: la punta con Verde 4 se perderia en el suelo.
const PALETA: Array[Color] = [
	Color8(0x25, 0x56, 0x2e),   # pie, donde las hojas se tapan unas a otras (Verde 2)
	Color8(0x46, 0x82, 0x32),   # cuerpo (Verde 3)
	Color8(0xa8, 0xca, 0x58),   # punta (Verde 5)
]

const SALIDA := "res://assets/game/textures/grass_tufts.png"
const LADO := 16
const VARIANTES := 4
const ALTURAS: Array[Vector2i] = [
	Vector2i(5, 8), Vector2i(6, 9), Vector2i(10, 13), Vector2i(11, 14)]

func _initialize() -> void:
	var hoja := Image.create_empty(LADO * VARIANTES, LADO, false, Image.FORMAT_RGBA8)
	hoja.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260923
	for v in VARIANTES:
		_mata(hoja, v * LADO, ALTURAS[v], rng)
	var ruta := ProjectSettings.globalize_path(SALIDA)
	DirAccess.make_dir_recursive_absolute(ruta.get_base_dir())
	hoja.save_png(ruta)
	print("escrito %s" % SALIDA)
	quit()

## Una mata: de cuatro a seis hojas de un texel de ancho que nacen juntas en el
## pie y se abren en abanico. Oscuras abajo, donde se tapan unas a otras, y
## claras en la punta, que es lo que recibe el sol.
func _mata(hoja: Image, x0: int, alturas: Vector2i, rng: RandomNumberGenerator) -> void:
	var hojas := rng.randi_range(4, 6)
	for k in hojas:
		var abanico := (float(k) / float(hojas - 1)) * 2.0 - 1.0   # -1 izquierda, 1 derecha
		var pie := LADO / 2 + int(round(abanico * 3.0))
		var alto := rng.randi_range(alturas.x, alturas.y)
		# Las hojas de fuera se inclinan mas que las del centro.
		var inclinacion := abanico * rng.randf_range(0.25, 0.5)
		for h in alto:
			var t := float(h) / float(alto - 1)
			var x := pie + int(round(inclinacion * h))
			var y := LADO - 1 - h
			if x < 0 or x >= LADO:
				continue
			hoja.set_pixel(x0 + x, y, _tono(t))

## Tono a lo largo de la hoja: t = 0 en el pie, 1 en la punta.
func _tono(t: float) -> Color:
	if t < 0.3:
		return PALETA[0]
	if t < 0.6:
		return PALETA[1]
	return PALETA[2]
