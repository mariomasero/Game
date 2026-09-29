class_name VillageMetrics
extends RefCounted

## Escala del mundo. Un texel del arte mide siempre lo mismo en unidades, asi
## que todo lo que se dibuje a la misma resolucion encaja sin conversiones.
##
## El bloque de cesped exportado de PixZels mide 32x32x32 voxeles y ocupa una
## celda, de ahi salen todas las constantes.

## Texeles por celda, fijado por el arte.
const TEXELS_PER_CELL := 32

## Lado de una celda en unidades de mundo, sobre el eje X.
const CELL := 1.0

## Lado de un texel en unidades. Es el valor de scale_mesh de cada .obj.
const TEXEL := CELL / float(TEXELS_PER_CELL)

## Inclinacion de la camara aprobada en la decision 010. Las escenas la exponen
## como pitch_degrees para poder comparar angulos, pero lo que se hornea fuera de
## una escena (las bibliotecas de pintura de tools/build_paint_library.gd) y los
## objetos del pueblo parten de aqui.
const DEFAULT_PITCH_DEGREES := 55.0

## Celdas de alto que ocupa el frame del personaje. El frame mide 32x32 y el
## dibujo llena 16 px de ancho, asi que a 2 el personaje sale de un bloque de
## ancho y su frame abarca dos de alto.
const PLAYER_CELLS := 2

## Alto del viewport interno. Se lee de project.godot en vez de fijarlo aqui
## para que cambiar la resolucion no desincronice el tamano de camara.
static func viewport_height() -> float:
	return float(ProjectSettings.get_setting(
		"display/window/size/viewport_height", 360))

## Ancho del viewport interno, de project.godot por lo mismo que el alto.
static func viewport_width() -> float:
	return float(ProjectSettings.get_setting(
		"display/window/size/viewport_width", 640))

## Tamano ortogonal de camara que hace que una unidad mida TEXELS_PER_CELL
## pixeles de pantalla en el eje horizontal.
static func camera_size() -> float:
	return viewport_height() / float(TEXELS_PER_CELL)

## Lado de un texel del personaje en unidades. Es el pixel_size del sprite.
static func player_pixel_size() -> float:
	return TEXEL * float(PLAYER_CELLS)

## Ancho dibujado del personaje en unidades: 16 de los 32 texeles del frame.
static func player_width() -> float:
	return 16.0 * player_pixel_size()

## Alto dibujado del personaje en unidades de mundo, para una inclinacion dada.
## El dibujo llena 25 de los 32 texeles del frame.
static func player_height(pitch_degrees: float) -> float:
	return 25.0 * player_pixel_size() * sprite_scale_y(pitch_degrees)

## Pixeles de pantalla por unidad de mundo, en horizontal.
const PIXELS_PER_UNIT := float(TEXELS_PER_CELL) / CELL

## Compensacion anisotropa del mundo.
##
## Con la camara inclinada un angulo p sobre el horizonte, la proyeccion
## ortogonal comprime el suelo por sin(p) y las caras verticales por cos(p); el
## eje X no se toca. Ningun angulo deja las dos sin comprimir, asi que en vez de
## buscar el angulo se estira la geometria en mundo justo lo que la proyeccion
## va a comprimir. El resultado es que un bloque de 32x32x32 texeles ocupa
## exactamente 32x32 pixeles en cada cara visible, en cualquier angulo.
##
## La celda deja de ser cubica en unidades de mundo: mide CELL en X,
## cell_height() en Y y cell_depth() en Z. En pantalla vuelve a ser cuadrada,
## que es lo que importa para el pixel art.
static func block_scale(pitch_degrees: float) -> Vector3:
	return Vector3(CELL, cell_height(pitch_degrees), cell_depth(pitch_degrees))

## Alto de una celda en unidades. Hace que una cara vertical de 32 texeles mida
## 32 pixeles de pantalla.
static func cell_height(pitch_degrees: float) -> float:
	return CELL / cos(deg_to_rad(pitch_degrees))

## Fondo de una celda en unidades. Hace que una cara superior de 32 texeles mida
## 32 pixeles de pantalla.
static func cell_depth(pitch_degrees: float) -> float:
	return CELL / sin(deg_to_rad(pitch_degrees))

## Compensacion vertical del sprite del personaje. Es la misma regla que la de
## una cara vertical del mundo: el sprite mira a la camara, asi que se comprime
## por cos(p) igual que una pared. A 55 grados devuelve 1.7434468, el valor que
## el personaje aprobado ya usa.
static func sprite_scale_y(pitch_degrees: float) -> float:
	return cell_height(pitch_degrees) / CELL

## Tamano de un pixel de pantalla en unidades, sobre el plano de la camara.
static func screen_pixel() -> float:
	return CELL / float(TEXELS_PER_CELL)

## Pixel de pantalla de un punto del mundo, sin la posicion de la camara.
##
## La camara es ortografica y su orientacion no cambia nunca -- solo se desplaza
## al seguir al personaje --, asi que la pantalla es una funcion lineal del mundo
## mas un desplazamiento que solo depende de donde esta la camara. Esto es la
## parte lineal: restando dos puntos da lo mismo que Camera3D.unproject_position,
## este donde este la camara. Por eso lo que se compara en pantalla (que muro tapa
## al personaje) se puede calcular una vez y seguir valiendo con la camara en
## marcha. La y crece hacia abajo, como en unproject_position.
##
## De la base de la camara girada -p sobre X: su eje arriba es (0, cos p, -sen p).
static func screen_point(p: Vector3, pitch_degrees: float) -> Vector2:
	var pitch := deg_to_rad(pitch_degrees)
	return Vector2(p.x, p.z * sin(pitch) - p.y * cos(pitch)) * PIXELS_PER_UNIT
