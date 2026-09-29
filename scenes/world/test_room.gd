@tool
extends Node3D

## Sala de pruebas para fijar el angulo de camara y comprobar la densidad de
## texel con arte real. No es una escena de juego: solo suelo, unos muros y el
## personaje. La camara, la compensacion del sprite y la escala anisotropa de
## los bloques se derivan de VillageMetrics, asi que cambiar pitch_degrees
## basta para comparar angulos sin que nada deje de cuadrar en pixeles.
##
## Es @tool solo para que scenes/world/village.gd, que hereda de aqui, pueda
## ensenar el suelo en el editor. La sala en si no hace nada en el editor: todo
## lo que construye son nodos sin owner que no deben acabar guardados en el .tscn.

## Cubo de PixZels para los muros. El suelo ya no lo usa: es una sola ArrayMesh
## de quads planos, porque un plano continuo no necesita seis caras y porque la
## UV por vertice es lo unico que permite que el dibujo cruce el limite de celda
## sin escribir un shader.
const BLOCK: Mesh = preload("res://assets/game/tilesets/grass_block.obj")
const COBBLESTONE: Material = preload("res://assets/game/materials/cobblestone_pixel.tres")

## Material del suelo por teselas. Mismos ajustes que village_pixel.tres --
## nearest, rugoso, sin especular -- y ademas texture_repeat apagado, para que un
## error de coma flotante en el borde exterior recorte en vez de envolver al otro
## lado del atlas.
##
## village_pixel.tres, summer_grass_pixel.tres y dirt_pixel.tres quedan sin
## usar en esta escena, pero NO se borran: son arte, y los bloques de cesped y
## tierra vuelven en cuanto haya terreno elevado.
const GROUND_MATERIAL: Material = preload("res://assets/game/materials/ground_pixel.tres")

## Hierba que se mece y se aparta al paso del personaje. La hoja de matas es
## PROVISIONAL (tools/build_grass_tufts.gd) hasta que llegue la dibujada: cuatro
## matas de 16x16 en fila, dos bajas y dos altas.
const GRASS_SHADER: Shader = preload("res://assets/game/shaders/grass_tuft.gdshader")
const GRASS_TUFTS: Texture2D = preload("res://assets/game/textures/grass_tufts.png")
const GRASS_VARIANTS := 4
const GRASS_TUFT_TEXELS := 16

## Lo que el personaje sube andando, en texeles de cara vertical. La losa de
## acera mide 8 (ALTO_TEXELES en tools/build_paint_library.gd); los 2 de mas son
## holgura, porque a la altura justa la capsula roza la arista de la losa y el
## paso se da por bloqueado. Un bloque entero, 32, sigue siendo un muro.
const STEP_TEXELS := 10

## Radio del pie del personaje, en texeles. Es lo unico que toca los bordillos,
## asi que tambien es cuanto antes de llegar al canto sube y cuanto despues de
## pasarlo baja: con 3 texeles, unos 3 px en pantalla.
const FOOT_TEXELS := 3

@export var pitch_degrees: float = VillageMetrics.DEFAULT_PITCH_DEGREES
@export var ground_cells := Vector2i(26, 20)

## Zonas de tierra del suelo, en celdas y en el mismo sistema que _cell_center.
##
## La muestra esta elegida para que ejercite las 16 mascaras de la rejilla
## desplazada y no solo las nueve que da un rectangulo suelto. Un rectangulo
## produce las cuatro esquinas exteriores, los cuatro bordes y el nucleo; las
## cuatro esquinas INTERIORES solo aparecen alrededor de un hueco del terreno de
## menos precedencia (de ahi grass_holes) y las dos diagonales solo donde dos
## celdas se tocan unicamente en diagonal (de ahi las pasaderas sueltas).
##
## El camino mide cuatro celdas de ancho a proposito. En rejilla desplazada un
## rectangulo de W celdas deja solo (W-1) de relleno puro, porque 16 px de cada
## borde caen dentro de una tesela de transicion: con W=2 los dos flecos se
## pelean en el centro y el camino se lee como una cadena de lentejas.
@export var dirt_patches: Array[Rect2i] = [
	Rect2i(-6, -4, 8, 4),    # patio dentro del muro en L
	Rect2i(-2, 0, 4, 7),     # camino del patio a donde aparece el personaje
	Rect2i(-11, 1, 5, 5),    # plazoleta oeste, que aloja la isla de cesped
	Rect2i(6, -4, 1, 1),     # pasaderas NW-SE -> mascara 9
	Rect2i(7, -3, 1, 1),
	Rect2i(10, -3, 1, 1),    # pasaderas NE-SW -> mascara 6
	Rect2i(9, -2, 1, 1),
	Rect2i(9, 4, 3, 3),      # banco de degradacion, aislado a proposito
]

## Zonas de adoquin. Tapan a las de tierra.
##
## El umbral lleva un anillo de tierra de al menos una celda alrededor: dos
## terrenos no contiguos a distancia de Chebyshev menor que 2 producen teselas
## con tres terrenos, que el atlas no sabe dibujar y hay que degradar.
@export var cobblestone_patches: Array[Rect2i] = [
	Rect2i(-4, -3, 2, 2),    # umbral pavimentado dentro del patio
	Rect2i(9, 4, 1, 1),      # esquina del banco: pareja cesped/adoquin y 2 triples
]

## Recorta cesped sobre cualquier zona anterior. Existe para que la muestra
## ejercite las cuatro esquinas interiores (7, 11, 13, 14).
@export var grass_holes: Array[Rect2i] = [
	Rect2i(-9, 3, 1, 1),     # isla de cesped dentro de la plazoleta
]

## Zonas de agua (WaterSurface). Vacio en la sala: test_ground_mesh cuenta una
## tesela por vertice de la rejilla, y las que tocan agua salen del suelo para
## ir a la orilla. Las pruebas de agua rellenan esto antes de meter la sala en
## el arbol.
@export var water_patches: Array[Rect2i] = []

