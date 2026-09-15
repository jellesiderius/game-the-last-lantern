extends "res://tests/level_builder_replay.gd"
## Walks the real player through the generated test dungeon with SceneTransit:
## entrance -> gate -> hall -> corridor -> treasure room -> corridor -> hall -> exit.


func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://captures/level_builder")
	initial_frames = Engine.get_frames_drawn()
	GameProgress.ensure_preview()
	GameProgress.active_slot = 0
	await load_world("res://scenes/levels/TestDungeonIngang.tscn")
	var gate := get_tree().current_scene.get_node("Gameplay/Drempelpoort") as Node3D
	await _travel("gate into the hall", gate.global_position, "TestDungeonHal", &"DungeonEntrance")
	await _travel("hall east door into the corridor", _door("HallOost"), "TestDungeonGang", &"GangWest")
	await _travel("corridor north door into the treasure room", _door("GangNoord"), "TestDungeonSchatkamer", &"SchatZuid")
	await _travel("treasure room back to the corridor", _door("SchatZuid"), "TestDungeonGang", &"GangNoord")
	await _travel("corridor back to the hall", _door("GangWest"), "TestDungeonHal", &"HallOost")
	var exit := get_tree().current_scene.get_node("Gameplay/Uitgang") as Node3D
	await _travel("hall exit back outside", exit.global_position, "TestDungeonIngang", &"")
	_finish("test_dungeon_walkthrough")


func _door(door_name: String) -> Vector3:
	return (get_tree().current_scene.get_node("Terrain/" + door_name) as Node3D).global_position


## Steers the player into a portal, waits for the scene change and checks the arrival.
func _travel(label: String, target: Vector3, scene_name: String, arrival_id: StringName) -> void:
	var player: CharacterBody3D = GameSession.player
	player.use_test_input = true
	var started := false
	for tick in int(12.0 * Engine.physics_ticks_per_second):
		if SceneTransit.active:
			started = true
			break
		var offset := Vector3(target.x - player.global_position.x, 0, target.z - player.global_position.z)
		player.test_input = _world_input(offset.normalized()) if offset.length() > .05 else Vector2.ZERO
		await frames(1)
	player.test_input = Vector2.ZERO
	check(label + ": walking in starts the transition", started, player.global_position)
	for tick in int(12.0 * Engine.physics_ticks_per_second):
		if not SceneTransit.active:
			break
		await frames(1)
	await frames(30)
	var scene := get_tree().current_scene
	check(label + ": arrives in " + scene_name, scene != null and scene.scene_file_path.get_file().get_basename() == scene_name, scene.scene_file_path if scene else null)
	world = scene
	var arrived: CharacterBody3D = GameSession.player
	arrived.use_test_input = true
	if scene.has_node("HUD"):
		scene.get_node("HUD").set_process_input(false)
	if arrival_id.is_empty():
		return
	var marker: Node3D
	for node in get_tree().get_nodes_in_group("scene_spawn_points"):
		if node is SceneSpawnPoint and node.spawn_key() == arrival_id and scene.is_ancestor_of(node):
			marker = node
	check(
		label + ": stands at the " + String(arrival_id) + " arrival",
		marker != null and Vector2(arrived.global_position.x - marker.global_position.x, arrived.global_position.z - marker.global_position.z).length() < 2.2,
		[arrived.global_position, marker.global_position if marker else null]
	)
	check(label + ": player stays on the floor", arrived.global_position.y > -.5, arrived.global_position)
