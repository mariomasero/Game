extends SceneTree

## Guardia de los ajustes que rompen el pixel art en silencio.
##
## Las tres familias comparten la misma forma de fallar: no dan error, no se ven
## de inmediato y sobreviven semanas. Ya paso dos veces con el personaje --
## idle.png estaba en compress/mode=2 con mipmaps y walk.png con
## detect_3d/compress_to=1, "programada para comprimirse sola al primer uso en
## 3D" (docs/decisions/010-mundo-pixel-exacto.md).
##
## Es la unica prueba que hay que ejecutar tambien cuando no se toca el suelo.
##
##   godot --headless --path . --script tests/test_pixel_settings_guard.gd

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
	else:
		print("PASS: " + message)

func _run() -> void:
	_importaciones()
	_materiales()
	_ajustes_de_proyecto()
	print("RESULTADO GUARDIA PIXEL: %d comprobaciones, %d fallos" % [checks, failures])
	quit(1 if failures else 0)

## Recorre los .import de las texturas de juego. El formato es INI, asi que
## ConfigFile lo lee; las claves llevan barra dentro de la seccion params.
func _importaciones() -> void:
	var rutas := _archivos("res://assets/game", ".png.import")
	_check(not rutas.is_empty(), "Se encuentran .import de textura en assets/game")
	for ruta in rutas:
		var cfg := ConfigFile.new()
		if cfg.load(ruta) != OK:
			_check(false, "Se puede leer %s" % ruta)
			continue
		var nombre := ruta.get_file()
		_check(cfg.get_value("params", "compress/mode", -1) == 0,
			"%s sin compresion VRAM" % nombre)
		_check(cfg.get_value("params", "mipmaps/generate", true) == false,
			"%s sin mipmaps" % nombre)
		# Sin esta, Godot recomprime la textura a VRAM en cuanto la ve usada en
		# 3D y destroza el pixel art sin decir nada.
		_check(cfg.get_value("params", "detect_3d/compress_to", 1) == 0,
			"%s sin recompresion automatica en 3D" % nombre)

## El filtrado en Godot 4 no vive en el importador sino en el material, y un
## material creado desde el editor sale con filtro lineal por omision.
func _materiales() -> void:
	# Con subcarpetas: las plantas tienen un material cada una en plantas/.
	var rutas := _archivos("res://assets/game/materials", ".tres")
	for ruta in rutas:
		var archivo := ruta.trim_prefix("res://assets/game/materials/")
		var mat := load(ruta)
		if mat is BaseMaterial3D:
			_check(mat.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST,
				"%s con filtrado nearest" % archivo)
		elif mat is ShaderMaterial:
			_check(_shader_nearest(mat as ShaderMaterial),
				"%s: cada textura del shader con filter_nearest" % archivo)
		else:
			_check(false, "%s es un BaseMaterial3D o un ShaderMaterial" % archivo)
	_check(not rutas.is_empty(), "Hay materiales que comprobar")

## En un shader el filtrado lo decide la pista de cada sampler y, sin pista, es
## lineal. Se lee el codigo: basta un sampler2D sin filter_nearest para fallar.
func _shader_nearest(mat: ShaderMaterial) -> bool:
	if mat.shader == null:
		return false
	var patron := RegEx.create_from_string("uniform\\s+sampler2D\\s+\\w+\\s*(:[^;]*)?;")
	var hay := false
	for encontrado in patron.search_all(mat.shader.code):
		hay = true
		if not encontrado.get_string(1).contains("filter_nearest"):
			return false
	return hay

## Forward+ expone MSAA, FXAA y TAA, y las tres rompen el pixel art: TAA lo
## arrastra entre fotogramas (prohibido en AGENTS.md:76) y las otras dos
## inventan colores fuera de paleta en los bordes, que es justo la metrica que
## la decision 010 usa como instrumento de medida.
func _ajustes_de_proyecto() -> void:
	_check(ProjectSettings.has_setting("rendering/renderer/rendering_method"),
		"El renderizador esta fijado en project.godot y no heredado del motor")
	_check(ProjectSettings.get_setting(
		"rendering/renderer/rendering_method", "") == "forward_plus",
		"El renderizador efectivo es forward_plus")
	var features: PackedStringArray = ProjectSettings.get_setting(
		"application/config/features", PackedStringArray())
	_check(features.has("Forward Plus"),
		"config/features declara Forward Plus")
	_check(not features.has("GL Compatibility"),
		"config/features ya no declara GL Compatibility")
	_check(int(ProjectSettings.get_setting(
		"rendering/anti_aliasing/quality/msaa_3d", 1)) == 0, "MSAA 3D apagado")
	_check(int(ProjectSettings.get_setting(
		"rendering/anti_aliasing/quality/screen_space_aa", 1)) == 0,
		"Antialiasing de pantalla apagado")
	_check(ProjectSettings.get_setting(
		"rendering/anti_aliasing/quality/use_taa", true) == false, "TAA apagado")

## Archivos terminados en `sufijo` bajo `raiz`, con subcarpetas.
func _archivos(raiz: String, sufijo: String) -> Array[String]:
	var salida: Array[String] = []
	var dir := DirAccess.open(raiz)
	if dir == null:
		return salida
	for archivo in dir.get_files():
		if archivo.ends_with(sufijo):
			salida.append(raiz.path_join(archivo))
	for sub in dir.get_directories():
		salida.append_array(_archivos(raiz.path_join(sub), sufijo))
	return salida
