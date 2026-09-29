class_name WaterSurface
extends RefCounted

## Agua del suelo: casillas pintadas como agua que se ven hundidas unos pixeles,
## con la textura animada de water_pixel.gdshader y una orilla de tierra.
##
## No es un terreno del atlas (GroundAtlas): se mueve, asi que no puede hornearse
## en ground_atlas.png ni tener teselas de transicion. Se dibuja en tres piezas:
##
## - La mascara de orilla (shore_mask), una imagen de un texel por texel de mundo
##   con 1 donde hay agua. Las esquinas del estanque salen redondeadas, las de
##   fuera y las de dentro, y todo el borde ondula un poco, para que la orilla no
##   siga el borde de las casillas. Es la unica verdad de donde acaba
##   el agua; las otras dos piezas la leen del mismo sitio
##   (shore_mask.gdshaderinc).
## - La orilla: las teselas del suelo que tocan agua (test_room.gd las saca de
##   Ground), enteras y con su UV de siempre, pero con un material que descarta
##   los texeles de agua (water_shore.gdshader).
## - La lamina de agua, en y = -hondo, debajo de la orilla. Hundirla es lo que da
##   volumen: con la camara mirando a -Z, bajo un borde con tierra al norte asoma
##   un escalon de tierra y al sur el suelo tapa el agua, como en un estanque de
##   verdad. Con el borde curvo, el escalon no es una cara recta que se pueda
##   modelar por casilla, asi que lo pinta el shader de la lamina: cada texel
##   mira si el rayo de la camara choca con tierra antes de llegar al agua.
##
## Las mallas van en unidades de celda en X y Z, como la del suelo, y el nodo
## lleva la escala anisotropa. Y va en unidades de mundo.

## Nombre del marcador de agua en paint_terrain.meshlib.tres. El pueblo lo lee
## por nombre, igual que los terrenos de GroundAtlas.TERRAIN_IDS.
const ITEM := &"water"

const SHADER: Shader = preload("res://assets/game/shaders/water_pixel.gdshader")
const SHORE_SHADER: Shader = preload("res://assets/game/shaders/water_shore.gdshader")
const TEXTURE: Texture2D = preload("res://assets/game/textures/water_128.png")
## El atlas del suelo, el mismo de ground_pixel.tres: la orilla son teselas del
## suelo y el escalon sale del relleno de tierra.
const GROUND_ATLAS: Texture2D = preload("res://assets/game/tilesets/ground_atlas.png")

const Silueta := preload("res://scripts/presentation/ground_silhouette.gd")

## Paleta de water_128.png por papeles, en el orden de los tone_* de
## water_pixel.gdshader: base, claro, oscuro, onda y destello. El shader separa
## las capas del agua por estos colores; si la textura cambia de paleta, hay que
## cambiarlos aqui (test_water.gd lo comprueba). Todos de apollo_proyecto.gpl
## desde el 29 de septiembre de 2026: Azul medio 2, 3 y 1, Azul 5 y Azul 6.
const PALETTE: Array[Color] = [
	Color8(56, 108, 136), Color8(68, 124, 150), Color8(48, 94, 122),
	Color8(115, 190, 211), Color8(164, 221, 219),
]
const TONES: Array[StringName] = [
	&"tone_base", &"tone_light", &"tone_dark", &"tone_ripple", &"tone_sparkle",
]

## Terreno con que se dibuja el escalon. Tierra aunque la orilla sea de cesped:
## lo que asoma bajo el borde de un estanque es barro, no hierba.
const BANK_TERRAIN := GroundAtlas.Terrain.DIRT

## Radio maximo, en texeles, de las esquinas redondeadas. Cada esquina toma el
## menor entre este y la mitad de sus dos lados, para que dos curvas del mismo
## lado no se pisen: una casilla suelta sale redonda (16), un canal de una
## casilla de ancho acaba en media luna y un estanque grande lleva esquinas de
## una casilla entera.
##
## No mas de una casilla: asi la curva de cada esquina cae dentro de su casilla y
## de las teselas que tocan agua, que son las unicas que la orilla dibuja.
const SHORE_RADIUS := 32.0
## Ondulacion de la orilla: cuantos texeles como mucho se desplaza el borde. Es
## un desplazamiento del dibujo con el ruido de GroundSilhouette, en coordenadas
## globales y con periodo de 128, asi que empalma solo entre teselas. Grano largo
## para que ondule en tramos de media casilla y no a mordiscos como el cesped;
## otra semilla que el suelo (1) para que un estanque no repita el fleco del
## camino que llega hasta el.
##
## Tope: menos de 16, o el agua llegaria a teselas sin agua en sus casillas.
const SHORE_FRINGE := 3.0
const SHORE_GRAIN := 16
const SHORE_SEED := 7

