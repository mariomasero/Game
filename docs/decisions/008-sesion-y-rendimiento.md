# H4 — Sesión técnica y rendimiento

17 de septiembre de 2026. Objetivo: comprobar continuidad del ciclo y obtener una primera medición reproducible, sin modificar arte ni reglas.

## Condiciones

- Godot 4.6.2 oficial, ejecutando el PCK release existente con un arnés externo (`tests/measure_lab_session.gd`). No es una medición del EXE release ni del coste de la interfaz del editor.
- Windows, AMD Ryzen 7 9800X3D, NVIDIA RTX 5070 Ti, controlador 595.97, OpenGL Compatibility.
- Ventana 1280×720, imagen interna 640×360, VSync activado y límite explícito de 60 FPS.
- Dos segundos de calentamiento. Luego 180 segundos de actividad y finalización del pedido en curso: **186,58 s medidos**.
- Personaje movido mediante acciones de entrada, paneles y botones activados por llamadas/señales, compras, producción con tiempo real, recogida, entrega, mejora, pausa y autoguardado. No se simula el tiempo con `advance()`.
- APPDATA aislado; partida real intacta. Sin servicios remotos. El escenario automatiza las operaciones sin exigir proximidad para abrir cada panel: no valida navegación humana ni el tiempo de desplazamiento real entre pedidos.

## Resultado

**20 pedidos completados, mejora comprada y saldo final correcto de 320 cr.** La pausa detuvo la producción y el guardado final fue correcto. Cero fallos de aserción, errores de ejecución o avisos de recursos retenidos en el log.

| Medida | Resultado |
|---|---:|
| Intervalos entre fotogramas registrados | 11.195 |
| Mediana | 16,666 ms |
| Percentil 95 | 16,727 ms |
| Percentil 99 | 16,776 ms |
| Intervalo máximo | 18,098 ms |
| Memoria estática inicial del motor | 35,05 MiB |
| Memoria estática máxima observada | 36,71 MiB |
| Memoria estática final | 36,71 MiB |

Los intervalos se miden con reloj real entre señales `process_frame`; incluyen la espera impuesta por VSync/límite de FPS. No son tiempos puros de CPU o GPU ni permiten estimar el máximo FPS posible. El percentil 99 significa que el 99 % de los intervalos fue igual o menor a ese valor.

La memoria es `Performance.MEMORY_STATIC`: no representa toda la RAM del proceso ni la VRAM. Incluye el propio arnés, que conserva muestras, y recursos cargados durante el recorrido. Entre el segundo 60 y el final aumentó aproximadamente 163 KiB. Esta prueba corta no demuestra ausencia de fugas en sesiones de horas. [Definición de monitores, Godot 4.6](https://docs.godotengine.org/en/4.6/classes/class_performance.html).

Datos: [JSON de la sesión](../measurements/2026-09-17-session.json). [Captura final](../captures/h4-session-end.png). Log completo local: `.local/session-measurement/session.log`. No se extrapolan estos resultados a otros equipos, resoluciones ni escenarios.

## Reproducir

Crear una carpeta de perfil nueva. Establecer `APPDATA` y `BIOTECH_TEST_PROFILE` a esa misma ruta absoluta, y `BIOTECH_TEST_OUTPUT` a un directorio existente de resultados. Ejecutar desde la raíz:

```powershell
godot --max-fps 60 --main-pack C:/ruta/biotech/builds/windows/Biotech.pck --script C:/ruta/biotech/tests/measure_lab_session.gd --log-file C:/ruta/biotech/.local/session.log
```

El arnés rechaza perfiles ajenos, partidas con pedidos ya completados y modo headless. Finaliza después de tres minutos más el pedido en curso. Genera JSON y captura; no se incluye en la distribución del juego.

## Decisión

La muestra no indica una necesidad de optimización para esta sala en este equipo. Conservar la implementación y evitar cambios especulativos. H4 mantiene pendiente la prueba humana de comprensión y comodidad, con [ficha preparada](../PRUEBA_JUGABLE.md); tampoco sustituye la revisión visual manual de H1 ni las pruebas con 3–5 personas de H5.
