extends CanvasLayer
## Shared loading/presentation coordinator. PlayerCharacter owns all travel movement.
signal transition_finished(scene: Node)
signal transition_failed(reason: String)
@export_range(.1, 1, .05, "suffix:s") var menu_fade_duration := .3
@export_range(.1, 1, .05, "suffix:s") var automatic_loading_delay := .25
@export_range(.2, 2, .05, "suffix:s") var minimum_loading_time := .75
@export_range(.2, 2, .05, "suffix:s") var new_game_loading_time := 1.1
@export_range(2, 6, 1) var cached_scene_limit := 3
@export var rest_transition: SceneTravelSettings = preload("res://settings/transitions/default.tres")
var active := false
var pause_on_arrival := false
var phase := "idle"
## Prior main-thread preparation cost predicts whether a warm map needs the loading card.
var preparation_seconds: Dictionary = {}
var _scene_cache: Dictionary = {}
var _cache_order: Array[String] = []
var _pending_scenes: Dictionary = {}
var _active_path := ""
var _minimum_visible := 0.0
var _preparation_started := 0
@onready var fade: ColorRect = $Fade
@onready var loading_screen: Control = $Fade/LoadingScreen


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputRouter.controller_disconnected.connect(
		func():
			if active:
				pause_on_arrival = true
	)


func _process(_delta: float) -> void:
	for path: String in _pending_scenes.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get(path) as PackedScene
			_pending_scenes.erase(path)
			if packed:
				_scene_cache[path] = packed
				_touch_cache(path)
		elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_pending_scenes.erase(path)
	_trim_cache()
	if active:
		InputRouter.block_gameplay_input()


func _input(_event: InputEvent) -> void:
	if active:
		get_viewport().set_input_as_handled()


## Resource-only prefetch: never instantiate actors or run a second map while playing.
func prefetch_scene(path: String) -> Error:
	if _scene_cache.has(path) or _pending_scenes.has(path):
		return OK
	if _pending_scenes.size() >= 2:
		return ERR_BUSY
	if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
		return ERR_FILE_NOT_FOUND
	return _request_resource(path)


func is_scene_cached(path: String) -> bool:
	return _scene_cache.has(path)


func _request_resource(path: String) -> Error:
	if _scene_cache.has(path):
		_touch_cache(path)
		return OK
	if _pending_scenes.has(path):
		return OK
	var error := ResourceLoader.load_threaded_request(path, "PackedScene")
	if error == OK:
		_pending_scenes[path] = true
	return error


func _touch_cache(path: String) -> void:
	_cache_order.erase(path)
	_cache_order.append(path)


func _trim_cache() -> void:
	var current := get_tree().current_scene
	for path: String in _cache_order.duplicate():
		if _scene_cache.size() <= cached_scene_limit:
			break
		if path == _active_path or (current != null and path == current.scene_file_path):
			continue
		_scene_cache.erase(path)
		_cache_order.erase(path)


func _begin(path: String) -> bool:
	if active or Dialogue.active or Checkpoints.active:
		return false
	if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
		transition_failed.emit("De bestemming kon niet worden geopend.")
		return false
	active = true
	_active_path = path
	pause_on_arrival = false
	phase = "departing"
	loading_screen.hide()
	_minimum_visible = minimum_loading_time
	InputRouter.block_gameplay_input()
	return true


## Menus and other direct loads use this entry point. New Game always shows the card.
func change_scene(
	path: String,
	heading := "De wereld ontwaakt",
	always_show := false,
	prepare: Callable = Callable(),
	validate: Callable = Callable(),
	allow_loading := true
) -> bool:
	if not _begin(path):
		return false
	var was_paused := GameClock.paused
	var player := GameSession.player
	if player:
		player.suspend_controls()
	GameClock.paused = true
	_load_from_menu.call_deferred(
		path, heading, always_show, was_paused, prepare, validate, allow_loading
	)
	return true


func request(portal: ScenePortal, player: PlayerCharacter) -> bool:
	return request_destination(
		player,
		portal.target_scene,
		portal.target_spawn,
		portal.exit_direction(),
		portal.settings,
		portal.loading_title,
		portal.allow_loading_screen
	)


