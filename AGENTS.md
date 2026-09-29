# Instrucciones para agentes — Proyecto biotecnología

Actualizado: 23 de septiembre de 2026.

## Propósito y fuentes de verdad

Desarrollar por incrementos, en Godot 4.7.2, un juego sobre un laboratorio de pueblo que crece hasta convertirse en una corporación biotecnológica. El usuario (Mario) no tiene experiencia previa en desarrollo: explicar en lenguaje sencillo qué se hace, cómo abrirlo y cómo comprobarlo.

Orden de lectura y precedencia:

1. **Instrucciones actuales del usuario.** Prevalecen sobre cualquier documento.
2. **`GAME_DESIGN.md`** — visión y diseño vigentes. Manda sobre cualquier descripción anterior de mecánicas.
3. **Este archivo** — cómo trabajar, reglas técnicas y estado real.
4. **`docs/decisions/`** — registros técnicos. **010** (mundo de píxel exacto), **011** (suelo por teselas), **012** (migración a Godot 4.7.2), **013** (mapa del pueblo pintado a mano con GridMap) y **014** (parcela del laboratorio y cámara que sigue) están vigentes y contienen mediciones que no hay que repetir ni contradecir sin evidencia nueva. **001–009** describen el prototipo de pedidos ya retirado: son historia, no reflejan el código actual.

Documentos desactualizados: `Readme.me` describe todavía el bucle de pedidos, Godot 4.6.2 y referencias visuales antiguas; no usarlo como fuente hasta sincronizarlo. `DEVELOPMENT_PLAN.md` lo retiró el usuario el 23 de septiembre; su contenido (hitos H0–H14 e historial) sigue en Git: `git show 338cb3e:DEVELOPMENT_PLAN.md`. No recrearlo sin que el usuario lo pida.

Distinguir siempre: decisión de diseño, propuesta, implementación existente y verificación realizada.

## El juego que construimos

Resumen de `GAME_DESIGN.md`; ante cualquier duda, leer el original.

- Un protagonista que llega de fuera abre un pequeño laboratorio en un pueblo y lo convierte en una corporación. Tono acogedor con humor negro y una deriva gradual hacia lo inquietante. La ruta responsable también debe poder prosperar.
- Bucle: **atender encargos → producir y ganar dinero → investigar y reinvertir → conseguir nuevas capacidades → acceder a problemas y oportunidades mayores.** Producción sostiene el negocio, investigación abre posibilidades, reinversión cambia el mundo de forma visible.
- Una tarea puede dar tres recompensas: **dinero, conocimiento y relación**.
- Ciencia real y coherente, con procedimientos abstraídos y tiempos comprimidos. Cada concepto científico incorporado debe aportar una decisión, una predicción o un descubrimiento. Ejecución accesible y arcade.
- Referencias de experiencia: Stardew Valley y Graveyard Keeper 2. Identidad propia.
- Control directo del personaje; la gestión ocurre interactuando con equipos y personas del mundo.

**Siguiente objetivo de diseño (`GAME_DESIGN.md` §9):** un primer tramo de escalada pequeño y completo — un producto conocido y rentable, una necesidad nueva de un cliente, una investigación breve relacionada, una compra que desbloquee una capacidad diferente y una oportunidad nueva que la use. Convertirlo en tareas pequeñas y observables antes de programar; consultar con el usuario el contenido concreto (productos, cliente, ciencia), porque el diseño lo deja abierto.

Fuera de alcance mientras no se decida lo contrario: combate, multijugador, trabajadores autónomos, varias instalaciones, un árbol grande de investigación, contenido masivo y simulación científica detallada. La escala corporativa orienta cada incremento; no se construye de una vez.

## Estado real del repositorio (23 de septiembre de 2026)

