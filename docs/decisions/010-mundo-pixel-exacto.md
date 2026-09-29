# Mundo de píxel exacto, iluminación y control

19 de septiembre de 2026. Petición: rehacer el apartado gráfico con el estilo de
Core Keeper, partiendo de un pueblo con casas y no de cuevas.

## Corrección de partida

Afirmé que Core Keeper era un juego 2D puro y propuse migrar a `TileMapLayer`,
`CharacterBody2D` y luces 2D. **El usuario me corrigió y tenía razón.** Core
Keeper es un juego 3D que parece 2D: las paredes son modelos 3D y los personajes
son sprites 2D dentro de ese espacio. Fuente: mensajes de jugadores en los foros
de Steam, no una declaración de Pugstorm. Coherente con lo observable —al doblar
una esquina con una antorcha las sombras se alinean con la posición de la luz,
que es proyección real y no un degradado radial.

Consecuencia: **la arquitectura del proyecto ya era la correcta**. No hubo
migración. Lo que faltaba era la iluminación y un kit modular.

## Anclaje de téxel

**1 unidad de mundo = 32 téxeles.** De ahí salen `VillageMetrics.TEXEL`
(0,03125), el `scale_mesh` de cada `.obj` de PixZels y el `pixel_size` del
personaje. La constante la fijó el usuario junto con su tabla de proporciones.

## Compensación anisótropa: el hallazgo principal

Con una cámara ortográfica inclinada un ángulo *p*, la proyección comprime el
suelo por sen(*p*) y las caras verticales por cos(*p*); el eje X no se toca.
**Ningún ángulo deja las dos sin comprimir**: no existe solución entera de
32·sen(*p*) y 32·cos(*p*) a la vez. A 55° una cara lateral perdía 14 de sus 32
filas de téxeles y el suelo 6 de 32, y por eso el `.obj` se veía menos nítido
que su atlas.

La solución no fue buscar el ángulo bueno, sino **estirar la geometría en mundo
exactamente lo que la proyección va a comprimir**:

```
escala de celda = (1,  1/cos(p),  1/sin(p))     a 55° = (1, 1,7434, 1,2208)
```

Medido tras el cambio, en todos los ángulos probados (45°, 55°, 65°, 75°):
ancho de celda 32,00 px, cara superior 32,00 px, cara vertical 32,00 px. Una
cara de muro comparada téxel a téxel contra `grass_side.png` con material sin
luz difiere como mucho **4 de 255**, que es el redondeo sRGB del framebuffer y
no remuestreo.

**Efecto secundario que hay que conocer:** la celda deja de ser cúbica en
unidades de mundo y **el ángulo de cámara pasa a ser irrelevante**. Renders a
45°, 50°, 60° y 65° comparados contra 55° difieren solo en un 1,7–3,1 % de
píxeles, y ese resto son las sombras del sol. La proyección ha quedado fija en
1 celda de techo + 1 celda de fachada por bloque, 64 px de alto. Para cambiar
esa proporción hay que tocar el arte o la compensación, no la cámara. Se deja
la inclinación en **55°** por continuidad y se ajusta el aspecto con la
dirección del sol.

## Ruido de píxel: era acné de sombra

Una zona de suelo renderizaba **221 colores** donde su textura tiene 9. Aislado
apagando cosas de una en una: con `shadow_enabled = false` bajaba a 9 exactos,
igual que con el sol apagado o con material sin luz. Era auto-sombreado.

El mando que importa es `shadow_normal_bias`, no `shadow_bias`: con normal_bias
a 0 ni subiendo el bias a 0,15 se limpiaba (513 colores). Valores elegidos
**0,05 / 2,0**, que devuelven los 9 colores exactos y encogen la sombra
proyectada real solo un 0,6 % (11 509 → 11 436 px).

## GL Compatibility: la prueba que condicionaba el diseño

El plan exigía medir esto antes de construir el kit. Resultado:

