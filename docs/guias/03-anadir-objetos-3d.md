# 03 · Añadir objetos 3D: árboles, casas y demás

Los bloques del GridMap sirven para muros y terreno. Todo lo que tenga forma
propia, como un árbol, una casa, una farola o una valla, es un **objeto**: una
escena pequeña que haces una vez y luego colocas en el pueblo tantas veces como
quieras.

El proyecto trae dos escenas en `scenes/village/props/` para empezar:

- `_plantilla_objeto.tscn`: la **plantilla vacía** que duplicas para cada objeto
  nuevo.
- `bloque_cesped.tscn`: un **ejemplo** ya hecho con el bloque de césped, para ver
  cómo funciona antes de usar arte tuyo.

## Cómo es un objeto por dentro

```
Objeto          ← la raíz. Se encarga sola de la escala, el encaje y la colisión
├─ Modelo       ← aquí dentro va tu modelo (.obj, .glb o una malla)
└─ Colision     ← el cuerpo con el que choca el personaje
   └─ Forma     ← la caja de colisión
```

La raíz hace sola tres cosas:

1. **Pone el modelo a la escala del píxel.** No escales nada a mano. Si tu modelo
   se hizo a 32 píxeles por casilla, en el juego se verá a píxel exacto.
2. **Apoya el modelo en el suelo y lo centra.**
3. **Lo encaja en la rejilla** cuando lo mueves en el editor, y deja los giros en
   pasos de 90°.

## Prueba primero con el ejemplo

1. Abre `scenes/world/village.tscn`.
2. En Sistema de archivos, busca `scenes/village/props/bloque_cesped.tscn`.
3. Tienes dos maneras de ponerlo:
   - **Arrástralo encima del nodo Objetos** en el panel Escena. Aparece en el
     centro y luego lo mueves.
   - O selecciona **Objetos**, **mantén Mayús** y suéltalo directamente en la
     vista 3D, donde lo quieras. Sin Mayús quedaría fuera de Objetos: Godot
     pone lo que sueltas *al lado* del nodo seleccionado, no dentro.
4. Con el objeto seleccionado, pon el ratón en la vista 3D y pulsa **W** para
   elegir Mover. Arrastra las flechas y verás que salta de casilla en casilla.
5. Pulsa **E** para elegir Rotar y gíralo sobre el eje vertical, el anillo verde.
   Se queda en 0°, 90°, 180° o 270°.
6. Guarda con **Ctrl+S** y prueba con **F6**. El personaje choca con el bloque.

> **W** y **E** hacen cosas distintas según lo que tengas seleccionado. Con un
> objeto, **W** mueve y **E** rota. Con un GridMap, **W** borra y **E** pinta.

## Paso a paso: tu propio objeto

Tomo como ejemplo un árbol hecho en PixZels. Con una casa o cualquier otra cosa
se hace igual.

### 1. Traer el modelo al proyecto

1. Crea una carpeta para él: en Sistema de archivos, clic derecho en
   `assets/game/` → **Nueva carpeta** → `models/arbol_roble`.
2. Copia ahí, desde el Explorador de Windows, el `.obj`, el `.mtl` y el `.png` que
   exporta PixZels. Godot los importa solo al volver a su ventana.
3. **Ajusta la textura para pixel art.** Selecciona el `.png` en Sistema de
   archivos y abre la pestaña **Importar** (Import), junto a Escena. Deja:
   - **Compress → Mode: Lossless**;
   - **Mipmaps → Generate: desactivado**;
   - **Detect 3D → Compress To: Disabled**.

   Pulsa **Reimportar**. Sin esto la textura sale borrosa o con colores raros.
   La prueba `tests/test_pixel_settings_guard.gd` avisa si se te olvida.
4. **Ajusta la escala del modelo.** Selecciona el `.obj` y, en **Importar**, pon
   **Scale Mesh** a `0.03125` en los tres ejes. Es 1/32: 32 vóxeles de PixZels
   pasan a medir una casilla. Pulsa **Reimportar**.

