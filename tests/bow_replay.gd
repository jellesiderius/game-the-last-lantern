extends "res://tests/runtime_replay.gd"
var release_samples: Array = []
var denied_count := 0


func on_denied() -> void:
	denied_count += 1


func check_empty_draw() -> void:
	# Clear ground south of the newly authored west wall isolates refusal movement.
	await reset_bow(Vector3(-3.8, 0, 5.0))
	p.test_input = Vector2.RIGHT
	await step(35)
	p.magic.try_spend(4)
	var moving_from := p.position
	await start("bow_direct_press")
	await step(23)
	check(
		"empty bow preserves full movement speed",
		(
			absf(Vector2(p.velocity.x, p.velocity.z).length() - p.settings.max_speed) < .01
			and absf(p.position.distance_to(moving_from) - p.settings.max_speed * .2) < .03
		),
		p.position.distance_to(moving_from)
	)
	check(
		"empty feedback uses upper-body animation filter",
		p.state == "bow_empty" and p.visual.action_mix.filter_enabled
	)
	# Real key/mouse/trigger edges: an empty action must fail before any charge pose.
	for binding in ["Q", "RMB"]:
		await reset_bow()
		p.magic.try_spend(4)
		p.bow.settings.charged_arrow_unlocked = true
		denied_count = 0
		p.use_test_input = false
		pc_button(binding, true)
		await step(3)
		check(
			binding + " empty press plays refusal immediately",
			p.state == "bow_empty" and p.clip == "bow_empty" and denied_count == 1
		)
		check(
			binding + " empty has no arrow aim or charge",
			(
				not p.visual.bow.visible
				and not p.visual.bow.held_arrow.visible
				and not p.bow.aim_line.visible
				and not p.bow.charged
				and not p.bow.shot_pending
			)
		)
		await step(120)
		check(
			binding + " empty hold does not repeat or charge",
			p.state == "locomotion" and denied_count == 1 and p.bow.shots_fired == 0
		)
		p.magic.restore(1)
		await step(40)
		check(
			binding + " refill while held requires new press",
			p.state == "locomotion" and p.magic.current == 1
		)
		pc_button(binding, false)
		await step(3)
		pc_button(binding, true)
		await step(40)
		check(
			binding + " new press after refill draws",
			p.state == "bow_draw" and p.magic.current == 1
		)
		pc_button(binding, false)
		await step(40)
		check(
			binding + " recovered shot consumes once",
			p.magic.current == 0 and p.bow.shots_fired == 1
		)
		p.use_test_input = true
	await reset_bow()
	p.magic.try_spend(4)
	p.use_test_input = false
	denied_count = 0
	joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await step(25)
	joy_button(JOY_BUTTON_B, true)
	await step(3)
	check(
		"controller empty trigger refuses before draw",
		p.state == "bow_empty" and denied_count == 1 and not p.visual.bow.held_arrow.visible
	)
	await step(120)
	check(
		"controller empty hold never charges",
		p.state == "bow_aim" and denied_count == 1 and p.bow.shots_fired == 0
	)
	joy_button(JOY_BUTTON_B, false)
	joy_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await step(25)
	p.use_test_input = true
	for interruption in ["dodge", "light", "hurt", "dead"]:
		await reset_bow()
		p.magic.try_spend(4)
		await start("bow_direct_press")
		await step(5)
		if interruption in ["hurt", "dead"]:
			p.receive_hit(
				1 if interruption == "hurt" else 10,
				GameClock.next_attack_id(),
				p.position + Vector3.FORWARD
			)
		else:
			await start(interruption)
		var expected: String = (
			"roll"
			if interruption == "dodge"
			else ("light_attack" if interruption == "light" else interruption)
		)
		check(
			"refusal allows " + interruption,
			p.state == expected and not p.bow.shot_pending and p.bow.shots_fired == 0
		)
	await reset_bow()
	await start("bow_direct_press")
	await step(10)
	p.magic.try_spend(4)
	await step(2)
	check(
		"magic drain interrupts existing draw",
		p.state == "bow_empty" and not p.visual.bow.held_arrow.visible and not p.bow.shot_pending
	)
	GameClock.hitstop(.04)
	var frozen := p.action_time
	await step(4)
	check("refusal respects shared hitstop", is_equal_approx(p.action_time, frozen))
	GameClock.paused = true
	await step(5)
	check("refusal respects pause", is_equal_approx(p.action_time, frozen))
	GameClock.paused = false
	await step(3)
	check(
		"resume leaves valid empty weapon pose",
		p.state == "locomotion" and p.visual.weapon.visible and not p.visual.bow.visible
	)
	await reset_bow()


func shot(draw_ticks := 36) -> void:
	if not p.bow.active():
		await start("bow_aim")
		await step(25)
	await start("bow_draw")
	await step(draw_ticks)
	await start("bow_release")
	await step(30)


func reset_bow(at := Vector3(-3.8, 0, 3.5)) -> void:
	for arrow in get_tree().get_nodes_in_group("projectiles"):
		arrow.queue_free()
	await reset(at)
	p.bow.shots_fired = 0
	p.bow.settings.charged_arrow_unlocked = false


