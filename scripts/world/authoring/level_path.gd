@tool
class_name LevelPath
extends Path3D
## Editor-authored surface paint. The curve stays editable after baking.
@export_range(.2, 20, .1, "suffix:m") var width := 2.4:
	set(value):
		width = value
		_changed()
@export_range(.01, 2, .01, "suffix:m") var edge_softness := .25:
	set(value):
		edge_softness = value
		_changed()


func _ready() -> void:
	if Engine.is_editor_hint():
		curve_changed.connect(_changed)
		set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_changed()


func _changed() -> void:
	if Engine.is_editor_hint() and is_inside_tree() and get_parent() is LevelTerrain:
		get_parent().request_bake()
