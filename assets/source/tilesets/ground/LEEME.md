# Suelos del pueblo — qué dibujar

Tres archivos PNG, que se pueden entregar de uno en uno. Nada más. **No hay que dibujar ninguna pieza de transición:**
los bordes y las esquinas entre césped, tierra y adoquín los compone la
herramienta a partir de estos tres rellenos.

| Archivo | Tamaño |
|---|---|
| `fill_grass_128.png` | 128 × 128 px exactos |
| `fill_dirt_128.png` | 128 × 128 px exactos |
| `fill_cobblestone_128.png` | 128 × 128 px exactos |

Los nombres importan: la herramienta los busca por nombre. Godot no toca nada de
esta carpeta (la de arriba tiene un `.gdignore`), así que puedes guardar aquí
también tus `.aseprite` sin que el motor se entere.

## Dibuja como se ve en pantalla

La derecha del PNG es la derecha del mundo y **abajo** del PNG es hacia el fondo
de la pantalla. No hay que girar nada, ni transponer, ni pensar en 3D: lo que
dibujas es literalmente lo que se ve desde la cámara. Un camino que en el PNG va
de izquierda a derecha, en el juego va de izquierda a derecha.

Esto es distinto de los atlas de bloque de PixZels, que sí guardan la cara
superior transpuesta. Aquí no hay nada que compensar.

## Los 128 × 128 son 4 × 4 casillas del juego

Cada casilla del suelo mide 32 × 32 px, así que tu dibujo cubre cuatro por
cuatro. **No hace falta dibujar ni marcar las casillas**: el corte lo hace la
herramienta. Lo único que importa es que el dibujo sea continuo *a través* de
esos cortes.

Ese es justamente el objetivo: hoy el mismo matojo se repite en cada casilla de
32 px y el suelo se lee como una cuadrícula. Con 128 px el motivo tarda cuatro
casillas en repetirse.

## La regla más importante: costura

El PNG tiene que **repetir sin junta consigo mismo**. Si lo pegas cuatro veces en
cuadrícula no se debe ver dónde acaba uno y empieza el siguiente. En concreto: la
columna 127 tiene que continuar en la columna 0, y la fila 127 en la fila 0.

En Aseprite: **Vista → Modo mosaico → Mosaico en ambos ejes**, y **dibuja con eso
encendido de principio a fin**, no lo compruebes al final.

La herramienta mide la costura y avisa si no cierra.

## Variación de baja frecuencia

Manchas tonales amplias y detalles escasos y dispersos, no un patrón denso ni un
motivo fuerte. Dos motivos:

- Con 128 px de periodo, un detalle llamativo se reconoce y el suelo vuelve a
  leerse como cuadrícula, solo que de cuatro casillas en vez de una.
- El relleno se ve también **dentro** de las piezas de transición, junto a la
  junta. Un relleno callado empalma sin que se note; uno con estructura fuerte
  canta en el borde.

## Alfa 255 en todo el lienzo

Un solo téxel transparente abre un agujero por el que se ve el color de fondo
como un punto negro nítido, que se lee como un píxel muerto del monitor y no como
un error. La herramienta se niega a hornear si encuentra alguno.

## Lo que ya está medido sobre tu arte actual

- `grass_top.png` y `dirt_top.png` **repiten sin costura** a 32 px. Mientras no
  entregues los rellenos, la herramienta los usa repetidos cuatro por cuatro.
- `grass_top.png` es **un solo verde** (`#78a44b`). En el suelo ya no se usa:
  lo sustituye `fill_grass_128.png`, de manchas suaves que no compiten con las
  matas de hierba 3D.
- `dirt_top.png` lleva un **marco oscuro de 1 px** (`#281316`) que es del lienzo
  del editor y no del dibujo. La herramienta lo detecta y lo quita; si dibujas el
  relleno de tierra, no lo incluyas.
- **`cobblestone_top.png` no repite sin costura.** Es el único arte que las
  medidas obligan a retocar, aunque no dibujes los rellenos nuevos.
- El **bordillo** de cada transición se toma del color más oscuro del terreno de
  encima. El adoquín tiene uno bueno (`#363230`, su color de junta) y el césped
  también. La tierra no lo tenía; desde el `fill_dirt_128.png` del 23 de
  septiembre de 2026 su tono más oscuro le da bordillo (`#7a4841` desde que el
  29 de septiembre se pasó a la paleta del proyecto; antes `#774f40`).

## Estado (23 de septiembre de 2026)

- `fill_dirt_128.png` **entregado** (era `path_dirt.png` en `Game!ssetslocks`).
- `fill_grass_128.png` **entregado** (era `grass_128.png`). Sustituye al verde
  liso de `grass_top.png` en el suelo; el bloque de césped sigue usando su cara.
- 29 de septiembre: los rellenos pasan a `assets/source/palettes/apollo_proyecto.gpl`.
  El de césped es uno nuevo de Mario (12 colores de la paleta), con sus dos
  verdes más oscuros subidos un escalón a petición suya (Verde 1 → Verde 2 y
  Verde 2 → Verde 3; queda en 11 colores y su bordillo pasa a `#25562e`). Así ya
  repite sin costura; con los verdes originales la herramienta medía 4 téxeles de
  desajuste. Un primer intento de manchas «más naturales» (grupos grandes)
  estropeó los hierbajos y se leía como patrón al repetir. La versión vigente se
  rehizo con `terrain.py` de la skill `pixel-art-sprites` y los pinceles de Mario
  sacados de su textura (matas, brotes, motas, flores y piedras), receta en
  `.local/cesped_natural/cesped.txt`, semilla 8. Cambios respecto a su textura:
  el ruido de las manchas es de valor en varias escalas con dominante de 8 px (la
  suma de senos de `terrain.py` daba venas regulares), cobertura 30 %, y Verde 1
  ya no se usa: la sombra de las matas y las motas de las manchas van en Verde 2,
  como pide la skill para el tono más oscuro. Se desplazó 3 px en x para que la
  medida de costura, que compara con una sola columna del centro, no dé un falso
  aviso. La tierra y
  `cobblestone_top.png` se reasignaron al color de la paleta más cercano (la tierra
  conserva sus 4 tonos; el adoquín pasa de 5 grises a 4). Originales en
  `.local/respaldo-paleta-2026-09-29/`.
- El adoquín sigue saliendo de su `*_top.png` repetido 4 × 4. No hace
  falta entregarlos a la vez: en modo `normal` la herramienta usa cada relleno
  que exista y avisa de los que faltan.

## Cuando los tengas

```
godot --headless --path . --script tools/build_ground_atlas.gd -- --modo=normal
godot --headless --path . --editor --quit
godot --path . --script tests/capture_ground.gd -- --out=docs/captures/h6-suelo-real.png
```

## Opcional, si algún día quieres control artesano

`siluetas_128.png`, de 128 × 128, con 4 × 4 máscaras de 32 × 32 en blanco y negro
exactos. Sustituye a las siluetas generadas. Hay un contrato de encaje que
cumplir en los bordes, y el comprobador te dice en qué téxel exacto tiene que
entrar y salir la frontera por cada lado.
