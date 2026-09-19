extends Node3D

## Sala de pruebas para fijar el angulo de camara y comprobar la densidad de
## texel con arte real. No es una escena de juego: solo suelo, unos muros y el
## personaje. La camara y la compensacion del sprite se derivan de
## VillageMetrics, asi que cambiar pitch_degrees basta para comparar angulos.

const BLOCK: Mesh = preload("res://assets/game/tilesets/grass_block.obj")
const MATERIAL: Material = preload("res://assets/game/materials/village_pixel.tres")

@export var pitch_degrees: float = 55.0
@export var ground_cells := Vector2i(26, 20)

@onready var camera: Camera3D = $Camera3D
@onready var player: CharacterBody3D = $Player

func _ready() -> void:
	_build_ground()
	_build_walls()
	_place_camera()
	_fit_sprite()

func _build_ground() -> void:
	var cells: Array[Vector3] = []
	for j in ground_cells.y:
		for i in ground_cells.x:
			cells.append(_cell_center(i - ground_cells.x / 2, j - ground_cells.y / 2, -1))
	_add_blocks(&"Ground", cells)

	# Un unico colisionador plano: miles de cajas contiguas enganchan al andar.
	var body := StaticBody3D.new()
	body.name = &"GroundBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ground_cells.x, 1.0, ground_cells.y) * VillageMetrics.CELL
	shape.shape = box
	shape.position = Vector3(0.0, -0.5 * VillageMetrics.CELL, 0.0)
	body.add_child(shape)
	add_child(body)

func _build_walls() -> void:
	var cells: Array[Vector3] = []
	# Muro en L de tres hiladas, para juzgar la cara vertical.
	for i in range(-6, 3):
		for h in 3:
			cells.append(_cell_center(i, -5, h))
	for j in range(-4, 1):
		for h in 3:
			cells.append(_cell_center(2, j, h))
	# Escalones sueltos de una, dos y tres hiladas.
	for step in 3:
		for h in step + 1:
			cells.append(_cell_center(5 + step * 2, 1, h))
	_add_blocks(&"Walls", cells)

	var body := StaticBody3D.new()
	body.name = &"WallBodies"
	for center in cells:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3.ONE * VillageMetrics.CELL
		shape.shape = box
		shape.position = center
		body.add_child(shape)
	add_child(body)

func _cell_center(i: int, j: int, height: int) -> Vector3:
	var c := VillageMetrics.CELL
	return Vector3((i + 0.5) * c, (height + 0.5) * c, (j + 0.5) * c)

func _add_blocks(node_name: StringName, centers: Array[Vector3]) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = BLOCK
	multi.instance_count = centers.size()
	for index in centers.size():
		multi.set_instance_transform(index, Transform3D(Basis.IDENTITY, centers[index]))
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = multi
	node.material_override = MATERIAL
	add_child(node)

func _place_camera() -> void:
	var pitch := deg_to_rad(pitch_degrees)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = VillageMetrics.CAMERA_SIZE
	camera.rotation = Vector3(-pitch, 0.0, 0.0)
	camera.position = Vector3(0.0, sin(pitch) * 24.0, cos(pitch) * 24.0)

func _fit_sprite() -> void:
	var sprite: AnimatedSprite3D = player.get_node(^"AnimatedSprite3D")
	sprite.pixel_size = VillageMetrics.TEXEL
	sprite.scale = Vector3(1.0, VillageMetrics.sprite_scale_y(pitch_degrees), 1.0)
