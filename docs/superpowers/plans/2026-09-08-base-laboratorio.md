# Base del laboratorio — plan de implementación

> Ejecución en esta sesión con superpowers:executing-plans; sin commits automáticos.

**Objetivo:** dejar una prueba corta de H1 que permita evaluar el supuesto cenital de H0.
**Arquitectura:** escena de sala que compone personaje, terminal y UI; señales locales y nodos nativos. Sin autoloads ni reglas económicas todavía.
**Tecnología:** Godot 4.6.2 instalado, GDScript tipado, renderizador Compatibility.

1. Documentar hipótesis H0 y reconstruir `Readme.me`, ausente al inicio, identificándolo como documento nuevo.
2. Configurar `project.godot`, Input Map, filtrado nearest, `.gitignore` y escenas pequeñas en `scenes/world`, `scenes/player`, `scenes/lab`, `scenes/ui`.
3. Crear una comprobación de integración de movimiento, colisión, distancia de interacción y bloqueo de UI; comprobar el fallo inicial y después implementar el mínimo comportamiento.
4. Importar con Godot headless, ejecutar la escena y las pruebas. Abrir una vista renderizada para revisar legibilidad y composición si el entorno lo permite.
5. Registrar resultados reales, limitaciones y siguiente paso en el plan principal y README. Revisar los archivos nuevos; conservar `AGENTS.md` y el backlog.

No se añaden producción, inventario, dinero, guardado, arte final ni plugins en esta prueba. La perspectiva es un supuesto reversible.
