# H3 — Plan de implementación

> Ejecución con superpowers:subagent-driven-development. Especificación: docs/decisions/005-progreso-y-guardado.md.

**Objetivo:** reinvertir en una mejora y reanudar una partida coherente.
**Arquitectura:** dominio LabSession/LabSnapshot, almacén de archivos independiente, coordinador local LabPersistence y UI existente.
**Stack:** Godot 4.6.2, GDScript tipado. Sin dependencias ni cambios al arte/personaje. Sin commits/pushes. Copia de recuperación previa en .local.

- [x] Tarea 1: almacén de archivos `scripts/persistence/lab_save_store.gd` y `tests/test_lab_save_store.gd`. Escribir y observar pruebas fallando antes de implementar. Consumir el validator Callable y cumplir las cuatro firmas de la especificación. Probar temporal, backup, corrupción, versión rechazada por validator y reemplazo explícito archivado.
- [x] Tarea 2: mejora + snapshot. `LabSession` añade committed, upgrade_owned, batch_duration_seconds, buy_upgrade, production_seconds; `LabDefinitions` coste/requisito/duración. `LabSnapshot.capture/validate/apply` separa persistencia del dominio. Pruebas de compra/transiciones y restauración atómica primero.
- [x] Tarea 3: `LabPersistence` + UI, prueba de escena real con ruta aislada. Carga, autoguardado, cinco segundos durante producción, pausa/salir, recuperación y confirmación de nueva partida. Pruebas antiguas no deben escribir la partida del usuario.
- [x] Tarea 4: revisión local completada; revisión independiente no disponible por límite de uso, importación/arranque, suites, capturas reales y hashes; actualizar documentación con resultado y límites. Dejar objetivo general abierto.
