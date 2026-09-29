# Casa del laboratorio viejo (old_laboratory)

## Lo que usa el juego

`scenes/village/props/laboratorio_viejo.tscn`, un `VillageProp` con:

| Archivo (`assets/game/`) | Qué es |
|---|---|
| `models/old_laboratory/casa_laboratorio.obj` | El `.obj` del 28 de septiembre, sin tocar. 2576 caras de vóxel, 256 × 192 × 128 vóxeles, fachada hacia +Z |
| `models/old_laboratory/casa_laboratorio_atlas.png` | Atlas de 1024 × 512 **rehecho** por `tools/build_old_lab_atlas.gd` (ver abajo) |
| `materials/old_lab_pixel.tres` | Material con filtrado *nearest*, como el de la farola |

Va a **32 téxeles por unidad** (1 px por téxel, como los bloques y los árboles):
mide 8 × 6 × 4 casillas y ocupa 8 × 4. La puerta mide 80 téxeles y el personaje
unos 45 px. La colisión es la caja entera de la casa.

El `.obj` ya viene en unidades (1 vóxel = 1/32), así que se importa con
**Scale Mesh 1**, no 0,03125. Además lleva LOD apagado (simplificaría los
peldaños del tejado) y la compresión de malla apagada (movía los vértices hasta
0,005 téxeles).

## El atlas que faltaba

`casa_laboratorio.mtl` pide `casa_laboratorio_atlas.png`, pero la exportación
llegó sin él. El `.obj` sale de tallar las seis vistas de
`casa_pixzels_ortho.png` (frente, este, trasera, oeste, planta y suelo, en
celdas de 256 × 256). Medido: los 224 108 téxeles de sus caras caen todos sobre
un píxel opaco de la vista de su lado. Así que el atlas se rehace sin inventar
nada: cada téxel de cada cara copia el píxel de la vista hacia la que mira. La
herramienta falla si una cara no cuadra, si dos se pisan en el atlas o si sale un
color que no está en `casa_laboratorio.gpl`.

    Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tools/build_old_lab_atlas.gd

Si una exportación nueva trae su propio atlas, se copia junto al `.obj` y no hace
falta la herramienta.

**Lo que se ve raro:** los peldaños del tejado inclinado son vóxeles, y su cara
de delante (1 téxel de alto) toma el color de la vista de frente, no de la planta.
Sobre la claraboya se ven dos líneas finas por eso. Se arregla en el modelo, no
en el atlas.

## Fuentes

| Archivo | Qué es |
|---|---|
| `casa_pixzels_ortho.png` | Las seis vistas para PixZels (21:52). **Es la que vale**: retoca las vistas sueltas |
| `casa_frente.png`, `casa_lateral_este.png`, `casa_lateral_oeste.png`, `casa_trasera.png`, `casa_planta.png` | Vistas sueltas anteriores (20:48) |
| `casa_laboratorio.gpl` | Paleta de 41 colores. Todas las vistas y el atlas la cumplen |
| `casa_laboratorio.obj/.mtl` | Copia de la exportación original |

Las imágenes de referencia de Codex no se han copiado.
