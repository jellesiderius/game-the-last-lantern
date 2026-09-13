extends Node3D
## F6 is a saved gallery. CLI captures the imported assets at native resolution.


func _ready() -> void:
	if "--forest-asset-review" in OS.get_cmdline_user_args():
		capture_assets.call_deferred()


func capture_assets() -> void:
	get_window().size = Vector2i(800, 800)
	get_window().position = Vector2i(100, 80)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_window().grab_focus()
	Engine.max_fps = 60
	var started := Engine.get_frames_drawn()
	for root: Node3D in $Assets.get_children():
		root.set_physics_process(false)
		root.hide()
	for root: Node3D in $Assets.get_children():
		var old := root.position
		root.position = Vector3.ZERO
		root.show()
		var bounds := AABB()
		var first := true
		for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			var box := mesh.global_transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		$Floor.position.y = bounds.position.y - .01
		var center := bounds.get_center()
		$Camera3D.size = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) * 1.35
		for pair in [["front", Vector3(0, .9, -6)], ["game", Vector3(4, 5, 4)]]:
			$Camera3D.position = center + pair[1]
			$Camera3D.look_at(center)
			for i in 20:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var folder := "res://captures/forest/native_assets/" + root.name
			DirAccess.make_dir_recursive_absolute(folder)
			get_viewport().get_texture().get_image().save_png(folder + "/" + pair[0] + ".png")
		root.hide()
		root.position = old
	(
		FileAccess
		. open("res://captures/forest/native_assets/render.json", FileAccess.WRITE)
		. store_string(
			JSON.stringify(
				{
					"renderer": RenderingServer.get_current_rendering_method(),
					"frames": Engine.get_frames_drawn() - started,
					"viewport": get_viewport().get_visible_rect().size
				},
				"\t"
			)
		)
	)
	get_tree().quit()
