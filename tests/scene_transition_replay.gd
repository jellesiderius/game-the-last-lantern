extends "res://tests/forest_replay.gd"
## Lives outside the replaced level. Cross the real portals in both directions.
var switches := 0
var transition_errors: Array[String] = []


func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func tap(code: Key) -> void:
	key(code, true)
	await step(4)
	key(code, false)
	await step(4)


func cross_portal(direction: Vector3, expected: String, label: String, disconnect := false) -> void:
	p = get_tree().current_scene.get_node("Player")
	p.use_test_input = true
	p.test_input = world_input(direction)
	for i in 1600:
		await step(1)
		if SceneTransit.active:
			break
	check(label + " starts from walking into the area", SceneTransit.active)
	if not SceneTransit.active:
		return
	var departing: PlayerCharacter = p
	var start: Vector3 = p.position
	var departure_distance := 0.0
	var entry_distance := 0.0
	var arriving: PlayerCharacter
	var entry_start := Vector3.ZERO
	var opaque_before_change := false
	var previous_scene := get_tree().current_scene
	p.request_action("dodge")
	p.request_action("light")
	await step(2)
	check(
		label + " ignores combat during travel",
		p.state == "scene_travel" and p.pending_inputs.is_empty()
	)
	check(
		label + " travel cannot be interrupted by damage",
		not p.receive_hit(1, GameClock.next_attack_id(), p.position + Vector3.RIGHT)
	)
	if disconnect:
		previous_scene.get_node("HUD")._controller_disconnected()
	for i in 1200:
		if is_instance_valid(departing):
			departure_distance = departing.position.distance_to(start)
		if SceneTransit.fade.modulate.a > .99:
			opaque_before_change = true
		if get_tree().current_scene != previous_scene and get_tree().current_scene != null:
			var candidate := get_tree().current_scene.get_node("Player") as PlayerCharacter
			if arriving == null:
				arriving = candidate
				entry_start = arriving.position
			entry_distance = candidate.position.distance_to(entry_start)
		if not SceneTransit.active:
			break
		await step(1)
	check(label + " finishes without locking input", not SceneTransit.active)
	arena = get_tree().current_scene
	p = arena.get_node("Player")
	check(label + " loads expected map", arena.name == expected, arena.name)
	check(label + " walks farther before departing", departure_distance > 1.2, departure_distance)
	check(label + " hides map replacement under full fade", opaque_before_change)
	check(label + " walks into the destination", entry_distance > 1.2, entry_distance)
	check(label + " returns normal player control", p.state == "locomotion")
	check(
		label + " preserves health and magic",
		p.health.current == 4 and p.magic.current == 2,
		[p.health.current, p.magic.current]
	)
	if disconnect:
		check(
			"disconnect waits for safe arrival then pauses",
			GameClock.paused and arena.get_node("HUD/Root/PausePanel").visible
		)
		arena.get_node("HUD")._resume()
	await step(70)
	check(
		label + " arrival does not bounce into the return portal",
		not SceneTransit.active and arena == get_tree().current_scene
	)
	await capture(label)


func review_room() -> void:
	var camera := get_viewport().get_camera_3d()
	var saved_transform := camera.global_transform
	var saved_mode := camera.physics_interpolation_mode
	var hud := arena.get_node("HUD")
	hud.hide()
	arena.set_physics_process(false)
	GameClock.paused = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for view in [
		["front", Vector3(0, 7, 16)],
		["left", Vector3(-16, 7, 0)],
		["right", Vector3(16, 7, 0)],
		["back", Vector3(0, 7, -16)]
	]:
		camera.global_position = view[1]
		camera.look_at(Vector3(0, .8, 0))
		await step(20)
		await capture("house_source_" + view[0])
	camera.global_transform = saved_transform
	await step(20)
	await capture("house_source_game")
	camera.physics_interpolation_mode = saved_mode
	GameClock.paused = false
	arena.set_physics_process(true)
	hud.show()


func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://captures/forest")
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	render_cap = Engine.max_fps
	SceneTransit.transition_finished.connect(func(_scene): switches += 1)
	SceneTransit.transition_failed.connect(func(reason): transition_errors.append(reason))
	for target in get_tree().get_nodes_in_group("damageable"):
		target.disabled = true
	p.respawn(Vector3(6, 0, -68.6))
	p.health.damage(1)
	p.magic.try_spend(2)
	arena.reset_camera()
	check("forest gate has a broad saved trigger", arena.get_node("ForestExit").trigger_size.x >= 5)
	await cross_portal(Vector3.FORWARD, "ForestPassage", "new_forest")
	await cross_portal(Vector3.FORWARD, "ForestHouse", "inside_house")
	if "--transition-review" in OS.get_cmdline_user_args():
		await review_room()
	p.use_test_input = true
	p.test_input = world_input(Vector3.FORWARD)
	await step(40)
	p.test_input = Vector2.ZERO
	p.use_test_input = false
	await step(30)
	await tap(KEY_E)
	await tap(KEY_ENTER)
	check(
		"house NPC can start its own editable dialogue",
		Dialogue.active and Dialogue.speaker_label.text == "Linde"
	)
	await capture("house_conversation")
	await tap(KEY_ESCAPE)
	await cross_portal(Vector3.BACK, "ForestPassage", "outside_house", true)
	await cross_portal(Vector3.BACK, "ForestOpening", "back_in_first_forest")
	check("all four real portal crossings completed", switches == 4, switches)
	var portal := preload("res://scenes/components/ScenePortal.tscn").instantiate() as ScenePortal
	arena.add_child(portal)
	portal.enabled = false
	portal.target_scene = "res://missing_map.tscn"
	check(
		"unconfigured destination leaves gameplay usable",
		not SceneTransit.request(portal, p) and not SceneTransit.active
	)
	portal.target_scene = "res://scenes/levels/ForestPassage.tscn"
	portal.target_spawn = &"MissingSpawn"
	var original := arena
	SceneTransit.request(portal, p)
	for i in 600:
		await step(1)
		if not SceneTransit.active:
			break
	check(
		"missing spawn recovers in original map",
		(
			not SceneTransit.active
			and get_tree().current_scene == original
			and not GameClock.paused
			and p.state == "locomotion"
		)
	)
	check(
		"bad destination emits a failure signal", transition_errors.size() == 2, transition_errors
	)
	portal.queue_free()
	var report := {
		"cap": render_cap,
		"checks": results,
		"failures": failures,
		"render_frames": Engine.get_frames_drawn() - initial_render_frame
	}
	(
		FileAccess
		. open("res://captures/forest/transition_checks_%d.json" % render_cap, FileAccess.WRITE)
		. store_string(JSON.stringify(report, "\t"))
	)
	print("SCENE_TRANSITION_REPLAY_RESULT ", JSON.stringify(report))
	get_tree().quit(1 if failures else 0)
