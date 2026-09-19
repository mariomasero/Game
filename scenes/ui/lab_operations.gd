extends CanvasLayer

const Guidance = preload("res://scripts/presentation/lab_guidance.gd")

signal closed
signal new_game_started

var session: LabSession
var station_kind: StringName = &"terminal"
var displayed_order_id: int = 0
var persistence: LabPersistence
var confirming_new_game: bool = false

@onready var overlay: Control = $Overlay
@onready var pause_overlay: Control = $PauseOverlay
@onready var content: VBoxContainer = $Overlay/Panel/Margin/Content
@onready var title: Label = content.get_node("Title")
@onready var body: Label = content.get_node("Body")
@onready var inventory: Label = content.get_node("Inventory")
@onready var progress: ProgressBar = content.get_node("Progress")
@onready var feedback: Label = content.get_node("Feedback")
@onready var actions: GridContainer = content.get_node("Actions")
@onready var close_button: Button = content.get_node("Close")
@onready var notifications: Control = $Notifications

func _ready() -> void:
	close_button.pressed.connect(close_station)
	$PauseOverlay/Panel/Content/Resume.pressed.connect(_resume)
	actions.get_node("BuyMatrix").pressed.connect(_buy.bind(&"matrix"))
	actions.get_node("BuyCatalyst").pressed.connect(_buy.bind(&"catalyst"))
	actions.get_node("Start").pressed.connect(_start)
	actions.get_node("Collect").pressed.connect(_collect)
	actions.get_node("Deliver").pressed.connect(_deliver)
	actions.get_node("Request").pressed.connect(_request)
	actions.get_node("Refund").pressed.connect(_refund)
	actions.get_node("Upgrade").pressed.connect(_upgrade)
	$PauseOverlay/Panel/Content/NewGame.pressed.connect(_confirm_new_game)
	$PauseOverlay/Panel/Content/ConfirmNew/Cancel.pressed.connect(_cancel_new_game)
	$PauseOverlay/Panel/Content/ConfirmNew/Confirm.pressed.connect(_new_game)
	$PauseOverlay/Panel/Content/Sound.pressed.connect(notifications.toggle_sound)
	notifications.sound_changed.connect(_refresh_sound)
	notifications.announced.connect(_on_notice)

func bind_persistence(value: LabPersistence) -> void:
	persistence = value
	notifications.configure_settings(value.save_path.get_base_dir().path_join("audio.cfg") if value.enabled else "")
	persistence.status_changed.connect(_refresh_pause)
	persistence.attention_required.connect(show_pause.bind(false))
	$PauseOverlay/Panel/Content/SaveExit.pressed.connect(persistence.save_and_quit)
	$PauseOverlay/Panel/Content/Recover.pressed.connect(persistence.recover)
	$PauseOverlay/Panel/Content/Retry.pressed.connect(persistence.save_now)
	$PauseOverlay/Panel/Content/QuitUnsaved.pressed.connect(persistence.quit_without_saving)

func bind_session(value: LabSession) -> void:
	session = value
	notifications.bind_session(value)
	session.changed.connect(_refresh)
	_refresh()

func open_station(kind: StringName) -> void:
	station_kind = kind
	feedback.text = "Uso interno. Dirección agradece su productividad." if kind == &"terminal" else "Calibración: %d → %d s · %d cr · Requiere %d pedidos." % [session.definitions.batch_seconds, session.definitions.upgraded_batch_seconds, session.definitions.upgrade_cost, session.definitions.upgrade_required_orders]
	overlay.show()
	_refresh()
	close_button.grab_focus()

func close_station() -> void:
	overlay.hide()
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_action_pressed("ui_cancel"):
		return
	if overlay.visible:
		close_station()
	elif get_tree().paused:
		_resume()
	else:
		show_pause()
	get_viewport().set_input_as_handled()

func show_pause(save_current: bool = true) -> void:
	if overlay.visible:
		close_station()
	get_tree().paused = true
	pause_overlay.show()
	if persistence != null and save_current and not persistence.blocked:
		persistence.save_now()
	$Prompt.text = "PAUSA · La producción está detenida"
	_refresh_pause()
	if persistence == null or not persistence.blocked:
		$PauseOverlay/Panel/Content/Resume.grab_focus()
	elif persistence.can_recover:
		$PauseOverlay/Panel/Content/Recover.grab_focus()
	else:
		$PauseOverlay/Panel/Content/NewGame.grab_focus()

func _resume() -> void:
	if confirming_new_game:
		_cancel_new_game()
		return
	if persistence != null and persistence.blocked:
		return
	pause_overlay.hide()
	get_tree().paused = false

func _refresh_pause() -> void:
	if persistence == null:
		return
	var pane: VBoxContainer = $PauseOverlay/Panel/Content
	pane.add_theme_constant_override("separation", 3 if persistence.write_failed else 6)
	pane.get_node("Body").text = "¿Empezar de nuevo? El progreso actual dejará de estar activo.\nSe conservará una copia del archivo anterior." if confirming_new_game else "La producción está detenida.\n" + persistence.status_message
	pane.get_node("ConfirmNew").visible = confirming_new_game
	pane.get_node("Sound").visible = not confirming_new_game
	pane.get_node("Resume").visible = not persistence.blocked and not confirming_new_game
	pane.get_node("NewGame").visible = not confirming_new_game
	pane.get_node("SaveExit").visible = not confirming_new_game
	pane.get_node("SaveExit").text = "Salir conservando archivos" if persistence.blocked else "Guardar y salir"
	pane.get_node("Recover").visible = persistence.blocked and persistence.can_recover and not confirming_new_game
	pane.get_node("Retry").visible = persistence.write_failed and not persistence.blocked and not confirming_new_game
	pane.get_node("QuitUnsaved").visible = persistence.write_failed and not persistence.blocked and not confirming_new_game

