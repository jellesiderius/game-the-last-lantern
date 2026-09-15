@tool
class_name LevelWater
extends Path3D
## Water painted into a level: a closed area or a river along a path.
## The terrain lowers its ground into a bed with soft banks underneath; this node
## draws the stylized water surface over it. Shore foam, depth colour and refraction
## come from the depth buffer, so banks, walls, rocks and bridge posts get contact
## foam automatically. Wading actors (the player and enemies) leave rings.
enum Shape { AREA, PATH }
const MAX_ACTORS := 4
@export var shape: Shape = Shape.AREA:
	set(value):
		shape = value
		_changed()
## River width when the shape is a path.
@export_range(.5, 20, .25, "suffix:m") var width := 3.0:
	set(value):
		width = value
		_changed()
@export_range(.1, 3, .05, "suffix:m") var depth := .6:
	set(value):
		depth = value
		_changed()
## Distance over which the bank eases from the shore down to the full depth.
@export_range(.1, 4, .05, "suffix:m") var bank := .9:
	set(value):
		bank = value
		_changed()
## How far the surface sits below the surrounding ground.
@export_range(0, .5, .01, "suffix:m") var surface_drop := .12:
	set(value):
		surface_drop = value
		_changed()
@export var ripples := true
## Leave empty for the shared stylized water; assign a copy to tune one pond.
@export var surface_material: ShaderMaterial:
	set(value):
		surface_material = value
		_changed()
var _material: ShaderMaterial
var _outline := PackedVector2Array()
var _motion := PackedFloat32Array([0, 0, 0, 0])
var _queued := false


func _ready() -> void:
	rebuild()
	if Engine.is_editor_hint():
		curve_changed.connect(_changed)


func _changed() -> void:
	if not is_inside_tree():
		return
	if not _queued:
		_queued = true
		rebuild.call_deferred()
	if Engine.is_editor_hint() and get_parent() is LevelTerrain:
		get_parent().request_bake()


## Outline in the parent's X/Z space, counter-clockwise; empty when incomplete.
func outline() -> PackedVector2Array:
	var points := PackedVector2Array()
	if curve == null:
		return points
	for i in curve.point_count:
		var p := transform * curve.get_point_position(i)
		points.append(Vector2(p.x, p.z))
	if shape == Shape.PATH:
		if points.is_empty():
			return PackedVector2Array()
		if points.size() == 1:
			points.append(points[0] + Vector2(.01, 0))
		var grown := Geometry2D.offset_polyline(
			points, width / 2, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND
		)
		points = grown[0] if not grown.is_empty() else PackedVector2Array()
	else:
		if points.size() > 1 and points[0].is_equal_approx(points[points.size() - 1]):
			points.remove_at(points.size() - 1)
	if points.size() < 3:
		return PackedVector2Array()
	if Geometry2D.is_polygon_clockwise(points):
		points.reverse()
	return points


## Bed height relative to the surrounding ground: 0 at the shore, easing down to
## -depth over `bank` metres inside the outline.
static func bed_height(shore: PackedVector2Array, bed_depth: float, bank_width: float, point: Vector2) -> float:
	if shore.size() < 3 or not Geometry2D.is_point_in_polygon(point, shore):
		return 0.0
	var inside := INF
	for i in shore.size():
		var closest := Geometry2D.get_closest_point_to_segment(point, shore[i], shore[(i + 1) % shore.size()])
		inside = minf(inside, point.distance_to(closest))
	var t := clampf(inside / maxf(bank_width, .01), 0, 1)
	return -bed_depth * t * t * (3.0 - 2.0 * t)


func rebuild() -> void:
	_queued = false
	var previous := get_node_or_null("Generated")
	if previous:
		remove_child(previous)
		previous.queue_free()
	_outline = outline()
	# Never draw water beyond the terrain: there is no bed out there to look into.
	var ground := get_parent() as LevelTerrain
	if ground and _outline.size() >= 3:
		var half := ground.size / 2
		var clipped := Geometry2D.intersect_polygons(
			_outline, PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
		)
		_outline = PackedVector2Array()
		for part in clipped:
			if part.size() >= 3 and (_outline.is_empty() or LevelTerrain.polygon_area(part) > LevelTerrain.polygon_area(_outline)):
				_outline = part
	if _outline.size() < 3:
		return
	var indices := Geometry2D.triangulate_polygon(_outline)
	if indices.is_empty():
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var to_local := transform.affine_inverse()
	for index in indices:
		var point := _outline[index]
		surface.set_normal(Vector3.UP)
		surface.set_uv(point)
		surface.add_vertex(to_local * Vector3(point.x, -surface_drop, point.y))
	var source := surface_material
	if source == null:
		source = ShaderMaterial.new()
		source.shader = preload("res://shaders/level_water.gdshader")
	# Every running pond gets its own copy for the wading rings.
	_material = source if Engine.is_editor_hint() else source.duplicate() as ShaderMaterial
	# Unowned: rebuilt on every load, never saved into the scene.
	var generated := Node3D.new()
	generated.name = "Generated"
	add_child(generated)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Surface"
	mesh_instance.mesh = surface.commit()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.material_override = _material
	generated.add_child(mesh_instance)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not ripples or _material == null or _outline.size() < 3:
		return
	var parent := get_parent() as Node3D
	var surface_y := to_global(Vector3(0, -surface_drop, 0)).y
	var candidates: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group("player"):
		if node is Node3D:
			candidates.append(node)
	for brain in get_tree().get_nodes_in_group("enemy_ai"):
		var actor: Variant = brain.get("actor")
		if actor is Node3D:
			candidates.append(actor)
	var actors: Array[Vector4] = []
	for actor in candidates:
		if actors.size() >= MAX_ACTORS:
			break
		var at := actor.global_position
		var local := parent.to_local(at) if parent else at
		if absf(at.y - surface_y) > 1.2 or not Geometry2D.is_point_in_polygon(Vector2(local.x, local.z), _outline):
			continue
		var speed := 0.0
		if actor is CharacterBody3D:
			speed = Vector2(actor.velocity.x, actor.velocity.z).length()
		var slot := actors.size()
		_motion[slot] = lerpf(_motion[slot], clampf(speed / 3.0, 0, 1), 1.0 - exp(-5.0 * delta))
		actors.append(Vector4(at.x, at.y, at.z, _motion[slot]))
	while actors.size() < MAX_ACTORS:
		_motion[actors.size()] = 0.0
		actors.append(Vector4(0, -10000, 0, 0))
	_material.set_shader_parameter("actors", actors)
