extends SceneTree

## Hornea el atlas de suelo a partir de GroundAtlas.all_cells().
##
##   godot --headless --path . --script tools/build_ground_atlas.gd -- --modo=marcador
##
## Modos:
##   normal      Usa el arte de assets/source/tilesets/ground/fill_<id>_128.png.
##               El terreno que aun no tenga el suyo cae a su *_top.png, como
##               en marcador, y lo dice.
##   marcador    Deriva los rellenos de los *_top.png de 32x32 que ya existen,
##               repitiendolos 4x4. Sirve para ejercitar la tuberia entera antes
##               de que haya una sola pieza de arte nueva.
##   depuracion  Un color plano por terreno y cuatro cuadrantes planos por
##               transicion, sin arte. Comprueba la SELECCION de tesela con
##               independencia del arte: con este atlas, cada celda logica tiene
##               que salir en pantalla como un bloque de 32x32 px uniforme.
##               Escribe en una ruta distinta a proposito.
##
## Las 42 piezas de transicion no se dibujan: son una silueta de 1 bit aplicada a
## dos rellenos, y la silueta la genera scripts/presentation/ground_silhouette.gd. La misma
## coleccion sirve para las tres parejas.
##
## LA VENTANA DE RELLENO VA DESPLAZADA MEDIA CELDA. La tesela T(i,j) cubre el
## mundo de i-0,5 a i+0,5, asi que su texel u esta en la columna global
## 32i-16+u. El relleno se repite cada 128 texeles, luego la ventana que le toca
## empieza en posmod(32*fase-16, 128) y no en 32*fase. Si se usara la ventana
## alineada a celda, el patron daria un salto de 16 pixeles entre una tesela de
## relleno y su vecina de transicion, que es justo la costura que este trabajo
## viene a quitar.
##
## Este atlas no pasa por PixZels y no se transpone nada: las UV las escribe el
## juego desde GroundAtlas. No anadir su salida a la tabla BLOQUES de
## tools/fix_block_atlas_orientation.gd -- alli solo entran atlas de seis caras
## de PixZels, que miden 85x99.
##
## La composicion se hace entera en memoria y solo se guarda si han pasado todas
## las comprobaciones: un atlas a medio escribir es peor que ninguno.

const Atlas := preload("res://scripts/domain/ground_atlas.gd")
const Silueta := preload("res://scripts/presentation/ground_silhouette.gd")

## Colores de depuracion, separados al menos 32 por canal para que la comparacion
## en la captura admita el redondeo sin ambiguedad.
const COLORES_DEPURACION: Array[Color] = [
	Color8(64, 176, 64), Color8(176, 96, 32), Color8(112, 128, 192),
]

## Centinela del lienzo. No aparece en ningun arte, asi que cualquier texel que
## lo conserve al final es un fallo de aritmetica de rectangulos.
const CENTINELA := Color8(255, 0, 255, 0)

## Fuentes del modo marcador: la cara superior del bloque de cada terreno.
const TOPS := {
	0: "res://assets/source/tilesets/grass/grass_top.png",
	1: "res://assets/source/tilesets/dirt/dirt_top.png",
	2: "res://assets/source/tilesets/cobblestone/cobblestone_top.png",
}

var _semilla := 1
var _fleco := 1.5
var _grano := 4
var _diagonal_arriba := true
var _acento := true
var _procedencia := {}

func _initialize() -> void:
	var modo := "marcador"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--modo="):
			modo = arg.substr(7)
		elif arg.begins_with("--semilla="):
			_semilla = int(arg.substr(10))
		elif arg.begins_with("--fleco="):
			_fleco = float(arg.substr(8))
		elif arg == "--sin-acento":
			_acento = false
	match modo:
		"depuracion":
			quit(0 if _hornea(modo, Atlas.debug_atlas_path()) else 1)
		"marcador", "normal":
			quit(0 if _hornea(modo, Atlas.atlas_path()) else 1)
		_:
			printerr("Modo desconocido: %s (normal, marcador, depuracion)" % modo)
			quit(1)

