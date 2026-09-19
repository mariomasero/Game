# H4 — Ejecutable local de Windows

Objetivo: abrir el prototipo fuera del editor y comprobar que los recursos, el ciclo y el guardado funcionan en la exportación real. Sin cambios al personaje ni al arte.

1. Comprobar Godot 4.6.2 y obtener sus plantillas oficiales, verificando el SHA-256 publicado.
2. Crear preset Windows x86_64 con la escena principal y sus dependencias; excluir pruebas y fuentes de autoría.
3. Exportar a `builds/windows`, incluir instrucciones y atribuciones.
4. Arrancar el ejecutable con APPDATA aislado; probar persistencia entre procesos y renderizar una captura desde los recursos exportados.
5. Registrar resultados y límites; H4 conserva pendiente la prueba con una persona ajena.

Referencias: [Exportar proyectos](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_projects.html), [Windows](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_windows.html), [implementación de rutas Windows 4.6.2](https://github.com/godotengine/godot/blob/4.6.2-stable/platform/windows/os_windows.cpp).

Resultado: pasos realizados. EXE/PCK local, instrucciones, licencias y reconstrucción comprobados. Ver [evidencia y límites](../decisions/007-exportacion-windows.md): 32 comprobaciones del PCK, arranque/render/producción/recarga del EXE y un aviso de audio pendiente en el cierre headless del arnés. No se da por completa la prueba humana de H4.
