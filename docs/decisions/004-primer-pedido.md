# Primer pedido del laboratorio — 16 de septiembre de 2026

## Dirección autorizada

El usuario pide continuar añadiendo mecánicas y bases de un juego de rutinas de laboratorio, inspirado en Stardew Valley y una corporación inquietante como Umbrella. Se ocupa gradualmente del arte. Esto autoriza avanzar H2 con la sala actual sin declarar cerradas las revisiones manuales de H1. Personaje y arte quedan intactos.

## Incremento jugable

Un encargo corporativo repetible de un compuesto totalmente ficticio, «Lumen». El ordenador ofrece compras y entregas; la máquina existente prepara y permite recoger un lote. El jugador comienza con 120 créditos. Una cápsula de matriz cuesta 12 y un vial de catalizador 8; una unidad de cada produce una muestra en 12 segundos. El encargo paga 35, dejando 15 de margen para futura reinversión. Durante la producción se puede caminar y reponer insumos. No hay simulación científica real.

El HUD muestra saldo, siguiente acción y progreso del lote. Paneles separados para ordenador y máquina, con existencias, costes, mensajes de error y botones comprensibles. La siguiente orden se solicita explícitamente tras entregar; repetir el botón de entrega nunca vuelve a cobrar la anterior. Escape cierra un panel; desde la sala abre pausa, que detiene producción y movimiento. La sesión aún no se guarda: avisarlo dentro del juego hasta H3.

Revisión de jugabilidad: comprar solo un tipo de insumo puede agotar el saldo. El ordenador permite devolver todos los insumos sin usar por su coste para recuperar esa situación; nunca devuelve ingredientes ya consumidos en un lote. API adicional `refund_supplies() -> String`. Se validan también los datos de balance editables para evitar precios, duración o cantidades inválidas.

Se prefiere completar este recorrido físico sobre añadir menús de gestión global o varias recetas: reutiliza la sala y permite probar el ritmo antes de ampliar contenido. Compras por unidad, sin cantidades de texto libre. Reglas separadas de UI y geometría, definiciones como Resource editable y estado local a la sala. Sin plugins ni autoloads.

## Contrato de dominio

`scripts/domain/lab_session.gd`: `LabSession extends Node`, señal `changed`, recurso `definitions`, saldo entero `money`, inventario `Dictionary[StringName, int]`, `batch_state: StringName` (`empty`, `producing`, `ready`), `remaining_seconds: float`, `completed_orders: int`, `order_active: bool`, `order_id: int`.

Métodos `buy(item_id: StringName, quantity: int = 1) -> String`, `start_batch() -> String`, `collect_batch() -> String`, `deliver_order(expected_order_id: int) -> String`, `request_order() -> String`: cadena vacía indica éxito; en rechazo devuelven una razón legible sin mutaciones parciales. `advance(delta: float) -> void` consume solo tiempo finito positivo durante producción; `_process` lo llama, respetando la pausa nativa. `count_item(item_id: StringName) -> int` consulta inventario.

`scripts/domain/lab_definitions.gd`: `LabDefinitions extends Resource`; `starting_money`, `matrix_price`, `catalyst_price`, `batch_seconds`, `order_reward`, `order_quantity`. IDs estables `matrix`, `catalyst`, `lumen`; receta única consume 1+1 y da 1. Datos en `resources/definitions/first_lab.tres`, separados del estado mutable. UI obtiene los valores del recurso, sin duplicar el balance.

## Comprobación

- Tres ciclos completos: 120 → 135 → 150 → 165; existencias consumidas y recompensas únicas.
- Rechazar cantidades no positivas, desconocidas, excesivas o inasequibles; ausencia de ingredientes, segundo lote ocupado, recogida anticipada y repetida, entrega sin producto/inactiva/ID antiguo.
- Interacción real con ambos equipos: proximidad, obstáculos, bloqueo del personaje con UI, recuperación al cerrar, progreso mientras se camina, pausa sin avance y reanudación.
- Conservar las 56 pruebas anteriores, hashes de fuentes/personaje y capturas legibles a 640×360.
- H3 pendiente: mejora y persistencia coherente. No se considera terminado el objetivo general por completar H2.

APIs consultadas: [pausa Godot 4.6](https://docs.godotengine.org/en/4.6/tutorials/scripting/pausing_games.html), [Resource 4.6](https://docs.godotengine.org/en/4.6/classes/class_resource.html), [Control 4.6](https://docs.godotengine.org/en/4.6/classes/class_control.html).

## Resultado comprobado

Godot `4.6.2.stable.official.71f334935`: importación y arranque de la escena principal sin errores; 133 comprobaciones de dominio, 27 del recorrido mediante entradas reales y 56 anteriores, todas aprobadas. El recorrido espera los 12 segundos reales, comprueba que se puede caminar, pausa y reanuda, recoge, entrega y solicita otra orden. El dominio verifica tres ciclos y transacciones inválidas. Los 33 hashes del personaje/fuentes coinciden con el estado previo.

La revisión independiente detectó y ayudó a corregir el atasco por gasto en un solo insumo, el saldo inicial de Resources personalizados y valores de balance inválidos. Revisión final sin hallazgos materiales pendientes.

Capturas reales: [ordenador](../captures/h2-terminal.png), [producción](../captures/h2-production.png), [entrega](../captures/h2-delivered.png), [pausa](../captures/h2-pause.png). No constituyen una prueba manual de diversión, estabilidad durante una sesión prolongada o exportación. Se mantiene pendiente H3 (mejora y guardado), y el objetivo general sigue abierto.
