extends "res://tests/room_replay.gd"
## Focused native portal journey. Save fixtures always live in an isolated test directory.
var dungeon: DungeonDefinition
var seen_hidden := false
var seen_loading := false
var switches := 0
var transit_errors: Array[String] = []
var frame_spikes: Array = []
var measurement_started := false


func _process(delta: float) -> void:
	if measurement_started and delta > .025:
		frame_spikes.append(
			{
				"ms": snappedf(delta * 1000.0, .01),
				"phase": SceneTransit.phase,
				"alpha": SceneTransit.fade.modulate.a
			}
		)


func capture(label: String) -> void:
	if (
		DisplayServer.get_name() == "headless"
		or "--portal-performance-only" in OS.get_cmdline_user_args()
	):
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		"res://captures/drempelpoort/" + label + ".png"
	)


func open_fixture(path: String) -> void:
	var previous := get_tree().current_scene
	arena = load(path).instantiate()
	if "play_entrance" in arena:
		arena.play_entrance = false
	if previous != self and is_instance_valid(previous):
		previous.queue_free()
		await get_tree().process_frame
	get_tree().root.add_child(arena)
	get_tree().current_scene = arena
	await step(8)
	p = arena.get_node("Player")
	p.use_test_input = true
	p.test_input = Vector2.ZERO
	for enemy in get_tree().get_nodes_in_group("damageable"):
		enemy.disabled = true


func approach(portal: ScenePortal, rolling: bool, expected: String, label: String) -> bool:
	var forward := portal.exit_direction()
	p.respawn(portal.global_position - forward * 1.7)
	p.use_test_input = true
	p.test_input = Vector2.ZERO
	p.facing = forward
	arena.reset_camera()
	await step(8)
	p.health.current = 3
	p.magic.current = 2
	p.test_input = world_input(forward)
	await step(1)
	measurement_started = true
	if rolling:
		p.request_action("dodge")
	var last_state := p.state
	for i in 360:
		last_state = p.state
		await step(1)
		if SceneTransit.active:
			break
	check(
		label + " triggers from " + ("roll" if rolling else "walk"),
		SceneTransit.active,
		{"state_before": last_state, "position": p.position}
	)
	if not SceneTransit.active:
		await capture(label + "_failed")
		return false
	if rolling:
		check(label + " catches the roll before it ends", last_state == "roll", last_state)
	check(label + " locks player immediately", p.state == "scene_travel")
	check(label + " rejects duplicate requests", not SceneTransit.request(portal, p))
	seen_loading = false
	seen_hidden = false
	var travel_started := Time.get_ticks_msec()
	var old_actor := p
	var hidden_captured := false
	var partial_captured := false
	var plane := portal.global_position
	var loading_captured := false
	for i in 1800:
		if is_instance_valid(old_actor) and not partial_captured:
			var plane_distance := (old_actor.global_position - plane).dot(forward)
			if plane_distance > -.4 and plane_distance < -.12:
				partial_captured = true
				await capture(label + "_partial")
		if is_instance_valid(old_actor) and not old_actor.visible:
			seen_hidden = true
			if not hidden_captured:
				check(
					label + " stops departure foot effects",
					(
						not old_actor.ground_feedback.enabled
						and old_actor.ground_feedback.live_puffs.is_empty()
					)
				)
				var light_energy := 0.0
				for light: Light3D in old_actor.find_children("*", "Light3D", true, false):
					light_energy += light.light_energy
				check(label + " leaves no actor light behind", light_energy < .001, light_energy)
			if not hidden_captured:
				hidden_captured = true
				await capture(label + "_absorbed")
		if SceneTransit.loading_screen.visible:
			seen_loading = true
			if not loading_captured:
				loading_captured = true
				await capture(label + "_loading")
		if not SceneTransit.active:
			break
		await step(1)
	check(label + " hides entire departing actor at portal", seen_hidden)
	check(label + " uses short fade without loading screen", not seen_loading)
	print("PORTAL_TRAVEL_MS ", label, " ", Time.get_ticks_msec() - travel_started)
	check(label + " completes once", not SceneTransit.active)
	arena = get_tree().current_scene
	check(label + " loads correct separate map", arena.name == expected, arena.name)
	p = arena.get_node("Player")
	p.use_test_input = true
	p.test_input = Vector2.ZERO
	check(label + " restores visible controllable actor", p.visible and p.state == "locomotion")
	check(label + " preserves meters", p.health.current == 3 and p.magic.current == 2)
	for enemy in get_tree().get_nodes_in_group("damageable"):
		enemy.disabled = true
	await step(20)
	check(label + " does not bounce back", not SceneTransit.active)
	await capture(label + "_arrival")
	return arena.name == expected


