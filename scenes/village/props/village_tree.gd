@tool
class_name VillageTree
extends VillageProp

## Arbol del pueblo: un VillageProp cuya copa se vuelve translucida mientras tapa
## al personaje. El dibujo y el viento son del shader (tree_sway.gdshaderinc).
##
## Funciona como los muros que tapan (test_room.gd): el arbol se dibuja con dos
## copias del mismo quad.
##
## - Lienzo, el de la escena, opaco y con recorte. Siempre proyecta la sombra; al
##   fundirse deja de verse y sigue dibujandose solo en el mapa de sombras, asi
##   que la sombra no desaparece.
## - Fundido, que se crea al arrancar el juego con tree_sway_faded.gdshader: la
##   copa translucida y el tronco opaco. Solo se ve mientras dura el fundido.
##
## Quien decide si tapa es village.gd, que conoce al personaje: le pasa su
## rectangulo en pantalla a tapa() y el paso de tiempo a fundir().

const LIENZO := ^"Modelo/Lienzo"
const SHADER_FUNDIDO := preload("res://assets/game/shaders/tree_sway_faded.gdshader")

## Opacidad que conserva la copa mientras tapa al personaje. Algo mas que los
## muros (0,30): la copa tiene que seguir leyendose como arbol.
@export_range(0.0, 1.0, 0.05) var opacidad_al_tapar := 0.35

## Pixeles que se ensancha el personaje al buscar si la copa le tapa. Poco: la
## copa se mira pixel a pixel, y con mucho margen se fundiria al pasar al lado.
@export var margen_px := 4.0

## 0 opaca, 1 fundida del todo.
var fundido := 0.0

var _lienzo: MeshInstance3D
var _fundido: MeshInstance3D
var _copa: BitMap
var _rect_min := Vector2.ZERO
var _rect_size := Vector2.ZERO

func _ready() -> void:
	super()
	_lienzo = get_node_or_null(LIENZO) as MeshInstance3D
	var mat := _material()
	if mat == null:
		return
	_rect_min = _param(mat, &"rect_min")
	_rect_size = _param(mat, &"rect_size")
	_copa = _mascara(mat.get_shader_parameter(&"canopy_texture") as Texture2D)
	if not Engine.is_editor_hint():
		_crear_fundido(mat)

func _material() -> ShaderMaterial:
	if _lienzo == null:
		return null
	return _lienzo.get_surface_override_material(0) as ShaderMaterial

## Valor de un uniforme: el del material o, si no lo cambia, el del shader. Los
## materiales de los arboles escriben su rectangulo para no depender de esto,
## que con --headless no funciona.
func _param(mat: ShaderMaterial, nombre: StringName) -> Variant:
	var valor: Variant = mat.get_shader_parameter(nombre)
	if valor == null:
		valor = RenderingServer.shader_get_parameter_default(mat.shader.get_rid(), nombre)
	return valor if valor != null else Vector2.ZERO

## Texeles opacos de la copa. Con --headless el servidor de render no guarda la
## imagen de la textura, asi que se lee del PNG (solo existe en el proyecto, no
## en el juego exportado, donde get_image si funciona).
func _mascara(textura: Texture2D) -> BitMap:
	if textura == null:
		return null
	var imagen := textura.get_image()
	if imagen == null and FileAccess.file_exists(textura.resource_path):
		imagen = Image.load_from_file(ProjectSettings.globalize_path(textura.resource_path))
	if imagen == null:
		return null
	var mascara := BitMap.new()
	mascara.create_from_image_alpha(imagen, 0.5)
	return mascara

## La copia translucida lleva los mismos parametros que el Lienzo, asi que se
## mueve igual: al cambiar de una a otra no salta ningun pixel.
func _crear_fundido(mat: ShaderMaterial) -> void:
	var translucido := ShaderMaterial.new()
	translucido.shader = SHADER_FUNDIDO
	for uniforme in mat.shader.get_shader_uniform_list():
		var nombre: StringName = uniforme["name"]
		var valor: Variant = mat.get_shader_parameter(nombre)
		if valor != null:
			translucido.set_shader_parameter(nombre, valor)
	_fundido = MeshInstance3D.new()
	_fundido.name = "Fundido"
	_fundido.mesh = _lienzo.mesh
	_fundido.material_override = translucido
	_fundido.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fundido.visible = false
	_lienzo.add_sibling(_fundido)
	_fundido.transform = _lienzo.transform

## Si algun texel opaco de la copa cae dentro de `caja`, un rectangulo en el
## sistema de VillageMetrics.screen_point. No mira quien esta delante: eso lo
## decide quien llama. Tampoco sigue el viento: la copa viaja unos pocos texeles
## y margen_px ya los cubre.
func tapa(caja: Rect2, pitch_degrees: float) -> bool:
	if _copa == null:
		return false
	# El centro del rectangulo del shader cae en la raiz y su borde de abajo en
	# el suelo: de ahi sale donde empieza el dibujo en pantalla.
	var raiz := VillageMetrics.screen_point(global_position, pitch_degrees)
	var origen := raiz - Vector2(_rect_min.x + _rect_size.x * 0.5, _rect_min.y + _rect_size.y)
	var dibujo := Rect2(origen, Vector2(_copa.get_size()))
	var comun := dibujo.intersection(caja.grow(margen_px))
	if comun.size.x <= 0.0 or comun.size.y <= 0.0:
		return false
	var desde := Vector2i((comun.position - origen).floor())
	var hasta := Vector2i((comun.end - origen).ceil()).min(_copa.get_size())
	for y in range(maxi(desde.y, 0), hasta.y):
		for x in range(maxi(desde.x, 0), hasta.x):
			if _copa.get_bit(x, y):
				return true
	return false

## Avanza el fundido hacia 1 si `tapando`, hacia 0 si no, `paso` por llamada.
func fundir(tapando: bool, paso: float) -> void:
	if _fundido == null:
		return
	var previo := fundido
	fundido = move_toward(fundido, 1.0 if tapando else 0.0, paso)
	if is_equal_approx(previo, fundido):
		return
	var visible_fundido := fundido > 0.0
	_fundido.visible = visible_fundido
	_lienzo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY \
		if visible_fundido else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_fundido.set_instance_shader_parameter(&"canopy_opacity",
		lerpf(1.0, opacidad_al_tapar, fundido))
