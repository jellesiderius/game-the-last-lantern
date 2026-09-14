extends Node
signal tick_done
var arena: Node3D
var p: PlayerCharacter
var targets: Array
var results: Array = []
var failures := 0
var tick := 0
var render_cap := 0
var initial_render_frame := 0
var initial_wall_ms := 0


func _ready() -> void:
	process_physics_priority = 100
	call_deferred("run")


func _physics_process(_dt: float) -> void:
	tick += 1
	tick_done.emit()


func step(frames: int) -> void:
	for _i in frames:
		await tick_done


func check(label: String, passed: bool, data = null) -> void:
	results.append({"check": label, "passed": passed, "data": data})
	if not passed:
		failures += 1
	print("CHECK ", label, " ", "PASS" if passed else "FAIL", " ", JSON.stringify(data))


func reset(at := Vector3(0, 0, 2)) -> void:
	# Editor-added actors can enter the group before the named regression fixtures.
	# Keep the original fixtures stable while still disabling every extra actor below.
	if arena.has_node("DummyA"):
		var ordered: Array = []
		for fixture in [
			"DummyA", "DummyB", "DummyBehindWall", "PracticeEnemy", "RangeNear", "RangeFar"
		]:
			ordered.append(arena.get_node(fixture))
		for target in targets:
			if not ordered.has(target):
				ordered.append(target)
		targets = ordered
	GameClock.reset()
	p.respawn(at)
	p.use_test_input = true
	p.test_input = Vector2.ZERO
	p.was_paused = false
	p.facing = Vector3.FORWARD
	p.pivot.rotation.y = 0
	p.set_physics_process(true)
	for i in targets.size():
		var d = targets[i]
		d.reset_target()
		d.disabled = true
		d.position = Vector3(20 + i * 3, 0, 0)
	await step(3)


func until_idle(max_frames := 240) -> int:
	var count := 0
	while p.state != "locomotion" and count < max_frames:
		await step(1)
		count += 1
	return count


func start(action: String) -> void:
	p.request_action(action)
	await step(1)


func place_target(index: int, at: Vector3) -> void:
	targets[index].position = at
	await step(2)


func prepare_window() -> void:
	if DisplayServer.get_name() != "headless":
		get_window().position = Vector2i(80, 80)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
		get_window().grab_focus()
	initial_render_frame = Engine.get_frames_drawn()
	initial_wall_ms = Time.get_ticks_msec()