- **Escena principal:** `scenes/world/test_room.tscn` + `test_room.gd`. Es una **sala de muestra**, no una escena de juego: sirve para fijar cámara y densidad de téxel con arte real. Contiene suelo por teselas (césped, tierra, adoquín), muros de bloques en `MultiMeshInstance3D` que se funden al tapar al personaje, sol con sombras y el personaje.
- **Pueblo pintable:** `scenes/world/village.tscn` + `village.gd` (hereda de `test_room.gd`). El suelo se pinta en el GridMap `Terreno`, los bloques en el GridMap `Bloques` y los objetos sueltos (escenas `VillageProp` de `scenes/village/props/`) cuelgan de `Objetos`. En el editor se ve el suelo final; en el juego los GridMap se ocultan y se convierten en el suelo y los muros de siempre. No es la escena principal: se prueba con F6. Guías para el usuario en `docs/guias/`. Límite en la decisión 013: los objetos sueltos no se funden. Primer objeto con arte propio: `farola.tscn` (24 de septiembre; modelo de PixMesh con el poste alargado a 48 téxeles, 3 casillas, fuentes y `.blend` para Pixel Art Studio en `assets/source/props/street_lamp/`; con 64 salía 3,4 veces más alta que el personaje). Va a **16 téxeles por unidad** (2 px por téxel), no a 32 como los bloques; el personaje, con `pixel_size` 0,0375, sale a 1,2 px por téxel; usa `centrar_por_la_base` por el brazo. Un `.obj` con varias líneas `o` sale en Godot con una superficie por pieza: juntarlas en un solo objeto. **Valla de hierro** (28 de septiembre): `metal_fence.tscn` + `village_fence.gd` (`VillageFence`), valla que **se une sola**: suelta es solo el poste (32 téxeles de alto, 1 casilla) y a cada lado con otra valla del mismo padre en la casilla de al lado (en X o Z) le sale un tramo que llega justo al borde, donde empieza el de la vecina; dos juntas forman un paño de 64 × 32. Los tramos y su colisión son nodos internos creados al entrar en el árbol: no cuentan en la caja (huella 1 × 1) ni se guardan en `village.tscn`. El script no nombra su propia clase (grupo y `call()`): con esa referencia, Godot 4.7.2 dejaba scripts sin liberar al salir de las pruebas. Piezas **provisionales** de `tools/build_fence.gd` con los 7 colores de la exportación de PixZels (85 × 70, no se usa: reducida a 32 se rompía); cómo cambiarlas por piezas de PixZels en `assets/source/props/metal_fence/LEEME.md`. No está colocada en el pueblo. **Casa del laboratorio viejo** (28 de septiembre): `laboratorio_viejo.tscn`, `VillageProp` con el `.obj` de vóxeles de Mario (256 × 192 × 128, ya en unidades: se importa a escala 1, sin LOD ni compresión de malla), a 32 téxeles por unidad: 8 × 6 × 4 casillas, huella 8 × 4, colisión de caja entera. El `.obj` llegó sin su atlas; `tools/build_old_lab_atlas.gd` lo rehace copiando a cada cara el píxel de su vista en `casa_pixzels_ortho.png` (medido: todos los téxeles de las caras caen en píxeles opacos de su vista) y falla si sale un color fuera de `casa_laboratorio.gpl`. Detalle en `assets/source/props/old_laboratory/LEEME.md`. No está colocada en el pueblo y, como todo objeto suelto, no se funde si tapa al personaje. **`test_village_map.gd` falla en 4 comprobaciones de muros desde que `village.tscn` tiene bloques pintados** (la prueba supone que empieza vacío): pendiente de arreglar la prueba.
- **Árboles con viento (24–27 de septiembre):** `scenes/village/props/arbol.tscn` (frondoso, 137×185) y `abeto.tscn` (122×234), escenas `VillageTree` (`village_tree.gd`, hereda de `VillageProp`) con un quad vertical que dibuja `assets/game/shaders/tree_sway.gdshader` a partir de las dos capas de Mario (copa y tronco en `assets/game/textures/tree_*` y `fir_*`; fuentes en `assets/source/props/tree/` y `fir/`; las ramas visibles entre las hojas van en la capa del tronco). El código está en `tree_sway.gdshaderinc`; cada árbol cambia sus valores en su material (`tree_pixel.tres`, `fir_pixel.tres`: rectángulo, copa, viento; el abeto con racimos alargados, `rustle_size` 16×5, y más movimiento vertical, `rustle_axes`). A 1 px por téxel. Cada píxel lee un téxel entero desplazado téxeles enteros: flexión del árbol entero (crece con la altura al cuadrado), agitación de racimos de la copa con una onda que la cruza a favor del viento (asoman las ramas) y destellos de un tono al siguiente de la copa; rachas con la misma onda y valores que la hierba; tiempo a saltos de 0,1 s. Los destellos copian el color de un téxel de la propia copa (`lit_texel_*`): convertido a mano, la tarjeta lo decodificaba una unidad distinto (457 píxeles fuera de paleta en 40 fotogramas del abeto). El quad se rehace desde su UV en el shader, así que no gira ni se deforma aunque se gire la raíz. **Proyecta sombra pero no la recibe** (`shadows_disabled`): recibiéndola se salpicaba de su propia penumbra. Medido con ventana: sin viento, todos los téxeles con su color (14 343 de 14 343 y, en el abeto, 12 689 de 12 697: los 8 restantes, tapados por un muro de delante); con viento, ningún color nuevo en los árboles (solo penumbras de su sombra en el suelo). `VillageProp.huella_fija` = 1×1: solo el tronco ocupa casilla y choca. **Copa que tapa (27 de septiembre):** `village.gd` (`_fundir_copas`, con `player_screen_box` de `test_room.gd`) funde la copa si un téxel opaco suyo cae sobre el personaje y el árbol está delante, en `occluder_fade_time`, hasta `opacidad_al_tapar` (0,35, por árbol). Como los muros: una copia translúcida creada al arrancar (`Modelo/Fundido`, `tree_sway_faded.gdshader`, mezcla de verdad) y el `Lienzo` solo en el mapa de sombras mientras dura; el tronco y las ramas siguen opacos. Busca los árboles en todo el pueblo, no solo en `Objetos`.
- **Plantas (29 de septiembre):** 53 escenas `VillageProp` en `scenes/village/props/plantas/` (14 arbustos, 10 hierbas, 18 flores y matas, 11 setas y rocas), generadas por `tools/build_plants.gd` desde `assets/source/props/plantas/plantas.json`; no retocarlas a mano. Texturas: los recortes de la versión `paleta_casa` de Mario, sin tocar, en `assets/game/textures/plantas/`; la versión `original` (92 colores, fuera de paleta) se guarda solo como referencia. Un material por planta en `assets/game/materials/plantas/` con `assets/game/shaders/plant_sway.gdshader`: quad rehecho desde su UV como el árbol, 1 px por téxel, solo la flexión del árbol (filas desplazadas téxeles enteros, más arriba más) con las rachas de la hierba; setas y rocas quietas. Proyecta sombra y no la recibe. Arbustos y rocas grandes chocan y ocupan las casillas de su ancho; lo demás es `atravesable` (opción nueva de `VillageProp`: sin colisión y sin aviso). Medido con ventana: con viento ningún color nuevo en las plantas (45–82 píxeles nuevos por captura, todos en el borde de sombras que se mueven). Sus tres amarillos (`#d99a1c`, `#f0c832`, `#f7e27a`) entraron en la paleta como Amarillo 1–3. No se funden al tapar al personaje, la hierba del suelo no las evita y ninguna está colocada en el pueblo. Detalle en `assets/source/props/plantas/LEEME.md`.
- **Parcela del laboratorio (decisión 014):** GridMap `Parcela` (dónde se pueden poner muebles) y `Node3D` `Muebles` (muebles iniciales puestos a mano). `village.gd` los registra en `layout: PlotLayout` (`scripts/domain/plot_layout.gd`, reglas de colocar, mover y quitar sin escena) y avisa en el editor de lo que no cuadra. Cada mueble es una `PlaceableDefinition` (`resources/definitions/placeables/`) que debe estar en el `catalog` de Pueblo. En el pueblo la cámara sigue al personaje a píxel exacto (`follow_player`); en la sala de pruebas no. **No hay todavía modo construir**, dinero, inventario ni guardado: `layout` es la base para ellos. Lo que se construye es solo dentro de la parcela, a ras de suelo; no se edita el terreno del mapa.
- **Hierba:** `test_room.gd` (`_build_grass`, grupo «Hierba» del inspector) planta matas en las celdas de césped sin muro, en una `MultiMeshInstance3D` con `assets/game/shaders/grass_tuft.gdshader`: viento y empuje del personaje, con desplazamiento redondeado a píxel entero. Reparto en `scripts/presentation/grass_scatter.gd` (70 % en manchas, 30 % suelto, semilla fija). La hoja `assets/game/textures/grass_tufts.png` es **provisional** (`tools/build_grass_tufts.gd`; cuatro matas de 16×16, dos bajas y dos altas; Verde 2, 3 y 5 de `apollo_proyecto.gpl`, elegidos por Mario el 29 de septiembre). El suelo usa los rellenos de 128 de `assets/source/tilesets/ground/` que existan (césped y tierra desde el 23 de septiembre; el 29 se pasaron a la paleta del proyecto, el césped con un relleno nuevo de Mario) y, para los demás, su `*_top.png` repetido. En el pueblo la hierba todavía no evita objetos sueltos ni muebles.
- **Agua (24 de septiembre):** se pinta en el GridMap `Terreno` con el marcador `water` (id fijo 100 en `paint_terrain.meshlib.tres`, `WaterSurface.ITEM`); en la sala, `water_patches` (vacío por defecto: `test_ground_mesh` cuenta una tesela por vértice). No es un terreno de `GroundAtlas`. `scripts/presentation/water_surface.gd` dibuja una **máscara de orilla** a téxel (`shore_mask`: casillas cuadradas → esquinas de fuera y de dentro redondeadas con radio `min(32, medio lado)` → ondulación de ±3 px con el ruido de `ground_silhouette.gd`). Las teselas del suelo que tocan agua salen de `Ground` (`_shore_tiles`, con la UV elegida como siempre y las esquinas mojadas copiando el terreno seco, `_dry_corners`) y las dibuja la orilla con `assets/game/shaders/water_shore.gdshader`, que descarta los téxeles de agua y sale idéntica a `ground_pixel.tres` (medido: con y sin estanque solo cambian los píxeles del agua y su escalón). Debajo va la lámina, hundida `water_depth_texels` px (6), con `water_pixel.gdshader` (adaptado del entregado, original en `assets/source/tilesets/water/`: con luz y leído por téxel de mundo), que además pinta el escalón de tierra siguiendo la curva: mira si el rayo de la cámara toca tierra antes de llegar al agua. **Agua quieta** (decisión del usuario, 24 de septiembre): la textura se separa por sus cinco colores (`WaterSurface.PALETTE`; el shader los lee de téxeles de la propia textura, `tone_*`, porque la conversión sRGB de la tarjeta difiere en una unidad de la de Godot); el fondo no viaja, solo se balancea ±1 px por filas; dos capas de ondas derivan despacio (`water_ripple_speed`, 0,6 px/s) y se encienden y apagan a trozos; destellos en cruz en puntos fijos; espuma de 1 px a trozos en todo el contorno visible y dos filas un tono más oscuras bajo el escalón. Tiempo a saltos de 1/8 s. Desde el 29 de septiembre, onda y destello son Azul 5 y Azul 6 de `apollo_proyecto.gpl` (antes `#6ea4b4` y `#aad0d2`); sin medir en pantalla tras el cambio. Medido antes: el agua en pantalla usa los mismos colores que antes del cambio. Las dos leen la máscara con `shore_mask.gdshaderinc`. Cajas de colisión por casilla (`WaterBodies`), no por curva; sin hierba ni muebles encima. Escalón siempre de tierra: provisional hasta que haya arte de orilla.
- **Bloques de césped:** `grass` y `summer_grass` (atlas de PixZels en `assets/game/tilesets/`, materiales `village_pixel.tres` y `summer_grass_pixel.tres`). El bloque de pradera (`grass_meadow`) y `tools/build_grass_variant.gd` se retiraron el 23 de septiembre. En `build_paint_library.gd` el id de cada bloque es su posición en `BLOQUES`: añadir siempre al final.
- **Personaje:** `scenes/player/` — `CharacterBody3D` + `AnimatedSprite3D`, reposo, andar y correr (acción `run`, Shift) en ocho direcciones a partir de cinco orientaciones con espejo. Movimiento relativo a la cámara con compensación de profundidad.
- **Dominio y presentación:** `scripts/domain/village_metrics.gd` (escala del mundo y compensación anisótropa), `scripts/domain/ground_atlas.gd` (selección de teselas del suelo), `scripts/presentation/display_mode.gd` (pantalla completa con F11 o Alt+Intro).
- **Herramientas de autoría:** `tools/` — `build_ground_atlas.gd` (sus siluetas salen de `scripts/presentation/ground_silhouette.gd`, que viaja con el juego porque el agua usa su ruido), `build_grass_tufts.gd`, `fix_block_atlas_orientation.gd`, `build_fence.gd` (piezas provisionales de la valla), `build_plants.gd` (escenas y materiales de las plantas), `build_paint_library.gd` (las tres `MeshLibrary` de pintura, `assets/game/tilesets/paint_*.meshlib.tres`: terreno, bloques y zonas; volver a ejecutarla si cambia el ángulo o se añade un bloque a su tabla `BLOQUES`). Se ejecutan con `--script`; no forman parte del juego exportado.
- **Retirado el 23 de septiembre:** todo el bucle de pedidos de H2–H4 (sesión de laboratorio, definiciones, economía, guardado, avisos y sus pruebas). Recuperable en Git (`0f65341`, `338cb3e`). Hoy **no hay** economía, UI de juego ni guardado. No resucitar esos scripts en bloque: las mecánicas nuevas se diseñan a partir de `GAME_DESIGN.md`; el historial puede consultarse como referencia de patrones (por ejemplo, escritura atómica de partidas).
- **Exportación:** preset «Windows Desktop» en `export_presets.cfg`, con plantillas oficiales. Las plantillas de 4.7.2 **no están instaladas** todavía (Editor → Gestionar plantillas de exportación). Ningún ejecutable de 4.7.2 ha sido exportado ni probado.

