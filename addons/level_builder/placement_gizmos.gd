@tool
extends EditorNode3DGizmoPlugin
var undo_redo: EditorUndoRedoManager
const HEIGHT_HANDLE_OFFSET := Vector3(0, .6, 0)


func _init() -> void:
	create_material("portal", Color(.2, .85, .8))
	create_material("spawn", Color(1, .8, .25))
	create_material("height", Color(.45, 1, .25))
	create_handle_material("height_handles")


func _get_gizmo_name() -> String:
	return "Level Builder"


func _has_gizmo(node: Node3D) -> bool:
	return node is LevelRamp or node is ScenePortal or LevelChecks.has_property(node, &"spawn_id")


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node := gizmo.get_node_3d()
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	if node is LevelRamp:
		if node.curve == null or node.curve.point_count != 2:
			return
		var handles := PackedVector3Array()
		var guides := PackedVector3Array()
		for i in 2:
			var point: Vector3 = node.curve.get_point_position(i)
			var handle := point + HEIGHT_HANDLE_OFFSET
			handles.append(handle)
			guides.append_array(PackedVector3Array([point, handle]))
		gizmo.add_lines(guides, get_material("height", gizmo))
		gizmo.add_handles(handles, get_material("height_handles", gizmo), PackedInt32Array([0, 1]))
		return
	var points := PackedVector3Array(
		[
			Vector3(0, .12, 0),
			Vector3(0, .12, -1.5),
			Vector3(0, .12, -1.5),
			Vector3(-.3, .12, -1),
			Vector3(0, .12, -1.5),
			Vector3(.3, .12, -1)
		]
	)
	if node is ScenePortal:
		var x: float = node.trigger_size.x * .5
		var z: float = node.trigger_size.z * .5
		var h: float = node.trigger_size.y
		for y in [0.0, h]:
			points.append_array(
				PackedVector3Array(
					[
						Vector3(-x, y, -z),
						Vector3(x, y, -z),
						Vector3(x, y, -z),
						Vector3(x, y, z),
						Vector3(x, y, z),
						Vector3(-x, y, z),
						Vector3(-x, y, z),
						Vector3(-x, y, -z)
					]
				)
			)
		for p in [Vector2(-x, -z), Vector2(x, -z), Vector2(x, z), Vector2(-x, z)]:
			points.append_array(PackedVector3Array([Vector3(p.x, 0, p.y), Vector3(p.x, h, p.y)]))
	gizmo.add_lines(points, get_material("portal" if node is ScenePortal else "spawn", gizmo))
	gizmo.add_collision_segments(points)


func _get_handle_name(_gizmo: EditorNode3DGizmo, id: int, _secondary: bool) -> String:
	return "Beginhoogte — sleep omhoog/omlaag" if id == 0 else "Eindhoogte — sleep omhoog/omlaag"


func _get_handle_value(gizmo: EditorNode3DGizmo, _id: int, _secondary: bool) -> Variant:
	return (gizmo.get_node_3d() as LevelRamp).curve.duplicate()


func _set_handle(
	gizmo: EditorNode3DGizmo, id: int, _secondary: bool, camera: Camera3D, screen_pos: Vector2
) -> void:
	var ramp := gizmo.get_node_3d() as LevelRamp
	if not is_instance_valid(ramp) or not ramp.is_inside_tree():
		return
	var point := ramp.curve.get_point_position(id)
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	var axis := ramp.global_basis.y.normalized()
	var center := ramp.to_global(point)
	var closest := Geometry3D.get_closest_points_between_segments(
		origin, origin + direction * 4096, center - axis * 1024, center + axis * 1024
	)
	point.y = maxf(0, ramp.to_local(closest[1]).y - HEIGHT_HANDLE_OFFSET.y)
	var changed := ramp.curve.duplicate() as Curve3D
	changed.set_point_position(id, point)
	ramp.curve = changed
	ramp.update_gizmos()


func _commit_handle(
	gizmo: EditorNode3DGizmo, _id: int, _secondary: bool, restore: Variant, cancel: bool
) -> void:
	var ramp := gizmo.get_node_3d() as LevelRamp
	if not is_instance_valid(ramp):
		return
	if cancel:
		ramp.curve = restore
	else:
		undo_redo.create_action("Sleep ramphoogte", UndoRedo.MERGE_DISABLE, ramp)
		undo_redo.add_do_property(ramp, "curve", ramp.curve)
		undo_redo.add_undo_property(ramp, "curve", restore)
		undo_redo.commit_action(false)
	ramp.update_gizmos()
