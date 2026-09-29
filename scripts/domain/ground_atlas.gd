class_name GroundAtlas
extends RefCounted

## Reparto del atlas de suelo. Unica verdad de donde vive cada tesela.
##
## La consumen el juego (para escribir las UV de la malla), el horneador
## (tools/build_ground_atlas.gd, que escribe lo que all_cells() enumera) y el
## comprobador (tools/check_ground_atlas.gd, que verifica lo que all_cells()
## enumera). Al haber una sola lista no puede haber dos verdades que sincronizar.
##
## Este atlas NO es un atlas de bloque de PixZels: no tiene disposicion de seis
## caras, no sale de PixZels y sus UV las escribimos nosotros, asi que no hay
## ninguna transposicion que compensar. No anadirlo nunca a la tabla BLOQUES de
## tools/fix_block_atlas_orientation.gd.

## Lado de una celda de suelo en texeles. Coincide con VillageMetrics.TEXELS_PER_CELL.
const CELL_TEXELS := 32

## Lado del bloque de relleno, en celdas. El dibujo de un terreno se repite cada
## FILL_CELLS celdas en vez de cada una, que es lo que impide que el suelo se lea
## como cuadricula.
const FILL_CELLS := 4

## Una pagina es un bloque de FILL_CELLS x FILL_CELLS celdas: 128 x 128 texeles.
## Es la unidad de reparto del atlas.
const PAGE_TEXELS := CELL_TEXELS * FILL_CELLS

## Paginas por fila del atlas. Con 8 el atlas queda en 1024 de ancho.
const PAGES_PER_ROW := 8

## Guarda de tamano. Si el atlas la pasa, hay que reorganizarlo en mas columnas
## en vez de alargarlo: algunos controladores llevan mal las relaciones de
## aspecto extremas.
const MAX_ATLAS_TEXELS := 2048

## Bits de cuadrante de la rejilla desplazada. La tesela T(i,j) cubre cuatro
## celdas logicas con sus cuadrantes, y el bit vale 1 cuando esa celda es del
## terreno de ENCIMA de la pareja. NO reordenar: la posicion de la pagina de
## transicion sale de estos valores.
const BIT_NW := 1
const BIT_NE := 2
const BIT_SW := 4
const BIT_SE := 8
const MASK_ALL := 15
const MASK_COUNT := 16

## Mascaras de borde recto y diagonales. Se usan para rotular y para exigir
## cobertura en las pruebas.
const STRAIGHT_MASKS: Array[int] = [3, 5, 10, 12]
const DIAGONAL_MASKS: Array[int] = [6, 9]
const INNER_CORNER_MASKS: Array[int] = [7, 11, 13, 14]

## Terrenos. El valor entero ES la precedencia: quien se dibuja encima de quien.
## El orden es semantico y no arbitrario -- el cesped es el fondo, la tierra es
## un camino sobre el cesped, el adoquin un pavimento sobre la tierra.
##
## Este entero es codigo interno y no se serializa nunca. La identidad que se
## guarda es el StringName de TERRAIN_IDS, segun DEVELOPMENT_PLAN.md:114.
enum Terrain { GRASS = 0, DIRT = 1, COBBLESTONE = 2 }

const TERRAIN_IDS: Array[StringName] = [&"grass", &"dirt", &"cobblestone"]

## Parejas de transicion, como (bajo, alto) por precedencia. APPEND-ONLY: la fila
## de la pagina sale de esta posicion, asi que insertar en medio o reordenar
## mueve arte ya dibujado. Los StringName de arriba no cambian nunca.
const PAIRS: Array[Vector2i] = [
	Vector2i(Terrain.GRASS, Terrain.DIRT),
	Vector2i(Terrain.GRASS, Terrain.COBBLESTONE),
	Vector2i(Terrain.DIRT, Terrain.COBBLESTONE),
]

const FUENTE_DIR := "res://assets/source/tilesets/ground/"
const ATLAS_PATH := "res://assets/game/tilesets/ground_atlas.png"
const ATLAS_DEBUG_PATH := "res://assets/game/tilesets/ground_atlas_depuracion.png"

# --- Terrenos ---

static func terrain_count() -> int:
	return TERRAIN_IDS.size()

static func terrain_id(terrain: int) -> StringName:
	return TERRAIN_IDS[terrain]

## -1 si el id no se conoce. No se adivina.
static func terrain_from_id(id: StringName) -> int:
	return TERRAIN_IDS.find(id)

# --- Parejas ---

## Indice de la pareja que dibuja `alto` sobre `bajo`, o -1 si no hay pagina.
## Solo se guarda una orientacion: la que pone encima el de mas precedencia.
static func pair_index(bajo: int, alto: int) -> int:
	for q in PAIRS.size():
		if PAIRS[q].x == bajo and PAIRS[q].y == alto:
			return q
	return -1

static func has_pair(bajo: int, alto: int) -> bool:
	return pair_index(bajo, alto) >= 0

## Voltea los cuatro cuadrantes. Sirve para leer una pareja al reves: la misma
## pagina con la mascara complementada. Es una involucion, y lleva mascaras
## rectas a rectas y diagonales a diagonales.
static func invert_mask(mask: int) -> int:
	return (~mask) & MASK_ALL

# --- Tamano y paginas ---

## Paginas ocupadas: una de relleno por terreno y MASK_COUNT de transicion por
## pareja. Se guardan las 16 mascaras y no 14 para que la aritmetica no tenga
## casos especiales; las degeneradas 0 y 15 salen como relleno puro solas.
static func page_count() -> int:
	return terrain_count() + PAIRS.size() * MASK_COUNT

