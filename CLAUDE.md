# CLAUDE.md

@AGENTS.md

## Notas solo para Claude Code

`AGENTS.md` es la fuente de verdad compartida con Codex. No copies aquí sus reglas: si algo cambia, se cambia allí.

Skills del proyecto (`.claude/skills/`):

- `verificar-godot` — pruebas, guarda de píxel y arranque, con resumen corto. Úsala antes de dar cualquier tarea por cerrada.
- `integrar-bloque-pixzels` — llevar un bloque nuevo de PixZels al juego.
- `auditar-paleta` — comprobar que una textura solo usa los colores de su paleta.

Para gastar menos uso:

- No vuelques al contexto la salida completa de Godot. `verificar-godot` la guarda en `.local/verificacion/ultimo.log`; busca en ese archivo solo lo que falle.
- Lee los archivos grandes por rangos o con búsquedas, no enteros, salvo que haga falta.
- Una tarea por sesión. Al terminar, resume lo hecho para que Mario pueda empezar la siguiente con `/clear`.
