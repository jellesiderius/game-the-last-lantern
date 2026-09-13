extends Node
## Automatic collision-derived navigation, shared per world and agent size.
## Offline meshes are optional caches, never a dependency on a level name/bounds.
var scene: Node
var geometry: NavigationMeshSourceGeometryData3D
var signature := ""
var surfaces: Dictionary = {}
var pending: Array[Dictionary] = []
var regions: Array[RID] = []
var generation := 0
var busy := false
var buckets: Dictionary = {}
var geometry_dirty := false
const BUCKET_SIZE := 3.0


func _ready() -> void:
	process_physics_priority = -20
	get_tree().node_added.connect(_geometry_changed)
	get_tree().node_removed.connect(_geometry_changed)


func _geometry_changed(node: Node) -> void:
	if not is_instance_valid(scene):
		return
	if node is StaticBody3D or (node is CollisionShape3D and node.get_parent() is StaticBody3D):
		geometry_dirty = true


## Moving/changing an existing static shape can call this after a batch of edits.
## Added/removed streamed colliders invalidate automatically.
func invalidate() -> void:
	geometry_dirty = true


func surface_for(actor: Node3D, radius: float, height := 1.0) -> EnemySurfaceNavigation:
	var current := get_tree().current_scene
	if current == null:
		return EnemySurfaceNavigation.new()
	if current != scene:
		_bind_scene(current)
	var key := Vector2i(ceili(radius * 10), ceili(height * 10))
	if not surfaces.has(key):
		var surface := EnemySurfaceNavigation.new()
		surface.baked_radius = float(key.x) / 10
		surface.baked_height = float(key.y) / 10
		surface.map_rid = NavigationServer3D.map_create()
		NavigationServer3D.map_set_active(surface.map_rid, true)
		NavigationServer3D.map_set_cell_size(surface.map_rid, .1)
		NavigationServer3D.map_set_cell_height(surface.map_rid, .05)
		surfaces[key] = surface
		pending.append(
			{"surface": surface, "world": actor.get_world_3d(), "generation": generation}
		)
		call_deferred("_build_next")
	return surfaces[key]


func _bind_scene(current: Node) -> void:
	_clear_maps()
	scene = current
	geometry = null
	signature = ""
	buckets.clear()
	geometry_dirty = false


static func bake_settings(radius: float, height := 1.0) -> NavigationMesh:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = CombatLayers.WORLD
	mesh.agent_radius = radius
	mesh.agent_height = height
	mesh.agent_max_climb = .20
	mesh.agent_max_slope = 45.0
	mesh.cell_size = .1
	mesh.cell_height = .05
	mesh.edge_max_error = 1.0
	mesh.region_min_size = 1.0
	mesh.filter_ledge_spans = true
	mesh.filter_walkable_low_height_spans = true
	return mesh


static func geometry_signature(data: NavigationMeshSourceGeometryData3D) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data.get_vertices().to_byte_array())
	context.update(data.get_indices().to_byte_array())
	return context.finish().hex_encode()


static func parse_world_geometry(
	mesh: NavigationMesh, data: NavigationMeshSourceGeometryData3D, root: Node
) -> void:
	NavigationServer3D.parse_source_geometry_data(mesh, data, root)
	# Godot parses relative to its root. Bake in world coordinates so translated,
	# rotated and scaled level roots require no special-case navigation code.
	if root is Node3D and not root.global_transform.is_equal_approx(Transform3D.IDENTITY):
		var vertices := data.get_vertices()
		for i in range(0, vertices.size(), 3):
			var point: Vector3 = (
				root.global_transform * Vector3(vertices[i], vertices[i + 1], vertices[i + 2])
			)
			vertices[i] = point.x
			vertices[i + 1] = point.y
			vertices[i + 2] = point.z
		data.set_vertices(vertices)


func _build_next() -> void:
	if busy or pending.is_empty() or not is_instance_valid(scene):
		return
	busy = true
	var job: Dictionary = pending.pop_front()
	var surface: EnemySurfaceNavigation = job.surface
	var mesh := bake_settings(surface.baked_radius, surface.baked_height)
	if geometry == null:
		geometry = NavigationMeshSourceGeometryData3D.new()
		parse_world_geometry(mesh, geometry, scene)
		signature = geometry_signature(geometry)
	# Any saved region can provide a verified cache. Changed colliders invalidate it.
	for node in scene.find_children("*", "NavigationRegion3D", true, false):
		var candidate: NavigationMesh = node.navigation_mesh
		if (
			candidate
			and candidate.agent_radius >= surface.baked_radius
			and candidate.agent_height >= surface.baked_height
			and candidate.get_meta("source_signature", "") == signature
		):
			mesh = candidate
			_install(mesh, surface, job.generation)
			return
	NavigationServer3D.bake_from_source_geometry_data_async(
		mesh, geometry, func(): _install(mesh, surface, job.generation)
	)


func _install(mesh: NavigationMesh, surface: EnemySurfaceNavigation, job_generation: int) -> void:
	if job_generation == generation and surface.map_rid.is_valid():
		surface.mesh = mesh
		surface.minimum_iteration = NavigationServer3D.map_get_iteration_id(surface.map_rid) + 1
		var region := NavigationServer3D.region_create()
		surface.region_rid = region
		NavigationServer3D.region_set_enabled(region, true)
		NavigationServer3D.region_set_navigation_mesh(region, mesh)
		NavigationServer3D.region_set_map(region, surface.map_rid)
		regions.append(region)
		NavigationServer3D.map_force_update(surface.map_rid)
		surface.installed = mesh.get_polygon_count() > 0
		print(
			"ENEMY_NAVIGATION_READY polygons=",
			mesh.get_polygon_count(),
			" radius=",
			surface.baked_radius
		)
	busy = false
	call_deferred("_build_next")


func _physics_process(_delta: float) -> void:
	if GameClock.dt <= 0:
		return
	if geometry_dirty and is_instance_valid(scene):
		_bind_scene(scene)
	buckets.clear()
	for brain in get_tree().get_nodes_in_group("enemy_ai"):
		if not brain.operational():
			continue
		var cell := Vector3i((brain.actor.global_position / BUCKET_SIZE).floor())
		if not buckets.has(cell):
			buckets[cell] = []
		buckets[cell].append(brain)


func neighbors(position: Vector3, distance: float, exclude: EnemyBrain) -> Array:
	var result: Array = []
	var center := Vector3i((position / BUCKET_SIZE).floor())
	var reach := ceili(distance / BUCKET_SIZE)
	for x in range(-reach, reach + 1):
		for z in range(-reach, reach + 1):
			for y in range(-1, 2):
				for brain in buckets.get(center + Vector3i(x, y, z), []):
					if (
						is_instance_valid(brain)
						and brain != exclude
						and brain.operational()
						and absf(brain.actor.global_position.y - position.y) < 1.1
						and brain.actor.global_position.distance_to(position) < distance
					):
						result.append(brain)
	return result


func _clear_maps() -> void:
	generation += 1
	pending.clear()
	for region in regions:
		NavigationServer3D.free_rid(region)
	regions.clear()
	for surface in surfaces.values():
		NavigationServer3D.free_rid(surface.map_rid)
		surface.map_rid = RID()
		surface.installed = false
	surfaces.clear()


func _exit_tree() -> void:
	_clear_maps()
