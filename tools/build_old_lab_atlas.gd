extends SceneTree

## Atlas de la casa del laboratorio viejo (scenes/village/props/laboratorio_viejo.tscn).
##
## El .obj del 28 de septiembre llego sin su atlas: casa_laboratorio.mtl pide
## casa_laboratorio_atlas.png y no estaba en ningun sitio. El .obj sale de tallar
## vóxeles con las seis vistas de assets/source/props/old_laboratory/
## casa_pixzels_ortho.png -- medido: los 224 108 texeles de sus caras caen todos
## sobre un pixel opaco de la vista de su lado --, asi que el atlas se rehace sin
## inventar nada: cada texel de cada cara copia el pixel de la vista hacia la que
## mira la cara (la de +Z, el frente; la de +Y, la planta...).
##
## Comprueba al escribir: que cada cara es un rectangulo con su UV a 1 texel por
## voxel, que ninguna pisa a otra en el atlas, que todo cae en pixeles opacos de
## su vista y que solo salen colores de casa_laboratorio.gpl.
##
## Si llega un .obj nuevo con su propio atlas, no hace falta: se copia el atlas
## junto al .obj y listo. Si llega sin el, se vuelve a ejecutar.
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tools/build_old_lab_atlas.gd

const OBJ := "res://assets/game/models/old_laboratory/casa_laboratorio.obj"
const ATLAS := "res://assets/game/models/old_laboratory/casa_laboratorio_atlas.png"
const HOJA := "res://assets/source/props/old_laboratory/casa_pixzels_ortho.png"
const PALETA := "res://assets/source/props/old_laboratory/casa_laboratorio.gpl"

## Lo que miden las UV del .obj: 0,5/1024 en u y caras de n voxeles que ocupan
## n/1024 en u y n/512 en v.
const ANCHO := 1024
const ALTO := 512
## El .obj esta en unidades (1 voxel = 1/32).
const VOXEL := 32.0
## Celdas de 256 x 256 de la hoja, en este orden. Cada vista va centrada en la
## suya: el frente ocupa las filas 32..223, con el suelo en la 223.
enum Vista { FRENTE, ESTE, TRASERA, OESTE, PLANTA, SUELO }
const CELDA := 256

func _initialize() -> void:
	var ok := _construir()
	print("RESULTADO ATLAS LABORATORIO: " + ("escrito" if ok else "FALLO"))
	quit(0 if ok else 1)

func _construir() -> bool:
	var hoja := Image.load_from_file(ProjectSettings.globalize_path(HOJA))
	if hoja == null or hoja.get_size() != Vector2i(CELDA * 6, CELDA):
		printerr("%s tiene que medir %dx%d" % [HOJA, CELDA * 6, CELDA])
		return false
	hoja.convert(Image.FORMAT_RGBA8)
	var paleta := _paleta()
	if paleta.is_empty():
		return false
	var texto := FileAccess.get_file_as_string(OBJ)
	if texto.is_empty():
		printerr("No se pudo leer %s" % OBJ)
		return false
	var v: Array[Vector3i] = []
	var vt: Array[Vector2] = []
	var vn: Array[Vector3i] = []
	var caras: Array[PackedStringArray] = []
	for linea in texto.split("\n"):
		var p := linea.strip_edges().split(" ", false)
		if p.is_empty():
			continue
		match p[0]:
			"v":
				v.append(Vector3i(roundi(p[1].to_float() * VOXEL),
					roundi(p[2].to_float() * VOXEL), roundi(p[3].to_float() * VOXEL)))
			"vt":
				vt.append(Vector2(p[1].to_float(), p[2].to_float()))
			"vn":
				vn.append(Vector3i(p[1].to_int(), p[2].to_int(), p[3].to_int()))
			"f":
				caras.append(p.slice(1))

	var atlas := Image.create(ANCHO, ALTO, false, Image.FORMAT_RGBA8)
	var escritos := {}
	var fallos := 0
	for cara in caras:
		if cara.size() != 4:
			printerr("Cara de %d vertices; se esperan cuadrados" % cara.size())
			return false
		var pos: Array[Vector3i] = []
		var uv: Array[Vector2] = []
		var n := Vector3i.ZERO
		for esquina in cara:
			var i := esquina.split("/")
			pos.append(v[i[0].to_int() - 1])
			uv.append(vt[i[1].to_int() - 1])
			n = vn[i[2].to_int() - 1]
		fallos += _pintar_cara(pos, uv, n, hoja, atlas, escritos, paleta)
	if fallos > 0:
		printerr("%d texeles no cuadran; el atlas no se escribe" % fallos)
		return false
	if atlas.save_png(ProjectSettings.globalize_path(ATLAS)) != OK:
		printerr("No se pudo escribir %s" % ATLAS)
		return false
	print("%d caras, %d texeles pintados" % [caras.size(), escritos.size()])
	return true

