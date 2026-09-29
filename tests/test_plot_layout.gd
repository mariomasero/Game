extends SceneTree

## Reglas de la parcela del laboratorio (docs/decisions/014-parcela-y-camara.md),
## sin escena: donde cabe un mueble, moverlo, quitarlo y guardarlo.
##
##   godot --headless --path . --script tests/test_plot_layout.gd

const BLOQUE_CESPED := "res://resources/definitions/placeables/bloque_cesped.tres"

var checks := 0
var failures := 0

func _initialize() -> void:
	_run()
	print("RESULTADO PARCELA: %d comprobaciones, %d fallos" % [checks, failures])
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
	else:
		print("PASS: " + message)

func _def(id: StringName, huella: Vector2i) -> PlaceableDefinition:
	var d := PlaceableDefinition.new()
	d.id = id
	d.huella = huella
	return d

## Parcela de 6x4 casillas, de (0,0) a (5,3), con un bloque en (5,0).
func _parcela() -> PlotLayout:
	var p := PlotLayout.new()
	for z in 4:
		for x in 6:
			p.permitidas[Vector2i(x, z)] = true
	p.bloqueadas[Vector2i(5, 0)] = true
	return p

func _run() -> void:
	_huellas()
	_colocar()
	_mover_y_quitar()
	_guardar()
	_definicion_de_ejemplo()

func _huellas() -> void:
	_check(PlotLayout.huella_girada(Vector2i(2, 1), 1) == Vector2i(1, 2),
		"Una mesa de 2x1 girada 90 grados ocupa 1x2")
	_check(PlotLayout.huella_girada(Vector2i(2, 1), 2) == Vector2i(2, 1),
		"Girada 180 grados vuelve a ocupar 2x1")
	_check(PlotLayout.huella_girada(Vector2i(2, 1), -1) == Vector2i(1, 2),
		"Un giro negativo cuenta como su equivalente positivo")
	var c := PlotLayout.celdas(Vector2i(2, 1), Vector2i(3, 1), 1)
	_check(c == ([Vector2i(3, 1), Vector2i(3, 2)] as Array[Vector2i]),
		"Las casillas salen del origen hacia x y z crecientes (%s)" % str(c))

	var celda := VillageMetrics.block_scale(VillageMetrics.DEFAULT_PITCH_DEGREES)
	var impar := PlotLayout.centro_en_mundo(Vector2i.ONE, Vector2i(3, 2), 0, celda)
	_check(impar.is_equal_approx(Vector3(3.5 * celda.x, 0.0, 2.5 * celda.z)),
		"Un mueble de 1x1 cae en el centro de su casilla (%s)" % impar)
	var par := PlotLayout.centro_en_mundo(Vector2i(2, 1), Vector2i(3, 2), 0, celda)
	_check(par.is_equal_approx(Vector3(4.0 * celda.x, 0.0, 2.5 * celda.z)),
		"Uno de 2x1 cae en la esquina entre sus dos casillas (%s)" % par)
	var ida_y_vuelta := true
	for giro in 4:
		for origen: Vector2i in [Vector2i(0, 0), Vector2i(-3, 7), Vector2i(11, -4)]:
			var centro := PlotLayout.centro_en_mundo(Vector2i(3, 2), origen, giro, celda)
			if PlotLayout.origen_desde_mundo(Vector2i(3, 2), centro, giro, celda) != origen:
				ida_y_vuelta = false
	_check(ida_y_vuelta, "Del centro en el mundo se recupera el origen, en los cuatro giros")

func _colocar() -> void:
	var p := _parcela()
	var mesa := _def(&"mesa", Vector2i(2, 1))
	_check(p.motivo_para_no_colocar(mesa, Vector2i(0, 0), 0) == &"",
		"Una mesa cabe dentro de la parcela")
	_check(p.motivo_para_no_colocar(mesa, Vector2i(5, 1), 0) == PlotLayout.FUERA_DE_PARCELA,
		"Si una casilla se sale de la parcela, no cabe")
	_check(p.motivo_para_no_colocar(mesa, Vector2i(4, 0), 0) == PlotLayout.BLOQUEADA,
		"Encima de un bloque no cabe")
	var id := p.colocar(mesa, Vector2i(0, 0), 0)
	_check(id > 0 and p.ocupante(Vector2i(1, 0)) == id,
		"Colocada, ocupa sus dos casillas")
	_check(p.motivo_para_no_colocar(mesa, Vector2i(1, 0), 1) == PlotLayout.OCUPADA,
		"Otra mesa encima de la primera no cabe")
	_check(p.colocar(mesa, Vector2i(1, 0), 1) == -1 and p.ids().size() == 1,
		"Colocar donde no cabe no cambia nada")
	_check(p.colocar(null, Vector2i(3, 3), 0) == -1,
		"Sin definicion no se coloca nada")

