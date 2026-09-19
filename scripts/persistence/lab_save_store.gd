class_name LabSaveStore
extends RefCounted

const MAX_FILE_BYTES := 1024 * 1024


func load_game(path: String, validator: Callable) -> Dictionary:
	var primary_error: String = ""
	if FileAccess.file_exists(path):
		var primary := _read_valid_state(path, validator)
		if primary.error.is_empty():
			return _result("ok", primary.state, "")
		primary_error = primary.error
	elif DirAccess.dir_exists_absolute(path):
		primary_error = "La ruta de la partida contiene una carpeta."
	var source := _recovery_source(path, validator)
	if not source.path.is_empty():
		return _result("recovered", source.state, primary_error if not primary_error.is_empty() else "Hay una escritura pendiente de recuperar.")
	if not primary_error.is_empty():
		return _result("error", {}, primary_error)
	if not source.error.is_empty():
		return _result("error", {}, source.error)
	return _result("missing", {}, "")


func save_game(path: String, state: Dictionary, validator: Callable) -> String:
	var state_error := _validate_state(state, validator)
	if not state_error.is_empty():
		return state_error
	if FileAccess.file_exists(path):
		var current := _read_valid_state(path, validator)
		if not current.error.is_empty():
			return "La partida existente no se sobrescribió: " + current.error
	else:
		var existing := load_game(path, validator)
		if existing.status != "missing":
			return "Hay una partida pendiente de recuperación. " + String(existing.error)
	var preparation_error := _prepare_parent(path)
	if not preparation_error.is_empty():
		return preparation_error
	if FileAccess.file_exists(path + ".tmp"):
		var archive_error := _archive(path + ".tmp")
		if not archive_error.is_empty():
			return archive_error
	var write_error := _write_verified(path + ".tmp", state, validator)
	if not write_error.is_empty():
		return write_error
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			var remove_error := DirAccess.remove_absolute(path + ".bak")
			if remove_error != OK:
				return "No se pudo retirar la copia de seguridad anterior (%s)" % error_string(remove_error)
		var backup_error := DirAccess.rename_absolute(path, path + ".bak")
		if backup_error != OK:
			return "No se pudo rotar la partida a copia de seguridad (%s)" % error_string(backup_error)
	var install_error := DirAccess.rename_absolute(path + ".tmp", path)
	if install_error != OK:
		return "No se pudo instalar la partida guardada (%s)" % error_string(install_error)
	return ""


func recover_backup(path: String, validator: Callable) -> String:
	var backup := _recovery_source(path, validator)
	if backup.path.is_empty():
		return "No hay una copia válida para recuperar. " + String(backup.error)
	var stage_path := path + ".recovering"
	if FileAccess.file_exists(stage_path):
		var stage_archive_error := _archive(stage_path)
		if not stage_archive_error.is_empty():
			return stage_archive_error
	var write_error := _write_verified(stage_path, backup.state, validator)
	if not write_error.is_empty():
		return write_error
	for prior_path in [path, path + ".bak", path + ".tmp", path + ".replacing"]:
		if FileAccess.file_exists(prior_path):
			var archive_error := _archive(prior_path)
			if not archive_error.is_empty():
				return archive_error
	var install_error := DirAccess.rename_absolute(stage_path, path)
	if install_error != OK:
		return "No se pudo instalar la copia recuperada (%s)" % error_string(install_error)
	return ""


func replace_game(path: String, state: Dictionary, validator: Callable) -> String:
	var state_error := _validate_state(state, validator)
	if not state_error.is_empty():
		return state_error
	var preparation_error := _prepare_parent(path)
	if not preparation_error.is_empty():
		return preparation_error
	var stage_path := path + ".replacing"
	if FileAccess.file_exists(stage_path):
		var stage_archive_error := _archive(stage_path)
		if not stage_archive_error.is_empty():
			return stage_archive_error
	var write_error := _write_verified(stage_path, state, validator)
	if not write_error.is_empty():
		return write_error
	for prior_path in [path, path + ".bak", path + ".tmp", path + ".recovering"]:
		if FileAccess.file_exists(prior_path):
			var archive_error := _archive(prior_path)
			if not archive_error.is_empty():
				return archive_error
	var install_error := DirAccess.rename_absolute(stage_path, path)
	if install_error != OK:
		return "No se pudo instalar la partida nueva (%s)" % error_string(install_error)
	return ""


func _result(status: String, state: Dictionary, error: String) -> Dictionary:
	return {"status": status, "state": state, "error": error}


func _recovery_source(path: String, validator: Callable) -> Dictionary:
	var last_error: String = ""
	# A verified backup has priority. Staged data is only offered for explicit
	# recovery when no primary/backup can be used; never create a fresh save over it.
	for suffix: String in [".bak", ".recovering", ".replacing", ".tmp"]:
		var candidate := path + suffix
		if FileAccess.file_exists(candidate):
			var data := _read_valid_state(candidate, validator)
			if data.error.is_empty():
				return {"path": candidate, "state": data.state, "error": ""}
			last_error = data.error
	return {"path": "", "state": {}, "error": last_error}


func _validate_state(state: Dictionary, validator: Callable) -> String:
	if not validator.is_valid():
		return "El validador no es invocable"
	var validation: Variant = validator.call(state)
	if not validation is String:
		return "El validador devolvió un resultado inválido"
	return validation as String


func _read_valid_state(path: String, validator: Callable) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"state": {}, "error": "No se pudo leer el archivo (%s)" % error_string(FileAccess.get_open_error())}
	var length := file.get_length()
	if length > MAX_FILE_BYTES:
		file.close()
		return {"state": {}, "error": "El archivo es demasiado grande"}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var parse_error := json.parse(text)
	if parse_error != OK:
		return {"state": {}, "error": "JSON dañado en la línea %d" % json.get_error_line()}
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return {"state": {}, "error": "La raíz JSON no es un objeto"}
	var state: Dictionary = parsed
	var validation_error := _validate_state(state, validator)
	if not validation_error.is_empty():
		return {"state": {}, "error": validation_error}
	return {"state": state, "error": ""}


func _write_verified(path: String, state: Dictionary, validator: Callable) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "No se pudo abrir el temporal para escritura (%s)" % error_string(FileAccess.get_open_error())
	file.store_string(JSON.stringify(state))
	file.flush()
	var file_error := file.get_error()
	file.close()
	if file_error != OK:
		return "No se pudo completar la escritura (%s)" % error_string(file_error)
	var verification := _read_valid_state(path, validator)
	if not verification.error.is_empty():
		return "La verificación del temporal falló: " + verification.error
	return ""


func _prepare_parent(path: String) -> String:
	var parent := path.get_base_dir()
	if DirAccess.dir_exists_absolute(parent):
		return ""
	var result := DirAccess.make_dir_recursive_absolute(parent)
	if result != OK:
		return "No se pudo crear la carpeta de guardado (%s)" % error_string(result)
	return ""


func _archive(path: String) -> String:
	var suffix := "%d" % Time.get_ticks_usec()
	var archive_path := path + ".archive-" + suffix
	var counter := 1
	while FileAccess.file_exists(archive_path):
		archive_path = path + ".archive-%s-%d" % [suffix, counter]
		counter += 1
	var archive_error := DirAccess.rename_absolute(path, archive_path)
	if archive_error != OK:
		return "No se pudo archivar %s (%s)" % [path.get_file(), error_string(archive_error)]
	return ""
