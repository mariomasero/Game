class_name LabPersistence
extends Node

signal status_changed
signal attention_required

const Snapshot = preload("res://scripts/persistence/lab_snapshot.gd")
const Store = preload("res://scripts/persistence/lab_save_store.gd")

@export var enabled: bool = true
@export var save_path: String = "user://lab_save.json"
var session: LabSession
var status_message: String = ""
var last_error_detail: String = ""
var blocked: bool = false
var can_recover: bool = false
var write_failed: bool = false
var _elapsed: float = 0.0
var _store := Store.new()
var _previous_auto_quit: bool = true

func bind_session(value: LabSession) -> void:
	session = value
	if not enabled:
		return
	_previous_auto_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(save_and_quit)
	var result: Dictionary = _store.load_game(save_path, Snapshot.validate)
	match result.status:
		"ok":
			Snapshot.apply(session, result.state)
			status_message = "Partida cargada."
		"missing":
			save_now()
		_:
			blocked = true
			can_recover = result.status == "recovered"
			last_error_detail = result.error
			status_message = "No se pudo cargar la partida. Tus archivos se han conservado."
	session.committed.connect(_on_committed)
	status_changed.emit()
	if blocked or write_failed:
		attention_required.emit()

func _exit_tree() -> void:
	if enabled and session != null:
		get_tree().auto_accept_quit = _previous_auto_quit

func _process(delta: float) -> void:
	if not enabled or blocked or session == null or get_tree().paused:
		return
	_elapsed += delta
	if _elapsed >= 5.0:
		_elapsed = 0.0
		if session.batch_state == &"producing" or write_failed:
			save_now()
			if write_failed:
				attention_required.emit()

func _on_committed() -> void:
	save_now()
	if write_failed:
		attention_required.emit()

func save_now() -> String:
	if not enabled:
		return ""
	if blocked:
		return "Recupera la partida o inicia una nueva antes de guardar."
	var error: String = _store.save_game(save_path, Snapshot.capture(session), Snapshot.validate)
	write_failed = not error.is_empty()
	last_error_detail = error
	status_message = "No se pudo guardar. Reintenta antes de salir." if write_failed else "Partida guardada."
	_elapsed = 0.0
	status_changed.emit()
	return error

func recover() -> String:
	if not enabled or not blocked or not can_recover:
		return "No hay una copia recuperable."
	var error: String = _store.recover_backup(save_path, Snapshot.validate)
	if error.is_empty():
		var loaded: Dictionary = _store.load_game(save_path, Snapshot.validate)
		if loaded.status == "ok":
			error = Snapshot.apply(session, loaded.state)
		else:
			error = loaded.error
	if error.is_empty():
		blocked = false
		can_recover = false
		write_failed = false
		status_message = "Copia recuperada. El archivo anterior se ha conservado."
	else:
		last_error_detail = error
		status_message = "No se pudo recuperar la copia. Los archivos se han conservado."
	status_changed.emit()
	return error

func start_new_game() -> String:
	var fresh := LabSession.new()
	fresh.definitions = session.definitions
	fresh.money = maxi(fresh.definitions.starting_money, 0)
	var data := Snapshot.capture(fresh)
	fresh.free()
	var error: String = _store.replace_game(save_path, data, Snapshot.validate) if enabled else ""
	if error.is_empty():
		Snapshot.apply(session, data)
		blocked = false
		can_recover = false
		write_failed = false
		status_message = "Partida nueva guardada. La anterior se ha conservado."
	else:
		last_error_detail = error
		status_message = "No se pudo iniciar una partida nueva. Reintenta antes de salir."
	status_changed.emit()
	return error

func save_and_quit() -> void:
	if blocked or save_now().is_empty():
		get_tree().quit()
	else:
		attention_required.emit()

func quit_without_saving() -> void:
	get_tree().quit()
