# Sprites del personaje

Original character template created by **Eris Esra**: https://erisesra.itch.io/character-templates-pack

Se conservan los originales aportados por el usuario en `assets/16x32/`, incluidos los archivos Aseprite. Condiciones del paquete en [Read Me.txt](<../../Read Me.txt>): se permite su uso en juegos comerciales y no comerciales; no se permite revender las plantillas como paquetes o encargos de personajes. Conservar el texto original para sus condiciones completas.

## Integración

- `idle.png`: copia sin modificaciones de `assets/16x32/16x32 Idle-Sheet.png`.
- `walk.png`: copia sin modificaciones de `assets/16x32/16x32 Walk-Sheet.png`.
- Hojas de 128×160 píxeles; cuatro columnas y cinco filas. Aunque el personaje se denomina 16×32, su lienzo por fotograma es **32×32**, tal como indica el Read Me original.
- Filas: abajo, abajo/derecha, derecha, arriba/derecha, arriba. Las orientaciones hacia la izquierda usan reflejo horizontal. Orden contrastado con los tags de los Aseprite originales y revisión renderizada.
- Cada fotograma dura 100 ms en el Aseprite: cuatro fotogramas por animación, a 10 FPS, en bucle.
- PNG con transparencia, sin recortes ni cambios de paleta. Escala visual ×1,5 con nearest (25% menor que la integración inicial); cuerpo de colisión de 14×10 y sombra reducida. Pivote en el centro inferior del lienzo, a los pies, para mantener el orden de dibujo. Las escalas fraccionarias priorizan la proporción del prototipo y no preservan un tamaño idéntico para todos los píxeles fuente.
- Reposo y caminar corresponden a acciones existentes. Run, Jump, Attack, Rotate e Interact permanecen como fuentes disponibles; no se han añadido mecánicas nuevas.

Recurso editable en Godot: `scenes/player/player_frames.tres`. No hay plugin importador ni generación de recursos durante el juego.