## Opacidad que conserva una pared mientras tapa al personaje.
@export_range(0.0, 1.0, 0.05) var occluder_opacity: float = 0.30

## Segundos que tarda el fundido, en cada sentido.
@export var occluder_fade_time: float = 0.12

## Celdas que se ensancha la silueta del personaje al buscar que pared le tapa.
## Con 0 solo se abre el hueco justo de su ancho, que es una rendija estrecha;
## subirlo abre una ventana mas generosa alrededor.
@export var occluder_margin_cells: float = 1.0

## La camara sigue al personaje sin salirse del suelo
## (docs/decisions/014-parcela-y-camara.md). Apagado en la sala: existe para
## juzgar texeles con un encuadre fijo, y test_ground_texel y las capturas
## cuentan con la camara mirando al origen. El pueblo lo enciende.
@export var follow_player := false

@export_group("Hierba")
@export var grass_enabled := true
## Matas por celda de cesped, de media.
@export_range(0.0, 6.0, 0.1) var grass_density: float = 1.6
## Fraccion de las matas que crece en manchas; el resto va suelto.
@export_range(0.0, 1.0, 0.05) var grass_cluster_share: float = 0.7
## Tamano de cada mancha (desviacion tipica, en celdas).
@export_range(0.1, 3.0, 0.05) var grass_cluster_radius: float = 0.6
## Celdas de cesped por mancha: menos, mas manchas.
@export_range(1.0, 40.0, 0.5) var grass_cells_per_cluster: float = 7.0
## Distancia minima de una mata al borde del cesped, en celdas. Por debajo de
## ~0,3 las matas crecen sobre el flequillo de tierra de las teselas de transicion.
@export_range(0.0, 0.5, 0.05) var grass_margin: float = 0.35
@export var grass_seed := 1
@export_range(0.0, 0.3, 0.01) var grass_wind_strength: float = 0.06
@export_range(0.0, 3.0, 0.05) var grass_push_radius: float = 0.8
@export_group("Agua")
## Pixeles de pantalla que se hunde el agua bajo el suelo: lo que mide la orilla
## de tierra que asoma en el borde norte.
@export_range(1, 16) var water_depth_texels := 6
## Pixeles por segundo que derivan las ondas del agua, siempre a saltos enteros.
## El fondo no se desplaza: el agua es de estanque (water_pixel.gdshader).
@export_range(0.0, 4.0, 0.1) var water_ripple_speed := 0.6
@export_group("")

@onready var camera: Camera3D = $Camera3D
@onready var player: CharacterBody3D = $Player

## Resumen de la ultima construccion del suelo, para que las pruebas no tengan
## que reimplementar la seleccion de tesela para comprobarla:
##   tiles       teselas emitidas
##   masks       Dictionary indice de pareja -> Dictionary de mascaras vistas
##   degraded    Array[Vector2i] con las teselas que hubo que degradar
var ground_stats: Dictionary = {}

## Tipos de bloque de muro. Cada uno es un Dictionary con
##   mesh      la malla que se instancia
##   material  el material con que se dibuja, o null si la malla trae el suyo
##   local     Transform3D de la malla dentro de su celda (escala incluida)
##   box       AABB que ocupa la malla dentro de su celda, relativa al centro de
##             la celda. Un cubo la llena; una losa baja solo su fondo.
## Un tipo por material, porque cada uno necesita su trio de MultiMesh.
var _wall_kinds: Array[Dictionary] = []

## Un elemento por bloque, en paralelo: centro de celda, giro y tipo.
var _wall_centers: Array[Vector3] = []
var _wall_bases: Array[Basis] = []
var _wall_kind := PackedInt32Array()

var _wall_rects: Array[Rect2] = []
var _wall_depth := PackedFloat32Array()
var _wall_fade := PackedFloat32Array()

## Material de la hierba, para pasarle los pies del personaje cada fotograma.
var _grass_material: ShaderMaterial

## Teselas del suelo que tocan agua, Vector2i -> Rect2 con su UV en el atlas.
## Las elige _build_ground_mesh como cualquier otra y las dibuja la orilla de
## _build_water_node, recortadas por la silueta del agua.
var _shore_tiles: Dictionary = {}

## Un nodo por tipo de bloque, en el orden de _wall_kinds.
var _walls_solid: Array[MultiMeshInstance3D] = []
var _walls_faded: Array[MultiMeshInstance3D] = []

## Indices de bloque de cada tipo, para no recorrer todos en cada refresco.
var _kind_members: Array[PackedInt32Array] = []

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# El suelo va antes que la camara porque sus bordes son los limites del
	# seguimiento. Que pared tapa al personaje ya no depende de la camara: se
	# compara con VillageMetrics.screen_point.
	_build_ground()
	_place_camera()
	_build_walls()
	# Despues de los muros, para no plantar hierba dentro de un bloque.
	_build_grass()
	_fit_sprite()

## La accion existe desde la decision 009 pero se quedo sin nadie que la
## atendiera al borrar laboratory_3d.gd. Con la ventana en 960x540, la pantalla
## completa es justo como se llega al x2 en Full HD.
func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event.is_action_pressed(&"toggle_fullscreen"):
		DisplayMode.toggle_fullscreen()
		get_viewport().set_input_as_handled()

func _cell_size() -> Vector3:
	return VillageMetrics.block_scale(pitch_degrees)

## Celdas de suelo que hay que poner. El minimo lo marca el encuadre: si el
## suelo se queda mas corto que el viewport salen bandas de fondo en los bordes,
## asi que ground_cells actua de suelo minimo y no de tamano fijo.
func _ground_extent() -> Vector2i:
	var ancho := int(ceil(float(ProjectSettings.get_setting(
		"display/window/size/viewport_width", 960)) / VillageMetrics.PIXELS_PER_UNIT))
	var fondo := int(ceil(VillageMetrics.viewport_height() / VillageMetrics.PIXELS_PER_UNIT))
	return Vector2i(maxi(ground_cells.x, ancho + 4), maxi(ground_cells.y, fondo + 4))