func asset_views(label: String) -> void:
	if "--portal-performance-only" in OS.get_cmdline_user_args():
		return
	var camera := get_viewport().get_camera_3d()
	var original := camera.global_transform
	var original_size := camera.size
	arena.set_physics_process(false)
	var at: Vector3 = arena.get_node("Poort1").global_position + Vector3.UP * 1.5
	camera.size = 4.6
	for view in [
		["front", Vector3(0, 6, 12)],
		["left", Vector3(-12, 6, 0)],
		["right", Vector3(12, 6, 0)],
		["back", Vector3(0, 6, -12)],
		["game", Vector3(9, 15, 9)]
	]:
		camera.global_position = at + view[1]
		camera.look_at(at)
		await step(4)
		await capture(label + "_" + view[0])
	camera.global_transform = original
	camera.size = original_size
	arena.set_physics_process(true)


func robustness_checks() -> void:
	# NPCs can overlap even if a custom actor is mistakenly put on the player layer.
	await open_fixture("res://scenes/levels/ForestPassage.tscn")
	var gate: ThresholdGate = arena.get_node("Drempelpoort")
	p.respawn(Vector3.ZERO)
	var enemy = load("res://scenes/actors/npcs/enemy/AcornGuard.tscn").instantiate()
	arena.add_child(enemy)
	enemy.disabled = true
	enemy.global_position = gate.global_position
	enemy.collision_layer = 2
	await step(8)
	check("non-player overlap never starts travel", not SceneTransit.active)
	enemy.queue_free()
	# Bad spawn validation must recover the actor and retain the current origin route.
	var original := gate.dungeon
	var invalid := original.duplicate() as DungeonDefinition
	invalid.entrance = &"MissingEntranceFixture"
	gate.dungeon = invalid
	p.respawn(gate.position + Vector3(0, 0, 1.0))
	await step(6)
	# Trigger coverage is above; request directly to isolate invalid destination recovery.
	gate._try_travel(p)
	check("invalid spawn starts validation", SceneTransit.active)
	for i in 900:
		await step(1)
		if not SceneTransit.active:
			break
	await step(3)  # Area overlap lists settle after the recovery teleport.
	check("failed load keeps the source forest", get_tree().current_scene == arena)
	check(
		"failed load restores actor and effects",
		p.visible and p.state == "locomotion" and p.ground_feedback.enabled and not GameClock.paused
	)
	check("failed load clears pending route", DungeonTravel.pending.is_empty())
	check("failed load restores outside trigger", not gate.overlaps_body(p))
	check("exactly one expected failure", transit_errors.size() == 1, transit_errors)
	transit_errors.clear()
	gate.dungeon = original
	# The shared preparation hook must preserve the ordinary house-door fade.
	for pair in [["HouseDoor", "ForestHouse"], ["Door", "ForestPassage"]]:
		var door: ScenePortal = arena.get_node(pair[0])
		p.respawn(door.global_position - door.exit_direction() * 1.5)
		await step(8)
		check("ordinary door starts", SceneTransit.request(door, p))
		var loading := false
		for i in 900:
			loading = loading or SceneTransit.loading_screen.visible
			await step(1)
			if not SceneTransit.active:
				break
		arena = get_tree().current_scene
		p = arena.get_node("Player")
		p.use_test_input = true
		p.test_input = Vector2.ZERO
		check("ordinary door still has no loading screen", not loading)
		check("ordinary door reaches " + pair[1], arena.name == pair[1])


