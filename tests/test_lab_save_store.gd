extends SceneTree

const STORE_SCRIPT := preload("res://scripts/persistence/lab_save_store.gd")

var checks: int = 0
var failures: int = 0
var test_dir: String


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)


func _validator(state: Dictionary) -> String:
	if state.get("schema_version") != 1:
		return "Versión no compatible"
	var money: Variant = state.get("money")
	if not (money is int or money is float) or money < 0 or floorf(float(money)) != float(money):
		return "Saldo inválido"
	return ""


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "Abre el fixture para escritura: " + path.get_file())
	if file != null:
		file.store_string(content)
		file.close()


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed


func _has_state(value: Variant, schema_version: int, money: int) -> bool:
	return value is Dictionary and value.get("schema_version") == schema_version and value.get("money") == money


func _archive_count(prefix: String) -> int:
	var count := 0
	for file_name in DirAccess.get_files_at(test_dir):
		if file_name.begins_with(prefix + ".archive-"):
			count += 1
	return count


func _cleanup() -> void:
	if not DirAccess.dir_exists_absolute(test_dir):
		return
	for file_name in DirAccess.get_files_at(test_dir):
		DirAccess.remove_absolute(test_dir + "/" + file_name)
	DirAccess.remove_absolute(test_dir)


func _run() -> void:
	test_dir = "user://test_h3_store_%d" % Time.get_ticks_usec()
	_check(DirAccess.make_dir_recursive_absolute(test_dir) == OK, "Crea un directorio aislado")
	var path := test_dir + "/save.json"
	var store: RefCounted = STORE_SCRIPT.new()
	var valid := {"schema_version": 1, "money": 120}
	var newer := {"schema_version": 1, "money": 135}

	var missing: Dictionary = store.load_game(path, Callable(self, "_validator"))
	_check(missing.status == "missing" and missing.state.is_empty() and missing.error.is_empty(),
		"Distingue una partida ausente")
	var save_error: String = store.save_game(path, valid, Callable(self, "_validator"))
	_check(save_error == "", "Guarda una partida válida: " + save_error)
	_check(_has_state(_read_json(path), 1, 120), "Instala la primaria con el estado completo")
	_check(not FileAccess.file_exists(path + ".tmp"), "Retira el temporal tras instalar la primaria")
	var loaded: Dictionary = store.load_game(path, Callable(self, "_validator"))
	_check(loaded.status == "ok" and _has_state(loaded.state, 1, 120) and loaded.error.is_empty(), "Carga la primaria válida")

	save_error = store.save_game(path, newer, Callable(self, "_validator"))
	_check(save_error == "", "Guarda una segunda versión: " + save_error)
	_check(_has_state(_read_json(path), 1, 135) and _has_state(_read_json(path + ".bak"), 1, 120),
		"Rota la primaria anterior a backup antes de instalar")
	var invalid_state := {"schema_version": 2, "money": 999}
	var primary_before: Variant = _read_json(path)
	_check(not store.save_game(path, invalid_state, Callable(self, "_validator")).is_empty(),
		"Rechaza el estado antes de escribir")
	_check(_read_json(path) == primary_before, "Un guardado inválido no modifica la primaria")

	_write_text(path + ".tmp", JSON.stringify({"schema_version": 1, "money": 777}))
	loaded = store.load_game(path, Callable(self, "_validator"))
	_check(loaded.status == "ok" and _has_state(loaded.state, 1, 135), "No confía en un temporal si la primaria es válida")
	DirAccess.remove_absolute(path)
	loaded = store.load_game(path, Callable(self, "_validator"))
	_check(loaded.status == "recovered" and _has_state(loaded.state, 1, 120),
		"Ofrece el backup válido cuando falta la primaria")
	_check(not FileAccess.file_exists(path), "Leer el backup no lo instala automáticamente")
	var recovery_error: String = store.recover_backup(path, Callable(self, "_validator"))
	_check(recovery_error == "", "Recupera el backup solo por acción explícita: " + recovery_error)
	_check(_has_state(_read_json(path), 1, 120) and _archive_count("save.json.tmp") == 1,
		"La recuperación instala la copia y archiva el temporal previo")

	_write_text(path, "{broken json")
	_write_text(path + ".bak", JSON.stringify(newer))
	loaded = store.load_game(path, Callable(self, "_validator"))
	_check(loaded.status == "recovered" and _has_state(loaded.state, 1, 135) and not loaded.error.is_empty(),
		"Una primaria corrupta ofrece el backup válido sin instalarlo")
	_check(_has_state(_read_json(path + ".bak"), 1, 135), "El error de carga no modifica el backup")
	var corrupt_text := FileAccess.get_file_as_string(path)
	recovery_error = store.recover_backup(path, Callable(self, "_validator"))
	_check(recovery_error == "", "Permite recuperar tras corrupción explícitamente: " + recovery_error)
	_check(_has_state(_read_json(path), 1, 135) and _archive_count("save.json") >= 1,
		"Recuperar conserva la primaria corrupta en un archivo")
	_check(corrupt_text == "{broken json", "El fixture corrupto tenía el contenido esperado")

	_write_text(path, JSON.stringify({"schema_version": 99, "money": 5}))
	_write_text(path + ".bak", JSON.stringify(valid))
	loaded = store.load_game(path, Callable(self, "_validator"))
	_check(loaded.status == "recovered" and _has_state(loaded.state, 1, 120) and loaded.error.contains("compatible"),
		"Una versión desconocida ofrece el backup compatible para recuperación explícita")
	_check(_read_json(path).schema_version == 99, "No convierte ni sobrescribe la versión desconocida")

	_write_text(path + ".bak", JSON.stringify(valid))
	_write_text(path + ".tmp", JSON.stringify(newer))
	var archives_before := _archive_count("save.json") + _archive_count("save.json.bak") + _archive_count("save.json.tmp")
	var replace_error: String = store.replace_game(path, {"schema_version": 1, "money": 42}, Callable(self, "_validator"))
	_check(replace_error == "", "Reemplaza la partida solo por acción explícita: " + replace_error)
	var archives_after := _archive_count("save.json") + _archive_count("save.json.bak") + _archive_count("save.json.tmp")
	_check(_read_json(path).money == 42 and archives_after == archives_before + 3,
		"Nueva partida archiva primaria, backup y temporal anteriores")

	var oversized := "{\"schema_version\":1,\"money\":1,\"padding\":\"" + "x".repeat(1024 * 1024) + "\"}"
	_write_text(path, oversized)
	loaded = store.load_game(path, Callable(self, "_validator"))
	_check(loaded.status == "error" and loaded.error.contains("grande"), "Rechaza archivos que superan el límite de lectura")

	# A crash after archiving the prior files must not look like a fresh install.
	for suffix: String in [".recovering", ".replacing", ".tmp"]:
		var interrupted: String = test_dir + "/interrupted" + suffix.replace(".", "_") + ".json"
		_write_text(interrupted + suffix, '{"schema_version":1,"money":75}')
		var pending: Dictionary = store.load_game(interrupted, _validator)
		_check(pending.status == "recovered", "Detecta escritura interrumpida " + suffix)
		_check(not store.save_game(interrupted, {"schema_version": 1, "money": 120}, _validator).is_empty(), "No pisa el estado pendiente " + suffix)
		_check(store.recover_backup(interrupted, _validator).is_empty(), "Recuperación explícita del temporal " + suffix)
		_check(_has_state(_read_json(interrupted), 1, 75), "Conserva el estado recuperado " + suffix)
	_cleanup()
	print("RESULTADO ALMACÉN: %d comprobaciones, %d fallos" % [checks, failures])
	quit(0 if failures == 0 else 1)