## Rango de celdas de suelo: position inclusive, end() exclusive, en indices de
## celda. Centrado con division entera, igual que el bucle al que sustituye.
func _ground_cell_range() -> Rect2i:
	var extent := _ground_extent()
	return Rect2i(-extent.x / 2, -extent.y / 2, extent.x, extent.y)

## Rango de teselas de dibujo. La rejilla de dibujo va media celda al noroeste de
## la logica y tiene un vertice mas que celdas en cada eje, asi que una losa de
## extent celdas necesita extent+1 teselas. Sin esa fila y esa columna de mas, el
## ultimo vertice del mapa se quedaria sin tesela.
func _ground_tile_range() -> Rect2i:
	var celdas := _ground_cell_range()
	return Rect2i(celdas.position, celdas.size + Vector2i.ONE)

func _build_ground() -> void:
	var teselas := _ground_tile_range()
	_build_ground_node(teselas)
	_ground_collider(teselas)
	_build_water_node()
	_water_collider()

## El suelo es un plano continuo y sus caras laterales e inferior nunca se ven,
## asi que no necesita ser una rejilla de cubos. Una sola ArrayMesh de quads da
## un material, una llamada de dibujo y, sobre todo, UV por vertice: es lo unico
## que permite que el dibujo cruce el limite de celda sin escribir un shader.
func _build_ground_node(rango: Rect2i) -> void:
	var node := MeshInstance3D.new()
	node.name = &"Ground"
	node.mesh = _build_ground_mesh(rango)
	node.material_override = GROUND_MATERIAL
	# La malla se construye en unidades de celda y la compensacion anisotropa va
	# aqui: cambiar pitch_degrees pasa a ser una escritura de propiedad y no una
	# reconstruccion de miles de vertices.
	var size := _cell_size()
	node.scale = Vector3(size.x, 1.0, size.z)
	# No hay nada debajo del suelo, asi que no tiene a quien proyectar sombra, y
	# sacarlo del mapa de sombras quita de raiz su auto-sombreado. RECIBIR sombra
	# de los muros no requiere estar en el mapa de sombras: eso lo decide el
	# material, no cast_shadow.
	#
	# Medido bajo Forward+ el 22 de septiembre de 2026, en una region de 64x64 de
	# relleno puro: con los bias actuales (0,05 / 2,0) el suelo daba 9 colores
	# exactos, los mismos que con las sombras del sol apagadas, y con los bias a
	# cero daba 240. Es decir, el acne de sombra existe tambien en Forward+ y los
	# valores calibrados en la decision 010 siguen haciendo su trabajo: no son
	# coste gratuito heredado de GL Compatibility.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

## Malla del suelo para un rango de celdas, en unidades de celda y con la cara
## superior en y=0.
##
## Los cuatro vertices son A=(minX,minZ) B=(minX,maxZ) C=(maxX,maxZ)
## D=(maxX,minZ), el mismo orden que la cara superior de grass_block.obj, para
## que las UV emparejen sin pensar. El bobinado, en cambio, va AL REVES que el
## .obj: Wavefront declara las caras en antihorario y Godot considera frontal el
## horario, asi que el importador invierte el orden al traer el modelo. Copiarlo
## literal deja el suelo invisible por descarte de cara trasera -- comprobado,
## no supuesto. De ahi A,C,B y A,D,C.
func _build_ground_mesh(rango: Rect2i) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var fin := rango.end
	var mascaras := {}
	var degradadas: Array[Vector2i] = []
	_shore_tiles.clear()
	for j in range(rango.position.y, fin.y):
		for i in range(rango.position.x, fin.x):
			var esquinas := PackedInt32Array([
				_terrain_at(i - 1, j - 1), _terrain_at(i, j - 1),
				_terrain_at(i - 1, j), _terrain_at(i, j)])
			# Cuadrantes que caen en agua, con los mismos bits que las mascaras.
			var mojadas := 0
			for k in 4:
				if _is_water(i - 1 + (k & 1), j - 1 + (k >> 1)):
					mojadas |= 1 << k
			if mojadas == GroundAtlas.MASK_ALL:
				continue
			if mojadas != 0:
				esquinas = _dry_corners(esquinas, mojadas)
			if _needs_promotion(esquinas):
				degradadas.append(Vector2i(i, j))
			var reducida := _reduce_corners(esquinas)
			var fase := _tile_phase(i, j)
			var rect: Rect2i
			if reducida.z == 0:
				rect = GroundAtlas.fill_cell(reducida.x, fase)
			else:
				var pareja := GroundAtlas.pair_index(reducida.x, reducida.y)
				rect = GroundAtlas.transition_cell(pareja, reducida.z, fase)
				if not mascaras.has(pareja):
					mascaras[pareja] = {}
				mascaras[pareja][reducida.z] = true

			# La tesela va centrada en el vertice donde se tocan cuatro celdas
			# logicas, que es lo que hace que la junta cruce por su centro y
			# nunca por su borde. Las que tocan agua no van aqui: la orilla las
			# recorta con una silueta curva, y eso lo dibuja WaterSurface con su
			# propio material (_build_water_node).
			var uv := GroundAtlas.uv_rect(rect)
			if mojadas != 0:
				_shore_tiles[Vector2i(i, j)] = uv
				continue
			var base := verts.size()
			verts.push_back(Vector3(i - 0.5, 0.0, j - 0.5))
			verts.push_back(Vector3(i - 0.5, 0.0, j + 0.5))
			verts.push_back(Vector3(i + 0.5, 0.0, j + 0.5))
			verts.push_back(Vector3(i + 0.5, 0.0, j - 0.5))
			for _k in 4:
				norms.push_back(Vector3.UP)
			for v in _ground_uvs(uv):
				uvs.push_back(v)
			idx.push_back(base)
			idx.push_back(base + 2)
			idx.push_back(base + 1)
			idx.push_back(base)
			idx.push_back(base + 3)
			idx.push_back(base + 2)

	ground_stats = {
		"tiles": rango.size.x * rango.size.y,
		"masks": mascaras,
		"degraded": degradadas,
	}
	if not degradadas.is_empty():
		push_warning(("Suelo: %d teselas con tres terrenos degradadas " +
			"(primeras: %s). Deja al menos una celda del terreno intermedio " +
			"entre dos terrenos no contiguos.") % [
			degradadas.size(), str(degradadas.slice(0, 4))])

	# Arrays crudos y no SurfaceTool: su deduplicacion de vertices no aporta nada
	# aqui, porque dos celdas contiguas comparten posicion pero no UV.
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return malla