## Desplazamiento de cada texel, Vector2i, en una tabla de 128 x 128 que se
## repite como el ruido. Se calcula una vez: el pueblo entero la lee en cada
## repintado del editor.
static var _desvios: Array[Vector2i] = []

## Alto de la orilla en unidades de mundo para `texels` pixeles de pantalla. Es
## una cara vertical, asi que lleva la compensacion de cell_height.
static func depth(texels: int, cell: Vector3) -> float:
	return float(texels) * VillageMetrics.TEXEL * cell.y

## Mascara de agua de cada tesela que toca agua: Vector2i -> bits de GroundAtlas
## (BIT_NW...), 1 si ese cuadrante es agua. La tesela (i, j) va centrada en el
## vertice que comparten las celdas (i-1, j-1), (i, j-1), (i-1, j) e (i, j).
static func tile_masks(agua: Dictionary) -> Dictionary:
	var teselas := {}
	for c: Vector2i in agua:
		# La celda es el cuadrante k de la tesela que tiene en la esquina
		# opuesta: el NW (k = 0) de la tesela de su esquina SE, y asi.
		for k in 4:
			var t := c + Vector2i(1 - (k & 1), 1 - (k >> 1))
			teselas[t] = int(teselas.get(t, 0)) | (1 << k)
	return teselas

## Rectangulo de teselas que cubre la mascara de orilla.
static func mask_tiles(teselas: Dictionary) -> Rect2i:
	var rect := Rect2i()
	var primera := true
	for t: Vector2i in teselas:
		if primera:
			rect = Rect2i(t, Vector2i.ONE)
			primera = false
		else:
			rect = rect.expand(t).expand(t + Vector2i.ONE)
	return rect

## Texel de mundo del texel (0, 0) de la mascara. La tesela (i, j) cubre los
## texeles 32i-16 a 32i+15, porque la rejilla de dibujo va media celda al
## noroeste de la logica.
static func mask_origin(rect: Rect2i) -> Vector2i:
	var lado := Vector2i.ONE * GroundAtlas.CELL_TEXELS
	return rect.position * lado - lado / 2

## Imagen L8 del rectangulo `rect` de teselas: 255 donde hay agua y 0 donde hay
## tierra. Fuera de ella todo es tierra, porque solo hay agua en teselas que
## tocan una casilla de agua.
##
## Se dibuja en tres pasadas:
##   1. Las casillas de agua, cuadradas.
##   2. Las esquinas, redondeadas: en cada vertice donde una sola casilla de las
##      cuatro es distinta de las otras (una esquina de fuera si es agua, de
##      dentro si es tierra), se le quita a esa casilla lo que queda fuera de un
##      cuarto de circulo. Dos casillas de agua en diagonal son dos esquinas de
##      fuera: entre las dos queda un paso de tierra y no un canal de dos pixeles.
##   3. La ondulacion, solo en las teselas con agua y tierra.
static func shore_mask(teselas: Dictionary, rect: Rect2i) -> Image:
	var lado := GroundAtlas.CELL_TEXELS
	var medio := lado / 2
	var tam := rect.size * lado
	var img := Image.create_empty(tam.x, tam.y, false, Image.FORMAT_L8)
	for t: Vector2i in teselas:
		var en := (t - rect.position) * lado
		var mask: int = teselas[t]
		for k in 4:
			if mask & (1 << k):
				var cuarto := Vector2i(k & 1, k >> 1) * medio
				img.fill_rect(Rect2i(en + cuarto, Vector2i(medio, medio)), Color.WHITE)
	var base := img.get_data()

	var origen := mask_origin(rect)
	for t: Vector2i in teselas:
		var mask: int = teselas[t]
		for k in 4:
			var agua := mask & (1 << k) != 0
			# La casilla del cuadrante k es una esquina si sus dos vecinas por
			# el vertice son del otro tipo; en la diagonal, solo si es agua.
			var h := mask & (1 << (k ^ 1)) != 0
			var v := mask & (1 << (k ^ 2)) != 0
			var d := mask & (1 << (k ^ 3)) != 0
			if h == agua or v == agua or (d == agua and not agua):
				continue
			var s := Vector2i(1 if k & 1 else -1, 1 if k >> 1 else -1)
			var radio := minf(SHORE_RADIUS, minf(
				_side_cells(teselas, t, Vector2i(s.x, 0), k, agua),
				_side_cells(teselas, t, Vector2i(0, s.y), k, agua)) * medio)
			_round_corner(base, tam, t * lado - origen, s, radio, 0 if agua else 255)

	var salida := base.duplicate()
	if _desvios.is_empty():
		_build_offsets()
	for t: Vector2i in teselas:
		if teselas[t] == GroundAtlas.MASK_ALL:
			continue
		var en := (t - rect.position) * lado
		for y in range(en.y, en.y + lado):
			for x in range(en.x, en.x + lado):
				var mundo := origen + Vector2i(x, y)
				var p := Vector2i(x, y) + _desvios[posmod(mundo.y, Silueta.PERIODO)
					* Silueta.PERIODO + posmod(mundo.x, Silueta.PERIODO)]
				var valor := 0
				if p.x >= 0 and p.y >= 0 and p.x < tam.x and p.y < tam.y:
					valor = base[p.y * tam.x + p.x]
				salida[y * tam.x + x] = valor
	return Image.create_from_data(tam.x, tam.y, false, Image.FORMAT_L8, salida)

