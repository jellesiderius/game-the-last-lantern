extends "res://tests/room_replay.gd"


func prepare_window() -> void:
	super.prepare_window()
	# These visual replays drive their own pause/reset scenarios. Physical keys
	# aimed at another Godot window must not pause or restart a recording.
	var hud := get_tree().current_scene.get_node("HUD")
	hud.set_process_input(false)
	InputRouter.controller_disconnected.disconnect(hud._controller_disconnected)


## Exercise the saved acorn prefab, authored rig and AI in the real miniature room.


func deploy(enemy, at: Vector3) -> void:
	enemy.position = at
	enemy.spawn_position = at
	enemy.disabled = false
	enemy.brain.reset_brain()


func wait_state(enemy, state: String, budget := 900) -> void:
	for i in budget:
		if enemy.brain.state == state:
			return
		await step(1)
	check("reaches " + state, false, enemy.brain.state)


func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	render_cap = Engine.max_fps
	var guards := get_tree().get_nodes_in_group("acorn_guards")
	check("two saved acorn enemies in startup room", guards.size() == 2)
	var enemy = guards[0]
	var visual = enemy.visual
	var skeleton: Skeleton3D = visual.find_children("*", "Skeleton3D", true, false)[0]
	check(
		"authored rig and separate club socket",
		skeleton.get_bone_count() == 19 and skeleton.find_bone("club_socket") >= 0
	)
	for clip in [
		"idle",
		"look_around",
		"walk",
		"run",
		"turn",
		"windup",
		"strike",
		"recover",
		"hurt",
		"death",
		"lunge_windup",
		"lunge_strike",
		"lunge_recover",
		"jab_windup",
		"jab_strike",
		"jab_recover",
		"jab_back_windup",
		"jab_back_strike",
		"jab_back_recover"
	]:
		check("imported clip " + clip, visual.animation_player.has_animation(clip))
	check("per-enemy hit flash material", enemy.flash_material != guards[1].flash_material)
	var navigation := NavigationWorld.surface_for(enemy, enemy.brain.settings.movement.radius)
	for i in 1800:
		if navigation.ready:
			break
		await step(1)
	check("world navigation initializes from saved collision", navigation.ready)
	check(
		"tree blocks a direct walk",
		not navigation.segment_clear(Vector3(-8, 0, -4), Vector3(-6, 0, -4), .25)
	)
	var landing := navigation.route(Vector3(-11, 0, .6), Vector3(-11, 4, -9), .25)
	check("long stair landing is reachable", not landing.is_empty() and landing[-1].y > 3.9)
	var bridge := navigation.route(Vector3(0, 0, .6), Vector3(0, 0, 6), .25)
	check("bridge connects both banks", not bridge.is_empty() and bridge[-1].z > 5.8)
	await reset(Vector3(0, 0, -1.5))
	deploy(enemy, Vector3(0, 0, -6))
	enemy.brain.direction = Vector3.BACK
	await step(60)
	check(
		"visible player is pursued promptly with running clip",
		enemy.position.z > -5.2 and visual.current_clip == "run",
		enemy.position
	)
	await wait_state(enemy, "windup")
	check("distance-closing opportunity selects lunge", enemy.brain.attack.clip == &"lunge_strike")
	var tell_start := GameClock.elapsed
	var tell_duration: float = enemy.brain.attack.windup
	await step(30)
	check(
		"windup shows warning and causes no damage",
		(
			enemy.get_node("Telegraph").visible
			and p.health.current == 5
			and visual.current_clip == enemy.brain.windup_clip
		)
	)
	var age: float = enemy.brain.state_time
	var bone_pose := skeleton.get_bone_pose(skeleton.find_bone("hand_R"))
	GameClock.paused = true
	await step(15)
	check(
		"pause freezes AI and authored bones together",
		(
			is_equal_approx(age, enemy.brain.state_time)
			and bone_pose.is_equal_approx(skeleton.get_bone_pose(skeleton.find_bone("hand_R")))
		)
	)
	GameClock.paused = false
	p.was_paused = false
	await wait_state(enemy, "strike")
	check(
		"complete authored tell before strike",
		GameClock.elapsed - tell_start >= tell_duration - .01,
		GameClock.elapsed - tell_start
	)
	await step(4)
	check("no damage before authored club contact", p.health.current == 5)
	await step(12)
	check("club strike deals exactly one health segment", p.health.current == 4, p.health.current)
	await wait_state(enemy, "recover")
	check(
		"recovery hides warning",
		not enemy.get_node("Telegraph").visible and visual.current_clip == enemy.brain.recovery_clip
	)
	var recovery_start: Vector3 = enemy.position
	var recovery_health := p.health.current
	await step(60)
	check(
		"stumble gives a stationary counterattack window",
		(
			enemy.brain.state == "recover"
			and enemy.position.distance_to(recovery_start) < .04
			and p.health.current == recovery_health
		),
		enemy.brain.state_time
	)
	await reset(Vector3(0, 0, -2))
	deploy(enemy, Vector3(0, 0, -2.75))
	await wait_state(enemy, "windup")
	check(
		"close opponent selects a close-range beat",
		enemy.brain.attack.clip in [&"strike", &"jab_strike", &"jab_back_strike"],
		enemy.brain.attack.clip
	)
	await step(35)
	var locked: Vector3 = enemy.brain.direction
	p.position = enemy.position - locked * .85
	# Judge the committed strike itself; a later string strike may legitimately retrack.
	var stayed_locked := true
	for i in 240:
		if enemy.brain.state == "windup" and enemy.brain.chain_count == 0:
			stayed_locked = stayed_locked and enemy.brain.direction.dot(locked) > .999
		elif enemy.brain.state == "strike":
			stayed_locked = stayed_locked and enemy.brain.direction.dot(locked) > .999
		else:
			break
		await step(1)
	check("late dodge behind the swing avoids damage", p.health.current == 5 and stayed_locked)
	await reset(Vector3(0, 0, -2))
	deploy(enemy, Vector3(0, 0, -3.0))
	var attack_id := GameClock.next_attack_id()
	enemy.receive_hit(1, attack_id, p.position)
	enemy.receive_hit(1, attack_id, p.position)
	await step(8)
	check(
		"hurt animation and target deduplication",
		visual.current_clip == "hurt" and enemy.health.current == 5
	)
	enemy.receive_hit(100, GameClock.next_attack_id(), p.position)
	await step(24)
	check(
		"death clip plays before disappearance",
		(
			visual.visible
			and visual.current_clip == "death"
			and enemy.get_node("Hurtbox").collision_layer == 0
		)
	)
	await step(120)
	check("defeated guard disappears", not visual.visible)
	await step(165)
	check(
		"practice-room respawn restores enemy and bones",
		enemy.health.current == 6 and visual.visible and enemy.reset_time == 0
	)
	await reset(Vector3(0, 0, -2))
	enemy.position = p.position + Vector3(.4, 0, -.9)
	await step(2)
	await start("light")
	await step(70)
	check(
		"sunblade damages imported acorn once",
		enemy.health.current == 5 and enemy.last_ids.size() == 1,
		enemy.health.current
	)
	await reset(Vector3(0, 0, -2))
	enemy.position = p.position + Vector3(0, 0, -3.3)
	p.bow.settings.charged_arrow_unlocked = false
	await start("bow_aim")
	await step(25)
	await start("bow_draw")
	await step(36)
	await start("bow_release")
	await step(75)
	check(
		"arrow hits imported acorn hurtbox",
		enemy.health.current == 5 and p.magic.current == 3,
		enemy.health.current
	)
	await tactical_checks(enemy)
	await pressure_checks(enemy)
	await return_heading_checks(enemy)
	await idle_routine_checks(enemy)
	await source_review(enemy)
	var rendered := Engine.get_frames_drawn() - initial_render_frame
	check(
		"actual rendered frames", DisplayServer.get_name() == "headless" or rendered > 60, rendered
	)
	var output := {
		"failures": failures,
		"results": results,
		"render_cap": render_cap,
		"renderer": RenderingServer.get_current_rendering_method(),
		"rendered_frames": rendered
	}
	(
		FileAccess
		. open("res://captures/acorn_guard/runtime_checks.json", FileAccess.WRITE)
		. store_string(JSON.stringify(output, "\t"))
	)
	print("ACORN_REPLAY_FINISHED ", failures, " failures; ", results.size(), " checks")
	get_tree().quit(1 if failures else 0)


