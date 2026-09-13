class_name CharacterDefinition
extends Resource
## A playable type supplies an authored visual scene; the controller and components are shared.
@export var id: StringName
@export var display_name := "Character"
@export var visual_scene: PackedScene
@export var movement: MovementSettings
@export var body_radius := .24
@export var body_height := .90
@export var maximum_health := 5.0
