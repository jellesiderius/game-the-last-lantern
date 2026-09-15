@tool
class_name LevelRamp
extends Path3D
## A two-point slope. The curve points are the low and high ends, heights included;
## nothing else stores a height, so dragging an endpoint is the only edit needed.
@export var surface_style: SurfaceStyle:
	set(value):
		if surface_style and surface_style.changed.is_connected(_changed):
			surface_style.changed.disconnect(_changed)
		surface_style = value
		if surface_style:
			surface_style.changed.connect(_changed)
		_changed()
## Ends take the height of whatever plateau or ground lies under them.
## Editing a height by hand turns this off for that ramp.
@export var follow_ground := true:
	set(value):
		follow_ground = value
		_changed()
## Sandstone treads. Off by default so ramps in older levels keep their slope;
## the Stairs tool stores true explicitly.
@export var stairs := false:
	set(value):
		stairs = value
		_changed()
## The end that sits on a plateau edge; the other end moves when the length changes.
@export_enum("Begin", "Einde") var anchor_end := 1:
	set(value):
		anchor_end = value
		_changed()
## Builder stairs keep exactly the length their rise needs, so raising or lowering
## the plateau lengthens or shortens them. Older ramps only stretch when too steep.
@export var fit_length := false:
	set(value):
		fit_length = value
		_changed()
## Default stays 3: older levels saved ramps without an explicit width.
@export_range(.5, 12, .25, "suffix:m") var width := 3.0:
	set(value):
		width = value
		_changed()
@export_range(0, 100, .5, "suffix:m") var start_height: float:
	get:
		return _point_height(0)
	set(value):
		_set_point_height(0, value)
@export_range(0, 100, .5, "suffix:m") var end_height: float:
	get:
		return _point_height(1)
	set(value):
		_set_point_height(1, value)


func _point_height(index: int) -> float:
	if curve and curve.point_count > index:
		return curve.get_point_position(index).y
	return 0.0


func _set_point_height(index: int, height: float) -> void:
	if curve == null or curve.point_count <= index:
		return
	# Scene loading re-applies saved heights; only a real edit overrides the ground.
	if is_inside_tree():
		follow_ground = false
	var edited := curve.duplicate() as Curve3D
	var point := edited.get_point_position(index)
	point.y = snappedf(clampf(height, 0.0, LevelTerrain.MAX_HEIGHT), LevelTerrain.HEIGHT_STEP)
	edited.set_point_position(index, point)
	curve = edited
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
		update_gizmos()
		get_parent().request_bake()