## Las cuatro UV de una tesela, en el orden A, B, C, D de la malla.
##
## Orientacion natural, sin transponer ni voltear nada: u crece con el mundo +X
## (derecha en pantalla) y v con el mundo +Z (hacia abajo en pantalla), que es
## tambien como crece la y de una Image y la v de una Texture2D en Godot. La
## transposicion del atlas de bloque existia porque PixZels hornea las UV del
## .obj; aqui las UV las escribimos nosotros, asi que no hay nada que compensar.
func _ground_uvs(uv: Rect2) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	uvs.push_back(Vector2(uv.position.x, uv.position.y))
	uvs.push_back(Vector2(uv.position.x, uv.end.y))
	uvs.push_back(Vector2(uv.end.x, uv.end.y))
	uvs.push_back(Vector2(uv.end.x, uv.position.y))
	return uvs

## Cuadrante del bloque de relleno que le toca a la tesela. Hace que el dibujo
## cruce el limite de celda: el patron visible pasa de 32 a 128 pixeles.
##
## posmod y no %: i y j son negativos en media sala y el resto con signo de
## GDScript devolveria indices fuera del bloque, partiendo el patron por la
## mitad del mapa.
func _tile_phase(i: int, j: int) -> Vector2i:
	return Vector2i(posmod(i, GroundAtlas.FILL_CELLS),
		posmod(j, GroundAtlas.FILL_CELLS))

## Terreno de una celda. Unica definicion de "que material lleva una celda", y la
## costura por la que entrara un mapa autorado de verdad: cuando el mapa deje de
## ser tres @export, solo cambia esta funcion.
func _terrain_at(i: int, j: int) -> int:
	var celda := Vector2i(i, j)
	if _in_patches(grass_holes, celda):
		return GroundAtlas.Terrain.GRASS
	if _in_patches(cobblestone_patches, celda):
		return GroundAtlas.Terrain.COBBLESTONE
	if _in_patches(dirt_patches, celda):
		return GroundAtlas.Terrain.DIRT
	return GroundAtlas.Terrain.GRASS

## true si la celda es agua. Va aparte de _terrain_at porque el agua no es un
## terreno del atlas: una celda de agua no tiene tesela, deja un hueco en el
## suelo. village.gd la sobrescribe con lo pintado.
func _is_water(i: int, j: int) -> bool:
	return _in_patches(water_patches, Vector2i(i, j))

func _in_patches(patches: Array[Rect2i], celda: Vector2i) -> bool:
	for patch in patches:
		if patch.has_point(celda):
			return true
	return false

## true si las cuatro esquinas no forman una pareja que el atlas sepa dibujar, es
## decir si _reduce_corners va a tener que ascender algun terreno.
func _needs_promotion(esquinas: PackedInt32Array) -> bool:
	var presentes: Array[int] = []
	for t in esquinas:
		if not presentes.has(t):
			presentes.append(t)
	if presentes.size() <= 1:
		return false
	if presentes.size() > 2:
		return true
	presentes.sort()
	return not GroundAtlas.has_pair(presentes[0], presentes[1])

## Reduce las cuatro esquinas a una pareja que el atlas sepa dibujar.
##
## Con tres terrenos una tesela tiene 81 combinaciones de esquinas y el atlas
## solo tiene piezas para parejas: 36 de esas 81 no tienen dibujo. En vez de
## prohibirlas -- el mapa pasa por estados invalidos mientras se dibuja -- se
## asciende el terreno de menor precedencia al menor de los presentes que sea
## mayor que el, hasta que quedan dos.
##
## Al menor de los PRESENTES y no a bajo+1, para no meter en la tesela un terreno
## que el autor no ha pintado en ninguna de las cuatro celdas. Y hacia arriba y
## nunca hacia abajo, porque el terreno de mas precedencia es el que el autor ha
## puesto a proposito: es preferible comerse fondo que encoger un camino.
##
## Devuelve (bajo, alto, mascara). mascara == 0 significa relleno puro de `bajo`;
## en una transicion la mascara nombra las esquinas del terreno `alto`.
func _reduce_corners(esquinas: PackedInt32Array) -> Vector3i:
	var e := esquinas.duplicate()
	while true:
		var presentes: Array[int] = []
		for t in e:
			if not presentes.has(t):
				presentes.append(t)
		presentes.sort()
		if presentes.size() == 1:
			return Vector3i(presentes[0], presentes[0], 0)
		if presentes.size() == 2 and GroundAtlas.has_pair(presentes[0], presentes[1]):
			var alto: int = presentes[1]
			var mask := 0
			for k in e.size():
				if e[k] == alto:
					mask |= 1 << k
			return Vector3i(presentes[0], alto, mask)
		var bajo: int = presentes[0]
		var destino: int = presentes[1]
		for k in e.size():
			if e[k] == bajo:
				e[k] = destino
	return Vector3i.ZERO

