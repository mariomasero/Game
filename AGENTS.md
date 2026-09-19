# Instrucciones para Codex — Proyecto biotecnología

Actualizado: 16 de septiembre de 2026.

## Propósito y fuentes de verdad

Desarrollar por incrementos un videojuego en Godot 4.6 sobre llevar el laboratorio de una corporación biotecnológica. El jugador controla a un personaje, trabaja en el laboratorio, gestiona desde los equipos y reinvierte lo obtenido. Las rutinas y la progresión de Stardew Valley y una corporación inquietante como Umbrella son las referencias pedidas por el usuario. Crear una identidad propia.

Leer `Readme.me` y `DEVELOPMENT_PLAN.md` antes de ampliar funcionalidades. Las instrucciones actuales del usuario prevalecen. Distinguir decisiones de diseño, propuestas técnicas, implementación existente y verificaciones realizadas. Los registros del 8 de septiembre describen la base 2D anterior; no acreditan una migración 3D.

## Dirección acordada y decisiones abiertas

- Motor: Godot 4.6. El historial registra 4.6.2; comprobar el ejecutable real al retomar el repositorio.
- Dirección visual: mundo 3D low-poly con texturas pixel art, personajes 2D dentro del mundo y cámara elevada de orientación fija. Referencia visual aportada: el proyecto Pokémon Light Platinum NDS, según la conversación. La referencia guía la apariencia; no define nuestras mecánicas ni exige reproducir su implementación.
- Aclaración del 16 de septiembre: el arte del juego debe ser pixel art. El personaje actual, con ocho direcciones y proporciones originales, está aprobado por el usuario: no modificar sus sprites, escala, materiales, animaciones ni control en las siguientes tareas de arte.
- Paleta solicitada después: iluminación y colores más alegres, con suelo y paredes más blancos. La muestra usa blancos, turquesa y azul cielo; conservar la legibilidad de las baldosas y las sombras.
- Nueva prioridad del usuario: continuar con mecánicas y bases jugables; él irá desarrollando el arte. Conservar la representación actual al ampliar sistemas. Tono corporativo autorizado; esto no incorpora automáticamente combate, terror ni simulación científica real.
- Control directo del personaje y gestión mediante equipos. Desarrollo incremental, adecuado para una persona sin experiencia previa.
- Propuesta de partida: GDScript tipado, PC con teclado/ratón y partida individual local. Plataformas finales pendientes.
- Ajustes por validar en H1: proyección, ángulos, encuadre, escala, resolución interna y relación entre sprites y escenario.
- Abierto: nombre, tono definitivo, profundidad de gestión y narrativa. Combate, terror, multijugador y simulación científica detallada no están aprobados.

No volver a abrir la elección general entre mundo 2D y mundo 3D como requisito previo. Resolver los ajustes visuales con una muestra pequeña dentro del enfoque acordado.

## Alcance y ritmo de trabajo

H2/H3 tienen el primer pedido completo, mejora y persistencia implementados y comprobados. La siguiente base es H4: claridad, feedback y primera versión pequeña jugable. El usuario se ocupa del arte; no ampliarlo por rutina. La revisión manual final de H1 sigue pendiente, pero la nueva solicitud autoriza avanzar las mecánicas sobre la sala actual. No presentar esa revisión como realizada.

El bucle posterior se conserva: comprar insumos → preparar un lote ficticio → esperar mientras se puede actuar → entregar un pedido → cobrar → mejorar un equipo. Cada nueva mecánica debe aportar una decisión o mejorar ese bucle.

Trabajar en una tarea observable cada vez. Explicar en lenguaje sencillo qué se hará, cómo abrirlo y cómo comprobarlo. Resolver decisiones rutinarias y reversibles sin pedir confirmación repetidamente; consultar cambios de dirección, nuevos gastos o decisiones difíciles de revertir. No implementar todo el backlog ni introducir ciudad, trabajadores autónomos, combate, contenido masivo o un árbol grande de investigación durante el prototipo.

## Antes de editar el proyecto

1. Revisar instrucciones locales, escenas, recursos y cambios de Git; conservar trabajo ajeno.
2. Comprobar versión real de Godot y `project.godot`, si existe. No cambiar de versión menor sin acuerdo.
3. Identificar el comportamiento esperado y su comprobación concreta.
4. Exponer un plan breve si la tarea afecta varios sistemas.
5. Consultar documentación de Godot 4.6 al usar APIs; no copiar ejemplos de Godot 3 o `latest` sin comprobarlos.

