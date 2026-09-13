extends "res://tests/room_replay.gd"
## Real saved forest, real physics entrance, navigation and pause handoff.
var landed_count := 0


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/forest/" + label + ".png")


func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://captures/forest")
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	p.use_test_input = true
	render_cap = Engine.max_fps
	p.landed.connect(func(_speed): landed_count += 1)
	await step(40)
	check(
		"forest starts seated on saved stump",
		p.state == "entrance" and p.position.y > 1.1,
		p.position
	)
	await capture("opening")
	var camera := get_viewport().get_camera_3d()
	if "--forest-overview" in OS.get_cmdline_user_args():
		p.set_physics_process(false)
		arena.set_physics_process(false)
		camera.size = 18.0
		arena.camera_rig.position = Vector3(.5, 1, -5.0)
		await step(160)
		await capture("overview")
		if "--forest-shading-review" in OS.get_cmdline_user_args():
			arena.get_node("Sun").light_angular_distance = 0.5
			await step(80)
			await capture("shading_soft_shadow")
			arena.get_node("WorldEnvironment").environment.ssao_enabled = false
			await step(80)
			await capture("shading_no_ssao")
			arena.get_node("Sun").shadow_enabled = false
			await step(80)
			await capture("shading_no_shadow")
		get_tree().quit()
		return
	var held_position := p.position
	var held_time := p.action_time
	var butterfly_position: Vector3 = arena.get_node("Butterflies/Butterfly0").position
	GameClock.paused = true
	await step(24)
	check(
		"pause freezes entrance physics and pose clock",
		p.position.is_equal_approx(held_position) and p.action_time == held_time
	)
	check(
		"pause freezes butterflies",
		arena.get_node("Butterflies/Butterfly0").position.is_equal_approx(butterfly_position)
	)
	GameClock.paused = false
	p.was_paused = false
	p.request_action("dodge")
	p.request_action("light")
	await step(1)
	check(
		"entrance does not buffer attacks or dodges",
		p.pending_inputs.is_empty() and p.state == "entrance"
	)
	while p.state == "entrance" and p.action_time < 2.8:
		await step(1)
	await capture("hop")
	var highest := p.position.y
	for i in 200:
		await step(1)
		highest = maxf(highest, p.position.y)
		if p.state == "locomotion":
			break
	check(
		"jump leaves stump and lands once",
		p.position.z > 5.5 and p.is_on_floor() and landed_count == 1,
		{"position": p.position, "landings": landed_count, "highest": highest}
	)
	check(
		"entrance returns control without queued action",
		p.state == "locomotion" and p.attacks_started.is_empty()
	)
	await step(40)
	await capture("playable")
	check("health UI appears at handoff", arena.get_node("HUD/Root/Status").modulate.a > .99)
	var start_position := p.position
	p.test_input = world_input(Vector3.RIGHT)
	await step(35)
	p.test_input = Vector2.ZERO
	check("movement available after entrance", p.position.distance_to(start_position) > .6)
	# Follow the authored path to its first enemy without teleporting through scenery.
	var route := [
		Vector3(-1, 0, 6),
		Vector3(.2, 0, 2),
		Vector3(-1.5, 0, -.4),
		Vector3(-2.8, 0, -2.8),
		Vector3(-3, 0, -5.5),
		Vector3(-1.5, 0, -7.8),
		Vector3(1.6, 0, -8.5),
		Vector3(4, 0, -10)
	]
	var route_ok := true
	for waypoint in route:
		var reached := false
		for i in 300:
			var direction: Vector3 = waypoint - p.position
			direction.y = 0
			if direction.length() < .22:
				reached = true
				break
			p.test_input = world_input(direction.normalized())
			await step(1)
		if not reached:
			route_ok = false
			break
	p.test_input = Vector2.ZERO
	check("saved forest path is traversable", route_ok, p.position)
	await step(20)
	await capture("first_guard")
	var guard = arena.get_node("AcornGuard")
	check(
		"first AcornGuard responds after exploration",
		guard.brain.state not in ["idle", "patrol"],
		guard.brain.state
	)
	arena.restart()
	await step(10)
	check(
		"restart returns to safe ground with control",
		p.state == "locomotion" and p.is_on_floor() and p.health.current == p.health.maximum
	)
	var steady_start := Time.get_ticks_msec()
	var steady_frames := Engine.get_frames_drawn()
	await step(240)
	var steady_fps := (
		float(Engine.get_frames_drawn() - steady_frames)
		/ (float(Time.get_ticks_msec() - steady_start) / 1000.0)
	)
	var report := {
		"steady_render_fps": steady_fps,
		"checks": results,
		"failures": failures,
		"render_frames": Engine.get_frames_drawn() - initial_render_frame,
		"seconds": (Time.get_ticks_msec() - initial_wall_ms) / 1000.0,
		"cap": render_cap
	}
	(
		FileAccess
		. open("res://captures/forest/checks_%d.json" % render_cap, FileAccess.WRITE)
		. store_string(JSON.stringify(report, "\t"))
	)
	print("FOREST_REPLAY_RESULT ", JSON.stringify(report))
	get_tree().quit(1 if failures else 0)
