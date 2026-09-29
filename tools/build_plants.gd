extends SceneTree

## Genera una escena VillageProp por cada planta de Mario (arbustos, hierbas,
## flores, setas y rocas), lista para arrastrar al pueblo.
##
##   godot --headless --path . --script tools/build_plants.gd
##
## Lee assets/source/props/plantas/plantas.json (lienzo, tamano del dibujo y
## categoria de cada planta) y los PNG de assets/game/textures/plantas/, que
## tienen que estar importados: la primera vez, abrir antes el editor o pasar
## --editor --quit. Escribe, por cada planta:
##
## - assets/game/materials/plantas/<nombre>.tres: el material de
##   plant_sway.gdshader con su textura, su rectangulo y su viento.
## - scenes/village/props/plantas/<nombre>.tscn: la escena, con el quad del
##   tamano del rectangulo y, si estorba, su colision.
##
## Se puede volver a ejecutar cuando cambie un dibujo o la tabla de abajo: las
## escenas se sobrescriben, asi que no hay que retocarlas a mano. Lo que se
## ajusta por planta va en MOVIMIENTO y SOLIDAS.

const FICHA := "res://assets/source/props/plantas/plantas.json"
const TEXTURAS := "res://assets/game/textures/plantas/"
const MATERIALES := "res://assets/game/materials/plantas/"
const ESCENAS := "res://scenes/village/props/plantas/"
const SHADER := preload("res://assets/game/shaders/plant_sway.gdshader")
const PROP := preload("res://scenes/village/props/village_prop.gd")

## Viento por categoria: [bend_texels, sway_texels, sway_frequency]. Las matas se
## doblan mas y mas deprisa que los arbustos; setas y rocas no se mueven.
const MOVIMIENTO := {
	"arbustos": [1.0, 0.6, 0.4],
	"hierbas": [1.5, 1.0, 0.6],
	"hierbas_y_flores": [1.5, 1.0, 0.6],
	"setas_y_rocas": [0.0, 0.0, 0.0],
}

## Rachas comunes a todas las plantas: las de grass_tuft.gdshader y el arbol.
const VIENTO := {
	&"wind_direction": Vector2(1.0, 0.3),
	&"wind_speed": 1.2,
	&"wind_scale": 0.35,
	&"wind_strength": 1.0,
	&"time_step": 0.1,
}

## Lo que frena al personaje: los arbustos y las rocas grandes. Lo demas se cruza.
const SOLIDAS := ["roca_musgo", "roca_plana", "roca_grande_musgo", "roca_alta"]
const CATEGORIAS_SOLIDAS := ["arbustos"]

## La colision de lo que estorba es algo mas estrecha que el dibujo, para que el
## personaje no choque con hojas que no toca, y media casilla de fondo, como el
## tronco del arbol.
const ANCHO_COLISION := 0.8
const FONDO_COLISION := 0.5

var _fallos := 0

func _initialize() -> void:
	var texto := FileAccess.get_file_as_string(FICHA)
	var fichas: Variant = JSON.parse_string(texto)
	if not fichas is Array:
		printerr("No se puede leer %s" % FICHA)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MATERIALES))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ESCENAS))
	for ficha: Dictionary in fichas:
		_planta(ficha)
	print("%d plantas, %d fallos" % [(fichas as Array).size(), _fallos])
	quit(1 if _fallos else 0)

## Texeles que puede viajar la punta con viento de brisa (wind_strength 1): el
## maximo de la flexion de plant_sway.gdshader.
static func viaje_maximo(bend: float, sway: float) -> int:
	return ceili(bend + 1.35 * sway)

