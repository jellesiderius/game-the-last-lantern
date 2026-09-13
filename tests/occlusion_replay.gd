extends "res://tests/runtime_replay.gd"
## Saved opaque geometry covers player, skinned NPC and friendly dummy together.


func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/occlusion/" + label + ".png")


func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	DirAccess.make_dir_recursive_absolute("res://captures/occlusion")
	await reset(Vector3(-1.5, 0, 5))
	for target in targets:
		target.hide()
	var npc = targets.filter(func(t): return t.brain != null)[0]
	var dummy = targets.filter(func(t): return t.brain == null)[0]
	npc.position = Vector3(0, 0, 5)
	dummy.position = Vector3(1.5, 0, 5)
	npc.show()
	dummy.show()
	p.set_physics_process(false)
	arena.set_physics_process(false)
	var camera := get_viewport().get_camera_3d()
	camera.size = 5.8
	camera.global_position = Vector3(0, 3.1, 11)
	camera.look_at(Vector3(0, .6, 5))
	var wall := arena.get_node("OcclusionReviewWall") as MeshInstance3D
	await capture("fully_hidden")
	wall.position.x = 2.8
	await capture("partly_hidden")
	wall.hide()
	await capture("clear")
	p.visual.show_damage_protection(.55, .6)
	npc.flash = .1
	await capture("clear_hit_feedback")
	wall.show()
	wall.position.x = 0
	p.visual.sample("dodge_roll", .19, 0, 0)
	await capture("hidden_roll")
	var rendered := Engine.get_frames_drawn() - initial_render_frame
	FileAccess.open("res://captures/occlusion/render.json", FileAccess.WRITE).store_string(
		JSON.stringify(
			{
				"frames": rendered,
				"renderer": RenderingServer.get_current_rendering_method(),
				"player": p.definition.id,
				"npc": npc.name,
				"friendly": dummy.name,
				"silhouette_color": OcclusionSilhouette.STYLE.stencil_color.to_html(false)
			},
			"\t"
		)
	)
	print("OCCLUSION_REVIEW ", rendered)
	get_tree().quit()
