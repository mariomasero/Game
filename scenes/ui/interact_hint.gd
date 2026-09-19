class_name InteractHint
extends Node3D

## Cartel flotante que aparece sobre un objeto cuando el jugador puede usarlo.
## Solo se dibuja a sí mismo: quien conoce al jugador activa o desactiva `active`.

const FADE_SPEED: float = 9.0
const BOB_HEIGHT: float = 0.05
const BOB_SPEED: float = 2.6
const RISE: float = 0.14

@export var text: String = "E":
	set(value):
		text = value
		if is_instance_valid(label):
			label.text = value

var active: bool = false

var _shown: float = 0.0
var _elapsed: float = 0.0
var _base_height: float = 0.0

@onready var label: Label3D = $Label

func _ready() -> void:
	label.text = text
	_base_height = position.y
	_apply(0.0)

func _process(delta: float) -> void:
	_elapsed += delta
	_shown = move_toward(_shown, 1.0 if active else 0.0, FADE_SPEED * delta)
	_apply(_shown)

# Aparece subiendo desde el objeto y flota despacio mientras está disponible.
func _apply(amount: float) -> void:
	visible = amount > 0.01
	position.y = _base_height - RISE * (1.0 - amount) + sin(_elapsed * BOB_SPEED) * BOB_HEIGHT * amount
	label.modulate.a = amount
	label.outline_modulate.a = amount
