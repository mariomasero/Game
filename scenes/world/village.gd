@tool
extends "res://scenes/world/test_room.gd"

## Pueblo pintado a mano en el editor (docs/decisions/013-mapa-autorado-con-gridmap.md).
## Como se usa: docs/guias/02-pintar-el-mapa.md.
##
## Reutiliza todo lo de la sala de pruebas -- suelo por teselas, muros con
## sombra y fundido, camara, personaje -- y solo cambia DE DONDE sale el mapa:
##
## - Terreno es un GridMap que hace de lienzo. Sus casillas son marcadores planos
##   de paint_terrain.meshlib.tres; aqui se leen por NOMBRE de item y se traducen
##   con GroundAtlas.terrain_from_id, asi que el entero del item no significa
##   nada y reordenar la biblioteca no rompe el mapa. Solo cuenta la planta 0.
##   El marcador WaterSurface.ITEM no es un terreno: esas casillas son agua.
## - Bloques es un GridMap normal con bloques de paint_blocks.meshlib.tres. En el
##   editor los dibuja el propio GridMap; en el juego se oculta y sus casillas se
##   convierten en los muros de siempre, con colision y fundido.
## - Objetos (un Node3D) guarda arboles, casas y demas escenas VillageProp que se
##   arrastran a mano. No necesitan nada de aqui: se guardan en la escena tal cual.
## - Parcela es un GridMap con un solo marcador, PlotLayout.ITEM_PARCELA: las
##   casillas donde se pueden poner muebles (decision 014).
## - Muebles (un Node3D) guarda los muebles iniciales de la parcela, escenas
##   VillageProp puestas a mano igual que los Objetos. Se registran en `layout`,
##   que es lo que usara el modo construir para moverlos.
##
## En el editor se construye solo el suelo, como vista previa sin owner, para
## que nunca acabe guardado en village.tscn. Se regenera solo al pintar. Los
## muebles se comprueban tambien solos y sus problemas salen como aviso en el
## nodo Pueblo.

## GridMap donde se pinta el terreno del suelo.
@export var terrain_map: GridMap:
	set(valor):
		terrain_map = valor
		update_configuration_warnings()

## GridMap donde se pintan los bloques: muros, escalones, terreno elevado.
@export var block_map: GridMap:
	set(valor):
		block_map = valor
		update_configuration_warnings()

## GridMap donde se pinta la parcela del laboratorio.
@export var plot_map: GridMap:
	set(valor):
		plot_map = valor
		update_configuration_warnings()

## Nodo del que cuelgan los objetos decorativos. Dentro de la parcela estorban a
## los muebles igual que un bloque.
@export var props_root: Node3D

## Nodo del que cuelgan los muebles iniciales de la parcela.
@export var furniture_root: Node3D:
	set(valor):
		furniture_root = valor
		update_configuration_warnings()

## Los muebles que se pueden poner en la parcela. Un mueble de Muebles se
## reconoce porque su escena es la `escena` de una de estas definiciones.
@export var catalog: Array[PlaceableDefinition] = []

## Por si la vista previa se queda atras. Normalmente no hace falta: el suelo se
## rehace solo un cuarto de segundo despues de pintar.
@export_tool_button("Regenerar suelo", "Reload") var regenerar_suelo: Callable = _regenerate_preview

## Quien ocupa cada casilla de la parcela. Se rellena al arrancar con la parcela
## pintada, los bloques y objetos que caen dentro y los muebles de Muebles.
var layout := PlotLayout.new()

## Celdas de hierba que se anaden alrededor de lo pintado, para que el borde del
## mapa no acabe justo en la ultima casilla.
const MARGEN_PINTADO := 2

## Cada cuanto mira el editor si ha cambiado lo pintado. GridMap no avisa cuando
## se pinta una casilla, asi que se compara una huella.
const INTERVALO_EDITOR := 0.25

## Terreno leido de terrain_map: Vector2i -> GroundAtlas.Terrain. Lo que no esta
## es hierba.
var _terreno := {}

## Casillas pintadas con el marcador de agua: Vector2i -> true.
var _agua := {}

## Rectangulo de celdas que cubre todo lo pintado, suelo y bloques. Vacio si no
## hay nada.
var _pintado := Rect2i()

var _huella := 0
var _huella_parcela := 0
var _espera := 0.0

