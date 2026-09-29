@tool
class_name VillageProp
extends Node3D

## Raiz de un objeto del pueblo puesto a mano: un arbol, una casa, una farola.
## Como se usa: docs/guias/03-anadir-objetos-3d.md.
##
## Existe para que colocar un objeto sea solo arrastrarlo a la vista 3D:
##
## 1. Estira el hijo Modelo con VillageMetrics.block_scale. Un modelo hecho a 32
##    texeles por unidad -- lo que da PixZels con scale_mesh 0,03125 -- sale asi a
##    pixel exacto sin que nadie escriba 1,7434 en el Inspector.
## 2. Apoya el modelo en el suelo y lo centra sobre la raiz, midiendo su caja
##    (o solo su base, con centrar_por_la_base).
## 3. En el editor, al moverlo, lo encaja en la rejilla de celdas y deja el giro
##    en saltos de 90 grados. El iman del editor no sirve aqui: solo admite un
##    paso igual en los tres ejes y la celda mide (1; 1,74; 1,22).
##
## El giro vive en la raiz y la escala en Modelo, pero la escala se aplica en los
## ejes del MUNDO: Modelo lleva R^-1 * S * R. Con la escala en los ejes del
## modelo, girar 90 grados pondria el 1,22 del fondo en el ancho y el pixel
## dejaria de ser cuadrado.
##
## La escala anisotropa parte de VillageMetrics.DEFAULT_PITCH_DEGREES, igual que
## las bibliotecas de pintura: si el pueblo cambia pitch_degrees, los objetos no
## lo siguen.

## Donde cae la raiz dentro de la celda al encajar.
enum Anclaje {
	## Centro de celda si el objeto ocupa un numero impar de celdas en ese eje,
	## esquina si ocupa un numero par. Asi su huella cae siempre sobre celdas
	## enteras.
	AUTOMATICO,
	CENTRO_DE_CELDA,
	ESQUINA_DE_CELDA,
}

const MODELO := ^"Modelo"
const FORMA := ^"Colision/Forma"

## Encaja el objeto en la rejilla al moverlo en el editor.
@export var ajustar_a_rejilla := true:
	set(valor):
		ajustar_a_rejilla = valor
		_encajar()

@export var anclaje := Anclaje.AUTOMATICO:
	set(valor):
		anclaje = valor
		_encajar()

## Con esto encendido la caja de colision es la caja del modelo entero. Para un
## arbol, cuya copa no deberia frenar al personaje, se apaga y se ajusta a mano
## el tamano de Colision/Forma para que abarque solo el tronco.
@export var colision_automatica := true:
	set(valor):
		colision_automatica = valor
		_reajustar()

## Centra el objeto por lo que toca el suelo en vez de por su caja entera. Para
## lo que sobresale hacia un lado, como el brazo de una farola o la copa torcida
## de un arbol: con la caja entera el poste quedaria descentrado en su casilla.
@export var centrar_por_la_base := false:
	set(valor):
		centrar_por_la_base = valor
		_reajustar()

## Casillas que ocupa el objeto sin girar, si no deben salir de su caja. Para un
## arbol: la copa sobresale varias casillas, pero solo el tronco estorba. Con
## (0, 0) se mide del modelo.
@export var huella_fija := Vector2i.ZERO:
	set(valor):
		huella_fija = valor
		_reajustar()

## El personaje lo cruza: no lleva Colision/Forma y no se avisa de que falte.
## Para hierbas, flores y guijarros.
@export var atravesable := false:
	set(valor):
		atravesable = valor
		update_configuration_warnings()

## Por si se cambia el modelo y no se recoloca solo.
@export_tool_button("Recolocar modelo", "Reload") var recolocar: Callable = _reajustar

## Caja del modelo en unidades de mundo, ya colocado: la base en y=0 y centrado en
## X y Z sobre la raiz, antes del giro de la raiz. Con centrar_por_la_base lo
## centrado es la base, y la caja puede sobresalir mas hacia un lado.
var caja := AABB()

