# Farola (street_lamp)

Modelo de Mario, hecho en PixMesh el 24 de septiembre de 2026. La exportación
original llegó a `Game!\assets\props\street_lamp` (fuera del repositorio).

| Archivo | Qué es |
|---|---|
| `a-blocky-street-lamp-with-a-cylindrical.obj/.mtl/_atlas0.png`, `street_lamp.glb` | Exportación original de PixMesh, sin tocar. 1,94 unidades de alto, atlas de 64 × 32 a **16 téxeles por unidad** |
| `street_lamp.blend` | Fuente editable para Blender y Pixel Art Studio, ya con el poste alargado |

El juego usa `assets/game/models/street_lamp/street_lamp.obj` y
`street_lamp_atlas.png` (64 × 64).

## Cambio respecto a la exportación

A petición de Mario, **solo se alargó el poste**: de 31 a **48 téxeles de alto**
(3 casillas). El poste crece 17 téxeles por encima del collar del medio. La base,
el collar, la escuadra y el farol no cambian de forma, pero lo que está por encima
del collar sube 1,0625 unidades. Primero se hizo de 64 (4 casillas), pero en el
juego medía 128 px frente a los ~38 del personaje y Mario eligió 3 casillas.

El brazo empezaba dentro del remate del poste y a su misma altura, así que sus
caras coincidían en un plano. Ahora empieza en la cara exterior del remate, con
su UV recortada lo mismo.

Para no estirar los píxeles, el poste tiene una tira nueva de 37 × 4 en las filas
32–35 del atlas, que pasa de 64 × 32 a 64 × 64 con el contenido original arriba.
La tira es la del poste original con su columna lisa gris repetida 17 veces.
Conserva el óxido de abajo, la línea oscura sobre el collar y el óxido bajo el
remate. Todas las caras siguen a 16 téxeles por unidad (medido en las 792 aristas).

## Tamaño del píxel

A 16 téxeles por unidad, cada téxel de la farola mide 2 × 2 px en pantalla, el
doble que los bloques, que van a 32. El personaje sale a 1,2 px por téxel. Mario
lo eligió así: solo se alarga el poste, sin cambiar la resolución.

## Repintar en Blender con Pixel Art Studio

1. Abre `street_lamp.blend`. La textura apunta al atlas del juego
   (`assets/game/models/street_lamp/street_lamp_atlas.png`), con interpolación
   *Closest*.
2. En Pixel Art Studio, la densidad que detecta debe ser **16 píxeles por unidad**.
   No la cambies o dejará de casar con el modelo.
3. Pinta y guarda la imagen: en el Editor de imágenes, **Imagen → Guardar**
   (Alt+S). Al volver a Godot se reimporta sola.
4. Si cambias la **forma** (vértices o UV), exporta de nuevo como OBJ encima de
   `assets/game/models/street_lamp/street_lamp.obj`, con **Forward −Z** y **Up Y**,
   sin materiales. Después pide que se compruebe.

Usa solo los colores que ya tiene el atlas, o los de una paleta acordada.
