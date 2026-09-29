# Parcela del laboratorio y cámara que sigue al personaje

23 de septiembre de 2026. El usuario quiere construir como en Stardew Valley. La
primera pregunta fue si un sistema de bloques es la base adecuada. Precisó:

- Un pueblo diseñado a mano con una **parcela reservada** para construir y
  ampliar el laboratorio, como la zona de construcción de Stardew Valley.
- **Primera versión:** colocar y mover muebles, mesas y máquinas sobre una
  cuadrícula, solo a ras de suelo.
- **Más adelante:** ampliar el edificio y decidir si también se editan suelos y
  paredes dentro de la parcela.
- **No** excavar ni modificar el terreno de todo el mapa como en Core Keeper.

Pidió revisar qué partes de GridMap sirven antes de rehacer nada. Para esta tarea
eligió **solo la base técnica**: sin modo construir, sin interfaz y sin dinero.

## Revisión de GridMap para construir

Fuentes: la [referencia de GridMap de 4.7](https://docs.godotengine.org/en/4.7/classes/class_gridmap.html),
el código de la decisión 013 y lo medido allí.

| Parte de GridMap | ¿Sirve? | Motivo |
|---|---|---|
| Pincel, paleta y plantas en el editor | **Sí** | Ya pinta terreno y bloques. Ahora pinta también la parcela, con la forma que se quiera |
| Editor de `MeshLibrary` de 4.7 | **Sí** | Para autorar bloques |
| `set_cell_item` en ejecución y octantes, que dibujan y chocan por trozos | **Hoy no; candidato más adelante** | El jugador no edita el terreno, así que no hace falta partir el suelo. Puede servir para las paredes y suelos interiores de la ampliación, pero el fundido por bloque seguiría pidiendo la conversión a `MultiMeshInstance3D` |
| Ítems como muebles o máquinas | **No** | Un ítem es solo malla, colisión y navegación, sin script, estado ni interacción. Ocupa una celda y no sabe de huellas de 2×1. GridMap no guarda datos por celda |
| Giro de ítems (24 orientaciones) | **No para muebles** | El giro se aplica **después** de la escala horneada: con la celda de (1; 1,74; 1,22), 90° deforma el píxel y la pieza se sale de su celda. `VillageProp` lo resuelve con R⁻¹·S·R |
| `map_to_local` / `local_to_map` | Equivalente | `_cell_center` da lo mismo, y `test_village_map` lo comprueba |
| Navegación horneada | Hoy no | No hay personajes no jugadores |

**Decisión:** GridMap sigue siendo solo herramienta de autoría: terreno, bloques y
parcela. Los muebles y las máquinas son escenas `VillageProp`, y lo que ocupa
cada casilla lo lleva un modelo de datos propio. No se rehace nada de lo que ya
funciona: suelo, muros, fundido, escala, objetos y guías siguen igual.

La respuesta a la pregunta de partida es que la rejilla es la base correcta: los
dos juegos de referencia construyen sobre casillas y a una sola altura. Lo que
faltaba no era la idea, sino una cámara que se mueva y un registro de qué ocupa
cada casilla.

## Cámara que sigue al personaje

`test_room.gd` gana `follow_player`. En la sala está apagado, porque la sala juzga
téxeles con un encuadre fijo y `test_ground_texel` y las capturas cuentan con él.
`village.tscn` lo enciende.

- **Siempre la misma orientación.** La cámara mira al objetivo desde el mismo
  desplazamiento que antes, (0; 24·sen p; 24·cos p). Solo se desplaza; no gira.
- **Encaje al píxel.** El objetivo se calcula en píxeles de pantalla y se
  redondea. En mundo son pasos de 1/32 en X y de 1/(32·sen p) en Z. Así todo lo
  estático se desplaza un número entero de píxeles y los téxeles siguen cayendo
  en píxeles enteros.
- **Límites.** Cada celda mide 32 × 32 px en pantalla, así que los bordes del
  suelo en pantalla salen del rango de teselas. El objetivo se frena para que el
  encuadre no pase de ellos. Si el mapa es más estrecho que la pantalla, se queda
  en su centro.
- **Fundido independiente de la cámara.** Nueva función pura
  `VillageMetrics.screen_point(p, pitch)`: la parte lineal de la proyección,
  (x; z·sen p − y·cos p)·32. Los rectángulos de los muros y la silueta del
  personaje se miden con ella en vez de con `unproject_position`, así que los
  rectángulos calculados una vez siguen valiendo con la cámara en marcha.
- El suelo se construye ahora antes que la cámara, porque sus bordes son los
  límites del seguimiento.

### Medido con ventana (Forward+, D3D12)

Mapa de unas 85 × 50 celdas, cámara desplazada a (22; 23,5), lejos del origen:

| Qué | Resultado |
|---|---|
| Colores de una zona de césped puro de 64 × 64 | **9** con la cámara en el origen y **9** desplazada. Sin acné nuevo |
| Dos fotos con la cámara quieta | **0** píxeles distintos |
| Paso de cámara tras mover el personaje 0,37 × 0,23 unidades | **12 × 6 píxeles**, enteros |
| Píxeles que no coinciden tras compensar ese paso | **122 de 518 400** (0,02 %), todos en el borde diagonal de la sombra de un muro |

Los 122 píxeles son el mapa de sombras del sol, que se reencaja cuando la cámara
se mueve. Con la cámara quieta no cambia nada. Si al jugar el borde de las
sombras se nota vivo al andar, las palancas son el tamaño del atlas de sombra
direccional o fijar el reparto de cascadas. **No se ha tocado ninguna**: hay que
verlo primero en pantalla.

## Parcela y ocupación

- **Parcela pintada.** `tools/build_paint_library.gd` genera una tercera biblioteca,
  `paint_zones.meshlib.tres`, con un solo marcador amarillo semitransparente.
  Se llama `PlotLayout.ITEM_PARCELA` (`parcela`) y flota 0,04 para no parpadear
  contra los de terreno. `village.tscn` gana el GridMap `Parcela`. Se lee la
  planta 0 por nombre de ítem, como el terreno, y en el juego se oculta. El suelo
  se extiende hasta cubrir la parcela aunque no se haya pintado terreno.
- **`PlaceableDefinition`** (`scripts/domain/placeable_definition.gd`) es un
  `Resource` con `id` estable, `nombre`, `huella` sin girar y `escena`. Hay una
  de ejemplo: `resources/definitions/placeables/bloque_cesped.tres`. No hay arte
  de muebles todavía.
- **`PlotLayout`** (`scripts/domain/plot_layout.gd`) lleva las reglas, sin escena:
  - `permitidas`: las casillas de la parcela;
  - `bloqueadas`: bloques de la planta 0 y huellas de los objetos de `Objetos`;
  - colocar, mover (atómico: si no cabe, no cambia nada) y quitar;
  - motivo del rechazo: `fuera_de_parcela`, `bloqueada` u `ocupada`;
  - `to_dict` y `from_dict` con `schema_version` e id de definición, listos para
    cuando vuelva el guardado. Un mueble desconocido o que ya no cabe se
    informa; nunca se descarta en silencio.
- **Casilla y mundo.** El origen de un mueble es la esquina de x y z mínimas de su
  huella ya girada. El centro en el mundo cae en el centro de casilla si la huella
  es impar y en la esquina si es par, igual que el anclaje automático de
  `VillageProp`. La prueba lo comprueba con `posicion_encajada`.
- **Muebles iniciales puestos a mano.** Nuevo `Node3D` `Muebles` en `village.tscn`.
  Sus hijos son escenas `VillageProp` que Mario arrastra como los objetos.
  - Se reconocen por su escena, que tiene que ser la `escena` de una definición
    del `catalog` de Pueblo.
  - Se registran en `village.gd` → `layout`.
  - Lo que no cuadra sale como aviso en el nodo Pueblo del editor: sin
    definición, fuera de la parcela, solapado, encima de un bloque, sin encajar
    en la rejilla o con una huella distinta de la que mide el modelo.
- **`VillageProp`** expone `huella()` y `giro_en_pasos()`, antes privados.

## Límites y lo que queda fuera

- **Fuera de esta tarea:**
  - el modo construir (tecla, cursor, elegir pieza, poner y quitar con el ratón);
  - dinero e inventario;
  - guardado;
  - ampliar el edificio;
  - paredes y suelos interiores;
  - comprobar que el personaje no está en la casilla donde se pone un mueble.

  `layout` y sus funciones son la base para todo ello.
- **El fundido recorre todos los bloques en cada fotograma.** Con mapas de miles
  de bloques puede notarse. Agruparlos por zonas se hará solo si una medición lo
  pide.
- **El borde de las sombras cambia un poco al moverse la cámara** (ver la
  medición).
- **En el editor, la cámara se queda en el origen**, como vista previa del
  encuadre de salida. En el juego sigue al personaje.
- **La escala de los muebles es la de `DEFAULT_PITCH_DEGREES`**, igual que las
  bibliotecas y los objetos.

## Verificación

- `tests/test_plot_layout.gd`: 30 comprobaciones, 0 fallos. Cubre huellas giradas,
  ida y vuelta entre casilla y mundo, rechazos, mover atómico, quitar, guardar y
  cargar pasando por JSON, id desconocido y versión desconocida.
- `tests/test_village_map.gd`: 60 comprobaciones, 0 fallos (antes 42). Cubre:
  - biblioteca de zonas sin colisión;
  - lectura de la parcela y bloque que la bloquea;
  - mueble registrado en su casilla;
  - avisos de mueble solapado y fuera;
  - coincidencia con `posicion_encajada`;
  - suelo bajo la parcela;
  - `screen_point` igual a `unproject_position` con la cámara en cuatro sitios;
  - cámara en píxeles enteros y sin enseñar fondo en las dos esquinas del mapa;
  - muro que se funde lejos del origen, y muro lejano que no.
- Las pruebas de suelo y la guarda de píxel no cambian: 26, 17, 5 y 41
  comprobaciones, 0 fallos. El editor importa sin errores y la escena principal
  arranca con el aviso esperado de 2 teselas degradadas.
- La medición con ventana de la tabla de arriba.
- **Pendiente de revisión manual por el usuario:**
  - pintar una parcela en el editor;
  - arrastrar el bloque de ejemplo a `Muebles` y ver el aviso al sacarlo de la
    parcela;
  - con F6, andar fuera de la pantalla inicial y ver que la cámara le sigue sin
    temblar.
