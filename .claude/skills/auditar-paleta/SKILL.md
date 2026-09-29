---
name: auditar-paleta
description: Comprueba que una o varias texturas PNG solo usan los colores de su paleta (Aseprite, GPL, HEX o PNG) y señala cada color que sobra, con su posición y el color de paleta más cercano. Úsala siempre que entre al repositorio una textura nueva o modificada (bloques, suelo, hierba, agua, sprites, iconos), cuando una herramienta de tools/ genere imágenes, antes de aceptar arte hecho con IA, y cuando Mario hable de colores fuera de paleta, disciplina de paleta, colores que no cuadran o tonos que cambian.
---

# Auditar la paleta de una textura

Regla del proyecto: ninguna textura introduce colores fuera de su paleta definida. El script de esta skill lo mide sin tocar las imágenes.

## Ejecutar

```bash
python .claude/skills/auditar-paleta/scripts/auditar_paleta.py --paleta RUTA_PALETA IMAGEN_O_CARPETA [...]
```

Si `python` no existe en Windows, prueba `py`. Necesita Pillow y NumPy (`pip install pillow numpy`); si faltan, díselo a Mario antes de instalar nada.

Las carpetas se recorren enteras buscando `.png`. El código de salida es 0 si todo cabe en la paleta y 1 si sobra algún color.

## Elegir la paleta

AGENTS.md cita `Grass_palette.aseprite` para la hierba; búscala con una búsqueda por nombre (`*palette*`) en `assets/source/`. Si no está claro qué paleta corresponde a una textura, pregunta a Mario: auditar contra la paleta equivocada da resultados sin sentido.

Un `.aseprite` guarda dos cosas que pueden no coincidir: la paleta del panel y los colores pintados. Por defecto se lee el panel. Si el archivo es una muestra con los colores pintados, usa `--modo pixeles`. Ante la duda, ejecuta con `--mostrar-paleta` en los dos modos y compara; si el panel tiene 32 o más colores que no se parecen a los de la textura, probablemente sea la paleta por defecto de Aseprite.

## Leer el resultado

- `OK` — todos los píxeles opacos están en la paleta. Los píxeles transparentes (alfa 0) no cuentan.
- `FUERA` — lista hasta 10 colores sobrantes, con cuántos píxeles usan, dónde aparece el primero y el color de paleta más cercano con su distancia.
- Una **distancia de 1 o 2** suele ser un redondeo de conversión de color, no un error de dibujo. Menciónalo tal cual; no lo arregles por tu cuenta.
- **Píxeles semitransparentes** — el proyecto no usa antialiasing, así que suelen indicar bordes suavizados por un programa o por una IA.

`--mapa .local/auditoria-paleta` deja un PNG con lo correcto oscurecido y lo sobrante en magenta. Enséñaselo a Mario cuando haya muchos píxeles fuera. Déjalo en `.local/`, nunca dentro de `assets/`.

## Lo que no hay que hacer

- **No corrijas texturas.** AGENTS.md prohíbe modificar texturas pintadas salvo petición expresa. Informa de lo que sobra y deja que Mario decida.
- `--cuantizar SALIDA.png` escribe una copia con cada color llevado al más cercano de la paleta, y se niega a sobrescribir el original. Úsalo solo si Mario lo pide, por ejemplo para limpiar una imagen generada con IA, y deja la copia fuera de `assets/game/` hasta que él la revise.
- **No audites capturas de pantalla contra la paleta.** La luz cambia los colores en pantalla (AGENTS.md mide el césped al sol en 114,164,86 frente a `#78a44b`). Esta skill es para archivos de textura.

## Informar

Copia el bloque del script tal cual, sin la paleta completa salvo que sea útil. Resume en una frase qué imágenes están limpias y cuáles no.