## Copia la vista a la cara. Devuelve cuantos texeles fallan alguna comprobacion.
func _pintar_cara(pos: Array[Vector3i], uv: Array[Vector2], n: Vector3i,
		hoja: Image, atlas: Image, escritos: Dictionary, paleta: Dictionary) -> int:
	var eje := 0 if n.x != 0 else (1 if n.y != 0 else 2)
	var a := (eje + 1) % 3
	var b := (eje + 2) % 3
	# UV = uv0 + J * (p - p0), con J sacado de dos lados del cuadrado.
	var d1 := Vector2(pos[1][a] - pos[0][a], pos[1][b] - pos[0][b])
	var d2 := Vector2(pos[3][a] - pos[0][a], pos[3][b] - pos[0][b])
	var e1 := (uv[1] - uv[0]) * Vector2(ANCHO, ALTO)
	var e2 := (uv[3] - uv[0]) * Vector2(ANCHO, ALTO)
	var det := d1.x * d2.y - d2.x * d1.y
	if is_zero_approx(det):
		printerr("Cara degenerada en %s" % str(pos[0]))
		return 1
	var ja := (e1 * d2.y - e2 * d1.y) / det   # cuanto se mueve la UV por texel en a
	var jb := (e2 * d1.x - e1 * d2.x) / det   # y en b
	# La cuarta esquina tiene que cuadrar: la cara es un rectangulo sin torcer.
	var d3 := Vector2(pos[2][a] - pos[0][a], pos[2][b] - pos[0][b])
	var e3 := (uv[2] - uv[0]) * Vector2(ANCHO, ALTO)
	if not (ja * d3.x + jb * d3.y).is_equal_approx(e3):
		printerr("La UV de la cara en %s no es un rectangulo" % str(pos[0]))
		return 1
	var desde := pos[0].min(pos[1]).min(pos[2]).min(pos[3])
	var hasta := pos[0].max(pos[1]).max(pos[2]).max(pos[3])
	# El voxel de la cara: el de dentro del plano.
	var capa := hasta[eje] - 1 if n[eje] > 0 else desde[eje]
	var fallos := 0
	for i in range(desde[a], hasta[a]):
		for j in range(desde[b], hasta[b]):
			var t := Vector3i.ZERO
			t[eje] = capa
			t[a] = i
			t[b] = j
			var c := Vector2(i + 0.5 - pos[0][a], j + 0.5 - pos[0][b])
			var u := uv[0] * Vector2(ANCHO, ALTO) + ja * c.x + jb * c.y
			var destino := Vector2i(floori(u.x), ALTO - 1 - floori(u.y))
			var origen := _pixel_de_vista(n, t)
			var color := hoja.get_pixelv(origen)
			if color.a8 == 0:
				printerr("Texel %s de la cara %s sin pixel en su vista" % [str(t), str(n)])
				fallos += 1
				continue
			if not paleta.has(color.to_rgba32() | 0xff):
				printerr("Color %s fuera de casa_laboratorio.gpl" % color.to_html(false))
				fallos += 1
			if escritos.has(destino) and escritos[destino] != color:
				printerr("Dos caras pisan el texel %s del atlas" % str(destino))
				fallos += 1
			escritos[destino] = color
			atlas.set_pixelv(destino, color)
	return fallos

## Pixel de la hoja que ve el voxel `t` mirando hacia `n`. Voxeles con el origen
## en el centro de la base: x de -128 a 127, y de 0 a 191, z de -64 a 63.
func _pixel_de_vista(n: Vector3i, t: Vector3i) -> Vector2i:
	var fila := 223 - t.y
	if n == Vector3i(0, 0, 1):
		return Vector2i(Vista.FRENTE * CELDA + t.x + 128, fila)
	if n == Vector3i(0, 0, -1):
		return Vector2i(Vista.TRASERA * CELDA + 127 - t.x, fila)
	# Desde +X el frente (+Z) queda a la izquierda; desde -X, a la derecha.
	if n == Vector3i(1, 0, 0):
		return Vector2i(Vista.ESTE * CELDA + 127 - t.z, fila)
	if n == Vector3i(-1, 0, 0):
		return Vector2i(Vista.OESTE * CELDA + 128 + t.z, fila)
	# La planta con el fondo (-Z) arriba; el suelo, visto desde abajo, al reves.
	if n == Vector3i(0, 1, 0):
		return Vector2i(Vista.PLANTA * CELDA + t.x + 128, 128 + t.z)
	return Vector2i(Vista.SUELO * CELDA + t.x + 128, 127 - t.z)

## Colores de la paleta de GIMP, como RGBA32 opaco.
func _paleta() -> Dictionary:
	var salida := {}
	var texto := FileAccess.get_file_as_string(PALETA)
	for linea in texto.split("\n"):
		# El nombre del color va tras un tabulador.
		var p := linea.replace("\t", " ").strip_edges().split(" ", false)
		if p.size() >= 3 and p[0].is_valid_int() and p[1].is_valid_int() \
				and p[2].is_valid_int():
			salida[Color8(p[0].to_int(), p[1].to_int(), p[2].to_int()).to_rgba32()] = true
	if salida.is_empty():
		printerr("No se pudo leer la paleta %s" % PALETA)
	return salida
