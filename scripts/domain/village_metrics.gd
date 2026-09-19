class_name VillageMetrics
extends RefCounted

## Escala del mundo. Un texel del arte mide siempre lo mismo en unidades, asi
## que todo lo que se dibuje a la misma resolucion encaja sin conversiones.
##
## El bloque de cesped exportado de PixZels mide 32x32x32 voxeles y ocupa una
## celda, de ahi salen todas las constantes.

## Texeles por celda, fijado por el arte.
const TEXELS_PER_CELL := 32

## Lado de una celda en unidades de mundo.
const CELL := 1.0

## Lado de un texel en unidades. Es el valor de scale_mesh de cada .obj.
const TEXEL := CELL / float(TEXELS_PER_CELL)

## Alto del viewport interno, declarado en project.godot.
const VIEWPORT_HEIGHT := 360.0

## Tamano ortogonal de camara que hace que una unidad mida TEXELS_PER_CELL
## pixeles de pantalla en el eje horizontal.
const CAMERA_SIZE := VIEWPORT_HEIGHT / float(TEXELS_PER_CELL)

## Pixeles de pantalla por unidad de mundo, en horizontal.
const PIXELS_PER_UNIT := float(TEXELS_PER_CELL) / CELL

## Compensacion vertical del sprite del personaje para una inclinacion dada.
## A 55 grados devuelve 1.7434468, el valor que el personaje aprobado ya usa.
static func sprite_scale_y(pitch_degrees: float) -> float:
	return 1.0 / cos(deg_to_rad(pitch_degrees))

## Tamano de un pixel de pantalla en unidades, sobre el plano de la camara.
static func screen_pixel() -> float:
	return CELL / float(TEXELS_PER_CELL)
