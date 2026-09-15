extends "res://tests/level_builder_replay.gd"
## Exercise the real actor and steering on saved gentle and steep builder ramps.


func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://captures/level_builder")
	initial_frames = Engine.get_frames_drawn()
	if DisplayServer.get_name() != "headless":
		get_window().title = "Level Builder — geïsoleerde hellingcontrole"
		get_window().position = Vector2i(80, 80)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
		get_window().grab_focus()
	GameProgress.ensure_preview()
	GameProgress.active_slot = 0
	if "--builder-patrol-only" in OS.get_cmdline_user_args():
		await load_world("BuilderForest")
		for enemy in world.get_node("Enemies").get_children():
			enemy.disabled = true
		var guard: CharacterBody3D = world.get_node("Enemies").get_child(0)
		await _trip(
			guard, "authored_patrol", Vector3(1.7, 0, -8), Vector3(-4.7, 1.5, -8), false, true
		)
		_finish("authored_patrol")
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--builder-ramp-scene="):
			var source: Node = load(argument.trim_prefix("--builder-ramp-scene=")).instantiate()
			check(
				"requested level rebakes",
				FACTORY.save(source, "res://captures/level_builder/RequestedRamps.tscn") == OK
			)
			source.free()
			await load_world("res://captures/level_builder/RequestedRamps.tscn")
			world.player.respawn(Vector3(-9, 0, 9))
			await frames(180)
			var placed: CharacterBody3D = world.get_node("Enemies").get_child(0)
			check(
				"placed enemy home follows its initial floor contact",
				absf(placed.spawn_position.y - placed.global_position.y) < .15,
				{"home": placed.spawn_position, "position": placed.position}
			)
			await _ramp_trips("requested", true)
			_finish("requested_ramps_%d" % Engine.max_fps)
			return
	await load_world("BuilderForest")
	await _ramp_trips("gentle")
	# Save the steeper fixture before loading it, so locomotion consumes the same
	# persisted collision data as an ordinary player-authored level.
	var fixture: Node = load("res://scenes/levels/BuilderForest.tscn").instantiate()
	var terrain := fixture.get_node("Terrain") as LevelTerrain
	terrain.get_node("Rotsbank").height = 5
	var ramp: LevelRamp
	for child in terrain.get_children():
		if child is LevelRamp:
			ramp = child
	var changed := ramp.curve.duplicate() as Curve3D
	changed.set_point_position(0, Vector3(2, 0, -8))
	ramp.curve = changed
	check(
		"steep ramp fixture saves",
		FACTORY.save(fixture, "res://captures/level_builder/SteepRamp.tscn") == OK
	)
	fixture.free()
	await load_world("res://captures/level_builder/SteepRamp.tscn")
	await _ramp_trips("steep")
	# Bridges: a guard crosses from a 1 m plateau to a 2 m plateau and back using
	# its own navigation, which must include the bridge's generated collider.
	check(
		"bridge fixture saves",
		_bridge_fixture("res://captures/level_builder/BridgeEnemies.tscn") == OK
	)
	await load_world("res://captures/level_builder/BridgeEnemies.tscn")
	var bridge_guard: CharacterBody3D = world.get_node("Enemies").get_child(0)
	await _trip(bridge_guard, "bridge_up", Vector3(0, 1, -7), Vector3(0, 2, 7))
	await _trip(bridge_guard, "bridge_down", Vector3(0, 2, 7), Vector3(0, 1, -7))
	_finish("enemy_ramps_%d" % Engine.max_fps)


func _bridge_fixture(path: String) -> Error:
	var kit := load("res://settings/area_sets/forest.tres") as AreaSet
	var area := WorldArea.new()
	area.code = &"area.bridge_enemies"
	area.display_name = "Bridge Enemies"
	area.scene_path = path
	var root := FACTORY.create(kit, area, Vector2(30, 26))
	var terrain := root.get_node("Terrain") as LevelTerrain
	for item in [[Rect2(-10, -12, 20, 8), 1.0], [Rect2(-6, 4, 16, 8), 2.0]]:
		var rect: Rect2 = item[0]
		var plateau := LevelTerrace.new()
		plateau.curve = Curve3D.new()
		for corner in [
			rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)
		]:
			plateau.curve.add_point(Vector3(corner.x, 0, corner.y))
		terrain.add_child(plateau, true)
		plateau.owner = root
		plateau.height = item[1]
	var bridge := LevelBridge.new()
	bridge.name = "Brug"
	bridge.curve = Curve3D.new()
	bridge.curve.add_point(Vector3(0, 1, -4))
	bridge.curve.add_point(Vector3(0, 2, 4))
	terrain.add_child(bridge, true)
	bridge.owner = root
	var guard: Node3D = load("res://scenes/actors/npcs/enemy/PlacedAcornGuard.tscn").instantiate()
	guard.name = "BridgeGuard"
	root.get_node("Enemies").add_child(guard)
	guard.owner = root
	guard.position = Vector3(0, 1, -8)
	var error := FACTORY.save(root, path)
	root.free()
	return error


