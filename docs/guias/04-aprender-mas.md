# 04 · Aprender más

## Documentación oficial de Godot 4.7

Está en inglés; la versión en español está incompleta, pero sirve para lo básico:
<https://docs.godotengine.org/es/4.x/>. El traductor del navegador funciona bien
con estas páginas.

| Tema | Enlace | Cuándo leerlo |
|---|---|---|
| Primer vistazo al editor | [first_look_at_the_editor](https://docs.godotengine.org/en/4.7/getting_started/introduction/first_look_at_the_editor.html) | Antes de nada |
| Nodos y escenas | [nodes_and_scenes](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/nodes_and_scenes.html) | Para entender el panel Escena |
| Instanciar escenas | [instancing](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/instancing.html) | Antes de hacer tus propios objetos (guía 03) |
| Introducción al 3D | [introduction_to_3d](https://docs.godotengine.org/en/4.7/tutorials/3d/introduction_to_3d.html) | Moverte por la vista 3D y las herramientas Mover, Rotar y Escalar |
| GridMap | [using_gridmaps](https://docs.godotengine.org/en/4.7/tutorials/3d/using_gridmaps.html) | Para sacarle partido a la paleta: seleccionar, rellenar, mover y duplicar zonas |
| Importar modelos 3D | [importing_3d_scenes](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_3d_scenes/index.html) | Cuando traigas modelos de Blender (`.glb`) |
| Física y colisiones | [physics_introduction](https://docs.godotengine.org/en/4.7/tutorials/physics/physics_introduction.html) | Para entender StaticBody3D y CollisionShape3D |
| Tu primer juego 3D | [first_3d_game](https://docs.godotengine.org/en/4.7/getting_started/first_3d_game/index.html) | Un tutorial completo, si quieres ver cómo se hace un juego pequeño de principio a fin |
| GDScript, lo básico | [gdscript_basics](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_basics.html) | Solo si algún día te apetece leer o tocar código |

Una advertencia al buscar en internet: muchos vídeos y foros son de **Godot 3**, y
los menús y los nombres cambian mucho. Busca siempre que diga «Godot 4».

## Un camino de aprendizaje sugerido

1. **Primera semana: el editor.** Guías 01 y 02. Pinta caminos, plazas y muros;
   rómpelo y deshazlo con Ctrl+Z. Lee *first_look_at_the_editor* y
   *nodes_and_scenes*.
2. **Tus primeros objetos.** Guía 03 con un objeto sencillo de PixZels, como una
   caja o una valla, antes que una casa. Lee *instancing*.
3. **Composición.** Monta una plaza con varias cosas: una fuente, bancos, una
   farola. Fíjate en qué se lee bien desde la cámara, con la vista previa
   (Ctrl+P). Compara con tus referencias (Graveyard Keeper 2, SacriFire).
4. **Luz.** Selecciona **Sun** y prueba a girarlo o a cambiar su color. Si no te
   gusta, Ctrl+Z. Así aprendes cómo cambia el ambiente.
5. **Cuando quieras**: *first_3d_game* te enseña a hacer un juego completo
   pequeño y un poco de GDScript.

## Glosario

| Palabra | Qué es en este proyecto |
|---|---|
| **Nodo** | Una pieza de una escena: luz, cámara, malla, cuerpo físico… |
| **Escena** (`.tscn`) | Un grupo de nodos guardado en un archivo. Se puede meter dentro de otra |
| **Instancia** | Una copia de una escena metida en otra. Si cambias el original, cambian todas |
| **Recurso** (`.tres`) | Datos que usan los nodos: materiales, texturas, paletas |
| **Casilla** o **celda** | La unidad de la rejilla. Mide un bloque: 32 × 32 píxeles en pantalla |
| **Parcela** | La zona amarilla donde crece el laboratorio. Solo ahí van los muebles |
| **Ficha** (definición) | El archivo `.tres` de un mueble: su id, su nombre, cuántas casillas ocupa y su escena |
| **Huella** | Las casillas que ocupa un objeto o mueble en el suelo, por ejemplo 2 × 1 |
| **Planta** (floor) | La altura en casillas del GridMap: 0 es a ras de suelo, 1 encima… |
| **GridMap** | El nodo de Godot para pintar piezas 3D en casillas. Aquí hay dos: **Terreno** y **Bloques** |
| **MeshLibrary** | La paleta de un GridMap: la lista de piezas que se pueden pintar. Las nuestras son `assets/game/tilesets/paint_*.meshlib.tres` |
| **Tesela** (tile) | Un trozo del dibujo del suelo. Las transiciones entre terrenos son teselas que se eligen solas según lo que pintas |
| **Atlas** | Una imagen con muchas teselas o caras juntas, como `ground_atlas.png` |
| **Material** | Cómo se pinta una superficie: textura, color, brillo. Para pixel art, siempre con filtro *Nearest* |
| **Nearest** | Filtro de textura que deja los píxeles nítidos. El contrario, *Linear*, los emborrona |
| **Colisión** | La forma invisible con la que choca el personaje (StaticBody3D + CollisionShape3D) |
| **Gizmo** | Las flechas y anillos de colores para mover y girar en la vista 3D |
| **Escena principal** | La que se abre con F5 y al ejecutar el juego |
