# Árbol (tree)

Dibujo de Mario, llegado el 24 de septiembre de 2026 a `Game!\assets\props`
(fuera del repositorio).

| Archivo | Qué es |
|---|---|
| `trees-pixelart_canopy.png`, `trees-pixelart_trunk.png` | Las dos capas, 137 × 185, mismo lienzo y encajadas al téxel. Versión del 27 de septiembre: las ramas que se ven entre las hojas pasan de la copa al tronco (sube hasta la fila 32); la copa queda solo con verdes |

La imagen de partida en alta resolución (`trees.png`) y el árbol completo en una
sola capa (`trees-pixelart.png`) se borraron el 29 de septiembre por petición de
Mario: no se usaban.

El juego usa copias sin tocar de las capas: `assets/game/textures/tree_canopy.png`
y `tree_trunk.png`. Las lee `assets/game/shaders/tree_sway.gdshader`, que las mueve
con el viento desplazando téxeles enteros; la escena es
`scenes/village/props/arbol.tscn`.

## Tamaño

Va a 1 px de pantalla por téxel, igual que bloques y suelo: 185 px de alto, unas
seis veces el personaje. Es la única escala a píxel exacto que no lo agranda; para
un árbol más pequeño hay que redibujarlo a menos resolución.

## Si se repinta

- Mantén las dos capas del mismo tamaño y encajadas. Donde la copa tapa al tronco,
  el tronco puede seguir dibujado: asoma cuando las hojas se apartan.
- Las ramas van mejor en el tronco que en la copa: el tronco solo se dobla con el
  árbol entero, y las hojas se agitan por encima de las ramas. Lo marrón que quede
  en la copa se agita con las hojas.
- Si cambian el tamaño del lienzo, la fila del suelo, la punta de la copa o el pie
  del tronco, hay que ajustar `rect_min`, `rect_size`, `top_row` y la copa en
  `tree_pixel.tres` y el `QuadMesh` de `arbol.tscn`. `tests/test_tree.gd` avisa si no cuadran.
- Los destellos cambian cuatro tonos de la copa al sol por el siguiente. Cada uno
  se da con un téxel que lo tiene (`lit_texel_0..3` en
  `assets/game/materials/tree_pixel.tres`, de oscuro a claro). Si repintas la copa,
  comprueba que esos téxeles siguen siendo de esos tonos; la prueba avisa si no
  son de la copa o no van de oscuro a claro.
