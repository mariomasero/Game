extends RefCounted

## Genera las siluetas de transicion del suelo. Sin dibujar nada a mano.
##
## Una silueta es una mascara de 1 bit de 32x32: 1 donde va el terreno de encima
## y 0 donde va el de debajo. La misma silueta sirve para las tres parejas, asi
## que las 42 piezas de transicion del atlas salen de aqui y no del lapiz.
##
## Vive en scripts/ y no en tools/ porque la usa tambien el juego: la orilla del
## agua (WaterSurface.shore_mask) es la misma silueta con 1 donde hay agua, y se
## calcula al construir el mapa porque el agua no se hornea en el atlas.
##
## ## El campo
##
##     Phi_m(u,v) = (1-a)(1-b) s_NW + a(1-b) s_NE + (1-a)b s_SW + ab s_SE
##     a = u/31   b = v/31   s_k = +1 si el bit k esta puesto, -1 si no
##
## El divisor es 31 y no 32, y eso es lo que hace exacto el contrato de encaje.
## Con (u+0.5)/32 queda un peso residual de 1/32 sobre las celdas lejanas en la
## columna de borde, que desplaza la frontera medio texel y descuadra las
## teselas vecinas. Con u/31 sale exacto:
##
##   - Phi(0,0) = s_NW exacto, asi que el texel de cada esquina es de su unica
##     celda duena.
##   - Phi(0,v) = (1-b) s_NW + b s_SW, asi que la columna de borde depende SOLO
##     de sus dos celdas duenas. Esa es la condicion de encaje: el borde derecho
##     de T(i,j) y el izquierdo de T(i+1,j) se asoman a las mismas dos celdas
##     logicas, luego evaluan la misma funcion con los mismos argumentos.
##   - m=0 da Phi = -1 y m=15 da Phi = +1 en toda la tesela, asi que mientras la
##     amplitud del ruido sea menor que 1 las dos degeneradas salen limpias.
##   - Una mascara de arista cruza en v = 15,5: el centro de la tesela, que es
##     justo el borde de celda logica.
##
## ## El ruido
##
## Se evalua en coordenadas GLOBALES de texel, con periodo PERIODO, y es funcion
## solo de la posicion y nunca de la mascara. Por eso el campo total es una unica
## funcion global y las teselas son ventanas disjuntas de su conjunto de nivel:
## no hay ninguna condicion de casado que comprobar entre vecinas, porque el
## texel 31 de una y el texel 0 de la siguiente son posiciones globales
## contiguas y leen muestras contiguas del mismo ruido.
##
## Esa es la razon de que la silueta dependa de la fase ademas de la mascara: si
## dependiera solo de la mascara, un borde recto largo repetiria el mismo fleco
## cada 32 pixeles. Con la fase, el periodo del fleco pasa a ser PERIODO, el
## mismo que el del relleno.

const LADO := 32
const FASES := 4
const PERIODO := LADO * FASES

## Amplitud por texel de fleco: A = fleco * 2/31, porque el gradiente del campo
## en la frontera vale 2/31 por texel. Asi el parametro dice lo que parece.
const AMPLITUD_POR_TEXEL := 2.0 / 31.0

## Las dos diagonales valen +-0,001 en los cuatro texeles centrales, asi que sin
## esto el punto de pellizco lo decidiria el ruido. Se fija a mano; son texeles
## interiores y no pueden romper el contrato de bordes.
const DIAGONALES := [6, 9]

## Devuelve 1024 bytes con 0 o 1, en orden de filas.
static func silueta(mask: int, fase: Vector2i, semilla: int, fleco: float,
		grano: int, diagonal_arriba: bool) -> PackedByteArray:
	var amplitud := fleco * AMPLITUD_POR_TEXEL
	var s := [
		1.0 if (mask & 1) != 0 else -1.0,   # NW
		1.0 if (mask & 2) != 0 else -1.0,   # NE
		1.0 if (mask & 4) != 0 else -1.0,   # SW
		1.0 if (mask & 8) != 0 else -1.0,   # SE
	]
	var salida := PackedByteArray()
	salida.resize(LADO * LADO)
	for v in LADO:
		var b := float(v) / float(LADO - 1)
		for u in LADO:
			var a := float(u) / float(LADO - 1)
			var phi: float = (1.0 - a) * (1.0 - b) * s[0] \
				+ a * (1.0 - b) * s[1] \
				+ (1.0 - a) * b * s[2] \
				+ a * b * s[3]
			var x := LADO * fase.x - LADO / 2 + u
			var y := LADO * fase.y - LADO / 2 + v
			var valor := phi + amplitud * ruido(x, y, semilla, grano)
			salida[v * LADO + u] = 1 if valor > 0.0 else 0

	if mask in DIAGONALES:
		var centro := 1 if diagonal_arriba else 0
		for dv in 2:
			for du in 2:
				var u := LADO / 2 - 1 + du
				var v := LADO / 2 - 1 + dv
				salida[v * LADO + u] = centro
	return salida

## Ruido de valor con periodo PERIODO en los dos ejes, interpolado con
## smoothstep sobre una reticula de paso `grano`.
static func ruido(x: int, y: int, semilla: int, grano: int) -> float:
	var nodos := PERIODO / grano
	var gx := float(x) / float(grano)
	var gy := float(y) / float(grano)
	var x0 := int(floor(gx))
	var y0 := int(floor(gy))
	var tx := gx - float(x0)
	var ty := gy - float(y0)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var v00 := _valor(posmod(x0, nodos), posmod(y0, nodos), semilla)
	var v10 := _valor(posmod(x0 + 1, nodos), posmod(y0, nodos), semilla)
	var v01 := _valor(posmod(x0, nodos), posmod(y0 + 1, nodos), semilla)
	var v11 := _valor(posmod(x0 + 1, nodos), posmod(y0 + 1, nodos), semilla)
	return lerpf(lerpf(v00, v10, tx), lerpf(v01, v11, tx), ty)

## Mezclador entero explicito y no hash(): hash() de Godot no esta garantizado
## estable entre versiones, y este PNG se hornea y se versiona.
static func _valor(x: int, y: int, semilla: int) -> float:
	var h := (x * 374761393 + y * 668265263 + semilla * 362437) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = (h ^ (h >> 16)) & 0xFFFFFFFF
	return float(h & 0xFFFF) / 32767.5 - 1.0

## Anillo de acento: los texeles del terreno de encima que tocan al de debajo
## por uno de sus cuatro lados.
##
## Erosion de 4 vecinos y no de 8: con 8 se marcan tambien los contactos solo
## diagonales y el anillo sale grueso y escalonado.
##
## En el borde de la tesela se replica el texel de dentro, porque la silueta de
## la vecina no se conoce aqui. El error maximo es de un texel y solo en el punto
## de cruce.
static func acento(silueta_bits: PackedByteArray) -> PackedByteArray:
	var salida := PackedByteArray()
	salida.resize(LADO * LADO)
	for v in LADO:
		for u in LADO:
			var i := v * LADO + u
			if silueta_bits[i] == 0:
				salida[i] = 0
				continue
			var borde := 0
			for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var nu: int = clampi(u + d.x, 0, LADO - 1)
				var nv: int = clampi(v + d.y, 0, LADO - 1)
				if silueta_bits[nv * LADO + nu] == 0:
					borde = 1
			salida[i] = borde
	return salida