func source_review(enemy) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await reset(Vector3(0, 0, -2))
	enemy.position = Vector3(0, 0, 9)
	enemy.reset_physics_interpolation()
	enemy.disabled = true
	enemy.visual.rotation = Vector3.ZERO
	GameClock.paused = true
	p.hide()
	arena.get_node("HUD").hide()
	var hidden_geometry: Array[Node3D] = []
	for child: Node3D in arena.get_node("Geometry").get_children():
		if child.visible and not child.name.begins_with("Ground_"):
			hidden_geometry.append(child)
			child.hide()
	var camera := get_viewport().get_camera_3d()
	var gameplay_camera_transform := camera.transform
	var gameplay_camera_size := camera.size
	camera.size = 1.85
	var interpolation := camera.physics_interpolation_mode
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var center: Vector3 = enemy.position + Vector3(0, .54, 0)
	for view in {
		"front": Vector3(0, .05, -4),
		"left": Vector3(-4, 0, 0),
		"right": Vector3(4, 0, 0),
		"back": Vector3(0, 0, 4),
		"game": Vector3(4, 6.7, -4)
	}:
		var offsets := {
			"front": Vector3(0, .05, -4),
			"left": Vector3(-4, 0, 0),
			"right": Vector3(4, 0, 0),
			"back": Vector3(0, 0, 4),
			"game": Vector3(4, 6.7, -4)
		}
		camera.global_position = center + offsets[view]
		camera.look_at(center)
		enemy.visual.sample("idle", 0.0)
		await shot("godot_" + view)
	camera.global_position = center + Vector3(2, 1.2, -4)
	camera.look_at(center)
	for action in [
		["walk", .12],
		["run", .13],
		["turn", .2],
		["windup", .65],
		["strike", .09],
		["lunge_windup", .56],
		["lunge_strike", .11],
		["lunge_recover", .2],
		["death", .65]
	]:
		enemy.visual.sample(action[0], action[1])
		await shot("godot_" + action[0])
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://captures/acorn_guard/motion")
	)
	var clips := [
		"run",
		"windup",
		"strike",
		"recover",
		"lunge_windup",
		"lunge_strike",
		"lunge_recover",
		"jab_windup",
		"jab_strike",
		"jab_back_windup",
		"jab_back_strike",
		"idle"
	]
	var durations := [
		.8,
		enemy.brain.settings.attack.windup,
		enemy.brain.settings.attack.active_duration,
		enemy.brain.settings.attack.recovery,
		enemy.brain.settings.attack_variants[1].windup,
		enemy.brain.settings.attack_variants[1].active_duration,
		enemy.brain.settings.attack_variants[1].recovery,
		enemy.brain.settings.attack_variants[2].windup,
		enemy.brain.settings.attack_variants[2].active_duration,
		enemy.brain.settings.attack_variants[3].windup,
		enemy.brain.settings.attack_variants[3].active_duration,
		.5
	]
	var frame := 0
	for i in clips.size():
		var clip_name: String = clips[i]
		var duration: float = durations[i]
		var imported_length: float = enemy.visual.animation_player.get_animation(clip_name).length
		for f in ceili(duration * 30.0):
			var time := float(f) / 30.0
			enemy.visual.sample(clip_name, time / duration * imported_length)
			await shot("motion/%03d" % frame)
			frame += 1
	for child in hidden_geometry:
		child.show()
	# Final screenshot uses the actual unchanged gameplay framing.
	GameClock.paused = false
	p.show()
	arena.get_node("HUD").show()
	camera.transform = gameplay_camera_transform
	camera.size = gameplay_camera_size
	camera.physics_interpolation_mode = interpolation
	camera.reset_physics_interpolation()
	for d in targets:
		d.disabled = false
		d.reset_target()
	p.respawn(Vector3(0, 0, -2))
	p.use_test_input = true
	arena.reset_camera()
	await wait_state(enemy, "windup")
	await step(20)
	await shot("gameplay")


