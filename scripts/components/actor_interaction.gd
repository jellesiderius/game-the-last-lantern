class_name ActorInteraction
extends Node
var target: Interactable
@onready var actor: Node3D = get_parent()


func refresh() -> void:
	target = null
	var closest := INF
	for candidate: Interactable in get_tree().get_nodes_in_group("interactables"):
		var distance := actor.global_position.distance_to(candidate.global_position)
		if (
			distance > candidate.interaction_radius
			or distance >= closest
			or not candidate.can_interact(actor)
		):
			continue
		var ray := PhysicsRayQueryParameters3D.create(
			actor.global_position + Vector3.UP * .4,
			candidate.global_position + Vector3.UP * .4,
			CombatLayers.WORLD
		)
		if not actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		target = candidate
		closest = distance


func activate() -> bool:
	refresh()
	if not is_instance_valid(target):
		return false
	target.interact(actor)
	return true
