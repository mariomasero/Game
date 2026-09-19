class_name LabSession
extends Node

signal changed
signal committed

const LabDefinitionsType = preload("res://scripts/domain/lab_definitions.gd")
const DEFAULT_DEFINITIONS: LabDefinitionsType = preload("res://resources/definitions/first_lab.tres")
const MAX_BUY_QUANTITY: int = 999
const MAX_INT: int = 9223372036854775807
const MATRIX_ID: StringName = &"matrix"
const CATALYST_ID: StringName = &"catalyst"
const PRODUCT_ID: StringName = &"lumen"

@export var definitions: LabDefinitionsType = DEFAULT_DEFINITIONS

var money: int
var inventory: Dictionary[StringName, int] = {}
var batch_state: StringName = &"empty"
var remaining_seconds: float = 0.0
var batch_duration_seconds: float = 0.0
var upgrade_owned: bool = false
var completed_orders: int = 0
var order_active: bool = true
var order_id: int = 1
var _state_changed_before_ready: bool = false


func _init() -> void:
	money = definitions.starting_money


func _ready() -> void:
	if definitions == null:
		definitions = DEFAULT_DEFINITIONS
	if not _state_changed_before_ready:
		money = maxi(definitions.starting_money, 0)


func _process(delta: float) -> void:
	advance(delta)


func count_item(item_id: StringName) -> int:
	return inventory.get(item_id, 0)


func buy(item_id: StringName, quantity: int = 1) -> String:
	if quantity <= 0:
		return "La cantidad debe ser positiva."
	if quantity > MAX_BUY_QUANTITY:
		return "La cantidad es demasiado alta."
	var unit_price := _price_for(item_id)
	if unit_price < 0:
		return "Artículo desconocido."
	if unit_price == 0:
		return "El precio del artículo no es válido."
	if quantity > money / unit_price:
		return "Saldo insuficiente."
	if count_item(item_id) > MAX_INT - quantity:
		return "No cabe esa cantidad en el inventario."
	money -= unit_price * quantity
	inventory[item_id] = count_item(item_id) + quantity
	_mark_changed()
	return ""


func start_batch() -> String:
	if batch_state != &"empty":
		return "La máquina ya está ocupada."
	if definitions == null:
		return "Faltan las definiciones del laboratorio."
	var duration := production_seconds()
	if not is_finite(duration) or duration <= 0.0:
		return "La duración del lote no es válida."
	if count_item(MATRIX_ID) < 1 or count_item(CATALYST_ID) < 1:
		return "Faltan ingredientes."
	inventory[MATRIX_ID] = count_item(MATRIX_ID) - 1
	inventory[CATALYST_ID] = count_item(CATALYST_ID) - 1
	batch_state = &"producing"
	batch_duration_seconds = duration
	remaining_seconds = duration
	_mark_changed()
	return ""


func collect_batch() -> String:
	if batch_state != &"ready":
		return "El lote todavía no está listo."
	if count_item(PRODUCT_ID) == MAX_INT:
		return "No cabe otra muestra en el inventario."
	inventory[PRODUCT_ID] = count_item(PRODUCT_ID) + 1
	batch_state = &"empty"
	remaining_seconds = 0.0
	batch_duration_seconds = 0.0
	_mark_changed()
	return ""


func deliver_order(expected_order_id: int) -> String:
	if not order_active:
		return "No hay un pedido activo."
	if expected_order_id != order_id:
		return "El pedido ya no está activo."
	if definitions == null:
		return "Faltan las definiciones del laboratorio."
	if definitions.order_quantity <= 0:
		return "La cantidad del pedido no es válida."
	if definitions.order_reward < 0:
		return "La recompensa del pedido no es válida."
	if count_item(PRODUCT_ID) < definitions.order_quantity:
		return "Faltan muestras para entregar."
	if definitions.order_reward > MAX_INT - money:
		return "La recompensa supera el saldo admitido."
	if completed_orders == MAX_INT:
		return "No se pueden registrar más pedidos completados."
	inventory[PRODUCT_ID] = count_item(PRODUCT_ID) - definitions.order_quantity
	money += definitions.order_reward
	completed_orders += 1
	order_active = false
	_mark_changed()
	return ""