func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	render_cap = Engine.max_fps
	check(
		"selected profile initialized",
		p.definition != null and p.visual.scene_file_path == p.definition.visual_scene.resource_path
	)
	check(
		"movement and animation use selected character profile",
		(
			p.definition.movement != null
			and p.visual.movement == p.settings
			and is_equal_approx(p.settings.max_speed, p.definition.movement.max_speed)
		)
	)
	await reset()
	var camera = get_viewport().get_camera_3d()
	var initial_basis = camera.global_basis
	var up = p.move_direction(Vector2.UP)
	var right = p.move_direction(Vector2.RIGHT)
	check(
		"camera screen directions",
		(
			camera.unproject_position(p.position + up).y < camera.unproject_position(p.position).y
			and (
				camera.unproject_position(p.position + right).x
				> camera.unproject_position(p.position).x
			)
		)
	)
	var distances = []
	for stick in [Vector2.UP, Vector2(1, -1).normalized()]:
		await reset(Vector3(3.0, 0, 4.5))
		p.test_input = stick
		var origin = p.position
		await step(120)
		distances.append(Vector2(p.position.x - origin.x, p.position.z - origin.z).length())
		print(
			"MOVEMENT_TRACE ",
			JSON.stringify(
				{
					"origin": origin,
					"end": p.position,
					"input": p.test_input,
					"direction": p.input_direction,
					"state": p.state,
					"camera": camera.global_basis
				}
			)
		)
		check(
			"maximum speed " + str(stick),
			absf(Vector2(p.velocity.x, p.velocity.z).length() - p.settings.max_speed) < .01
		)
		check(
			"full-speed cycle matches authored character stride",
			(
				is_equal_approx(
					float(p.visual.tree.get("parameters/LocomotionRate/scale")),
					p.settings.max_speed / p.settings.run_cycle_speed
				)
				and (
					p.settings.max_speed / p.settings.run_cycle_speed
					<= p.settings.maximum_locomotion_rate
				)
			)
		)
	check("straight equals diagonal distance", absf(distances[0] - distances[1]) < .015, distances)
	check("camera orientation independent", camera.global_basis.is_equal_approx(initial_basis))
	await reset()
	p.test_input = Vector2.UP * .5
	await step(40)
	check(
		"analog half input",
		absf(Vector2(p.velocity.x, p.velocity.z).length() - p.settings.max_speed * .5) < .01
	)
	p.test_input = Vector2.ZERO
	await step(8)
	check("quick braking", Vector2(p.velocity.x, p.velocity.z).length() < .01)
	await reset(Vector3(0, 0, 4))
	p.facing = Vector3.RIGHT
	var roll_start = p.position
	await start("dodge")
	var roll_ticks = 1 + await until_idle()
	check(
		"roll distance",
		absf(p.position.distance_to(roll_start) - 3.36) < .03,
		p.position.distance_to(roll_start)
	)
	check("roll duration", absf(float(roll_ticks) / 120 - .42) < .012, float(roll_ticks) / 120)
	for action in ["walk", "dodge", "light"]:
		await reset(Vector3(5.3, 0, 3))
		p.facing = Vector3.RIGHT
		if action == "walk":
			p.test_input = Vector2(.7071068, .7071068)
		else:
			await start(action)
		await step(100)
		check(
			"wall blocks " + action,
			p.position.x <= 5.7 - p.definition.body_radius + .002,
			p.position.x
		)
	await reset()
	for clip_name in [
		"idle",
		"walk",
		"run",
		"dodge_roll",
		"attack_1",
		"attack_2",
		"attack_3",
		"heavy_charge",
		"heavy_hold",
		"heavy_release",
		"heavy_release_charged",
		"roll_attack",
		"hurt",
		"death"
	]:
		check("import clip " + clip_name, p.visual.animation_player.has_animation(clip_name))
	p.attacks_started.clear()
	await start("light")
	await step(10)
	p.request_action("light")
	p.request_action("light")
	await until_idle()
	check("early repeated clicks are discarded", p.attacks_started == ["attack_1"])
	p.attacks_started.clear()
	await start("light")
	for i in 2:
		while p.action_time < p.attack_duration() - p.settings.light_reinput_window + .015:
			await step(1)
		p.request_action("light")
		await step(1)
	await until_idle()
	check(
		"three separate combo clips",
		p.attacks_started == ["attack_1", "attack_2", "attack_3"],
		p.attacks_started.duplicate()
	)
	await start("light")
	await until_idle()
	check("combo resets to first", p.attacks_started.back() == "attack_1")
	# Measure the same controller clock and active ticks for every attack.
	for attack_definition in p.moveset.attacks:
		var action_clip: String = attack_definition.clip
		await reset(Vector3(0, 0, 3))
		p.locked_direction = Vector3.FORWARD
		p._enter(
			(
				"light_attack"
				if action_clip.begins_with("attack_")
				else ("heavy_attack" if action_clip == "heavy_release" else "roll_attack")
			),
			action_clip
		)
		var duration_ticks := 0
		var active_ticks := 0
		while p.is_attack() and duration_ticks < 120:
			await step(1)
			duration_ticks += 1
			if p.active_window:
				active_ticks += 1
		var data: AttackDefinition = attack_definition
		var expected: float = data.duration()
		check(
			"action clock " + action_clip,
			(
				absf(duration_ticks / 120.0 - expected) <= 1.0 / 120.0 + .0001
				and absf(active_ticks / 120.0 - data.active_duration) <= 1.0 / 120.0 + .0001
			),
			{"duration": duration_ticks / 120.0, "active": active_ticks / 120.0}
		)
	await reset()
	p.heavy_held = true
	await start("heavy")
	await step(20)
	var partial = p.charge_amount
	await start("release")
	check("early heavy release", p.state == "heavy_attack" and partial > 0 and partial < 1, partial)
	await until_idle()
	await reset()
	p.heavy_held = true
	var charge_begin := GameClock.elapsed
	await start("heavy")
	while p.state == "charge":
		await step(1)
	check(
		"heavy auto release follows configurable charge duration",
		absf(GameClock.elapsed - charge_begin - p.settings.charge_duration) <= 1.0 / 120.0 + .0001,
		GameClock.elapsed - charge_begin
	)

	check(
		"full heavy charge releases automatically",
		p.state == "heavy_attack" and p.clip == "heavy_release" and p.charge_amount == 1
	)
	check("full charge selects distinct clip", p.visual.current_clip == "heavy_release_charged")
	check(
		"charged impact has stronger knockback without default time freeze",
		p.visual.weapon.knockback == 4.5 and is_zero_approx(p.visual.weapon.hitstop_duration)
	)
	await start("release")
	check("charged damage is three", p.visual.weapon.damage == 3, p.visual.weapon.damage)
	await until_idle()
	await reset()
	p.magic.current = 0
	await place_target(0, p.position + Vector3(0, 0, -.95))
	p.heavy_held = true
	await start("heavy")
	await until_idle()
	check(
		"charged strike applies three damage once and restores one magic",
		targets[0].health.current == 3 and p.magic.current == 1,
		{"hp": targets[0].health.current, "magic": p.magic.current}
	)
	await reset()
	p.heavy_held = true
	await start("heavy")
	await step(15)
	await start("dodge")
	check("dodge cancels charge", p.state == "roll" and not p.active_window)
	await until_idle()
	await reset()
	await start("dodge")
	await step(8)
	await start("light")
	await step(55)
	check("early roll attack input expires", p.state == "locomotion")
	await reset()
	await start("dodge")
	await step(39)
	await start("light")
	await step(12)
	check("late roll attack input queues", p.state == "roll_attack", p.debug_status())
	await until_idle()
	await reset()
	await start("light")
	await step(3)
	await start("dodge")
	await step(45)
	check("early dodge buffer expires", p.state == "locomotion")
	await reset()
	await start("light")
	await step(29)
	p.request_action("light")
	p.request_action("dodge")
	await step(5)
	check("late dodge wins over combo", p.state == "roll")
	await reset()
	await place_target(0, p.position + Vector3(.55, 0, -.86))
	await place_target(1, p.position + Vector3(-.45, 0, -.82))
	await place_target(2, p.position + Vector3(0, 0, .8))
	await start("light")
	await step(5)
	check(
		"windup does no damage", targets[0].health.current == 6 and targets[1].health.current == 6
	)
	await step(65)
	check(
		"one swing hits two targets once",
		targets[0].health.current == 5 and targets[1].health.current == 5,
		[targets[0].health.current, targets[1].health.current]
	)
	check("no invisible hit behind", targets[2].health.current == 6, targets[2].health.current)
	check(
		"damage stops after active window",
		targets[0].last_ids.size() == 1 and targets[1].last_ids.size() == 1
	)
	await reset(Vector3(1.9, 0, -.65))
	await place_target(0, Vector3(1.9, 0, -1.65))
	await start("light")
	await step(75)
	check("wall blocks damage", targets[0].health.current == 6, targets[0].health.current)
	await reset()
	var first_enemy_hit := GameClock.next_attack_id()
	check(
		"first enemy hit applies damage",
		p.receive_hit(1, first_enemy_hit, p.position + Vector3.FORWARD)
	)
	var simultaneous_damage := 1
	for i in 5:
		if p.receive_hit(1, GameClock.next_attack_id(), p.position + Vector3.RIGHT):
			simultaneous_damage += 1
	check(
		"six simultaneous enemies cost one HP during damage immunity",
		simultaneous_damage == 1 and p.health.current == 4
	)
	await step(2)
	check("damage immunity is visibly presented", p.visual.damage_feedback_active)
	await step(69)
	check(
		"late damage immunity still blocks another enemy",
		not p.receive_hit(1, GameClock.next_attack_id(), p.position + Vector3.FORWARD)
	)
	await step(3)
	check("immunity presentation ends with gameplay window", not p.visual.damage_feedback_active)
	check(
		"same enemy swing never damages twice after immunity",
		not p.receive_hit(1, first_enemy_hit, p.position + Vector3.FORWARD)
	)
	check(
		"fresh enemy swing damages after immunity expires",
		(
			p.receive_hit(1, GameClock.next_attack_id(), p.position + Vector3.FORWARD)
			and p.health.current == 3
		)
	)
	await reset()
	for at in [.025, .10, .29]:
		p.invulnerability = 0
		p.state = "roll"
		p.action_time = at
		var before = p.health.current
		var hit = p.receive_hit(1, GameClock.next_attack_id(), p.position + Vector3.FORWARD)
		check(
			"roll iframe " + str(at),
			hit == (at < .05 or at >= .27),
			[hit, before - p.health.current]
		)
	await reset()
	await start("light")
	await step(12)
	var before_time = p.action_time
	var before_pose = p.visual.skeleton.get_bone_pose_rotation(
		p.visual.skeleton.find_bone("sword_socket")
	)
	GameClock.hitstop(.04)
	await step(4)
	check("hitstop freezes shared action time", is_equal_approx(before_time, p.action_time))
	check(
		"hitstop freezes bone animation",
		before_pose.is_equal_approx(
			p.visual.skeleton.get_bone_pose_rotation(p.visual.skeleton.find_bone("sword_socket"))
		)
	)
	GameClock.paused = true
	before_time = p.action_time
	await step(10)
	check("pause freezes action", is_equal_approx(before_time, p.action_time))
	arena.restart()
	check(
		"restart clears hitstop and hitboxes",
		(
			not GameClock.paused
			and GameClock.stop_remaining == 0
			and not p.active_window
			and p.visual.weapon.trail_points.is_empty()
			and Engine.time_scale == 1
		)
	)
	await reset()
	var got_hit = p.receive_hit(1, GameClock.next_attack_id(), p.position + Vector3.FORWARD)
	check("hurt interrupts action", got_hit and p.state == "hurt" and p.health.current == 4)
	check(
		"damage grants invulnerability",
		not p.receive_hit(1, GameClock.next_attack_id(), p.position + Vector3.FORWARD)
	)
	await step(75)
	p.receive_hit(10, GameClock.next_attack_id(), p.position + Vector3.FORWARD)
	await step(110)
	check(
		"death and restart prompt",
		p.state == "dead" and p.health.current == 0 and p.action_time >= .9
	)
	arena.restart()
	check("respawn restores HP", p.state == "locomotion" and p.health.current == 5)
	await reset()
	var enemy = arena.get_node("PracticeEnemy")
	enemy.position = p.position + Vector3(0, 0, -.9)
	# Isolate tell/contact timing; turning into a target has its own movement replay.
	enemy.brain.direction = Vector3.BACK
	enemy.disabled = false
	# Default tells may include a random delay hold; wait for the first contact itself.
	for i in 240:
		if p.health.current < 5:
			break
		await step(1)
	check("enemy telegraph produces one damage", p.health.current == 4, p.health.current)
	await reset()
	p.visual.stowed = true
	p.visual.sample("idle", 0, 0, 0)
	var tip = p.visual.weapon.get_node("BladeTip").global_position - p.position
	if p.visual.stow_at_rest:
		check(
			"stowed blade centered and above floor",
			absf(tip.x) < .005 and tip.y > .06 and tip.y < p.definition.body_height * .3,
			tip
		)
	else:
		check(
			"armed idle blade clear of floor and attached to hand",
			(
				tip.x > p.definition.body_radius
				and tip.y > .02
				and tip.y < p.definition.body_height
				and p.visual.socket.bone_name == "sword_socket"
			),
			tip
		)
	check(
		"one bone-attached weapon",
		(
			p.visual.find_children("SwordAttachment", "BoneAttachment3D", true, false).size() == 1
			and p.visual.find_children("WeaponModel", "Node3D", true, false).size() == 1
		)
	)
	var output = {
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
	}
	var f = FileAccess.open(report_path("runtime"), FileAccess.WRITE)
	f.store_string(JSON.stringify(output, "\t"))
	f.close()
	print("REPLAY_FINISHED ", failures, " failures; ", results.size(), " checks")
	if "--replay" in OS.get_cmdline_user_args():
		get_tree().quit(1 if failures else 0)
	else:
		arena.restart()
		p.use_test_input = false
		for d in targets:
			d.disabled = false
		queue_free()


func report_path(suite: String) -> String:
	var suffix := "" if p.definition.id == "crow" else "_" + p.definition.id
	return "res://captures/" + suite + "_checks" + suffix + "_" + str(render_cap) + ".json"
