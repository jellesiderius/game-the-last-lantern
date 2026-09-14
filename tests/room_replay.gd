extends "res://tests/runtime_replay.gd"
## Traversal and camera checks on the actual authored 32 m room, at fixed 120 Hz physics.


func reset(at := Vector3(0, 0, 2)) -> void:
	await super.reset(at)
	arena.reset_camera()


func camera_lag() -> float:
	return Vector2(p.position.x - arena.camera_home.x, p.position.z - arena.camera_home.z).length()


func world_input(direction: Vector3) -> Vector2:
	var camera := get_viewport().get_camera_3d()
	var right := Vector3(camera.global_basis.x.x, 0, camera.global_basis.x.z).normalized()
	var back := Vector3(camera.global_basis.z.x, 0, camera.global_basis.z.z).normalized()
	return Vector2(direction.dot(right), direction.dot(back))


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		"res://captures/lantern_village/room_" + label + ".png"
	)


func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	render_cap = Engine.max_fps
	var camera := get_viewport().get_camera_3d()
	var original_basis := camera.global_basis
	check(
		"readable orthographic gameplay camera",
		(
			camera.projection == Camera3D.PROJECTION_ORTHOGONAL
			and camera.size >= 12.0
			and camera.size <= 14.0
		)
	)
	check(
		"32 m floor authored in scene",
		arena.get_node("Collision/EntranceBody/Collision").shape.size.x == 32
	)
	await reset(Vector3(0, 0, 7))
	await step(50)
	p.test_input = world_input(Vector3.FORWARD)
	var worst_lag := 0.0
	var lag_samples: Array = []
	for i in 230:
		await step(1)
		if i > 30:
			worst_lag = maxf(
				worst_lag,
				(
					Vector2(
						p.position.x - arena.camera_rig.position.x,
						p.position.z - arena.camera_rig.position.z
					)
					. length()
				)
			)
		if i == 95:
			await capture("bridge_run")
		if i % 30 == 0:
			lag_samples.append(camera_lag())
	p.test_input = Vector2.ZERO
	check(
		"bridge is traversable without falling",
		p.position.z < -.8 and p.position.y > -.03,
		p.position
	)
	check(
		"camera trails a ghost target a smooth distance while running",
		worst_lag > .9 and worst_lag < 2.2,
		worst_lag
	)
	check("player moves within frame when starting", float(lag_samples[1]) > .2, lag_samples)
	check("camera keeps its angle", camera.global_basis.is_equal_approx(original_basis))
	await step(12)
	var stop_lag := camera_lag()
	check("camera settles toward stopped player", stop_lag < worst_lag, stop_lag)
	var last_lag := stop_lag
	var monotonic := true
	for i in 360:
		await step(1)
		var current_lag := camera_lag()
		monotonic = monotonic and current_lag <= last_lag + .0001
		last_lag = current_lag
	check("camera locks onto stopped player without overshoot", monotonic and last_lag < .003, last_lag)
	await capture("camera_settled")
	await reset(Vector3(0, 0, -3))
	p.test_input = world_input(Vector3.RIGHT)
	await step(80)
	var before_reverse: Vector3 = arena.camera_home
	p.test_input = world_input(Vector3.LEFT)
	await step(1)
	check("camera does not snap direction on reversal", arena.camera_home.x > before_reverse.x)
	await step(200)
	check("camera catches the new direction", arena.camera_home.x > p.position.x)
	GameClock.paused = true
	await step(1)
	var paused_camera: Vector3 = arena.camera_home
	await step(24)
	check("pause freezes follow", arena.camera_home.is_equal_approx(paused_camera))
	GameClock.paused = false
	p.was_paused = false
	await step(12)
	check("resume continues follow", not arena.camera_home.is_equal_approx(paused_camera))
	GameClock.hitstop(.04)
	await step(1)
	var stopped_camera: Vector3 = arena.camera_home
	await step(2)
	check("hitstop freezes follow", arena.camera_home.is_equal_approx(stopped_camera))
	await step(12)
	check("hitstop releases follow", not arena.camera_home.is_equal_approx(stopped_camera))
	arena.restart()
	check(
		"restart resets framing immediately", camera_lag() < .0001 and GameClock.stop_remaining == 0
	)
	await reset(Vector3(0, 0, -9.3))
	p.test_input = world_input(Vector3.FORWARD)
	await step(115)
	p.test_input = Vector2.ZERO
	await step(25)
	check(
		"four-step ramp reaches 1 m terrace",
		p.position.z < -12.1 and absf(p.position.y - 1) < .03,
		p.position
	)
	await capture("terrace")
	p.test_input = world_input(Vector3.BACK)
	await step(120)
	p.test_input = Vector2.ZERO
	await step(25)
	check(
		"ramp descent returns to plaza", p.position.z > -10 and absf(p.position.y) < .03, p.position
	)
	await reset(Vector3(-11, 0, .7))
	await capture("long_stair_start")
	p.test_input = world_input(Vector3.FORWARD)
	var ascent_monotonic := true
	var ascent_grounded := true
	var previous_height := p.position.y
	var highest_camera_lag := 0.0
	for i in 330:
		await step(1)
		ascent_monotonic = ascent_monotonic and p.position.y >= previous_height - .003
		ascent_grounded = ascent_grounded and p.is_on_floor()
		previous_height = p.position.y
		highest_camera_lag = maxf(
			highest_camera_lag, p.position.y + arena.camera_target_height - arena.camera_home.y
		)
		if i == 155:
			await capture("long_stair_ascent")
	p.test_input = Vector2.ZERO
	await step(70)
	check(
		"long stair reaches 4 m landing",
		p.position.z < -8.3 and absf(p.position.y - 4) < .03,
		p.position
	)
	check("long ascent stays grounded without height bumps", ascent_monotonic and ascent_grounded)
	check(
		"camera follows ascent with bounded height lag",
		highest_camera_lag > .1 and highest_camera_lag < .35,
		highest_camera_lag
	)
	check(
		"camera settles at elevated landing",
		absf(arena.camera_home.y - 4.65) < .03,
		arena.camera_home.y
	)
	await capture("long_stair_landing")
	p.test_input = world_input(Vector3.BACK)
	var descent_grounded := true
	for i in 360:
		await step(1)
		descent_grounded = descent_grounded and p.is_on_floor()
		if i == 170:
			await capture("long_stair_descent")
	p.test_input = Vector2.ZERO
	await step(70)
	check(
		"long stair returns to ground", p.position.z > .1 and absf(p.position.y) < .03, p.position
	)
	check("long descent stays on ramp", descent_grounded)
	check(
		"camera returns to ground height",
		absf(arena.camera_home.y - .65) < .03,
		arena.camera_home.y
	)
	var distances := []
	for direction in [Vector3.RIGHT, Vector3(1, 0, -1).normalized()]:
		await reset(Vector3(0, 0, -4))
		p.test_input = world_input(direction)
		var origin := p.position
		await step(120)
		distances.append(Vector2(p.position.x - origin.x, p.position.z - origin.z).length())
	check("straight and diagonal travel match", absf(distances[0] - distances[1]) < .025, distances)
	await reset(Vector3(14, 0, 11))
	p.test_input = world_input(Vector3.RIGHT)
	await step(90)
	check("walking stays inside outer fence", p.position.x < 15.7, p.position)
	await start("dodge")
	await step(65)
	check(
		"rolling stays inside outer fence", p.position.x < 15.7 and p.position.y > -.03, p.position
	)
	check(
		"camera stops at its boundary",
		arena.camera_rig.position.x <= 12.01,
		arena.camera_rig.position
	)
	await reset(Vector3(0, 0, -3))
	p.facing = Vector3.BACK
	p.pivot.rotation.y = PI
	await step(35)
	check(
		"sword rests in right hand",
		not p.visual.stow_at_rest and p.visual.socket.bone_name == "sword_socket"
	)
	var normal: Vector3 = p.visual.weapon.get_node("WeaponModel").global_basis.y.normalized()
	check("broad sword faces point sideways", absf(normal.y) < .06, normal)
	check(
		"one sword instance",
		p.visual.find_children("WeaponModel", "Node3D", true, false).size() == 1
	)
	await capture("player_idle")
	var hud := arena.get_node("HUD")
	p.health.damage(1)
	await step(40)
	await capture("hud_four_health")
	check(
		"HUD reflects health component",
		hud.hp.get_child(3).value == 1 and hud.hp.get_child(4).value == 0
	)
	for i in 4:
		p.magic.try_spend()
	await step(32)
	await capture("hud_empty_magic")
	var all_empty := true
	for segment in hud.magic_meter.get_children():
		all_empty = all_empty and segment.value == 0
	check("HUD reflects empty magic", all_empty)
	p.magic.restore(1)
	await step(32)
	check(
		"HUD reflects restored magic",
		hud.magic_meter.get_child(0).value == 1 and hud.magic_meter.get_child(1).value == 0
	)
	p.magic.reset()
	p.health.reset()
	await start("light")
	await step(14)
	await capture("melee_active")
	await until_idle()
	await start("bow_direct_press")
	await step(36)
	await capture("bow_draw")
	await start("bow_direct_release")
	await step(5)
	await capture("arrow")
	await until_idle()
	var report := {
		"failures": failures,
		"render_cap": render_cap,
		"physics_fps": Engine.physics_ticks_per_second,
		"rendered_frames": Engine.get_frames_drawn() - initial_render_frame,
		"wall_seconds": (Time.get_ticks_msec() - initial_wall_ms) / 1000.0,
		"camera_half_life": arena.camera_follow_half_life,
		"results": results
	}
	var f := FileAccess.open(
		"res://captures/lantern_village/room_checks_" + str(render_cap) + ".json", FileAccess.WRITE
	)
	f.store_string(JSON.stringify(report, "\t"))
	print("ROOM_REPLAY_FINISHED ", failures, " failures; ", results.size(), " checks")
	get_tree().quit(1 if failures else 0)
