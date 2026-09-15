extends Node
## Builds a small walkable test house with the level builder factory:
## an outdoor clearing with a cottage, and inside a living room, kitchen and bedroom.
## The front door lets daylight in; the doors between rooms do not.
## Run as a scene so autoloads exist:
## Godot --headless --path . res://tools/level_builder/BuildTestHouse.tscn
const FACTORY := preload("res://addons/level_builder/level_factory.gd")
const OUTSIDE := "res://scenes/levels/TestHuisBuiten.tscn"
const LIVING := "res://scenes/levels/TestHuisWoonkamer.tscn"
const KITCHEN := "res://scenes/levels/TestHuisKeuken.tscn"
const BEDROOM := "res://scenes/levels/TestHuisSlaapkamer.tscn"


func _ready() -> void:
	var forest := load("res://settings/area_sets/forest.tres") as AreaSet
	var interior := load("res://settings/area_sets/interior.tres") as AreaSet

	# Outside: a clearing with the cottage; its front door leads into the living room.
	var outside := FACTORY.create(forest, _area("buiten", "Testhuis buiten", OUTSIDE), Vector2(24, 20))
	var cottage_asset := load("res://settings/level_assets/cottage.tres") as LevelAsset
	var cottage: Node3D = cottage_asset.scene.instantiate()
	cottage.name = "Huisje"
	outside.get_node("Props").add_child(cottage)
	cottage.position = Vector3(0, 0, -6)
	cottage.rotation_degrees.y = 180
	cottage.scale = Vector3.ONE * 1.35
	var front := LevelDoor.new()
	front.name = "Voordeur"
	front.style = LevelDoor.Style.OPENING
	front.collision_layer = 0
	front.collision_mask = 2
	front.door_id = &"Voordeur"
	front.target_scene = LIVING
	front.target_spawn = &"WoonkamerZuid"
	front.settings = load("res://settings/transitions/door.tres")
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.resource_local_to_scene = true
	shape.shape = box
	front.add_child(shape)
	var arrival := SceneSpawnPoint.new()
	arrival.name = "Arrival"
	arrival.spawn_id = &"Voordeur"
	arrival.position = Vector3(0, 0, LevelDoor.ARRIVAL_DEPTH)
	arrival.rotation_degrees.y = 180
	front.add_child(arrival)
	front.width = 2.0
	front.position = Vector3(0, 0, -3.5)
	outside.get_node("Gameplay").add_child(front)
	_player_at(outside, Vector3(0, 0, 3))
	FACTORY.own(outside, outside)
	_save(outside, OUTSIDE)

	# Living room: daylight through the front door (south), kitchen east, bedroom north.
	var living := FACTORY.create_room("interior", interior, _area("woonkamer", "Testhuis woonkamer", LIVING), Vector2(12, 10))
	var living_ground := living.get_node("Terrain") as LevelTerrain
	var front_back := FACTORY.add_door(living_ground, living, 2, 0, &"WoonkamerZuid", OUTSIDE, &"Voordeur")
	front_back.outside_light = true
	FACTORY.add_door(living_ground, living, 1, 0, &"WoonkamerOost", KITCHEN, &"KeukenWest")
	FACTORY.add_door(living_ground, living, 0, 3, &"WoonkamerNoord", BEDROOM, &"SlaapkamerZuid")
	_props(living, "barrel", [Vector3(-4.8, 0, -3.8), Vector3(-4, 0, -4)])
	FACTORY.start_at_door(living, &"WoonkamerZuid")
	_save(living, LIVING)

	# Kitchen: back west to the living room.
	var kitchen := FACTORY.create_room("interior", interior, _area("keuken", "Testhuis keuken", KITCHEN), Vector2(8, 8))
	FACTORY.add_door(kitchen.get_node("Terrain"), kitchen, 3, 0, &"KeukenWest", LIVING, &"WoonkamerOost")
	_props(kitchen, "barrel", [Vector3(2.8, 0, -2.8)])
	FACTORY.start_at_door(kitchen, &"KeukenWest")
	_save(kitchen, KITCHEN)

	# Bedroom: back south to the living room.
	var bedroom := FACTORY.create_room("interior", interior, _area("slaapkamer", "Testhuis slaapkamer", BEDROOM), Vector2(10, 8))
	FACTORY.add_door(bedroom.get_node("Terrain"), bedroom, 2, 0, &"SlaapkamerZuid", LIVING, &"WoonkamerNoord")
	FACTORY.start_at_door(bedroom, &"SlaapkamerZuid")
	_save(bedroom, BEDROOM)
	print("TEST_HOUSE_OK")
	get_tree().quit()


func _area(key: String, title: String, scene: String) -> WorldArea:
	var area := WorldArea.new()
	area.code = StringName("area.test_house." + key)
	area.display_name = title
	area.scene_path = scene
	var path := "res://settings/areas/test_house_" + key + ".tres"
	_check(ResourceSaver.save(area, path, ResourceSaver.FLAG_CHANGE_PATH), path)
	area.take_over_path(path)
	return area


func _player_at(root: Node3D, at: Vector3) -> void:
	root.set("spawn_position", at)
	for path in ["Player", "Spawns/Entrance", "Spawns/StartCheckpoint"]:
		var node := root.get_node_or_null(path) as Node3D
		if node:
			node.position = at


func _props(root: Node3D, id: String, positions: Array) -> void:
	var asset := load("res://settings/level_assets/%s.tres" % id) as LevelAsset
	if asset == null or asset.scene == null:
		return
	for i in positions.size():
		var prop: Node3D = asset.scene.instantiate()
		prop.name = "%s%d" % [id.capitalize(), i]
		root.get_node("Props").add_child(prop)
		prop.owner = root
		prop.position = positions[i]


func _save(root: Node, path: String) -> void:
	_check(FACTORY.save(root, path), path)
	root.free()


func _check(error: Error, what: String) -> void:
	if error != OK:
		push_error("TEST_HOUSE_FAILED %s: %s" % [what, error_string(error)])
		get_tree().quit(1)