func _hornea(modo: String, destino: String) -> bool:
	var tamano := Atlas.atlas_size()
	if tamano.x > Atlas.MAX_ATLAS_TEXELS or tamano.y > Atlas.MAX_ATLAS_TEXELS:
		printerr(("El atlas mediria %s y la guarda esta en %d. Reorganizalo en " +
			"mas columnas en vez de alargarlo.") % [tamano, Atlas.MAX_ATLAS_TEXELS])
		return false

	var img := Image.create(tamano.x, tamano.y, false, Image.FORMAT_RGBA8)
	img.fill(CENTINELA)

	var rellenos: Array = []
	var acentos: Array = []
	if modo != "depuracion":
		rellenos = _carga_rellenos(modo)
		if rellenos.is_empty():
			return false
		for t in Atlas.terrain_count():
			acentos.append(_color_mas_oscuro(rellenos[t]))
			print("  acento de %s: %s" % [Atlas.terrain_id(t), acentos[t].to_html(false)])

	# Las 16 ventanas de relleno de cada terreno, precalculadas una vez.
	var ventanas := {}
	if modo != "depuracion":
		for t in Atlas.terrain_count():
			for fy in Atlas.FILL_CELLS:
				for fx in Atlas.FILL_CELLS:
					ventanas[[t, fx, fy]] = _ventana(rellenos[t], Vector2i(fx, fy))

	var celdas := Atlas.all_cells()
	for celda in celdas:
		var rect: Rect2i = celda["rect"]
		var fase: Vector2i = celda["phase"]
		if celda["kind"] == &"fill":
			if modo == "depuracion":
				img.fill_rect(rect, COLORES_DEPURACION[celda["terrain"]])
			else:
				_pega(img, ventanas[[celda["terrain"], fase.x, fase.y]], rect.position)
		else:
			if modo == "depuracion":
				_cuadrantes(img, rect, celda["low"], celda["high"], celda["mask"])
			else:
				_compone(img, rect, ventanas[[celda["low"], fase.x, fase.y]],
					ventanas[[celda["high"], fase.x, fase.y]],
					celda["mask"], fase, acentos[celda["high"]])

	if not _comprueba(img, celdas):
		return false

	var ruta := ProjectSettings.globalize_path(destino)
	var error := img.save_png(ruta)
	if error != OK:
		printerr("save_png(%s) devolvio %d" % [ruta, error])
		return false
	_escribe_import(destino)
	_escribe_procedencia(destino, modo)
	print("%s  %s  %d celdas  modo=%s" % [destino, tamano, celdas.size(), modo])
	print("Recuerda importar: godot --headless --path . --editor --quit")
	return true

# --------------------------------------------------------------- rellenos

func _carga_rellenos(modo: String) -> Array:
	var salida: Array = []
	for t in Atlas.terrain_count():
		var img: Image = null
		var ruta := Atlas.fill_source_path(t)
		# En normal, el relleno que falte sale de la cara superior del bloque. Asi
		# los rellenos se pueden entregar de uno en uno: desde el 23 de septiembre
		# de 2026 existe el de tierra y los otros dos siguen siendo sus *_top.png.
		if modo == "normal" and FileAccess.file_exists(ruta):
			img = _relleno_dibujado(ruta)
		else:
			if modo == "normal":
				print("  sin %s: se usa %s repetido 4x4" % [ruta.get_file(),
					String(TOPS[t]).get_file()])
			img = _relleno_de_top(TOPS[t])
		if img == null:
			return []
		salida.append(img)
	return salida

func _relleno_dibujado(ruta: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(ruta))
	if img == null:
		printerr("No se pudo abrir %s" % ruta)
		return null
	if img.get_size() != Vector2i(Atlas.PAGE_TEXELS, Atlas.PAGE_TEXELS):
		printerr(("%s mide %s y tiene que medir %dx%d exactos. Reducir " +
			"seria remuestrear, y eso destruye el pixel art.") % [
			ruta, img.get_size(), Atlas.PAGE_TEXELS, Atlas.PAGE_TEXELS])
		return null
	img.convert(Image.FORMAT_RGBA8)
	var costura := _energia_de_costura(img)
	if costura > 0:
		printerr(("  AVISO %s no repite sin costura: %d texeles de " +
			"desajuste al envolver. Se va a ver una rejilla cada %d px.") % [
			ruta.get_file(), costura, Atlas.PAGE_TEXELS])
	_procedencia[ruta] = _sha(ruta)
	return img

func _relleno_de_top(ruta: String) -> Image:
	var top := Image.load_from_file(ProjectSettings.globalize_path(ruta))
	if top == null:
		printerr("No se pudo abrir %s" % ruta)
		return null
	top.convert(Image.FORMAT_RGBA8)
	var quitados := _quita_marco(top)
	if quitados > 0:
		print("  %s: quitados %d texeles de marco del lienzo" % [
			ruta.get_file(), quitados])
	var costura := _energia_de_costura(top)
	if costura > 0:
		printerr(("  AVISO %s no repite sin costura: %d texeles de " +
			"desajuste al envolver. Se va a ver una rejilla cada %d px.") % [
			ruta.get_file(), costura, Atlas.CELL_TEXELS])
	_procedencia[ruta] = _sha(ruta)
	return _repite(top, Atlas.PAGE_TEXELS)

