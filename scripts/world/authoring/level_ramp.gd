@tool
class_name LevelRamp
extends Path3D
@export var surface_style: SurfaceStyle:
	set(value):
		if surface_style and surface_style.changed.is_connected(_changed):
			surface_style.changed.disconnect(_changed)
		surface_style = value
		if surface_style:
			surface_style.changed.connect(_changed)
		_changed()
## The two Curve3D points are the actual low/high ends, including their Y heights.
var _legacy_start_height := 0.0
var _legacy_end_height := 1.5
var _last_connected_height := INF
var _last_connected_point := Vector3.INF
@export var terrace_attachment: NodePath:
	set(value):
		terrace_attachment = value
		_last_connected_height = INF
		_last_connected_point = Vector3.INF
		_changed()
@export_enum("Begin", "Einde") var attached_end := 1
@export_storage var points_define_height := false
@export_range(.5, 12, .25, "suffix:m") var width := 3.0:
	set(value):
		width = value
		_changed()
@export_range(0, 12, .25, "suffix:m") var start_height: float:
	get:
		return (
			curve.get_point_position(0).y
			if points_define_height and curve and curve.point_count > 0
			else _legacy_start_height
		)
	set(value):
		_legacy_start_height = value
		_set_point_height(0, value)
@export_range(0, 12, .25, "suffix:m") var end_height: float:
	get:
		return (
			curve.get_point_position(1).y
			if points_define_height and curve and curve.point_count > 1
			else _legacy_end_height
		)
	set(value):
		_legacy_end_height = value
		_set_point_height(1, value)


func ensure_point_heights() -> void:
	if points_define_height or curve == null or curve.point_count != 2:
		return
	# Upgrade earlier saved ramps once, preserving their visible/collision height.
	var upgraded := curve.duplicate() as Curve3D
	for i in 2:
		var point := upgraded.get_point_position(i)
		point.y += _legacy_start_height if i == 0 else _legacy_end_height
		upgraded.set_point_position(i, point)
	points_define_height = true
	curve = upgraded


func sync_connection() -> void:
	if curve == null or curve.point_count != 2:
		return
	if terrace_attachment.is_empty() and get_parent() is LevelTerrain:
		var found := RampConnection.find_attachment(self, curve, get_parent())
		if not found.is_empty():
			attached_end = found.endpoint
			terrace_attachment = get_path_to(found.terrace)
	if terrace_attachment.is_empty():
		return
	var terrace := get_node_or_null(terrace_attachment) as LevelTerrace
	if terrace == null or terrace.get_parent() != get_parent() or terrace.connected_ramp() == self:
		return
	var height := terrace.height + terrace.position.y
	var requested := transform * curve.get_point_position(attached_end)
	# A direct endpoint height drag moves the attached plateau too. A plateau edit
	# takes priority when its height itself changed since the last synchronization.
	if (
		is_finite(_last_connected_height)
		and is_equal_approx(height, _last_connected_height)
		and not is_equal_approx(requested.y, height)
	):
		terrace.height = requested.y - terrace.position.y
		height = requested.y
	var prefer_endpoint := (
		_last_connected_point != Vector3.INF
		and not Vector2(requested.x, requested.z).is_equal_approx(
			Vector2(_last_connected_point.x, _last_connected_point.z)
		)
	)
	var fitted := RampConnection.fit(self, curve, terrace, attached_end, prefer_endpoint)
	if fitted.is_empty():
		return
	if not is_equal_approx(width, fitted.width):
		width = fitted.width
	var changed := false
	for i in 2:
		changed = (
			changed
			or not curve.get_point_position(i).is_equal_approx(fitted.curve.get_point_position(i))
		)
	if changed:
		curve = fitted.curve
	_last_connected_height = height
	_last_connected_point = transform * curve.get_point_position(attached_end)


func _set_point_height(index: int, height: float) -> void:
	if points_define_height and curve and curve.point_count > index:
		var edited := curve.duplicate() as Curve3D
		var point := edited.get_point_position(index)
		point.y = height
		edited.set_point_position(index, point)
		curve = edited
	_changed()


func _ready() -> void:
	ensure_point_heights()
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