## Migración de la base 2D

Inspeccionar el proyecto real antes de decidir qué reutilizar. La documentación disponible registra movimiento, terminal, UI y sprites en 2D; no contiene una escena 3D validada.

- Conservar originales de sprites, PC, escritorio, atribuciones y archivos Aseprite. Los PNG del mobiliario pueden servir de referencia visual o marcador temporal; no convertirlos en el escenario definitivo por defecto.
- Reutilizar recursos `SpriteFrames`, texturas, acciones de entrada y UI cuando sean compatibles. Adaptar las dependencias del mundo 2D de manera explícita.
- Sustituir representación y física del mundo por nodos 3D. No trasladar directamente dimensiones de colliders en píxeles a unidades 3D.
- Mantener la base recuperable mediante el mecanismo de control de versiones existente antes de sustituir escenas. No borrar el prototipo por rutina ni mantener dos implementaciones completas en desarrollo.
- Las ocho orientaciones ya documentadas no obligan a producir ocho nuevas. El objetivo inicial es reposo y caminar en cuatro direcciones; conservar las fuentes adicionales.
- Revisar las pruebas que asumen `Vector2`, nodos 2D o un orden de dibujo 2D. Sus resultados históricos no validan profundidad ni colisiones 3D.

## Arquitectura proporcional

- Escenas pequeñas y composición. Separar reglas de producción/economía de UI y representación del mundo.
- GDScript tipado; nombres `snake_case`, clases `PascalCase` y constantes `UPPER_SNAKE_CASE`.
- Input Map para acciones. Movimiento sobre el plano XZ, con Y como altura; relacionar las entradas con la cámara para que «arriba» resulte intuitivo en pantalla.
- Mundo: `Node3D`, `MeshInstance3D`, `StaticBody3D` y `CollisionShape3D`. Jugador: `CharacterBody3D`, colisión y `AnimatedSprite3D`. Cámara: `Camera3D`. Interacción: `Area3D` y, si hace falta, comprobación de línea de visión. UI: `Control`/`CanvasLayer`.
- No usar `CharacterBody2D`, `Camera2D` ni `TileMapLayer` como base del nuevo mundo. Los nodos 2D siguen siendo válidos para UI y utilidades donde correspondan.
- Construir la sala con escenas modulares sencillas; evaluar `GridMap` solo si colocar módulos manualmente se vuelve un problema real.
- No crear un `GameManager` monolítico ni un bus global para cada interacción. Autoloads solo ante una necesidad compartida clara.
- Recetas, artículos y mejoras como datos con IDs estables; estado mutable separado de las definiciones.
- Carpetas propuestas, que solo se crean cuando hagan falta: `scenes/{world,player,lab,ui}`, `scripts/{domain,systems,persistence}`, `resources/definitions`, `assets/source`, `assets/game/{models,textures,sprites,audio}`, `docs/decisions`, `tests`.

## Cámara, sprites y acabado

La cámara mantiene orientación fija durante el juego. Puede seguir al personaje si la sala lo requiere; «fija» no significa inmóvil. Sin rotación ni zoom controlados por el jugador en H1. Empezar con proyección ortográfica; una perspectiva suave es una alternativa de prueba dentro del mismo enfoque.

No imponer un azimut de 45° como requisito del estilo NDS. Comparar un encuadre alineado con la sala y, si ayuda, uno oblicuo; registrar los valores elegidos. Una inclinación hacia el suelo de 50–60° es solo un punto de partida, no una medición de la referencia.

Para el personaje: cuatro direcciones de reposo/caminar, pivote en los pies y sombra simple. Ajustar tamaño físico mediante la relación píxel/unidad y comprobar el resultado en cámara. Probar la orientación del sprite hacia la cámara y su profundidad: evitar inclinaciones, recortes, z-fighting y transparencias que lo dibujen delante de objetos que deberían taparlo. No desactivar la prueba de profundidad para ocultar esos problemas.

Fijar escala modular, proporciones, densidad de texel, paleta, pivotes e iluminación con una muestra pequeña. Propuesta inicial: módulo de suelo de 1 unidad y sala de unos 10×10 módulos, sujetos a comodidad de movimiento. No heredar automáticamente las escalas fraccionarias del prototipo 2D.

Probar 640×360 como resolución interna inicial, filtrado nearest, escalado entero y barras si la ventana no encaja. Separar la UI si necesita más resolución para ser legible. Texturas de 32, 64 o 128 píxeles son puntos de partida según el objeto, no un tamaño universal. Nearest por sí solo no garantiza estabilidad: revisar parpadeo de texturas durante el movimiento y minificación, y decidir los mipmaps con evidencia visual.

