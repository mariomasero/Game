# H1 — Primera sala 3D

Fecha: 15 de septiembre de 2026. Implementa la dirección indicada en AGENTS.md y DEVELOPMENT_PLAN.md; sustituye la elección de representación de 001, cuyo historial se conserva.

## Primera entrega

Una sala recorrible de 10×10 unidades, suelo, paredes traseras altas y laterales bajas, puerta decorativa, mesa con terminal y máquina provisional. Cámara ortográfica estática, alineada con la habitación, inclinada 55°. Personaje 2D con cuatro direcciones, física 3D y UI modal. Sin ampliar H2.

Se eligen primitivas editables de Godot para comprobar las proporciones primero. Un GLB de Blender será la siguiente tarea H1.5; no es requisito para arrancar esta habitación. Los sprites y SpriteFrames existentes se reutilizan. El panel conserva su contenido y funcionamiento con un diseño adaptado a 640×360.

## Componentes y contratos

- `scenes/world/laboratory_3d.tscn`: compone sala, jugador, terminal, cámara e interfaz. Su script coordina apertura y cierre.
- `scenes/world/room_shell.tscn`: geometría y colisiones estáticas editables.
- `scenes/player/player_3d.tscn`: CharacterBody3D y AnimatedSprite3D. `controls_enabled: bool` bloquea entradas; `camera: Camera3D` orienta el movimiento XZ.
- `scenes/lab/terminal_3d.tscn`: Area3D con mobiliario. `can_interact(body: PhysicsBody3D) -> bool` exige proximidad y segmento libre de obstáculos hasta un punto situado delante del ordenador.
- `scenes/ui/lab_hud_3d.tscn`: Control/CanvasLayer; E abre, Escape y botón cierran. La UI recibe el ratón y bloquea el personaje.

## Recuperación

Git está inicializado en `prototype/h1-laboratory`, sin commits. No se crea un commit sin autorización. Se conservan todas las escenas 2D en sus rutas originales, congeladas, y se crea `.local/backups/pre-h1-3d-2026-09-15.zip` antes de editar el arranque. SHA256: `F43F4EAFEC3819D30DA78525AE0CA4A0F5788548A8567CDE6B20A4003C38C27B`. La copia local no sustituye un historial de Git. Solo se desarrollará la escena 3D nueva; no hay dos implementaciones activas.

## Verificación prevista

Importación y arranque en Godot 4.6.2; pruebas de movimiento cardinal/diagonal, paredes, mesa, suelo, animaciones, interacción lejana/obstruida, apertura repetida, bloqueo y recuperación de control. Capturas renderizadas delante/detrás de la mesa y en bordes, panel y ventanas de distinta proporción. La aceptación visual del usuario, recorrido manual completo y GLB reimportado siguen siendo criterios para cerrar H1.

## Referencias de API

