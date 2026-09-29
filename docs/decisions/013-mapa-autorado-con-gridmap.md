# Mapa del pueblo pintado a mano con GridMap

23 de septiembre de 2026. Petición: «Para empezar a montar los escenarios dentro
del editor de Godot, ¿cómo lo hago para generar los mapas a mi gusto e ir poniendo
los tiles?». Y después: «iré poco a poco añadiendo más bloques, árboles, casas,
elementos de la ciudad… quiero ver el mapa al que le voy añadiendo los elementos
3D a mano». El usuario eligió GridMap en 3D frente a un TileMap 2D aparte, y que el
código de unión lo escriba el agente: él trabaja solo con herramientas del editor.

## Problema

`test_room.gd` construía todo en `_ready()`. El suelo salía de tres listas de
`Rect2i` y los muros de bucles escritos a mano. Al abrir la escena en el editor
no se veía ni suelo ni muros, y no había forma de pintar.

## Decisión

Hay tres capas, y cada una se autora con una herramienta nativa del editor:

| Capa | Nodo en `village.tscn` | Cómo se edita | Qué sale en el juego |
|---|---|---|---|
| Suelo | GridMap `Terreno` con `paint_terrain.meshlib.tres` | Pincel de GridMap, solo en la planta 0 | La `ArrayMesh` por teselas de la decisión 011, con sus transiciones |
| Bloques | GridMap `Bloques` con `paint_blocks.meshlib.tres` | Pincel de GridMap, con plantas | Muros de `MultiMeshInstance3D` con sombra, fundido y una caja de colisión por bloque |
| Objetos | `Node3D` `Objetos` con escenas `VillageProp` | Arrastrar desde el Sistema de archivos | La escena tal cual, con su colisión |

- **GridMap como lienzo, no como suelo.** La decisión 011 rechazó GridMap para
  *dibujar* el suelo, porque harían falta entre 48 y 141 ítems. Aquí solo tiene tres
  marcadores planos y semitransparentes, uno por terreno. `village.gd` los lee y
  construye la malla de siempre, así que la objeción no aplica. En el juego el
  lienzo se oculta.
- **La identidad es el nombre del ítem.** Coincide con `GroundAtlas.TERRAIN_IDS`
  y se traduce con `terrain_from_id`. El entero del ítem no significa nada, como
  pide la regla de guardar el `StringName`. Un nombre desconocido es hierba y
  lanza un aviso.
- **La escala va horneada en la biblioteca.** GridMap no escala sus piezas a la
  celda, así que `tools/build_paint_library.gd` escribe la escala anisótropa
  en la transformación de cada ítem, a partir de
  `VillageMetrics.DEFAULT_PITCH_DEGREES`. `village.gd` fija `cell_size` desde
  `VillageMetrics` en el editor y en el juego.
- **Los muros salen de la biblioteca.** `village.gd` toma de cada ítem su malla, el
  material de la superficie 0 y su transformación. `test_room.gd` pasa a admitir
  un trío Shadow/Solid/Faded por tipo de bloque. El primero conserva los nombres
  `WallsShadow`, `WallsSolid` y `WallsFaded`, y los siguientes llevan número. Un
  bloque nuevo en la biblioteca funciona sin tocar código.
- **La vista previa se construye en el editor.** `test_room.gd` pasa a ser `@tool`,
  pero no hace nada en el editor. `village.gd` construye en el editor solo el nodo
  `Ground`, sin `owner` para que no se guarde, y lo rehace cuando cambia una
  huella de lo pintado. La comprueba cada 0,25 s, porque GridMap no avisa por
  celda.
- **Los objetos se colocan libres, no en GridMap.** GridMap no admite escenas con
  colisión ni lógica. `VillageProp` (`scenes/village/props/village_prop.gd`) se
  encarga de tres cosas:
  - Estira `Modelo` con `R⁻¹·S·R`, para que la escala quede en los ejes del mundo
    aunque el objeto esté girado.
  - Apoya y centra el modelo midiendo su caja.
  - En el editor, encaja la posición en la rejilla y el giro en múltiplos de 90°.

  El imán del editor admite un único paso para los tres ejes, así que no sirve con
  celdas de (1; 1,74; 1,22). El anclaje automático pone el objeto en el centro de
  la celda si su huella es impar y en la esquina si es par. La colisión automática
  es la caja del modelo; se puede apagar para ajustarla a mano, por ejemplo a solo
  el tronco de un árbol.

La sala de pruebas y sus rectángulos no cambian. Sigue siendo el banco de las 16
máscaras y de las 2 teselas degradadas.

## Límites conocidos

- ~~El mapa jugable cabe en una pantalla.~~ Resuelto en la
  [decisión 014](014-parcela-y-camara.md): la cámara sigue al personaje a píxel
  exacto y el fundido ya no depende de dónde esté la cámara.
- **Los objetos libres no se funden.** Una casa delante del personaje lo tapa sin
  volverse transparente. El fundido solo cubre los bloques de `Bloques`.
- **Un bloque de varias superficies se dibuja con un solo material**, el de la
  superficie 0, porque el fundido usa `material_override`.
- **Solo giros de 90°.** Con escala anisótropa, un giro libre deformaría el píxel.
- Las miniaturas de la paleta se recortan a mano de la cara superior del atlas,
  porque en modo headless el editor no las genera.

## Verificación

- `tests/test_village_map.gd`: 42 comprobaciones, 0 fallos, tanto en modo headless
  como con ventana bajo Forward+. En headless sale al final
  `ERROR: Parameter "material" is null` desde `servers/rendering/dummy`; con
  ventana no aparece.
- Las pruebas de suelo y la guarda de píxel siguen igual: 26, 17, 5 y 41
  comprobaciones, 0 fallos, con el aviso esperado de 2 teselas degradadas.
- El editor importa sin errores, y al abrir `village.tscn` en el editor headless
  no aparece ningún error.
- `docs/captures/013-pueblo-pintado.png` es una captura del juego con un camino
  pintado, adoquín, un muro de piedra de dos plantas, bloques de césped y el objeto
  de ejemplo.
- **Pendiente de revisión manual por el usuario:** pintar en el editor con ventana
  y ver cómo se rehace la vista previa, y arrastrar y encajar objetos.