### 2. Hacer el material nítido

Godot suaviza las texturas por defecto, así que hace falta un material propio que
las mantenga nítidas:

1. En `assets/game/materials/`, clic derecho sobre `village_pixel.tres` →
   **Duplicar…** → llámalo `arbol_roble_pixel.tres`.
2. Haz doble clic en el nuevo material. En el Inspector, en **Albedo → Texture**,
   arrastra el `.png` del árbol.

Al duplicarlo conservas los ajustes de pixel art: filtro *Nearest* y sin brillo.

### 3. Crear la escena del objeto

1. Clic derecho sobre `scenes/village/props/_plantilla_objeto.tscn` →
   **Duplicar…** → llámala `arbol_roble.tscn`, sin guion bajo delante. Ábrela con
   doble clic.
2. Cambia el nombre de la raíz **Objeto** a **ArbolRoble**: doble clic sobre el
   nombre en el panel Escena.
3. Selecciona **Modelo** en el panel Escena. **Mantén Mayús** y arrastra el `.obj`
   desde Sistema de archivos a la vista 3D. Aparece dentro de Modelo un
   MeshInstance3D con la malla, y el modelo se coloca solo, apoyado en el suelo.
   Si ha quedado fuera de Modelo, arrástralo encima de Modelo en el panel Escena.
4. Selecciona ese hijo nuevo. En el Inspector, en **Surface Material Override → 0**,
   arrastra `arbol_roble_pixel.tres`.
5. Guarda con **Ctrl+S**.

### 4. Ajustar la colisión

Por defecto, la caja de colisión envuelve el modelo entero. En una casa está bien.
En un árbol, la copa frenaría al personaje antes de tiempo, así que conviene que
solo choque el tronco:

1. Selecciona la raíz (**ArbolRoble**) y, en el Inspector, **desmarca «Colision
   Automatica»**.
2. Selecciona **Colision → Forma**. En el Inspector, abre **Shape** (la
   BoxShape3D) y reduce **Size**, por ejemplo a `0.5, 1, 0.5`. También puedes
   arrastrar los puntos naranjas en la vista 3D.
3. Guarda.

Para ver las cajas de colisión mientras juegas: menú **Depurar → Formas de
colisión visibles** (Debug → Visible Collision Shapes) y luego **F6**.

### 5. Colocarlo en el pueblo

Igual que el ejemplo: en `village.tscn`, arrastra `arbol_roble.tscn` encima de
**Objetos**, o selecciona Objetos y suéltalo con **Mayús** en la vista 3D. Después
muévelo con **W** y gíralo con **E**. Para plantar varios, selecciona uno y pulsa
**Ctrl+D** para duplicarlo, y luego mueve la copia.

Si algún día cambias el árbol en `arbol_roble.tscn`, cambian todos los árboles del
pueblo a la vez.

## Muebles de la parcela

