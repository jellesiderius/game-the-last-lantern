extends CanvasLayer
## Persistent presentation/loading coordinator. PlayerCharacter owns all travel movement.
signal transition_finished(scene: Node)
signal transition_failed(reason: String)
var active := false
var pause_on_arrival := false
var phase := "idle"
@onready var fade: ColorRect = $Fade


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func request(portal: ScenePortal, player: PlayerCharacter) -> bool:
	if (
		active
		or GameClock.paused
		or Dialogue.active
		or player.state not in ["locomotion", "bow_empty"]
	):
		return false
	if (
		portal.target_scene.is_empty()
		or not ResourceLoader.exists(portal.target_scene, "PackedScene")
	):
		transition_failed.emit("No destination scene configured")
		return false
	active = true
	pause_on_arrival = false
	phase = "departing"
	var settings := portal.settings if portal.settings else SceneTravelSettings.new()
	_travel.call_deferred(
		player, portal.target_scene, portal.target_spawn, portal.exit_direction(), settings
	)
	return true


func _fade_to(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fade, "modulate:a", alpha, duration)
	await tween.finished


func _travel(
	player: PlayerCharacter,
	path: String,
	spawn_id: StringName,
	direction: Vector3,
	settings: SceneTravelSettings
) -> void:
	var old_scene := get_tree().current_scene
	var hp := player.health.current
	var magic := player.magic.current
	var load_error := ResourceLoader.load_threaded_request(path, "PackedScene")
	if load_error != OK:
		await _recover(player, "Destination could not be loaded", settings.fade_duration)
		return
	InputRouter.block_gameplay_input()
	player.begin_scene_travel(direction, settings.walk_speed, settings.exit_walk_distance)
	fade.show()
	fade.modulate.a = 0
	# Begin darkening during the extra steps; the actor is never visibly teleported.
	await get_tree().create_timer(.12).timeout
	await _fade_to(1, settings.fade_duration)
	while is_instance_valid(player) and not player.scene_travel_done:
		await get_tree().physics_frame
	if not is_instance_valid(player) or get_tree().current_scene != old_scene:
		await _recover(player, "Source scene changed during travel", settings.fade_duration)
		return
	GameClock.paused = true
	phase = "loading"
	await get_tree().create_timer(settings.black_hold).timeout
	var status := ResourceLoader.load_threaded_get_status(path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(path)
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		await _recover(player, "Destination load failed", settings.fade_duration)
		return
	var packed := ResourceLoader.load_threaded_get(path) as PackedScene
	# Validate the spawn on an unattached instance before removing the current map.
	var next_scene := packed.instantiate()
	var spawn: SceneSpawnPoint
	for node in next_scene.find_children("*", "Marker3D", true, false):
		if node is SceneSpawnPoint and node.spawn_id == spawn_id:
			spawn = node
			break
	var next_player := next_scene.get_node_or_null("Player") as PlayerCharacter
	if spawn == null or next_player == null:
		next_scene.free()
		await _recover(
			player, "Destination needs Player and matching SceneSpawnPoint", settings.fade_duration
		)
		return
	AttackTokenManager.reset()
	old_scene.queue_free()
	await get_tree().process_frame
	get_tree().root.add_child(next_scene)
	get_tree().current_scene = next_scene
	next_player.global_position = spawn.global_position
	next_player.reset_physics_interpolation()
	next_player.health.current = clampf(hp, 0, next_player.health.maximum)
	next_player.health.changed.emit(next_player.health.current, next_player.health.maximum)
	next_player.magic.current = mini(magic, next_player.magic.maximum)
	next_player.magic.changed.emit(
		next_player.magic.current, next_player.magic.maximum, &"scene_travel"
	)
	next_player.begin_scene_travel(
		spawn.entry_direction(), settings.walk_speed, settings.entry_walk_distance
	)
	if next_scene.has_method("reset_camera"):
		next_scene.reset_camera()
	GameClock.paused = false
	phase = "arriving"
	await get_tree().physics_frame
	await _fade_to(0, settings.fade_duration)
	while is_instance_valid(next_player) and not next_player.scene_travel_done:
		await get_tree().physics_frame
	if is_instance_valid(next_player):
		next_player.finish_scene_travel()
	fade.hide()
	InputRouter.block_gameplay_input()
	active = false
	phase = "idle"
	transition_finished.emit(next_scene)
	if pause_on_arrival and next_scene.has_node("HUD"):
		next_scene.get_node("HUD")._controller_disconnected()


func _recover(player: PlayerCharacter, reason: String, duration: float) -> void:
	GameClock.paused = false
	if is_instance_valid(player):
		player.finish_scene_travel()
	await _fade_to(0, duration)
	fade.hide()
	InputRouter.block_gameplay_input()
	active = false
	phase = "idle"
	transition_failed.emit(reason)
