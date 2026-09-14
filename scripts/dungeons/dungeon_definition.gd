class_name DungeonDefinition
extends Resource
## Share this resource between every entrance to the same dungeon and its level.
@export var id: StringName
@export var display_name := "Vergeten heiligdom"
@export_file("*.tscn") var scene_path := ""
@export var entrance: StringName = &"DungeonEntrance"
## Item codes and quantities; granted once per saved world, upon completion.
@export var completion_loot: Dictionary[String, int] = {}


func completion_flag() -> String:
	return "dungeon." + String(id) + ".completed"
