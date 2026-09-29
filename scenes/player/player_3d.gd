extends CharacterBody3D

@export var speed: float = 3.2
## Multiplicador de velocidad mientras se mantiene la accion "run" (Shift).
## La cadencia de la animacion se multiplica por lo mismo, que es lo que
## mantiene constante el terreno recorrido por fotograma y evita que los pies
## patinen. Como la hoja de correr tiene seis fotogramas frente a los cuatro de
## andar, la zancada sale mas larga ademas de mas rapida.
@export var run_multiplier: float = 1.8
@export var camera: Camera3D
## Lo mas alto que se sube andando, sin saltar: un bordillo, no un muro. Lo fija
## la escena del mundo a la altura de su losa mas baja (test_room.gd), porque en
## unidades depende del angulo de camara. Con 0 no se sube nada.
@export var step_height: float = 0.0:
	set(valor):
		step_height = valor
		# Bajar el bordillo tiene que ser tan inmediato como subirlo: sin esto el
		# personaje flota al salir de la acera y cae con la gravedad.
		floor_snap_length = maxf(floor_snap_length, valor)
var controls_enabled: bool = true
var _facing: StringName = &"down"

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D

func _physics_process(delta: float) -> void:
	var input_direction := Vector2.ZERO
	if controls_enabled:
		input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var running: bool = controls_enabled and Input.is_action_pressed("run")
	var right := Vector3.RIGHT
	var back := Vector3.BACK
	if is_instance_valid(camera):
		right = camera.global_basis.x
		back = camera.global_basis.z
		right.y = 0.0
		back.y = 0.0
		right = right.normalized()
		back = back.normalized()
	var direction := right * input_direction.x + back * input_direction.y * _depth_gain()
	var current_speed: float = speed * (run_multiplier if running else 1.0)
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0
		_step_up(delta)
	move_and_slide()
	_update_animation(input_direction, running)

## Si lo que frena el paso es un escalon de hasta step_height con suelo encima,
## sube al personaje a su altura; move_and_slide hace despues el avance. Solo se
## sube: un muro sigue parando aunque su pie sea bajo, porque a la altura del
## escalon tambien choca.
func _step_up(delta: float) -> void:
	if step_height <= 0.0:
		return
	var avance := Vector3(velocity.x, 0.0, velocity.z) * delta
	if avance.is_zero_approx():
		return
	var choque := KinematicCollision3D.new()
	if not test_move(global_transform, avance, choque) or choque.get_normal().y > 0.7:
		return
	var subida := Vector3(0.0, step_height, 0.0)
	if test_move(global_transform, subida):
		return
	# El apoyo se tantea un radio de pie mas alla: con el avance de un solo
	# fotograma el pie apenas asoma sobre la losa y puede tocar solo su arista,
	# que da un choque inclinado. Solo se sube; el avance lo sigue haciendo
	# move_and_slide.
	var tanteo := avance.normalized() * maxf(avance.length(), _radio() + safe_margin)
	var arriba := global_transform.translated(subida)
	if test_move(arriba, tanteo):
		return
	var apoyo := KinematicCollision3D.new()
	if not test_move(arriba.translated(tanteo), -subida, apoyo) 			or apoyo.get_normal().y < 0.7:
		return
	global_position.y += step_height + apoyo.get_travel().y

## Radio de lo que pisa: el pie que le pone la escena del mundo
## (test_room.gd, _fit_body) o, sin el, la capsula.
func _radio() -> float:
	for nombre: NodePath in [^"Pie", ^"CollisionShape3D"]:
		var forma := get_node_or_null(nombre) as CollisionShape3D
		if forma != null and forma.shape is CylinderShape3D:
			return (forma.shape as CylinderShape3D).radius
		if forma != null and forma.shape is CapsuleShape3D:
			return (forma.shape as CapsuleShape3D).radius
	return 0.0

## Cuanto hay que estirar el avance en profundidad para que el personaje recorra
## los mismos pixeles de pantalla en todas las direcciones.
##
## La camara inclinada comprime el eje de profundidad por sen(inclinacion), asi
## que sin compensar se avanza mas despacio en vertical que en horizontal
## aunque la velocidad en el mundo sea la misma. El factor sale de la propia
## camara: con rotacion (-p, 0, 0) su basis.z es (0, sen p, cos p).
func _depth_gain() -> float:
	if not is_instance_valid(camera):
		return 1.0
	var sine: float = absf(camera.global_basis.z.y)
	return 1.0 / sine if sine > 0.001 else 1.0

func _update_animation(direction: Vector2, running: bool) -> void:
	if not direction.is_zero_approx():
		sprite.flip_h = direction.x < 0.0
		if is_zero_approx(direction.x):
			_facing = &"down" if direction.y > 0.0 else &"up"
		elif is_zero_approx(direction.y):
			_facing = &"side"
		else:
			_facing = &"down_side" if direction.y > 0.0 else &"up_side"
	var actual_velocity := Vector2(get_real_velocity().x, get_real_velocity().z)
	var moving: bool = controls_enabled and actual_velocity.length_squared() > 0.01
	var estado := &"idle_"
	if moving:
		estado = &"run_" if running else &"walk_"
	sprite.speed_scale = run_multiplier if moving and running else 1.0
	sprite.play(StringName(String(estado) + String(_facing)))