func finish_dungeon() -> void:
	var definition: DungeonDefinition = arena.dungeon
	for path in arena.required_enemies:
		var enemy := arena.get_node(path)
		enemy.receive_hit(100, GameClock.next_attack_id(), p.position, 0)
	await step(4)
	check(
		"objective marks " + String(definition.id) + " complete",
		DungeonTravel.completed(definition)
	)
	check("exit reflects completion", arena.get_node("Uitgang/Visual").completed)
	var loot: int = GameProgress.data.inventory.get("lantern_shard", 0)
	check(
		"completion cannot grant loot twice",
		(
			not DungeonTravel.complete(definition)
			and GameProgress.data.inventory.get("lantern_shard", 0) == loot
		)
	)
	check(
		"completion persists to disk",
		SaveStore.read_slot(0).world.get(definition.completion_flag(), false)
	)


func run() -> void:
	SaveStore.directory = "user://save_tests/threshold_%d" % OS.get_process_id()
	GameProgress.data = SaveSchema.new_game()
	GameProgress.data.opening_completed = true
	GameProgress.active_slot = 0
	GameProgress.save()
	SceneTransit.transition_finished.connect(func(_scene): switches += 1)
	SceneTransit.transition_failed.connect(func(reason): transit_errors.append(reason))
	DirAccess.make_dir_recursive_absolute("res://captures/drempelpoort")
	prepare_window()
	if "--dungeon-rest-only" in OS.get_cmdline_user_args():
		await rest_reset_checks()
		finish()
		return
	await open_fixture("res://scenes/levels/DrempelpoortGallery.tscn")
	p.respawn(Vector3(0, 0, 2))
	arena.reset_camera()
	await step(20)
	await capture("grey_gameplay")
	await asset_views("grey")
	var gate: ThresholdGate = arena.get_node("Poort1")
	dungeon = gate.dungeon
	check("unfinished gate stays grey", not gate.get_node("Visual").completed)
	var space := arena.get_world_3d().direct_space_state
	var opening := PhysicsRayQueryParameters3D.create(
		gate.position + Vector3(0, .8, 1), gate.position + Vector3(0, .8, -1), 1
	)
	var stone := PhysicsRayQueryParameters3D.create(
		gate.position + Vector3(1.1, .8, 1), gate.position + Vector3(1.1, .8, -1), 1
	)
	check("opening has no blocking collider", space.intersect_ray(opening).is_empty())
	check("stone legs block movement", not space.intersect_ray(stone).is_empty())
	if not await approach(gate, true, "ForgottenSanctum", "gallery_roll_in"):
		finish()
		return
	check(
		"remembers exact first gate", DungeonTravel.return_route(dungeon).gate == "gate.gallery.1"
	)
	await finish_dungeon()
	if not await approach(
		arena.get_node("Uitgang"), true, "DrempelpoortGallery", "gallery_roll_out"
	):
		finish()
		return
	check(
		"returns to first gate outside trigger",
		p.position.distance_to(Vector3(-3, 0, 1.45)) < .3,
		p.position
	)
	check("return direction faces away", p.facing.dot(Vector3.BACK) > .99)
	check(
		"both entrances share completed appearance",
		arena.get_node("Poort1/Visual").completed and arena.get_node("Poort2/Visual").completed
	)
	p.respawn(Vector3(0, 0, 2))
	arena.reset_camera()
	await step(10)
	await capture("gold_gameplay")
	await asset_views("gold")
	if "--portal-presentation-only" in OS.get_cmdline_user_args():
		check(
			"native presentation drew frames",
			Engine.get_frames_drawn() - initial_render_frame > 100
		)
		finish()
		return
	if not await approach(arena.get_node("Poort2"), false, "ForgottenSanctum", "second_gate_in"):
		finish()
		return
	check(
		"second entrance replaces remembered origin",
		DungeonTravel.return_route(dungeon).gate == "gate.gallery.2"
	)
	await approach(arena.get_node("Uitgang"), false, "DrempelpoortGallery", "second_gate_out")
	check("returns to second gate", p.position.distance_to(Vector3(3, 0, 1.45)) < .3, p.position)
	# Restore real source scenes, and exercise the actual newly placed entrance in each.
	for pair in [["ForestOpening", "RootCellar"], ["ForestPassage", "ForgottenSanctum"]]:
		await open_fixture("res://scenes/levels/" + pair[0] + ".tscn")
		check(
			pair[0] + " retains its forest assets",
			arena.has_node("Assets") and arena.get_node("Assets").get_child_count() > 30
		)
		gate = arena.get_node("Drempelpoort")
		var return_at: Vector3 = gate.get_node("ReturnPoint").global_position + Vector3.BACK * .45
		p.respawn(gate.position + Vector3(0, 0, 2.6))
		arena.reset_camera()
		await step(15)
		await capture(pair[0] + "_gate")
		if not await approach(gate, true, pair[1], pair[0] + "_in"):
			finish()
			return
		await finish_dungeon()
		if not await approach(arena.get_node("Uitgang"), false, pair[0], pair[0] + "_out"):
			finish()
			return
		check(
			pair[0] + " returns to own portal", p.position.distance_to(return_at) < .3, p.position
		)
		await capture(pair[0] + "_completed")
	await robustness_checks()
	var saved := SaveStore.read_slot(0)
	for slot in [1, 2]:
		GameProgress.data = SaveSchema.new_game()
		GameProgress.active_slot = slot
		check(
			"slot %d starts with independent dungeon state" % slot,
			not DungeonTravel.completed(dungeon) and DungeonTravel.return_route(dungeon).is_empty()
		)
		GameProgress.save()
	GameProgress.active_slot = 0
	GameProgress.data = saved
	GameProgress.progress_changed.emit()
	check(
		"disk reload restores completion",
		DungeonTravel.completed(dungeon) and arena.get_node("Drempelpoort/Visual").completed
	)
	check("no transition failures", transit_errors.is_empty(), transit_errors)
	check(
		"native renderer actually drew",
		Engine.get_frames_drawn() - initial_render_frame > 100,
		Engine.get_frames_drawn() - initial_render_frame
	)
	finish()


