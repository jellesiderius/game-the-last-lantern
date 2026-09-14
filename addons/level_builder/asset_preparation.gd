@tool
class_name LevelAssetPreparation
extends RefCounted
## Offline/editor preparation. Never called by gameplay, never touches import cache.
enum CollisionMode { AUTO, NONE, BOX, CONVEX, TRIMESH, TRUNK }


static func prepare(source: PackedScene, destination: String, mode := CollisionMode.AUTO) -> Error:
	if source == null or source.resource_path.is_empty() or destination == source.resource_path:
		return ERR_INVALID_PARAMETER
	var root: Node3D
	if FileAccess.file_exists(destination):
		var packed := (
			ResourceLoader.load(destination, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
			as PackedScene
		)
		if packed == null:
			return ERR_INVALID_DATA
		root = packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
		if root == null or not root.has_meta("level_asset_source"):
			if root:
				root.free()
			return ERR_ALREADY_EXISTS
		if root.get_meta("level_asset_source") != source.resource_path:
			root.free()
			return ERR_ALREADY_EXISTS
	else:
		root = Node3D.new()
		root.name = destination.get_base_dir().get_file().to_pascal_case()
		var model := source.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		model.name = "Model"
		root.add_child(model)
		model.owner = root
	root.set_meta("level_asset_source", source.resource_path)
	root.set_meta("level_asset_collision_mode", mode)
	var old := root.get_node_or_null("GeneratedCollision")
	if old:
		root.remove_child(old)
		old.free()
	# Existing authored/imported collisions (including -colonly) are authoritative.
	if mode != CollisionMode.NONE and not _has_collision(root):
		var meshes: Array[Dictionary] = []
		_collect_meshes(root, Transform3D.IDENTITY, meshes, true)
		var body := StaticBody3D.new()
		body.name = "GeneratedCollision"
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("level_builder_generated", true)
		root.add_child(body)
		var all_points := PackedVector3Array()
		for item in meshes:
			var mesh: Mesh = item.mesh
			var transformed := PackedVector3Array()
			for point in mesh.get_faces():
				transformed.append(item.transform * point)
			all_points.append_array(transformed)
			if mode in [CollisionMode.AUTO, CollisionMode.TRIMESH, CollisionMode.CONVEX]:
				var shape: Shape3D
				if mode == CollisionMode.CONVEX:
					var convex := ConvexPolygonShape3D.new()
					convex.points = transformed
					shape = convex
				else:
					var concave := ConcavePolygonShape3D.new()
					concave.set_faces(transformed)
					shape = concave
				_add_shape(body, shape)
		if not all_points.is_empty() and mode in [CollisionMode.BOX, CollisionMode.TRUNK]:
			var bounds := AABB(all_points[0], Vector3.ZERO)
			for point in all_points:
				bounds = bounds.expand(point)
			if mode == CollisionMode.BOX:
				var box := BoxShape3D.new()
				box.size = bounds.size.max(Vector3(.05, .05, .05))
				_add_shape(body, box, bounds.get_center())
			else:
				# Fit the low trunk, excluding the canopy. Preview remains editable in the prefab.
				var height := minf(1.7, bounds.size.y * .4)
				var low := AABB()
				var first := true
				for point in all_points:
					if point.y <= bounds.position.y + height * .7:
						low = AABB(point, Vector3.ZERO) if first else low.expand(point)
						first = false
				var cylinder := CylinderShape3D.new()
				cylinder.radius = maxf(.1, maxf(low.size.x, low.size.z) * .5)
				cylinder.height = maxf(.2, height)
				_add_shape(
					body,
					cylinder,
					Vector3(
						low.get_center().x,
						bounds.position.y + cylinder.height * .5,
						low.get_center().z
					)
				)
		if body.get_child_count() == 0:
			root.free()
			return ERR_INVALID_DATA
		LevelTerrain.own_generated(body, root)
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	var packed := PackedScene.new()
	var error := packed.pack(root)
	if error == OK:
		error = ResourceSaver.save(packed, destination)
	root.free()
	return error


static func _has_collision(node: Node) -> bool:
	if node is CollisionShape3D and node.shape and not node.disabled:
		return true
	for child in node.get_children():
		if _has_collision(child):
			return true
	return false


static func _add_shape(body: StaticBody3D, resource: Shape3D, at := Vector3.ZERO) -> void:
	var shape := CollisionShape3D.new()
	shape.shape = resource
	shape.position = at
	body.add_child(shape)


static func _collect_meshes(
	node: Node, parent_transform: Transform3D, meshes: Array[Dictionary], root := false
) -> void:
	var transform := parent_transform
	if node is Node3D and not root:
		transform *= node.transform
	if node is MeshInstance3D and node.mesh and node.visible:
		meshes.append({"mesh": node.mesh, "transform": transform})
	for child in node.get_children():
		_collect_meshes(child, transform, meshes)