## Motor: Godot 4.7.2

- Versión verificada: `4.7.2.stable.official.ed1daf0bf`. Ejecutables en `C:\Users\mario\Desktop\Godot\` (`Godot_v4.7.2-stable_win64.exe`, `…_console.exe` para la terminal, y `godot.cmd`). No están en el `PATH`: usar la ruta completa.
- Renderizador **Forward+** (decisión 011) sobre **Direct3D 12** en Windows (`rendering_device/driver.windows="d3d12"`). Física **Jolt** (`physics/3d/physics_engine="Jolt Physics"`). Migración y mediciones en la decisión 012.
- El editor elimina de `project.godot` las claves que coinciden con el valor por defecto, así que la ausencia de `rendering_method` no significa que falte: la guarda comprueba el valor efectivo.
- Consultar la documentación de 4.7 (`https://docs.godotengine.org/en/4.7/`) y su [guía de migración](https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html) al usar APIs. No copiar ejemplos de Godot 3 ni de `latest` sin comprobar que existen en 4.7.
- No cambiar de versión menor sin acuerdo. Una versión de parche (4.7.x) se puede adoptar tras pasar las pruebas y la guarda de píxel.

### Cambios de 4.7 que afectan al código

- Teclado y ratón informan `device = InputEvent.DEVICE_ID_KEYBOARD` (16) y `DEVICE_ID_MOUSE` (32), no 0. No comparar `event.device == 0`; en pruebas que fabriquen `InputEventKey` a mano, poner el identificador nuevo.
- Una sobrescritura sin tipo de retorno hereda el del método padre; devolver algo incompatible es error de compilación.
- Escribir un elemento de una propiedad `Packed*Array` (`prop[i] = x`) ya no llama al *setter* de la propiedad. Reasignar el array entero si hace falta que salte.
- `AudioStreamPlayer.area_mask` pasa a 0 por defecto; el *hinting* de fuentes importadas pasa a 3. Para fuentes pixel art, fijar `hinting` a *None* y desactivar el antialiasing de la fuente en su importación.
- No existen en 4.7, aunque se lean en foros: *traits* de GDScript, ni un modo de cámara estable o *pixel snapping* 3D. No suponerlos.

