@tool
class_name LevelAsset
extends Resource
## One reusable, already prepared scene. Collision belongs to that scene.
@export var id: StringName
@export var display_name := "Asset"
@export var category := "Props"
@export var scene: PackedScene
@export var tags := PackedStringArray()
@export var scatter_allowed := false
@export_range(.1, 10, .1) var spacing := 1.0
@export var scale_range := Vector2(1, 1)
@export var random_yaw := false
@export var thumbnail: Texture2D