func _planta(ficha: Dictionary) -> void:
	var nombre: String = ficha["nombre"]
	var categoria: String = ficha["categoria"]
	var textura := load(TEXTURAS + nombre + ".png") as Texture2D
	if textura == null:
		printerr("Falta %s%s.png (¿sin importar?)" % [TEXTURAS, nombre])
		_fallos += 1
		return
	var imagen := Image.load_from_file(ProjectSettings.globalize_path(textura.resource_path))
	var lienzo := Vector2i(int(ficha["lienzo"][0]), int(ficha["lienzo"][1]))
	if imagen.get_size() != lienzo or lienzo.x % 2 != 0:
		printerr("%s mide %s y la ficha dice %s (tiene que ser de ancho par)"
			% [nombre, imagen.get_size(), lienzo])
		_fallos += 1
		return
	var viento: Array = MOVIMIENTO[categoria]
	var margen := viaje_maximo(viento[0], viento[1])
	# El pie esta en el centro de la fila de abajo (pie_px de la ficha), asi que
	# basta ensanchar lo mismo por los dos lados.
	var rect_min := Vector2(-margen, 0)
	var rect_size := Vector2(lienzo.x + 2 * margen, lienzo.y)
	var celda := VillageMetrics.block_scale(VillageMetrics.DEFAULT_PITCH_DEGREES)
	var paso := celda * VillageMetrics.TEXEL

	var mat := ShaderMaterial.new()
	mat.resource_name = nombre
	mat.shader = SHADER
	mat.set_shader_parameter(&"plant_texture", textura)
	mat.set_shader_parameter(&"rect_min", rect_min)
	mat.set_shader_parameter(&"rect_size", rect_size)
	mat.set_shader_parameter(&"top_row", float(imagen.get_used_rect().position.y))
	mat.set_shader_parameter(&"pixel_step", paso)
	mat.set_shader_parameter(&"bend_texels", viento[0])
	mat.set_shader_parameter(&"sway_texels", viento[1])
	mat.set_shader_parameter(&"sway_frequency", viento[2])
	# El viento de todo el pueblo se escribe entero, con los valores de la hierba
	# y los arboles, para poder cambiarlo desde el Inspector de cada material.
	for uniforme: StringName in VIENTO:
		mat.set_shader_parameter(uniforme, VIENTO[uniforme])
	var ruta_mat := MATERIALES + nombre + ".tres"
	if ResourceSaver.save(mat, ruta_mat) != OK:
		printerr("No se puede guardar %s" % ruta_mat)
		_fallos += 1
		return
	# Recargado desde el disco para que la escena lo enlace y no lo copie dentro.
	mat = ResourceLoader.load(ruta_mat, "", ResourceLoader.CACHE_MODE_REPLACE)

	var solida := categoria in CATEGORIAS_SOLIDAS or nombre in SOLIDAS
	var objeto := Vector2(float(ficha["objeto"][0]), float(ficha["objeto"][1]))
	var huella := Vector2i(maxi(1, roundi(objeto.x / VillageMetrics.TEXELS_PER_CELL)), 1) \
		if solida else Vector2i.ONE

	var raiz := Node3D.new()
	raiz.name = nombre.to_pascal_case()
	raiz.set_script(PROP)
	raiz.set(&"colision_automatica", false)
	raiz.set(&"huella_fija", huella)
	raiz.set(&"atravesable", not solida)

	var modelo := Node3D.new()
	modelo.name = "Modelo"
	raiz.add_child(modelo)
	modelo.owner = raiz
	var quad := QuadMesh.new()
	quad.size = rect_size * VillageMetrics.TEXEL
	var malla := MeshInstance3D.new()
	malla.name = "Lienzo"
	malla.mesh = quad
	malla.set_surface_override_material(0, mat)
	modelo.add_child(malla)
	malla.owner = raiz

	if solida:
		var cuerpo := StaticBody3D.new()
		cuerpo.name = "Colision"
		raiz.add_child(cuerpo)
		cuerpo.owner = raiz
		var caja := BoxShape3D.new()
		var alto := objeto.y * paso.y
		caja.size = Vector3(
			minf(objeto.x * VillageMetrics.TEXEL * ANCHO_COLISION, huella.x * celda.x),
			alto, FONDO_COLISION * celda.z)
		var forma := CollisionShape3D.new()
		forma.name = "Forma"
		forma.shape = caja
		forma.position = Vector3(0, alto * 0.5, 0)
		cuerpo.add_child(forma)
		forma.owner = raiz

	var escena := PackedScene.new()
	var ruta := ESCENAS + nombre + ".tscn"
	if escena.pack(raiz) != OK or ResourceSaver.save(escena, ruta) != OK:
		printerr("No se puede guardar %s" % ruta)
		_fallos += 1
	raiz.free()
