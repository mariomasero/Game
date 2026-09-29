# Suelo por teselas: transiciones y continuidad

22 de septiembre de 2026. Petición: «¿hay alguna manera de conectar texturas del
suelo?», con dos cosas a la vez —transiciones entre suelos distintos y
continuidad del patrón dentro de un mismo suelo— para las tres parejas de
césped, tierra y adoquín.

Pregunta clave del usuario: «me gustaría las 3 parejas pero no hay manera de
hacer esto proceduralmente o mediante algún plugin».

## La respuesta: las piezas de transición no son arte

Una pieza de transición es una **silueta de 1 bit aplicada a dos rellenos**. La
silueta es independiente del terreno, así que una sola colección de 16 sirve para
las tres parejas, y las 42 piezas salen de componer, no de dibujar. El usuario
dibuja **tres rellenos y ninguna pieza de transición**.

La silueta, además, se genera. Campo bilineal sobre los cuatro bits de la tesela:

    Phi_m(u,v) = (1-a)(1-b)·s_NW + a(1-b)·s_NE + (1-a)b·s_SW + ab·s_SE
    a = u/31    b = v/31    s_k = +1 si el bit k está puesto, -1 si no

**El divisor es 31 y no 32, y eso es lo que hace exacto el contrato de encaje.**
Con `(u+0,5)/32` queda un peso residual de 1/32 sobre las celdas lejanas en la
columna de borde, que desplaza la frontera medio téxel y descuadra las teselas
vecinas. Con `u/31`, `Phi(0,v) = (1-b)·s_NW + b·s_SW`: la columna de borde depende
**solo de sus dos celdas dueñas**. Como el borde derecho de `T(i,j)` y el
izquierdo de `T(i+1,j)` se asoman a las mismas dos celdas lógicas, evalúan la
misma función con los mismos argumentos y encajan por construcción, no por suerte.

El fleco orgánico lo da un ruido de valor evaluado en **coordenadas globales de
téxel** con periodo 128, función solo de la posición y nunca de la máscara. Por eso
el campo total es una única función global y las teselas son ventanas disjuntas de
su conjunto de nivel: no hay ninguna condición de casado que comprobar. Y por eso
la silueta depende también de la fase: si dependiera solo de la máscara, un borde
recto largo repetiría el mismo fleco cada 32 px.

Detalle en `scripts/presentation/ground_silhouette.gd` (en `tools/` hasta el 24 de septiembre de 2026; se movió porque el agua la usa en el juego).

## Arquitectura: el suelo deja de ser una rejilla de cubos

Pasa a ser **una sola `ArrayMesh`** de quads planos con UV por vértice, un
material y una llamada de dibujo.

El argumento decisivo no es el coste: `MultiMesh` solo varía `Transform3D` y
`Color` por instancia, y `custom_data` solo se lee desde un shader. Sin UV por
instancia cada tesela cuesta un material, y una UV por instancia tampoco podría
hacer que un patrón **cruce** el límite de celda, porque cada instancia recibe un
único rect. Es decir, `MultiMesh` resuelve las transiciones pero no la
continuidad. `ArrayMesh` resuelve las dos con el mismo mecanismo y sin shader.

De ~17.000 vértices con cinco de cada seis caras invisibles a 3.080 útiles.

La malla se construye **en unidades de celda** y la compensación anisótropa va en
la escala del nodo, así que cambiar `pitch_degrees` es una escritura de propiedad.

**Bobinado:** el orden de vértices copia la cara superior de `grass_block.obj`,
pero el bobinado va al revés. Wavefront declara las caras en antihorario y Godot
considera frontal el horario, así que el importador invierte el orden al traer el
modelo. Copiarlo literal deja el suelo invisible; comprobado, no supuesto.

## Selección: rejilla desplazada, 16 máscaras

La rejilla de dibujo va media celda al noroeste de la lógica. La tesela `T(i,j)`
cubre cuatro celdas en sus cuadrantes —`NW=(i-1,j-1)` bit 1, `NE=(i,j-1)` bit 2,
`SW=(i-1,j)` bit 4, `SE=(i,j)` bit 8— y la junta cruza por su **centro**, nunca
por su borde. 16 piezas con esquinas interiores y exteriores correctas, frente a
las 47 del blob. El bitmask cardinal de 4 bits cuesta lo mismo y no puede expresar
una esquina interior: descartado por incapacidad, no por coste.

**El desplazamiento no rompe la exactitud de téxel.** Media celda en X son 16 px;
en Z son `0,5 · cell_depth(p) · sin(p) · 32 = 16` px, porque `cell_depth(p)·sin(p)`
vale 1 por construcción. Verificado a 45°, 55°, 65° y 75° con desvío máximo de
0,0001 px (`tests/test_ground_texel.gd`).

## Continuidad: relleno de 4×4 celdas

Fase `(posmod(i,4), posmod(j,4))`. **`posmod` y no `%`**: `i` y `j` son negativos
en media sala y el resto con signo partiría el patrón por la mitad del mapa.