func _confirm_new_game() -> void:
	confirming_new_game = true
	_refresh_pause()
	$PauseOverlay/Panel/Content/ConfirmNew/Cancel.grab_focus()

func _cancel_new_game() -> void:
	confirming_new_game = false
	_refresh_pause()
	$PauseOverlay/Panel/Content/NewGame.grab_focus()

func _new_game() -> void:
	var error: String = persistence.start_new_game()
	confirming_new_game = false
	_refresh_pause()
	if error.is_empty():
		notifications.clear_notice()
		new_game_started.emit()
		$PauseOverlay/Panel/Content/Resume.grab_focus()

func _process(_delta: float) -> void:
	notifications.world_visible = not overlay.visible and not pause_overlay.visible
	if session != null:
		_refresh_clock()

func _refresh() -> void:
	var data: Resource = session.definitions
	$RoomTag.text = "%d cr · %d %s" % [session.money, session.completed_orders, "pedido" if session.completed_orders == 1 else "pedidos"]
	displayed_order_id = session.order_id
	var at_terminal := station_kind == &"terminal"
	title.text = "RED CORPORATIVA / PEDIDOS" if at_terminal else "ESTACIÓN / PREPARAR LOTE"
	if at_terminal:
		body.text = "ORDEN C-%03d · Control de calidad\nEntregar %d muestra Lumen · Pago: %d cr" % [session.order_id, data.order_quantity, data.order_reward] if session.order_active else "Entrega registrada. Dirección espera nuevos resultados.\nSolicita otra orden cuando quieras continuar."
	else:
		body.text = "Lumen · Compuesto experimental ficticio\nReceta: 1 matriz + 1 catalizador → 1 muestra · %d s" % int(session.production_seconds())
	inventory.text = "ALMACÉN   Matriz: %d    Catalizador: %d    Lumen: %d" % [session.count_item(&"matrix"), session.count_item(&"catalyst"), session.count_item(&"lumen")]
	for button: Button in actions.get_children():
		button.visible = at_terminal if button.name in [&"BuyMatrix", &"BuyCatalyst", &"Deliver", &"Request", &"Refund"] else not at_terminal
	actions.columns = 2 if at_terminal else 3
	actions.get_node("Upgrade").text = "Calibrada · %d s" % int(session.production_seconds()) if session.upgrade_owned else "Calibrar · %d cr" % data.upgrade_cost
	actions.get_node("BuyMatrix").text = "Comprar matriz · %d cr" % data.matrix_price
	actions.get_node("BuyCatalyst").text = "Comprar catalizador · %d cr" % data.catalyst_price
	# Rejected actions explain why they cannot proceed.
	actions.get_node("Request").visible = at_terminal and not session.order_active
	actions.get_node("Deliver").visible = at_terminal and session.order_active
	_refresh_clock()

func _refresh_clock() -> void:
	var batch: StringName = session.batch_state
	progress.visible = batch != &"empty"
	var duration: float = session.batch_duration_seconds
	progress.value = 100.0 if batch == &"ready" else 100.0 * (1.0 - session.remaining_seconds / duration) if is_finite(duration) and duration > 0 else 0.0
	content.get_node("BatchStatus").text = "Máquina disponible"
	if batch == &"producing":
		content.get_node("BatchStatus").text = "Produciendo Lumen · %d s restantes" % ceili(session.remaining_seconds)
	elif batch == &"ready":
		content.get_node("BatchStatus").text = "LOTE LISTO · Recoge la muestra en la máquina"
	$Subtitle.text = Guidance.next_step(session)

func _report(error: String, success: String, cue: StringName = &"success") -> void:
	feedback.text = error if not error.is_empty() else success
	notifications.notify(feedback.text, &"error" if not error.is_empty() else cue)
	_refresh()

func _buy(item_id: StringName) -> void:
	_report(session.buy(item_id), "Compra recibida · +1 %s en el almacén" % ("matriz" if item_id == &"matrix" else "catalizador"))

func _start() -> void:
	_report(session.start_batch(), "Lote iniciado. Puedes salir y reponer suministros mientras esperas.", &"start")

func _collect() -> void:
	_report(session.collect_batch(), "Muestra recogida. Entrégala desde el ordenador.")

func _deliver() -> void:
	_report(session.deliver_order(displayed_order_id), "Entrega aceptada. +%d cr. Dirección cuenta contigo." % session.definitions.order_reward, &"cash")

func _request() -> void:
	_report(session.request_order(), "Nueva orden recibida. Prepara otra muestra Lumen.")

func _refund() -> void:
	_report(session.refund_supplies(), "Insumos sin usar devueltos. Se ha reintegrado su coste.")

func _upgrade() -> void:
	_report(session.buy_upgrade(), "Calibración instalada. Los próximos lotes durarán %d segundos." % int(session.definitions.upgraded_batch_seconds), &"upgrade")

func _on_notice(message: String) -> void:
	if overlay.visible:
		feedback.text = message

func _refresh_sound() -> void:
	$PauseOverlay/Panel/Content/Sound.text = "Sonido: silenciado" if notifications.muted else "Sonido: activado"
	if not notifications.settings_error.is_empty():
		$PauseOverlay/Panel/Content/Body.text = notifications.settings_error