func _mover_y_quitar() -> void:
	var p := _parcela()
	var mesa := _def(&"mesa", Vector2i(2, 1))
	var a := p.colocar(mesa, Vector2i(0, 0), 0)
	var b := p.colocar(mesa, Vector2i(0, 2), 0)

	_check(p.mover(a, Vector2i(1, 0), 0),
		"Un mueble se puede mover solapando su propio sitio")
	_check(p.ocupante(Vector2i(0, 0)) == -1 and p.ocupante(Vector2i(2, 0)) == a,
		"Al moverlo libera lo que deja y ocupa lo nuevo")

	var antes := p.colocacion(a)
	_check(not p.mover(a, Vector2i(0, 1), 1),
		"No se puede mover encima de otro mueble")
	_check(p.colocacion(a) == antes and p.ocupante(Vector2i(1, 0)) == a
		and p.ocupante(Vector2i(0, 2)) == b,
		"Un movimiento que falla deja todo como estaba")

	_check(p.mover(a, Vector2i(4, 1), 1),
		"Girado, una mesa de 2x1 cabe de pie junto al borde")
	_check(p.colocacion(a)["giro"] == 1,
		"El giro se guarda")
	_check(not p.mover(999, Vector2i.ZERO, 0) and not p.quitar(999),
		"Un id que no existe no se mueve ni se quita")

	_check(p.quitar(b) and p.ocupante(Vector2i(0, 2)) == -1
		and p.ids() == ([a] as Array[int]),
		"Quitar un mueble libera sus casillas")

func _guardar() -> void:
	var p := _parcela()
	var mesa := _def(&"mesa", Vector2i(2, 1))
	var silla := _def(&"silla", Vector2i.ONE)
	p.colocar(mesa, Vector2i(0, 0), 0)
	p.colocar(silla, Vector2i(3, 2), 3)
	var datos := p.to_dict()

	# Por JSON, para comprobar que no se guarda nada que JSON no entienda.
	var leido: Dictionary = JSON.parse_string(JSON.stringify(datos))
	var catalogo := {&"mesa": mesa, &"silla": silla}
	var q := _parcela()
	var problemas := q.from_dict(leido, catalogo)
	_check(problemas.is_empty(), "Se carga sin problemas (%s)" % str(problemas))
	_check(q.to_dict() == datos, "Guardar y cargar da lo mismo")
	_check(q.ocupante(Vector2i(1, 0)) != -1 and q.ocupante(Vector2i(3, 2)) != -1,
		"Tras cargar, las casillas vuelven a estar ocupadas")
	_check(leido["colocaciones"][0]["def"] == "mesa",
		"Se guarda el id de la definicion, no un indice")

	var r := _parcela()
	problemas = r.from_dict(leido, {&"mesa": mesa})
	_check(problemas.size() == 1 and problemas[0].contains("silla")
		and r.ids().size() == 1,
		"Un mueble desconocido se informa y el resto se carga (%s)" % str(problemas))

	var s := _parcela()
	s.bloqueadas[Vector2i(3, 2)] = true
	problemas = s.from_dict(leido, catalogo)
	_check(problemas.size() == 1 and problemas[0].contains(String(PlotLayout.BLOQUEADA)),
		"Un mueble que ya no cabe se informa (%s)" % str(problemas))

	var viejo := leido.duplicate(true)
	viejo["schema_version"] = 99
	var t := _parcela()
	t.colocar(silla, Vector2i(0, 3), 0)
	problemas = t.from_dict(viejo, catalogo)
	_check(problemas.size() == 1 and t.ids().size() == 1,
		"Una version de datos desconocida no carga nada ni borra lo que habia")

func _definicion_de_ejemplo() -> void:
	var d := load(BLOQUE_CESPED) as PlaceableDefinition
	_check(d != null and d.id == &"bloque_cesped" and d.huella == Vector2i.ONE
		and d.escena != null,
		"La definicion de ejemplo trae id, huella y escena")
