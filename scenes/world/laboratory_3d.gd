extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var terminal: Area3D = $Terminal
@onready var machine: Area3D = $Machine/Interaction
@onready var hud: CanvasLayer = $HUD
@onready var overlay: Control = $HUD/Overlay
@onready var prompt: Label = $HUD/Prompt

func _ready() -> void:
	hud.bind_session($Session)
	hud.closed.connect(_close_terminal)
	hud.bind_persistence($Persistence)
	hud.new_game_started.connect(_reset_player)
	$Persistence.bind_session($Session)

func _available_station() -> Area3D:
	var nearest: Area3D = null
	for station: Area3D in [terminal, machine]:
		if station.can_interact(player):
			if nearest == null or player.global_position.distance_squared_to(station.global_position) < player.global_position.distance_squared_to(nearest.global_position):
				nearest = station
	return nearest

func _physics_process(_delta: float) -> void:
	var available: Area3D = null if overlay.visible else _available_station()
	terminal.set_hint_active(available == terminal)
	machine.set_hint_active(available == machine)
	if overlay.visible:
		prompt.text = "ESC · Volver al laboratorio     |     La producción continúa"
	elif available == terminal:
		prompt.text = "E · Pedidos y suministros     |     ESC · Pausa"
	elif available == machine:
		prompt.text = "E · Preparar / recoger lote     |     ESC · Pausa"
	else:
		prompt.text = "WASD / Flechas · Moverse     |     E · Usar equipo     |     ESC · Pausa"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	# La pantalla completa tambien funciona con el panel abierto.
	if event.is_action_pressed("toggle_fullscreen"):
		DisplayMode.toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if overlay.visible:
		return
	if event.is_action_pressed("interact"):
		var station := _available_station()
		if station != null:
			player.controls_enabled = false
			hud.open_station(&"terminal" if station == terminal else &"machine")
			get_viewport().set_input_as_handled()

func _close_terminal() -> void:
	player.controls_enabled = true

func _reset_player() -> void:
	player.position = Vector3(0, 0, 2.5)
	player.velocity = Vector3.ZERO
