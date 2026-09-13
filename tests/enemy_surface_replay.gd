extends "res://tests/enemy_movement_replay.gd"
## Both directions across the real bridge and the 1 m / 4 m stair ramps.


func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	var guard = get_tree().get_nodes_in_group("acorn_guards")[0]
	await reset(Vector3(12, 0, 10))
	var navigation := NavigationWorld.surface_for(guard, guard.brain.settings.movement.radius)
	for i in 1800:
		if navigation.ready:
			break
		await step(1)
	check("automatic world navigation is ready", navigation.ready)
	await traversal(guard, "bridge_out", Vector3(0, 0, .6), Vector3(0, 0, 6), .10)
	await traversal(guard, "bridge_back", Vector3(0, 0, 6), Vector3(0, 0, .6), .10)
	await traversal(guard, "short_stairs_up", Vector3(0, 0, -9), Vector3(0, 1, -13), .95)
	await traversal(guard, "short_stairs_down", Vector3(0, 1, -13), Vector3(0, 0, -9), .95)
	await traversal(guard, "long_stairs_up", Vector3(-11, 0, .6), Vector3(-11, 4, -9.5), 3.9)
	await traversal(guard, "long_stairs_down", Vector3(-11, 4, -9.5), Vector3(-11, 0, .6), 3.9)
	await reset(Vector3(0, 0, 4.7))
	deploy(guard, Vector3(0, 0, -.5))
	guard.brain.direction = Vector3.BACK
	for i in 900:
		if guard.position.z > 3.8:
			break
		await step(1)
	check("combat perception and chase cross the bridge", guard.position.z > 3.8, guard.position)
	await pursuit(guard, "bridge_side", Vector3(2.5, 0, 1), Vector3(0, 0, 5), 0.0)
	await pursuit(guard, "short_stair_side", Vector3(1.3, 0, -9.8), Vector3(-.4, 1, -13), .65)
	await pursuit(guard, "long_stair_side", Vector3(-9.8, 0, .2), Vector3(-11, 2.5, -5), 2.0)
	var output := {
		"failures": failures,
		"results": results,
		"rendered_frames": Engine.get_frames_drawn() - initial_render_frame,
		"render_cap": Engine.max_fps,
		"renderer": RenderingServer.get_current_rendering_method()
	}
	(
		FileAccess
		. open(
			"res://captures/acorn_guard/surface_checks_%d.json" % Engine.max_fps, FileAccess.WRITE
		)
		. store_string(JSON.stringify(output, "\t"))
	)
	print("SURFACE_REPLAY_FINISHED ", failures, " failures; ", results.size(), " checks")
	get_tree().quit(1 if failures else 0)


func traversal(guard, label: String, from: Vector3, to: Vector3, expected_height: float) -> void:
	await reset(Vector3(12, 0, 10))
	send_home(guard, from, to)
	var high := from.y
	var low := from.y
	var reached := false
	var navigation := NavigationWorld.surface_for(guard, guard.brain.settings.movement.radius)
	var path := navigation.route(from, to, guard.brain.settings.movement.radius)
	check(
		label + " has connected surface path",
		not path.is_empty() and path[-1].distance_to(to) < .25,
		path
	)
	var review := DisplayServer.get_name() != "headless"
	if review:
		arena.set_physics_process(false)
		arena.get_node("HUD").hide()
		get_viewport().get_camera_3d().size = 6
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://captures/acorn_guard/" + label)
		)
	for i in 1800:
		await step(1)
		high = maxf(high, guard.position.y)
		low = minf(low, guard.position.y)
		if review:
			arena.camera_rig.position = guard.position + Vector3.UP * .65
			if i % 4 == 0:
				await shot(label + "/%03d" % (i / 4))
		if guard.position.distance_to(to) < .22:
			reached = true
			break
	check(
		label + " reaches destination",
		reached,
		{"position": guard.position, "path": guard.brain.locomotion.path}
	)
	check(
		label + " follows floor height without falling",
		high >= expected_height and low > -.05,
		{"min": low, "max": high}
	)
	if review:
		arena.set_physics_process(true)
		get_viewport().get_camera_3d().size = 13
		arena.get_node("HUD").show()
		arena.reset_camera()


func pursuit(
	guard, label: String, from: Vector3, player_at: Vector3, minimum_height: float
) -> void:
	await reset(player_at)
	p.invulnerability = 0
	deploy(guard, from)
	# Reproduce an opponent who has just seen the player enter the crossing.
	guard.brain.last_seen = player_at
	guard.brain.memory = guard.brain.settings.memory_duration
	var arrived := false
	var max_height := from.y
	var review := DisplayServer.get_name() != "headless"
	if review:
		arena.set_physics_process(false)
		arena.get_node("HUD").hide()
		get_viewport().get_camera_3d().size = 7
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://captures/acorn_guard/" + label)
		)
	for i in 1800:
		await step(1)
		max_height = maxf(max_height, guard.position.y)
		if review:
			arena.camera_rig.position = (guard.position + p.position) * .5 + Vector3.UP * .65
			if i % 4 == 0:
				await shot(label + "/%03d" % (i / 4))
		if (
			guard.position.distance_to(p.position) < 1.0
			and absf(guard.position.y - p.position.y) < .46
		):
			arrived = true
			break
	check(
		label + " pursuit reaches the player's surface",
		arrived and max_height >= minimum_height,
		{
			"position": guard.position,
			"state": guard.brain.state,
			"height": max_height,
			"path": guard.brain.locomotion.path
		}
	)
	if review:
		arena.set_physics_process(true)
		get_viewport().get_camera_3d().size = 13
		arena.get_node("HUD").show()
		arena.reset_camera()
