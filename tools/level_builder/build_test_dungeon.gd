extends Node
## Builds a small walkable test dungeon with the level builder factory:
## an outdoor entrance with a Drempelpoort, a hall, a corridor and a treasure room,
## all connected by LevelDoors through the normal SceneTransit.
## Run as a scene so autoloads exist:
## Godot --headless --path . res://tools/level_builder/BuildTestDungeon.tscn
const FACTORY := preload("res://addons/level_builder/level_factory.gd")
const ENTRANCE := "res://scenes/levels/TestDungeonIngang.tscn"
const HALL := "res://scenes/levels/TestDungeonHal.tscn"
const CORRIDOR := "res://scenes/levels/TestDungeonGang.tscn"
const TREASURE := "res://scenes/levels/TestDungeonSchatkamer.tscn"
const DEFINITION := "res://settings/dungeons/test_dungeon.tres"


func _ready() -> void:
	var cave := load("res://settings/area_sets/cave.tres") as AreaSet
	var forest := load("res://settings/area_sets/forest.tres") as AreaSet
	var dungeon := DungeonDefinition.new()
	dungeon.id = &"test_dungeon"
	dungeon.display_name = "Testkelder"
	dungeon.scene_path = HALL
	dungeon.entrance = &"DungeonEntrance"
	_check(ResourceSaver.save(dungeon, DEFINITION, ResourceSaver.FLAG_CHANGE_PATH), DEFINITION)
	dungeon.take_over_path(DEFINITION)

	# Outdoor entrance: a clearing with the gate to the dungeon.
	var outside := FACTORY.create(forest, _area("ingang", "Testkelder ingang", ENTRANCE), Vector2(20, 16))
	var gate: Node3D = load("res://scenes/world/dungeons/Drempelpoort.tscn").instantiate()
	gate.name = "Drempelpoort"
	outside.get_node("Gameplay").add_child(gate)
	gate.owner = outside
	gate.position = Vector3(0, 0, -4)
	gate.set("dungeon", dungeon)
	gate.set("gate_id", &"test_dungeon.ingang")
	gate.set("identity_scene", ENTRANCE)
	FACTORY.own(outside, outside)
	_save(outside, ENTRANCE)

	# Hall: dungeon arrival and exit; a door east into the corridor.
	var hall := FACTORY.create_room("dungeon", cave, _area("hal", "Testkelder hal", HALL), Vector2(16, 14), dungeon)
	FACTORY.add_door(hall.get_node("Terrain"), hall, 1, 0, &"HallOost", CORRIDOR, &"GangWest")
	_rocks(hall, [Vector3(-5, 0, -4), Vector3(5, 0, -4.5)])
	_save(hall, HALL)

	# Corridor: back west to the hall, north into the treasure room.
	var corridor := FACTORY.create_room("interior", cave, _area("gang", "Testkelder gang", CORRIDOR), Vector2(20, 8))
	var corridor_ground := corridor.get_node("Terrain") as LevelTerrain
	FACTORY.add_door(corridor_ground, corridor, 3, 0, &"GangWest", HALL, &"HallOost", LevelDoor.Style.STONE_ARCH)
	FACTORY.add_door(corridor_ground, corridor, 0, 5, &"GangNoord", TREASURE, &"SchatZuid", LevelDoor.Style.STONE_ARCH)
	_arrive_at(corridor, &"GangWest")
	_save(corridor, CORRIDOR)

	# Treasure room: back south to the corridor.
	var treasure := FACTORY.create_room("interior", cave, _area("schatkamer", "Testkelder schatkamer", TREASURE), Vector2(10, 10))
	FACTORY.add_door(treasure.get_node("Terrain"), treasure, 2, 0, &"SchatZuid", CORRIDOR, &"GangNoord", LevelDoor.Style.STONE_ARCH)
	_rocks(treasure, [Vector3(-3, 0, -3), Vector3(3, 0, -2.5)])
	_arrive_at(treasure, &"SchatZuid")
	_save(treasure, TREASURE)
	print("TEST_DUNGEON_OK")
	get_tree().quit()


func _area(key: String, title: String, scene: String) -> WorldArea:
	var area := WorldArea.new()
	area.code = StringName("area.test_dungeon." + key)
	area.display_name = title
	area.scene_path = scene
	var path := "res://settings/areas/test_dungeon_" + key + ".tres"
	_check(ResourceSaver.save(area, path, ResourceSaver.FLAG_CHANGE_PATH), path)
	area.take_over_path(path)
	return area


## Rooms entered through a door start (in the editor and on F6) at that door.
func _arrive_at(root: Node3D, door_id: StringName) -> void:
	var door := root.get_node("Terrain/" + String(door_id)) as LevelDoor
	var arrival := door.get_node("Arrival") as Node3D
	var at: Vector3 = door.transform * arrival.position
	root.set("spawn_position", at)
	root.get_node("Player").position = at
	root.get_node("Spawns/Entrance").position = at
	root.get_node("Spawns/StartCheckpoint").position = at


func _rocks(root: Node3D, positions: Array) -> void:
	var asset := load("res://settings/level_assets/rock_cluster.tres") as LevelAsset
	if asset == null or asset.scene == null:
		return
	for i in positions.size():
		var rock: Node3D = asset.scene.instantiate()
		rock.name = "Rots%d" % i
		root.get_node("Props").add_child(rock)
		rock.owner = root
		rock.position = positions[i]


func _save(root: Node, path: String) -> void:
	_check(FACTORY.save(root, path), path)
	root.free()


func _check(error: Error, what: String) -> void:
	if error != OK:
		push_error("TEST_DUNGEON_FAILED %s: %s" % [what, error_string(error)])
		get_tree().quit(1)