Empezar con materiales simples, una luz y ambiente controlado. Sin TAA, desenfoque ni efectos complejos en la primera muestra. Usar paredes frontales bajas o abiertas para permitir la visión; evitar un sistema de desvanecimiento de paredes hasta que haga falta.

## Producción de assets y herramientas

Flujo principal: Blender → modelo low-poly y UV → textura pixel art → exportación `.glb` → escena Godot con colisión/interacción. Guardar fuentes editables aparte de los archivos de juego. No sobrescribir cambios en escenas importadas: integrar el modelo en una escena propia que conserve colisiones y scripts al reimportar.

| Herramienta | Papel previsto | Condición |
|---|---|---|
| Blender | Modelado modular y exportación GLB | Base del flujo propuesto |
| Pixel Art Studio | Pintar texturas sobre modelos | Opcional; compra/instalación no confirmadas |
| Aseprite | Sprites, animación y limpieza final | Usar si está disponible; admite editor equivalente |
| sprite-gen | Ayuda con variantes, efectos y animaciones provisionales | Evaluar antes de integrar; revisar cada resultado |
| PixZels | Pruebas de objetos geométricos | Complemento opcional; comprobar salida útil hacia Blender |
| Puck’s Pixelizer | Experimentar con acabado de texturas | Opcional; no necesario para H1 |

El flujo puede arrancar con primitivas de Godot, Blender y un editor de imágenes disponible. No bloquear H1 por comprar el bundle. PixelLab queda como alternativa opcional, sin dependencia ni integración asumidas.

Para `sprite-gen`, comprobar versión, licencia, proveedores, costes y formatos realmente disponibles antes de usarlo. No prometer ejecución local sobre la RTX 5070 Ti ni instalación de un backend de difusión. No construir un importador propio de atlas hasta que una exportación real demuestre que aporta valor frente al editor de `SpriteFrames`.

## Plugins y dependencias

Prioridad: funcionalidad nativa suficiente → plugin gratuito compatible y mantenido → código propio pequeño. No añadir una dependencia por ahorrar unas líneas.

Antes de adoptarla, verificar fuente oficial, licencia, versión/commit, compatibilidad real con Godot 4.6, mantenimiento y dependencias. Registrar estos datos, propósito y prueba en `docs/DEPENDENCIES.md` cuando exista la primera. Distinguir herramientas de autoría de plugins que se distribuyen con el juego. Mantener avisos y atribuciones de assets. No instalar herramientas de pago ni activar servicios facturados sin autorización.

## Persistencia y reglas de juego

- Datos en `user://`, nunca en `res://`; `schema_version` e IDs estables.
- Dinero entero al principio. Validar cantidades, saldo e insumos antes de confirmar operaciones; no duplicar consumos ni cobros.
- Desde H3, guardar dinero, inventario, mejoras y lote de forma coherente. Sin producción offline; la pausa no avanza producción.
- Proteger partidas existentes con escritura temporal y recuperación apropiada. Un archivo corrupto no debe sobrescribirse automáticamente con una partida vacía.
- Versionar y migrar formatos cuando haya partidas que conservar.
- Desde H3 existe `user://lab_save.json`, `schema_version = 1`, copia `.bak` y archivos previos archivados. Mantener compatibilidad al ampliar el estado. Las pruebas usan rutas aisladas o desactivan Persistence antes de añadir la sala al árbol; nunca probar sobre la partida real.

## Verificación y entrega

Detectar el ejecutable instalado. Con proyecto existente, comprobaciones orientativas:

```bash
godot --version
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 1
```

El arranque headless no valida el aspecto. Para H1, revisar visualmente cámara, pies del sprite, paredes, colisiones, profundidad delante/detrás del mobiliario y redimensionado. Comprobar terminal cercano, inaccesible a través de paredes, bloqueo de acciones con UI y recuperación del control. Para H2/H3, comprobar transacciones inválidas, entrega repetida y recarga durante producción. Usar pruebas existentes cuando correspondan; no imponer un framework para cambios documentales.

Cerrar cada tarea con cambios, comprobaciones ejecutadas y limitaciones. Actualizar hitos solo con evidencia; nunca presentar como aprobada una prueba manual o exportación no realizada. No versionar `.godot/`, builds, secretos ni partidas; conservar UID necesarios. No hacer commits, pushes ni cambios destructivos sobre trabajo ajeno por rutina.