## Da a cada esquina mojada el terreno de la esquina seca que tiene al otro lado
## de la orilla: primero la de su columna, luego la de su fila y por ultimo la
## diagonal. Como esos cuadrantes quedan casi enteros bajo el agua (solo asoma
## la curva de la orilla), lo que importa es que no metan una transicion que no
## existe: un camino de tierra que llega al agua sigue recto hasta la orilla en
## vez de rematarse en curva contra un cesped que el autor no ha pintado. `mojadas` usa los bits de las mascaras y nunca es
## MASK_ALL, asi que siempre hay una esquina seca de la que copiar.
func _dry_corners(esquinas: PackedInt32Array, mojadas: int) -> PackedInt32Array:
	var secas := esquinas.duplicate()
	for k in 4:
		if not mojadas & (1 << k):
			continue
		# k ^ 2 cambia de fila (misma columna), k ^ 1 de columna, k ^ 3 ambas.
		for otra in [k ^ 2, k ^ 1, k ^ 3]:
			if not mojadas & (1 << otra):
				secas[k] = esquinas[otra]
				break
	return secas

## Un unico colisionador plano: miles de cajas contiguas enganchan al andar.
##
## Se deriva del rango de teselas y no del origen. Con la division entera de
## _ground_cell_range un extent impar deja la losa descentrada media celda: la
## version anterior ponia el box de z=-10,5 a +10,5 mientras el suelo iba de -10
## a +11, asi que al norte sobresalia sobre el vacio y al sur faltaba suelo
## solido bajo suelo pintado. No se veia por el margen de cuatro celdas, pero el
## personaje se habria caido con suelo pintado bajo los pies.
##
## Las teselas van media celda al noroeste, asi que la tesela (i,j) ocupa
## [i-0,5, i+0,5] y la losa entera [position-0,5, position+size-0,5].
func _ground_collider(rango: Rect2i) -> void:
	var size := _cell_size()
	var body := StaticBody3D.new()
	body.name = &"GroundBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(rango.size.x * size.x, size.y, rango.size.y * size.z)
	shape.shape = box
	shape.position = Vector3(
		(rango.position.x + rango.size.x * 0.5 - 0.5) * size.x,
		-0.5 * size.y,
		(rango.position.y + rango.size.y * 0.5 - 0.5) * size.z)
	body.add_child(shape)
	add_child(body)

## Celdas de agua dentro del rango del suelo: Vector2i -> true. Fuera del rango
## no hay suelo en el que hacer hueco.
func water_cells() -> Dictionary:
	var celdas := {}
	var rango := _ground_cell_range()
	for j in range(rango.position.y, rango.end.y):
		for i in range(rango.position.x, rango.end.x):
			if _is_water(i, j):
				celdas[Vector2i(i, j)] = true
	return celdas

## Lamina de agua y orilla (WaterSurface). Un nodo aparte del suelo porque
## lleva otros materiales, pero con su misma escala: las mallas tambien van en
## unidades de celda. Va despues de _build_ground_node, que es quien elige la
## tesela de cada vertice y deja las de la orilla en _shore_tiles.
func _build_water_node() -> void:
	var agua := water_cells()
	if agua.is_empty():
		return
	var size := _cell_size()
	var teselas := WaterSurface.tile_masks(agua)
	var rect := WaterSurface.mask_tiles(teselas)
	var origen := WaterSurface.mask_origin(rect)
	var mascara := ImageTexture.create_from_image(WaterSurface.shore_mask(teselas, rect))
	var malla := WaterSurface.build_mesh(teselas, _shore_tiles,
		WaterSurface.depth(water_depth_texels, size))
	malla.surface_set_material(0, WaterSurface.material(water_ripple_speed,
		mascara, origen, water_depth_texels))
	if malla.get_surface_count() > 1:
		malla.surface_set_material(1, WaterSurface.shore_material(mascara, origen))
	var node := MeshInstance3D.new()
	node.name = &"Water"
	node.mesh = malla
	node.scale = Vector3(size.x, 1.0, size.z)
	# Como el suelo: no tiene nada debajo a quien dar sombra, y recibir la de los
	# muros lo decide el material.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

## Una caja por casilla de agua, de una celda de alto, para que no se pueda
## entrar. La losa del suelo sigue entera por debajo: el agua se ve hundida pero
## no hay hueco en el que caerse.
func _water_collider() -> void:
	var agua := water_cells()
	if agua.is_empty():
		return
	var size := _cell_size()
	var celdas: Array = agua.keys()
	celdas.sort()
	var body := StaticBody3D.new()
	body.name = &"WaterBodies"
	for c: Vector2i in celdas:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = _cell_center(c.x, c.y, 0)
		body.add_child(shape)
	add_child(body)

## Celdas de cesped donde puede crecer hierba: las del suelo cuyo terreno es
## cesped y que no tienen un bloque encima ni son agua. Dictionary Vector2i ->
## true, que es lo que espera GrassScatter.
func grass_cells() -> Dictionary:
	var size := _cell_size()
	var ocupadas := {}
	for centro in _wall_centers:
		ocupadas[Vector2i(floori(centro.x / size.x), floori(centro.z / size.z))] = true
	var celdas := {}
	var rango := _ground_cell_range()
	for j in range(rango.position.y, rango.end.y):
		for i in range(rango.position.x, rango.end.x):
			var celda := Vector2i(i, j)
			if _terrain_at(i, j) == GroundAtlas.Terrain.GRASS and not ocupadas.has(celda) \
					and not _is_water(i, j):
				celdas[celda] = true
	return celdas

