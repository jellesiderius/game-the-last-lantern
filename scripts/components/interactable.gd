class_name Interactable
extends Node3D
## Override interact for doors, pickups or friendly NPCs; selection remains shared.
signal interacted(actor: Node3D)
@export var prompt := "Interact"
@export var interaction_radius := 1.6
@export var enabled := true


func _ready() -> void:
	add_to_group("interactables")


func can_interact(_actor: Node3D) -> bool:
	return enabled and is_visible_in_tree()


func interact(actor: Node3D) -> void:
	interacted.emit(actor)