| Pregunta | Respuesta medida |
|---|---|
| ¿`OmniLight3D` proyecta sombras? | **Sí.** 98 028 píxeles claramente más oscuros al activarlas |
| ¿Cuántas luces con sombra a la vez? | **8 comprobadas**, todas proyectando |
| ¿Límite de luces por objeto? | **8 exactos.** La novena aporta 0,0000 |
| ¿Se puede subir? | **Sí.** Con `rendering/limits/opengl/max_lights_per_object=16` las luces 9–14 vuelven a aportar |

Se deja en el valor por defecto de 8, que para un pueblo sobra. Subirlo encarece
el sombreador de todos los objetos, así que es una palanca a usar solo con una
necesidad concreta. **No hay que pasar a Forward+.**

## Orientación del atlas de PixZels

PixZels empaqueta las seis vistas del bloque cada una con un giro distinto y lo
compensa en las UV del `.obj`. En el bloque de césped la cara superior quedaba
girada 180°, así que el dibujo salía del revés sobre el mapa. Comprobado
comparando el suelo renderizado contra `grass_top.png` en las ocho orientaciones
posibles: el giro de 180° daba 0 téxeles fuera de 1024.

Corregido en el archivo de juego, nunca en `assets/source/`. La herramienta
[`tools/fix_block_atlas_orientation.gd`](../../tools/fix_block_atlas_orientation.gd)
lo repite tras cada reexportación; es idempotente y se niega a actuar si
encuentra cualquier desajuste que no sea exactamente 180°. **Con un solo bloque
exportado no hay evidencia de que PixZels lo haga siempre.**

## Personaje

Cambios autorizados expresamente por el usuario, sobre material que
`AGENTS.md:15` protege:

- **Tamaño ×2.** `pixel_size` 0,03125 → 0,0625. El dibujo mide 32 × 50 px (un
  bloque de ancho) y su lienzo 64 × 64 (dos de alto). La cápsula (radio 0,35) y
  el disco de sombra siguen al dibujo desde `test_room.gd`, sin tocar
  `player_3d.tscn`.
- **Correr con Shift.** Acción `run` nueva, quinta dependencia del Input Map del
  personaje, que antes eran cuatro. Velocidad ×1,8. Integrada la hoja
  `16x32 Run-Sheet.png` del paquete original, que llevaba sin usar desde el
  principio: 192 × 160, seis columnas. La cadencia se multiplica por lo mismo
  que la velocidad, de modo que el terreno por fotograma es idéntico al de andar
  (0,320 u medidos en ambas) y los pies no patinan.
- **Movimiento isótropo en pantalla.** La profundidad se estira por
  1/sen(inclinación), derivado de la propia cámara. Medido: 102,4 px/s en
  horizontal, vertical y diagonal; 184,3 px/s corriendo en las tres.
- **Compresión VRAM desactivada.** `idle.png` estaba en `compress/mode=2` con
  mipmaps y `walk.png` tenía `detect_3d/compress_to=1`, es decir, programada
  para comprimirse sola al primer uso en 3D. El personaje pasó de 22 a 15
  colores en pantalla, y 15 es el mínimo posible en ese recorte.

## Resolución

Viewport interno de 640×360 a **960×540**, cámara ortográfica **16,875**
derivada de `project.godot` en vez de escrita a mano. Se ve 2,25 veces más
mundo, los téxeles siguen exactos y el escalado entero da ×2 en Full HD y ×4 en
4K. Ventana por defecto 960×540.

## Regresiones heredadas del borrado, corregidas aquí

- `window/stretch/aspect="keep"`, que la [decisión 009](009-pantalla-completa-16-9.md)
  fijó de forma explícita, no estaba en el archivo. Restaurada.
- La acción `toggle_fullscreen` se quedó **sin nadie que la atendiera** al
  borrar `laboratory_3d.gd`: F11 y Alt+Intro no hacían nada. Vuelta a atender
  desde `test_room.gd`, que importa más ahora que la ventana es 960×540 y la
  pantalla completa es cómo se llega al ×2.

## Riesgo abierto

Los originales del paquete de Eris Esra, incluidos los `.aseprite`, están en
`Game!/assets/player/16x32/`, **fuera del repositorio y sin control de
versiones**, pese a que `AGENTS.md:45` pide conservarlos. Si esa carpeta se
pierde no se recuperan desde aquí.
