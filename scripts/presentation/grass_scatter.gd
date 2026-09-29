class_name GrassScatter
extends RefCounted

## Reparto de las matas de hierba sobre las celdas de cesped, sin escena.
##
## Un reparto uniforme se lee como sal espolvoreada. La hierba de verdad crece a
## manchas, asi que una fraccion fija de las matas (cluster_share, 0,7 por
## omision) se agrupa alrededor de unos centros con caida normal -- densa en el
## medio, rala en el borde, sin corte -- y el resto se reparte al azar para que
## entre mancha y mancha no quede el suelo pelado.
##
## Todo va en unidades de celda (la celda (i, j) ocupa [i, i+1] x [j, j+1]) y la
## semilla es fija: el mismo mapa da siempre la misma hierba.

## Intentos por mata antes de darla por perdida. Una mata de mancha que cae fuera
## del cesped se vuelve a tirar en vez de caer al azar, para que la fraccion en
## manchas no baje en los mapas con mucho camino.
const INTENTOS := 8

## Cada elemento es Vector3(x, z, cercania): la posicion del pie de la mata en
## celdas y lo cerca que esta del centro de su mancha, de 1 en el centro a casi
## 0 en el borde. Las matas sueltas llevan cercania 0 exacta.
##
##   grass             Dictionary Vector2i -> true con las celdas de cesped
##   density           matas por celda de cesped, de media
##   cluster_share     fraccion de las matas que va en manchas
##   cluster_radius    desviacion tipica de una mancha, en celdas
##   cells_per_cluster celdas de cesped por centro de mancha
##   margin            distancia minima del pie al borde del cesped, en celdas
static func scatter(grass: Dictionary, density: float, cluster_share: float,
		cluster_radius: float, cells_per_cluster: float, margin: float,
		semilla: int) -> PackedVector3Array:
	var salida := PackedVector3Array()
	if grass.is_empty():
		return salida
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var celdas: Array = grass.keys()

	var centros: Array[Vector2] = []
	var n_centros := maxi(1, roundi(celdas.size() / maxf(cells_per_cluster, 1.0)))
	for _k in n_centros:
		centros.append(_punto_en(celdas[rng.randi() % celdas.size()], rng))

	var total := roundi(celdas.size() * density)
	# Reparto exacto y no por moneda: con la moneda la fraccion bailaria de un
	# mapa a otro y la regla del 70 % seria solo una tendencia.
	var en_manchas := roundi(total * cluster_share)
	var dos_sigma := 2.0 * cluster_radius * cluster_radius
	for k in total:
		for _intento in INTENTOS:
			var p: Vector2
			var cercania := 0.0
			if k < en_manchas:
				var c: Vector2 = centros[rng.randi() % centros.size()]
				p = c + Vector2(rng.randfn(0.0, cluster_radius), rng.randfn(0.0, cluster_radius))
				cercania = exp(-p.distance_squared_to(c) / dos_sigma)
			else:
				p = _punto_en(celdas[rng.randi() % celdas.size()], rng)
			if is_on_grass(grass, p, margin):
				salida.append(Vector3(p.x, p.y, cercania))
				break
	return salida

## true si el pie y las cuatro esquinas de un cuadrado de lado 2*margin a su
## alrededor caen en cesped. Aleja las matas del flequillo de las teselas de
## transicion, que se come parte de la celda de cesped vecina.
static func is_on_grass(grass: Dictionary, p: Vector2, margin: float) -> bool:
	for dx in [-margin, margin]:
		for dz in [-margin, margin]:
			if not grass.has(Vector2i(floori(p.x + dx), floori(p.y + dz))):
				return false
	return true

static func _punto_en(celda: Vector2i, rng: RandomNumberGenerator) -> Vector2:
	return Vector2(celda) + Vector2(rng.randf(), rng.randf())
