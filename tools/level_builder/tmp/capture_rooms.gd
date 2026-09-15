extends Node
## Temporary: gameplay-camera screenshots of generated test scenes.


func _ready() -> void:
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://captures/level_builder")
	get_tree().root.size = Vector2i(1280, 800)
	for scene_name in ["TestHuisWoonkamer", "TestHuisKeuken", "TestHuisSlaapkamer", "ForestHouse"]:
		var previous := get_tree().current_scene
		if previous:
			get_tree().root.remove_child(previous)
			previous.queue_free()
		var world: Node = load("res://scenes/levels/%s.tscn" % scene_name).instantiate()
		get_tree().root.add_child(world)
		get_tree().current_scene = world
		for i in 60:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://captures/level_builder/room_%s.png" % scene_name)
		print("ROOM saved ", scene_name)
	get_tree().quit()
