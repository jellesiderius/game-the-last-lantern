extends Node
## Temporary: fresh bake of the forest opening, looking at the authored stairs.


func _ready() -> void:
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://captures/level_builder")
	get_tree().root.size = Vector2i(1280, 800)
	var previous := get_tree().current_scene
	if previous:
		get_tree().root.remove_child(previous)
		previous.queue_free()
	var world: Node = load("res://scenes/levels/BosOpening.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	var terrain := world.get_node("Terrain") as LevelTerrain
	terrain.baked_signature = ""
	print("BAKE ", terrain.bake(), " ", terrain.last_error)
	for i in 30:
		await get_tree().process_frame
	var player: Node3D = world.get("player")
	for spot in [["trap2_foot", Vector3(-9.5, 0, -27.3)]]:
		player.set("state", "locomotion")
		player.global_position = spot[1] + Vector3(0, 6, 0)
		player.set_physics_process(false)
		world.call("reset_camera")
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://captures/level_builder/stairs_%s.png" % spot[0])
		print("LOOK ", spot[0])
	get_tree().quit()
