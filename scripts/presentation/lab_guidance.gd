class_name LabGuidance
extends RefCounted

static func next_step(session: LabSession) -> String:
	if session.batch_state == &"producing":
		return "Lote en proceso · %d s restantes · Puedes reponer insumos en el ordenador" % ceili(session.remaining_seconds)
	if session.batch_state == &"ready":
		return "Lote listo · Acércate a la máquina y recoge la muestra"
	if session.order_active and session.count_item(&"lumen") >= session.definitions.order_quantity:
		return "Muestra en almacén · Entrega el pedido desde el ordenador"
	if not session.upgrade_owned and session.completed_orders >= session.definitions.upgrade_required_orders and session.money >= session.definitions.upgrade_cost:
		return "Mejora desbloqueada · Calibra la máquina por %d cr para producir más rápido" % session.definitions.upgrade_cost
	if not session.order_active:
		return "Pedido cobrado · Solicita otra orden en el ordenador"
	var needs_matrix: bool = session.count_item(&"matrix") == 0
	var needs_catalyst: bool = session.count_item(&"catalyst") == 0
	if not needs_matrix and not needs_catalyst:
		return "Insumos preparados · Acércate a la máquina para iniciar el lote"
	var needed_money: int = (session.definitions.matrix_price if needs_matrix else 0) + (session.definitions.catalyst_price if needs_catalyst else 0)
	if session.money < needed_money and (not needs_matrix or not needs_catalyst):
		return "Falta saldo · Devuelve insumos sin usar en el ordenador para repartir la compra"
	if needs_matrix and needs_catalyst:
		return "Siguiente paso · Compra matriz y catalizador en el ordenador"
	return "Falta %s · Compra una unidad en el ordenador" % ("matriz" if needs_matrix else "catalizador")
