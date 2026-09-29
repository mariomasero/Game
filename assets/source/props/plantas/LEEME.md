# Plantas (arbustos, hierbas, flores, setas y rocas)

Dibujos de Mario, llegados el 29 de septiembre de 2026 a `Game!\assets\props\plantas`
(fuera del repositorio) en dos versiones: `original` y `paleta_casa`, la misma
hoja pasada a la paleta del proyecto.

| Archivo | Qué es |
|---|---|
| `plantas.json` | Ficha de las 53 plantas: nombre, categoría, lienzo, tamaño del dibujo y pie (`pie_px`, siempre en el centro de la fila de abajo). La lee `tools/build_plants.gd` |
| `hoja_completa_paleta_casa.png` | La hoja entera en la paleta del proyecto, de donde salieron los recortes del juego |
| `hoja_completa_original.png`, `original/` | La hoja y los recortes con los colores de partida (92 colores, casi ninguno de la paleta). Solo como referencia: el juego no los usa |

El juego usa copias sin tocar de los recortes de `paleta_casa`:
`assets/game/textures/plantas/<nombre>.png` (sin la carpeta `@8x`, que es una
vista ampliada).

## Paleta: por qué `paleta_casa`

- `paleta_casa` usa 50 colores, todos de `apollo_proyecto.gpl`. `original` usa 92
  y casi ninguno lo está. La regla del proyecto (AGENTS.md, «Arte y assets») obliga
  a usar la paleta.
- A la vista, `original` tiene verdes más oscuros y se despega más del césped;
  `paleta_casa` usa los mismos verdes que el césped y la hierba, así que la
  planta parece crecer del suelo. Con la luz del juego las dos se leen bien.
- Los amarillos de `arbusto_flores_amarillas`, `dientes_de_leon` y
  `flores_amarillas` (`#d99a1c`, `#f0c832`, `#f7e27a`) no estaban en la paleta:
  Apollo no tiene amarillo limón y los ocres más cercanos dejaban las flores
  anaranjadas. Mario los añadió a la paleta el 29 de septiembre como Amarillo 1,
  2 y 3.

## Cómo llegan al juego

`tools/build_plants.gd` escribe por cada planta un material
(`assets/game/materials/plantas/`) y una escena `VillageProp`
(`scenes/village/props/plantas/`). Se vuelve a ejecutar si cambia un dibujo o la
ficha; las escenas se sobrescriben, así que lo que se ajusta va en las tablas del
principio de la herramienta:

- **Viento** por categoría: arbustos poco y despacio, hierbas y flores más, setas
  y rocas quietas. Lo dibuja `assets/game/shaders/plant_sway.gdshader`, con la
  flexión del árbol: cada fila se desplaza téxeles enteros, más cuanto más arriba.
- **Qué estorba**: los arbustos y las rocas grandes (`roca_musgo`, `roca_plana`,
  `roca_grande_musgo`, `roca_alta`) llevan colisión y ocupan las casillas de su
  ancho (un arbusto grande, 3). Lo demás es `atravesable`: el personaje lo cruza.

## Tamaño

Van a 1 px de pantalla por téxel, como el árbol. El personaje mide unos 36 px, así
que una flor (unos 34 px) sale casi de su altura, una hierba alta (unos 50 px) algo
más, y un arbusto grande (unos 70 px) le dobla. Para una planta más pequeña hay que
redibujarla a menos resolución: escalarla rompería el píxel.

## Si se repinta

- Mantén el lienzo de ancho par y el pie en el centro de la fila de abajo.
- Sin semitransparencias y con los colores de `apollo_proyecto.gpl`.
- Si cambia el tamaño, actualiza su línea de `plantas.json` (`lienzo` y `objeto`)
  y vuelve a ejecutar la herramienta.
