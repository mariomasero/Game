# Primer pedido — plan de implementación

> Ejecución: superpowers:subagent-driven-development, una tarea observable con dominio y presentación independientes.

**Objetivo:** comprar insumos, producir físicamente en la máquina y entregar tres pedidos sin errores de saldo o duplicación.
**Arquitectura:** LabSession local a la sala, datos Resource, panel de operaciones que emite intenciones, interacción 3D existente reutilizada en la máquina.
**Tecnología:** Godot 4.6.2, GDScript tipado, sin dependencias.
**Especificación:** `docs/decisions/004-primer-pedido.md`.

## Restricciones

- No editar personaje ni gráficos. No commits/pushes. Repositorio sin commit inicial: trabajar en la rama actual con copia recuperable de escenas, pruebas y configuración.
- Mantener rutas del panel/Close que usan las pruebas actuales.
- La pausa detiene el reloj de producción; los paneles de equipos no pausan el mundo.

## Tarea 1 — Reglas de pedidos y producción

Archivos: `scripts/domain/lab_definitions.gd`, `lab_session.gd`, `resources/definitions/first_lab.tres`, `tests/test_lab_session.gd`.
Interfaz: contrato completo de la especificación. UI consume `changed`, campos de estado y métodos que devuelven razón de rechazo.

- [x] Escribir prueba que carga el script real y falla si falta; después ejecutar compras/rechazos, tres ciclos y doble entrega con expectativas literales (135/150/165).
- [x] Ejecutar `godot --headless --path . --script tests/test_lab_session.gd` y observar el fallo de comportamiento pendiente.
- [x] Implementar estado y transacciones atómicas, avance finito y recurso de balance.
- [x] Repetir pruebas y revisar saldo, no duplicación, independencia entre sesiones y señal de cambios.

## Tarea 2 — Recorrido jugable y paneles

Archivos: `scenes/world/laboratory_3d.gd/.tscn`, `scenes/lab/machine.tscn`, `scenes/ui/lab_hud_3d.tscn`, nuevo `lab_operations.gd`, `tests/test_order_loop.gd`.
Consume: API de LabSession. Produce: controles reales para comprar, iniciar, recoger, entregar y solicitar otro encargo; estado visible y pausa.

- [x] Escribir prueba del flujo con entradas reales, botones y física. Debe fallar con el panel de bienvenida actual.
- [x] Añadir Area3D frontal a máquina reutilizando comprobación de obstáculos; elegir solo un equipo alcanzable.
- [x] Integrar paneles, saldo, guía de siguiente paso, progreso y pausa sin cambiar arte/personaje.
- [x] Probar compra → máquina → espera con movimiento → recogida → entrega; pausa no avanza; bloqueo por pared y UI.

## Tarea 3 — Verificación de la entrega

- [x] Importar y arrancar con Godot 4.6.2; ejecutar pruebas nuevas y las 56 anteriores.
- [x] Capturar terminal, producción y entrega con renderer real; corregir recortes y texto ilegible.
- [x] Revisión independiente del dominio y de la integración; resolver fallos materiales.
- [x] Comparar hashes del personaje; actualizar Readme, AGENTS y DEVELOPMENT_PLAN con evidencias y límites, sin cerrar el objetivo general.
