extends "res://tests/room_replay.gd"
## Real ramp-edge falls, contacts, action interruptions and distance-based saved puff scenes.


func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	render_cap = Engine.max_fps
	var dust := p.ground_feedback
	check(
		"fall and landing imported",
		(
			p.visual.animation_player.has_animation("fall")
			and p.visual.animation_player.has_animation("land")
		)
	)
	await reset(Vector3(0, 0, -4))
	var count := dust.steps_emitted
	await step(40)
	check("idle emits no footsteps", dust.steps_emitted == count)
	p.test_input = world_input(Vector3.RIGHT)
	await step(80)
	check(
		"movement creates spaced footsteps",
		dust.steps_emitted - count >= 4 and dust.steps_emitted - count <= 6,
		dust.steps_emitted - count
	)
	check(
		"clouds are saved scene instances",
		(
			not dust.live_puffs.is_empty()
			and dust.live_puffs.back().scene_file_path == "res://scenes/effects/dust/DustPuff.tscn"
		)
	)
	await capture("running_dust")
	var puff: Node3D = dust.live_puffs.back()
	var puff_age: float = puff.age
	GameClock.paused = true
	await step(10)
	check("pause freezes dust", is_equal_approx(puff.age, puff_age))
	GameClock.paused = false
	p.test_input = Vector2.ZERO
	await step(12)
	count = dust.steps_emitted
	await step(65)
	check(
		"stopping stops dust and old clouds expire",
		dust.steps_emitted == count and dust.live_puffs.is_empty()
	)
	# Exit the SIDE of the actual long ramp, two metres above the existing square.
	await reset(Vector3(-11, 2.0, -4))
	await step(12)
	check("starts grounded on real ramp", p.is_on_floor())
	p.test_input = world_input(Vector3.RIGHT)
	var waited := 0
	while p.state != "fall" and waited < 100:
		await step(1)
		waited += 1
	check("leaving ramp enters fall", p.state == "fall" and not p.is_on_floor(), p.position)
	p.test_input = Vector2.ZERO
	await step(10)
	check("airborne uses authored fall pose", p.visual.current_clip == "fall")
	check("fall is not a rolling invulnerability window", not p.is_invulnerable())
	await capture("falling")
	count = dust.steps_emitted
	var position_before := p.position
	var fall_time := p.action_time
	GameClock.hitstop(.1)
	await step(8)
	check(
		"hitstop freezes fall physics and animation clock",
		p.position.is_equal_approx(position_before) and is_equal_approx(p.action_time, fall_time)
	)
	await step(7)
	var magic_before := p.magic.current
	for action in ["light", "dodge", "heavy", "bow_direct_press"]:
		p.request_action(action)
	await step(1)
	check(
		"fall cannot create an air swing roll or shot",
		p.state == "fall" and not p.active_window and p.magic.current == magic_before
	)
	var lands := dust.landings_emitted
	waited = 0
	while not p.is_on_floor() and waited < 150:
		await step(1)
		waited += 1
	check(
		"landing returns to valid movement", p.is_on_floor() and p.state == "locomotion", p.position
	)
	check("landing starts authored response", p.visual.current_clip == "land")
	check("fall emits no footsteps", dust.steps_emitted == count)
	check("landing creates small clouds", dust.landings_emitted == lands + 1)
	await step(5)
	await capture("landing")
	await start("light")
	check("landing does not lock attack input", p.state == "light_attack")
	await until_idle()
	check("airborne requests were not queued on landing", p.state == "locomotion")
	# Draw interruption must restore props without creating a projectile or paying magic.
	await reset(Vector3(0, 0, -4))
	await start("bow_direct_press")
	await step(8)
	var shots := p.bow.shots_fired
	p.position.y += 2.0
	await step(18)
	check(
		"fall cancels unfinished bow draw",
		(
			p.state == "fall"
			and not p.bow.shot_pending
			and not p.visual.bow.visible
			and not p.visual.bow.held_arrow.visible
		)
	)
	check(
		"cancelled falling shot costs no magic", p.magic.current == 4 and p.bow.shots_fired == shots
	)
	check("sword restored in fall", p.visual.weapon.visible)
	p.receive_hit(1, GameClock.next_attack_id(), p.position + Vector3.RIGHT)
	check("hurt has priority over fall", p.state == "hurt")
	await step(1)
	p.invulnerability = 0
	p.receive_hit(9, GameClock.next_attack_id(), p.position + Vector3.RIGHT)
	await step(45)
	check("death is never replaced by fall or landing", p.state == "dead")
	await reset(Vector3(0, 0, -4))
	check(
		"respawn clears airborne state and old clouds",
		(
			p.state == "locomotion"
			and p.airborne_time == 0
			and p.landing_time < 0
			and dust.live_puffs.is_empty()
		)
	)
	# Normal downhill traversal is grounded, not a sequence of false falls.
	await reset(Vector3(-11, 3.5, -7))
	p.test_input = world_input(Vector3.BACK)
	var false_fall := false
	for i in 220:
		await step(1)
		false_fall = false_fall or p.state == "fall" or p.visual.current_clip == "land"
	check("ramp descent never falsely plays fall or landing", not false_fall)
	var report := {
		"failures": failures,
		"render_cap": render_cap,
		"physics_fps": Engine.physics_ticks_per_second,
		"rendered_frames": Engine.get_frames_drawn() - initial_render_frame,
		"wall_seconds": (Time.get_ticks_msec() - initial_wall_ms) / 1000.0,
		"results": results
	}
	(
		FileAccess
		. open("res://captures/lantern_village/fall_dust_%d.json" % render_cap, FileAccess.WRITE)
		. store_string(JSON.stringify(report, "\t"))
	)
	print("FALL_DUST_REPLAY_FINISHED ", failures, " failures; ", results.size(), " checks")
	get_tree().quit(1 if failures else 0)
