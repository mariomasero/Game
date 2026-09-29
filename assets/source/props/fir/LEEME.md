# Abeto (fir)

Dibujo de Mario, llegado el 27 de septiembre de 2026 a `Game!\assets\props`
(fuera del repositorio), como «segundo árbol».

| Archivo | Qué es |
|---|---|
| `trees2-pixelart_canopy.png`, `trees_2-pixelart-trunk.png` | Las dos capas, 122 × 234, mismo lienzo y encajadas al téxel. El tronco solo está dibujado donde asoma entre los pisos de ramas |

El juego usa copias sin tocar de las capas: `assets/game/textures/fir_canopy.png`
y `fir_trunk.png`. Las mueve `assets/game/shaders/tree_sway.gdshader` con los
valores de `assets/game/materials/fir_pixel.tres`; la escena es
`scenes/village/props/abeto.tscn`.

Copa sobre tronco daba el abeto completo (`trees_2-pixelart.png`) salvo **2 píxeles
de contorno** que faltan en las dos capas: columna 44, filas 132 y 133 (en el
completo eran `#000a0c` y `#170c0f`). No se han añadido: el arte es de Mario.

La imagen de partida en alta resolución (`trees_2.png`) y el abeto completo en una
sola capa se borraron el 29 de septiembre por petición de Mario: no se usaban.

## Viento

Un abeto es más rígido y más alto que el árbol frondoso: oscila más despacio
(`sway_frequency` 0,22) y algo más en la punta, y sus racimos son pisos de ramas
anchos y bajos (`rustle_size` 16 × 5) que suben y bajan casi tanto como se
apartan (`rustle_axes`). El borde que más se agita es el de las puntas de las
ramas, lejos del tronco (`crown_radius` muy alto en vertical).

## Si se repinta

Lo mismo que para el árbol frondoso (`assets/source/props/tree/LEEME.md`): capas
del mismo tamaño, y si cambian el lienzo, la fila del suelo, la punta o los tonos
al sol, ajustar `fir_pixel.tres` y el `QuadMesh` de `abeto.tscn`.
