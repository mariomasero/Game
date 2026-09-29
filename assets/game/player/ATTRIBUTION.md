# Sprites del personaje

Original character template created by **Eris Esra**: https://erisesra.itch.io/character-templates-pack

Condiciones completas en [CHARACTER-LICENSE.txt](../../../docs/distribution/licenses/CHARACTER-LICENSE.txt),
copia literal del «Read Me.txt» del paquete: se permite su uso en proyectos
comerciales y no comerciales; no se permite revender las plantillas como
paquetes, con añadidos o modificadas. El crédito es obligatorio si el producto
es gratuito y agradecido en cualquier caso, así que se mantiene siempre.

Los originales del paquete, incluidos los archivos Aseprite, están fuera del
repositorio en `Game!/assets/player/16x32/`. **No están bajo control de
versiones**: si esa carpeta se pierde, no se recuperan desde aquí.

## Integración

Copias sin modificaciones de las hojas del paquete:

| Archivo | Origen | Tamaño | Rejilla |
|---|---|---|---|
| `idle.png` | `16x32 Idle-Sheet.png` | 128 × 160 | 4 columnas × 5 filas |
| `walk.png` | `16x32 Walk-Sheet.png` | 128 × 160 | 4 columnas × 5 filas |
| `run.png` | `16x32 Run-Sheet.png` | 192 × 160 | 6 columnas × 5 filas |

`walk.png` ya no es copia literal: tiene 34 píxeles repintados por el usuario en
el cuarto fotograma de la fila `up_side`.

Aunque el personaje se denomine 16×32, su lienzo por fotograma es **32×32**, tal
como indica la licencia original.

**Filas:** abajo, abajo/derecha, derecha, arriba/derecha, arriba. Las
orientaciones hacia la izquierda usan reflejo horizontal. Orden contrastado con
los tags de los Aseprite originales y con revisión renderizada.

**Tiempos:** 10 FPS en bucle, los 100 ms por fotograma del Aseprite. Andar son
cuatro fotogramas por dirección; correr, seis.

**Correr** multiplica la velocidad por 1,8 y la cadencia por lo mismo, de modo
que el terreno recorrido por fotograma es idéntico al de andar (0,320 unidades
medidas en ambas) y los pies no patinan. La zancada sale 1,5 veces más larga y
la cadencia 1,2 veces más rápida, que es lo que hace correr de verdad.

**Presentación actual:** `pixel_size` 0,0625, es decir 2 téxeles del sprite por
celda del mundo, con lo que el dibujo mide 32 × 50 píxeles en pantalla (un
bloque de ancho) y su lienzo abarca 64 × 64 (dos bloques de alto). Filtrado
nearest, pivote a los pies, compensación vertical 1/cos(inclinación) para
contrarrestar el escorzo de la cámara. Cápsula de colisión de radio 0,35 y disco
de sombra de 24 píxeles de diámetro, ambos derivados del dibujo en tiempo de
ejecución.

**Importación:** las tres hojas van con `compress/mode=0`, `mipmaps/generate=false`
y `detect_3d/compress_to=0`. Esa última línea es obligatoria: sin ella Godot
recomprime la textura a VRAM en cuanto detecta uso en 3D y destroza el pixel
art. Ya ocurrió con `idle.png`.

Jump, Attack, Rotate e Interact siguen disponibles en el paquete original y sin
integrar; no hay mecánicas para ellas.

Recurso editable en Godot: `scenes/player/player_frames.tres`. No hay plugin
importador ni generación de recursos durante el juego.