## Toda la hierba es una MultiMesh de quads verticales, una llamada de dibujo
## para miles de matas; el movimiento lo pone grass_tuft.gdshader.
##
## Cada mata es una cara vertical de GRASS_TUFT_TEXELS texeles, asi que lleva la
## misma compensacion que una pared: alto por cell_height. El pie se ajusta a la
## rejilla de pixeles de pantalla -- 1/32 de celda en X y en Z, que con la celda
## ya estirada son pasos de un pixel exacto -- para que el dibujo caiga texel a
## pixel igual que el suelo.
func _build_grass() -> void:
	_grass_material = null
	if not grass_enabled:
		return
	var matas := GrassScatter.scatter(grass_cells(), grass_density,
		grass_cluster_share, grass_cluster_radius, grass_cells_per_cluster,
		grass_margin, grass_seed)
	if matas.is_empty():
		return

	var size := _cell_size()
	var lado := GRASS_TUFT_TEXELS * VillageMetrics.TEXEL
	var quad := QuadMesh.new()
	quad.size = Vector2(lado, lado)
	quad.center_offset = Vector3(0.0, lado * 0.5, 0.0)

	var material := ShaderMaterial.new()
	material.shader = GRASS_SHADER
	material.set_shader_parameter(&"tufts", GRASS_TUFTS)
	material.set_shader_parameter(&"variants", GRASS_VARIANTS)
	material.set_shader_parameter(&"pixel_step", VillageMetrics.TEXEL * size)
	material.set_shader_parameter(&"tuft_height", lado * size.y)
	material.set_shader_parameter(&"wind_strength", grass_wind_strength)
	material.set_shader_parameter(&"push_radius", grass_push_radius)
	material.set_shader_parameter(&"player_position", player.global_position)
	_grass_material = material

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = quad
	multi.instance_count = matas.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = grass_seed
	var escala := Basis.from_scale(Vector3(1.0, size.y, 1.0))
	var paso := 1.0 / float(VillageMetrics.TEXELS_PER_CELL)
	for k in matas.size():
		var m := matas[k]
		var pie := Vector3(snappedf(m.x, paso) * size.x, 0.0, snappedf(m.y, paso) * size.z)
		multi.set_instance_transform(k, Transform3D(escala, pie))
		# Las altas (variantes 2 y 3) hacia el centro de la mancha y las bajas
		# hacia el borde y sueltas: la mancha se lee con volumen.
		var alta := rng.randf() < lerpf(0.15, 0.9, m.z)
		var variante := (2 if alta else 0) + rng.randi_range(0, 1)
		multi.set_instance_custom_data(k, Color(
			float(variante) / float(GRASS_VARIANTS), rng.randf(), 0.0, 0.0))

	var node := MultiMeshInstance3D.new()
	node.name = &"Grass"
	node.multimesh = multi
	node.material_override = material
	# Como el suelo: miles de matas en el mapa de sombras solo darian ruido. Si
	# reciben la de los muros, que la decide el material y no esto.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

## Los muros van de adoquin: la sala existe para juzgar la cara vertical y una
## pared de cesped no dice nada sobre como se lee la piedra en pantalla.
func _build_walls() -> void:
	_wall_kinds.clear()
	_wall_centers.clear()
	_wall_bases.clear()
	_wall_kind.resize(0)
	_add_wall_blocks()
	_prepare_walls()

	var body := StaticBody3D.new()
	body.name = &"WallBodies"
	for i in _wall_centers.size():
		var ocupa: AABB = _wall_kinds[_wall_kind[i]]["box"]
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = ocupa.size
		shape.shape = box
		# El giro va en el nodo y no en la caja: BoxShape3D no admite escala, y
		# un giro de 90 grados de una celda no cubica intercambia su ancho y su
		# fondo igual que lo hace el bloque que se ve.
		shape.transform = Transform3D(_wall_bases[i], _wall_centers[i]) 			* Transform3D(Basis.IDENTITY, ocupa.get_center())
		body.add_child(shape)
	add_child(body)

## Coloca los bloques de la sala. Es la costura por la que village.gd pone los
## que se han pintado en el editor: sobrescribe esta funcion y el resto del muro
## -- sombras, fundido, colision -- sale igual.
func _add_wall_blocks() -> void:
	var cubo := _add_wall_kind(BLOCK, COBBLESTONE,
		Transform3D(Basis.from_scale(_cell_size()), Vector3.ZERO))
	# Muro en L de tres hiladas, para juzgar la cara vertical.
	for i in range(-6, 3):
		for h in 3:
			_add_wall(_cell_center(i, -5, h), cubo)
	for j in range(-4, 1):
		for h in 3:
			_add_wall(_cell_center(2, j, h), cubo)
	# Escalones sueltos de una, dos y tres hiladas.
	for step in 3:
		for h in step + 1:
			_add_wall(_cell_center(5 + step * 2, 1, h), cubo)

## Registra un tipo de bloque y devuelve su indice. Lo que ocupa sale de la
## propia malla, asi que una losa de 8 texeles choca y tapa a su altura y no a la
## de una celda entera.
func _add_wall_kind(mesh: Mesh, material: Material, local: Transform3D) -> int:
	_wall_kinds.append({"mesh": mesh, "material": material, "local": local,
		"box": local * mesh.get_aabb()})
	return _wall_kinds.size() - 1

func _add_wall(center: Vector3, kind: int, giro := Basis.IDENTITY) -> void:
	_wall_centers.append(center)
	_wall_bases.append(giro)
	_wall_kind.append(kind)

