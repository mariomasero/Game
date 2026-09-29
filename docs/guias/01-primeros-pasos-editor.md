# 01 · Primeros pasos en el editor

En esta guía aprendes a moverte por Godot. No hace falta que lo memorices: vuelve
aquí cuando se te olvide algo.

## Abrir el proyecto

1. Abre `C:\Users\mario\Desktop\Godot\Godot_v4.7.2-stable_win64.exe`.
2. En el gestor de proyectos, haz doble clic en **Biotech — Laboratorio**. Si no
   aparece, pulsa **Importar** y elige el archivo `project.godot` de la carpeta
   `Game!\biotech`.

> Si el editor está en inglés y lo prefieres en español: **Editor → Editor
> Settings → Interface → Editor → Editor Language → es**, y reinícialo. En estas
> guías pongo el nombre en español y, entre paréntesis, el inglés cuando cambia
> mucho.

## Los cuatro paneles que vas a usar

```
┌──────────────┬────────────────────────────────┬──────────────┐
│ Escena       │                                │ Inspector    │
│ (árbol de    │         Vista 3D               │ (propiedades │
│  nodos)      │    (donde ves y colocas)       │  del nodo    │
├──────────────┤                                │  que tengas  │
│ Sistema de   │                                │  elegido)    │
│ archivos     ├────────────────────────────────┤              │
│ (FileSystem) │  Panel inferior (Salida, GridMap…)            │
└──────────────┴────────────────────────────────┴──────────────┘
```

- **Escena**: la lista de *nodos* de la escena abierta. Al hacer clic en uno lo
  seleccionas. El **ojo** que hay a su derecha lo oculta o lo muestra en el editor.
- **Sistema de archivos**: las carpetas del proyecto. Desde aquí se abren escenas
  con doble clic y se arrastran cosas a la vista 3D. Lo que sueltas en la vista
  queda *al lado* del nodo seleccionado; con **Mayús** queda *dentro* de él.
- **Inspector**: las propiedades del nodo seleccionado, como su posición o su
  material. Aquí aparecen también las opciones propias del proyecto, como
  «Ajustar A Rejilla» en los objetos.
- **Vista 3D**: el mundo. Arriba del todo, los botones **2D / 3D / Script** cambian
  de vista. Si ves otra cosa, pulsa **3D**.
- **Panel inferior**: **Salida** (Output) muestra avisos y errores. Cuando
  seleccionas un GridMap, aparece aquí la paleta para pintar.

## Moverte por la vista 3D

| Acción | Cómo |
|---|---|
| Girar alrededor | Arrastra con el **botón central** (la rueda pulsada) |
| Desplazarte | **Mayús + botón central** y arrastra |
| Acercar o alejar | **Rueda** del ratón |
| Volar (vista libre) | Mantén el **botón derecho** y usa **W A S D**; **E** sube y **Q** baja; **Mayús** va más rápido |
| Centrar en lo seleccionado | **F** con el ratón sobre la vista |
| Vista desde arriba | **7** del teclado numérico |

Si te pierdes, selecciona un nodo en el panel Escena, pon el ratón sobre la vista
y pulsa **F**.

## Nodos, escenas y recursos

- Un **nodo** es una pieza con una función: una luz, una cámara, un cuerpo que
  choca… En el panel Escena ves cómo se anidan: un nodo *hijo* se mueve con su
  *padre*.
- Una **escena** (`.tscn`) es un grupo de nodos guardado en un archivo. El pueblo
  es una escena, el personaje es otra y cada árbol que hagas será otra. Una escena
  puede meterse dentro de otra: a eso se le llama **instanciar**. Si cambias la
  escena del árbol, cambian todos los árboles del pueblo.
- Un **recurso** (`.tres`, `.png`, `.obj`…) son datos que usan los nodos: un
  material, una textura, un modelo o una paleta de bloques.

## Guardar, deshacer y probar

| Acción | Atajo |
|---|---|
| Guardar la escena | **Ctrl+S** |
| Deshacer / rehacer | **Ctrl+Z** / **Ctrl+Mayús+Z** |
| Probar la escena abierta | **F6** |
| Probar el juego desde la escena principal | **F5** |
| Parar la prueba | **F8**, o cierra la ventana del juego |

**F5 y F6 no hacen lo mismo.** La escena principal del proyecto es todavía la sala
de pruebas (`test_room.tscn`). Para probar el pueblo, ábrelo y pulsa **F6**.

Cuando quieras que el pueblo sea lo primero que se abre: clic derecho sobre
`scenes/world/village.tscn` en Sistema de archivos → **Establecer como escena
principal** (Set as Main Scene).

## Ver lo mismo que verá la cámara del juego

1. En el panel Escena, selecciona **Camera3D**.
2. Arriba a la izquierda de la vista 3D aparece la casilla **Vista previa**
   (Preview). Márcala.
3. Ahora la vista 3D muestra justo el encuadre del juego. Desmárcala para volver a
   moverte libremente. El atajo es **Ctrl+P**.

## Comprueba que lo has entendido

1. Abre `scenes/world/village.tscn` con doble clic.
2. Gira, desplázate y acércate por la vista 3D.
3. Selecciona **Player**, pulsa **F** y mira su posición en el Inspector (Transform
   → Position).
4. Activa la vista previa de **Camera3D** y vuelve a quitarla.
5. Pulsa **F6**, anda con **WASD** o las flechas (con **Mayús** corres) y cierra
   con **F8**.

Siguiente: [02 · Pintar el mapa](02-pintar-el-mapa.md).