## Casillas que mide el lado de la esquina del cuadrante `k` de la tesela `t`,
## yendo en la direccion `paso`: cuantos vertices seguidos, empezando por el
## siguiente, son borde recto con la casilla de la esquina del mismo lado. Si la
## esquina es de agua el borde tiene agua de ese lado; si es de tierra, tierra.
static func _side_cells(teselas: Dictionary, t: Vector2i, paso: Vector2i, k: int,
		agua: bool) -> int:
	# Los dos cuadrantes del lado de la casilla: la misma fila si se anda en X,
	# la misma columna si se anda en Y.
	var lado_bits := 0
	for q in 4:
		var misma := (q >> 1) == (k >> 1) if paso.y == 0 else (q & 1) == (k & 1)
		if misma:
			lado_bits |= 1 << q
	var recto := lado_bits if agua else GroundAtlas.MASK_ALL & ~lado_bits
	var n := 1
	while int(teselas.get(t + paso * n, 0)) == recto:
		n += 1
	return n

## Quita a la esquina de la casilla que sale del texel `vertice` hacia `s` lo que
## cae fuera del cuarto de circulo de radio `radio` tangente a sus dos lados, y
## lo pone a `valor`.
static func _round_corner(datos: PackedByteArray, tam: Vector2i, vertice: Vector2i,
		s: Vector2i, radio: float, valor: int) -> void:
	var n := ceili(radio)
	for b in n:
		for a in n:
			var fuera := Vector2(radio - (a + 0.5), radio - (b + 0.5))
			if fuera.x > 0.0 and fuera.y > 0.0 and fuera.length_squared() > radio * radio:
				var x := vertice.x + (a if s.x > 0 else -1 - a)
				var y := vertice.y + (b if s.y > 0 else -1 - b)
				if x >= 0 and y >= 0 and x < tam.x and y < tam.y:
					datos[y * tam.x + x] = valor

static func _build_offsets() -> void:
	var periodo := Silueta.PERIODO
	_desvios.resize(periodo * periodo)
	for y in periodo:
		for x in periodo:
			_desvios[y * periodo + x] = Vector2i(
				roundi(SHORE_FRINGE * Silueta.ruido(x, y, SHORE_SEED, SHORE_GRAIN)),
				roundi(SHORE_FRINGE * Silueta.ruido(x, y, SHORE_SEED + 1, SHORE_GRAIN)))

## Material de la lamina. El shader lee la textura por texel de mundo, asi que
## un texel de agua cae en un pixel de pantalla igual que uno de suelo sin pasarle
## ninguna escala. `ripple_speed` en pixeles por segundo; `mascara` y `origen`
## son los de shore_mask y mask_origin; `hondo` en pixeles.
static func material(ripple_speed: float, mascara: Texture2D, origen: Vector2i,
		hondo: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"water_texture", TEXTURE)
	mat.set_shader_parameter(&"ripple_speed", ripple_speed)
	var tonos := tone_texels()
	for k in TONES.size():
		mat.set_shader_parameter(TONES[k], tonos[k])
	_set_mask(mat, mascara, origen)
	mat.set_shader_parameter(&"depth_texels", hondo)
	mat.set_shader_parameter(&"ground_atlas", GROUND_ATLAS)
	var relleno := GroundAtlas.fill_page(BANK_TERRAIN)
	mat.set_shader_parameter(&"bank_page", relleno.position)
	return mat

