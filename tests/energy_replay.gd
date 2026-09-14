extends "res://tests/room_replay.gd"
## Measured reach and presentation of the sunblade's visible energy extension.


func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	render_cap = Engine.max_fps
	p.visual.weapon.swing_random.seed = 73159
	var origin := Vector3(0, 0, -3)
	for distance in [.85, 1.25, 1.65, 1.85]:
		await reset(origin)
		await place_target(0, origin + Vector3.FORWARD * distance)
		await start("light")
		await until_idle()
		check(
			"light hits visible range %.2f m" % distance,
			targets[0].health.current == 5,
			targets[0].health.current
		)
	await reset(origin)
	p.magic.try_spend(4)
	await place_target(0, origin + Vector3(-.75, 0, -1.55))
	await place_target(1, origin + Vector3(.75, 0, -1.55))
	await place_target(2, origin + Vector3(0, 0, 1.2))
	await start("light")
	await step(6)
	check(
		"energy windup has no damage",
		targets[0].health.current == 6 and targets[1].health.current == 6
	)
	await step(8)
	await capture("energy_early")
	await step(5)
	await capture("energy_late")
	await until_idle()
	check(
		"wide energy hits multiple targets once",
		targets[0].health.current == 5 and targets[1].health.current == 5
	)
	check("wide energy never hits behind", targets[2].health.current == 6)
	check("wide energy restores one magic per swing", p.magic.current == 1)
	await reset(origin)
	await place_target(0, origin + Vector3(.35, 0, -.55))
	await start("light")
	await until_idle()
	check("physical blade and energy cannot double-hit", targets[0].health.current == 5)
	await reset(origin)
	await place_target(0, origin + Vector3.FORWARD * 3.0)
	await start("light")
	await until_idle()
	check("normal energy respects maximum reach", targets[0].health.current == 6)
	await reset(origin)
	await place_target(0, origin + Vector3.FORWARD * 2.35)
	p.heavy_held = true
	await start("heavy")
	while p.state == "charge" and p.charge_amount < .88:
		await step(1)
	await capture("heavy_charge_pose")
	check(
		"heavy raises sword above the shoulders",
		p.visual.weapon.get_node("BladeTip").global_position.y > p.position.y + .85
	)
	while p.state == "charge" or (p.state == "heavy_attack" and p.action_time < .275):
		await step(1)
	await capture("energy_charged")
	check(
		"charged attack has its own bone clip and impact beat",
		(
			p.visual.current_clip == "heavy_release_charged"
			and p.feedback.heavy_impact_played
			and p.feedback.burst.visible
		)
	)
	await until_idle()
	check(
		"charged energy has greater reach and damage",
		targets[0].health.current == 3,
		targets[0].health.current
	)
	await reset(Vector3(-9.1, 0, -4))
	p.facing = Vector3.LEFT
	p.pivot.rotation.y = PI * .5
	await place_target(0, Vector3(-11, 0, -4))
	await start("light")
	await until_idle()
	check("world geometry blocks extended energy", targets[0].health.current == 6)
	await reset(origin)
	await start("light")
	await step(12)
	var trail := p.visual.weapon.energy_trail
	var mat := trail.material_override as ShaderMaterial
	var color: Color = mat.get_shader_parameter("slash_color")
	check("sunblade slash uses amber palette", color.g > .55 and color.b < .2, color)
	check(
		"visible energy retains horizontal damage radius",
		is_equal_approx(
			(
				Vector2(
					p.visual.weapon.energy_tip.x - p.global_position.x,
					p.visual.weapon.energy_tip.z - p.global_position.z
				)
				. length()
			),
			p.visual.weapon.energy_radius()
		)
	)
	check(
		"ribbon follows actual sword and swept edge instead of a planar fan",
		(
			trail.visible
			and not p.feedback.slash.visible
			and not trail.samples.is_empty()
			and trail.samples.back()[0].is_equal_approx(
				p.visual.weapon.get_node("BladeBase").global_position
			)
			and trail.samples.back()[1].is_equal_approx(
				p.visual.weapon.get_node("BladeTip").global_position
			)
			and trail.samples.back()[2].is_equal_approx(p.visual.weapon.energy_tip)
		)
	)
	p.receive_hit(1, GameClock.next_attack_id(), p.position + Vector3.RIGHT)
	await step(1)
	check(
		"hurt clears energy and trail",
		not trail.visible and trail.samples.is_empty() and not p.visual.weapon.energy_primed
	)
	arena.restart()
	check(
		"restart clears energy and active window",
		not trail.visible and trail.samples.is_empty() and not p.active_window
	)
	var directions: Dictionary = {}
	var poses: Dictionary = {}
	var styles: Dictionary = {}
	var previous_style := ""
	var no_repeat := true
	var stable := true
	var upward := false
	var downward := false
	for i in 24:
		await reset(origin)
		await place_target(0, origin + Vector3.FORWARD * 1.3)
		await start("light")
		var weapon: MeleeWeapon = p.visual.weapon
		var frozen_basis := weapon.swing_basis
		var frozen_direction := weapon.swing_direction
		directions[frozen_direction] = true
		poses[p.visual.current_clip] = true
		var selected_style := String(weapon.swing_style.id)
		styles[selected_style] = true
		no_repeat = no_repeat and selected_style != previous_style
		previous_style = selected_style
		upward = upward or frozen_basis.x.y > .1
		downward = downward or frozen_basis.x.y < -.1
		await step(13)
		stable = (
			stable
			and weapon.swing_basis.is_equal_approx(frozen_basis)
			and weapon.swing_direction == frozen_direction
		)
		check("random swing %d hits forward target once" % i, targets[0].health.current >= 5)
		if i < 4:
			await capture("energy_random_%d" % i)
		await until_idle()
		check("random swing %d finishes with one hit" % i, targets[0].health.current == 5)
	check("random swings use both authored directions", directions.size() == 2)
	check("all six authored blade paths are used", poses.size() == 6, poses.keys())
	check("level rising and falling styles are distinct", styles.size() == 3)
	check("consecutive swings never repeat a style", no_repeat)
	check("random swings include rising and falling diagonals", upward and downward)
	check("random pose stays fixed throughout each swing", stable)
	await reset(origin)
	p.visual.weapon.last_light_direction = 1.0
	p.attacks_started.clear()
	await start("light")
	var chain_directions: Array = []
	var chain_clips: Array = []
	var chain_gap := false
	for i in 6:
		chain_directions.append(p.visual.weapon.swing_direction)
		chain_clips.append(p.visual.current_clip)
		var id: int = p.visual.weapon.attack_id
		if i < 5:
			while p.action_time < p.attack_duration() - p.settings.light_reinput_window + .015:
				await step(1)
			p.request_action("light")
			var guard := 0
			while p.visual.weapon.attack_id == id and guard < 120:
				await step(1)
				chain_gap = chain_gap or p.state == "locomotion"
				guard += 1
	await until_idle()
	check(
		"six-click chain alternates across third strike",
		chain_directions == [-1.0, 1.0, -1.0, 1.0, -1.0, 1.0],
		chain_directions
	)
	check("six-click chain has no idle gap", not chain_gap)
	check(
		"reverse finisher uses the authored rightward style",
		String(chain_clips.back()).ends_with("_right"),
		chain_clips
	)
	await step(60)
	check("chain stops when clicks stop", p.state == "locomotion" and p.attacks_started.size() == 6)
	await reset(origin)
	p.attacks_started.clear()
	await start("light")
	for i in 4:
		await step(3)
		p.request_action("light")
	await until_idle()
	await step(80)
	check(
		"spam during a swing never queues follow-ups",
		p.attacks_started.size() == 1,
		p.attacks_started
	)
	await reset(origin)
	await start("light")
	while p.action_time < p.attack_duration() - p.settings.light_reinput_window + .015:
		await step(1)
	var previous_id: int = p.visual.weapon.attack_id
	p.request_action("light")
	await step(1)
	check(
		"late fresh click starts immediately",
		p.visual.weapon.attack_id != previous_id and p.action_time < .02
	)
	p.receive_hit(1, GameClock.next_attack_id(), p.position + Vector3.RIGHT)
	await step(1)
	check("hurt interrupts immediate follow-up", not p.light_link_requested and p.state == "hurt")
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
		. open(
			"res://captures/lantern_village/energy_checks_%d.json" % render_cap, FileAccess.WRITE
		)
		. store_string(JSON.stringify(report, "\t"))
	)
	print("ENERGY_REPLAY_FINISHED ", failures, " failures; ", results.size(), " checks")
	get_tree().quit(1 if failures else 0)
