extends Control

signal announced(message: String)
signal sound_changed

const Cues = preload("res://scripts/presentation/lab_cues.gd")
var muted: bool = false
var settings_error: String = ""
var world_visible: bool = true
var _settings_path: String = ""
var _session: LabSession
var _last_batch: StringName = &"empty"
var _remaining: float = 0.0
var _cues: Dictionary[StringName, AudioStreamWAV] = {}

@onready var cue_player: AudioStreamPlayer = $CuePlayer
@onready var toast: PanelContainer = $Toast
@onready var text: Label = $Toast/Margin/Text

func bind_session(value: LabSession) -> void:
	_session = value
	_last_batch = value.batch_state
	value.changed.connect(_observe_batch)

func configure_settings(path: String) -> void:
	_settings_path = path
	settings_error = ""
	var settings := ConfigFile.new()
	if not path.is_empty() and settings.load(path) == OK:
		var preference: Variant = settings.get_value("audio", "muted", false)
		muted = preference if preference is bool else false
	else:
		muted = false
	if muted:
		cue_player.stop()
	sound_changed.emit()

func toggle_sound() -> void:
	muted = not muted
	if muted:
		cue_player.stop()
	settings_error = ""
	if not _settings_path.is_empty():
		var settings := ConfigFile.new()
		settings.set_value("audio", "muted", muted)
		var directory_error := DirAccess.make_dir_recursive_absolute(_settings_path.get_base_dir())
		if directory_error != OK or settings.save(_settings_path) != OK:
			settings_error = "El ajuste se aplica ahora, pero no se ha podido guardar."
	sound_changed.emit()

func notify(message: String, kind: StringName = &"success") -> void:
	text.text = message
	_remaining = 4.0
	announced.emit(message)
	if muted:
		return
	if not _cues.has(kind):
		_cues[kind] = Cues.make_cue(kind)
	cue_player.stream = _cues[kind]
	cue_player.play()

func clear_notice() -> void:
	_remaining = 0.0
	toast.hide()
	cue_player.stop()

func _observe_batch() -> void:
	if _last_batch == &"producing" and _session.batch_state == &"ready":
		notify("Lote listo · Recoge la muestra en la máquina", &"ready")
	_last_batch = _session.batch_state

func _process(delta: float) -> void:
	if not get_tree().paused and world_visible:
		_remaining = maxf(0.0, _remaining - delta)
	toast.visible = _remaining > 0 and world_visible and not get_tree().paused
