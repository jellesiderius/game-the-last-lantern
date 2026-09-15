extends "res://tests/test_dungeon_replay.gd"
## Walks the real player through the generated test house with SceneTransit:
## outside -> living room -> kitchen -> living room -> bedroom -> living room -> outside.


func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://captures/level_builder")
	initial_frames = Engine.get_frames_drawn()
	GameProgress.ensure_preview()
	GameProgress.active_slot = 0
	await load_world("res://scenes/levels/TestHuisBuiten.tscn")
	var front := get_tree().current_scene.get_node("Gameplay/Voordeur") as Node3D
	await _travel("front door into the living room", front.global_position, "TestHuisWoonkamer", &"WoonkamerZuid")
	var scene := get_tree().current_scene
	check(
		"daylight falls in only through the front door",
		scene.has_node("Terrain/WoonkamerZuid/Frame/Sunbeam")
		and not scene.has_node("Terrain/WoonkamerOost/Frame/Sunbeam")
		and not scene.has_node("Terrain/WoonkamerNoord/Frame/Sunbeam")
	)
	await _travel("living room east door into the kitchen", _door("WoonkamerOost"), "TestHuisKeuken", &"KeukenWest")
	await _travel("kitchen back to the living room", _door("KeukenWest"), "TestHuisWoonkamer", &"WoonkamerOost")
	await _travel("living room north door into the bedroom", _door("WoonkamerNoord"), "TestHuisSlaapkamer", &"SlaapkamerZuid")
	await _travel("bedroom back to the living room", _door("SlaapkamerZuid"), "TestHuisWoonkamer", &"WoonkamerNoord")
	await _travel("front door back outside", _door("WoonkamerZuid"), "TestHuisBuiten", &"Voordeur")
	_finish("test_house_walkthrough")