## Reusable travel entry point for routes whose return destination is chosen at runtime.
func request_destination(
	player: PlayerCharacter,
	path: String,
	spawn_id: StringName,
	direction: Vector3,
	travel_settings: SceneTravelSettings,
	heading: String,
	allow_loading := true,
	allow_dodge := false
) -> bool:
	if not is_instance_valid(player):
		return false
	var movable := player.state in ["locomotion", "bow_empty"]
	if GameClock.paused or not (movable or (allow_dodge and player.state == "roll")):
		return false
	if not _begin(path):
		return false
	var settings := travel_settings if travel_settings else SceneTravelSettings.new()
	# Lock gameplay immediately, in the trigger's frame, including pending attacks.
	player.begin_scene_travel(direction, settings.walk_speed, settings.exit_walk_distance)
	_travel.call_deferred(player, path, spawn_id, settings, heading, allow_loading)
	return true


func _fade_to(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fade, "modulate:a", alpha, duration)
	await tween.finished


func _render_frame() -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw


func _show_loading(heading: String) -> void:
	if not loading_screen.visible:
		loading_screen.present(heading)
		loading_screen.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(loading_screen, "modulate:a", 1.0, .16)
		await tween.finished
	# Flush actual artwork before the main-thread scene instantiation / shader preparation.
	await _render_frame()


func _prepare_scene(path: String, heading: String, allow_loading := true) -> Node:
	phase = "loading"
	var started := Time.get_ticks_msec()
	if (
		allow_loading
		and (not preparation_seconds.has(path) or float(preparation_seconds[path]) > .15)
	):
		await _show_loading(heading)
	while not _scene_cache.has(path) and _pending_scenes.has(path):
		if allow_loading and (Time.get_ticks_msec() - started) / 1000.0 >= automatic_loading_delay:
			await _show_loading(heading)
		await get_tree().process_frame
	if not _scene_cache.has(path):
		return null
	var packed: PackedScene = _scene_cache[path]
	_touch_cache(path)
	_preparation_started = Time.get_ticks_msec()
	return packed.instantiate()


func _replace_scene(old_scene: Node, next_scene: Node) -> void:
	AttackTokenManager.reset()
	old_scene.queue_free()
	await get_tree().process_frame
	get_tree().root.add_child(next_scene)
	get_tree().current_scene = next_scene
	# Some menu roots reset GameClock in _ready. Keep the covered scene frozen.
	GameClock.paused = true


func _finish_preparing(path: String) -> void:
	await DungeonTravel.prepare_arrival()
	await _render_frame()
	await _render_frame()
	preparation_seconds[path] = (Time.get_ticks_msec() - _preparation_started) / 1000.0
	if loading_screen.visible:
		var remaining: float = (
			_minimum_visible - (Time.get_ticks_msec() - loading_screen.shown_at_msec) / 1000.0
		)
		if remaining > 0:
			await get_tree().create_timer(remaining).timeout


func _load_from_menu(
	path: String,
	heading: String,
	always_show: bool,
	was_paused: bool,
	prepare: Callable,
	validate: Callable,
	allow_loading: bool
) -> void:
	var old_scene := get_tree().current_scene
	fade.show()
	fade.modulate.a = 0.0
	if always_show:
		_minimum_visible = new_game_loading_time
		loading_screen.present(heading)
		loading_screen.modulate.a = 1.0
	var error := _request_resource(path)
	await _fade_to(1, menu_fade_duration)
	await _render_frame()
	if error != OK:
		await _recover(
			null, "De bestemming kon niet worden geladen.", menu_fade_duration, was_paused
		)
		return
	var next_scene := await _prepare_scene(path, heading, allow_loading)
	if next_scene == null:
		await _recover(
			null, "De bestemming kon niet worden geladen.", menu_fade_duration, was_paused
		)
		return
	if validate.is_valid() and not validate.call(next_scene):
		next_scene.free()
		await _recover(
			null,
			"Het aankomstpunt is niet beschikbaar of niet uniek. De save is behouden.",
			menu_fade_duration,
			was_paused
		)
		return
	await _replace_scene(old_scene, next_scene)
	if prepare.is_valid():
		prepare.call(next_scene)
	await _finish_preparing(path)
	phase = "arriving"
	await _fade_to(0, menu_fade_duration)
	# In particular, the seated forest introduction starts only when it can be seen.
	GameClock.reset()
	_complete(next_scene)


