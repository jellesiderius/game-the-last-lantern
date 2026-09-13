extends "res://tests/enemy_movement_replay.gd"
## Approach sweeps around the actual ramp corner, including boundary starts.


func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	var guard = get_tree().get_nodes_in_group("acorn_guards")[0]
	var navigation := NavigationWorld.surface_for(guard, guard.brain.settings.movement.radius)
	for i in 1800:
		if navigation.ready:
			break
		await step(1)
	check("corner test navigation synchronizes", navigation.ready)
	var review := DisplayServer.get_name() != "headless"
	if review:
		await approach(
			guard, Vector3(-7.8, 0, -1), Vector3(-11, 2, -4), Vector3.INF, "corner_wide_approach"
		)
		await approach(
			guard, Vector3(-9.7, 0, -.25), Vector3(-11, 2, -4), Vector3.INF, "corner_stairs"
		)
		await approach(
			guard, Vector3(-10.05, 0, -.6), Vector3(-11, 2, -4), Vector3.INF, "corner_recovery"
		)
	else:
		for side in [-1.0, 1.0]:
			for width in [1.3, 1.15, .95, .65]:
				for z in [-.6, -.25, 0.0, .25]:
					await approach(guard, Vector3(-11 + side * width, 0, z), Vector3(-11, 2, -4))
			for width in [1.3, .95]:
				for z in [-.25, .25]:
					await approach(guard, Vector3(side * width, 0, -10 + z), Vector3(0, 1, -13))
	await approach(
		guard, Vector3(1, 0, -4), Vector3(5, 0, -4), Vector3(3, 0, -4), "corner_dummy", true
	)
	await approach(guard, Vector3(5, 0, -4), Vector3(1, 0, -4), Vector3(3, 0, -4), "", true)
	await approach(
		guard, Vector3(6.1, 0, -2), Vector3(9, 0, -.8), Vector3(6.65, 0, -2), "corner_dummy_rock"
	)
	await approach(guard, Vector3(9, 0, -6.55), Vector3(9, 0, -1), Vector3(9, 0, -6))
	await approach(guard, Vector3(7.5, 0, -2), Vector3(10.5, 0, -2))
	await approach(guard, Vector3(10.5, 0, -2), Vector3(7.5, 0, -2))
	if not review:
		await narrow_passage(guard)
	var output := {
		"failures": failures,
		"results": results,
		"rendered_frames": Engine.get_frames_drawn() - initial_render_frame
	}
	(
		FileAccess
		. open(
			"res://captures/acorn_guard/corner_checks_%d.json" % Engine.max_fps, FileAccess.WRITE
		)
		. store_string(JSON.stringify(output, "\t"))
	)
	print("CORNER_REPLAY_FINISHED ", failures, " failures; ", results.size(), " checks")
	get_tree().quit(1 if failures else 0)


func narrow_passage(guard) -> void:
	await reset(Vector3(12, 0, 14))
	var passage := preload("res://tests/fixtures/NarrowNavigationPassage.tscn").instantiate()
	passage.position = Vector3(5, 6, 10)
	arena.add_child(passage)
	await step(2)
	var profile: EnemyMovementSettings = guard.brain.settings.movement
	var normal := NavigationWorld.surface_for(guard, profile.radius, profile.height)
	var comfortable := NavigationWorld.surface_for(
		guard, profile.radius + profile.preferred_path_clearance, profile.height
	)
	for i in 1800:
		if normal.ready and comfortable.ready:
			break
		await step(1)
	var from: Vector3 = passage.position + Vector3(0, 0, -3)
	var to: Vector3 = passage.position + Vector3(0, 0, 3)
	var restricted := comfortable.route(from, to, profile.radius)
	check(
		"preferred clearance cannot cross the 0.8 m passage",
		not restricted.is_empty() and restricted[-1].distance_to(to) > 1.0,
		restricted
	)
	send_home(guard, from, to)
	var minimum_height := from.y
	var used_fallback := false
	for i in 1800:
		await step(1)
		minimum_height = minf(minimum_height, guard.position.y)
		used_fallback = used_fallback or guard.brain.locomotion.route_surface == normal
		if guard.position.distance_to(to) < .22:
			break
	check(
		"physical-size route traverses the narrow passage",
		used_fallback and guard.position.distance_to(to) < .22,
		guard.position
	)
	check(
		"narrow passage traversal stays on the elevated floor",
		minimum_height > 5.95,
		minimum_height
	)
	guard.disabled = true
	passage.queue_free()
	await step(2)


func approach(
	guard, from: Vector3, goal: Vector3, dummy_at := Vector3.INF, label := "", returning := false
) -> void:
	await reset(goal + Vector3(0, 0, 2) if returning else goal)
	if dummy_at.is_finite():
		var dummy = targets.filter(func(actor): return actor.brain == null)[0]
		dummy.position = dummy_at
	p.invulnerability = 0
	deploy(guard, from)
	guard.brain.last_seen = goal
	guard.brain.memory = guard.brain.settings.memory_duration
	if returning:
		send_home(guard, from, goal)
	var review := DisplayServer.get_name() != "headless" and not label.is_empty()
	if review:
		arena.set_physics_process(false)
		arena.get_node("HUD").hide()
		get_viewport().get_camera_3d().size = 7
		var folder := "res://captures/acorn_guard/" + label
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		for file in DirAccess.get_files_at(folder):
			if file.ends_with(".png"):
				DirAccess.remove_absolute(folder + "/" + file)
	var arrived := false
	var minimum_clearance := INF
	var trace: Array = []
	var navigation := NavigationWorld.surface_for(guard, guard.brain.settings.movement.radius)
	for i in 1200:
		await step(1)
		if dummy_at.is_finite():
			minimum_clearance = minf(minimum_clearance, guard.position.distance_to(dummy_at))
		if review:
			arena.camera_rig.position = (guard.position + goal) * .5 + Vector3.UP * .65
			if i % 4 == 0:
				await shot(label + "/%03d" % (i / 4))
		if i % 120 == 0:
			var collisions: Array = []
			for j in guard.get_slide_collision_count():
				var hit: KinematicCollision3D = guard.get_slide_collision(j)
				collisions.append({"normal": hit.get_normal(), "body": hit.get_collider().name})
			trace.append(
				{
					"tick": i,
					"clock": [GameClock.paused, GameClock.stop_remaining, GameClock.dt],
					"position": guard.position,
					"velocity": guard.get_real_velocity(),
					"state": guard.brain.state,
					"recovery": guard.brain.locomotion.recovering_surface,
					"path": guard.brain.locomotion.path,
					"nearest": navigation.closest_ground(guard.position),
					"steering": guard.brain.locomotion.last_steering,
					"speed": guard.brain.locomotion.speed,
					"direction": guard.brain.direction,
					"turning": guard.brain.turning_in_place,
					"collisions": collisions
				}
			)
		if (
			guard.position.distance_to(goal) < (.22 if returning else 1.0)
			and absf(guard.position.y - goal.y) < .46
		):
			arrived = true
			break
	check(
		"corner approach from %s reaches target surface" % from,
		arrived,
		{
			"position": guard.position,
			"trace": trace if not arrived else [],
			"dummy_clearance": minimum_clearance if dummy_at.is_finite() else null
		}
	)
	if dummy_at.is_finite():
		check(
			"passive body keeps physical clearance from %s" % from,
			minimum_clearance > .50,
			minimum_clearance
		)
	if review:
		arena.set_physics_process(true)
		get_viewport().get_camera_3d().size = 13
		arena.get_node("HUD").show()
		arena.reset_camera()