- [CharacterBody3D 4.6](https://docs.godotengine.org/en/4.6/classes/class_characterbody3d.html)
- [SpriteBase3D 4.6: pivote, billboard y alpha cut](https://docs.godotengine.org/en/4.6/classes/class_spritebase3d.html)
- [PhysicsRayQueryParameters3D 4.6](https://docs.godotengine.org/en/4.6/classes/class_physicsrayqueryparameters3d.html)
- [Resolución y escalado entero en 4.6](https://docs.godotengine.org/en/4.6/tutorials/rendering/multiple_resolutions.html)

## Ficha de la muestra implementada

Valores comprobados por render, aún sujetos a aceptación visual del usuario:

| Parámetro | Valor |
|---|---|
| Proyección y encuadre | Ortográfica; tamaño vertical 13,5 unidades; cámara estática |
| Orientación | X = −55°, Y = 0°, Z = 0°; habitación alineada |
| Posición de cámara | (0; 13,34; 8,8904) |
| Módulo y sala | 1 unidad; suelo 10×10 |
| Paredes | Fondo 1,8; laterales 0,56; borde frontal 0,12 |
| Mesa | 2,1×1,1 de huella; tablero a 1,1 de altura |
| Personaje | Lienzo original 32×32; 0,0375 unidades/píxel; escala vertical 1/cos(55°) ≈ 1,7434468; píxeles cuadrados 1:1 en el viewport 640×360; arte visible de unos 24 píxeles de altura |
| Pivote | Origen en los pies; offset de sprite (0,16), elevación 0,02; cápsula radio 0,27 y altura 1,4 |
| Orientación de sprite | Billboard limitado al eje Y: permanece vertical, con escala vertical para compensar la vista elevada |
| Transparencia | Alpha cut discard; prueba de profundidad activa; sin sombra proyectada del sprite |
| Sombra del personaje | Disco opaco de 12 lados, radio 0,3, apoyado en el suelo |
| Animación | Reposo/caminar en ocho direcciones; vistas izquierdas reflejadas; fotogramas originales, 4 por animación a 10 FPS |
| Resolución | 640×360, ventana inicial 1280×720, viewport con keep e integer |
| Texturas | Suelo y pantalla SVG de formas rectangulares, rasterizados a 32×32; suelo repetido cada unidad, unos 32 texeles/unidad |
| Filtrado | Nearest; la importación actual del suelo genera mipmaps; minificación temporal pendiente de recorrido |
| Luz | Un DirectionalLight3D a (−65°, −25°, 0°), energía 0,16 y color (1; 0,985; 0,96); ambiente 0,45 con color (0,95; 0,98; 1), actualizado el 16 de septiembre |
| Materiales | Simples y rugosos, blancos con acentos turquesa/azul cielo y pequeños detalles coral/amarillo; sin TAA, desenfoque ni efectos complejos |

La primera captura reveló una pared recortada por el HUD y suelo demasiado claro. Se amplió el encuadre vertical y se desplazó la cámara hacia arriba; se redujeron las energías de luz y ambiente. La segunda serie muestra completos los bordes y mantiene los pies sobre el suelo. La mesa oculta correctamente la parte inferior del personaje cuando pasa detrás.

### Corrección del personaje solicitada por el usuario

Conservar al personaje tal como viene en `assets/16x32/16x32 All Animations-Sheet.png`: dibujos, colores y proporciones originales. Comparación directa de píxeles: los 20 fotogramas de `idle.png` y los 20 de `walk.png` coinciden con las filas de reposo/caminar de la hoja completa; no fue necesario modificar ni sustituir PNG.

La configuración anterior proyectaba cada píxel a aproximadamente 1,467×1,346 píxeles de pantalla, ensanchando la silueta. Se ajustó el tamaño a 0,0375 unidades/píxel y la compensación vertical al inverso del coseno de 55°. El resultado proyectado es 1×1 píxel en 640×360, ampliado uniformemente por el escalado entero de la ventana. Se mantiene el sprite vertical y la profundidad 3D. Estos dos valores dependen del encuadre actual: si cambia la cámara, revisar su proyección para conservar píxeles cuadrados.

### Paleta clara solicitada el 16 de septiembre

La primera paleta crema/verde grisáceo usaba luz directa 0,55 y ambiente 0,4. A petición del usuario se sustituyó por blancos y acentos más alegres; se ajustó la iluminación sin alterar la cámara ni el personaje. Suelo: base `#e3e9ed`, juntas `#c5d5df`, luces `#f4f6f2` y detalles `#d9e3e7`. El terminal pixel art conserva su atlas y material originales. La interfaz adopta paneles claros y texto oscuro.

Importación, render y 56 comprobaciones automatizadas sin fallos. Los hashes de los 33 archivos del personaje coinciden con el estado previo. [Sala actual](../captures/h1-bright-room.png) y [panel actual](../captures/h1-bright-panel.png). Valoración del usuario y recorrido manual pendientes.

## Evidencia y límites

- Godot 4.6.2: importación y arranque comprobados; tras activar las ocho direcciones, 46 comprobaciones automatizadas, sin fallos.
- Render real mediante OpenGL Compatibility, NVIDIA RTX 5070 Ti; sin benchmark de rendimiento.
- [Sala](../captures/h1-3d-room.png), [delante de mesa](../captures/h1-3d-desk-front.png), [detrás de mesa](../captures/h1-3d-desk-behind.png), [panel](../captures/h1-3d-panel.png).
- `tests/capture_laboratory_3d.gd` reproduce las capturas, incluyendo los laterales y bordes, en `.local/captures/h1-3d/`.
- Ventanas 960×720 y 1440×900: el motor informa de escalado uniforme ×1 y ×2, con márgenes de 160/180 y 80/90 píxeles por lado. A 640×360 escala ×1 sin márgenes. Las capturas corresponden al viewport interno y no prueban visualmente las barras externas.
- No se ha realizado una sesión manual completa, una grabación para estudiar parpadeos, ni exportación. H1.5 y aceptación visual pendientes; H1 no está cerrado.
