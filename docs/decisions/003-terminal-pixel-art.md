# H1.5 — Mesa con terminal y textura pixel art

Fecha: 16 de septiembre de 2026. Alcance: sustituir solo la representación del terminal por un modelo propio de Blender con UV y textura pixel art. El usuario confirma pixel art y considera terminado el personaje: sus archivos, proporciones, animaciones y ocho direcciones quedan intactos.

## Diseño

Mesa gris azulada, tablero claro con marco oscuro, cajonera y ordenador de carcasa marfil con pantalla verde. Una textura de 128×128, paleta limitada y detalles en bloques de píxeles. Geometría sencilla y plana; sin suavizado de textura. Las imágenes anteriores del PC/escritorio sirven de referencia visual, conservadas sin modificación.

La fuente editable será `assets/source/terminal/terminal.blend`, junto a un atlas SVG de rectángulos sobre cuadrícula y su PNG rasterizado. El juego recibe `assets/game/models/terminal.glb`. `terminal_3d.tscn` mantiene el Area3D, los colliders, el punto de interacción y el indicador flotante existente; el GLB solo aporta representación. No se escribirá sobre la escena importada.

## Pasos y comprobación

- Conservar copia de la escena actual y hashes del personaje.
- Crear atlas, malla y UV; guardar fuente y exportar GLB con el Blender 5.2.1 instalado.
- Importar en Godot 4.6.2 y envolver en la escena actual del terminal.
- Comprobar el aspecto en cámara y profundidad delante/detrás/laterales; ejecutar las pruebas actuales de interacción y colisiones.
- Cambiar un detalle visual pequeño en la fuente, reexportar e importar de nuevo; comprobar que colisiones, script e indicador permanecen y las pruebas siguen pasando.
- Registrar resultado real, comandos y limitaciones. H1 continúa hasta revisión manual y aceptación visual.

Sin nuevas dependencias de ejecución ni plugins. Las fuentes Blender quedan excluidas de importación por `.gdignore`; se distribuye el GLB.

## Resultado comprobado

- Blender **5.2.1 LTS** instalado y Godot **4.6.2.stable.official.71f334935**.
- Fuente `.blend` editable, 18 mallas y 216 triángulos, UV por cara y atlas 128×128 de paleta limitada. Fuente de textura en SVG con rectángulos alineados a píxeles; PNG generado por Godot. No se ha modificado ninguna imagen del personaje.
- `terminal_3d.tscn` instancia el GLB bajo `Model`; conserva el área 3,2×2×2,6, huella de colisión 2,1×1,1×1,1, punto de interacción e indicador flotante.
- Material externo nativo en `assets/game/materials/terminal_pixel.tres`, conectado mediante la configuración de importación del GLB: sin iluminación que cambie la paleta y nearest sin usar mipmaps. La primera importación conservaba nearest con mipmaps desde Blender; se corrigió la configuración en Godot para mantener los detalles más nítidos a la distancia de juego.
- Reexportación real: se amplió el piloto verde del monitor en el `.blend` y se guardó como revisión 2. Cambió el GLB y Godot recibió las nuevas dimensiones. Comparación de cuatro archivos de escena/script/indicador antes y después de reexportar: cero cambios.
- Suite actual, incluidas las pruebas del indicador añadido a la base: **56 comprobaciones, 0 fallos**, antes de sustituir el arte y tras ambas versiones importadas. Se verificaron movimiento, ocho direcciones, suelo/paredes/mesa/máquina, proximidad y obstrucción, panel e indicador.
- Capturas reales revisadas en OpenGL Compatibility: sala, delante/detrás y laterales de la mesa. El personaje queda oculto por el mueble cuando corresponde y el indicador funciona.
- Hashes de **33 archivos del personaje**, incluidos escenas, scripts, SpriteFrames, PNG y fuentes: sin modificaciones durante esta tarea.
- Revisión independiente de la integración sin otros defectos. Se detectó y resolvió un riesgo del flujo de texturas: la opción explícita `--refresh-atlas` recarga y empaqueta el PNG nuevo; la exportación normal conserva el pintado guardado en Blender. La opción se ejecutó satisfactoriamente.

Capturas: [sala](../captures/h1-5-room.png), [delante](../captures/h1-5-front.png), [detrás](../captures/h1-5-behind.png). Fuentes y comandos: [README del terminal](../../assets/source/terminal/README.md).

Copias locales de recuperación: `.local/backups/pre-h1-5-terminal-2026-09-16.zip` y `.local/backups/terminal-v1.glb`. Logs y verificaciones bajo `.local/h1-5-*`. Git continúa sin commits; no se creó un historial ficticio ni se mezclaron cambios ajenos del indicador con esta tarea.

**Límites:** la revisión por capturas no sustituye la aceptación del usuario ni el recorrido manual completo. La sala restante sigue provisional. No se ha realizado una prueba temporal de parpadeo, benchmark ni exportación ejecutable. H1.5 tiene el flujo técnico comprobado; H1 permanece abierto para la revisión H1.6.

## Referencias

- [Importación GLB en Godot 4.6](https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html).
- [Image de Godot 4.6: rasterizar SVG](https://docs.godotengine.org/en/4.6/classes/class_image.html).
- API del exportador glTF verificada contra el código local del Blender 5.2.1 instalado.
