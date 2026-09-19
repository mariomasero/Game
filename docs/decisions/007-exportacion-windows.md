# H4 — Primera exportación Windows

17 de septiembre de 2026. Entrega local, sin publicación ni firma comercial.

## Abrir y reconstruir

Abrir `builds/windows/Biotech.exe`, conservando `Biotech.pck` a su lado. La carpeta incluye `LEEME.txt`, créditos, licencias y `SHA256.txt`. El ejecutable ocupa 104.653.312 bytes; el paquete de juego, 156.088 bytes. Comparte la partida habitual de F5, sin cambiar el nombre del proyecto ni schema_version 1.

Reconstrucción desde la raíz, con Godot 4.6.2 oficial en PATH:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/export_windows.ps1
```

La excepción de ejecución de scripts afecta solo a ese proceso, no a la política del sistema. El script comprueba versión, hash de plantilla y errores de importación/exportación. No instala herramientas ni publica archivos.

Plantilla en `.local/tools/godot-4.6.2/windows_release_x86_64.exe`, extraída del [paquete oficial 4.6.2](https://github.com/godotengine/godot-builds/releases/tag/4.6.2-stable). Para otra instalación, descargar `Godot_v4.6.2-stable_export_templates.tpz`, verificar SHA-256 y extraer `templates/windows_release_x86_64.exe` a esa ruta:

- TPZ: `942366dc4e27e7686a99da4d3cfb1b8ae8d3eb9444f6d8217eef16245b599ef2`.
- Plantilla x86_64: `3b2d3f99bd640961aad1a1a200f0f7233b7de45b02801ce22d3224dc294d93d1`.

El preset selecciona recursos concretos. Se incluyen explícitamente scripts precargados, definición de economía, GLB y material: la primera selección por escena omitió estas dependencias y el EXE falló al cargar. La selección corregida se comprobó en el paquete real. Fuentes Blender/Aseprite, pruebas, documentos, copias locales y partidas no se distribuyen.

Referencias de configuración: [exportación Godot 4.6](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_projects.html) y [Windows](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_windows.html).

## Evidencia

- Importación y exportación release correctas; logs `.local/h4-export/import.log` y `export.log`.
- EXE release con arranque normal, fuera del editor, APPDATA aislado: crea una partida nueva. Con una partida sintética de lote de 8 s, guarda automáticamente aproximadamente 2,99 s restantes; otro proceso lo termina, conserva 45 cr y tres pedidos. Logs `release-production.log` / `release-reload.log`. No se ha usado la partida real.
- Captura del EXE mediante `--write-movie` durante tres fotogramas: [sala exportada](../captures/h4-windows-release.png). Windows, NVIDIA RTX 5070 Ti, controlador 595.97, OpenGL Compatibility, imagen interna 640×360. Se revisan carga de sala, texturas, terminal, sprite y HUD. Tres fotogramas no acreditan rendimiento ni estabilidad temporal.
- Arnés externo `tests/test_exported_lab.gd`, ejecutado con el motor y `--main-pack builds/windows/Biotech.pck`: **32 comprobaciones, 0 fallos**, repartidas en tres procesos (13 + 11 + 8). Verifica recursos del paquete, movimiento, ciclo de pedidos, compra de mejora, pausa, recarga sin producción offline, sonido persistente y ausencia de cobro duplicado. El primer lote espera tiempo real; los otros dos se adelantan desde el dominio. Los botones se activan por señal, no mediante clic físico.
- Distinción: las plantillas oficiales instaladas no admiten `--script` ni el cambio externo de arranque que se intentó. El arnés verifica el PCK con el motor; las pruebas directas del EXE son las de arranque, producción/recarga y captura anteriores. No se presenta el arnés como un recorrido manual del EXE.
- En la primera verificación, el proceso headless del arnés emitía al cerrar un aviso de dos objetos de audio pendientes de liberar. Diagnosticado después: el arnés salía antes de completarse la retirada asíncrona de reproducciones. Ver la corrección de cierre más abajo; no se cambió el código del juego ni la exportación.
- Los 33 archivos del personaje/fuentes conservan sus hashes. No cambia arte, cámara, reglas ni formato de partida.

## Repetir el arnés

Usar una carpeta **nueva** para APPDATA, establecer `BIOTECH_TEST_PROFILE` al mismo directorio y `BIOTECH_TEST_OUTPUT` al directorio de capturas. En tres procesos sucesivos ejecutar:

```powershell
godot --main-pack C:/ruta/biotech/builds/windows/Biotech.pck --script C:/ruta/biotech/tests/test_exported_lab.gd -- prepare
godot --main-pack C:/ruta/biotech/builds/windows/Biotech.pck --script C:/ruta/biotech/tests/test_exported_lab.gd -- resume
godot --main-pack C:/ruta/biotech/builds/windows/Biotech.pck --script C:/ruta/biotech/tests/test_exported_lab.gd -- verify
```

El arnés rechaza una ruta de usuario fuera del perfil especificado. Los logs y capturas deben dirigirse a `.local/`. Después de añadir la comprobación de liberación de audio, las fases tienen 14/11/8 comprobaciones en headless y una adicional por fase si se ejecutan con gráficos.

## Corrección del cierre del arnés — 17 de septiembre

Un caso mínimo reproduce el aviso sin laboratorio ni persistencia: iniciar y detener 20 sonidos en el mismo turno, liberar el reproductor y cerrar inmediatamente deja 20 streams observables mediante WeakRef. Dando tiempo al servidor de audio, los 20 se liberan y el aviso desaparece. La implementación oficial de [AudioServer 4.6.2](https://github.com/godotengine/godot/blob/4.6.2-stable/servers/audio/audio_server.cpp) confirma que `stop_playback_stream` marca la reproducción para desvanecerla y eliminarla durante la mezcla.

El arnés guarda referencias débiles de los sonidos usados, libera la sala y espera hasta que desaparezcan, con un máximo de un segundo y una aserción de fallo si siguen retenidos. No añade una espera fija al juego ni silencia advertencias. Se ha repetido el ciclo completo en tres procesos headless: **33 comprobaciones (14 + 11 + 8), cero fallos y sin avisos de objetos retenidos**. Registros en `.local/audio-debug/{prepare,resume,verify}.log`; reproducción mínima en la misma carpeta. El EXE y el PCK conservan sus hashes, por lo que no hace falta reconstruir ni sustituir la entrega. Esta evidencia resuelve el aviso reproducido del arnés; no acredita todas las posibles secuencias de cierre del motor.

La [sesión técnica posterior de 186,58 s](008-sesion-y-rendimiento.md) aporta una primera medición del PCK con el motor. Pendientes: recorrido completo de una persona ajena, escucha subjetiva, sesiones de mayor duración, escalado/oclusión manual de H1 y decidir el próximo cambio a partir de esa prueba. H4 permanece en curso.