## Casillas pintadas en plot_map: Vector2i -> true.
var _parcela := {}

## Lo que no cuadra de los muebles de Muebles, para los avisos del editor.
var _problemas_muebles := PackedStringArray()

## Objetos de Objetos que flotan, para los avisos del editor.
var _problemas_objetos := PackedStringArray()

## Arboles del pueblo, cuelguen de donde cuelguen, para fundir su copa.
var _arboles: Array[VillageTree] = []

func _ready() -> void:
	_ajustar_rejillas()
	if Engine.is_editor_hint():
		_place_camera()
		_regenerate_preview()
		_revisar_parcela()
		return
	for mapa: GridMap in _rejillas():
		# El lienzo, los bloques y la parcela del editor no se ven ni chocan en
		# el juego: los sustituyen el suelo por teselas y los muros de
		# test_room.gd, y la parcela es solo un dato.
		mapa.visible = false
		mapa.collision_layer = 0
		mapa.collision_mask = 0
	_leer_terreno()
	# Los hijos ya han pasado por _ready, asi que cada VillageProp ya ha medido
	# su modelo y sabe su huella.
	_leer_parcela()
	_leer_muebles()
	for problema in _problemas_muebles:
		push_warning("Parcela: " + problema)
	for problema in _problemas_objetos:
		push_warning("Objetos: " + problema)
	_arboles.clear()
	_buscar_arboles(self)
	super()

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		super(delta)
		_fundir_copas(delta)
		return
	_espera -= delta
	if _espera > 0.0:
		return
	_espera = INTERVALO_EDITOR
	if _huella_pintura() != _huella:
		_regenerate_preview()
	if _huella_muebles() != _huella_parcela:
		_revisar_parcela()

func _buscar_arboles(nodo: Node) -> void:
	for hijo in nodo.get_children():
		if hijo is VillageTree:
			_arboles.append(hijo)
		else:
			_buscar_arboles(hijo)

## La copa que tapa al personaje se funde como los muros y con su mismo tiempo
## (occluder_fade_time). Tapa si un texel opaco de la copa cae sobre el y el
## arbol esta por delante; el margen de 0,05 es el de los muros, para que un
## arbol en su misma fila no parpadee.
func _fundir_copas(delta: float) -> void:
	if _arboles.is_empty():
		return
	var caja := player_screen_box(0.0)
	var fondo: float = player.global_position.z
	var paso: float = delta / maxf(occluder_fade_time, 0.001)
	for arbol in _arboles:
		var tapando := arbol.global_position.z > fondo + 0.05 			and arbol.tapa(caja, pitch_degrees)
		arbol.fundir(tapando, paso)

func _rejillas() -> Array[GridMap]:
	var lista: Array[GridMap] = []
	for mapa: GridMap in [terrain_map, block_map, plot_map]:
		if mapa != null:
			lista.append(mapa)
	return lista

## La celda del GridMap tiene que medir lo mismo que la del suelo. Se fija desde
## aqui para que nadie tenga que escribir 1,7434 a mano en el Inspector.
func _ajustar_rejillas() -> void:
	for mapa: GridMap in _rejillas():
		if mapa == null:
			continue
		mapa.cell_size = _cell_size()
		mapa.cell_center_x = true
		mapa.cell_center_y = true
		mapa.cell_center_z = true
		mapa.cell_scale = 1.0

## Vista previa del suelo en el editor. En el juego no hace falta: _ready la
## construye una vez con su colisionador.
func _regenerate_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_ajustar_rejillas()
	_leer_terreno()
	_huella = _huella_pintura()
	for nombre: NodePath in [^"Ground", ^"Water"]:
		var viejo := get_node_or_null(nombre)
		if viejo != null:
			remove_child(viejo)
			viejo.queue_free()
	_build_ground_node(_ground_tile_range())
	_build_water_node()
	update_configuration_warnings()

func _huella_pintura() -> int:
	var datos := []
	if terrain_map != null:
		for celda in terrain_map.get_used_cells():
			datos.append(celda)
			datos.append(terrain_map.get_cell_item(celda))
	if block_map != null:
		datos.append(block_map.get_used_cells())
	return hash(datos)