## Un texel de water_128.png de cada color de PALETTE, en su orden; (-1, -1) si
## falta alguno.
static func tone_texels() -> Array[Vector2i]:
	var img := TEXTURE.get_image()
	if img.is_compressed():
		img.decompress()
	var salida: Array[Vector2i] = []
	for c in PALETTE:
		var donde := Vector2i(-1, -1)
		for y in img.get_height():
			for x in img.get_width():
				var p := img.get_pixel(x, y)
				if donde.x < 0 and Color8(p.r8, p.g8, p.b8) == c:
					donde = Vector2i(x, y)
			if donde.x >= 0:
				break
		salida.append(donde)
	return salida

## Material de la orilla: las teselas del suelo menos el agua.
static func shore_material(mascara: Texture2D, origen: Vector2i) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHORE_SHADER
	mat.set_shader_parameter(&"ground_atlas", GROUND_ATLAS)
	_set_mask(mat, mascara, origen)
	return mat

static func _set_mask(mat: ShaderMaterial, mascara: Texture2D, origen: Vector2i) -> void:
	mat.set_shader_parameter(&"shore_mask", mascara)
	mat.set_shader_parameter(&"mask_origin", origen)
	mat.set_shader_parameter(&"texels_per_cell", float(VillageMetrics.TEXELS_PER_CELL))

## Malla de dos superficies: 0 la lamina de agua y 1 la orilla. Vacia (sin
## superficies) si no hay agua.
##
## `teselas` es lo que da tile_masks. `orilla` es Vector2i -> Rect2 con la UV de
## cada tesela del suelo que toca agua, elegida por test_room.gd como las demas;
## las de agua por completo no estan porque no tienen nada que dibujar.
static func build_mesh(teselas: Dictionary, orilla: Dictionary, hondo: float) -> ArrayMesh:
	var malla := ArrayMesh.new()
	if teselas.is_empty():
		return malla
	# La lamina cubre las teselas con agua y la fila de al norte de cada una: el
	# texel de lamina que se ve por un hueco de la orilla esta `hondo` pixeles
	# mas al norte que el hueco, bajo el suelo.
	var lamina := {}
	for t: Vector2i in teselas:
		lamina[t] = true
		lamina[t + Vector2i.UP] = true
	var partes := _quads(_sorted(lamina), {}, -hondo)
	_add_surface(malla, partes[0], partes[1], partes[2], partes[3])
	var trozos := _quads(_sorted(orilla), orilla, 0.0)
	if not trozos[0].is_empty():
		_add_surface(malla, trozos[0], trozos[1], trozos[2], trozos[3])
	return malla

## Orden fijo, para que dos arranques del mismo mapa den la misma malla.
static func _sorted(celdas: Dictionary) -> Array:
	var lista: Array = celdas.keys()
	lista.sort()
	return lista

## Un quad horizontal por tesela a la altura `y`, con la UV de `uvs` si la tiene.
## Mismo orden y bobinado que las teselas del suelo: A, B, C, D con A,C,B y
## A,D,C, frontal visto desde arriba.
static func _quads(teselas: Array, uvs: Dictionary, y: float) -> Array:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var coords := PackedVector2Array()
	var idx := PackedInt32Array()
	for t: Vector2i in teselas:
		var base := verts.size()
		verts.push_back(Vector3(t.x - 0.5, y, t.y - 0.5))
		verts.push_back(Vector3(t.x - 0.5, y, t.y + 0.5))
		verts.push_back(Vector3(t.x + 0.5, y, t.y + 0.5))
		verts.push_back(Vector3(t.x + 0.5, y, t.y - 0.5))
		for _k in 4:
			norms.push_back(Vector3.UP)
		if uvs.has(t):
			var uv: Rect2 = uvs[t]
			coords.push_back(uv.position)
			coords.push_back(Vector2(uv.position.x, uv.end.y))
			coords.push_back(uv.end)
			coords.push_back(Vector2(uv.end.x, uv.position.y))
		idx.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	return [verts, norms, coords, idx]

static func _add_surface(malla: ArrayMesh, verts: PackedVector3Array,
		norms: PackedVector3Array, uvs: PackedVector2Array, idx: PackedInt32Array) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	if not uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
