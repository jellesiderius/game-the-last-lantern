@tool
class_name LevelBoundary
extends Path3D
## Editable prop line. Instances and blocking shapes are baked into the saved scene.
## Runtime only loads these children; it never scatters or generates collision.
@export var asset: LevelAsset:
	set(value):
		asset = value
		request_bake()
@export_range(.25, 20, .25, "suffix:m") var spacing := 2.0:
	set(value):
		spacing = maxf(.25, value)
		request_bake()
@export var random_yaw := true:
	set(value):
		random_yaw = value
		request_bake()
@export var random_seed := 1:
	set(value):
		random_seed = value
		request_bake()
@export_range(-100, 100, .5, "suffix:m") var height_offset := 0.0:
	set(value):
		height_offset = snappedf(clampf(value, -100, 100), .5)
		request_bake()
@export var block_movement := true:
	set(value):
		block_movement = value
		request_bake()
@export_range(.5, 100, .5, "suffix:m") var barrier_height := 4.0:
	set(value):
		barrier_height = maxf(.5, value)
		request_bake()
@export_range(.1, 8, .1, "suffix:m") var barrier_width := .6:
	set(value):
		barrier_width = maxf(.1, value)
		request_bake()
@export_storage var baked_signature := 0
var _queued := false
const SAMPLE_STEP := .5


func _ready() -> void:
	if Engine.is_editor_hint():
		curve_changed.connect(request_bake)
		set_notify_transform(true)
		request_bake()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		request_bake()
	elif what == NOTIFICATION_EDITOR_PRE_SAVE and Engine.is_editor_hint():
		bake()


func request_bake() -> void:
	if Engine.is_editor_hint() and is_inside_tree() and not _queued:
		_queued = true
		bake.call_deferred()


## Points in parent terrain space; follow the actual ground beneath the line.
func surface_point(at: Vector3, regions: Array[Dictionary]) -> Vector3:
	var point := transform * at
	var terrain := get_parent() as LevelTerrain
	if terrain == null:
		return point
	point.y = position.y
	for region in regions:
		if Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), region.polygon):
			point.y += LevelTerrain.region_height(region, Vector2(point.x, point.z))
			break
	return point


func ground_line() -> PackedVector3Array:
	var points := PackedVector3Array()
	if curve == null or curve.point_count < 2:
		return points
	var terrain := get_parent() as LevelTerrain
	var regions: Array[Dictionary] = []
	if terrain:
		regions = terrain.outlines()
	var length := curve.get_baked_length()
	var steps := maxi(1, ceili(length / SAMPLE_STEP))
	for i in steps + 1:
		points.append(surface_point(curve.sample_baked(length * i / steps), regions))
	return points


func bake() -> void:
	_queued = false
	if not Engine.is_editor_hint() or not is_inside_tree() or owner == null:
		return
	var terrain := get_parent() as LevelTerrain
	var signature := hash(
		[
			curve.get_baked_points() if curve else PackedVector3Array(),
			transform,
			asset.scene.resource_path if asset and asset.scene else "",
			spacing,
			random_yaw,
			random_seed,
			height_offset,
			block_movement,
			barrier_height,
			barrier_width,
			asset.scale_range if asset else Vector2.ONE,
			terrain.baked_signature if terrain else ""
		]
	)
	if signature == baked_signature and has_node("Baked"):
		return
	var previous := get_node_or_null("Baked")
	if previous:
		var selection := EditorInterface.get_selection()
		for selected in selection.get_selected_nodes():
			if selected == previous or previous.is_ancestor_of(selected):
				selection.remove_node(selected)
				selection.add_node(self)
				EditorInterface.edit_node(self)
		remove_child(previous)
		previous.queue_free()
	var baked := Node3D.new()
	baked.name = "Baked"
	add_child(baked)
	baked.owner = owner
	var props := Node3D.new()
	props.name = "Props"
	baked.add_child(props)
	props.owner = owner
	var length := curve.get_baked_length() if curve else 0.0
	if length < .01 or asset == null or asset.scene == null:
		baked_signature = signature
		return
	var regions: Array[Dictionary] = []
	if terrain:
		regions = terrain.outlines()
	var distances: Array[float] = []
	for i in floori(length / spacing) + 1:
		distances.append(i * spacing)
	var closed := (
		curve.get_point_position(0).distance_to(curve.get_point_position(curve.point_count - 1))
		< .01
	)
	if closed and length - distances[-1] < spacing * .5:
		distances.remove_at(distances.size() - 1)
	elif not closed and length - distances[-1] > spacing * .5:
		distances.append(length)
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var inverse := transform.affine_inverse()
	for distance in distances:
		var node := asset.scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
		if node == null:
			continue
		props.add_child(node, true)
		node.owner = owner
		node.position = (
			inverse
			* (surface_point(curve.sample_baked(distance), regions) + Vector3.UP * height_offset)
		)
		node.set_meta("level_asset_id", asset.id)
		if random_yaw:
			node.rotation.y = rng.randf() * TAU
		node.scale *= rng.randf_range(asset.scale_range.x, asset.scale_range.y)
	if block_movement:
		var body := StaticBody3D.new()
		body.name = "Barrier"
		body.collision_layer = 1
		body.collision_mask = 0
		baked.add_child(body)
		body.owner = owner
		var points := ground_line()
		for i in points.size() - 1:
			var a := points[i]
			var b := points[i + 1]
			var forward := Vector3(b.x - a.x, 0, b.z - a.z)
			if forward.length() < .001:
				continue
			var low := minf(a.y, b.y) - .5
			var high := maxf(a.y, b.y) + barrier_height
			var box := BoxShape3D.new()
			# Extend both ends to close the joins, even around sharp corners.
			box.size = Vector3(barrier_width, high - low, forward.length() + barrier_width)
			var shape := CollisionShape3D.new()
			shape.shape = box
			body.add_child(shape, true)
			shape.owner = owner
			shape.transform = (
				inverse
				* Transform3D(
					Basis(Vector3.UP, atan2(forward.x, forward.z)),
					Vector3((a.x + b.x) / 2, (low + high) / 2, (a.z + b.z) / 2)
				)
			)
	baked_signature = signature
	update_gizmos()
	EditorInterface.mark_scene_as_unsaved()