## Los muros se reparten en tres nodos por tipo de bloque, porque un material
## transparente no proyecta sombra:
##
## - WallsShadow lleva todos los bloques, es invisible y solo se dibuja en el
##   mapa de sombras. Se construye una vez y no se vuelve a tocar, asi que la
##   sombra del muro no desaparece cuando el muro se transparenta.
## - WallsSolid lleva los bloques que no estan tapando a nadie, opacos.
## - WallsFaded lleva los que si, con transparencia y color por instancia, que
##   es lo que permite fundir cada bloque a su ritmo sin saltos.
##
## El primer tipo usa esos nombres tal cual y los siguientes les anaden su
## numero (WallsSolid2, ...), para que la sala de pruebas, que solo tiene uno,
## siga teniendo los nodos que las capturas buscan.
func _prepare_walls() -> void:
	_walls_solid.clear()
	_walls_faded.clear()
	_kind_members.clear()
	for k in _wall_kinds.size():
		var miembros := PackedInt32Array()
		for i in _wall_centers.size():
			if _wall_kind[i] == k:
				miembros.append(i)
		_kind_members.append(miembros)

		var sufijo := "" if k == 0 else str(k + 1)
		var tipo := _wall_kinds[k]
		var material: Material = tipo["material"]
		var shadows := _wall_node(StringName("WallsShadow" + sufijo), tipo, material, false)
		shadows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		_fill_wall_node(shadows, k, miembros)

		var solid := _wall_node(StringName("WallsSolid" + sufijo), tipo, material, false)
		solid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_walls_solid.append(solid)

		# Un material que no sea BaseMaterial3D (un shader, o la malla sin
		# material propio) no se sabe volver transparente: esos bloques se
		# quedan opacos en vez de romperse.
		var translucido: Material = material
		if material is BaseMaterial3D:
			var copia := (material as BaseMaterial3D).duplicate() as BaseMaterial3D
			copia.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			copia.vertex_color_use_as_albedo = true
			translucido = copia
		var faded := _wall_node(StringName("WallsFaded" + sufijo), tipo, translucido, true)
		faded.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_walls_faded.append(faded)

	_wall_rects.clear()
	_wall_depth.resize(_wall_centers.size())
	_wall_fade.resize(_wall_centers.size())
	_wall_fade.fill(0.0)
	for i in _wall_centers.size():
		# Los bloques no se mueven y el rectangulo no depende de donde este la
		# camara (ver _screen_rect), asi que esto se calcula una vez.
		var ocupa: AABB = _wall_kinds[_wall_kind[i]]["box"]
		_wall_rects.append(_screen_rect(_wall_centers[i] + ocupa.get_center(), ocupa.size))
		# Profundidad del mundo, no la del espacio de camara. Con la camara
		# inclinada el espacio de camara mezcla altura con profundidad, y el
		# centro de un bloque alto sale "mas cerca" que un personaje que esta
		# delante pero a ras de suelo: la pared se transparentaba yendo por
		# delante. El sprite del personaje es un plano a su propia z, asi que lo
		# que decide quien tapa a quien es la z del mundo.
		_wall_depth[i] = _wall_centers[i].z
	_refresh_walls()

func _wall_node(node_name: StringName, tipo: Dictionary, material: Material,
		colors: bool) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = colors
	multi.mesh = tipo["mesh"]
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = multi
	node.material_override = material
	add_child(node)
	return node

func _fill_wall_node(node: MultiMeshInstance3D, kind: int,
		indices: PackedInt32Array) -> void:
	var local: Transform3D = _wall_kinds[kind]["local"]
	var multi := node.multimesh
	multi.instance_count = indices.size()
	for k in indices.size():
		var idx := indices[k]
		multi.set_instance_transform(k,
			Transform3D(_wall_bases[idx], _wall_centers[idx]) * local)
		if multi.use_colors:
			multi.set_instance_color(k, Color(1.0, 1.0, 1.0,
				lerpf(1.0, occluder_opacity, _wall_fade[idx])))

func _refresh_walls() -> void:
	for k in _kind_members.size():
		var solidos := PackedInt32Array()
		var fundidos := PackedInt32Array()
		for i in _kind_members[k]:
			if _wall_fade[i] > 0.001:
				fundidos.append(i)
			else:
				solidos.append(i)
		_fill_wall_node(_walls_solid[k], k, solidos)
		_fill_wall_node(_walls_faded[k], k, fundidos)

## Rectangulo que ocupa en pantalla la caja de una celda, en el sistema de
## VillageMetrics.screen_point: sin la posicion de la camara, para que siga
## valiendo cuando la camara sigue al personaje. La silueta del personaje en
## _process se mide en el mismo sistema, y es lo unico con lo que se compara.
func _screen_rect(center: Vector3, size: Vector3) -> Rect2:
	var half := size * 0.5
	var rect := Rect2()
	var primero := true
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var punto := VillageMetrics.screen_point(center
					+ Vector3(half.x * sx, half.y * sy, half.z * sz), pitch_degrees)
				if primero:
					rect = Rect2(punto, Vector2.ZERO)
					primero = false
				else:
					rect = rect.expand(punto)
	return rect

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if follow_player:
		_move_camera()
	if _grass_material != null:
		_grass_material.set_shader_parameter(&"player_position", player.global_position)
	if _walls_faded.is_empty():
		return
	var caja := player_screen_box(occluder_margin_cells * VillageMetrics.PIXELS_PER_UNIT)
	var fondo: float = player.global_position.z
	var paso: float = delta / maxf(occluder_fade_time, 0.001)
	var cambio := false
	for i in _wall_centers.size():
		# Tapa al personaje si le solapa en pantalla y su celda esta por delante
		# de la suya en profundidad. El margen evita que una pieza en su misma
		# fila parpadee.
		var tapa: bool = _wall_depth[i] > fondo + 0.05 and _wall_rects[i].intersects(caja)
		var previo := _wall_fade[i]
		_wall_fade[i] = move_toward(previo, 1.0 if tapa else 0.0, paso)
		cambio = cambio or not is_equal_approx(previo, _wall_fade[i])
	if cambio:
		_refresh_walls()

## Rectangulo del personaje en pantalla, ensanchado `margin_px` por cada lado, en
## el sistema de VillageMetrics.screen_point. Con el se busca lo que le tapa: los
## muros aqui y las copas de los arboles en village.gd.
func player_screen_box(margin_px: float) -> Rect2:
	var sprite := player.get_node(^"AnimatedSprite3D") as AnimatedSprite3D
	var pies := VillageMetrics.screen_point(player.global_position, pitch_degrees)
	var arriba := VillageMetrics.screen_point(player.global_position
		+ Vector3(0.0, 32.0 * sprite.pixel_size * sprite.scale.y, 0.0), pitch_degrees)
	var ancho := VillageMetrics.player_width() * VillageMetrics.PIXELS_PER_UNIT
	return Rect2(Vector2(pies.x - ancho * 0.5, arriba.y),
		Vector2(ancho, pies.y - arriba.y)).grow(margin_px)

func _cell_center(i: int, j: int, height: int) -> Vector3:
	var size := _cell_size()
	return Vector3((i + 0.5) * size.x, (height + 0.5) * size.y, (j + 0.5) * size.z)

