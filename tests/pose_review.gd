extends "res://tests/runtime_replay.gd"


## Technical pose contact sheets from the actual imported skeleton and material overrides.
func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	await reset(Vector3(0, 0, -3) if "spawn_position" in arena else Vector3(0, 0, 3))
	p.set_physics_process(false)
	arena.set_physics_process(false)
	arena.get_node("HUD").hide()
	GameClock.paused = true
	var camera := get_viewport().get_camera_3d()
	var game_back := camera.global_basis.z
	camera.size = 2.5
	var clips := p.visual.animation_player.get_animation_list()
	var rows := ceili(clips.size() / 3.0)
	var overlays := CanvasLayer.new()
	add_child(overlays)
	var label := Label.new()
	label.position = Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 42)
	overlays.add_child(label)
	var folder := "res://captures/pose_review/" + String(p.definition.id)
	DirAccess.make_dir_recursive_absolute(folder)
	for view in ["front", "side", "back", "left", "game"]:
		var sheet := Image.create(1152, 240 * rows, false, Image.FORMAT_RGB8)
		for i in clips.size():
			var action: String = clips[i]
			var anim := p.visual.animation_player.get_animation(action)
			var time := anim.length * .5
			if action.begins_with("heavy_release"):
				time = .265
			if action == "death":
				time = anim.length
			p.visual.stowed = not (
				action.begins_with("attack")
				or action.begins_with("heavy")
				or action == "roll_attack"
			)
			p.visual.sample(action, time, 0, 0)
			var bow_active := action.begins_with("bow_") and action != "bow_empty"
			p.visual.set_bow_mode(bow_active)
			if action == "neutral":
				p.visual.weapon.hide()
			if bow_active:
				p.visual.bow.present(
					p.visual.draw_socket.global_position,
					action in ["bow_draw", "bow_hold"],
					false,
					time
				)
			var offset: Vector3 = {
				"front": Vector3(0, .8, -4),
				"side": Vector3(4, .8, 0),
				"back": Vector3(0, .8, 2),
				"left": Vector3(-4, .8, 0),
				"game": game_back * 4.0 + Vector3.UP * .75,
			}[view]
			camera.global_position = p.global_position + offset
			camera.look_at(p.global_position + Vector3(0, .75, 0))
			label.text = action + " · " + view
			await RenderingServer.frame_post_draw
			var screenshot := get_viewport().get_texture().get_image()
			screenshot.save_png(folder + "/" + action + "_" + view + ".png")
			screenshot.resize(384, 240, Image.INTERPOLATE_LANCZOS)
			screenshot.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(
				screenshot, Rect2i(0, 0, 384, 240), Vector2i((i % 3) * 384, (i / 3) * 240)
			)
		sheet.save_png(folder + "/contact_" + view + ".png")
	get_tree().quit()
