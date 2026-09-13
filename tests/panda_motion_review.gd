extends "res://tests/runtime_replay.gd"
## Repeatable current-source poses in the real Forward+ room, independent of live input.
var output := "res://captures/panda_motion/after"


func capture_pose(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output + "/" + label + ".png")


func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	if "--motion-baseline" in OS.get_cmdline_user_args():
		output = "res://.dream-loop/panda-motion/before"
	DirAccess.make_dir_recursive_absolute(output)
	await reset(Vector3(0, 0, 5))
	for target in targets:
		target.hide()
	if "--motion-video" in OS.get_cmdline_user_args():
		await record_motion()
		get_tree().quit()
		return
	await step(12)
	await capture_pose("game")
	p.set_physics_process(false)
	arena.set_physics_process(false)
	var camera := get_viewport().get_camera_3d()
	var center := p.global_position + Vector3(0, .48, 0)
	camera.size = 1.9
	for view in ["front", "left", "right", "back", "game"]:
		var offset: Vector3 = {
			"front": Vector3(0, .3, -4),
			"left": Vector3(4, .3, 0),
			"right": Vector3(-4, .3, 0),
			"back": Vector3(0, .3, 4),
			"game": Vector3(3, 4, 3)
		}[view]
		camera.global_position = center + offset
		camera.look_at(center)
		for pair in [
			["idle", 0.0], ["walk", p.settings.walk_blend_speed], ["run", p.settings.max_speed]
		]:
			p.visual.reset_visual()
			for i in 8:
				if p.visual.synchronize_gait_phase:
					p.visual.gait_phase = float(i) / 8.0
					p.visual.idle_time = float(i) / 8.0 * 2.4
					p.visual.sample("", 0, pair[1], 0)
				else:
					p.visual.sample("", 0, pair[1], .065)
				await capture_pose(view + "_" + pair[0] + "_" + str(i))
	var frames := Engine.get_frames_drawn() - initial_render_frame
	FileAccess.open(output + "/render.json", FileAccess.WRITE).store_string(
		JSON.stringify(
			{"render_frames": frames, "renderer": RenderingServer.get_current_rendering_method()},
			"\t"
		)
	)
	print("PANDA_MOTION_REVIEW ", frames)
	get_tree().quit()


func record_motion() -> void:
	output = "res://captures/panda_motion/video_frames"
	DirAccess.make_dir_recursive_absolute(output)
	var camera := get_viewport().get_camera_3d()
	var captures := 0
	var started := Time.get_ticks_msec()
	var render_start := Engine.get_frames_drawn()
	# Native physics/input/action paths, rendered at 60 Hz. Different speeds and stops.
	for segment in 8:
		await reset(Vector3(-4, 0, 6))
		arena.reset_camera()
		arena.set_physics_process(false)
		camera.size = 3.4
		var speed: float = [0.0, .133333, .45, 1.0, 1.0, 0.0, .133333, 1.0][segment]
		for frame in 100:
			p.test_input = Vector2.RIGHT * speed if frame < 75 else Vector2.ZERO
			if segment == 4 and frame == 40:
				speed = -1.0
			if segment == 5 and frame in [8, 38, 68]:
				p.request_action("light")
			if segment == 6 and frame == 20:
				p.heavy_held = true
				p.request_action("heavy")
			if segment == 7 and frame == 22:
				p.request_action("dodge")
			await step(2)
			var center := p.global_position + Vector3(0, .48, 0)
			camera.global_position = center + Vector3(2.8, 1.5, 4)
			camera.look_at(center)
			if "--movie-capture" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
			else:
				await capture_pose("frame_%04d" % captures)
			captures += 1
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	FileAccess.open("res://captures/panda_motion/video_render.json", FileAccess.WRITE).store_string(
		JSON.stringify(
			{
				"frames": captures,
				"render_frames": Engine.get_frames_drawn() - render_start,
				"seconds": seconds,
				"observed_render_fps": (Engine.get_frames_drawn() - render_start) / seconds
			},
			"\t"
		)
	)