**La ventana de relleno va desplazada media celda.** La tesela `T(i,j)` cubre el
mundo de `i-0,5` a `i+0,5`, así que su téxel `u` está en la columna global
`32i-16+u` y la ventana que le toca empieza en `posmod(32·fase-16, 128)`, no en
`32·fase`. Con la ventana alineada a celda, el patrón daría un salto de 16 px
entre una tesela de relleno y su vecina de transición — justo la costura que este
trabajo viene a quitar. Es el detalle más fácil de equivocar de todo el sistema y
el atlas de depuración no puede cazarlo, porque sus rellenos son planos.

Las teselas de transición **también llevan fase**: cuesta atlas (720 teselas en
vez de 90) y a cambio la continuidad no se corta en el borde.

## Tres terrenos: precedencia con degradación automática

`GRASS=0 < DIRT=1 < COBBLESTONE=2`; el entero **es** la precedencia y no se
serializa nunca (la identidad que se guarda es el `StringName`).

Cuatro esquinas por tres terrenos son 81 combinaciones, y 36 —el 44 %— tienen los
tres terrenos y no tienen pieza en un atlas de parejas. Mientras queden más de
dos, se asciende el de menor precedencia **al menor de los presentes que sea mayor
que él**: al menor de los *presentes* y no a `bajo+1`, para no meter en la tesela
un terreno que el autor no ha pintado; y hacia arriba y nunca hacia abajo, porque
el de más precedencia es el que el autor ha puesto a propósito.

No prohíbe nada, porque el mapa pasa por estados inválidos mientras se dibuja,
pero **avisa** con la regla accionable: dejar una celda del terreno intermedio
entre terrenos no contiguos (distancia de Chebyshev ≥ 2). La muestra actual tiene
exactamente 2 teselas degradadas, y el número está clavado en la prueba para que
una nueva no entre de tapadillo.

## Atlas

`assets/game/tilesets/ground_atlas.png`, **1024 × 896**, rejilla de páginas de
128×128 a 8 por fila: fila 0 los rellenos (3 usadas, 5 reservadas), filas 1-6 las
tres parejas a 16 páginas cada una. 816 celdas de 32×32. Crecer no mueve nada ya
colocado porque las listas son *append-only* y la fila es el ordinal.

**Sin separadores ni padding**, y las UV son el rectángulo completo `[px, px+32]`.
La proyección es una escala pura alineada a ejes, un téxel por píxel con el centro
del píxel en el centro del téxel, así que el margen al borde es medio téxel frente
a un error de coma flotante de ~1e-4. **Condición de disparo: si alguien activa
mipmaps, esta disposición se rompe y el padding pasa a ser obligatorio.**

El error a no cometer es el inset de medio téxel: haría que los 32 píxeles de
pantalla muestreen 31 téxeles, duplicando una columna y perdiendo otra, y cuál
depende de dónde caiga el quad — o sea parpadeo al mover la cámara.
`GroundAtlas.uv_rect()` es el único sitio donde ocurre la conversión y no tiene
ningún parámetro que pueda ser un inset, a propósito.

## Forward+: el proyecto ya estaba en él, por accidente

El trabajo sin commitear había borrado `renderer/rendering_method="gl_compatibility"`
y su variante `.mobile`. Sin clave, Godot cae al valor por defecto del motor, que
es `forward_plus`, mientras `config/features` seguía declarando `"GL Compatibility"`.
Consultado al motor: `rendering_method = forward_plus`.

Se fija la clave explícitamente y se corrige `config/features`. No es un cambio de
dirección: es escribir lo que el proyecto ya hacía, y evita que una versión futura
de Godot lo cambie por debajo. **Esto deroga de hecho `010:80` («No hay que pasar a
Forward+»)**, que quedó derogado por un borrado de líneas y no por un argumento.

Se añaden guardas explícitas de antialiasing (`msaa_3d`, `screen_space_aa`,
`use_taa` a cero), porque Forward+ las expone y cualquiera de las tres rompe el
pixel art.

## Mediciones, 22 de septiembre de 2026, Forward+ sobre Vulkan

Región de 64×64 de relleno puro salvo donde se diga otra cosa.

### La geometría nueva no cambia la iluminación

| comparación | píxeles distintos | desviación máx. |
|---|---|---|
| cubos vs malla, **sin sombras del sol** | **0** de 518.400 | 0 |
| cubos vs malla, con sombras | 6 de 518.400 | 1/255 |
| cubos vs cubos (control de determinismo) | 0 | 0 |

Los 6 píxeles son del mapa de sombras: la geometría que proyecta cambió (cubos con
caras laterales → plano), así que 6 píxeles caen al otro lado de un redondeo sRGB.
Sin sombras la equivalencia es exacta.

### El acné de sombra existe también en Forward+

Contra lo que se podía esperar, los valores de la decisión 010 no eran un artefacto
de GL Compatibility.

| | colores en el suelo |
|---|---|
| sombras actuales (bias 0,05 / 2,0) | **9** |
| sin sombras del sol | **9** |
| sombras con bias 0 / 0 | **240** |

### Pero su justificación ha cambiado

Con el suelo ya fuera del mapa de sombras (`cast_shadow = OFF`):

