---
name: verificar-godot
description: Ejecuta las comprobaciones del proyecto Godot (versión, importación del editor, arranque, todas las pruebas headless y siempre la guarda de píxel) y devuelve un resumen corto en vez de la salida completa de Godot. Úsala SIEMPRE antes de dar por terminada cualquier tarea que toque código, escenas, recursos, shaders, materiales, texturas o ajustes del proyecto, y también cuando Mario pida probar, comprobar, verificar, pasar las pruebas o la guarda, o pregunte si algo se ha roto.
---

# Verificar el proyecto Godot

AGENTS.md exige ejecutar las pruebas y la guarda de píxel al cerrar cada tarea. Esta skill lo hace con un script que guarda la salida completa en un archivo y solo imprime una línea por paso. Así la verificación cuesta poco uso aunque se repita muchas veces.

## Cómo ejecutarla

Desde la raíz del repositorio:

```bash
bash .claude/skills/verificar-godot/scripts/verificar.sh
```

Variantes:

- `verificar.sh water plot_layout` — solo las pruebas cuyo nombre contenga esas palabras. La guarda de píxel se ejecuta siempre, porque AGENTS.md lo exige aunque no se toque el arte.
- `verificar.sh --sin-arranque water` — salta la importación y el arranque. Úsalo solo para repetir una prueba concreta mientras depuras; la verificación de cierre de tarea va siempre completa.

Si Godot está en otra ruta, define `GODOT` con el ejecutable `*_console.exe`. Cada paso tiene un límite de 300 s (`VERIFICAR_TIMEOUT`).

## Cómo leer el resultado

Una línea por paso: `OK`, `FALLO` o `AVISO`, con la última línea `RESULTADO` de cada prueba. Bajo un `FALLO` aparecen hasta 12 líneas con errores o `FAIL`, sin repetidas. La última línea es `RESUMEN`, y el código de salida es 0 si todo pasó.

Los avisos que AGENTS.md declara esperados se cuentan pero no hacen fallar: «2 teselas con tres terrenos degradadas» y el `Parameter "material" is null` de `test_plot_layout.gd` en headless. Si AGENTS.md añade otro aviso esperado, añádelo también a `ESPERADOS` en el script.

Si necesitas más detalle de un fallo, busca en `.local/verificacion/ultimo.log` con `grep` (por nombre de prueba o por el texto del error) en lugar de leer el archivo entero. Cada paso empieza con una línea `===== nombre (código N) =====`.

Un `AVISO` de versión significa que el ejecutable no es 4.7.2. No sigas adelante sin decírselo a Mario: AGENTS.md prohíbe cambiar de versión sin acuerdo.

## Lo que esta skill no comprueba

El arranque headless no valida el aspecto. Si el cambio es visual (cámara, sprites, profundidad, muros que tapan, agua, hierba, colores), dilo explícitamente al cerrar la tarea. Propón a Mario las comprobaciones a mano de AGENTS.md, o ejecuta las capturas de `tests/capture_*.gd` con ventana (sin `--headless`); lee antes la cabecera de cada script para saber dónde deja las imágenes.

## Al informar

Sigue el cierre de AGENTS.md: cambios hechos, comprobaciones ejecutadas con su resultado y limitaciones. Copia el bloque de resumen del script tal cual, sin añadir la salida completa. Nunca presentes como hecha una prueba manual, una captura revisada o una exportación que no se ha realizado.
