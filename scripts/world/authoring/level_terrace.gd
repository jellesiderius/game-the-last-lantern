@tool
class_name LevelTerrace
extends Path3D
@export var surface_style: SurfaceStyle:
	set(value):
		if surface_style and surface_style.changed.is_connected(_changed):
			surface_style.changed.disconnect(_changed)
		surface_style = value
		if surface_style:
			surface_style.changed.connect(_changed)
		_changed()
## Closed X/Z outline; control-point tangents are intentionally ignored for cliffs.
var _free_height := 1.5
@export var height_source: NodePath:
	set(value):
		height_source = value
		_changed()
@export_enum("Begin", "Einde") var height_source_end := 1:
	set(value):
		height_source_end = value
		_changed()
@export_range(0, 12, .25, "suffix:m") var height: float = 1.5:
	get:
		var ramp := connected_ramp()
		if ramp:
			_free_height = (
				(ramp.transform * ramp.curve.get_point_position(height_source_end)).y - position.y
			)
		return _free_height
	set(value):
		_free_height = value
		var ramp := connected_ramp()
		if ramp and absf(ramp.basis.y.y) > .001:
			var point := ramp.curve.get_point_position(height_source_end)
			var base_y := (ramp.transform * Vector3(point.x, 0, point.z)).y
			ramp.set(
				"start_height" if height_source_end == 0 else "end_height",
				(value + position.y - base_y) / ramp.basis.y.y
			)
		_changed()


func connected_ramp() -> LevelRamp:
	if height_source.is_empty():
		return null
	var ramp := get_node_or_null(height_source) as LevelRamp
	if ramp and ramp.get_parent() == get_parent() and ramp.curve and ramp.curve.point_count == 2:
		ramp.ensure_point_heights()
		return ramp
	return null


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
