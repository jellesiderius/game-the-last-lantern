extends Node
## Live world state. Only explicit load replaces it from disk; death never does.
signal progress_changed
var active_slot := -1
var data: Dictionary = {}
var defeated_since_rest: Dictionary = {}
var save_error := ""


func _ready() -> void:
	process_physics_priority = 90


func _physics_process(_delta: float) -> void:
	if (
		active_slot < 0
		or data.is_empty()
		or GameClock.paused
		or SceneTransit.active
		or Checkpoints.active
	):
		return
	var player := get_tree().get_first_node_in_group("player") as PlayerCharacter
	if player == null or player.state in ["entrance", "dead", "scene_travel"]:
		return
	data.play_seconds += GameClock.dt


func ensure_preview() -> void:
	if data.is_empty():
		data = SaveSchema.new_game()


func leave_game() -> void:
	active_slot = -1
	data = {}
	defeated_since_rest.clear()


func apply_stats(player: PlayerCharacter, restore := true) -> void:
	if data.is_empty():
		return
	player.health.maximum = data.stats.max_health
	player.magic.maximum = int(data.stats.max_magic)
	if restore:
		player.health.reset()
		player.magic.reset()


func capture_stats(player: PlayerCharacter) -> void:
	if player == null or data.is_empty():
		return
	data.stats.max_health = player.health.maximum
	data.stats.max_magic = player.magic.maximum
	data.display_lives = int(ceil(player.health.maximum))


func save(player: PlayerCharacter = null) -> bool:
	if active_slot < 0:
		save_error = "Testwereld — er is geen save slot actief."
		return false
	capture_stats(player)
	var result := SaveStore.write_slot(active_slot, data)
	save_error = result.error
	if result.ok:
		data.last_saved_unix = result.data.last_saved_unix
		progress_changed.emit()
	return result.ok


func set_world_flag(code: String, value: Variant = true) -> void:
	ensure_preview()
	data.world[code] = value
	progress_changed.emit()


func world_flag(code: String) -> Variant:
	return data.get("world", {}).get(code, false)


func is_lit(code: String) -> bool:
	return code in data.get("lit_checkpoints", [])


func finish_opening() -> void:
	if data.is_empty() or data.opening_completed:
		return
	data.opening_completed = true
	# Persist just the completed introduction; its safe stump return point stays unchanged.
	if active_slot >= 0:
		save(get_tree().get_first_node_in_group("player") as PlayerCharacter)