func _leer_terreno() -> void:
	_terreno.clear()
	_agua.clear()
	var zona := Rect2i()
	var hay := false
	var fuera_de_planta := 0
	var desconocidos := {}
	if terrain_map != null and terrain_map.mesh_library != null:
		var lib := terrain_map.mesh_library
		var existentes := lib.get_item_list()
		for celda in terrain_map.get_used_cells():
			if celda.y != 0:
				fuera_de_planta += 1
				continue
			var item := terrain_map.get_cell_item(celda)
			# get_item_name de un item que no existe no devuelve vacio: da error.
			var nombre := StringName(lib.get_item_name(item)) if existentes.has(item) \
				else StringName("#%d" % item)
			var plano := Vector2i(celda.x, celda.z)
			if nombre == WaterSurface.ITEM:
				_agua[plano] = true
				zona = _incluir(zona, hay, plano)
				hay = true
				continue
			var terreno := GroundAtlas.terrain_from_id(nombre)
			if terreno < 0:
				desconocidos[nombre] = true
				continue
			_terreno[plano] = terreno
			zona = _incluir(zona, hay, plano)
			hay = true
	# La parcela tambien cuenta: sin suelo debajo no se podria andar hasta ella.
	for mapa: GridMap in [block_map, plot_map]:
		if mapa == null:
			continue
		for celda in mapa.get_used_cells():
			zona = _incluir(zona, hay, Vector2i(celda.x, celda.z))
			hay = true
	_pintado = zona if hay else Rect2i()

	if fuera_de_planta > 0:
		push_warning(("Terreno: %d casillas pintadas fuera de la planta 0. El suelo " +
			"solo lee la planta 0; para poner altura usa el GridMap Bloques.") % fuera_de_planta)
	if not desconocidos.is_empty():
		push_warning(("Terreno: items sin terreno conocido %s. Se dibujan como hierba. " +
			"Los nombres validos son %s y %s.") % [str(desconocidos.keys()),
			str(GroundAtlas.TERRAIN_IDS), WaterSurface.ITEM])

## Casillas de la parcela, de la planta 0 de plot_map, leidas por nombre de item
## como el terreno.
func _leer_parcela() -> void:
	_parcela.clear()
	if plot_map == null or plot_map.mesh_library == null:
		return
	var lib := plot_map.mesh_library
	var existentes := lib.get_item_list()
	var fuera_de_planta := 0
	var desconocidos := {}
	for celda in plot_map.get_used_cells():
		if celda.y != 0:
			fuera_de_planta += 1
			continue
		var item := plot_map.get_cell_item(celda)
		var nombre := StringName(lib.get_item_name(item)) if existentes.has(item) \
			else StringName("#%d" % item)
		if nombre != PlotLayout.ITEM_PARCELA:
			desconocidos[nombre] = true
			continue
		_parcela[Vector2i(celda.x, celda.z)] = true
	if fuera_de_planta > 0:
		push_warning(("Parcela: %d casillas pintadas fuera de la planta 0. Los muebles " +
			"van a ras de suelo; solo cuenta la planta 0.") % fuera_de_planta)
	if not desconocidos.is_empty():
		push_warning("Parcela: items desconocidos %s; se ignoran. El valido es %s." % [
			str(desconocidos.keys()), PlotLayout.ITEM_PARCELA])