### Novedades de 4.7 que conviene aprovechar

Usarlas cuando la tarea las pida, no por rutina; cada una debe pasar la guarda de píxel.

| Novedad | Para qué nos sirve | Condición |
|---|---|---|
| **Editor de `MeshLibrary`** con rejilla, búsqueda, zoom y deshacer | Autorar bloques, muebles y máquinas modulares para `GridMap` cuando llegue la construcción | El suelo sigue siendo la `ArrayMesh` de la decisión 011 |
| **Ajuste a vértice en 3D** (mantener B) | Alinear piezas modulares en el editor | Solo autoría |
| **`AreaLight3D`** (luz rectangular con sombras suaves PCSS) | Fluorescentes y paneles del laboratorio, ventanas | Encarece todos los objetos en pantalla mientras hay una visible; medir colores fuera de paleta y coste antes de adoptarla |
| **Escalado 3D *nearest*** (`rendering/scaling_3d/mode`, `SCALING_3D_MODE_NEAREST`, escala 1/n) | Renderizar el mundo por debajo de 960×540 con la UI nítida, si algún día hace falta rendimiento o más píxel | Hoy no se usa: el mundo ya es 1:1 a 32 téxeles por unidad y cambiarlo rompe `VillageMetrics` |
| **`Tween.tween_await(signal)`** y `Tween.has_tweeners()` | Secuencias de diálogo, entregas o pequeñas escenas sin corrutinas sueltas | — |
| **`Control.offset_transform_*`** | Animar botones, avisos o tarjetas (rebote, escala) sin descolocar contenedores | — |
| **`Control.custom_maximum_size`** | Limitar paneles de texto y bocadillos | — |
| **`TextureRect` con `AtlasTexture` en mosaico**, `[img height=1em]` en `RichTextLabel` | Iconos de productos e insumos dentro del texto de la UI | Filtrado *nearest* en la UI |
| **`DrawableTexture2D`** | Superficies que se ensucian o se marcan (manchas, derrames) | Sin filtrado lineal |
| Correcciones de 4.7.1/4.7.2: sombras direccionales con cámara ortográfica, parpadeo de luz en mallas escaladas de forma no uniforme | Justo nuestro caso (cámara ortográfica y bloques con escala anisótropa) | Ya incluidas |

