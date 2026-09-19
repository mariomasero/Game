extends SceneTree

const SESSION_SCRIPT := preload("res://scripts/domain/lab_session.gd")
const DEFINITIONS_SCRIPT := preload("res://scripts/domain/lab_definitions.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)


func _snapshot(session: Node) -> Array:
	return [
		session.money,
		session.inventory.duplicate(true),
		session.batch_state,
		session.remaining_seconds,
		session.completed_orders,
		session.order_active,
		session.order_id,
	]


func _check_rejected_without_change(session: Node, result: String, before: Array, message: String) -> void:
	_check(not result.is_empty(), message + " devuelve una razón")
	_check(_snapshot(session) == before, message + " no modifica el estado")


func _buy_recipe(session: Node) -> void:
	_check(session.buy(&"matrix") == "", "Compra una matriz")
	_check(session.buy(&"catalyst") == "", "Compra un catalizador")


func _complete_order(session: Node, expected_balance: int) -> int:
	_buy_recipe(session)
	_check(session.start_batch() == "", "Inicia el lote con ambos ingredientes")
	_check(session.batch_state == &"producing", "El lote queda produciendo")
	var occupied := _snapshot(session)
	_check_rejected_without_change(session, session.start_batch(), occupied, "Rechazar un segundo lote")
	session.advance(6.0)
	var early := _snapshot(session)
	_check_rejected_without_change(session, session.collect_batch(), early, "Rechazar recogida anticipada")
	session.advance(6.0)
	_check(session.batch_state == &"ready" and is_zero_approx(session.remaining_seconds), "El lote termina exactamente")
	_check(session.collect_batch() == "", "Recoge el lote terminado")
	_check(session.count_item(&"lumen") == 1 and session.batch_state == &"empty", "Recoger guarda una muestra y libera la máquina")
	var repeated_collect := _snapshot(session)
	_check_rejected_without_change(session, session.collect_batch(), repeated_collect, "Rechazar recogida repetida")
	var delivered_id: int = session.order_id
	_check(session.deliver_order(delivered_id) == "", "Entrega el pedido activo")
	_check(session.money == expected_balance, "La entrega deja %d créditos" % expected_balance)
	_check(session.count_item(&"lumen") == 0 and not session.order_active, "La entrega consume la muestra y cierra el pedido")
	var delivered := _snapshot(session)
	_check_rejected_without_change(session, session.deliver_order(delivered_id), delivered, "Rechazar entrega repetida")
	return delivered_id


func _run() -> void:
	var custom_definitions: Resource = DEFINITIONS_SCRIPT.new()
	custom_definitions.starting_money = 77
	var packed_source: Node = SESSION_SCRIPT.new()
	packed_source.definitions = custom_definitions
	var packed := PackedScene.new()
	_check(packed.pack(packed_source) == OK, "Empaqueta una sesión con balance personalizado")
	packed_source.free()
	var packed_session: Node = packed.instantiate()
	root.add_child(packed_session)
	_check(packed_session.money == 77, "La escena inicia con el saldo de sus definiciones exportadas")
	packed_session.queue_free()
	var missing_definitions: Node = SESSION_SCRIPT.new()
	missing_definitions.definitions = null
	root.add_child(missing_definitions)
	_check(missing_definitions.definitions != null and missing_definitions.money == 120,
		"Las definiciones nulas recuperan el balance predeterminado")
	missing_definitions.queue_free()
	var negative_balance: Node = SESSION_SCRIPT.new()
	negative_balance.definitions = DEFINITIONS_SCRIPT.new()
	negative_balance.definitions.starting_money = -10
	root.add_child(negative_balance)
	_check(negative_balance.money == 0, "El saldo inicial negativo se normaliza a cero")
	negative_balance.queue_free()

	var session: Node = SESSION_SCRIPT.new()
	root.add_child(session)
	_check(session.definitions != null, "Carga las definiciones predeterminadas")
	_check(session.money == 120, "Empieza con 120 créditos")
	_check(session.order_active and session.order_id == 1, "Empieza con el primer pedido activo")
	_check(session.batch_state == &"empty", "Empieza con la máquina vacía")

	for invalid_quantity in [0, -1, 1000, 2147483647]:
		var before := _snapshot(session)
		_check_rejected_without_change(session, session.buy(&"matrix", invalid_quantity), before,
			"Rechazar cantidad %d" % invalid_quantity)
	var unknown := _snapshot(session)
	_check_rejected_without_change(session, session.buy(&"unknown"), unknown, "Rechazar artículo desconocido")
	var unaffordable := _snapshot(session)
	_check_rejected_without_change(session, session.buy(&"matrix", 11), unaffordable, "Rechazar compra inasequible")
	var no_ingredients := _snapshot(session)
	_check_rejected_without_change(session, session.start_batch(), no_ingredients, "Rechazar lote sin ingredientes")
	var no_product := _snapshot(session)
	_check_rejected_without_change(session, session.deliver_order(1), no_product, "Rechazar entrega sin producto")
	var active_order := _snapshot(session)
	_check_rejected_without_change(session, session.request_order(), active_order, "Rechazar pedido nuevo mientras hay uno activo")

	var stale_id := _complete_order(session, 135)
	_check(session.completed_orders == 1, "Cuenta la primera entrega una vez")
	_check(session.request_order() == "" and session.order_id == 2, "Solicita explícitamente el pedido 2")
	var stale := _snapshot(session)
	_check_rejected_without_change(session, session.deliver_order(stale_id), stale, "Rechazar ID antiguo")
	_complete_order(session, 150)
	_check(session.request_order() == "" and session.order_id == 3, "Solicita explícitamente el pedido 3")
	_complete_order(session, 165)
	_check(session.completed_orders == 3, "Cuenta tres pedidos completados")

	var second: Node = SESSION_SCRIPT.new()
	root.add_child(second)
	_check(second.money == 120 and second.count_item(&"matrix") == 0, "Las sesiones tienen estado independiente")
	_buy_recipe(second)
	_check(second.start_batch() == "", "La segunda sesión puede producir")
	second.advance(NAN)
	second.advance(INF)
	second.advance(-1.0)
	_check(second.batch_state == &"producing" and is_equal_approx(second.remaining_seconds, 12.0),
		"El avance ignora tiempos no finitos o no positivos")

	var max_int: int = 9223372036854775807
	var overflow: Node = SESSION_SCRIPT.new()
	root.add_child(overflow)
	overflow.inventory[&"matrix"] = max_int
	var full_inventory := _snapshot(overflow)
	_check_rejected_without_change(overflow, overflow.buy(&"matrix"), full_inventory,
		"Rechazar desbordamiento de inventario al comprar")
	overflow.batch_state = &"ready"
	overflow.inventory[&"lumen"] = max_int
	var full_product := _snapshot(overflow)
	_check_rejected_without_change(overflow, overflow.collect_batch(), full_product,
		"Rechazar desbordamiento de inventario al recoger")
	overflow.batch_state = &"empty"
	overflow.inventory[&"lumen"] = 1
	overflow.money = max_int
	var full_money := _snapshot(overflow)
	_check_rejected_without_change(overflow, overflow.deliver_order(1), full_money,
		"Rechazar desbordamiento de saldo al entregar")
	overflow.money = 120
	overflow.inventory[&"lumen"] = 1
	overflow.completed_orders = max_int
	var full_counter := _snapshot(overflow)
	_check_rejected_without_change(overflow, overflow.deliver_order(1), full_counter,
		"Rechazar desbordamiento del contador de pedidos")
	overflow.completed_orders = 0
	overflow.order_active = false
	overflow.order_id = max_int
	var full_order_id := _snapshot(overflow)
	_check_rejected_without_change(overflow, overflow.request_order(), full_order_id,
		"Rechazar desbordamiento del ID de pedido")

	var invalid: Node = SESSION_SCRIPT.new()
	root.add_child(invalid)
	invalid.definitions = DEFINITIONS_SCRIPT.new()
	invalid.definitions.matrix_price = 0
	var zero_price := _snapshot(invalid)
	_check_rejected_without_change(invalid, invalid.buy(&"matrix"), zero_price, "Rechazar precio cero")
	invalid.definitions.matrix_price = -1
	var negative_price := _snapshot(invalid)
	_check_rejected_without_change(invalid, invalid.buy(&"matrix"), negative_price, "Rechazar precio negativo")
	invalid.definitions.matrix_price = 12
	invalid.inventory[&"matrix"] = 1
	invalid.inventory[&"catalyst"] = 1
	invalid.definitions.batch_seconds = 0.0
	var zero_duration := _snapshot(invalid)
	_check_rejected_without_change(invalid, invalid.start_batch(), zero_duration, "Rechazar duración cero")
	invalid.definitions.batch_seconds = -1.0
	var negative_duration := _snapshot(invalid)
	_check_rejected_without_change(invalid, invalid.start_batch(), negative_duration, "Rechazar duración negativa")
	invalid.definitions.batch_seconds = 12.0
	invalid.inventory[&"lumen"] = 1
	invalid.definitions.order_quantity = 0
	var zero_order := _snapshot(invalid)
	_check_rejected_without_change(invalid, invalid.deliver_order(1), zero_order, "Rechazar cantidad de pedido cero")
	invalid.definitions.order_quantity = -1
	var negative_order := _snapshot(invalid)
	_check_rejected_without_change(invalid, invalid.deliver_order(1), negative_order, "Rechazar cantidad de pedido negativa")
	invalid.definitions.order_quantity = 1
	invalid.definitions.order_reward = -1
	var negative_reward := _snapshot(invalid)
	_check_rejected_without_change(invalid, invalid.deliver_order(1), negative_reward, "Rechazar recompensa negativa")

	var recovery: Node = SESSION_SCRIPT.new()
	root.add_child(recovery)
	_check(recovery.buy(&"matrix", 10) == "" and recovery.money == 0, "Permite gastar el saldo en diez matrices")
	_check(recovery.refund_supplies() == "", "Devuelve los insumos sin consumir")
	_check(recovery.money == 120 and recovery.count_item(&"matrix") == 0, "El reembolso recupera los 120 créditos")
	var no_refund := _snapshot(recovery)
	_check_rejected_without_change(recovery, recovery.refund_supplies(), no_refund, "Rechazar reembolso duplicado")
	_buy_recipe(recovery)
	_check(recovery.start_batch() == "", "Inicia un ciclo normal tras el reembolso")
	recovery.advance(12.0)
	_check(recovery.collect_batch() == "" and recovery.deliver_order(1) == "", "Completa el ciclo tras recuperar el saldo")
	_check(recovery.money == 135, "El ciclo posterior al reembolso termina con 135 créditos")
	var active_refund: Node = SESSION_SCRIPT.new()
	root.add_child(active_refund)
	_buy_recipe(active_refund)
	_check(active_refund.start_batch() == "", "Inicia lote antes de comprobar el reembolso bloqueado")
	_check(active_refund.buy(&"matrix") == "", "Compra un insumo sin consumir durante la producción")
	var active_remaining: float = active_refund.remaining_seconds
	var money_before_active_refund: int = active_refund.money
	_check(active_refund.refund_supplies() == "", "Devuelve existencias sin usar durante la producción")
	_check(active_refund.money == money_before_active_refund + 12, "Reembolsa 12 y no los 20 ya consumidos")
	_check(active_refund.batch_state == &"producing" and is_equal_approx(active_refund.remaining_seconds, active_remaining),
		"El reembolso conserva el lote activo y su tiempo restante")
	_check(active_refund.count_item(&"matrix") == 0 and active_refund.count_item(&"catalyst") == 0,
		"El reembolso limpia solo las existencias sin usar")

	print("RESULTADO DOMINIO: %d comprobaciones, %d fallos" % [checks, failures])
	session.queue_free()
	second.queue_free()
	overflow.queue_free()
	invalid.queue_free()
	recovery.queue_free()
	active_refund.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
