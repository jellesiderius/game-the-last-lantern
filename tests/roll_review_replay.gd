extends "res://tests/room_replay.gd"
## Slow-motion roll review: the whole game runs at 20% speed while the roll crosses the
## screen; every fourth rendered frame is cropped around the player into one sheet.


func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	var camera := get_viewport().get_camera_3d()
	camera.size = 4.0
	await reset(Vector3(-1, 0, 4))
	var side := p.move_direction(Vector2.RIGHT).normalized()
	p.facing = side
	p.pivot.rotation.y = atan2(-side.x, -side.z)
	await step(30)
	p.test_input = Vector2.RIGHT
	Engine.time_scale = .2
	await start("dodge")
	var size := 320
	var columns := 6
	var frames: Array[Image] = []
	var times: Array = []
	var rendered := 0
	# Keep sampling briefly after the roll so the return to idle is reviewed too.
	var after := 0
	while (p.state == "roll" or after < 8) and frames.size() < 54:
		if p.state != "roll":
			after += 1
		await RenderingServer.frame_post_draw
		rendered += 1
		if rendered % 4 != 1:
			continue
		var image := get_viewport().get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		var center := camera.unproject_position(p.global_position + Vector3.UP * .4)
		var rect := Rect2i(int(center.x) - size / 2, int(center.y) - size / 2, size, size)
		rect = rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
		var cell := Image.create(size, size, false, Image.FORMAT_RGBA8)
		cell.blit_rect(image, rect, Vector2i.ZERO)
		frames.append(cell)
		times.append(snappedf(p.action_time, .001))
	Engine.time_scale = 1.0
	p.test_input = Vector2.ZERO
	var sheet := Image.create(
		size * columns, size * ceili(frames.size() / float(columns)), false, Image.FORMAT_RGBA8
	)
	for i in frames.size():
		sheet.blit_rect(
			frames[i], Rect2i(Vector2i.ZERO, frames[i].get_size()), Vector2i(i % columns, i / columns) * size
		)
	sheet.save_png("res://captures/roll_review/roll_sheet.png")
	print("ROLL_REVIEW_TIMES ", times)
	print("ROLL_REVIEW_FINISHED ", frames.size())
	get_tree().quit(0)
