# H0 — Qué vamos a probar

Fecha: 8 de septiembre de 2026. Estado: dirección de la prueba confirmada por el usuario: «Mover al personaje por un laboratorio cenital y gestionar desde equipos». El acabado visual y la cámara del juego final siguen abiertos.

## Experiencia

Dirigir una pequeña compañía desde dentro de su laboratorio. La hipótesis es que desplazarse entre equipos, comprobar un lote y reinvertir el primer cobro resulta satisfactorio. La ciencia será ficticia y comprensible.

Confirmado: Godot 4.6, pixel art 2D/2.5D y avance incremental. Para esta prueba: PC, teclado/ratón, partida individual, GDScript tipado, personaje controlable y cámara cenital. Nombre comercial, tono y cámara definitiva siguen abiertos.

## Alternativas de representación

| Opción | Esquema | Qué permite comprobar | Coste de la prueba |
|---|---|---|---|
| Cenital 2D (propuesta) | Sala rectangular, X horizontal, Y vertical | Desplazamiento y proximidad a equipos con buena lectura | Bajo; formas provisionales y colisiones nativas |
| Isométrico 2D | Sala en rombo, ejes diagonales | Sensación de profundidad dibujada | Mayor trabajo de orden y oclusión; no muestra reversos |
| Escenario 3D con cámara ortográfica y sprites | Volumen visto desde un ángulo | Girar para ver distintas caras | Requiere otra prueba de representación y assets |

La cámara cenital puede seguir al personaje, pero no permite ver la cara posterior de un equipo. Solo se mantiene una implementación de prueba. Antes del arte final se revisará la elección.

## Primeros cinco minutos previstos (H2/H3; todavía no implementados)

1. 0:00–0:45: recorrer la sala y consultar un pedido en el terminal.
2. 0:45–1:30: comprar dos insumos con el saldo inicial.
3. 1:30–2:15: acercarse a la estación e iniciar un lote ficticio.
4. 2:15–3:00: moverse y consultar el pedido mientras termina el lote.
5. 3:00–4:00: recoger, entregar y cobrar una sola vez.
6. 4:00–5:00: reinvertir en una mejora o repetir para alcanzarla.

Los tiempos son objetivos de diseño, no medidas. Comprar → preparar → esperar pudiendo actuar → entregar → cobrar → mejorar es el bucle a validar.

## Prueba de esta sesión

Una sala, un personaje, paredes y un terminal. WASD/flechas para moverse, E cerca del terminal para consultar un mensaje, Escape o botón para cerrarlo. Con un panel abierto se bloquea el movimiento y la interacción del mundo. Arte geométrico temporal, sin servicios externos.

Comprobación: recorrer los bordes sin atravesarlos, reconocer cuándo se puede interactuar y abrir/cerrar el panel sin acciones simultáneas. El arranque automatizado no sustituye la revisión visual y manual.

H0 define el alcance de la primera prueba con control y perspectiva confirmados para el prototipo. H1 no se marcará completo hasta completar el recorrido manual y revisar sus bordes.
