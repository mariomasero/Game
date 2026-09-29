---
name: integrar-bloque-pixzels
description: Lleva un bloque nuevo o actualizado de PixZels desde la carpeta de exportación de Mario hasta el juego — copiar y renombrar el atlas, guardar las fuentes editables, corregir la orientación de la cara superior, material e importación a píxel exacto, añadirlo a la biblioteca de pintura del GridMap y verificarlo. Úsala siempre que Mario diga que ha hecho, exportado o retocado un bloque, que quiere un bloque nuevo en el pueblo, o mencione PixZels, un *_model_atlas.png o la carpeta Game!\assets\blocks.
---

# Integrar un bloque de PixZels

AGENTS.md («Arte y assets» y «Herramientas de autoría») define este proceso. Tiene varios pasos fáciles de olvidar, y saltarse uno deja un bloque girado, borroso o con un id cambiado.

## Antes de empezar

1. Pregunta a Mario el **nombre del bloque** en `snake_case` si no lo ha dicho (por ejemplo `stone_bricks`). Ese nombre fija todas las rutas.
2. Pregunta si es un **bloque nuevo** o la **actualización** de uno existente. En una actualización no se toca la tabla `BLOQUES`.
3. No modifiques los píxeles del atlas. La única transformación permitida es la de `tools/fix_block_atlas_orientation.gd`, que AGENTS.md exige porque PixZels hornea la cara superior rotada.

## Pasos

**1. Localizar lo exportado.** Los bloques llegan a `C:\Users\mario\Documents\Game!\assets\blocks` (en Git Bash, `'/c/Users/mario/Documents/Game!/assets/blocks'`, entre comillas simples por el `!`). Lista la carpeta y confirma con Mario qué archivos corresponden al bloque. Allí el atlas se llama `*_model_atlas.png`.

**2. Copiar, nunca mover.** La carpeta de origen es de Mario.
- Atlas de juego: `assets/game/tilesets/<bloque>_block_atlas.png`.
- Fuentes editables (proyecto de PixZels, `.aseprite` y cualquier otro original): `assets/source/tilesets/<bloque>/`. Si no sabes qué archivo es la fuente editable, pregunta.

**3. Corregir la orientación.** Lee primero la cabecera de `tools/fix_block_atlas_orientation.gd` para ver cómo se invoca y qué argumentos espera; no los supongas. Se ejecuta con `"$G" --headless --path . --script tools/fix_block_atlas_orientation.gd …`. Comprueba en su salida que ha procesado el atlas nuevo. En una actualización, pásala solo si el atlas vuelve a venir de PixZels sin corregir.

**4. Importación.** Ejecuta la importación del editor (`"$G" --headless --path . --editor --quit`) para que Godot cree el `.import`. Compara ese `.import` con el de un atlas existente, por ejemplo el de `grass`, y deja los mismos ajustes que exige AGENTS.md: `compress/mode=0`, sin mipmaps y `detect_3d/compress_to=0`.

**5. Material.** Los bloques existentes usan `village_pixel.tres` y `summer_grass_pixel.tres`. Averigua cómo llega el atlas al material. Si es un material por bloque, crea el nuevo copiando el patrón de uno existente, con filtrado *nearest* en el material (en Godot 4 no vive en el importador). Si hay una tabla o convención de nombres, síguela. No inventes parámetros de sombreado nuevos.

**6. Biblioteca de pintura (solo bloques nuevos).** Añade el bloque **al final** de la tabla `BLOQUES` de `tools/build_paint_library.gd`: el id de cada bloque es su posición y reordenar rompe los mapas ya pintados. Luego ejecuta la herramienta para regenerar `assets/game/tilesets/paint_*.meshlib.tres` y revisa con `git diff --stat` que solo cambian las bibliotecas esperadas.

**7. Atribución.** Si el bloque parte de un asset de terceros, pregunta a Mario si hay que añadir algo a `ATTRIBUTION.md`.

**8. Verificar.** Usa la skill `verificar-godot` completa. La guarda de píxel y `test_village_map.gd` son las que más importan aquí.

**9. Documentación.** Propón a Mario una línea para la sección de estado de AGENTS.md que diga qué bloque se añadió y con qué material. No edites AGENTS.md sin su visto bueno.

## Al cerrar

Explica a Mario en lenguaje sencillo cómo verlo: abrir `scenes/world/village.tscn`, elegir el bloque en el GridMap `Bloques` y pintarlo, y probar con F6. Recuérdale que las comprobaciones headless no validan el aspecto: tiene que mirar él que la cara superior está bien orientada y que el bloque se ve nítido.
