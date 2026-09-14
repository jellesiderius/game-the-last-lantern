extends Node
## Interaction and arrival coordinator. SaveStore owns disk; GameProgress owns the live world.
signal rest_started(point: Node3D)
signal rested(point: Node3D)
signal world_refreshed
signal respawned
signal arrival_failed(message: String)
@export var areas: Array[WorldArea] = [
	preload("res://settings/areas/forest_opening.tres"),
	preload("res://settings/areas/forest_passage.tres"),
	preload("res://settings/areas/forest_house.tres")
]
@export var new_game_loading_title := "Een nieuw avontuur"
var active := false
var current_point: Node3D
var reader: PlayerCharacter
var arrival_kind := ""
var previous_context: Dictionary = {}
var rest_menu: Control


func _ready() -> void:
	for area in WorldArea.discover():
		if area_for(area.code) == null:
			areas.append(area)
	SceneTransit.transition_finished.connect(_arrived)
	SceneTransit.transition_failed.connect(_arrival_failed)
	InputRouter.controller_disconnected.connect(_disconnected)


func _disconnected() -> void:
	# Rest is already modal. Keep it safely paused; a replacement device can continue.
	if active and is_instance_valid(rest_menu):
		rest_menu.show_message(
			"Controller losgekoppeld. Gebruik een toets om verder te gaan.", false
		)


func area_for(code: String) -> WorldArea:
	for area in areas:
		if area != null and area.code == code:
			return area
	return null


func should_play_opening() -> bool:
	return (
		arrival_kind in ["new", "load"]
		and not GameProgress.data.get("opening_completed", false)
		and GameProgress.data.get("checkpoint", {}).get("id") == SaveSchema.START_ID
	)


func start_slot(slot: int) -> bool:
	if SceneTransit.active or active:
		return false
	var summary := SaveStore.inspect_slot(slot)
	if summary.state == "filled":
		return _launch(summary.data, slot, "load")
	if summary.state != "empty":
		arrival_failed.emit(
			"Dit slot kan niet worden geladen. De bestaande bestanden zijn behouden."
		)
		return false
	var result := SaveStore.write_slot(slot, SaveSchema.new_game(), true)
	if not result.ok:
		arrival_failed.emit(result.error)
		return false
	return _launch(result.data, slot, "new")


func _launch(snapshot: Dictionary, slot: int, kind: String) -> bool:
	var area := area_for(snapshot.checkpoint.area)
	if area == null:
		arrival_failed.emit("Het opgeslagen gebied is niet beschikbaar. De save is behouden.")
		return false
	previous_context = {
		"slot": GameProgress.active_slot,
		"data": GameProgress.data.duplicate(true),
		"defeated": GameProgress.defeated_since_rest.duplicate(true)
	}
	arrival_kind = kind
	GameProgress.active_slot = slot
	GameProgress.data = snapshot.duplicate(true)
	if kind != "death":
		GameProgress.defeated_since_rest.clear()
	var title := new_game_loading_title if kind == "new" else "Terug bij het licht"
	var started := SceneTransit.change_scene(
		area.scene_path, title, kind == "new", _prepare_arrival, _validate_arrival, kind != "death"
	)
	if not started:
		_restore_context()
	return started


func _matching_anchor(scene: Node, code: String) -> Node3D:
	var match_node: Node3D
	for node in scene.find_children("*", "Node3D", true, false):
		var candidate: Node3D
		if node is CheckpointAnchor and node.checkpoint_id == code:
			candidate = node
		elif node is Vuurlelie and node.checkpoint_id == code:
			candidate = node.get_node_or_null(node.spawn_path)
		if candidate != null:
			if match_node != null:
				return null  # Ambiguous IDs must not silently select an unrelated spawn.
			match_node = candidate
	return match_node


func _validate_arrival(scene: Node) -> bool:
	return (
		scene.get_node_or_null("Player") is PlayerCharacter
		and _matching_anchor(scene, GameProgress.data.checkpoint.id) != null
	)


