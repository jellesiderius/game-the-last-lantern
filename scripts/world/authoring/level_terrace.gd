@tool
class_name LevelTerrace
extends Path3D
## Closed X/Z outline at one fixed height; control-point tangents are ignored.
## Height snaps to LevelTerrain.HEIGHT_STEP, so cliffs line up.
@export var surface_style: SurfaceStyle:
	set(value):
		if surface_style and surface_style.changed.is_connected(_changed):
			surface_style.changed.disconnect(_changed)
		surface_style = value
		if surface_style:
			surface_style.changed.connect(_changed)
		_changed()
## Default stays 1.5: older levels saved plateaus without an explicit height.
@export_range(0, 10, .5, "suffix:m") var height := 1.5:
	set(value):
		height = snappedf(clampf(value, 0.0, LevelTerrain.MAX_HEIGHT), LevelTerrain.HEIGHT_STEP)
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
