extends "res://scripts/world/authoring/authored_level.gd"
## A builder-made dungeon room: shares its DungeonDefinition with the Drempelpoort
## outside and its DungeonExit, and completes the dungeon once every required enemy
## is down. Leave Required Enemies empty to complete it from your own challenge code.
@export var dungeon: DungeonDefinition
@export var required_enemies: Array[NodePath] = []


func _ready() -> void:
	super._ready()
	for path in required_enemies:
		var enemy := get_node_or_null(path)
		if enemy != null and enemy.get("health") != null:
			enemy.health.depleted.connect(_check_objective.call_deferred)


func _check_objective() -> void:
	if required_enemies.is_empty() or dungeon == null:
		return
	for path in required_enemies:
		var enemy := get_node_or_null(path)
		if enemy == null or enemy.health.current > 0.0:
			return
	DungeonTravel.complete(dungeon)