var _encajando := false

func _ready() -> void:
	_reajustar()
	if Engine.is_editor_hint():
		set_notify_local_transform(true)
		var modelo := get_node_or_null(MODELO)
		if modelo != null:
			# Un modelo nuevo arrastrado dentro de Modelo se recoloca solo.
			modelo.child_entered_tree.connect(_al_cambiar_modelo)
			modelo.child_exiting_tree.connect(_al_cambiar_modelo)

func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
		_encajar()

func _al_cambiar_modelo(_nodo: Node) -> void:
	_reajustar.call_deferred()

func _celda() -> Vector3:
	return VillageMetrics.block_scale(VillageMetrics.DEFAULT_PITCH_DEGREES)

## Giro de la raiz redondeado a 90 grados, solo sobre Y.
func _giro() -> Basis:
	var yaw := basis.get_euler().y
	return Basis(Vector3.UP, deg_to_rad(roundf(rad_to_deg(yaw) / 90.0) * 90.0))

func _reajustar() -> void:
	if not is_inside_tree():
		return
	var modelo := get_node_or_null(MODELO) as Node3D
	if modelo == null:
		update_configuration_warnings()
		return
	var giro := _giro()
	var estirar := giro.inverse() * Basis.from_scale(_celda()) * giro
	var dentro := _caja_de(modelo, Transform3D.IDENTITY)
	if dentro.size == Vector3.ZERO:
		modelo.transform = Transform3D(estirar, Vector3.ZERO)
		caja = AABB()
		update_configuration_warnings()
		return
	var estirada := Transform3D(estirar, Vector3.ZERO) * dentro
	var centro := estirada.get_center()
	if centrar_por_la_base:
		var base := _base_de(modelo, Transform3D(estirar, Vector3.ZERO),
			estirada.position.y)
		if base.size != Vector3.ZERO:
			centro = base.get_center()
	modelo.transform = Transform3D(estirar,
		Vector3(-centro.x, -estirada.position.y, -centro.z))
	caja = AABB(estirada.position - Vector3(centro.x, estirada.position.y, centro.z),
		estirada.size)
	if colision_automatica:
		_ajustar_colision()
	update_configuration_warnings()
	_encajar()

## Caja de todo lo que se dibuja bajo `nodo`, en su espacio y sin su propia
## transformacion. Cubre tanto un MeshInstance3D suelto como un .glb instanciado,
## que trae sus mallas unos niveles mas abajo.
func _caja_de(nodo: Node, xf: Transform3D) -> AABB:
	var total := AABB()
	var hay := false
	for hijo in nodo.get_children():
		var hijo_3d := hijo as Node3D
		if hijo_3d == null:
			continue
		var x := xf * hijo_3d.transform
		if hijo is GeometryInstance3D:
			var propia := x * (hijo as GeometryInstance3D).get_aabb()
			total = total.merge(propia) if hay else propia
			hay = true
		var debajo := _caja_de(hijo, x)
		if debajo.size != Vector3.ZERO:
			total = total.merge(debajo) if hay else debajo
			hay = true
	return total

## Caja de los vertices que estan a la altura `suelo` -- la cara de abajo del
## modelo --, en el espacio de `nodo` con `xf` aplicado. Mira triangulos y no
## cajas porque un .obj llega como una sola malla: su caja incluye el brazo.
func _base_de(nodo: Node, xf: Transform3D, suelo: float) -> AABB:
	var puntos: Array[Vector3] = []
	_puntos_del_suelo(nodo, xf, suelo, puntos)
	if puntos.is_empty():
		return AABB()
	var total := AABB(puntos[0], Vector3.ZERO)
	for p in puntos:
		total = total.expand(p)
	return total

