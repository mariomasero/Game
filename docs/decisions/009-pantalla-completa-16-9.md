# Pantalla completa a 16:9 (Full HD y 4K)

19 de septiembre de 2026. Petición: poder jugar en Full HD y 4K con relación 16:9.

## Punto de partida comprobado

El juego **ya estaba en 16:9**. La imagen interna es 640×360, que es exactamente 16/9 = 1,7778. El proyecto usa modo de estiramiento `viewport`, `aspect` en `keep` (valor por defecto, ahora escrito de forma explícita) y escalado entero. La relación no necesitaba cambiarse.

Lo que faltaba era poder llenar la pantalla: no existía ninguna forma de pasar a pantalla completa, ni acción de entrada ni código. La ventana quedaba fija en 1280×720, que en un monitor 4K ocupa una esquina.

## Cambios

- `project.godot`: `window/stretch/aspect="keep"` escrito de forma explícita para dejar fijada la relación 16:9 y que un cambio futuro sea visible en el historial. Nueva acción `toggle_fullscreen`, con **F11** y **Alt+Intro**.
- `scripts/presentation/display_mode.gd` (`class_name DisplayMode`): alterna ventana y pantalla completa mediante `DisplayServer.window_set_mode`. No toca la imagen interna ni contiene reglas de juego. Ignora la llamada en modo headless para no afectar a las pruebas.
- `scenes/world/laboratory_3d.gd`: atiende la acción en `_unhandled_input` **antes** de la comprobación del panel, para que la pantalla completa también funcione con el terminal o la pausa abiertos.

No se ha modificado la resolución interna, la cámara, el `pixel_size` del personaje ni el tamaño de ventana por defecto. La relación píxel/unidad de la [decisión 002](002-sala-3d.md) depende del viewport 640×360 y se conserva intacta.

## Escalado resultante

Al ser 640×360 un divisor exacto de las resoluciones 16:9 habituales, el escalado entero amplía la imagen sin deformarla y sin barras negras:

| Pantalla | Escala | Píxeles sobrantes |
|---|---:|---:|
| 1280×720 | ×2 | 0×0 |
| 1920×1080 (Full HD) | ×3 | 0×0 |
| 2560×1440 | ×4 | 0×0 |
| 3840×2160 (4K) | ×6 | 0×0 |

En un monitor que no sea 16:9 (21:9, 16:10) el motor mantiene la relación y añade barras, que es el comportamiento buscado para pixel art.

## Comprobaciones realizadas

- Godot 4.6.2. Reimportación e inicio del proyecto sin errores ni avisos (`--headless --quit-after 120`).
- Cálculo de escalas de la tabla anterior verificado en ejecución, junto con `InputMap.has_action("toggle_fullscreen")` y sus dos eventos.
- Pruebas existentes: 3D 56, dominio 133, pedidos 27, progreso 51, almacén 48, fallos de guardado 5, partida 15 — todas sin fallos. `test_lab_feedback` da 1 fallo de 14 en «Actualizar la UI no reinicia el aviso sonoro»; se comprobó que **también falla sin estos cambios**, es una comprobación de posición de reproducción de audio que no se sostiene con el controlador de sonido de `--headless`.

## Limitaciones

- **No se ha verificado visualmente en pantalla completa real, ni a 1080p ni a 4K.** Las comprobaciones son de arranque, de cálculo y automáticas. Falta pulsar F11 en el juego y mirar el resultado.
- Con un panel abierto y un botón con el foco, **Alt+Intro** puede ser consumido por la interfaz antes de llegar a `_unhandled_input`; **F11** funciona siempre.
- El modo elegido es `WINDOW_MODE_FULLSCREEN` (pantalla completa sin bordes), no exclusivo. No se ha medido si el exclusivo daría menos latencia.
- No hay opción en un menú ni preferencia guardada: el juego arranca siempre en ventana. Añadirlo cuando exista una pantalla de ajustes.
