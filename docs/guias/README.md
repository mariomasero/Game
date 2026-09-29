# Guías para montar el pueblo

Guías para aprender a construir los escenarios del juego **solo con el editor de
Godot**, sin programar. Están pensadas para leerlas en orden la primera vez y
volver luego a la que haga falta.

| Guía | Qué aprendes | Tiempo aproximado |
|---|---|---|
| [01 · Primeros pasos en el editor](01-primeros-pasos-editor.md) | Los paneles, moverte por la vista 3D, qué son nodos y escenas, guardar y probar | 20 min |
| [02 · Pintar el mapa](02-pintar-el-mapa.md) | Pintar hierba, tierra y adoquín; poner muros y escalones; marcar la parcela del laboratorio | 30 min |
| [03 · Añadir objetos 3D](03-anadir-objetos-3d.md) | Convertir un modelo tuyo (árbol, casa, mesa…) en un objeto del pueblo o en un mueble de la parcela, y colocarlo | 40 min |
| [04 · Aprender más](04-aprender-mas.md) | Enlaces a la documentación oficial, un camino de aprendizaje y un glosario | — |

## Lo esencial en una tabla

| Quiero… | Hago… |
|---|---|
| Abrir el pueblo | Doble clic en `scenes/world/village.tscn` en el panel Sistema de archivos |
| Pintar el suelo | Selecciono el nodo **Terreno**, elijo un terreno en la paleta y pinto con **E** |
| Poner muros o escalones | Selecciono **Bloques**, elijo un bloque y pinto; con **1** y **3** bajo y subo de planta |
| Poner un árbol o una casa | Arrastro su escena `.tscn` encima del nodo **Objetos**, o lo selecciono y la suelto en la vista 3D con **Mayús** |
| Marcar la zona del laboratorio | Selecciono **Parcela** y pinto con **E** |
| Poner un mueble del laboratorio | Arrastro su escena encima de **Muebles**, dentro de lo amarillo. Antes tiene que tener su ficha en el catálogo (guía 03) |
| Ver cómo quedará el suelo | Oculto **Terreno** con el icono del ojo |
| Probarlo jugando | **F6**, que ejecuta la escena abierta; **F8** para parar |
| Deshacer | **Ctrl+Z** |
| Guardar | **Ctrl+S** |

## Qué hay detrás (por si tienes curiosidad)

Todo lo que usas es de Godot: el pincel de GridMap, la paleta, el arrastrar y
soltar y el Inspector. Hay tres piezas escritas para este proyecto que trabajan
solas mientras usas esas herramientas:

- `scenes/world/village.gd` lee lo que pintas y construye el suelo con las
  transiciones entre terrenos, igual en el editor que en el juego.
- `scenes/village/props/village_prop.gd` pone tus objetos a la escala exacta del
  píxel y los encaja en la rejilla.
- `tools/build_paint_library.gd` genera las paletas de terrenos, bloques y
  parcela.
- `scripts/domain/plot_layout.gd` lleva la cuenta de qué mueble ocupa cada casilla
  de la parcela.

No tienes que abrirlas nunca. Por qué funciona así lo explica
[la decisión 013](../decisions/013-mapa-autorado-con-gridmap.md).