## Los *_top.png llevan un marco de un texel del lienzo del editor que no es
## parte del dibujo. Repetirlo 4x4 imprimiria una rejilla oscura cada 32 px.
## Devuelve cuantos texeles se han sustituido.
func _quita_marco(img: Image) -> int:
	var lado := img.get_width()
	var borde := {}
	for i in lado:
		borde[img.get_pixel(i, 0)] = true
		borde[img.get_pixel(i, lado - 1)] = true
		borde[img.get_pixel(0, i)] = true
		borde[img.get_pixel(lado - 1, i)] = true
	if borde.size() != 1:
		return 0
	var color: Color = borde.keys()[0]
	var interior := {}
	for y in range(1, lado - 1):
		for x in range(1, lado - 1):
			interior[img.get_pixel(x, y)] = true
	if interior.has(color) or interior.size() < 2:
		return 0
	for i in range(1, lado - 1):
		img.set_pixel(i, 0, img.get_pixel(i, 1))
		img.set_pixel(i, lado - 1, img.get_pixel(i, lado - 2))
	for i in range(1, lado - 1):
		img.set_pixel(0, i, img.get_pixel(1, i))
		img.set_pixel(lado - 1, i, img.get_pixel(lado - 2, i))
	img.set_pixel(0, 0, img.get_pixel(1, 1))
	img.set_pixel(lado - 1, 0, img.get_pixel(lado - 2, 1))
	img.set_pixel(0, lado - 1, img.get_pixel(1, lado - 2))
	img.set_pixel(lado - 1, lado - 1, img.get_pixel(lado - 2, lado - 2))
	return 4 * lado - 4

## Texeles en los que la ultima fila/columna no enlaza con la primera. Cero
## significa que la imagen repite en mosaico consigo misma.
func _energia_de_costura(img: Image) -> int:
	var lado := img.get_width()
	var fallos := 0
	# Se mide el salto relativo: cuantos texeles del borde difieren de mas, por
	# encima de lo que ya difieren dos filas interiores contiguas. Un dibujo de
	# grano fino tiene muchas diferencias entre filas vecinas y eso no es costura.
	var interior := 0
	for i in lado:
		if img.get_pixel(i, lado / 2) != img.get_pixel(i, lado / 2 + 1):
			interior += 1
		if img.get_pixel(lado / 2, i) != img.get_pixel(lado / 2 + 1, i):
			interior += 1
	for i in lado:
		if img.get_pixel(i, lado - 1) != img.get_pixel(i, 0):
			fallos += 1
		if img.get_pixel(lado - 1, i) != img.get_pixel(0, i):
			fallos += 1
	return maxi(0, fallos - interior)

func _repite(fuente: Image, lado: int) -> Image:
	var salida := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	var n := fuente.get_width()
	for y in lado:
		for x in lado:
			salida.set_pixel(x, y, fuente.get_pixel(x % n, y % n))
	return salida

## Ventana de 32x32 del relleno que le toca a una tesela de la fase dada,
## desplazada media celda y envuelta. Ver la cabecera del archivo.
func _ventana(relleno: Image, fase: Vector2i) -> Image:
	var n := Atlas.PAGE_TEXELS
	var lado := Atlas.CELL_TEXELS
	var ox := posmod(lado * fase.x - lado / 2, n)
	var oy := posmod(lado * fase.y - lado / 2, n)
	var salida := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	for v in lado:
		for u in lado:
			salida.set_pixel(u, v, relleno.get_pixel((ox + u) % n, (oy + v) % n))
	return salida

# --------------------------------------------------------------- composicion

func _pega(destino: Image, origen: Image, en: Vector2i) -> void:
	destino.blit_rect(origen, Rect2i(Vector2i.ZERO, origen.get_size()), en)

## Seleccion binaria por texel, nunca una mezcla: la paleta de salida es la union
## de las dos de entrada mas el acento. Un lerp de color generaria cientos de
## colores nuevos y destruiria el instrumento de medida de la decision 010.
func _compone(destino: Image, rect: Rect2i, bajo: Image, alto: Image, mask: int,
		fase: Vector2i, acento: Color) -> void:
	var bits := Silueta.silueta(mask, fase, _semilla, _fleco, _grano,
		_diagonal_arriba)
	var anillo := Silueta.acento(bits) if _acento else PackedByteArray()
	var lado := Atlas.CELL_TEXELS
	for v in lado:
		for u in lado:
			var i := v * lado + u
			var color: Color
			if bits[i] == 1:
				color = acento if (_acento and anillo[i] == 1) else alto.get_pixel(u, v)
			else:
				color = bajo.get_pixel(u, v)
			destino.set_pixel(rect.position.x + u, rect.position.y + v, color)

