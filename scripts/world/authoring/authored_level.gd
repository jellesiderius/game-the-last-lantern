extends "res://scripts/world/prototype_room.gd"
## Generic saved level; its kit never determines gameplay or save identity.
@export var area: WorldArea
@export var area_set: AreaSet
@export var auto_camera_bounds := true


func _ready() -> void:
	if auto_camera_bounds and has_node("Terrain"):
		var ground := get_node("Terrain") as LevelTerrain
		var half := (ground.size / 2 - Vector2(5, 5)).max(Vector2.ONE)
		camera_min = Vector2(ground.position.x, ground.position.z) - half
		camera_max = Vector2(ground.position.x, ground.position.z) + half
	super._ready()
	if not SceneTransit.active:
		player.respawn(spawn_position)
		reset_camera()
