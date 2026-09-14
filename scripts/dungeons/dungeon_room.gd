extends "res://scripts/world/prototype_room.gd"
## Example objective adapter. Other dungeon scenes may use their own challenge code.
@export var dungeon: DungeonDefinition
@export var required_enemies: Array[NodePath] = []


func _ready() -> void:
	super._ready()
	for path in required_enemies:
		var enemy := get_node_or_null(path)
		if enemy != null:
			enemy.health.depleted.connect(_check_objective.call_deferred)


func _check_objective() -> void:
	if required_enemies.is_empty():
		return
	for path in required_enemies:
		var enemy := get_node_or_null(path)
		if enemy == null or enemy.health.current > 0.0:
			return
	DungeonTravel.complete(dungeon)
