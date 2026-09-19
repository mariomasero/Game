@tool
extends StaticBody3D

## Objeto importado de PixZels. Apoya la malla en el suelo, la centra sobre el
## origen y genera una caja de colision del tamano del objeto ya escalado.
## No hay medidas escritas a mano: basta con cambiar Scale Mesh en la
## importacion del .obj y volver a abrir la escena.

func _ready() -> void:
	fit_to_mesh()

func fit_to_mesh() -> void:
	var model := get_node_or_null(^"Model") as MeshInstance3D
	var collision := get_node_or_null(^"Collision") as CollisionShape3D
	if model == null or collision == null or model.mesh == null:
		return

	# El nodo puede llevar rotacion propia, asi que medimos la caja ya orientada.
	var oriented: AABB = Transform3D(model.transform.basis, Vector3.ZERO) * model.mesh.get_aabb()

	model.position = Vector3(
		-oriented.position.x - oriented.size.x * 0.5,
		-oriented.position.y,
		-oriented.position.z - oriented.size.z * 0.5)

	var box := BoxShape3D.new()
	box.size = oriented.size
	collision.shape = box
	collision.position = Vector3(0.0, oriented.size.y * 0.5, 0.0)