## El eje x de la tesela va a mundo +X (derecha en pantalla) y el eje y a mundo
## +Z (abajo en pantalla), asi que el cuadrante NW es el de arriba a la izquierda
## y le toca el bit 1.
func _cuadrantes(img: Image, rect: Rect2i, bajo: int, alto: int, mask: int) -> void:
	var mitad := Atlas.CELL_TEXELS / 2
	var posiciones := {
		Atlas.BIT_NW: Vector2i(0, 0), Atlas.BIT_NE: Vector2i(mitad, 0),
		Atlas.BIT_SW: Vector2i(0, mitad), Atlas.BIT_SE: Vector2i(mitad, mitad),
	}
	for bit in posiciones:
		var terreno: int = alto if (mask & bit) != 0 else bajo
		img.fill_rect(Rect2i(rect.position + posiciones[bit],
			Vector2i(mitad, mitad)), COLORES_DEPURACION[terreno])

func _color_mas_oscuro(img: Image) -> Color:
	var mejor := Color(1.0, 1.0, 1.0)
	var luz := 2.0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var l := c.get_luminance()
			if l < luz:
				luz = l
				mejor = c
	return mejor

# --------------------------------------------------------------- validacion

func _comprueba(img: Image, celdas: Array[Dictionary]) -> bool:
	var tamano := Atlas.atlas_size()
	var vistos := {}
	var cubierto := 0
	for celda in celdas:
		var r: Rect2i = celda["rect"]
		if not Rect2i(Vector2i.ZERO, tamano).encloses(r):
			printerr("La celda %s se sale del atlas: %s" % [celda["label"], r])
			return false
		var clave := "%d,%d" % [r.position.x, r.position.y]
		if vistos.has(clave):
			printerr("Dos celdas en %s: %s y %s" % [r.position, vistos[clave],
				celda["label"]])
			return false
		vistos[clave] = celda["label"]
		cubierto += r.size.x * r.size.y

	var reservado := (Atlas.PAGES_PER_ROW - Atlas.terrain_count()) \
		* Atlas.PAGE_TEXELS * Atlas.PAGE_TEXELS
	if cubierto + reservado != tamano.x * tamano.y:
		printerr(("Las celdas cubren %d texeles y los huecos reservados %d, " +
			"pero el atlas tiene %d.") % [cubierto, reservado, tamano.x * tamano.y])
		return false

	for celda in celdas:
		var r: Rect2i = celda["rect"]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if img.get_pixel(x, y).a < 1.0:
					printerr("Alfa < 1 en %s, local (%d,%d)" % [
						celda["label"], x - r.position.x, y - r.position.y])
					return false

	# Los huecos reservados van opacos: si algun dia una UV mal puesta apunta
	# ahi, se tiene que ver un color que no sale en ningun suelo y no un agujero.
	# Violeta rosa 5 de apollo_proyecto.gpl: el generador no inventa colores.
	img.fill_rect(Rect2i(Atlas.terrain_count() * Atlas.PAGE_TEXELS, 0,
		reservado / Atlas.PAGE_TEXELS, Atlas.PAGE_TEXELS), Color8(0xc6, 0x51, 0x97))
	return true

# --------------------------------------------------------------- salida

func _sha(res_path: String) -> String:
	var f := FileAccess.open(res_path, FileAccess.READ)
	if f == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(f.get_buffer(f.get_length()))
	f.close()
	return ctx.finish().hex_encode()

func _escribe_procedencia(destino: String, modo: String) -> void:
	var datos := {
		"modo": modo,
		"atlas_size": [Atlas.atlas_size().x, Atlas.atlas_size().y],
		"semilla": _semilla,
		"fleco_texeles": _fleco,
		"grano": _grano,
		"acento": _acento,
		"fuentes": _procedencia,
	}
	var ruta := destino.get_basename() + ".origen.json"
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(datos, "\t"))
	f.close()
	print("  procedencia en %s (modo=%s)" % [ruta.get_file(), modo])

## Escribe el .import solo si no existe, para no cambiar el uid de un archivo ya
## importado y romper las referencias uid://. Los tres valores que importan son
## compress/mode, mipmaps/generate y detect_3d/compress_to: sin el ultimo, Godot
## recomprime la textura a VRAM en cuanto la ve usada en 3D y destroza el pixel
## art en silencio. Ya paso con idle.png (decision 010).
func _escribe_import(res_path: String) -> void:
	var ruta := ProjectSettings.globalize_path(res_path + ".import")
	if FileAccess.file_exists(ruta):
		print("  .import ya existe, no se toca (se conserva el uid)")
		return
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	if f == null:
		printerr("No se pudo escribir %s" % ruta)
		return
	f.store_string("""[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="%s"

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
""" % res_path)
	f.close()
	print("  .import escrito (uid, path y dest_files los pone Godot al importar)")
