class_name PlotLayout
extends RefCounted

## Que ocupa cada casilla de la parcela del laboratorio
## (docs/decisions/014-parcela-y-camara.md).
##
## Son solo reglas, sin escena: donde se puede poner un mueble, moverlo y
## quitarlo. village.gd lo rellena con la parcela pintada y los muebles puestos a
## mano en el editor; el modo construir que vendra despues solo tendra que
## llamar a colocar, mover y quitar y dibujar el resultado.
##
## Todo va a ras de suelo: una casilla es un Vector2i (x, z) de la rejilla del
## pueblo, la misma de _cell_center y de los GridMap.

const SCHEMA_VERSION := 1

## Nombre del item de paint_zones.meshlib.tres que marca la parcela.
const ITEM_PARCELA := &"parcela"

## Motivos por los que no se puede colocar. &"" quiere decir que si se puede.
const FUERA_DE_PARCELA := &"fuera_de_parcela"
const BLOQUEADA := &"bloqueada"
const OCUPADA := &"ocupada"

## Casillas de la parcela: Vector2i -> true.
var permitidas := {}

## Casillas de la parcela con algo que no es un mueble encima -- un bloque
## pintado, un arbol --: Vector2i -> true.
var bloqueadas := {}

## Muebles puestos: id -> {def: PlaceableDefinition, origen: Vector2i, giro: int}.
var _colocaciones := {}

## Casilla -> id del mueble que la ocupa.
var _ocupacion := {}

var _siguiente := 1

## Huella de un mueble girado `giro` pasos de 90 grados: un giro impar cambia
## ancho por fondo.
static func huella_girada(huella: Vector2i, giro: int) -> Vector2i:
	return Vector2i(huella.y, huella.x) if posmod(giro, 2) == 1 else huella

## Casillas que ocupa un mueble. El origen es la esquina de x y z minimas de la
## huella ya girada, asi que no depende de hacia donde mire el mueble.
static func celdas(huella: Vector2i, origen: Vector2i, giro: int) -> Array[Vector2i]:
	var ocupa := huella_girada(huella, giro)
	var lista: Array[Vector2i] = []
	for dz in ocupa.y:
		for dx in ocupa.x:
			lista.append(origen + Vector2i(dx, dz))
	return lista

## Centro del mueble en el mundo, a ras de suelo. Con un numero impar de casillas
## cae en el centro de una casilla y con uno par en una esquina, que es tambien
## lo que hace el anclaje automatico de VillageProp.
static func centro_en_mundo(huella: Vector2i, origen: Vector2i, giro: int,
		celda: Vector3) -> Vector3:
	var ocupa := huella_girada(huella, giro)
	return Vector3((origen.x + ocupa.x * 0.5) * celda.x, 0.0,
		(origen.y + ocupa.y * 0.5) * celda.z)

## Lo contrario de centro_en_mundo: el origen de un mueble cuyo centro esta en
## `p`, redondeado a la casilla mas cercana.
static func origen_desde_mundo(huella: Vector2i, p: Vector3, giro: int,
		celda: Vector3) -> Vector2i:
	var ocupa := huella_girada(huella, giro)
	return Vector2i(roundi(p.x / celda.x - ocupa.x * 0.5),
		roundi(p.z / celda.z - ocupa.y * 0.5))

## Por que no se puede poner `def` ahi, o &"" si se puede. `ignorar` es el id de
## un mueble que no cuenta como estorbo, para mover un mueble sobre si mismo.
func motivo_para_no_colocar(def: PlaceableDefinition, origen: Vector2i, giro: int,
		ignorar := -1) -> StringName:
	for c in celdas(def.huella, origen, giro):
		if not permitidas.has(c):
			return FUERA_DE_PARCELA
		if bloqueadas.has(c):
			return BLOQUEADA
		var quien: int = _ocupacion.get(c, -1)
		if quien != -1 and quien != ignorar:
			return OCUPADA
	return &""