func tactical_checks(enemy) -> void:
	await reset(Vector3(0, 0, -2))
	deploy(enemy, Vector3(0, 0, -3.5))
	enemy.brain.cooldown = .9
	p.heavy_held = true
	await start("heavy")
	await step(10)
	check("heavy reaction has a delay", enemy.brain.spacing_left == 0)
	await step(28)
	check(
		"visible heavy tell prompts limited reposition",
		enemy.brain.spacing_left > 0 and enemy.brain.decision_reason == "respect_heavy_tell",
		enemy.brain.observation
	)
	check("reposition releases attack admission", not AttackTokenManager.owns(enemy.brain))
	await step(110)
	check("reposition ends instead of fleeing forever", enemy.brain.spacing_left == 0)
	await reset(Vector3(0, 0, -2))
	await start("bow_aim")
	await step(25)
	await start("bow_draw")
	deploy(enemy, Vector3(0, 0, -4.5))
	enemy.brain.direction = Vector3.BACK
	await step(20)
	check(
		"bow pressure chooses lunge with an angled approach",
		(
			enemy.brain.decision_reason == "bow_pressure"
			and enemy.brain.attack.clip == &"lunge_strike"
			and absf(enemy.brain._approach_destination().x - enemy.brain.last_seen.x) > .4
		),
		enemy.brain.decision_history
	)
	# The same charge behind a real tree must not become an observation.
	await reset(Vector3(-7, 0, -3.2))
	deploy(enemy, Vector3(-7, 0, -4.8))
	enemy.brain.cooldown = 1.0
	p.heavy_held = true
	await start("heavy")
	await step(32)
	check(
		"occluded player action is not read through tree",
		not enemy.brain.observation.get("visible", false) and enemy.brain.spacing_left == 0
	)
	var decision_file := FileAccess.open(
		"res://captures/acorn_guard/tactical_decisions.json", FileAccess.WRITE
	)
	decision_file.store_string(
		JSON.stringify({"results": results, "last_decisions": enemy.brain.decision_history}, "\t")
	)


