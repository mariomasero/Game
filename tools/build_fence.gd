extends SceneTree

## Piezas PROVISIONALES de la valla de hierro (scenes/village/props/metal_fence.tscn),
## hasta que Mario las haga en PixZels:
##
## - fence_post.obj: el poste, 32 texeles de alto, centrado en su casilla.
## - fence_rail.obj: un tramo que sale del poste hacia +X y llega justo al borde
##   de la casilla. La valla lo pone girado hacia cada vecina, y el de la vecina
##   termina en el mismo borde: dos vallas juntas forman un paño de 64 texeles.
## - fence_atlas.png: una tira con los 7 colores del atlas de PixZels de la valla
##   (assets/source/props/metal_fence/). Cada cara es de un solo color y su UV cae
##   en el centro de su texel, asi que el filtrado nearest no mezcla nada.
##
## Salen en texeles, como las exportaciones de PixZels: el .obj se importa con
## Scale Mesh 0,03125 y queda a 32 texeles por unidad. Cada cara es un voxel, con
## la normal hacia fuera y en sentido antihorario, como los .obj de PixZels.
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tools/build_fence.gd

const DIR := "res://assets/game/models/metal_fence/"

## Los 7 colores del atlas de PixZels de la valla, de oscuro a claro.
const PALETA: Array[Color] = [
	Color8(0, 0, 0), Color8(39, 40, 44), Color8(45, 46, 50), Color8(53, 55, 60),
	Color8(85, 88, 94), Color8(173, 171, 172), Color8(246, 242, 241)]
enum Tono { CONTORNO, SOMBRA_PROFUNDA, SOMBRA, BASE, LUZ, PENUMBRA, BRILLO }

## Cajas en texeles, [desde, hasta), con el origen en el centro de la casilla y a
## ras de suelo. Una casilla va de -16 a 16 en X y Z.
const POSTE: Array[AABB] = [
	AABB(Vector3(-4, 0, -4), Vector3(8, 3, 8)),    # zocalo
	AABB(Vector3(-3, 3, -3), Vector3(6, 22, 6)),   # fuste
	AABB(Vector3(-4, 25, -4), Vector3(8, 2, 8)),   # collarin
	AABB(Vector3(-2, 27, -2), Vector3(4, 3, 4)),   # punta
	AABB(Vector3(-1, 30, -1), Vector3(2, 2, 2)),   # remate
]
## Del fuste (x = 3) al borde (x = 16). El medio barrote del borde se junta con el
## de la vecina en uno de 2 texeles, y los huecos salen iguales, de 5.
const TRAMO: Array[AABB] = [
	AABB(Vector3(3, 4, -1), Vector3(13, 2, 2)),    # travesano bajo
	AABB(Vector3(3, 20, -1), Vector3(13, 2, 2)),   # travesano alto
	AABB(Vector3(8, 0, -1), Vector3(2, 26, 2)),    # barrote
	AABB(Vector3(15, 0, -1), Vector3(1, 26, 2)),   # medio barrote del borde
]
## Planos X del tramo en los que no se ponen caras: la que toca el poste y la del
## borde, que siempre tapa la vecina (el tramo solo se ve si la hay).
const TRAMO_SIN_CARAS: Array[int] = [3, 16]

const DIRECCIONES: Array[Vector3i] = [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP,
	Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]

func _initialize() -> void:
	var ok := _atlas()
	ok = _obj("fence_post", POSTE, []) and ok
	ok = _obj("fence_rail", TRAMO, TRAMO_SIN_CARAS) and ok
	print("RESULTADO VALLA: " + ("piezas escritas" if ok else "FALLO"))
	quit(0 if ok else 1)

func _atlas() -> bool:
	var imagen := Image.create(PALETA.size(), 1, false, Image.FORMAT_RGBA8)
	for i in PALETA.size():
		imagen.set_pixel(i, 0, PALETA[i])
	return imagen.save_png(DIR + "fence_atlas.png") == OK

## Voxel -> indice de la caja que lo pone (la ultima gana).
func _voxeles(cajas: Array[AABB]) -> Dictionary:
	var salida := {}
	for i in cajas.size():
		var c := cajas[i]
		for x in range(int(c.position.x), int(c.end.x)):
			for y in range(int(c.position.y), int(c.end.y)):
				for z in range(int(c.position.z), int(c.end.z)):
					salida[Vector3i(x, y, z)] = i
	return salida

