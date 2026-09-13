extends "res://tests/room_replay.gd"
## A clean native-camera recording of the entrance and first approach.


func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://captures/forest")
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	p.use_test_input = true
	arena.get_node("HUD").set_process_input(false)
	var frames := Engine.get_frames_drawn()
	await step(150)
	await shot("seated")
	await step(132)
	await shot("rising")
	await step(50)
	await shot("jump")
	while p.state == "entrance":
		await step(1)
	await step(80)
	await shot("landed")
	for waypoint in [
		Vector3(-1, 0, 6),
		Vector3(.2, 0, 2),
		Vector3(-1.5, 0, -.4),
		Vector3(-2.8, 0, -2.8),
		Vector3(-3, 0, -5.5),
		Vector3(-1.5, 0, -7.8),
		Vector3(1.6, 0, -8.5),
		Vector3(4, 0, -10)
	]:
		for i in 360:
			var direction: Vector3 = waypoint - p.position
			direction.y = 0
			if direction.length() < .22:
				break
			p.test_input = world_input(direction.normalized())
			await step(1)
	p.test_input = Vector2.ZERO
	await shot("guard_approach")
	await step(180)
	await shot("guard_attack")
	print("FOREST_PREVIEW_DRAWN_FRAMES ", Engine.get_frames_drawn() - frames)
	get_tree().quit()


func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		"res://captures/forest/preview_" + label + ".png"
	)