func check_rest_guards(alive: bool, label: String) -> void:
	for path in arena.required_enemies:
		var guard := arena.get_node(path)
		check(
			label + " " + String(guard.name),
			(
				(
					guard.health.current == guard.health.maximum
					and guard.visual.visible
					and guard.collision_layer == CombatLayers.ENEMY
					and guard.get_node("Hurtbox").collision_layer == CombatLayers.TARGET_HURTBOX
				)
				if alive
				else guard.health.current == 0 and not guard.visual.visible
			)
		)


func rest_reset_checks() -> void:
	# Simulate an existing save from when these ordinary guards were marked Permanent.
	for id in ["root_cellar", "forgotten_sanctum"]:
		for number in [1, 2]:
			GameProgress.data.world["enemy:dungeon.%s.guard%d" % [id, number]] = true
	GameProgress.set_world_flag("test.permanent_door_open", true)
	check("legacy save fixture written", GameProgress.save())
	GameProgress.data = SaveStore.read_slot(0)
	for name in ["RootCellar", "ForgottenSanctum"]:
		await open_fixture("res://scenes/levels/" + name + ".tscn")
		check_rest_guards(true, name + " old permanent flags no longer prevent respawn")
		await finish_dungeon()
	check(
		"both unloaded dungeons retain defeats until rest",
		GameProgress.defeated_since_rest.size() == 4
	)
	var loot_before: int = GameProgress.data.inventory.get("lantern_shard", 0)
	for name in ["RootCellar", "ForgottenSanctum"]:
		await open_fixture("res://scenes/levels/" + name + ".tscn")
		check_rest_guards(false, name + " revisiting without resting keeps enemies defeated")
	await capture("rest_dungeon_before")
	await open_fixture("res://scenes/levels/ForestOpening.tscn")
	var ordinary := arena.get_node("AcornGuard")
	ordinary.receive_hit(999, GameClock.next_attack_id(), p.position, 0)
	# A saved enemy prefab supplies a permanent/boss-policy fixture in the loaded area.
	var permanent = load("res://scenes/actors/npcs/enemy/AcornGuard.tscn").instantiate()
	permanent.respawn_rule = 2
	permanent.persistent_id = &"test.rest_permanent_guard"
	permanent.position = Vector3(-7, 0, 4)
	arena.add_child(permanent)
	permanent.disabled = true
	await step(3)
	permanent.receive_hit(999, GameClock.next_attack_id(), p.position, 0)
	var point: Vuurlelie = arena.get_node("Vuurlelie")
	p.respawn(point.get_node(point.spawn_path).global_position)
	p.facing = (point.global_position - p.global_position).normalized()
	p.health.current = 2
	p.magic.current = 1
	arena.reset_camera()
	await step(8)
	var started := Checkpoints.begin_rest(point, p)
	check("forest lily opens rest menu", started)
	if not started:
		return
	for i in 900:
		if (
			GameClock.paused
			and is_instance_valid(Checkpoints.rest_menu)
			and Checkpoints.rest_menu.visible
		):
			break
		await step(1)
	check(
		"sitting alone preserves defeats and meters",
		(
			GameProgress.defeated_since_rest.size() == 5
			and ordinary.health.current == 0
			and p.health.current == 2
			and p.magic.current == 1
		)
	)
	var refresh_cover: Array[float] = []
	Checkpoints.world_refreshed.connect(func(): refresh_cover.append(SceneTransit.fade.modulate.a))
	await Checkpoints.menu_action(&"rest")
	check(
		"rest resets defeated enemies across all areas", GameProgress.defeated_since_rest.is_empty()
	)
	check(
		"world resets under existing full fade",
		refresh_cover.size() == 1 and refresh_cover[0] > .999
	)
	check(
		"loaded forest enemy returns healthy at spawn",
		(
			ordinary.health.current == ordinary.health.maximum
			and ordinary.global_position.distance_to(ordinary.spawn_position) < .01
		)
	)
	check(
		"defeated boss policy stays permanent",
		permanent.health.current == 0 and GameProgress.world_flag("enemy:test.rest_permanent_guard")
	)
	check(
		"rest restores player meters",
		p.health.current == p.health.maximum and p.magic.current == p.magic.maximum
	)
	check(
		"rest preserves permanent world progress",
		GameProgress.world_flag("test.permanent_door_open")
	)
	check(
		"rest saved the forest checkpoint",
		SaveStore.read_slot(0).checkpoint.id == String(point.checkpoint_id)
	)
	check("rest has no loading screen", not SceneTransit.loading_screen.visible)
	Checkpoints.menu_action(&"continue")
	for i in 180:
		if not Checkpoints.active:
			break
		await step(1)
	check("rest closes with player control", not Checkpoints.active and p.state == "locomotion")
	for name in ["RootCellar", "ForgottenSanctum"]:
		await open_fixture("res://scenes/levels/" + name + ".tscn")
		check_rest_guards(true, name + " resting in forest revives unloaded dungeon enemies")
		check(
			name + " retains golden completion",
			DungeonTravel.completed(arena.dungeon) and arena.get_node("Uitgang/Visual").completed
		)
		await capture("rest_" + name + "_after")
		await finish_dungeon()
	check(
		"reclearing both dungeons grants no duplicate loot",
		GameProgress.data.inventory.get("lantern_shard", 0) == loot_before
	)
	check("native rest replay drew frames", Engine.get_frames_drawn() - initial_render_frame > 100)


func finish() -> void:
	var report := {
		"failures": failures,
		"checks": results,
		"transitions": switches,
		"frame_spikes": frame_spikes,
		"render_frames": Engine.get_frames_drawn() - initial_render_frame
	}
	var filename := (
		"rest_review.json" if "--dungeon-rest-only" in OS.get_cmdline_user_args() else "review.json"
	)
	FileAccess.open("res://captures/drempelpoort/" + filename, FileAccess.WRITE).store_string(
		JSON.stringify(report, "\t")
	)
	print("PORTAL_FRAME_SPIKES ", JSON.stringify(frame_spikes))
	print("THRESHOLD_REPLAY_DONE ", failures, " failures, ", switches, " transitions")
	get_tree().quit(1 if failures else 0)
