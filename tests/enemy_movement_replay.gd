extends "res://tests/acorn_replay.gd"
## Acceptance scenarios use the real prefab, collisions, clock and movement adapter.


func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	var guards := get_tree().get_nodes_in_group("acorn_guards")
	var navigation := NavigationWorld.surface_for(
		guards[0], guards[0].brain.settings.movement.radius
	)
	for i in 1800:
		if navigation.ready:
			break
		await step(1)
	await variation_checks(guards)
	await obstacle_checks(guards[0])
	await crossing_checks(guards)
	await crowd_crossing_checks()
	var output := {
		"failures": failures,
		"results": results,
		"render_cap": Engine.max_fps,
		"renderer": RenderingServer.get_current_rendering_method(),
		"rendered_frames": Engine.get_frames_drawn() - initial_render_frame
	}
	(
		FileAccess
		. open(
			"res://captures/acorn_guard/movement_checks_%d.json" % Engine.max_fps, FileAccess.WRITE
		)
		. store_string(JSON.stringify(output, "\t"))
	)
	print("MOVEMENT_REPLAY_FINISHED ", failures, " failures; ", results.size(), " checks")
	get_tree().quit(1 if failures else 0)


func variation_checks(guards: Array) -> void:
	await reset(Vector3(12, 0, 8))
	for i in guards.size():
		deploy(guards[i], Vector3(-1.4 + i * 2.8, 0, -4))
	await step(8)
	var first: Dictionary = guards[0].brain.personality.duplicate(true)
	var second: Dictionary = guards[1].brain.personality
	check(
		"instances keep independent speed, rhythm, phase and route",
		(
			first.speed != second.speed
			and first.phase != second.phase
			and first.wait != second.wait
			and first.patrol_yaw != second.patrol_yaw
		),
		[first, second]
	)
	guards[0].brain.reset_brain()
	check("same seed reproduces the same personality", first == guards[0].brain.personality)
	var states_differ := 0
	var poses_differ := 0
	var patrol_starts: Array = [[], []]
	var previous_states := [guards[0].brain.state, guards[1].brain.state]
	var rates: Array = []
	for i in 64:
		var rng := RandomNumberGenerator.new()
		rng.seed = i + 1
		var traits: Dictionary = guards[0].brain.settings.variation.sample(rng, 2)
		rates.append(traits.speed)
	check(
		"64 spawn seeds stay inside authored speed range",
		rates.min() >= .9 and rates.max() <= 1.1 and rates.max() - rates.min() > .15,
		[rates.min(), rates.max()]
	)
	var review := DisplayServer.get_name() != "headless"
	if review:
		arena.set_physics_process(false)
		arena.camera_rig.position = Vector3(0, .65, -4)
		get_viewport().get_camera_3d().size = 6
		arena.get_node("HUD").hide()
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://captures/acorn_guard/variety_motion")
		)
	for i in 1200:
		await step(1)
		for j in guards.size():
			if guards[j].brain.state == "patrol" and previous_states[j] != "patrol":
				patrol_starts[j].append(i)
			previous_states[j] = guards[j].brain.state
		if guards[0].brain.state != guards[1].brain.state:
			states_differ += 1
		if (
			absf(
				(
					guards[0].visual.animation_player.current_animation_position
					- guards[1].visual.animation_player.current_animation_position
				)
			)
			> .1
		):
			poses_differ += 1
		if review and i % 4 == 0:
			await shot("variety_motion/%03d" % (i / 4))
	check(
		"idle and patrol schedules do not stay synchronized",
		(
			patrol_starts[0].size() >= 2
			and patrol_starts[1].size() >= 2
			and patrol_starts[0] != patrol_starts[1]
			and states_differ > 0
		),
		{"different_state_ticks": states_differ, "patrol_starts": patrol_starts}
	)
	check("authored animation phases do not stay synchronized", poses_differ > 600, poses_differ)
	if review:
		arena.set_physics_process(true)
		get_viewport().get_camera_3d().size = 13
		arena.get_node("HUD").show()
		arena.reset_camera()


func send_home(enemy, from: Vector3, to: Vector3) -> void:
	deploy(enemy, from)
	enemy.spawn_position = to
	enemy.brain.returning_after_leash = true
	enemy.brain._enter("return_home")
	enemy.brain.direction = (to - from).normalized()


