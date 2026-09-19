extends Area3D

@onready var interaction_point: Marker3D = $InteractionPoint
@onready var hint: InteractHint = $InteractHint

func can_interact(body: PhysicsBody3D) -> bool:
	if not overlaps_body(body):
		return false
	# Query at chest height, ending at the console's accessible front edge.
	# Furniture and walls share layer 1; the player is on layer 2.
	var query := PhysicsRayQueryParameters3D.create(
		body.global_position + Vector3(0, 0.8, 0),
		interaction_point.global_position,
		1,
		[body.get_rid()]
	)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

# El cartel flotante solo se muestra cuando la interacción está realmente disponible.
func set_hint_active(value: bool) -> void:
	hint.active = value
