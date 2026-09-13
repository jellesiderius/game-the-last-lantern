class_name SceneSpawnPoint
extends Marker3D
## Negative local Z points into the destination; start outside the portal's trigger volume.
@export var spawn_id: StringName = &"Entrance"


func _ready() -> void:
	add_to_group("scene_spawn_points")


func entry_direction() -> Vector3:
	var direction := -global_basis.z
	direction.y = 0.0
	return direction.normalized()