## Souls-like pressure: delayed tells, followup chains, anti-mash counters and punished openings.
func pressure_checks(enemy) -> void:
	var brain: EnemyBrain = enemy.brain
	var original: EnemySettings = brain.settings
	var tuned: EnemySettings = original.duplicate(true)
	for beat in tuned.attack_variants:
		beat.strikes = Vector2i(3, 3)
		beat.delay_range = Vector2(.2, .2)
	brain.settings = tuned
	await reset(Vector3(0, 0, -2))
	deploy(enemy, Vector3(0, 0, -2.7))
	p.invulnerability = 100
	await wait_state(enemy, "windup")
	check(
		"delay hold extends the authored tell",
		is_equal_approx(brain.windup_duration - brain.tell_duration, .2),
		[brain.tell_duration, brain.windup_duration]
	)
	var tell_start := GameClock.elapsed
	await wait_state(enemy, "strike")
	check(
		"delayed strike waits for tell plus hold",
		GameClock.elapsed - tell_start >= brain.windup_duration - .02,
		GameClock.elapsed - tell_start
	)
	await wait_state(enemy, "windup")
	check(
		"strike chains into a telegraphed followup that is never slower",
		(
			brain.chain_count == 1
			and brain.decision_reason == "chain_followup"
			and brain.tell_duration <= tuned.attack_variants[brain.attack_index].windup
			and AttackTokenManager.owns(brain)
			and enemy.get_node("Telegraph").visible
		),
		brain.decision_history.back()
	)
	await wait_state(enemy, "recover", 1200)
	check(
		"a three-strike turn delivers three separate strikes",
		brain.chain_count == 2,
		brain.chain_count
	)
	# Later strikes must land after the player's damage i-frames, not vanish inside them.
	for beat in tuned.attack_variants:
		beat.strikes = Vector2i(2, 2)
		beat.delay_range = Vector2.ZERO
	await reset(Vector3(0, 0, -2))
	deploy(enemy, Vector3(0, 0, -2.7))
	p.invulnerability = 0
	var landed := [0, p.health.current]
	var count_hit := func(current: float, _maximum: float):
		if current < landed[1]:
			landed[0] += 1
		landed[1] = current
	p.health.changed.connect(count_hit)
	await wait_state(enemy, "recover", 1200)
	p.health.changed.disconnect(count_hit)
	check("a two-strike turn deals two separate hits", landed[0] == 2, landed)
	brain.settings = original
	p.invulnerability = 0
	await reset(Vector3(0, 0, -2))
	deploy(enemy, Vector3(0, 0, -3.2))
	brain.cooldown = 5.0
	await step(20)
	enemy.receive_hit(.1, GameClock.next_attack_id(), p.position)
	check("a single hit still staggers", brain.state == "stagger", brain.state)
	enemy.receive_hit(.1, GameClock.next_attack_id(), p.position)
	enemy.receive_hit(.1, GameClock.next_attack_id(), p.position)
	check(
		"mashing triggers an armored counterattack",
		(
			brain.state == "windup"
			and brain.decision_reason == "retaliate_against_pressure"
			and AttackTokenManager.owns(brain)
		),
		brain.state
	)
	var counter_health: float = enemy.health.current
	enemy.receive_hit(.1, GameClock.next_attack_id(), p.position)
	check(
		"counter tell keeps its armor but still takes damage",
		brain.state == "windup" and enemy.health.current < counter_health
	)
	await reset(Vector3(0, 0, -2))
	deploy(enemy, Vector3(0, 0, -4.4))
	# Keep the guard circling (no granted turn) so only the opening can end its cooldown.
	brain.cooldown = 5.0
	await step(40)
	await start("light")
	var saw_opening := false
	var pressed := false
	for i in 30:
		await step(1)
		if brain.sees_opening():
			saw_opening = true
			pressed = pressed or (brain.pressing_opening and brain.cooldown == 0.0)
	check("visible attack recovery is read as an opening", saw_opening, brain.observation)
	check("an opening cancels cooldown and presses straight in", pressed)