static func page_rows() -> int:
	return int(ceil(float(page_count()) / float(PAGES_PER_ROW)))

static func atlas_size() -> Vector2i:
	return Vector2i(PAGES_PER_ROW * PAGE_TEXELS, page_rows() * PAGE_TEXELS)

## Rectangulo de la pagina numero `page`, en texeles.
static func page_rect(page: int) -> Rect2i:
	var col := page % PAGES_PER_ROW
	var row := page / PAGES_PER_ROW
	return Rect2i(col * PAGE_TEXELS, row * PAGE_TEXELS, PAGE_TEXELS, PAGE_TEXELS)

## Las paginas de relleno van primero para que la fila 0 del atlas sea legible de
## un vistazo: un terreno por pagina, en el orden de TERRAIN_IDS.
static func fill_page_index(terrain: int) -> int:
	return terrain

## Cada pareja ocupa MASK_COUNT paginas consecutivas, empezando en la siguiente
## fila completa. Anadir un terreno no mueve ninguna pagina de transicion porque
## el hueco de la fila 0 esta reservado.
static func transition_page_index(pair: int, mask: int) -> int:
	return PAGES_PER_ROW + pair * MASK_COUNT + mask

static func fill_page(terrain: int) -> Rect2i:
	return page_rect(fill_page_index(terrain))

static func transition_page(pair: int, mask: int) -> Rect2i:
	return page_rect(transition_page_index(pair, mask))

# --- Celdas ---

## Celda de 32x32 dentro de una pagina, para la fase dada.
## fase = (posmod(i, FILL_CELLS), posmod(j, FILL_CELLS)).
static func cell_in_page(page: Rect2i, phase: Vector2i) -> Rect2i:
	return Rect2i(
		page.position.x + phase.x * CELL_TEXELS,
		page.position.y + phase.y * CELL_TEXELS,
		CELL_TEXELS, CELL_TEXELS)

static func fill_cell(terrain: int, phase: Vector2i) -> Rect2i:
	return cell_in_page(fill_page(terrain), phase)

static func transition_cell(pair: int, mask: int, phase: Vector2i) -> Rect2i:
	return cell_in_page(transition_page(pair, mask), phase)

# --- UV ---

## Rectangulo COMPLETO, borde a borde. Sin margen de medio texel.
##
## Este es el unico sitio del proyecto donde se convierte texeles a UV, y no
## tiene ningun parametro que pueda ser un inset, a proposito: meter medio texel
## hacia dentro escalaria la tesela a 31/32 y los 32 pixeles de pantalla
## muestrearian 31 texeles, duplicando una columna y perdiendo otra. Cual se
## duplica depende de donde caiga el quad, asi que el sintoma es parpadeo al
## mover la camara, que es lo que avisa AGENTS.md:74.
static func uv_rect(texels: Rect2i) -> Rect2:
	var atlas := atlas_size()
	return Rect2(
		float(texels.position.x) / float(atlas.x),
		float(texels.position.y) / float(atlas.y),
		float(texels.size.x) / float(atlas.x),
		float(texels.size.y) / float(atlas.y))

# --- Inventario ---

## Una entrada por cada celda de 32x32 del atlas. El horneador escribe lo que
## esto enumera y el comprobador verifica lo que esto enumera.
static func all_cells() -> Array[Dictionary]:
	var salida: Array[Dictionary] = []
	for t in terrain_count():
		for fy in FILL_CELLS:
			for fx in FILL_CELLS:
				salida.append({
					"kind": &"fill",
					"terrain": t,
					"id": terrain_id(t),
					"phase": Vector2i(fx, fy),
					"rect": fill_cell(t, Vector2i(fx, fy)),
					"label": "%s fase %d,%d" % [terrain_id(t), fx, fy],
				})
	for q in PAIRS.size():
		var bajo: int = PAIRS[q].x
		var alto: int = PAIRS[q].y
		for m in MASK_COUNT:
			for fy in FILL_CELLS:
				for fx in FILL_CELLS:
					salida.append({
						"kind": &"transition",
						"pair": q,
						"low": bajo,
						"high": alto,
						"mask": m,
						"phase": Vector2i(fx, fy),
						"rect": transition_cell(q, m, Vector2i(fx, fy)),
						"label": "%s sobre %s m%02d fase %d,%d" % [
							terrain_id(alto), terrain_id(bajo), m, fx, fy],
					})
	return salida

## Los cuatro cuadrantes de una mascara, para rotular y para el atlas de
## depuracion. true = terreno de encima.
static func mask_quadrants(mask: int) -> Dictionary:
	return {
		"nw": (mask & BIT_NW) != 0,
		"ne": (mask & BIT_NE) != 0,
		"sw": (mask & BIT_SW) != 0,
		"se": (mask & BIT_SE) != 0,
	}

# --- Rutas ---

static func atlas_path() -> String:
	return ATLAS_PATH

static func debug_atlas_path() -> String:
	return ATLAS_DEBUG_PATH

static func fill_source_path(terrain: int) -> String:
	return "%sfill_%s_%d.png" % [FUENTE_DIR, terrain_id(terrain), PAGE_TEXELS]

static func silhouette_source_path() -> String:
	return "%ssiluetas_%d.png" % [FUENTE_DIR, PAGE_TEXELS]
