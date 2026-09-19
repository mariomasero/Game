class_name LabSnapshot
extends RefCounted

const SCHEMA_VERSION: int = 1
const MAX_SAFE_INTEGER: int = 9007199254740991
const ITEM_IDS: Array[String] = ["matrix", "catalyst", "lumen"]

static func capture(session: LabSession) -> Dictionary:
	var items: Dictionary = {}
	for item_id in ITEM_IDS:
		items[item_id] = session.count_item(StringName(item_id))
	return {
		"schema_version": SCHEMA_VERSION,
		"money": session.money,
		"inventory": items,
		"completed_orders": session.completed_orders,
		"order_active": session.order_active,
		"order_id": session.order_id,
		"upgrades": {"precision_calibration": session.upgrade_owned},
		"batch": {"state": String(session.batch_state), "remaining_seconds": session.remaining_seconds, "duration_seconds": session.batch_duration_seconds},
	}

static func validate(data: Dictionary) -> String:
	if not _integer(data.get("schema_version")) or int(data.schema_version) != SCHEMA_VERSION:
		return "Versión de partida no compatible."
	for field in ["money", "completed_orders", "order_id"]:
		if not _integer(data.get(field)):
			return "La partida contiene cantidades inválidas."
	if not data.get("order_active") is bool or int(data.order_id) < 1:
		return "El pedido guardado no es válido."
	if int(data.order_id) != int(data.completed_orders) + (1 if data.order_active else 0):
		return "El historial del pedido es incoherente."
	if not data.get("inventory") is Dictionary or data.inventory.size() != ITEM_IDS.size():
		return "El almacén guardado no es válido."
	for item_id in ITEM_IDS:
		if not _integer(data.inventory.get(item_id)):
			return "El almacén contiene cantidades inválidas."
	if not data.get("upgrades") is Dictionary or data.upgrades.size() != 1 or not data.upgrades.get("precision_calibration") is bool:
		return "La mejora guardada no es válida."
	if not data.get("batch") is Dictionary:
		return "Falta el estado del lote."
	var batch: Dictionary = data.batch
	if not batch.get("state") is String or batch.state not in ["empty", "producing", "ready"]:
		return "Estado del lote desconocido."
	if not _number(batch.get("remaining_seconds")) or not _number(batch.get("duration_seconds")):
		return "Los tiempos del lote no son válidos."
	var remaining: float = batch.remaining_seconds
	var duration: float = batch.duration_seconds
	if remaining < 0 or duration < 0 or remaining > duration:
		return "Los tiempos del lote son incoherentes."
	if batch.state == "empty" and (remaining != 0 or duration != 0):
		return "Una máquina vacía no puede tener tiempo pendiente."
	if batch.state != "empty" and duration <= 0:
		return "El lote necesita una duración positiva."
	if batch.state == "producing" and remaining <= 0:
		return "El lote en proceso debe tener tiempo pendiente."
	if batch.state == "ready" and remaining != 0:
		return "El lote listo no puede tener tiempo pendiente."
	return ""

static func apply(session: LabSession, data: Dictionary) -> String:
	var error := validate(data)
	if not error.is_empty():
		return error
	var items: Dictionary[StringName, int] = {}
	for item_id in ITEM_IDS:
		items[StringName(item_id)] = int(data.inventory[item_id])
	session.money = int(data.money)
	session.inventory = items
	session.completed_orders = int(data.completed_orders)
	session.order_active = data.order_active
	session.order_id = int(data.order_id)
	session.upgrade_owned = data.upgrades.precision_calibration
	session.batch_state = StringName(data.batch.state)
	session.remaining_seconds = float(data.batch.remaining_seconds)
	session.batch_duration_seconds = float(data.batch.duration_seconds)
	session.publish_restored_state()
	return ""

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _integer(value: Variant) -> bool:
	return _number(value) and value >= 0 and value <= MAX_SAFE_INTEGER and float(value) == floorf(float(value))