func return_heading_checks(enemy) -> void:
	await reset(Vector3(5, 0, -4))
	deploy(enemy, Vector3(2, 0, -4))
	enemy.spawn_position = Vector3(-2, 0, -4)
	var original: EnemySettings = enemy.brain.settings
	enemy.brain.settings = original.duplicate(true)
	enemy.brain.settings.leash_distance = 1.5
	enemy.brain.direction = Vector3.RIGHT
	var at: Vector3 = enemy.position
	await step(12)
	check(
		"return turns on the spot before moving away",
		(
			enemy.brain.state == "return_home"
			and enemy.brain.turning_in_place
			and enemy.visual.current_clip == "turn"
			and enemy.position.distance_to(at) < .025
		),
		enemy.position - at
	)
	var camera := get_viewport().get_camera_3d()
	var review := DisplayServer.get_name() != "headless"
	if review:
		arena.set_physics_process(false)
		arena.camera_rig.position = Vector3(0, .65, -4)
		camera.size = 5
		arena.get_node("HUD").hide()
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://captures/acorn_guard/return_motion")
		)
	var minimum_alignment := 1.0
	var moving_frames := 0
	var trace: Array = []
	for i in 360:
		await step(1)
		var velocity: Vector3 = enemy.get_real_velocity()
		velocity.y = 0
		if velocity.length() > .2 and enemy.brain.state == "return_home":
			var front: Vector3 = -enemy.visual.global_basis.z
			minimum_alignment = minf(minimum_alignment, front.dot(velocity.normalized()))
			moving_frames += 1
		if i % 4 == 0:
			trace.append(
				{
					"position": enemy.position,
					"facing": enemy.brain.direction,
					"clip": enemy.visual.current_clip,
					"speed": velocity.length()
				}
			)
			if review:
				await shot("return_motion/%03d" % (i / 4))
	check(
		"return locomotion faces actual velocity",
		moving_frames > 80 and minimum_alignment > .965,
		minimum_alignment
	)
	check(
		"enemy arrives at home without diagonal skating",
		enemy.position.distance_to(enemy.spawn_position) < .19,
		enemy.position
	)
	(
		FileAccess
		. open("res://captures/acorn_guard/return_heading.json", FileAccess.WRITE)
		. store_string(
			JSON.stringify(
				{
					"min_facing_dot_velocity": minimum_alignment,
					"moving_frames": moving_frames,
					"trace": trace
				},
				"\t"
			)
		)
	)
	enemy.brain.settings = original
	if review:
		arena.set_physics_process(true)
		camera.size = 13
		arena.get_node("HUD").show()
		arena.reset_camera()


