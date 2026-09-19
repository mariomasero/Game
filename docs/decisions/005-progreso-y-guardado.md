# H3 — Mejora y guardado — 16 de septiembre de 2026

El siguiente incremento del objetivo autorizado permite reinvertir y conservar lo ganado. Se mantiene el arte y el personaje. No amplía recetas ni escenarios.

## Mecánica

«Calibración de precisión», ID `precision_calibration`: cuesta 100 cr, requiere tres pedidos completados y máquina vacía. Una compra única reduce los siguientes lotes de 12 a 8 segundos. Tras tres ciclos se dispone de 165 cr: comprarla deja 65, suficiente para continuar. La máquina muestra requisito, coste y efecto antes de comprar. No acelera lotes ya iniciados. Balance en LabDefinitions.

## Estado persistente

JSON schema_version 1 en `user://lab_save.json`. Campos obligatorios: money (entero no negativo), inventory (matrix/catalyst/lumen, cantidades enteras), completed_orders, order_active, order_id, upgrades (`precision_calibration`: bool), batch {state, remaining_seconds, duration_seconds}. Máximo entero JSON seguro 9007199254740991; estados de lote empty/producing/ready, tiempos finitos coherentes. order_id = completed_orders + 1 si hay orden activa, o completed_orders si está cerrada. No se guardan recursos/objetos ejecutables, ni reloj del sistema, ni progreso offline.

LabSnapshot valida todo antes de modificar una sesión. Las definiciones no forman parte del estado. Se guarda duración capturada al iniciar, para que el progreso de un lote no dependa de cambios de balance posteriores. Mejoras y pedidos conservados al cargar; posición del jugador vuelve al punto inicial seguro.

## Archivos y recuperación

LabSaveStore escribe temporal, verifica y reemplaza manteniendo `.bak` válida. Lectura devuelve status `missing`, `ok`, `recovered` (hay copia válida pero exige aceptación) o `error`. No sobrescribe una primaria dañada con una sesión vacía. Recuperar copia y nueva partida son acciones explícitas; conservan los archivos previos en archivos de recuperación con nombre único. Una versión desconocida se rechaza sin convertirla.

API del almacén (RefCounted): `load_game(path: String, validator: Callable) -> Dictionary` con status/state/error; `save_game(path: String, state: Dictionary, validator: Callable) -> String`; `recover_backup(path: String, validator: Callable) -> String`; `replace_game(path: String, state: Dictionary, validator: Callable) -> String`. Validator recibe Dictionary y devuelve String vacío si es válido. Paths runtime en user://; pruebas en carpeta única user://, nunca sobre la partida real. Recovered es solo lectura hasta recover_backup explícito.

LabPersistence local a la sala carga al iniciar, guarda tras transacciones y final del lote, cada cinco segundos durante producción, al pausar y al salir normalmente. Una señal `committed` distingue transacciones de actualizaciones de progreso. La pausa no avanza producción; los paneles no pausan. Error al cargar pausa el juego y ofrece recuperar copia, nueva partida confirmada o salir conservando archivos. Error de escritura visible permite reintentar y no declara éxito. UI de pausa incluye estado de guardado, guardar/salir y nueva partida con confirmación. Las pruebas antiguas desactivan persistencia antes de añadir la escena al árbol.

## Verificación

Compra rechazada antes de tres pedidos, saldo insuficiente/lote ocupado/compra repetida sin descuento; mejora obtenida y lote de ocho segundos. Round-trip completo, recarga durante producción sin avance offline, producto listo, pedido pagado sin doble cobro, corrupción, schema desconocido, recuperación, nueva partida archivada, y rechazo sin mutación parcial. Flujo real de UI y pausa con directorio de pruebas aislado. Regresión H2 y capturas reales.

Documentación API 4.6 consultada: [FileAccess](https://docs.godotengine.org/en/4.6/classes/class_fileaccess.html), [DirAccess](https://docs.godotengine.org/en/4.6/classes/class_diraccess.html), [Window](https://docs.godotengine.org/en/4.6/classes/class_window.html).

## Resultado y revisión

Implementado en Godot 4.6.2. Las siete suites suman 335 comprobaciones, cero fallos. Mejora/snapshot: 51; almacén: 48; carga/recorrido persistente: 15; fallo de escritura/reintento/cierre: 5; regresión H2: 216. La prueba de escena recarga durante producción, comprueba el autoguardado tras cinco segundos reales, reabre después del cobro y recorre recuperación/nueva partida con botones reales. El cierre usa la señal Window.close_requested que recibe el botón de la ventana. No se han probado cortes eléctricos ni fallos físicos de disco.

Revisión local detectó que una escritura interrumpida durante recuperación/reemplazo podía parecer una partida ausente. Se añadió prueba RED (12 fallos) y corrección: `.bak` tiene prioridad, pero si no hay una copia válida, los temporales verificados se ofrecen para recuperación explícita. Nunca se aplican automáticamente. La primaria válida siempre tiene prioridad. El protocolo conserva versiones anteriores, sin afirmar atomicidad física frente a cualquier fallo del sistema operativo.

No se completó la revisión independiente adicional por límite de uso del agente; se hizo revisión local de estado, I/O, pausa, UI y errores. Capturas reales: [lote mejorado](../captures/h3-production.png), [pausa](../captures/h3-pause.png), [recuperación](../captures/h3-recovery.png), [confirmación](../captures/h3-new-game.png). Fuentes/personaje: 33 hashes sin cambios. Pendientes exportación, sesión manual larga y valoración de diversión.