func obstacle_checks(enemy) -> void:
	await reset(Vector3(12, 0, 8))
	var navigation := NavigationWorld.surface_for(enemy, enemy.brain.settings.movement.radius)
	var from := Vector3(-8.6, 0, -4)
	var to := Vector3(-5.4, 0, -4)
	var radius: float = enemy.brain.settings.movement.radius
	var path := navigation.route(from, to, radius)
	var clear := not path.is_empty()
	var anchor := from
	for point in path:
		clear = clear and navigation.segment_clear(anchor, point, radius)
		anchor = point
	check(
		"tree route has capsule clearance at every smoothed segment",
		clear and path.size() > 1,
		path
	)
	check(
		"open plaza uses one straight segment",
		navigation.segment_clear(Vector3(0, 0, -5), Vector3(3, 0, -5), radius)
	)
	check(
		"larger enemy radius cannot cut through the tree",
		not navigation.segment_clear(from, to, .6)
	)
	var edge := navigation.route(Vector3(0, 0, -1), Vector3(0, 0, 7), radius)
	check("bridge route reaches the far bank", not edge.is_empty() and edge[-1].z > 6.8, edge)
	check(
		"no steering shortcut through canal water",
		not navigation.segment_clear(Vector3(3, 0, 1), Vector3(3, 0, 5), radius)
	)
	send_home(enemy, from, to)
	var reached := false
	var worst_heading := 1.0
	var minimum_progress := INF
	for i in 1200:
		await step(1)
		var velocity: Vector3 = enemy.get_real_velocity()
		velocity.y = 0
		if velocity.length() > .2:
			worst_heading = minf(worst_heading, velocity.normalized().dot(enemy.brain.direction))
		minimum_progress = minf(minimum_progress, enemy.position.distance_to(to))
		if enemy.position.distance_to(to) < .2:
			reached = true
			break
	check(
		"real actor walks around the tree and reaches home",
		reached,
		{
			"position": enemy.position,
			"nearest": minimum_progress,
			"path": enemy.brain.locomotion.path,
			"steering": enemy.brain.locomotion.last_steering,
			"direction": enemy.brain.direction,
			"surface": navigation.closest_ground(enemy.position)
		}
	)
	check("obstacle travel stays aligned with the feet", worst_heading > .96, worst_heading)
	check(
		"route cache avoids per-frame A-star searches",
		enemy.brain.locomotion.repaths < 70,
		enemy.brain.locomotion.repaths
	)


func crossing_checks(guards: Array) -> void:
	await reset(Vector3(12, 0, 8))
	send_home(guards[0], Vector3(-2, 0, -5), Vector3(2, 0, -5))
	send_home(guards[1], Vector3(2, 0, -5), Vector3(-2, 0, -5))
	var closest := INF
	var reached := [false, false]
	var detour := 0.0
	for i in 1200:
		await step(1)
		closest = minf(closest, guards[0].position.distance_to(guards[1].position))
		for j in guards.size():
			detour = maxf(detour, absf(guards[j].position.z + 5))
			if guards[j].position.distance_to(guards[j].spawn_position) < .2:
				reached[j] = true
				guards[j].disabled = true
		if reached[0] and reached[1]:
			break
	check(
		"opposing enemies pass without a head-on deadlock",
		reached[0] and reached[1],
		[guards[0].position, guards[1].position]
	)
	check("anticipation gives the other body physical clearance", closest > .50, closest)
	check("passing uses a bounded local detour", detour > .15 and detour < 1.4, detour)


func crowd_crossing_checks() -> void:
	await reset(Vector3(12, 0, 8))
	var crowd: Array = []
	var prefab := preload("res://scenes/actors/npcs/enemy/AcornGuard.tscn")
	var center := Vector3(0, 0, -4)
	var reached := 0
	for i in 4:
		var enemy = prefab.instantiate()
		enemy.name = "CrossingGuard%d" % i
		arena.add_child(enemy)
		var offset := Vector3.RIGHT.rotated(Vector3.UP, i * TAU / 4) * 2.5
		send_home(enemy, center + offset, center - offset)
		crowd.append(enemy)
	var minimum_clearance := INF
	for i in 1800:
		await step(1)
		for a in crowd.size():
			for b in range(a + 1, crowd.size()):
				minimum_clearance = minf(
					minimum_clearance, crowd[a].position.distance_to(crowd[b].position)
				)
		for enemy in crowd:
			if not enemy.disabled and enemy.position.distance_to(enemy.spawn_position) < .2:
				enemy.disabled = true
				reached += 1
		if reached == crowd.size():
			break
	check("four crossing spawn identities clear the shared center", reached == 4, reached)
	check(
		"four-agent crossing preserves capsule separation",
		minimum_clearance > .49,
		minimum_clearance
	)
	for enemy in crowd:
		enemy.queue_free()
	await step(2)