func _ramp_trips(label: String, pursuit := false) -> void:
	var faces: PackedVector3Array = (
		world.get_node("Terrain/Baked/GroundCollision/SurfaceShape").shape.get_faces()
	)
	var degenerate := 0
	for i in range(0, faces.size(), 3):
		if (
			(faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i]).length_squared()
			< .000000000001
		):
			degenerate += 1
	check(label + " collision has no zero-area triangles", degenerate == 0, degenerate)
	world.player.respawn(Vector3(9, 0, 9))
	for enemy in world.get_node("Enemies").get_children():
		enemy.disabled = true
	var guard: CharacterBody3D = world.get_node("Enemies").get_child(0)
	for child in world.get_node("Terrain").get_children():
		if not child is LevelRamp:
			continue
		var ramp := child as LevelRamp
		var low := ramp.global_transform * ramp.curve.get_point_position(0)
		var high := ramp.global_transform * ramp.curve.get_point_position(1)
		var along := Vector3(high.x - low.x, 0, high.z - low.z).normalized()
		var name := label + "_" + String(ramp.name) if pursuit else label
		await _trip(guard, name + "_up", low - along * .7, high + along * .7)
		await _trip(guard, name + "_down", high + along * .7, low - along * .7)
		if pursuit:
			await _trip(guard, name + "_chase_up", low - along * .7, high + along * .7, true)
			await _trip(guard, name + "_chase_down", high + along * .7, low - along * .7, true)


func _trip(
	guard: CharacterBody3D,
	label: String,
	from: Vector3,
	to: Vector3,
	pursuit := false,
	patrol := false
) -> void:
	world.player.respawn(to if pursuit else Vector3(-9, 0, 9))
	world.player.invulnerability = 0
	guard.spawn_position = from
	guard.reset_target()
	guard.disabled = true
	# Flush both teleports before the real movement tick: a previous test actor
	# at the player's new position must not contribute an old overlap recovery.
	await frames(2)
	guard.disabled = false
	guard.spawn_position = to
	guard.brain.returning_after_leash = true
	guard.brain._enter("return_home")
	if pursuit:
		guard.spawn_position = from
		guard.brain.returning_after_leash = false
		guard.brain.last_seen = to
		guard.brain.memory = 60
		guard.brain._enter("approach")
	if patrol:
		guard.spawn_position = from
		guard.brain.returning_after_leash = false
		guard.brain.authored_patrol = PackedVector3Array([to - from])
		guard.brain._enter("patrol")
	var forward := Vector3(to.x - from.x, 0, to.z - from.z).normalized()
	guard.brain.direction = forward
	var side := forward.cross(Vector3.UP)
	var nav := NavigationWorld.surface_for(
		guard, guard.brain.settings.movement.radius, guard.brain.settings.movement.height
	)
	for i in 240:
		if nav.ready:
			break
		await frames(1)
	var lateral := 0.0
	var reversals := 0.0
	var previous := from
	var recovery_ticks := 0
	var trace: Array[Dictionary] = []
	var reached := false
	var interrupted_patrol := false
	var started := GameClock.elapsed
	world.set_physics_process(false)
	world.get_node("CameraRig/Camera3D").size = 9
	for i in 2000:
		await frames(1)
		var at := guard.global_position
		if patrol and guard.brain.state != "patrol" and at.distance_to(to) > .22:
			interrupted_patrol = true
		if absf((at - previous).dot(side)) > .04:
			var contacts: Array = []
			for j in guard.get_slide_collision_count():
				var hit := guard.get_slide_collision(j)
				contacts.append(
					{
						"body": hit.get_collider().name,
						"normal": hit.get_normal(),
						"depth": hit.get_depth(),
						"position": hit.get_position()
					}
				)
			print("RAMP_LATERAL_CONTACT ", at, " ", contacts)
		lateral = maxf(lateral, absf((at - from).dot(side)))
		reversals += maxf(0, -(at - previous).dot(forward))
		recovery_ticks += 1 if guard.brain.locomotion.recovering_surface else 0
		previous = at
		world.camera_rig.position = at + Vector3.UP * .5
		if i % 12 == 0:
			trace.append(
				{
					"position": at,
					"steering": guard.brain.locomotion.last_steering,
					"recovering": guard.brain.locomotion.recovering_surface,
					"closest": nav.closest_ground(at)
				}
			)
		if i % 24 == 0 and DisplayServer.get_name() != "headless":
			await capture(label + "_%03d" % (i / 24))
		if (
			at.distance_to(to) < (1.0 if pursuit else .22)
			and absf(at.y - to.y) < .15
			and guard.is_on_floor()
		):
			reached = true
			break
	check(
		label + " reaches destination",
		reached,
		{"position": guard.position, "path": guard.brain.locomotion.path}
	)
	if not pursuit:
		check(
			label + " stays straight without slalom",
			lateral < .15 and reversals < .08,
			{"lateral": lateral, "backwards": reversals, "recovery_ticks": recovery_ticks}
		)
	if patrol:
		check(
			"long authored patrol is not cut off after six seconds",
			reached and not interrupted_patrol and GameClock.elapsed - started > 6,
			GameClock.elapsed - started
		)
	(
		FileAccess
		. open("res://captures/level_builder/" + label + "_trace.json", FileAccess.WRITE)
		. store_string(JSON.stringify(trace, "\t"))
	)
	guard.disabled = true
	world.set_physics_process(true)
	world.get_node("CameraRig/Camera3D").size = 13