## Color de una cara. Las de arriba con luz y las de abajo en sombra. En las
## verticales, una linea de contorno en los bordes de su caja, como el atlas de
## PixZels, pero solo si la caja mide 4 o mas en ese sentido: en un barrote de 2
## todo seria contorno.
func _tono(cajas: Array[AABB], indice: int, v: Vector3i, d: Vector3i) -> Tono:
	if d == Vector3i.UP:
		return Tono.BRILLO if indice == cajas.size() - 1 and cajas == POSTE else Tono.LUZ
	if d == Vector3i.DOWN:
		return Tono.SOMBRA_PROFUNDA
	var c := cajas[indice]
	if cajas == POSTE and indice == POSTE.size() - 1 and v.y == int(c.end.y) - 1:
		return Tono.BRILLO   # la chispa del remate, como en las puntas de PixZels
	var eje_u := 2 if d.x != 0 else 0
	for eje in [eje_u, 1]:
		var desde := int(c.position[eje])
		var hasta := int(c.end[eje])
		if hasta - desde >= 4 and (v[eje] == desde or v[eje] == hasta - 1):
			return Tono.CONTORNO
	return Tono.BASE

func _obj(nombre: String, cajas: Array[AABB], planos_x_sin_caras: Array[int]) -> bool:
	var voxeles := _voxeles(cajas)
	var lineas := PackedStringArray(["# Pieza provisional de la valla: tools/build_fence.gd",
		"# Texeles; importar con Scale Mesh 0,03125.", "mtllib fence.mtl", "o " + nombre])
	for i in PALETA.size():
		lineas.append("vt %.6f 0.500000" % ((i + 0.5) / PALETA.size()))
	for d in DIRECCIONES:
		lineas.append("vn %d %d %d" % [d.x, d.y, d.z])
	lineas.append("usemtl fence_atlas")
	var caras: PackedStringArray = []
	var n := 0
	for v: Vector3i in voxeles:
		for k in DIRECCIONES.size():
			var d := DIRECCIONES[k]
			if voxeles.has(v + d):
				continue
			if d.x != 0 and (v.x + maxi(d.x, 0)) in planos_x_sin_caras:
				continue
			var esquinas := _esquinas(v, d)
			for p in esquinas:
				lineas.append("v %d %d %d" % [p.x, p.y, p.z])
			var t := int(_tono(cajas, voxeles[v], v, d)) + 1
			var a := n + 1
			caras.append("f %d/%d/%d %d/%d/%d %d/%d/%d" % [a, t, k + 1, a + 1, t, k + 1,
				a + 2, t, k + 1])
			caras.append("f %d/%d/%d %d/%d/%d %d/%d/%d" % [a, t, k + 1, a + 2, t, k + 1,
				a + 3, t, k + 1])
			n += 4
	lineas.append_array(caras)
	var archivo := FileAccess.open(DIR + nombre + ".obj", FileAccess.WRITE)
	if archivo == null:
		return false
	archivo.store_string("\n".join(lineas) + "\n")
	archivo.close()
	var mtl := FileAccess.open(DIR + "fence.mtl", FileAccess.WRITE)
	mtl.store_string("newmtl fence_atlas\nKd 1.0 1.0 1.0\nmap_Kd fence_atlas.png\n")
	mtl.close()
	print("%s: %d voxeles, %d caras" % [nombre, voxeles.size(), n / 4])
	return true

## Las cuatro esquinas de la cara del voxel `v` que mira hacia `d`, en sentido
## antihorario vistas desde fuera.
func _esquinas(v: Vector3i, d: Vector3i) -> Array[Vector3i]:
	var eje := 0 if d.x != 0 else (1 if d.y != 0 else 2)
	var u := Vector3i.ZERO
	var w := Vector3i.ZERO
	u[(eje + 1) % 3] = 1
	w[(eje + 2) % 3] = 1
	var base := v
	if d[eje] > 0:
		base[eje] += 1
	var esquinas: Array[Vector3i] = [base, base + u, base + u + w, base + w]
	# u x w apunta a +eje; si la cara mira a -eje se recorre al reves.
	if d[eje] < 0:
		esquinas.reverse()
	return esquinas