func _travel(
	player: PlayerCharacter,
	path: String,
	spawn_id: StringName,
	settings: SceneTravelSettings,
	heading: String,
	allow_loading: bool
) -> void:
	var old_scene := get_tree().current_scene
	GameProgress.capture_stats(player)
	var hp := player.health.current
	var magic := player.magic.current
	var load_error := _request_resource(path)
	if load_error != OK:
		await _recover(player, "De bestemming kon niet worden geladen.", settings.fade_duration)
		return
	fade.show()
	fade.modulate.a = 0
	await get_tree().create_timer(settings.departure_fade_delay).timeout
	await _fade_to(1, settings.fade_duration)
	while is_instance_valid(player) and not player.scene_travel_done:
		await get_tree().physics_frame
	if not is_instance_valid(player) or get_tree().current_scene != old_scene:
		await _recover(
			player, "De vertrekmap is tijdens het laden veranderd.", settings.fade_duration
		)
		return
	GameClock.paused = true
	if settings.black_hold > 0:
		await get_tree().create_timer(settings.black_hold).timeout
	var next_scene := await _prepare_scene(path, heading, allow_loading)
	if next_scene == null:
		await _recover(player, "De bestemming kon niet worden geladen.", settings.fade_duration)
		return
	# Validate the spawn before removing the current map.
	var spawn: SceneSpawnPoint
	for node in next_scene.find_children("*", "Marker3D", true, false):
		if node is SceneSpawnPoint and node.spawn_key() == spawn_id:
			if spawn != null:
				next_scene.free()
				await _recover(player, "Het aankomstpunt is niet uniek.", settings.fade_duration)
				return
			spawn = node
	var next_player := next_scene.get_node_or_null("Player") as PlayerCharacter
	if spawn == null or next_player == null:
		next_scene.free()
		await _recover(
			player, "De bestemming mist een speler of aankomstpunt.", settings.fade_duration
		)
		return
	await _replace_scene(old_scene, next_scene)
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
	await _finish_preparing(path)
	GameClock.paused = false
	phase = "arriving"
	await get_tree().physics_frame
	await _fade_to(0, settings.fade_duration)
	while is_instance_valid(next_player) and not next_player.scene_travel_done:
		await get_tree().physics_frame
	if is_instance_valid(next_player):
		next_player.finish_scene_travel()
	_complete(next_scene)


func _complete(next_scene: Node) -> void:
	fade.hide()
	loading_screen.hide()
	InputRouter.block_gameplay_input()
	active = false
	_active_path = ""
	phase = "idle"
	transition_finished.emit(next_scene)
	if pause_on_arrival and next_scene.has_node("HUD"):
		next_scene.get_node("HUD")._controller_disconnected()


## A short rest/save refresh uses the same curtain, with no scene load or rollback of live progress.
func refresh_world(refresh: Callable) -> void:
	if active or not refresh.is_valid():
		return
	active = true
	phase = "refreshing"
	var was_paused := GameClock.paused
	GameClock.paused = true
	InputRouter.block_gameplay_input()
	loading_screen.hide()
	fade.modulate.a = 0.0
	fade.show()
	await _fade_to(1.0, rest_transition.fade_duration)
	refresh.call()
	if rest_transition.black_hold > 0:
		await get_tree().create_timer(rest_transition.black_hold).timeout
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _render_frame()
	await _fade_to(0.0, rest_transition.fade_duration)
	fade.hide()
	GameClock.paused = was_paused
	active = false
	phase = "idle"
	InputRouter.block_gameplay_input()


func _recover(
	player: PlayerCharacter, reason: String, duration: float, was_paused := false
) -> void:
	if is_instance_valid(player):
		player.finish_scene_travel()
	await _fade_to(0, duration)
	fade.hide()
	loading_screen.hide()
	GameClock.paused = was_paused
	InputRouter.block_gameplay_input()
	active = false
	_active_path = ""
	phase = "idle"
	transition_failed.emit(reason)
	if pause_on_arrival and get_tree().current_scene.has_node("HUD"):
		get_tree().current_scene.get_node("HUD")._controller_disconnected()