## Rellena `layout` con la parcela, lo que estorba dentro de ella y los muebles
## de furniture_root, y apunta en _problemas_muebles lo que no cuadra. No mueve
## nada: un mueble mal puesto se queda donde esta y se avisa.
func _leer_muebles() -> void:
	layout = PlotLayout.new()
	_problemas_muebles.clear()
	_problemas_objetos.clear()
	layout.permitidas = _parcela.duplicate()
	var celda := _cell_size()

	# Lo que estorba: agua, bloques a ras de suelo y objetos decorativos.
	for c: Vector2i in _agua:
		layout.bloqueadas[c] = true
	if block_map != null:
		for c in block_map.get_used_cells():
			if c.y == 0:
				layout.bloqueadas[Vector2i(c.x, c.z)] = true
	if props_root != null:
		for hijo in props_root.get_children():
			var objeto := hijo as VillageProp
			if objeto == null:
				continue
			var ocupa := objeto.huella()
			var origen := PlotLayout.origen_desde_mundo(ocupa, objeto.position, 0, celda)
			for c in PlotLayout.celdas(ocupa, origen, 0):
				layout.bloqueadas[c] = true
			if _flota(objeto.position, celda):
				_problemas_objetos.append(("%s flota en el aire (altura %.2f) sin un " +
					"bloque debajo. En el juego se vera mas atras de donde parece en " +
					"el editor: pon su altura (Position -> y) a 0.") % [objeto.name,
					objeto.position.y])

	if furniture_root == null:
		return
	var por_escena := {}
	for def in catalog:
		if def != null and def.escena != null:
			por_escena[def.escena.resource_path] = def
	for hijo in furniture_root.get_children():
		var mueble := hijo as VillageProp
		if mueble == null:
			_problemas_muebles.append("%s no es un objeto VillageProp." % hijo.name)
			continue
		var def: PlaceableDefinition = por_escena.get(mueble.scene_file_path)
		if def == null:
			_problemas_muebles.append(("%s no esta en el catalogo de Pueblo: anade su " +
				"definicion a Catalog en el Inspector.") % mueble.name)
			continue
		var giro := mueble.giro_en_pasos()
		var ocupa := PlotLayout.huella_girada(def.huella, giro)
		if mueble.caja.size != Vector3.ZERO and mueble.huella() != ocupa:
			_problemas_muebles.append(("%s mide %s casillas pero su definicion dice %s. " +
				"Corrige la huella en %s.") % [mueble.name, mueble.huella(), ocupa,
				def.resource_path.get_file()])
		var origen := PlotLayout.origen_desde_mundo(def.huella, mueble.position, giro, celda)
		var centro := PlotLayout.centro_en_mundo(def.huella, origen, giro, celda)
		if not Vector2(centro.x, centro.z).is_equal_approx(
				Vector2(mueble.position.x, mueble.position.z)) \
				or not is_zero_approx(mueble.position.y):
			_problemas_muebles.append(("%s no esta encajado en una casilla a ras de " +
				"suelo. Enciende Ajustar A Rejilla o pon su altura a 0.") % mueble.name)
		var motivo := layout.motivo_para_no_colocar(def, origen, giro)
		if motivo != &"":
			_problemas_muebles.append("%s en %s: %s." % [mueble.name, origen,
				_explicar(motivo)])
			continue
		layout.colocar(def, origen, giro)

## Si un objeto puesto en `p` queda en el aire: por encima del suelo y sin la
## cara de arriba de un bloque justo debajo. Con la camara del juego inclinada,
## lo que flota h unidades se ve h / tan(p) mas atras (a 55 grados, dos plantas
## son dos casillas), mientras que la camara libre del editor lo pone en otro
## sitio segun desde donde se mire: el objeto parece moverse al darle a jugar.
func _flota(p: Vector3, celda: Vector3) -> bool:
	if is_zero_approx(p.y):
		return false
	if p.y < 0.0 or block_map == null or block_map.mesh_library == null:
		return true
	# La casilla donde cae el punto justo por debajo del pie. La altura de su
	# bloque sale de la malla, como en los muros: una losa de acera mide un
	# cuarto de planta y una farola encima esta bien puesta.
	var debajo := Vector3i(floori(p.x / celda.x), floori(p.y / celda.y - 0.01),
		floori(p.z / celda.z))
	var item := block_map.get_cell_item(debajo)
	var lib := block_map.mesh_library
	if item == GridMap.INVALID_CELL_ITEM or not lib.get_item_list().has(item) \
			or lib.get_item_mesh(item) == null:
		return true
	var caja := lib.get_item_mesh_transform(item) * lib.get_item_mesh(item).get_aabb()
	var arriba := (debajo.y + 0.5) * celda.y + caja.end.y
	# Medio texel de tolerancia, como la base de VillageProp.
	return absf(p.y - arriba) > 0.5 * VillageMetrics.TEXEL

func _explicar(motivo: StringName) -> String:
	var textos := {
		PlotLayout.FUERA_DE_PARCELA: "se sale de la parcela",
		PlotLayout.BLOQUEADA: "hay un bloque u objeto en esas casillas",
		PlotLayout.OCUPADA: "se solapa con otro mueble",
	}
	return textos.get(motivo, String(motivo))

## Vuelve a leer parcela y muebles en el editor y refresca los avisos.
func _revisar_parcela() -> void:
	if not is_inside_tree():
		return
	_huella_parcela = _huella_muebles()
	_leer_parcela()
	_leer_muebles()
	update_configuration_warnings()

