# Valla de hierro (metal_fence)

## Lo que usa el juego: piezas provisionales

`scenes/village/props/metal_fence.tscn` es una valla que **se une sola**: suelta
es solo el poste, y si hay otra valla en la casilla de al lado (en X o en Z, no en
diagonal) a cada una le sale un tramo hacia la otra. Dos vallas juntas forman un
paño de 64 téxeles de largo y 32 de alto. El código está en
`scenes/village/props/village_fence.gd`.

Las piezas son **provisionales**, generadas por `tools/build_fence.gd` con los 7
colores de la exportación de PixZels:

| Archivo (`assets/game/models/metal_fence/`) | Qué es |
|---|---|
| `fence_post.obj` | El poste: 8 × 32 × 8 téxeles, centrado en su casilla |
| `fence_rail.obj` | Un tramo hacia +X: del fuste (x = 3) al borde de la casilla (x = 16), con dos travesaños, un barrote y medio barrote en el borde, que se junta con el de la vecina |
| `fence_atlas.png` | Tira de 7 × 1 con los colores; cada cara es de un solo color |

Las coordenadas van en téxeles, con el origen en el centro de la casilla y a ras
de suelo. Una casilla va de −16 a 16 en X y en Z.

### Cambiarlas por piezas de PixZels

1. Haz en PixZels el poste y el tramo a 32 vóxeles por casilla, con esas mismas
   medidas: el poste centrado y el tramo desde el poste hasta el borde de la
   casilla, hacia +X.
2. Exporta como OBJ y guárdalas encima de `fence_post.obj` y `fence_rail.obj`, o
   con otro nombre y cambia la ruta en `metal_fence.tscn` y en `village_fence.gd`
   (`TRAMO_MALLA`).
3. Cada `.obj` va con **Scale Mesh 0,03125** en la pestaña Importar, y su atlas con
   el material `assets/game/materials/metal_fence_pixel.tres`.
4. Pide que se compruebe: `tests/test_village_map.gd` mide que el poste tenga 32
   de alto y que dos tramos se toquen justo en el borde.

## La exportación de PixZels del 28 de septiembre

| Archivo | Qué es |
|---|---|
| `metal_fence.obj/.mtl`, `metal_fence_atlas.png` | Exportación de las 20:08, sin tocar. 85 × 70 × 15 vóxeles, atlas de 161 × 183 |
| `front.png`, `side.png`, `top.png` | Vistas de referencia de partida |
| `*-pixelart.png` | Las tres vistas ya en píxel (85 × 70, 15 × 70, 85 × 15) |

Está a píxel exacto y usa 7 colores más el transparente: negro de contorno, cuatro
grises (39,40,44 · 45,46,50 · 53,55,60 · 85,88,94) y dos brillos (173,171,172 ·
246,242,241). **No se usa en el juego**: medía 70 píxeles de alto y 2,66 casillas
de ancho, y la valla tiene que medir 32. Reducirla a 32 × 32 rompía el contorno
y los barrotes (probado el 28 de septiembre).
