@tool
class_name EnemyPatrol
extends Path3D
## A placed route overrides only this enemy's routine; its shared profile stays intact.
@export_node_path("Node3D") var enemy: NodePath
@export var ordered := true


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var actor := get_node_or_null(enemy)
	var brain := actor.get_node_or_null("Brain") as EnemyBrain if actor else null
	if brain == null or curve == null:
		return
	var offsets := PackedVector3Array()
	for i in curve.point_count:
		offsets.append(to_global(curve.get_point_position(i)) - actor.global_position)
	brain.authored_patrol = offsets
	brain.ordered_patrol = ordered