## Cambia si se pinta la parcela o los bloques, o si se mueve, gira, anade o
## quita un mueble u objeto.
func _huella_muebles() -> int:
	var datos := []
	for mapa: GridMap in [plot_map, block_map]:
		if mapa != null:
			datos.append(mapa.get_used_cells())
	for raiz: Node3D in [props_root, furniture_root]:
		if raiz == null:
			continue
		for hijo in raiz.get_children():
			datos.append(hijo.name)
			datos.append(hijo.scene_file_path)
			if hijo is Node3D:
				datos.append((hijo as Node3D).transform)
	return hash(datos)

func _incluir(zona: Rect2i, hay: bool, celda: Vector2i) -> Rect2i:
	var una := Rect2i(celda, Vector2i.ONE)
	return zona.merge(una) if hay else una

func _terrain_at(i: int, j: int) -> int:
	return _terreno.get(Vector2i(i, j), GroundAtlas.Terrain.GRASS)

func _is_water(i: int, j: int) -> bool:
	return _agua.has(Vector2i(i, j))

## El suelo cubre como minimo lo que ve la camara, como en la sala, y ademas todo
## lo pintado con su margen: nunca queda una casilla pintada sin suelo debajo.
func _ground_cell_range() -> Rect2i:
	var rango := super()
	if _pintado.has_area():
		rango = rango.merge(_pintado.grow(MARGEN_PINTADO))
	return rango

## Un tipo de muro por item de la biblioteca: la malla, su material y su
## transformacion (con la escala anisotropa horneada) salen del propio item, asi
## que un bloque nuevo anadido a la biblioteca funciona sin tocar este script.
func _add_wall_blocks() -> void:
	if block_map == null or block_map.mesh_library == null:
		return
	var lib := block_map.mesh_library
	var tipos := {}
	var celdas := block_map.get_used_cells()
	# Orden fijo, para que dos arranques del mismo mapa den los mismos nodos.
	celdas.sort()
	for celda in celdas:
		var item := block_map.get_cell_item(celda)
		if not tipos.has(item):
			var malla: Mesh = lib.get_item_mesh(item) if lib.get_item_list().has(item) else null
			if malla == null or malla.get_surface_count() == 0:
				push_warning("Bloques: el item %d no existe o no tiene malla; se ignora." % item)
				tipos[item] = -1
			else:
				tipos[item] = _add_wall_kind(malla, malla.surface_get_material(0),
					lib.get_item_mesh_transform(item))
		if tipos[item] < 0:
			continue
		_add_wall(_cell_center(celda.x, celda.z, celda.y), tipos[item],
			block_map.get_cell_item_basis(celda))

func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	if terrain_map == null:
		avisos.append("Asigna el GridMap Terreno a Terrain Map en el Inspector.")
	elif terrain_map.mesh_library == null:
		avisos.append("Terreno no tiene Mesh Library: usa paint_terrain.meshlib.tres.")
	if block_map == null:
		avisos.append("Asigna el GridMap Bloques a Block Map en el Inspector.")
	elif block_map.mesh_library == null:
		avisos.append("Bloques no tiene Mesh Library: usa paint_blocks.meshlib.tres.")
	if plot_map == null:
		avisos.append("Asigna el GridMap Parcela a Plot Map en el Inspector.")
	elif plot_map.mesh_library == null:
		avisos.append("Parcela no tiene Mesh Library: usa paint_zones.meshlib.tres.")
	for mapa in _rejillas():
		if not mapa.transform.is_equal_approx(Transform3D.IDENTITY):
			avisos.append(("%s se ha movido, girado o escalado. Dejalo en 0,0,0 o lo " +
				"pintado no coincidira con el juego.") % mapa.name)
	for raiz: Node3D in [props_root, furniture_root]:
		if raiz != null and not raiz.transform.is_equal_approx(Transform3D.IDENTITY):
			avisos.append(("%s se ha movido, girado o escalado. Dejalo en 0,0,0 o sus " +
				"objetos no caeran en las casillas.") % raiz.name)
	for problema in _problemas_muebles:
		avisos.append("Parcela: " + problema)
	for problema in _problemas_objetos:
		avisos.append("Objetos: " + problema)
	return avisos