func on_arrow(arrow: MagicArrow, amount: float) -> void:
	release_samples.append(
		{
			"time": p.action_time,
			"magic": p.magic.current,
			"damage": amount,
			"origin": arrow.global_position,
			"muzzle_error": arrow.global_position.distance_to(p.visual.bow.muzzle()),
			"held": p.visual.bow.held_arrow.visible
		}
	)


func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	render_cap = Engine.max_fps
	p.bow.arrow_fired.connect(on_arrow)
	p.magic.denied.connect(on_denied)
	await reset_bow()
	for clip_name in [
		"bow_equip", "bow_aim", "bow_draw", "bow_hold", "bow_release", "bow_unequip", "bow_empty"
	]:
		check("import " + clip_name, p.visual.animation_player.has_animation(clip_name))
	for i in 4:
		await shot()
		check(
			"shot consumes exactly one " + str(i + 1),
			p.magic.current == 3 - i and p.bow.shots_fired == i + 1
		)
	await shot()
	check("fifth shot blocked", p.magic.current == 0 and p.bow.shots_fired == 4)
	await step(120)
	check("magic never regenerates with time", p.magic.current == 0)
	await check_empty_draw()
	await reset_bow()
	await start("bow_aim")
	await step(25)
	await start("bow_draw")
	await step(15)
	await start("bow_release")
	await step(35)
	check(
		"early release free",
		p.magic.current == 4 and p.bow.shots_fired == 0 and p.state == "bow_aim"
	)
	await start("bow_draw")
	await step(150)
	check("full bow charge fires once while held", p.magic.current == 3 and p.bow.shots_fired == 1)
	await start("bow_cancel")
	await step(25)
	check(
		"Q cancel free and restores sword",
		(
			p.magic.current == 3
			and p.state == "locomotion"
			and p.visual.weapon.visible
			and not p.visual.bow.visible
			and not p.visual.bow.held_arrow.visible
		)
	)
	for interruption in ["dodge", "hurt", "dead"]:
		await reset_bow()
		await start("bow_aim")
		await step(25)
		await start("bow_draw")
		await step(40)
		if interruption == "dodge":
			await start("dodge")
		else:
			p.receive_hit(
				1 if interruption == "hurt" else 10,
				GameClock.next_attack_id(),
				p.position + Vector3.FORWARD
			)
		check(
			"cancel " + interruption,
			(
				p.magic.current == 4
				and p.bow.shots_fired == 0
				and not p.bow.shot_pending
				and p.visual.weapon.visible
				and not p.visual.bow.held_arrow.visible
			)
		)
		arena.restart()
		check(
			"valid respawn after " + interruption,
			(
				p.state == "locomotion"
				and p.magic.current == 4
				and p.visual.weapon.visible
				and not p.visual.bow.visible
			)
		)
	await reset_bow()
	p.attacks_started.clear()
	await start("bow_direct_press")
	await step(45)
	check(
		"direct bow input never starts melee",
		p.attacks_started.is_empty() and p.state == "bow_draw" and p.magic.current == 4
	)
	p.test_input = Vector2.UP
	var origin = p.position
	await step(30)
	check(
		"bow charge allows slow movement",
		(
			p.position.distance_to(origin) > p.settings.max_speed * .04
			and p.position.distance_to(origin) < p.settings.max_speed * .09
		)
	)
	p.test_input = Vector2.ZERO
	await start("bow_direct_release")
	await step(35)
	check(
		"direct release creates one arrow without left click",
		p.bow.shots_fired == 1 and p.magic.current == 3 and p.state == "locomotion"
	)
	await start("bow_direct_press")
	await step(35)
	await start("light")
	check(
		"left click remains melee and cancels drawn arrow",
		p.state == "light_attack" and p.magic.current == 3 and not p.visual.bow.visible
	)
	await until_idle()
	# Exercise the real InputMap event routing, in addition to state requests.
	for binding in ["Q", "RMB"]:
		await reset_bow()
		p.use_test_input = false
		pc_button(binding, true)
		await step(55)
		check(binding + " alone draws", p.state == "bow_draw" and p.magic.current == 4)
		pc_button(binding, false)
		await step(40)
		check(binding + " release shoots once", p.bow.shots_fired == 1 and p.magic.current == 3)
		p.use_test_input = true
	await reset_bow()
	p.use_test_input = false
	joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await step(25)
	joy_axis(JOY_AXIS_LEFT_X, 1.0)
	await step(6)
	var controller_direction := p.facing
	joy_axis(JOY_AXIS_LEFT_X, 0.0)
	await step(3)
	var stationary_mouse := InputEventMouseMotion.new()
	Input.parse_input_event(stationary_mouse)
	check(
		"controller keeps last direction with stationary mouse",
		p.input_device == "controller" and p.facing.is_equal_approx(controller_direction)
	)
	joy_button(JOY_BUTTON_B, true)
	await step(40)
	joy_button(JOY_BUTTON_B, false)
	await step(30)
	check("controller L2 circle produces one shot", p.bow.shots_fired == 1 and p.magic.current == 3)
	joy_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await step(25)
	p.use_test_input = true
	await reset_bow()
	# Straight controller aim: target shares the player lane, independent of hand offset.
	await place_target(0, Vector3(-3.8, 0, 0.2))
	await shot()
	await step(45)
	check(
		"normal arrow damage and no refill",
		targets[0].health.current == 5 and p.magic.current == 3,
		targets[0].health.current
	)
	await reset_bow()
	p.bow.settings.charged_arrow_unlocked = true
	# Straight controller aim: target shares the player lane, independent of hand offset.
	await place_target(0, Vector3(-3.8, 0, 0.2))
	await shot(104)
	await step(45)
	check(
		"charged arrow double damage same cost",
		targets[0].health.current == 4 and p.magic.current == 3,
		{
			"hp": targets[0].health.current,
			"magic": p.magic.current,
			"shots": p.bow.shots_fired,
			"state": p.state
		}
	)
	await reset_bow()
	await place_target(0, Vector3(-3.8, 0, 1.5))
	await place_target(1, Vector3(-3.8, 0, .3))
	await shot()
	await step(45)
	check(
		"first target only with two hurtboxes",
		targets[0].health.current == 5 and targets[1].health.current == 6
	)
	await reset_bow(Vector3(1.9, 0, 0))
	await place_target(0, Vector3(1.7, 0, -1.8))
	await shot()
	await step(50)
	check("wall blocks arrow", targets[0].health.current == 6 and p.magic.current == 3)
	await reset_bow(Vector3(1.9, 0, -.66))
	await place_target(0, Vector3(1.7, 0, -1.8))
	await shot()
	await step(40)
	check("muzzle cannot spawn through wall", targets[0].health.current == 6)
	await reset_bow(Vector3(0, 0, 2))
	p.magic.current = 1
	await place_target(0, p.position + Vector3(.55, 0, -.86))
	await place_target(1, p.position + Vector3(-.45, 0, -.82))
	await start("light")
	await step(65)
	check(
		"multi-target melee restores once",
		p.magic.current == 2 and targets[0].health.current == 5 and targets[1].health.current == 5
	)
	p.magic.current = 4
	await start("light")
	await step(65)
	check("refill capped", p.magic.current == 4)
	await reset_bow()
	p.magic.current = 1
	await start("light")
	await step(65)
	check("melee miss gives no magic", p.magic.current == 1)
	await reset_bow()
	await shot()
	# A surviving projectile pauses on the same clock.
	await start("bow_draw")
	await step(36)
	await start("bow_release")
	await step(5)
	var arrows = get_tree().get_nodes_in_group("projectiles")
	if not arrows.is_empty():
		var arrow = arrows.back()
		var at = arrow.global_position
		GameClock.hitstop(.04)
		await step(4)
		check("arrow hitstop no movement", arrow.global_position.is_equal_approx(at))
		GameClock.paused = true
		await step(10)
		check("arrow pause no movement", arrow.global_position.is_equal_approx(at))
		GameClock.paused = false
		await step(20)
		check(
			"arrow resumes without jump",
			not is_instance_valid(arrow) or arrow.global_position.distance_to(at) < 3.1
		)
	else:
		check("projectile available for pause check", false)
	arena.restart()
	await step(3)
	check(
		"restart removes every projectile", get_tree().get_nodes_in_group("projectiles").is_empty()
	)
	var synchronized := true
	for sample in release_samples:
		synchronized = (
			synchronized
			and absf(sample.time - p.bow.settings.release_moment) <= 1.0 / 120.0 + .0001
		)
	check("release clock sampled on shared time", synchronized, release_samples)
	var f = FileAccess.open(report_path("bow"), FileAccess.WRITE)
	f.store_string(
		JSON.stringify(
			{
				"observed_render_fps":
				(
					(Engine.get_frames_drawn() - initial_render_frame)
					* 1000.0
					/ maxi(1, Time.get_ticks_msec() - initial_wall_ms)
				),
				"physics_fps": Engine.physics_ticks_per_second,
				"render_cap": render_cap,
				"failures": failures,
				"results": results
			},
			"\t"
		)
	)
	f.close()
	print("BOW_REPLAY_FINISHED ", failures, " failures; ", results.size(), " checks")
	p.bow.settings.charged_arrow_unlocked = false
	if "--bow-replay" in OS.get_cmdline_user_args():
		get_tree().quit(1 if failures else 0)
	else:
		arena.restart()
		p.use_test_input = false
		for d in targets:
			d.disabled = false
		queue_free()


func pc_button(binding: String, pressed: bool) -> void:
	if binding == "Q":
		var event := InputEventKey.new()
		event.physical_keycode = KEY_Q
		event.keycode = KEY_Q
		event.pressed = pressed
		Input.parse_input_event(event)
	else:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
		Input.parse_input_event(event)


func joy_axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func joy_button(button: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
