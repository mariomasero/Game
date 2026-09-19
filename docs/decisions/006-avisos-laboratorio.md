# H4 — Avisos del laboratorio

Incremento de claridad y feedback sobre H3, autorizado por la petición de seguir construyendo las bases jugables. Se conservan arte, personaje, economía y schema_version 1.

- Confirmaciones de compras/cobros/recogida/mejora; aviso de lote listo aun lejos de la máquina. El texto del panel se mantiene y un aviso breve acompaña el regreso a la sala. El sonido complementa al texto, nunca es la única señal.
- Sonidos originales cortos sintetizados con AudioStreamWAV; sin plugins ni archivos de terceros. Sonido local, sin música/voz. Un control en pausa permite silenciarlos y conserva la preferencia en audio.cfg junto a la partida. No cambia ni reinicia la partida.
- Un componente de presentación observa solo la transición produciendo→listo; cargar una partida lista no reproduce falsos eventos ni cobra nada. Los avisos temporales se detienen en pausa, no bloquean controles y no tapan botones de paneles.
- La guía superior distingue qué insumo falta, entrega pendiente, máquina lista y compras desequilibradas recuperables. Solo recomienda una mejora si está desbloqueada y hay saldo suficiente.

Implementación: `scenes/ui/lab_feedback.gd/.tscn`, `scripts/presentation/lab_cues.gd` y `lab_guidance.gd`; integración en HUD existente. Pruebas reales de acciones, transición lista sin repetición, silencio/preferencia y rutas de guía. Capturas para legibilidad y regresión del ciclo H2/H3. No se presenta como validación acústica subjetiva, exportación ni cierre de H4.

Referencias API 4.6: [AudioStreamWAV](https://docs.godotengine.org/en/4.6/classes/class_audiostreamwav.html), [AudioStreamPlayer](https://docs.godotengine.org/en/4.6/classes/class_audiostreamplayer.html), [ConfigFile](https://docs.godotengine.org/en/4.6/classes/class_configfile.html).

## Resultado

- 14 comprobaciones nuevas de interacción/presentación superadas: compra, ingrediente restante, lote listo, ausencia de reinicio sonoro, silencio/carga/reactivación, errores legibles, recuperación de compras desequilibradas y carga de lote listo sin falso aviso.
- Regresión ejecutada del recorrido de pedidos (27), partida persistente (15), error/reintento/cierre (5) y laboratorio (56), todas sin fallos: **117 comprobaciones de integración** contando las 14 nuevas. Los 33 archivos de fuentes/personaje conservan sus hashes. No se cambia el formato de partida.
- Capturas reales: [aviso de lote listo](../captures/h4-batch-ready.png) y [silencio](../captures/h4-sound-muted.png). También revisado el panel con todos los controles de fallo de guardado; se redujo su separación vertical para que cupiesen a 640×360.
- Seis muestras WAV exportadas a `.local/captures/h4-feedback/`: mono PCM16 a 22050 Hz, duraciones 0,26–0,52 s, picos absolutos 10728–10956 sobre 32767 (sin saturación). Reproducción/avance del AudioStreamPlayer comprobados; gusto acústico y volumen en los altavoces del usuario pendientes.
- Un primer cierre headless del recorrido de pedidos emitió un aviso de ObjectDB; no se reprodujo al repetir con `--verbose`. Causa no demostrada, sin cambios especulativos para ocultarlo. Revisar si reaparece. No hay revisión independiente nueva por el límite de uso previo; revisión local realizada.
- H4 sigue en curso: sin exportación ni prueba con una persona ajena. Esta tarea mejora feedback, no añade contenido masivo.
