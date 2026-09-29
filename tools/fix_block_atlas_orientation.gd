extends SceneTree

## Corrige la orientacion de la cara superior en los atlas de bloque de PixZels.
##
## PixZels empaqueta las seis vistas del bloque con un giro distinto cada una y
## compensa esos giros en las UV del .obj. La cara superior queda girada 180
## grados respecto al PNG original, asi que el dibujo sale del reves sobre el
## mapa. Se repite en los tres bloques exportados hasta ahora (cesped, tierra y
## adoquin), asi que la convencion parece estable; el arreglo de raiz sigue
## siendo girar el PNG de la cara superior antes de aplicarlo en PixZels.
##
## La herramienta solo toca los archivos de juego (assets/game/tilesets/). El
## arte editable de assets/source/ no se modifica nunca.
##
## Es idempotente y se niega a adivinar: compara cada region con su PNG de
## origen en las dos orientaciones que PixZels produce y actua solo si el
## desajuste es exactamente un giro de 180 grados. Si ya esta bien, no hace
## nada; si encuentra cualquier otra cosa, lo dice y deja ese atlas intacto.
##
## La comparacion no exige igualdad exacta, porque el propio PixZels no la da:
## ver MARGEN y TOLERANCIA. Aun asi distingue de sobra las dos orientaciones,
## que se separan en decenas de texeles.
##
## Hay que volver a ejecutarla despues de cada reexportacion desde PixZels:
##   godot --headless --path . --script tools/fix_block_atlas_orientation.gd
##
## Al anadir un bloque nuevo basta con sumar su par atlas/origen a BLOQUES.

## Atlas de juego y el PNG de la cara superior del que sale cada uno.
const BLOQUES: Array[Dictionary] = [
	{
		"atlas": "res://assets/game/tilesets/grass_block_atlas.png",
		"top": "res://assets/source/tilesets/grass/grass_top.png",
	},
	{
		"atlas": "res://assets/game/tilesets/dirt_block_atlas.png",
		"top": "res://assets/source/tilesets/dirt/dirt_top.png",
	},
	{
		"atlas": "res://assets/game/tilesets/cobblestone_block_atlas.png",
		"top": "res://assets/source/tilesets/cobblestone/cobblestone_top.png",
	},
	{
		"atlas": "res://assets/game/tilesets/summer_grass_block_atlas.png",
		"top": "res://assets/source/tilesets/summer_grass/summer_grass_top.png",
	},
]

const ORIGEN := Vector2i(33, 33)
const LADO := 32

## Texeles del contorno que quedan fuera de la comparacion. Los PNG sueltos de
## algunas caras llevan un marco oscuro de un texel que el bloque no tiene: es
## del lienzo del editor, no del dibujo. Solo se excluyen de la comprobacion; el
## giro sigue aplicandose a la region entera.
const MARGEN := 1

## Diferencia maxima por canal que sigue contando como el mismo texel, sobre 255.
## PixZels no escribe exactamente el mismo color en el atlas y en el PNG suelto
## de la misma cara: desplaza algun canal una unidad. Exigir igualdad exacta
## hacia que la herramienta no reconociera su propia exportacion y se negara a
## tocar un atlas que si necesitaba el giro.
const TOLERANCIA := 2.5 / 255.0

## Transpuesta: como debe quedar la region para que el mapa se vea bien.
const ORIENTACION_CORRECTA := 0

## Antitranspuesta: como la escribe PixZels, girada 180 grados respecto a la buena.
const ORIENTACION_INVERTIDA := 1

func _initialize() -> void:
	var fallos := 0
	for bloque in BLOQUES:
		if not _arregla(bloque["atlas"], bloque["top"]):
			fallos += 1
	quit(1 if fallos > 0 else 0)

## Devuelve false solo si el atlas quedo sin arreglar porque no se reconoce.
func _arregla(ruta_atlas: String, ruta_top: String) -> bool:
	var ruta := ProjectSettings.globalize_path(ruta_atlas)
	var atlas := Image.load_from_file(ruta)
	var fuente := Image.load_from_file(ProjectSettings.globalize_path(ruta_top))
	if atlas == null or fuente == null:
		printerr("%s: no se pudo abrir el atlas o el PNG de origen" % ruta_atlas)
		return false

	var correcta := _difiere(atlas, fuente, ORIENTACION_CORRECTA)
	var invertida := _difiere(atlas, fuente, ORIENTACION_INVERTIDA)
	if correcta == 0:
		print("%s: la cara superior ya esta bien orientada, no se toca nada" % ruta_atlas)
		return true
	if invertida != 0:
		printerr(("%s: la cara superior no encaja ni en la orientacion buena (%d " +
			"texeles fuera) ni en la que exporta PixZels (%d fuera). No se toca.") % [
			ruta_atlas, correcta, invertida])
		return false

	var copia := Image.create(LADO, LADO, false, atlas.get_format())
	for y in LADO:
		for x in LADO:
			copia.set_pixel(x, y, atlas.get_pixel(ORIGEN.x + x, ORIGEN.y + y))
	for y in LADO:
		for x in LADO:
			atlas.set_pixel(ORIGEN.x + x, ORIGEN.y + y,
				copia.get_pixel(LADO - 1 - x, LADO - 1 - y))
	atlas.save_png(ruta)
	print("%s: cara superior girada 180 grados" % ruta_atlas)
	return true

## Texeles en los que la region del atlas se aparta del PNG de origen leido en
## una orientacion dada. El atlas de PixZels no guarda la cara tal cual: la
## guarda transpuesta. La orientacion buena es la transpuesta src(y, x); la que
## sale de PixZels es la antitranspuesta src(31-y, 31-x), girada 180 grados
## respecto a la anterior.
func _difiere(atlas: Image, fuente: Image, orientacion: int) -> int:
	var fallos := 0
	for y in range(MARGEN, LADO - MARGEN):
		for x in range(MARGEN, LADO - MARGEN):
			var sx := y if orientacion == ORIENTACION_CORRECTA else LADO - 1 - y
			var sy := x if orientacion == ORIENTACION_CORRECTA else LADO - 1 - x
			if not _mismo_texel(atlas.get_pixel(ORIGEN.x + x, ORIGEN.y + y),
					fuente.get_pixel(sx, sy)):
				fallos += 1
	return fallos

## Dos texeles que solo se separan por el redondeo de PixZels cuentan como uno.
func _mismo_texel(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= TOLERANCIA and absf(a.g - b.g) <= TOLERANCIA 		and absf(a.b - b.b) <= TOLERANCIA and absf(a.a - b.a) <= TOLERANCIA
