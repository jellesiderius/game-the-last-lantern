extends Node
## Disk access only; never owns live progress or reloads it after death.
signal slots_changed
signal save_succeeded(slot: int, saved_at: float)
var directory := "user://saves"
var last_error := ""
const MAX_BYTES := 8 * 1024 * 1024


func _init() -> void:
	# Replays get their own disposable directory; they cannot touch a player's slots.
	for flag in ["--intro-replay", "--loading-replay", "--checkpoint-replay", "--save-replay"]:
		if flag in OS.get_cmdline_user_args():
			directory = "user://save_tests/run_%d" % OS.get_process_id()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save-test-root="):
			var name := arg.trim_prefix("--save-test-root=")
			if name.is_valid_filename() and not name.is_empty():
				directory = "user://save_tests/" + name


func _path(slot: int, suffix := ".json") -> String:
	return directory.path_join("slot_%d" % (slot + 1) + suffix)


func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {}
	var envelope: Variant = JSON.parse_string(file.get_as_text())
	if not envelope is Dictionary or not envelope.get("payload") is String:
		return {}
	var payload: String = envelope.payload
	if envelope.get("checksum", "") != payload.sha256_text():
		return {}
	var data: Variant = JSON.parse_string(payload)
	return data if SaveSchema.valid(data) else {}


func inspect_slot(slot: int) -> Dictionary:
	if slot < 0 or slot >= SaveSchema.SLOT_COUNT:
		return {"state": "invalid", "data": {}}
	if FileAccess.file_exists(_path(slot, ".deleted")):
		return {"state": "empty", "data": {}}
	var data := _read(_path(slot))
	if not data.is_empty():
		return {"state": "filled", "data": data, "recovered": false}
	data = _read(_path(slot, ".bak"))
	if not data.is_empty():
		return {"state": "filled", "data": data, "recovered": true}
	# An interrupted/corrupt slot is occupied: selecting it must never overwrite it.
	for suffix in [".json", ".bak", ".tmp"]:
		if FileAccess.file_exists(_path(slot, suffix)):
			return {"state": "damaged", "data": {}}
	return {"state": "empty", "data": {}}


func read_slot(slot: int) -> Dictionary:
	return inspect_slot(slot).get("data", {}).duplicate(true)


func _write_file(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	return ok


func write_slot(slot: int, snapshot: Dictionary, create_only := false) -> Dictionary:
	last_error = ""
	if slot < 0 or slot >= SaveSchema.SLOT_COUNT or not SaveSchema.valid(snapshot):
		return _failure("Dit spel kan niet worden opgeslagen: de savegegevens zijn ongeldig.")
	if create_only and inspect_slot(slot).state != "empty":
		return _failure("Dit slot is al bezet. Kies het om te laden of verwijder het eerst.")
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return _failure("Opslaan is niet gelukt. De opslagmap is niet beschikbaar.")
	var saved := snapshot.duplicate(true)
	saved.last_saved_unix = Time.get_unix_time_from_system()
	var payload := JSON.stringify(saved)
	var envelope := JSON.stringify({"payload": payload, "checksum": payload.sha256_text()})
	if not _write_file(_path(slot, ".tmp"), envelope) or _read(_path(slot, ".tmp")).is_empty():
		return _failure(
			"Opslaan is niet gelukt. Controleer de vrije schijfruimte en probeer opnieuw."
		)
	# Keep the previous valid generation. A corrupt primary never replaces a good backup.
	var previous := _read(_path(slot)) if not create_only else {}
	if not previous.is_empty() or not FileAccess.file_exists(_path(slot, ".bak")) or create_only:
		var backup_text := (
			envelope if previous.is_empty() else FileAccess.get_file_as_string(_path(slot))
		)
		if not _write_file(_path(slot, ".bak.tmp"), backup_text):
			return _failure("Opslaan is niet gelukt: de herstelkopie kon niet worden geschreven.")
		if DirAccess.rename_absolute(_path(slot, ".bak.tmp"), _path(slot, ".bak")) != OK:
			return _failure("Opslaan is niet gelukt: de herstelkopie kon niet worden bijgewerkt.")
	if DirAccess.rename_absolute(_path(slot, ".tmp"), _path(slot)) != OK:
		return _failure("Opslaan is niet gelukt: het nieuwe bestand kon niet worden geplaatst.")
	if FileAccess.file_exists(_path(slot, ".deleted")):
		if DirAccess.remove_absolute(_path(slot, ".deleted")) != OK:
			return _failure("Het nieuwe spel kon niet worden geactiveerd. Probeer opnieuw.")
	if _read(_path(slot)).is_empty():
		return _failure("De opgeslagen voortgang kon niet worden gecontroleerd.")
	slots_changed.emit()
	save_succeeded.emit(slot, saved.last_saved_unix)
	return {"ok": true, "data": saved, "error": ""}


func _failure(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message, "data": {}}


## Call only after the UI's separate explicit confirmation.
func delete_slot(slot: int) -> bool:
	if slot < 0 or slot >= SaveSchema.SLOT_COUNT:
		return false
	# A tombstone prevents a partially removed backup from resurrecting a deleted game.
	if not _write_file(_path(slot, ".deleted"), "deleted"):
		last_error = "Verwijderen is niet gelukt. Het slot is behouden."
		return false
	for suffix in [".json", ".bak", ".tmp", ".bak.tmp", ".played"]:
		if FileAccess.file_exists(_path(slot, suffix)):
			DirAccess.remove_absolute(_path(slot, suffix))
	slots_changed.emit()
	return true


func mark_played(slot: int) -> void:
	if slot >= 0 and slot < SaveSchema.SLOT_COUNT:
		_write_file(_path(slot, ".played"), str(Time.get_unix_time_from_system()))


func preferred_slot(new_game: bool) -> int:
	var newest := -1.0
	var preferred := 0
	for slot in SaveSchema.SLOT_COUNT:
		var summary := inspect_slot(slot)
		if new_game and summary.state == "empty":
			return slot
		if summary.state == "filled":
			var played := float(summary.data.last_saved_unix)
			if FileAccess.file_exists(_path(slot, ".played")):
				played = maxf(
					played, FileAccess.get_file_as_string(_path(slot, ".played")).to_float()
				)
			if played > newest:
				newest = played
				preferred = slot
	return preferred
