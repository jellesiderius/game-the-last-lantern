extends "res://tests/runtime_replay.gd"
## Real motion, planted support, carry clearance, and unified-clock regression.


func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	await reset(Vector3(-6, 0, 8))
	var camera := get_viewport().get_camera_3d()
	var right := Vector3(camera.global_basis.x.x, 0, camera.global_basis.x.z).normalized()
	var back := Vector3(camera.global_basis.z.x, 0, camera.global_basis.z.z).normalized()
	p.test_input = Vector2(Vector3.RIGHT.dot(right), Vector3.RIGHT.dot(back))
	await step(30)
	var minimum_tip := INF
	var phase_travel := 0.0
	var previous_phase := p.visual.gait_phase
	var previous_feet := {}
	var support_speeds: Array[float] = []
	var motion_start := p.position
	var start_frames := Engine.get_frames_drawn()
	var start_ms := Time.get_ticks_msec()
	for i in 180:
		await step(1)
		for side in ["L", "R"]:
			var phase := fposmod(p.visual.gait_phase + (0.0 if side == "L" else .5), 1.0)
			var foot := (
				p.visual.skeleton.global_transform
				* (
					p
					. visual
					. skeleton
					. get_bone_global_pose(p.visual.skeleton.find_bone("foot_" + side))
					. origin
				)
			)
			if previous_feet.has(side) and phase > .025 and phase < .10:
				var previous: Dictionary = previous_feet[side]
				if previous.phase > .025 and previous.phase < phase:
					var shift: Vector3 = foot - previous.position
					support_speeds.append(Vector2(shift.x, shift.z).length() * 120.0)
			previous_feet[side] = {"phase": phase, "position": foot}
		phase_travel += fposmod(p.visual.gait_phase - previous_phase, 1.0)
		previous_phase = p.visual.gait_phase
		minimum_tip = minf(
			minimum_tip, p.visual.weapon.get_node("BladeTip").global_position.y - p.position.y
		)
	check(
		"configured responsive movement speed",
		absf(p.position.distance_to(motion_start) / 1.5 - 3.8) < .03,
		p.position.distance_to(motion_start) / 1.5
	)
	check(
		"run cadence calmer than first revision",
		phase_travel / 1.5 > 2.7 and phase_travel / 1.5 < 3.1,
		phase_travel / 1.5
	)
	check("moving sword tip stays above ground", minimum_tip > .035, minimum_tip)
	var support_speed := 0.0
	for value in support_speeds:
		support_speed += value
	support_speed /= maxf(1.0, support_speeds.size())
	check(
		"support foot holds ground during flat stance",
		support_speeds.size() > 8 and support_speed < .35,
		support_speed
	)
	p.test_input = Vector2.ZERO
	await step(30)
	var phase_stopped := p.visual.gait_phase
	await step(20)
	check("stopped feet do not keep cycling", is_equal_approx(phase_stopped, p.visual.gait_phase))
	check(
		"stopping settles the walk blend", p.visual.displayed_speed < .005, p.visual.displayed_speed
	)
	var phase_before := p.visual.gait_phase
	var idle_before := p.visual.idle_time
	GameClock.paused = true
	await step(12)
	check(
		"pause freezes both gait and idle clock",
		p.visual.gait_phase == phase_before and p.visual.idle_time == idle_before
	)
	GameClock.paused = false
	await step(2)
	await start("light")
	await until_idle()
	await step(20)
	check(
		"attack returns to relaxed carry",
		p.visual.weapon.get_node("BladeTip").global_position.y < p.visual.socket.global_position.y
	)
	var seconds := (Time.get_ticks_msec() - start_ms) / 1000.0
	var fps := (Engine.get_frames_drawn() - start_frames) / seconds
	if DisplayServer.get_name() != "headless":
		check("native rendered frames advance", Engine.get_frames_drawn() - start_frames > 50, fps)
	DirAccess.make_dir_recursive_absolute("res://captures/panda_motion")
	(
		FileAccess
		. open(
			"res://captures/panda_motion/locomotion_checks_" + str(Engine.max_fps) + ".json",
			FileAccess.WRITE
		)
		. store_string(
			JSON.stringify(
				{
					"failures": failures,
					"results": results,
					"render_frames": Engine.get_frames_drawn() - start_frames,
					"observed_render_fps": fps
				},
				"\t"
			)
		)
	)
	get_tree().quit(1 if failures else 0)