## Pone un mueble. Devuelve su id, o -1 si no cabe (y entonces no cambia nada).
func colocar(def: PlaceableDefinition, origen: Vector2i, giro: int) -> int:
	if def == null or motivo_para_no_colocar(def, origen, giro) != &"":
		return -1
	var id := _siguiente
	_siguiente += 1
	_colocaciones[id] = {"def": def, "origen": origen, "giro": posmod(giro, 4)}
	_ocupar(id)
	return id

## Mueve o gira un mueble. Si en el sitio nuevo no cabe, se queda donde estaba.
func mover(id: int, origen: Vector2i, giro: int) -> bool:
	if not _colocaciones.has(id):
		return false
	var c: Dictionary = _colocaciones[id]
	if motivo_para_no_colocar(c["def"], origen, giro, id) != &"":
		return false
	_desocupar(id)
	c["origen"] = origen
	c["giro"] = posmod(giro, 4)
	_ocupar(id)
	return true

func quitar(id: int) -> bool:
	if not _colocaciones.has(id):
		return false
	_desocupar(id)
	_colocaciones.erase(id)
	return true

## Ids de los muebles puestos, en el orden en que se pusieron.
func ids() -> Array[int]:
	var lista: Array[int] = []
	lista.assign(_colocaciones.keys())
	lista.sort()
	return lista

## Copia de un mueble puesto: {def, origen, giro}. Vacio si no existe.
func colocacion(id: int) -> Dictionary:
	return (_colocaciones.get(id, {}) as Dictionary).duplicate()

## Id del mueble que ocupa una casilla, o -1.
func ocupante(celda: Vector2i) -> int:
	return _ocupacion.get(celda, -1)

## Datos para guardar en la partida, en tipos que JSON entiende. Se guarda el id
## de la definicion, nunca su posicion en el catalogo.
func to_dict() -> Dictionary:
	var lista := []
	for id in ids():
		var c: Dictionary = _colocaciones[id]
		var origen: Vector2i = c["origen"]
		lista.append({
			"def": String((c["def"] as PlaceableDefinition).id),
			"origen": [origen.x, origen.y],
			"giro": c["giro"],
		})
	return {"schema_version": SCHEMA_VERSION, "colocaciones": lista}

## Carga los muebles de to_dict sobre esta parcela. `catalogo` es
## StringName -> PlaceableDefinition. Devuelve los problemas encontrados; un
## mueble que no se puede cargar se informa, nunca se descarta en silencio.
##
## Los muebles que ya hubiera se quitan antes: cargar es sustituir.
func from_dict(datos: Dictionary, catalogo: Dictionary) -> PackedStringArray:
	var problemas := PackedStringArray()
	var version := int(datos.get("schema_version", -1))
	if version != SCHEMA_VERSION:
		problemas.append("Version de datos %d; se esperaba %d. No se carga nada." % [
			version, SCHEMA_VERSION])
		return problemas
	for id in ids():
		quitar(id)
	for entrada in datos.get("colocaciones", []):
		if not entrada is Dictionary:
			problemas.append("Entrada de mueble ilegible: %s." % str(entrada))
			continue
		var nombre := StringName(str(entrada.get("def", "")))
		var def: PlaceableDefinition = catalogo.get(nombre)
		if def == null:
			problemas.append("Mueble desconocido '%s': no esta en el catalogo." % nombre)
			continue
		var o: Array = entrada.get("origen", [0, 0])
		var origen := Vector2i(int(o[0]), int(o[1]))
		var giro := int(entrada.get("giro", 0))
		if colocar(def, origen, giro) == -1:
			problemas.append("'%s' en %s no cabe: %s." % [nombre, origen,
				motivo_para_no_colocar(def, origen, giro)])
	return problemas

func _ocupar(id: int) -> void:
	var c: Dictionary = _colocaciones[id]
	for celda in celdas((c["def"] as PlaceableDefinition).huella, c["origen"], c["giro"]):
		_ocupacion[celda] = id

func _desocupar(id: int) -> void:
	var c: Dictionary = _colocaciones[id]
	for celda in celdas((c["def"] as PlaceableDefinition).huella, c["origen"], c["giro"]):
		_ocupacion.erase(celda)