func _place_camera() -> void:
	var pitch := deg_to_rad(pitch_degrees)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = VillageMetrics.camera_size()
	camera.rotation = Vector3(-pitch, 0.0, 0.0)
	_move_camera()

## La camara mira al objetivo desde siempre la misma distancia y el mismo angulo:
## al seguir al personaje solo se desplaza, nunca gira.
func _move_camera() -> void:
	var pitch := deg_to_rad(pitch_degrees)
	var objetivo := Vector3.ZERO
	if follow_player and not Engine.is_editor_hint():
		objetivo = camera_target_for(player.global_position)
	camera.position = objetivo + Vector3(0.0, sin(pitch) * 24.0, cos(pitch) * 24.0)

## Punto del suelo al que mira la camara cuando el personaje esta en `p`.
##
## Se calcula en pixeles de pantalla (el sistema de VillageMetrics.screen_point)
## por dos razones:
##
## - Encaje al pixel. Desplazar la camara un numero entero de pixeles mueve todo
##   lo estatico un numero entero de pixeles, asi que el suelo y los muros siguen
##   cayendo texel a pixel y no tiemblan al andar. En mundo eso son pasos de 1/32
##   en X y de 1/(32 sen p) en Z.
## - Limites. El suelo esta en y=0 y cada celda mide 32 px en pantalla en los dos
##   ejes, asi que sus bordes en pantalla salen directos del rango de teselas.
##   El objetivo se frena para que el encuadre no pase del borde del suelo; si
##   el mapa es mas estrecho que la pantalla, la camara se queda en su centro.
func camera_target_for(p: Vector3) -> Vector3:
	var seno := sin(deg_to_rad(pitch_degrees))
	var ppu := VillageMetrics.PIXELS_PER_UNIT
	var mitad := Vector2(VillageMetrics.viewport_width(),
		VillageMetrics.viewport_height()) * 0.5
	var teselas := _ground_tile_range()
	# Las teselas van media celda al noroeste: la (i,j) empieza en i-0,5.
	var borde_min := (Vector2(teselas.position) - Vector2(0.5, 0.5)) * ppu
	var borde_max := (Vector2(teselas.end) - Vector2(0.5, 0.5)) * ppu
	var px := VillageMetrics.screen_point(Vector3(p.x, 0.0, p.z), pitch_degrees)
	px = Vector2(_frenar(px.x, borde_min.x + mitad.x, borde_max.x - mitad.x),
		_frenar(px.y, borde_min.y + mitad.y, borde_max.y - mitad.y)).round()
	return Vector3(px.x / ppu, 0.0, px.y / (seno * ppu))

func _frenar(valor: float, minimo: float, maximo: float) -> float:
	if minimo > maximo:
		return (minimo + maximo) * 0.5
	return clampf(valor, minimo, maximo)

func _fit_sprite() -> void:
	var sprite: AnimatedSprite3D = player.get_node(^"AnimatedSprite3D")
	sprite.pixel_size = VillageMetrics.player_pixel_size()
	sprite.scale = Vector3(1.0, VillageMetrics.sprite_scale_y(pitch_degrees), 1.0)
	# Sin esto el sprite ignora la luz por completo: es el valor por defecto de
	# SpriteBase3D y hace que el personaje no se oscurezca al pasar por una
	# sombra. Exige que la luz total de la escena no pase de 1, o un albedo casi
	# blanco como el suyo se satura y pierde el dibujo.
	sprite.shaded = true
	_fit_body()

## La capsula y la sombra no son arte, asi que siguen al dibujo en vez de
## quedarse con los valores de la escena del personaje. Se ajustan aqui, en
## tiempo de ejecucion, para no tocar player_3d.tscn.
##
## El cuerpo va en dos piezas para poder subir bordillos a pie de pixel. La
## capsula empieza por encima del paso, asi que choca con muros pero no con una
## losa; debajo, un pie estrecho de fondo plano es lo que pisa el suelo y lo que
## tropieza con el canto. Con la capsula sola, que es redonda y ancha por abajo,
## el personaje subia antes de llegar al bordillo, se quedaba flotando unos
## fotogramas y al bajar resbalaba por la arista y caia con la gravedad.
func _fit_body() -> void:
	var paso := STEP_TEXELS * VillageMetrics.TEXEL * VillageMetrics.cell_height(pitch_degrees)
	var shape := player.get_node(^"CollisionShape3D") as CollisionShape3D
	var capsule := (shape.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
	# La huella en el suelo es mas estrecha que los hombros: un personaje de una
	# celda de ancho tiene que pasar por un hueco de una celda sin engancharse.
	capsule.radius = VillageMetrics.player_width() * 0.7 * 0.5
	capsule.height = maxf(VillageMetrics.player_height(pitch_degrees) - paso,
		capsule.radius * 2.0)
	shape.shape = capsule
	shape.position = Vector3(0.0, paso + capsule.height * 0.5, 0.0)

	var pie := player.get_node_or_null(^"Pie") as CollisionShape3D
	if pie == null:
		pie = CollisionShape3D.new()
		pie.name = &"Pie"
		player.add_child(pie)
	var cilindro := CylinderShape3D.new()
	cilindro.radius = FOOT_TEXELS * VillageMetrics.TEXEL
	# Se mete en la capsula hasta su parte ancha para que no quede un hueco entre
	# las dos piezas por el que se cuele la esquina de un muro.
	cilindro.height = paso + capsule.radius
	pie.shape = cilindro
	pie.position = Vector3(0.0, cilindro.height * 0.5, 0.0)
	player.set(&"step_height", paso)

	var shadow := player.get_node_or_null(^"Shadow") as MeshInstance3D
	if shadow != null and shadow.mesh is CylinderMesh:
		var disc := (shadow.mesh as CylinderMesh).duplicate() as CylinderMesh
		disc.top_radius = VillageMetrics.player_width() * 0.75 * 0.5
		disc.bottom_radius = disc.top_radius
		shadow.mesh = disc