## Dirección visual y reglas de píxel exacto

Referencias de apariencia (`GAME_DESIGN.md` §11): [Graveyard Keeper 2](https://store.steampowered.com/app/4358690/Graveyard_Keeper_2/) para legibilidad de personajes, objetos y espacios habitados; [SacriFire](https://store.steampowered.com/app/1661330/SacriFire/?l=spanish) para personajes pixel art integrados en entornos 3D con profundidad e iluminación; [Graytail](https://store.steampowered.com/app/2888960/Graytail/) para encuadre elevado, volumen y atmósfera que puede volverse inquietante. Guían la apariencia; no definen mecánicas.

Dirección: mundo 3D de bloques, escenarios y máquinas con texturas pixel art, personajes 2D dentro del mundo y cámara elevada. Acogedor al comienzo; iluminación y detalle acompañan la evolución narrativa. Colores e iluminación alegres.

Reglas vigentes, medidas en las decisiones 010 y 011 — no relajarlas sin medir:

- **1 unidad de mundo = 32 téxeles** (`VillageMetrics.TEXEL`). Todo el arte se dibuja a esa densidad.
- **Compensación anisótropa:** la geometría se estira en Y por `1/cos(p)` y en Z por `1/sin(p)` para que cada cara visible mida exactamente 32 px con la cámara ortográfica inclinada `p` (55° hoy). Usar siempre `VillageMetrics`; no poner escalas a mano. Está calculada para una cámara que mira a lo largo de −Z.
- **Cámara:** `Camera3D` ortográfica, orientación fija, puede seguir al personaje. El posible giro de cámara está **pendiente de decisión** (`GAME_DESIGN.md` §12); no implementarlo sin acuerdo, y tener en cuenta que un giro obliga a rehacer la compensación anisótropa.
- **Imagen interna 960×540**, `stretch/mode="viewport"`, `scale_mode="integer"`: x2 en 1080p, x4 en 4K.
- **Texturas de juego:** importación sin compresión VRAM (`compress/mode=0`), sin mipmaps y con `detect_3d/compress_to=0`. Filtrado *nearest* en el **material** (en Godot 4 no vive en el importador). Sin padding en el atlas de suelo: si alguien activa mipmaps, el padding pasa a ser obligatorio.
- **Sin antialiasing** de ningún tipo (MSAA, FXAA, SMAA, TAA) ni desenfoques: inventan colores fuera de paleta o arrastran píxeles entre fotogramas.
- **Sombras:** `shadow_bias = 0.05`, `shadow_normal_bias = 2.0` evitan el acné en los muros; el suelo no proyecta sombra (`cast_shadow = OFF`).
- **Luz (23 de septiembre):** sol `light_energy = 2.0`, ambiente `ambient_light_energy = 0.54`, iguales en `test_room.tscn` y `village.tscn`. El sol entra bajo y al suelo solo le llega ~35 % de su energía; con estas cifras el césped al sol sale con el color de su textura (medido 114,164,86 frente a `#78a44b`) y las caras de los muros no se queman. Con 0,57 / 0,31 el mundo salía a la mitad de brillo. Si se cambia el ángulo del sol, recalcular.
- **Profundidad del sprite:** no desactivar la prueba de profundidad para ocultar problemas de orden de dibujo; resolver recortes y z-fighting en su causa.
- **Paredes que tapan:** fundido de opacidad del muro que cubre al personaje (`occluder_opacity`, `occluder_fade_time`, `occluder_margin_cells` en `test_room.gd`).

## Arte y assets

El usuario produce el arte. No modificar sprites, escala, animaciones ni materiales del personaje, ni texturas pintadas, salvo petición expresa. Los agentes preparan integración, herramientas y comprobaciones.

- **Paleta:** `assets/source/palettes/apollo_proyecto.gpl` — Apollo (46 colores) + 12 propios, 58 en total (los tres últimos, Amarillo 1–3, añadidos el 29 de septiembre para las flores amarillas), más el negro `#000000` del contorno como excepción provisional. Toda textura pintada o generada (bloques, suelo, hierba, agua, sprites) usa solo esos colores, y los generadores de `tools/` tampoco pueden inventarlos. La paleta se cumple en las texturas, no en la imagen final: la luz del motor crea tonos intermedios y eso es correcto. No añadir colores sin acuerdo del usuario.

- **Bloques de PixZels:** llegan primero a `C:\Users\mario\Documents\Game!\assets\blocks`, fuera del repositorio y con nombres distintos (`*_model_atlas.png` allí, `<bloque>_block_atlas.png` aquí). Fuentes editables a `assets/source/tilesets/<bloque>/`, atlas de juego a `assets/game/tilesets/`, y pasar `tools/fix_block_atlas_orientation.gd` (PixZels hornea la cara superior rotada).
- **Suelo:** el usuario dibuja solo los rellenos por terreno; las 16 transiciones por pareja se generan con `tools/build_ground_atlas.gd`. Precedencia `GRASS < DIRT < COBBLESTONE`; la identidad que se guarda es el `StringName`, nunca el entero.
- **Modelos 3D:** Blender o PixZels → `.glb`/`.obj` → escena Godot propia que añade colisión e interacción, para no perder cambios al reimportar.
- Conservar fuentes editables, archivos Aseprite y `ATTRIBUTION.md`. No construir importadores propios si el editor de `SpriteFrames` o de `TileSet` basta.

## Arquitectura

- GDScript **tipado** en todo el código nuevo; `snake_case` para funciones y variables, `PascalCase` para clases, `UPPER_SNAKE_CASE` para constantes. Mantener el idioma y la densidad de comentarios del archivo que se edita (los comentarios explican el porqué y citan la medición o decisión que lo sostiene).
- Separar reglas de juego (producción, economía, investigación, relaciones) de la UI y de la representación del mundo. Las reglas deben poder probarse sin escena.
- Datos de contenido (productos, recetas, equipos, encargos, investigaciones) como `Resource` con **IDs estables** (`StringName`); estado mutable separado de las definiciones.
- Mundo: `Node3D`, `MeshInstance3D`/`MultiMeshInstance3D`, `StaticBody3D`, `CollisionShape3D`. Jugador: `CharacterBody3D` + `AnimatedSprite3D`. Interacción: `Area3D` y, si hace falta, línea de visión. UI: `Control`/`CanvasLayer`.
- Movimiento en el plano XZ, Y es altura, entradas relativas a la cámara. Acciones siempre por Input Map (`move_*`, `interact`, `run`, `toggle_fullscreen`).
- `TileMapLayer`, `CharacterBody2D` y `Camera2D` no son base del mundo. El **recurso** `TileSet` sí es legal para autorar mapas y leer sus bits de terreno desde un script. `GridMap` se usa como herramienta de autoría (decisión 013): lienzo de terreno que un script lee y bloques que en el juego pasan a `MultiMeshInstance3D`. No dibuja el suelo (decisión 011) y no se deja visible en el juego. Los objetos con colisión o lógica son escenas `VillageProp`, no ítems de GridMap; tampoco los muebles y las máquinas, porque un ítem no tiene script ni huella de varias casillas y girarlo deforma el píxel (revisión en la decisión 014). Lo que ocupa cada casilla de la parcela lo lleva `PlotLayout`.
- La cámara solo se desplaza, nunca gira. Lo que compare posiciones en pantalla usa `VillageMetrics.screen_point`, que no depende de dónde esté la cámara, en vez de `unproject_position`.
- Escenas pequeñas y composición. Sin `GameManager` monolítico ni bus global de eventos; autoloads solo ante una necesidad compartida clara (por ejemplo, el guardado cuando exista).
- Carpetas, creadas solo cuando hagan falta: `scenes/{world,player,lab,village,ui}`, `scripts/{domain,systems,persistence,presentation}`, `resources/definitions`, `assets/source`, `assets/game/{models,textures,tilesets,materials,player,audio}`, `docs/decisions`, `tests`, `tools`.

## Mecánicas nuevas

- Una tarea observable cada vez. Cada mecánica debe aportar una decisión al jugador o reforzar el bucle de `GAME_DESIGN.md` §3.
- Respetar los criterios de diversión del diseño: pocas variables legibles, resultados visuales claros, fallos que informan, esperas durante las que se puede hacer otra cosa, automatización gradual de lo dominado y explicaciones científicas opcionales.
- La progresión se ve en el mundo: mesas que se llenan de instrumental, espacios recuperados, personal y presencia en el pueblo.
- Resolver solo las decisiones rutinarias y reversibles. Consultar al usuario cambios de dirección, contenido científico o narrativo concreto, gastos y cualquier cosa difícil de revertir.

## Persistencia

Hoy no hay guardado. Cuando vuelva:

- Datos en `user://`, nunca en `res://`; JSON con `schema_version` e IDs estables. Dinero entero.
- Validar cantidades, saldo e insumos antes de confirmar una operación; no duplicar consumos ni cobros.
- Escritura temporal, verificación y reemplazo con copia `.bak`. Un archivo corrupto nunca se sobrescribe automáticamente con una partida vacía.
- Sin producción offline; la pausa no avanza tiempo de juego.
- Usar un archivo nuevo: en este equipo puede existir `user://lab_save.json` del prototipo retirado; no leerlo ni borrarlo sin avisar.
- Las pruebas usan rutas aisladas; nunca tocar la partida real.

## Plugins y dependencias

Prioridad: funcionalidad nativa de 4.7 → plugin gratuito, mantenido y compatible con 4.7 → código propio pequeño. No añadir una dependencia por ahorrar unas líneas. Antes de adoptarla, verificar fuente oficial, licencia, versión o commit, compatibilidad real con 4.7 y mantenimiento, y registrarlo en `docs/DEPENDENCIES.md` (crearlo con la primera). Distinguir herramientas de autoría de plugins que viajan con el juego. No instalar herramientas de pago ni activar servicios facturados sin autorización.

## Verificación y entrega

```bash
G="/c/Users/mario/Desktop/Godot/Godot_v4.7.2-stable_win64_console.exe"
"$G" --version
"$G" --headless --path . --editor --quit        # importa y detecta errores de carga
"$G" --headless --path . --quit-after 5          # arranca la escena principal
for t in tests/test_*.gd; do "$G" --headless --path . --script "$t"; done
```

- `tests/test_pixel_settings_guard.gd` es la guarda de importación, materiales y antialiasing. Revisa los materiales de `assets/game/materials/` con sus subcarpetas. **Ejecutarla siempre**, aunque no se toque el arte.
- `tests/test_village_map.gd` ata el pueblo pintable: bibliotecas, lectura de GridMap, muros por material, colisión, `VillageProp`, la farola, la valla que se une, parcela y muebles, y cámara que sigue (píxel entero, límites, fundido lejos del origen).
- `tests/test_plot_layout.gd` ata las reglas de la parcela sin escena: huellas giradas, colocar, mover, quitar, guardar y cargar. En `--headless` puede terminar con `ERROR: Parameter "material" is null` del servidor de render vacío; con ventana no sale.
- `tests/test_water.gd` ata el agua: que el suelo cede a la orilla justo las teselas que tocan agua, la forma de la máscara (casilla suelta redonda, radio de las esquinas, esquinas de dentro, diagonales separadas, sin escalones entre teselas, sin agua en teselas secas), lámina y orilla a píxel entero, que no se entra andando y que el pueblo lee el agua pintada.
- `tests/test_tree.gd` ata los dos árboles: quad del tamaño del rectángulo del shader, bordes entre píxeles con la raíz bajo el pie del tronco, margen para lo que viaja la copa, téxeles de destello de la copa, que no recibe sombra, que solo el tronco ocupa casilla, que `tapa()` sigue la silueta de la copa, que al fundirse la sombra sigue, y en el pueblo que la copa se funde con el personaje detrás y no delante.
- `tests/test_plants.gd` ata las plantas: una escena por ficha, quad del tamaño del rectángulo del shader, rectángulo centrado en el pie con margen para lo que viaja la punta, pie a ras de suelo, colisión solo en lo que estorba y dentro de su huella, y dibujos sin semitransparencias ni colores fuera de paleta.
- `tests/test_old_lab.gd` ata la casa del laboratorio viejo: medidas y huella (también girada), colisión, vértices en téxel entero y atlas solo con colores de su `.gpl`.
- `tests/test_grass_scatter.gd` ata el reparto de hierba (fracción en manchas, márgenes, determinismo) y que la sala solo la planta en césped libre, con el pie en píxel entero.
- `tests/test_ground_mesh.gd`, `test_ground_texel.gd` y `test_ground_walk.gd` atan el suelo. El aviso de «2 teselas con tres terrenos degradadas» es esperado: la muestra lo provoca a propósito y el número está fijado en la prueba.
- `tests/capture_ground.gd` y `tests/capture_player_animation.gd` generan capturas para revisión visual; necesitan ventana, no `--headless`.
- Cada mecánica nueva llega con su prueba headless de reglas (`extends SceneTree`, `PASS`/`FAIL` y línea `RESULTADO`, código de salida distinto de cero si falla), siguiendo el estilo de las existentes.
- El arranque headless no valida el aspecto. Para cambios visuales, revisar cámara, pies del sprite, profundidad delante y detrás de objetos, muros que tapan, colisiones y pantalla completa.

Cerrar cada tarea con: cambios hechos, comprobaciones ejecutadas con su resultado y limitaciones. Nunca presentar como realizada una prueba manual o una exportación que no se ha hecho.

Git: la rama de trabajo actual es `prototype/h1-laboratory`. No versionar `.godot/`, `builds/`, `.local/`, secretos ni partidas; conservar los `.uid`. No hacer commits, pushes ni cambios destructivos sobre trabajo ajeno sin que el usuario lo pida. `.local/` contiene scripts de sondeo desechables de sesiones anteriores: no son parte del proyecto.