| | región de suelo | región de muro |
|---|---|---|
| bias 0,05 / 2,0 | 9 | 10 |
| bias 0 / 0 | 9 | **286** |

Es decir: **el bias ya no hace nada por el suelo, y es lo único que evita el acné
en los muros.** Se queda, por otro motivo del que lo justificaba. Ajustarlo es
tarea aparte, ahora que se sabe a qué superficie sirve.

Apagar `cast_shadow` en el suelo cambia **0 píxeles**: el bias ya suprimía por
completo su auto-sombreado. Se hace igualmente porque quita trabajo inútil del mapa
de sombras y elimina la causa, no solo el síntoma.

### El atlas de depuración

Con colores planos por cuadrante y material sin luz, **476 de 480 celdas lógicas
visibles** salen como bloques de 32×32 px perfectamente uniformes del color de su
terreno. Las 4 restantes son exactamente las que tocan las 2 teselas degradadas
declaradas. La paleta de la imagen son **exactamente los tres colores de
depuración**, sin un solo color intermedio, lo que por sí solo demuestra que no hay
sangrado de téxel.

Esa única afirmación verifica a la vez la selección, el orden de bits, la
canonización de la pareja, la orientación UV, la búsqueda en el atlas y la
alineación de píxel, porque los cuatro cuartos de cada celda llegan de cuatro
teselas distintas y todos tienen que decir lo mismo.

## Correcciones que salieron de paso

**El colisionador del suelo estaba desfasado media celda en Z.** Con `extent=(34,21)`
la losa visual iba de `z=-10` a `z=+11` y el `BoxShape3D` de `-10,5` a `+10,5`: al
norte sobresalía sobre el vacío y al sur faltaba suelo sólido bajo suelo pintado.
No se veía por el margen de cuatro celdas del encuadre, pero el personaje se habría
caído por un borde que en pantalla se veía macizo. La causa era estructural:
división entera con un `extent` impar. Ahora se deriva del rango de teselas, y
`tests/test_ground_walk.gd` lo ata con un rayo por cada celda dibujada.

**`dirt_top.png` lleva un marco oscuro de 1 px** (`#281316` en los 124 téxeles del
perímetro) que es del lienzo del editor y no del dibujo. Repetirlo 4×4 imprimiría
una rejilla cada 32 px. La herramienta lo detecta y lo sustituye por el interior.

## Qué queda pendiente de revisión humana

1. **Si el arte se lee.** Ninguna prueba dice si una silueta de 32 px se entiende
   como borde de camino.
2. **Si la fase 4×4 se lee como textura o como cuadrícula.** El periodo son 128 px,
   un séptimo del ancho del viewport. Es el riesgo de arte número uno.
3. **`cobblestone_top.png` no repite sin costura.** Es el único arte que las
   medidas obligan a retocar.
4. **La tierra no tiene bordillo.** El acento se toma del color más oscuro del
   terreno de encima, y la paleta de la tierra, una vez quitado el marco del
   lienzo, no tiene ningún tono oscuro: su acento sale igual que su color
   dominante. El adoquín sí (`#363230`, su color de junta) y el césped también.
5. **Lo que la máscara no puede hacer y una pieza dibujada sí:** nada asoma por
   encima de la frontera, no hay sombra propia de escalón y los motivos no siguen
   la dirección de la junta. Lo primero se recupera casi entero con decoración
   suelta sembrada a lo largo de la frontera; lo último es el límite de fondo del
   método.
6. **Si el triple degradado es tolerable en su sitio.**

## Lo que se descartó, para que nadie lo reabra

- **`Decal`**: disponible en Forward+, pero proyecta sobre un AABB en espacio de
  mundo, así que su alineación al téxel depende de una posición en coma flotante y
  no de UV horneadas; su filtro es global y no por decal; y no resuelve la
  continuidad.
- **Terrain3D y el género «terreno con blending»**: mezcla lineal de texturas, que
  genera colores fuera de paleta y destruiría la compensación anisótropa.
- **Todos los addons de autotiling 3D**: pasan por `TileMapLayer` (prohibido como
  base del mundo por `AGENTS.md:58`) o por `GridMap` (48–141 ítems de biblioteca de
  cuatro vértices cada uno).
- **Triplanar**: mezcla proyecciones con peso continuo.
- **`MultiMesh` + shader**: en Forward+ `INSTANCE_CUSTOM` pasa a 32 bits y pierde su
  objeción de precisión, pero conserva la estructural.

Sí es legal el **recurso** `TileSet` —la prohibición nombra el nodo—, por si algún
día conviene autorar el mapa con el editor visual de tilesets y leer
`TileData.get_terrain_peering_bit()` desde un script.

Camino de mejora conocido, con criterio de disparo objetivo: sustituir el atlas
horneado por un shader de ~25 líneas que muestree el relleno con UV derivadas de la
posición de mundo. Baja los datos de arte de 3,5 MiB a ~64 KB y, sobre todo, escala
**linealmente** con el número de terrenos, porque las máscaras son independientes
del terreno. Adoptarlo cuando aparezca un cuarto terreno, no antes.
