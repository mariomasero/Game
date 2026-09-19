extends SceneTree

const Session = preload("res://scripts/domain/lab_session.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
	else:
		print("PASS: " + message)

func _cycle(session: Node) -> void:
	if not session.order_active:
		session.request_order()
	_check(session.buy(&"matrix").is_empty() and session.buy(&"catalyst").is_empty(), "Repone insumos")
	_check(session.start_batch().is_empty(), "Inicia lote")
	session.advance(12.0)
	_check(session.collect_batch().is_empty(), "Recoge lote")
	_check(session.deliver_order(session.order_id).is_empty(), "Entrega pedido")

func _run() -> void:
	var session := Session.new()
	_check(session.has_method("buy_upgrade"), "La mejora de máquina está disponible en el dominio")
	if not session.has_method("buy_upgrade"):
		session.free()
		quit(1)
		return
	_check(not session.buy_upgrade().is_empty() and session.money == 120, "Tres pedidos son requisito antes de comprar")
	for cycle in range(3):
		_cycle(session)
	_check(session.money == 165, "Tres pedidos dejan 165 créditos")
	_check(session.buy_upgrade().is_empty() and session.money == 65, "La calibración cuesta 100 créditos")
	_check(not session.buy_upgrade().is_empty() and session.money == 65, "Comprar de nuevo no descuenta dinero")
	session.request_order()
	session.buy(&"matrix")
	session.buy(&"catalyst")
	session.start_batch()
	_check(session.remaining_seconds == 8.0, "Los nuevos lotes duran ocho segundos")
	session.advance(3.0)
	var codec: Script = load("res://scripts/persistence/lab_snapshot.gd")
	var saved: Dictionary = codec.capture(session)
	var serialized: Dictionary = JSON.parse_string(JSON.stringify(saved))
	var restored := Session.new()
	_check(codec.apply(restored, serialized).is_empty(), "Restaura JSON completo durante producción")
	_check(restored.money == 45 and restored.upgrade_owned and restored.remaining_seconds == 5.0, "Conserva saldo, mejora y tiempo exacto")
	_check(restored.completed_orders == 3 and restored.order_id == 4, "Conserva historial y orden activa")
	_check(restored.count_item(&"matrix") == 0 and restored.count_item(&"catalyst") == 0, "No devuelve ingredientes consumidos")
	root.add_child(restored)
	restored.set_process(false)
	_check(restored.money == 45, "Entrar al árbol no reinicia una sesión restaurada")
	restored.advance(5.0)
	_check(restored.batch_state == &"ready", "Completa solo el tiempo que quedaba")
	var ready_data: Dictionary = codec.capture(restored)
	_check(codec.apply(session, ready_data).is_empty() and session.collect_batch().is_empty(), "Se puede recoger un lote listo recargado")
	_check(session.deliver_order(4).is_empty() and session.money == 80, "Paga el pedido tras recargar")
	var paid: Dictionary = codec.capture(session)
	codec.apply(restored, paid)
	_check(not restored.deliver_order(4).is_empty() and restored.money == 80, "Recargar un pedido pagado no duplica el cobro")
	for mutation: Dictionary in [
		{"schema_version": 2}, {"money": -1}, {"money": 1.5}, {"money": "65"},
		{"order_active": "true"}, {"order_id": 99}, {"inventory": {"matrix": -1, "catalyst": 0, "lumen": 0}},
		{"upgrades": {"precision_calibration": 2}},
		{"batch": {"state": "producing", "remaining_seconds": 9, "duration_seconds": 8}},
		{"batch": {"state": "empty", "remaining_seconds": 2, "duration_seconds": 0}},
		{"batch": {"state": "ready", "remaining_seconds": 0, "duration_seconds": 0}},
	]:
		var invalid: Dictionary = paid.duplicate(true)
		invalid.merge(mutation, true)
		var before: Dictionary = codec.capture(restored)
		_check(not codec.apply(restored, invalid).is_empty(), "Rechaza estado inválido: " + str(mutation.keys()))
		_check(codec.capture(restored) == before, "El rechazo conserva toda la sesión")
	var poor := Session.new()
	poor.completed_orders = 3
	poor.money = 99
	_check(not poor.buy_upgrade().is_empty() and poor.money == 99, "Rechaza mejora sin saldo")
	poor.money = 120
	poor.buy(&"matrix")
	poor.buy(&"catalyst")
	poor.start_batch()
	_check(not poor.buy_upgrade().is_empty() and poor.remaining_seconds == 12, "No cambia un lote ocupado")
	session.free()
	poor.free()
	restored.queue_free()
	await process_frame
	print("RESULTADO PROGRESO: %d comprobaciones, %d fallos" % [checks, failures])
	quit(1 if failures else 0)