func request_order() -> String:
	if order_active:
		return "Ya hay un pedido activo."
	if order_id == MAX_INT:
		return "No se pueden crear más pedidos."
	order_id += 1
	order_active = true
	_mark_changed()
	return ""


func refund_supplies() -> String:
	if definitions == null:
		return "Faltan las definiciones del laboratorio."
	if definitions.matrix_price <= 0 or definitions.catalyst_price <= 0:
		return "Los precios de los insumos no son válidos."
	var matrix_count := count_item(MATRIX_ID)
	var catalyst_count := count_item(CATALYST_ID)
	if matrix_count <= 0 and catalyst_count <= 0:
		return "No hay insumos sin usar para devolver."
	if matrix_count < 0 or catalyst_count < 0:
		return "El inventario de insumos no es válido."
	if matrix_count > MAX_INT / definitions.matrix_price:
		return "El reembolso supera el saldo admitido."
	if catalyst_count > MAX_INT / definitions.catalyst_price:
		return "El reembolso supera el saldo admitido."
	var matrix_refund := matrix_count * definitions.matrix_price
	var catalyst_refund := catalyst_count * definitions.catalyst_price
	if catalyst_refund > MAX_INT - matrix_refund:
		return "El reembolso supera el saldo admitido."
	var total_refund := matrix_refund + catalyst_refund
	if total_refund > MAX_INT - money:
		return "El reembolso supera el saldo admitido."
	money += total_refund
	inventory[MATRIX_ID] = 0
	inventory[CATALYST_ID] = 0
	_mark_changed()
	return ""


func advance(delta: float) -> void:
	if batch_state != &"producing" or not is_finite(delta) or delta <= 0.0:
		return
	var next_remaining := maxf(remaining_seconds - delta, 0.0)
	if is_equal_approx(next_remaining, remaining_seconds):
		return
	remaining_seconds = next_remaining
	if is_zero_approx(remaining_seconds):
		remaining_seconds = 0.0
		batch_state = &"ready"
	_mark_changed(batch_state == &"ready")


func production_seconds() -> float:
	if definitions == null:
		return 0.0
	return definitions.upgraded_batch_seconds if upgrade_owned else definitions.batch_seconds


func buy_upgrade() -> String:
	if definitions == null:
		return "Faltan las definiciones del laboratorio."
	if upgrade_owned:
		return "La calibración ya está instalada."
	if definitions.upgrade_cost <= 0 or definitions.upgrade_required_orders < 0 or not is_finite(definitions.upgraded_batch_seconds) or definitions.upgraded_batch_seconds <= 0:
		return "La configuración de la mejora no es válida."
	if completed_orders < definitions.upgrade_required_orders:
		return "Completa %d pedidos para desbloquear la calibración." % definitions.upgrade_required_orders
	if batch_state != &"empty":
		return "Recoge el lote antes de mejorar la máquina."
	if money < definitions.upgrade_cost:
		return "Saldo insuficiente para la calibración."
	money -= definitions.upgrade_cost
	upgrade_owned = true
	_mark_changed()
	return ""


func publish_restored_state() -> void:
	# Restoring must not trigger an autosave or _ready's initial balance.
	_state_changed_before_ready = true
	changed.emit()


func _price_for(item_id: StringName) -> int:
	if definitions == null:
		return -1
	match item_id:
		MATRIX_ID:
			return definitions.matrix_price
		CATALYST_ID:
			return definitions.catalyst_price
		_:
			return -1


func _mark_changed(transaction: bool = true) -> void:
	if not is_node_ready():
		_state_changed_before_ready = true
	changed.emit()
	if transaction:
		committed.emit()