func _prepare_arrival(scene: Node) -> void:
	var player := scene.get_node("Player") as PlayerCharacter
	GameProgress.apply_stats(player)
	if should_play_opening():
		return
	var anchor := _matching_anchor(scene, GameProgress.data.checkpoint.id)
	player.respawn(anchor.global_position)
	player.facing = -anchor.global_basis.z.normalized()
	player.pivot.rotation.y = atan2(-player.facing.x, -player.facing.z)
	player.reset_physics_interpolation()
	if scene.has_method("reset_camera"):
		scene.reset_camera()


func _arrived(_scene: Node) -> void:
	if arrival_kind.is_empty():
		return
	if arrival_kind != "death":
		SaveStore.mark_played(GameProgress.active_slot)
	else:
		respawned.emit()
	arrival_kind = ""
	previous_context.clear()


func _restore_context() -> void:
	if not previous_context.is_empty():
		GameProgress.active_slot = previous_context.slot
		GameProgress.data = previous_context.data
		GameProgress.defeated_since_rest = previous_context.defeated
	previous_context.clear()
	arrival_kind = ""


func _arrival_failed(message: String) -> void:
	if not arrival_kind.is_empty():
		_restore_context()
		arrival_failed.emit(message)


func respawn_player() -> bool:
	if GameProgress.active_slot < 0 or GameProgress.data.is_empty() or SceneTransit.active:
		return false
	# Capture live upgrades/inventory/flags. Do NOT call SaveStore.read_slot here.
	GameProgress.capture_stats(get_tree().get_first_node_in_group("player") as PlayerCharacter)
	return _launch(GameProgress.data, GameProgress.active_slot, "death")


func begin_rest(point: Vuurlelie, player: PlayerCharacter) -> bool:
	if active or SceneTransit.active or Dialogue.active or GameClock.paused:
		return false
	if player.state not in ["locomotion", "bow_empty"] or not point.can_interact(player):
		return false
	GameProgress.ensure_preview()
	active = true
	current_point = point
	reader = player
	InputRouter.block_gameplay_input()
	player.begin_rest_action(point, GameProgress.is_lit(point.checkpoint_id))
	rest_started.emit(point)
	return true


func finish_sitting() -> void:
	if not active or not is_instance_valid(current_point) or not is_instance_valid(reader):
		cancel_rest()
		return
	var point := current_point as Vuurlelie
	if not GameProgress.is_lit(point.checkpoint_id):
		GameProgress.data.lit_checkpoints.append(String(point.checkpoint_id))
	point.set_lit(true)
	reader.hold_rest_pose()
	GameClock.paused = true
	InputRouter.block_gameplay_input()
	rest_menu = get_node("UI/RestMenu")
	rest_menu.open(point.location_title())


func _respawn_world() -> void:
	# Clear defeats globally, including unloaded areas; their actors restore on next entry.
	# Loaded actors reset now. Permanent world flags and defeated bosses stay intact.
	GameProgress.defeated_since_rest.clear()
	for enemy in get_tree().get_nodes_in_group("damageable"):
		if enemy.has_method("rest_respawn"):
			enemy.rest_respawn()
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		projectile.queue_free()
	world_refreshed.emit()


func cancel_rest() -> void:
	if is_instance_valid(current_point):
		current_point.set_lit(GameProgress.is_lit(current_point.checkpoint_id))
	if is_instance_valid(reader):
		reader.finish_rest_action()
	active = false
	current_point = null
	reader = null
	GameClock.paused = false
	InputRouter.block_gameplay_input()


func menu_action(id: StringName) -> void:
	if not active or SceneTransit.active or rest_menu.busy:
		return
	match id:
		&"rest":
			rest_menu.set_busy(true)
			rest_menu.show_message("", false)
			await SceneTransit.refresh_world(_rest_world)
			var saved := GameProgress.save(reader)
			rest_menu.set_busy(false)
			rest_menu.buttons.get_node("rest").grab_focus()
			if not saved:
				rest_menu.show_message(GameProgress.save_error, false)
			rested.emit(current_point)
		&"continue":
			rest_menu.close()


func _rest_world() -> void:
	reader.health.reset()
	reader.magic.reset()
	GameProgress.data.checkpoint = {
		"id": String(current_point.checkpoint_id),
		"area": String(current_point.area.code),
		"location": current_point.location_title()
	}
	_respawn_world()