func _puntos_del_suelo(nodo: Node, xf: Transform3D, suelo: float,
		puntos: Array[Vector3]) -> void:
	for hijo in nodo.get_children():
		var hijo_3d := hijo as Node3D
		if hijo_3d == null:
			continue
		var x := xf * hijo_3d.transform
		var malla := hijo as MeshInstance3D
		if malla != null and malla.mesh != null:
			for v in malla.mesh.get_faces():
				var p := x * v
				# Medio texel de tolerancia: lo que no esta en la cara de abajo
				# esta por lo menos un texel entero mas arriba.
				if absf(p.y - suelo) <= 0.5 * VillageMetrics.TEXEL:
					puntos.append(p)
		_puntos_del_suelo(hijo, x, suelo, puntos)

func _ajustar_colision() -> void:
	var forma := get_node_or_null(FORMA) as CollisionShape3D
	if forma == null or caja.size == Vector3.ZERO:
		return
	var box := forma.shape as BoxShape3D
	if box == null:
		box = BoxShape3D.new()
		forma.shape = box
	box.size = caja.size
	forma.transform = Transform3D(Basis.IDENTITY, caja.get_center())

## Giro sobre Y en pasos de 90 grados, de 0 a 3. Es el mismo giro al que encaja
## _encajar, y el que guarda PlotLayout.
func giro_en_pasos() -> int:
	return posmod(roundi(basis.get_euler().y / (PI * 0.5)), 4)

## Huella del objeto en celdas enteras, en los ejes del padre (ya girada). La
## usa village.gd para comprobar que la definicion de un mueble dice lo mismo que
## su modelo.
func huella() -> Vector2i:
	if huella_fija.x > 0 and huella_fija.y > 0:
		return huella_fija if giro_en_pasos() % 2 == 0 \
			else Vector2i(huella_fija.y, huella_fija.x)
	if caja.size == Vector3.ZERO:
		return Vector2i.ONE
	var girada := Transform3D(_giro(), Vector3.ZERO) * caja
	var celda := _celda()
	return Vector2i(maxi(1, roundi(girada.size.x / celda.x)),
		maxi(1, roundi(girada.size.z / celda.z)))

## Desfase dentro de la celda: 0,5 es el centro y 0 la esquina.
func _desfase(celdas: int) -> float:
	match anclaje:
		Anclaje.CENTRO_DE_CELDA:
			return 0.5
		Anclaje.ESQUINA_DE_CELDA:
			return 0.0
	return 0.5 if celdas % 2 == 1 else 0.0

## Posicion mas cercana a `p` que deja la huella del objeto sobre celdas enteras
## y su base en una planta. En los ejes del padre.
func posicion_encajada(p: Vector3) -> Vector3:
	var celda := _celda()
	var ocupa := huella()
	var dx := _desfase(ocupa.x)
	var dz := _desfase(ocupa.y)
	return Vector3(
		(roundf(p.x / celda.x - dx) + dx) * celda.x,
		roundf(p.y / celda.y) * celda.y,
		(roundf(p.z / celda.z - dz) + dz) * celda.z)

## Encaja posicion y giro. Solo en el editor: en el juego el objeto ya esta donde
## se guardo.
func _encajar() -> void:
	if not Engine.is_editor_hint() or not ajustar_a_rejilla or _encajando \
			or not is_inside_tree():
		return
	var p := posicion_encajada(position)
	var giro := _giro()
	var giro_cambia := not basis.is_equal_approx(giro)
	if not giro_cambia and p.is_equal_approx(position):
		return
	_encajando = true
	transform = Transform3D(giro, p)
	_encajando = false
	if giro_cambia:
		# Con otro giro la escala se reparte distinto entre ancho y fondo.
		_reajustar()

func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	var modelo := get_node_or_null(MODELO) as Node3D
	if modelo == null:
		avisos.append("Falta un hijo Node3D llamado Modelo con el modelo dentro.")
	elif caja.size == Vector3.ZERO:
		avisos.append("Modelo esta vacio: arrastra dentro el .obj, .glb o una malla.")
	if get_node_or_null(FORMA) == null and not atravesable:
		avisos.append("Falta Colision/Forma: sin ella el personaje atraviesa el objeto.")
	return avisos
