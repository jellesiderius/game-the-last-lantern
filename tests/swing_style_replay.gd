extends "res://tests/room_replay.gd"
## Every authored path must preserve reach and change the actual blade's height.


func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	render_cap = Engine.max_fps
	var weapon: MeleeWeapon = p.visual.weapon
	weapon.definition = weapon.definition.duplicate()
	var styles := weapon.definition.light_swing_styles.duplicate()
	var camera := get_viewport().get_camera_3d()
	var original_size := camera.size
	# Closer presentation in this replay only; same camera angle as gameplay.
	if "--style-closeup" in OS.get_cmdline_user_args():
		camera.size = 5.5
	var origin := Vector3(0, 0, -3)
	for style: MeleeSwingStyle in styles:
		for direction in [-1.0, 1.0]:
			await reset(origin)
			weapon.definition.light_swing_styles.assign([style])
			weapon.last_light_direction = -direction
			await place_target(0, origin + Vector3.FORWARD * 1.85)
			await place_target(1, origin + Vector3(-.75, 0, -1.55))
			await place_target(2, origin + Vector3(.75, 0, -1.55))
			var label := String(style.id) + ("_left" if direction < 0 else "_right")
			await start("light")
			check(
				label + " imported authored clip",
				p.visual.animation_player.has_animation(weapon.swing_visual_clip)
			)
			check(label + " selected bone clip", p.visual.current_clip == weapon.swing_visual_clip)
			check(label + " radius unchanged", is_equal_approx(weapon.energy_radius(), 1.9))
			var reach_preserved := true
			var above_ground := true
			for phase in [0.0, .25, .5, .75, 1.0]:
				var point := weapon.energy_local_point(
					weapon.energy_angle(phase), weapon.energy_radius()
				)
				reach_preserved = (
					reach_preserved and absf(Vector2(point.x, point.z).length() - 1.9) < .001
				)
				above_ground = above_ground and point.y + weapon.energy_height() > 0.0
			check(label + " horizontal reach unchanged along arc", reach_preserved)
			check(label + " shallow arc stays above ground", above_ground)
			await step(9)
			var skeleton := p.visual.skeleton
			var torso_index := skeleton.find_bone("torso")
			var pelvis_index := skeleton.find_bone("pelvis")
			var head_index := skeleton.find_bone("head")
			var torso_begin := (
				skeleton.get_bone_global_pose(torso_index).basis.get_rotation_quaternion()
			)
			var pelvis_begin := (
				skeleton.get_bone_global_pose(pelvis_index).basis.get_rotation_quaternion()
			)
			var head_begin := (
				skeleton.get_bone_global_pose(head_index).basis.get_rotation_quaternion()
			)
			var begin_time := p.action_time
			var begin: Vector3 = weapon.get_node("BladeTip").global_position - p.global_position
			await capture("style_" + label + "_start")
			# Use action time rather than render counts, including slow display caps.
			while p.action_time < .17:
				await step(1)
			var end: Vector3 = weapon.get_node("BladeTip").global_position - p.global_position
			var rise := end.y - begin.y
			var torso_turn := torso_begin.angle_to(
				skeleton.get_bone_global_pose(torso_index).basis.get_rotation_quaternion()
			)
			var hip_turn := pelvis_begin.angle_to(
				skeleton.get_bone_global_pose(pelvis_index).basis.get_rotation_quaternion()
			)
			var head_turn := head_begin.angle_to(
				skeleton.get_bone_global_pose(head_index).basis.get_rotation_quaternion()
			)
			check(
				label + " body follows the blade",
				torso_turn > 0.9 and hip_turn > 0.25 and head_turn > 0.7,
				[torso_turn, hip_turn, head_turn]
			)
			check(
				label + " actual blade slope",
				(
					absf(rise) < .07
					if style.slope_degrees == 0
					else rise * signf(style.slope_degrees) > .20
				),
				{
					"rise": rise,
					"start": begin_time,
					"end": p.action_time,
					"begin": begin,
					"finish": end
				}
			)
			check(label + " actual blade follows direction", (end.x - begin.x) * direction > .3)
			await capture("style_" + label + "_end")
			await until_idle()
			check(
				label + " retains forward hit distance",
				targets[0].health.current == 5,
				targets[0].health.current
			)
			check(
				label + " retains multi-target width",
				targets[1].health.current == 5 and targets[2].health.current == 5,
				[targets[1].health.current, targets[2].health.current]
			)
			await step(35)
	weapon.definition.light_swing_styles.assign(styles)
	camera.size = original_size
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
		. open("res://captures/lantern_village/swing_styles_%d.json" % render_cap, FileAccess.WRITE)
		. store_string(JSON.stringify(report, "\t"))
	)
	print("SWING_STYLE_REPLAY_FINISHED ", failures, " failures; ", results.size(), " checks")
	get_tree().quit(1 if failures else 0)