func idle_routine_checks(enemy) -> void:
	await reset(Vector3(12, 0, 8))
	deploy(enemy, Vector3(0, 0, -4))
	var skeleton: Skeleton3D = enemy.visual.find_children("*", "Skeleton3D", true, false)[0]
	var torso := skeleton.find_bone("torso")
	await step(6)
	var initial_pose := skeleton.get_bone_pose_rotation(torso)
	var states := {}
	var max_turn := 0.0
	var max_distance := 0.0
	var walking_frames := 0
	var review := DisplayServer.get_name() != "headless"
	var camera := get_viewport().get_camera_3d()
	if review:
		arena.set_physics_process(false)
		arena.camera_rig.position = Vector3(0, .65, -4)
		camera.size = 3.5
		arena.get_node("HUD").hide()
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://captures/acorn_guard/idle_motion")
		)
	for i in 780:
		await step(1)
		states[enemy.brain.state] = true
		if enemy.brain.state == "idle":
			max_turn = maxf(max_turn, initial_pose.angle_to(skeleton.get_bone_pose_rotation(torso)))
		if enemy.visual.current_clip == "walk":
			walking_frames += 1
		max_distance = maxf(max_distance, enemy.position.distance_to(enemy.spawn_position))
		if review and i % 4 == 0:
			await shot("idle_motion/%03d" % (i / 4))
	check("unalerted guard looks around and shifts its body", max_turn > .12, max_turn)
	check(
		"idle routine includes a short bounded walking patrol",
		(
			states.has("idle")
			and states.has("patrol")
			and walking_frames > 20
			and max_distance > .4
			and max_distance < 1.0
		),
		{"states": states, "radius": max_distance, "walk_frames": walking_frames}
	)
	GameClock.paused = true
	await step(1)
	var frozen_position: Vector3 = enemy.position
	var frozen_pose := skeleton.get_bone_pose(torso)
	var frozen_time: float = enemy.brain.state_time
	await step(24)
	check(
		"pause also freezes ambient routine and pose",
		(
			enemy.position.is_equal_approx(frozen_position)
			and frozen_pose.is_equal_approx(skeleton.get_bone_pose(torso))
			and is_equal_approx(frozen_time, enemy.brain.state_time)
		)
	)
	GameClock.paused = false
	p.was_paused = false
	p.respawn(enemy.position + Vector3(0, 0, 2.5))
	await step(35)
	check(
		"player sight immediately interrupts the idle routine",
		enemy.brain.memory > 0 and enemy.brain.state not in ["idle", "patrol", "return_home"]
	)
	if review:
		arena.set_physics_process(true)
		camera.size = 13
		arena.get_node("HUD").show()
		arena.reset_camera()


func shot(label: String) -> void:
	# A hidden macOS window may wait many physics ticks for a draw. Preserve the
	# sampled gameplay instant, without invoking pause-menu/input side effects.
	var previous_stop := GameClock.stop_remaining
	GameClock.stop_remaining = INF
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		"res://captures/acorn_guard/" + label + ".png"
	)
	GameClock.stop_remaining = previous_stop