Los muebles, las mesas y las máquinas del laboratorio se hacen igual que cualquier
objeto, pero van en **Muebles** y no en **Objetos**, y siempre dentro de la
parcela, lo amarillo de la [guía 02](02-pintar-el-mapa.md#la-parcela-del-laboratorio-el-gridmap-parcela).
Así el juego sabe qué casillas ocupa cada uno. Es la base para que, más adelante,
el jugador pueda moverlos y comprar otros. Por ahora se colocan solo en el editor.

Cada mueble necesita una **ficha**, un pequeño archivo que dice cómo se llama y
cuántas casillas ocupa. Tomo como ejemplo una mesa de laboratorio de 2 × 1
casillas.

### 1. La escena del mueble

Hazla con los pasos 1 a 4 de arriba, por ejemplo
`scenes/village/props/mesa_laboratorio.tscn`.

### 2. La ficha

1. En Sistema de archivos, abre `resources/definitions/placeables/`.
2. Clic derecho sobre `bloque_cesped.tres` → **Duplicar…** → llámala
   `mesa_laboratorio.tres`.
3. Haz doble clic en la ficha nueva y rellena en el Inspector:

   | Campo | Qué poner | Ejemplo |
   |---|---|---|
   | **Id** | Un nombre único, en minúsculas y sin espacios. **No lo cambies después**: es lo que usarán las partidas guardadas | `mesa_laboratorio` |
   | **Nombre** | El nombre que verá el jugador | Mesa de laboratorio |
   | **Huella** | Casillas que ocupa sin girar: **x** es el ancho y **y** el fondo | x = 2, y = 1 |
   | **Escena** | Arrastra aquí la escena del mueble | `mesa_laboratorio.tscn` |

4. Guarda con **Ctrl+S**.

### 3. Añadirla al catálogo del pueblo

1. Abre `village.tscn` y selecciona **Pueblo**.
2. En el Inspector, abre **Catalog** y pulsa **Añadir elemento** (Add Element).
3. Arrastra `mesa_laboratorio.tres` al hueco nuevo.

### 4. Colocarla

1. Arrastra `mesa_laboratorio.tscn` encima de **Muebles** en el panel Escena, o
   selecciona Muebles y suéltala con **Mayús** en la vista 3D.
2. Muévela con **W** dentro de lo amarillo y gírala con **E**. Girada 90°, una mesa
   de 2 × 1 ocupa 1 × 2.
3. Guarda y prueba con **F6**.

### Si sale un aviso

Cuando un mueble no cuadra, aparece un **triángulo amarillo** junto a **Pueblo** en
el panel Escena. Pasa el ratón por encima: los avisos empiezan por «Parcela:» y
dicen qué mueble es.

| El aviso dice… | Qué pasa | Solución |
|---|---|---|
| no está en el catálogo | Falta el paso 3 | Añade su ficha a **Catalog** |
| se sale de la parcela | Alguna de sus casillas no es amarilla | Muévelo, o pinta más parcela |
| se solapa con otro mueble | Dos muebles en la misma casilla | Separa uno de los dos |
| hay un bloque u objeto en esas casillas | Hay un bloque de **Bloques** o un objeto de **Objetos** debajo | Muévelo, o quita el bloque o el objeto |
| no está encajado en una casilla a ras de suelo | Has apagado **Ajustar A Rejilla** o lo has subido | Enciéndela y pon su altura (Position → y) a 0 |
| mide N casillas pero su definición dice M | La **Huella** de la ficha no coincide con el modelo | Corrige la huella en la ficha |
| no es un objeto VillageProp | Has puesto dentro de Muebles algo que no se hizo con la plantilla | Sácalo de Muebles |
| (Objetos) flota en el aire sin un bloque debajo | Un objeto de **Objetos** se ha subido al arrastrarlo por la vista 3D. El editor lo enseña en un sitio y el juego, con su cámara inclinada, más atrás | Pon su altura (Position → y) a 0, o encima de un bloque si lo quieres ahí |

El aviso se actualiza solo al mover el mueble, en menos de un segundo.

## Vallas que se unen solas

`scenes/village/props/metal_fence.tscn` es una valla de hierro que se une con las
de al lado. Una suelta es solo el poste. Si pones otra en la casilla de al lado, a
la izquierda, a la derecha, delante o detrás, aparece el tramo que las une. En
diagonal no se unen.

1. Pon la primera en **Objetos**, como cualquier objeto.
2. Selecciónala, pulsa **Ctrl+D** y mueve la copia una casilla con **W**. En
   cuanto encaja al lado, aparece el tramo, también en el editor.
3. Sigue así para hacer filas o esquinas. Para abrir un hueco, borra una valla y
   sus vecinas pierden el tramo.

Solo se unen las vallas que cuelgan del mismo nodo: todas en **Objetos**, o
todas en **Muebles**.

## Plantas, setas y rocas

En `scenes/village/props/plantas/` hay una escena por cada planta de tu hoja: 14
arbustos, 10 hierbas, 18 flores y matas, y 11 setas y rocas. Se colocan como
cualquier objeto: arrastra el `.tscn` encima de **Objetos**. Las hierbas, flores y
arbustos se mecen con el viento; las setas y las rocas no.

- Los arbustos y las rocas grandes frenan al personaje. Lo demás se cruza
  andando: tiene encendida la opción **Atravesable**.
- No las retoques a mano: las escribe `tools/build_plants.gd` y se sobrescriben
  si se vuelve a ejecutar. Cómo cambiar el viento o qué estorba, en
  `assets/source/props/plantas/LEEME.md`.
- Todavía no se funden si tapan al personaje (solo lo hacen los árboles) y la
  hierba del suelo no las evita.

## Opciones de la raíz en el Inspector

| Opción | Qué hace |
|---|---|
| **Ajustar A Rejilla** | Encendida, el objeto salta de casilla en casilla al moverlo. Apágala para colocarlo libre, por ejemplo una flor desplazada un poco |
| **Anclaje** | **Automático**: si el objeto ocupa un número impar de casillas se centra en una casilla, y si es par se pone en una esquina, para que siempre cubra casillas enteras. **Centro de celda** y **Esquina de celda** fuerzan uno de los dos |
| **Colision Automatica** | La caja de colisión sigue al modelo. Apágala para ajustarla a mano |
| **Centrar Por La Base** | Centra el objeto por lo que toca el suelo, no por su caja entera. Para lo que sobresale hacia un lado, como el brazo de una farola o una copa torcida. Ejemplo: `farola.tscn` |
| **Atravesable** | El personaje lo cruza: el objeto no lleva colisión y el editor no avisa de que falte. Para hierbas, flores y guijarros |
| **Recolocar modelo** | Vuelve a apoyar y centrar el modelo si ha quedado raro después de cambiarlo |

## Problemas comunes

| Me pasa… | Solución |
|---|---|
| Se ve **borroso** | Al material le falta el filtro *Nearest*: vuelve a hacerlo duplicando `village_pixel.tres`. O la textura no tiene los ajustes de importación del paso 1 |
| Sale **enorme** | **Scale Mesh** del `.obj` no es `0.03125`. Corrígelo y reimporta |
| Sale **estirado o aplastado** | Has cambiado la escala de la raíz o de Modelo. Deja la raíz en escala 1 y pulsa **Recolocar modelo** |
| **Flota o está enterrado** | Pulsa **Recolocar modelo** |
| El personaje lo **atraviesa** | Falta **Colision/Forma** o su caja es muy pequeña. Actívala en *Formas de colisión visibles* para verla |
| **No encaja** en las casillas del suelo | **Objetos** se ha movido. Pon su posición a 0, 0, 0 |
| Una parte sale **blanca o muy clara** y el resto bien | El `.obj` trae varios objetos (líneas `o`) y Godot hace una superficie por cada uno, pero el material solo se pone en la primera. Pídeme que lo junte en un solo objeto, o en Blender une las piezas (Ctrl+J) antes de exportar |
| La cara de arriba sale **del revés** | Es una rareza de PixZels con las texturas. Pídeme que lo corrija con la herramienta que ya existe para los bloques |
| Delante del personaje **lo tapa sin volverse transparente** | Todavía no está hecho. Los muros del GridMap sí se transparentan; los objetos, de momento, no |

### ¿Y si el modelo viene de Blender (`.glb`)?

Funciona igual: suéltalo dentro de **Modelo**, con Mayús. Tiene que estar hecho a la misma
medida, 32 píxeles de textura por metro de Blender. Los materiales de un `.glb`
vienen dentro del archivo y hay que ponerlos en *Nearest*. La primera vez, pídeme
ayuda y lo dejamos preparado.

Siguiente: [04 · Aprender más](04-aprender-mas.md).
