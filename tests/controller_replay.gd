extends "res://tests/runtime_replay.gd"
## Uses real InputEvents and the saved InputMap, including native GUI focus/activation.
var held_axes: Dictionary = {}
var held_buttons: Dictionary = {}


func axis(index: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = index
	event.axis_value = value
	held_axes[index] = value
	Input.parse_input_event(event)


func button(index: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = index
	event.pressed = pressed
	held_buttons[index] = pressed
	Input.parse_input_event(event)


func tap(index: int) -> void:
	button(index, true)
	await step(2)
	button(index, false)
	await step(2)
	# Native GUI focus uses deferred layout work, so allow its render boundary too.
	await get_tree().process_frame
	await step(1)


func clean(at := Vector3(1.5, 0, 3.5)) -> void:
	for index in held_axes:
		axis(index, 0)
	for index in held_buttons:
		button(index, false)
	await step(3)
	await reset(at)
	p.use_test_input = false
	InputRouter.blocked_through_frame = -1
	await step(3)


func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	render_cap = Engine.max_fps
	await clean()
	var camera := get_viewport().get_camera_3d()
	var camera_basis := camera.global_basis
	axis(JOY_AXIS_LEFT_Y, -1)
	await step(40)
	check(
		"left stick reaches full speed",
		is_equal_approx(Vector2(p.velocity.x, p.velocity.z).length(), p.settings.max_speed)
	)
	axis(JOY_AXIS_LEFT_X, 1)
	await step(16)
	check(
		"diagonal stick speed normalized",
		absf(Vector2(p.velocity.x, p.velocity.z).length() - p.settings.max_speed) < .01
	)
	await clean()
	axis(JOY_AXIS_LEFT_X, .1)
	await step(12)
	check(
		"stick drift below deadzone does not move",
		Vector2(p.velocity.x, p.velocity.z).length() < .01
	)
	axis(JOY_AXIS_LEFT_X, 0)
	await step(90)
	var original_position := p.position
	var camera_position: Vector3 = arena.camera_rig.position
	var facing := p.facing
	axis(JOY_AXIS_RIGHT_X, 1)
	await step(45)
	check(
		"right stick pans camera only",
		(
			arena.camera_rig.position.distance_to(camera_position) > .3
			and p.position.distance_to(original_position) < .01
			and p.facing.is_equal_approx(facing)
		)
	)
	check("look preserves fixed camera rotation", camera.global_basis.is_equal_approx(camera_basis))
	axis(JOY_AXIS_RIGHT_X, 0)
	await step(90)
	check(
		"camera look returns on neutral",
		arena.camera_rig.position.distance_to(camera_position) < .03
	)
	await clean()
	p.attacks_started.clear()
	await tap(JOY_BUTTON_X)
	check("square performs melee", p.state == "light_attack" and p.attacks_started == ["attack_1"])
	for i in 2:
		while p.action_time < p.attack_duration() - p.settings.light_reinput_window + .015:
			await step(1)
		await tap(JOY_BUTTON_X)
	await until_idle()
	check(
		"square combo keeps three distinct swings",
		p.attacks_started == ["attack_1", "attack_2", "attack_3"],
		p.attacks_started.duplicate()
	)
	await clean()
	await tap(JOY_BUTTON_B)
	check("circle alone does not dodge or shoot", p.state == "locomotion" and p.magic.current == 4)
	await tap(JOY_BUTTON_A)
	check("cross starts dodge", p.state == "roll")
	axis(JOY_AXIS_TRIGGER_RIGHT, 1)
	await step(55)
	check(
		"cross then R2 queues roll attack",
		p.state == "roll_attack" and p.clip == "roll_attack",
		p.debug_status()
	)
	await clean()
	axis(JOY_AXIS_TRIGGER_RIGHT, 1)
	await step(22)
	check("R2 starts heavy charge", p.state == "charge" and p.charge_amount > .2)
	axis(JOY_AXIS_TRIGGER_RIGHT, 0)
	await step(6)
	check(
		"R2 release performs heavy",
		p.state == "heavy_attack" and p.charge_amount < 1,
		p.debug_status()
	)
	await clean()
	p.attacks_started.clear()
	axis(JOY_AXIS_TRIGGER_RIGHT, 1)
	await step(84)
	check(
		"full heavy charge auto releases once", p.state == "heavy_attack" and p.charge_amount == 1
	)
	await step(160)
	check(
		"holding R2 does not repeat heavy",
		p.state == "locomotion" and p.attacks_started == ["heavy_release"]
	)
	await clean()
	axis(JOY_AXIS_TRIGGER_LEFT, 1)
	await step(5)
	check("L2 enters bow aim", p.state == "bow_aim")
	axis(JOY_AXIS_LEFT_X, .75)
	await step(18)
	var aim_direction := p.facing
	axis(JOY_AXIS_LEFT_X, 0)
	await step(8)
	var still_mouse := InputEventMouseMotion.new()
	still_mouse.relative = Vector2.ZERO
	Input.parse_input_event(still_mouse)
	await step(3)
	check(
		"neutral stick and still mouse preserve controller aim",
		p.facing.is_equal_approx(aim_direction) and p.input_device == "controller"
	)
	p.bow.shots_fired = 0
	button(JOY_BUTTON_B, true)
	await step(32)
	check("circle draws while L2 held", p.state == "bow_draw" and p.bow.shots_fired == 0)
	button(JOY_BUTTON_B, false)
	await step(7)
	check(
		"circle release creates one arrow",
		p.bow.shots_fired == 1 and p.magic.current == 3 and p.state == "bow_shoot"
	)
	await step(28)
	check("held L2 returns to ready aim", p.state == "bow_aim")
	button(JOY_BUTTON_B, true)
	await step(190)
	check(
		"full bow auto fires once without repeats",
		p.bow.shots_fired == 2 and p.magic.current == 2 and p.state == "bow_aim"
	)
	button(JOY_BUTTON_B, false)
	await clean()
	axis(JOY_AXIS_TRIGGER_LEFT, 1)
	await step(5)
	button(JOY_BUTTON_B, true)
	await step(10)
	button(JOY_BUTTON_B, false)
	await step(30)
	check("early circle release costs no magic", p.magic.current == 4)
	button(JOY_BUTTON_B, true)
	await step(10)
	await tap(JOY_BUTTON_A)
	check(
		"cross cancels bow charge immediately",
		p.state == "roll" and p.magic.current == 4 and not p.visual.bow.visible
	)
	await clean()
	axis(JOY_AXIS_TRIGGER_LEFT, 1)
	await step(5)
	button(JOY_BUTTON_B, true)
	await step(10)
	axis(JOY_AXIS_TRIGGER_LEFT, 0)
	await step(28)
	check("L2 release cancels pending shot", p.magic.current == 4 and p.state == "locomotion")
	await clean(Vector3(0, 0, 3))
	p.magic.current = 0
	axis(JOY_AXIS_TRIGGER_LEFT, 1)
	axis(JOY_AXIS_LEFT_X, 1)
	await step(16)
	button(JOY_BUTTON_B, true)
	await step(12)
	check(
		"empty bow refusal preserves full movement",
		(
			p.state == "bow_empty"
			and absf(Vector2(p.velocity.x, p.velocity.z).length() - p.settings.max_speed) < .01
			and not p.visual.bow.held_arrow.visible
		)
	)
	await step(34)
	check(
		"empty held aim does not slow movement again",
		(
			absf(Vector2(p.velocity.x, p.velocity.z).length() - p.settings.max_speed) < .01
			and p.magic.current == 0
		)
	)
	await clean()
	var count := p.attacks_started.size()
	await tap(JOY_BUTTON_Y)
	check(
		"triangle is not a heavy attack",
		p.state == "locomotion" and p.attacks_started.size() == count
	)
	targets[0].position = p.position + Vector3(.8, 0, 0)
	targets[0].spawn_position = targets[0].position
	targets[0].health.current = 2
	await step(3)
	await tap(JOY_BUTTON_Y)
	check("triangle interacts with nearby friendly target", targets[0].health.current == 6)
	await tap(JOY_BUTTON_DPAD_RIGHT)
	check("locked ranged slot leaves bow selected", p.ranged_loadout.selected_slot == 0)
	await tap(JOY_BUTTON_DPAD_UP)
	check("D-pad up selects bow", p.ranged_loadout.selected_slot == 0)
	await clean()
	var hud = arena.get_node("HUD")
	var menu: GamePauseMenu = hud.pause_panel
	await tap(JOY_BUTTON_START)
	check(
		"Options opens menu and focuses resume",
		(
			GameClock.paused
			and menu.visible
			and get_viewport().gui_get_focus_owner() == menu.get_node("Layout/Tabs/Game/Resume")
		)
	)
	await tap(JOY_BUTTON_RIGHT_SHOULDER)
	check(
		"R1 opens controls tab with PS prompts",
		(
			menu.tabs.current_tab == 1
			and "ps_l2.svg" in menu.get_node("Layout/Tabs/Controls/Bindings").text
			and "ps_circle.svg" in menu.get_node("Layout/Tabs/Controls/Bindings").text
		)
	)
	await tap(JOY_BUTTON_RIGHT_SHOULDER)
	check(
		"R1 opens settings with focused checkbox",
		menu.tabs.current_tab == 2 and get_viewport().gui_get_focus_owner() is CheckButton
	)
	var original_shake: bool = p.settings.camera_shake
	await tap(JOY_BUTTON_A)
	check(
		"cross toggles focused setting",
		p.settings.camera_shake != original_shake and p.state == "locomotion"
	)
	await tap(JOY_BUTTON_LEFT_SHOULDER)
	await tap(JOY_BUTTON_LEFT_SHOULDER)
	check("L1 cycles back to game tab", menu.tabs.current_tab == 0)
	await tap(JOY_BUTTON_A)
	await step(8)
	check(
		"cross resumes without leaking dodge",
		not GameClock.paused and p.state == "locomotion" and not menu.visible
	)
	await tap(JOY_BUTTON_TOUCHPAD)
	check("touchpad opens menu", GameClock.paused and menu.visible)
	await tap(JOY_BUTTON_B)
	await step(8)
	check(
		"circle closes menu without firing",
		not GameClock.paused and p.state == "locomotion" and p.magic.current == 4
	)
	axis(JOY_AXIS_TRIGGER_LEFT, 1)
	await step(5)
	button(JOY_BUTTON_B, true)
	await step(10)
	InputRouter._controller_connection_changed(0, false)
	await step(5)
	check(
		"controller disconnect pauses and cancels draw",
		(
			GameClock.paused
			and p.state == "locomotion"
			and p.magic.current == 4
			and not p.bow.shot_pending
		)
	)
	button(JOY_BUTTON_B, false)
	axis(JOY_AXIS_TRIGGER_LEFT, 0)
	await tap(JOY_BUTTON_B)
	await step(10)
	check(
		"resume after disconnect does not auto fire",
		not GameClock.paused and p.magic.current == 4 and p.state == "locomotion"
	)
	await clean()
	p.receive_hit(10, GameClock.next_attack_id(), p.position + Vector3.FORWARD)
	await step(120)
	check(
		"death focuses controller restart",
		(
			menu.visible
			and get_viewport().gui_get_focus_owner() == menu.get_node("Layout/Tabs/Game/Restart")
		)
	)
	await tap(JOY_BUTTON_A)
	await step(8)
	check(
		"cross restarts from death without dodge",
		p.health.current == 5 and p.state == "locomotion" and not menu.visible
	)
	var output := {
		"failures": failures,
		"results": results,
		"physics_fps": Engine.physics_ticks_per_second,
		"render_cap": render_cap,
		"physical_controller": false,
		"observed_render_fps":
		(
			(Engine.get_frames_drawn() - initial_render_frame)
			* 1000.0
			/ maxi(1, Time.get_ticks_msec() - initial_wall_ms)
		)
	}
	var file := FileAccess.open(report_path("controller"), FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	file.close()
	print("CONTROLLER_REPLAY_FINISHED ", failures, " failures; ", results.size(), " checks")
	get_tree().quit(1 if failures else 0)
