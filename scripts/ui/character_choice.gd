class_name CharacterChoice
extends Button
## One authored choice binds its data, preview and highlight; no character-name branches.
@export var definition: CharacterDefinition
@export var preview: CharacterVisual
@export var selection_ring: MeshInstance3D


func _ready() -> void:
	text = definition.display_name
	preview.configure_locomotion(definition.movement)


func _process(delta: float) -> void:
	preview.sample("", 0.0, 0.0, delta)


func show_selected(selected: bool) -> void:
	selection_ring.visible = selected
