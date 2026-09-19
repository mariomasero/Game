# Terminal — fuente de arte pixel art

Modelo propio creado para este proyecto el 16 de septiembre de 2026. Referencia de formas y paleta: escritorio y PC ya aportados por el usuario; sus PNG se conservan intactos. La geometría y el atlas nuevo están hechos para esta muestra.

## Archivos editables

- `terminal.blend`: fuente principal del modelo, UV y textura empaquetada. Abrir en Blender; no requiere addons.
- `terminal_atlas.svg`: atlas editable sobre cuadrícula de 128×128, formado por rectángulos de píxeles enteros.
- `terminal_atlas.png`: rasterización del SVG. El GLB también incorpora la textura.
- `build_terminal.py`: receta inicial de autoría. Se niega a sobrescribir el `.blend`; no se usa para exportar cambios normales.
- `export_terminal.py`: exporta la fuente existente a `assets/game/models/terminal.glb` y su textura a `assets/game/textures/terminal_atlas.png`.

La fuente final contiene 18 mallas, 216 triángulos antes de cualquier procesamiento del importador, 1 material y 1 atlas. Origen a los pies, escala aplicada, huella de 2,1×1,1 y altura máxima 1,85 unidades. Frente en +Z de Godot. La fuente `.blend` está en Z arriba y el exportador hace la conversión. Las fuentes están excluidas de la importación Godot con `.gdignore`.

## Editar geometría y reexportar

Modificar y guardar `terminal.blend` en Blender. Desde la raíz del proyecto, con Blender 5.2.1 instalado:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup assets/source/terminal/terminal.blend --python-exit-code 1 --python assets/source/terminal/export_terminal.py
godot --headless --path . --editor --quit
godot --headless --path . --script tests/test_laboratory_3d.gd
```

`--factory-startup` evita cargar addons de la configuración personal en este proceso. `--python-exit-code 1` hace visible un error del script al shell. Ajustar únicamente la ruta al ejecutable en otro equipo.

## Editar el atlas SVG

Después de modificar el SVG, rasterizar y actualizar **explícitamente** la textura empaquetada del `.blend`:

```powershell
godot --headless --path . --script assets/source/terminal/rasterize_atlas.gd
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup assets/source/terminal/terminal.blend --python-exit-code 1 --python assets/source/terminal/export_terminal.py -- --refresh-atlas
godot --headless --path . --editor --quit
```

Sin `--refresh-atlas`, la exportación usa la imagen guardada dentro del `.blend`. Así se conservan posibles retoques de textura realizados directamente en Blender. Con la opción, el PNG rasterizado pasa a ser la fuente de textura y se guarda empaquetado en el `.blend`.

## Integración y filtrado

`scenes/lab/terminal_3d.tscn` contiene interacción, colisiones e indicador. Su hijo `Model` instancia el GLB. Reexportar no modifica esos nodos.

La configuración nativa `terminal.glb.import` vincula el material `TerminalPixelPalette` a `assets/game/materials/terminal_pixel.tres`: nearest, sin mipmaps en el muestreo, sin iluminación que altere la paleta. El volumen se describe mediante colores de las caras y bordes de la textura. Mantener el nombre del material al editar. La textura de juego se exporta desde la imagen del `.blend`, por lo que ambos flujos anteriores actualizan también el material externo de Godot.

Godot puede extraer otra copia del atlas junto al GLB (`terminal_terminal_atlas.png`); la textura usada por el material externo es `assets/game/textures/terminal_atlas.png`.

## Reimportación comprobada

Se exportó una primera versión, se integró y pasó la suite. Después se amplió el piloto verde del monitor en el `.blend` y se reexportó (revisión 2). La nueva geometría llegó a Godot; la escena contenedora, el script y el indicador conservaron sus hashes. La suite actual comprueba colisiones, terminal, UI y el indicador flotante.
