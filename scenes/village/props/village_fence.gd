@tool
class_name VillageFence
extends VillageProp

## Valla que se une sola con las de las casillas de al lado. Suelta es solo el
## poste; por cada vecina le sale un tramo hacia ella que llega justo al borde de
## la casilla, donde empieza el de la vecina. Dos vallas juntas forman un paño de
## 64 texeles de largo y 32 de alto (las piezas: tools/build_fence.gd).
##
## Vecinas son las VillageFence con el mismo padre, en la misma planta y a una
## casilla en X o en Z; no cuentan las diagonales.
##
## Los tramos y sus colisiones se crean al entrar en el arbol como nodos INTERNOS:
## no se guardan en la escena, no cuentan en la caja del modelo -- la huella sigue
## siendo la del poste, 1 x 1 -- y encenderlos o apagarlos en el editor no deja
## cambios en village.tscn.

const GRUPO := &"village_fence"
const TRAMO_MALLA := "res://assets/game/models/metal_fence/fence_rail.obj"
const TRAMO_MATERIAL := "res://assets/game/materials/metal_fence_pixel.tres"

## Lo que choca de un tramo hacia +X, en texeles: del fuste al borde y de la
## altura de los barrotes. Tan hondo como el fuste, para que no se cuele nada.
const TRAMO_CAJA := AABB(Vector3(3, 0, -3), Vector3(13, 26, 6))

## Hacia donde sale cada tramo, en los ejes de la valla sin girar. La malla del
## tramo va hacia +X y se gira sobre Y para los demas.
const LADOS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(0, 0, 1),
	Vector3i(-1, 0, 0), Vector3i(0, 0, -1)]

## Un tramo por lado, en el orden de LADOS, y su colision.
var tramos: Array[MeshInstance3D] = []
var choques: Array[CollisionShape3D] = []

var _pendiente := false

func _ready() -> void:
	super()
	add_to_group(GRUPO)
	_crear_tramos()
	_avisar_vecinas()

func _notification(what: int) -> void:
	# VillageProp recibe tambien estas notificaciones y encaja la valla; la union
	# se pide diferida, cuando ya esta en su sitio.
	match what:
		NOTIFICATION_LOCAL_TRANSFORM_CHANGED, NOTIFICATION_EXIT_TREE:
			_avisar_vecinas()

## Casilla de la valla en la rejilla de su padre: (columna, planta, fila).
func casilla() -> Vector3i:
	var celda := _celda()
	return Vector3i(floori(position.x / celda.x), roundi(position.y / celda.y),
		floori(position.z / celda.z))

func _crear_tramos() -> void:
	var modelo := get_node_or_null(MODELO) as Node3D
	var cuerpo := get_node_or_null(^"Colision") as StaticBody3D
	if modelo == null or cuerpo == null or not tramos.is_empty():
		return
	var malla: Mesh = load(TRAMO_MALLA)
	var material: Material = load(TRAMO_MATERIAL)
	for lado in LADOS:
		var tramo := MeshInstance3D.new()
		tramo.name = "Tramo"
		tramo.mesh = malla
		tramo.set_surface_override_material(0, material)
		# Girar sobre Y un angulo t lleva +X a (cos t, 0, -sin t).
		tramo.basis = Basis(Vector3.UP, atan2(-lado.z, lado.x))
		tramo.visible = false
		modelo.add_child(tramo, false, Node.INTERNAL_MODE_BACK)
		tramos.append(tramo)
		var choque := CollisionShape3D.new()
		choque.name = "Tramo"
		choque.shape = BoxShape3D.new()
		choque.disabled = true
		cuerpo.add_child(choque, false, Node.INTERNAL_MODE_BACK)
		choques.append(choque)

## Pide que se vuelvan a unir esta valla y las de su mismo padre. Al quitar una
## valla, las demas lo notan porque cuando llega la llamada ya no esta.
##
## Las otras vallas se tratan por el grupo y con call(), sin nombrar VillageFence:
## con el script refiriendose a su propia clase, al cargarlo desde la escena
## Godot 4.7.2 dejaba scripts sin liberar al salir (medido en
## tests/test_village_map.gd: 13 instancias y 8 recursos).
func _avisar_vecinas() -> void:
	if not is_inside_tree():
		return
	for otra in get_tree().get_nodes_in_group(GRUPO):
		if otra.get_parent() == get_parent():
			otra.call(&"_pedir_union")

func _pedir_union() -> void:
	if _pendiente:
		return
	_pendiente = true
	unir.call_deferred()

## Enciende el tramo y la colision de cada lado que tiene una valla vecina.
func unir() -> void:
	_pendiente = false
	if not is_inside_tree() or tramos.is_empty():
		return
	var ocupadas := {}
	for otra in get_tree().get_nodes_in_group(GRUPO):
		if otra != self and otra.get_parent() == get_parent() \
				and not otra.is_queued_for_deletion():
			ocupadas[otra.call(&"casilla")] = true
	var modelo := get_node(MODELO) as Node3D
	var giro := _giro()
	var mia := casilla()
	for i in LADOS.size():
		var hacia := giro * Vector3(LADOS[i])
		var unida := ocupadas.has(mia + Vector3i(roundi(hacia.x), 0, roundi(hacia.z)))
		tramos[i].visible = unida
		choques[i].disabled = not unida
		_colocar_choque(choques[i], modelo.transform * tramos[i].transform)

## La caja del tramo en los ejes de la raiz. Modelo estira en los ejes del mundo y
## los giros son de 90 grados, asi que la caja sigue alineada con los ejes.
func _colocar_choque(choque: CollisionShape3D, xf: Transform3D) -> void:
	var caja := xf * AABB(TRAMO_CAJA.position * VillageMetrics.TEXEL,
		TRAMO_CAJA.size * VillageMetrics.TEXEL)
	(choque.shape as BoxShape3D).size = caja.size
	choque.transform = Transform3D(Basis.IDENTITY, caja.get_center())
