@tool
class_name LevelTerrain
extends Node3D
## Only rebuilds in the editor or explicit offline tools. Play loads saved geometry.
@export var surface_style: SurfaceStyle:
	set(value):
		if surface_style and surface_style.changed.is_connected(request_bake):
			surface_style.changed.disconnect(request_bake)
		surface_style = value
		if surface_style:
			surface_style.changed.connect(request_bake)
		request_bake()
@export var area_set: AreaSet:
	set(value):
		if area_set and area_set.changed.is_connected(request_bake):
			area_set.changed.disconnect(request_bake)
		area_set = value
		if area_set:
			area_set.changed.connect(request_bake)
		request_bake()
@export var size := Vector2(24, 24):
	set(value):
		size = value.max(Vector2(2, 2))
		request_bake()
@export_range(.25, 2, .25) var resolution := .5:
	set(value):
		resolution = value
		request_bake()
@export var enclose_bounds := true:
	set(value):
		enclose_bounds = value
		request_bake()
@export_storage var baked_signature := ""
@export_tool_button("Werk grond bij", "MeshInstance3D") var rebuild: Callable:
	get:
		return Callable(self, "bake")
var last_error := ""
var dirty := false
var bake_delay := 0.0
var _paths: Array[Dictionary] = []
var _surface_groups := {}
const EPS := .000001


func _ready() -> void:
	set_process(Engine.is_editor_hint())
	if Engine.is_editor_hint():
		child_entered_tree.connect(func(_node): request_bake())
		child_exiting_tree.connect(func(_node): request_bake())
		request_bake()


func request_bake() -> void:
	if Engine.is_editor_hint():
		dirty = true
		bake_delay = .3


func _process(delta: float) -> void:
	if not dirty:
		return
	bake_delay -= delta
	if bake_delay <= 0 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		bake()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE and Engine.is_editor_hint():
		bake()
		if owner and not owner.scene_file_path.is_empty():
			save_baked_resources(owner.scene_file_path)


func outlines() -> Array[Dictionary]:
	for child in get_children():
		if child is LevelRamp:
			child.ensure_point_heights()
			child.sync_connection()
	var result: Array[Dictionary] = []
	for child in get_children():
		if child is LevelTerrace and child.curve:
			var points := PackedVector2Array()
			for i in child.curve.point_count:
				var p: Vector3 = child.transform * child.curve.get_point_position(i)
				points.append(Vector2(p.x, p.z))
			if points.size() > 1 and points[0].is_equal_approx(points[-1]):
				points.remove_at(points.size() - 1)
			if Geometry2D.is_polygon_clockwise(points):
				points.reverse()
			result.append(
				{
					"polygon": points,
					"height": child.height + child.position.y,
					"name": child.name,
					"style": child.surface_style
				}
			)
		elif child is LevelRamp and child.curve and child.curve.point_count == 2:
			child.ensure_point_heights()
			var start: Vector3 = child.transform * child.curve.get_point_position(0)
			var end: Vector3 = child.transform * child.curve.get_point_position(1)
			var a := Vector2(start.x, start.z)
			var b := Vector2(end.x, end.z)
			var side: Vector2 = (b - a).normalized().orthogonal() * child.width / 2
			var points := PackedVector2Array([a - side, b - side, b + side, a + side])
			if Geometry2D.is_polygon_clockwise(points):
				points.reverse()
			result.append(
				{
					"polygon": points,
					"height": maxf(start.y, end.y),
					"name": child.name,
					"style": child.surface_style,
					"ramp_start": a,
					"ramp_end": b,
					"start_height": start.y,
					"end_height": end.y
				}
			)
	return result


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if area_set == null:
		errors.append("Kies een areaset voor de grond.")
	for child in get_children():
		if child is LevelRamp and (child.curve == null or child.curve.point_count != 2):
			errors.append("Ramp %s: teken precies twee eindpunten." % child.name)
	var regions := outlines()
	for i in regions.size():
		if regions[i].has("ramp_start"):
			var distance: float = regions[i].ramp_start.distance_to(regions[i].ramp_end)
			if (
				distance < .1
				or absf(regions[i].end_height - regions[i].start_height) / maxf(.01, distance) > .95
			):
				errors.append(
					(
						"Ramp %s is te steil; verleng hem of verlaag het hoogteverschil."
						% regions[i].name
					)
				)
		var p: PackedVector2Array = regions[i].polygon
		if p.size() < 3 or Geometry2D.triangulate_polygon(p).is_empty():
			errors.append(
				"Terras %s: teken minstens drie punten zonder zelfkruising." % regions[i].name
			)
		for v in p:
			if absf(v.x) > size.x / 2 or absf(v.y) > size.y / 2:
				errors.append("Terras %s ligt buiten de grond." % regions[i].name)
		for j in range(i):
			for overlap in Geometry2D.intersect_polygons(p, regions[j].polygon):
				if polygon_area(overlap) > EPS:
					errors.append(
						(
							"Terrassen %s en %s overlappen; sluit hun randen aan."
							% [regions[i].name, regions[j].name]
						)
					)
	return errors


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := validate()
	if not last_error.is_empty():
		warnings.append(last_error)
	return warnings


func signature() -> String:
	var regions := outlines()
	for region in regions:
		region.style = region.style.signature() if region.style else ""
	var data := [
		"surface_styles_v6",
		size,
		resolution,
		enclose_bounds,
		regions,
		surface_style.signature() if surface_style else ""
	]
	if area_set:
		data.append(
			[
				area_set.ground_color,
				area_set.path_color,
				area_set.cliff_color,
				area_set.texture_scale,
				area_set.ground_texture.resource_path if area_set.ground_texture else "",
				area_set.path_texture.resource_path if area_set.path_texture else ""
			]
		)
	for child in get_children():
		if child is LevelPath and child.curve:
			data.append(
				[child.transform, child.width, child.edge_softness, child.curve.get_baked_points()]
			)
	return str(data).sha256_text()


func bake() -> bool:
	dirty = false
	var errors := validate()
	if not errors.is_empty():
		last_error = "\n".join(errors)
		update_configuration_warnings()
		return false
	var current := signature()
	if current == baked_signature and has_node("Baked"):
		return true
	last_error = ""
	_paths.clear()
	for child in get_children():
		if child is LevelPath and child.curve and child.curve.point_count > 0:
			var points := PackedVector2Array()
			for point in child.curve.get_baked_points():
				var p: Vector3 = child.transform * point
				points.append(Vector2(p.x, p.z))
			if points.is_empty():
				var p: Vector3 = child.transform * child.curve.get_point_position(0)
				points.append(Vector2(p.x, p.z))
			_paths.append({"points": points, "width": child.width, "soft": child.edge_softness})
	var regions := outlines()
	var cuts: Array[Dictionary] = []
	for region in regions:
		var polygon: PackedVector2Array = region.polygon
		var indices := Geometry2D.triangulate_polygon(polygon)
		for i in range(0, indices.size(), 3):
			var tri := PackedVector2Array(
				[polygon[indices[i]], polygon[indices[i + 1]], polygon[indices[i + 2]]]
			)
			if Geometry2D.is_polygon_clockwise(tri):
				tri.reverse()
			var bounds := Rect2(tri[0], Vector2.ZERO).expand(tri[1]).expand(tri[2])
			cuts.append({"polygon": tri, "region": region, "bounds": bounds})
	_surface_groups.clear()
	var total_area := 0.0
	# Bound editor work for large areas; dimensions stay exact.
	var cell_size := maxf(resolution, sqrt(size.x * size.y / 65536.0))
	var nx := ceili(size.x / cell_size)
	var nz := ceili(size.y / cell_size)
	for z in nz:
		for x in nx:
			var a := Vector2(-size.x / 2 + x * size.x / nx, -size.y / 2 + z * size.y / nz)
			var b := a + Vector2(size.x / nx, size.y / nz)
			var cell := Rect2(a, b - a)
			var pieces: Array[PackedVector2Array] = [
				PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)])
			]
			for cut in cuts:
				if not cell.intersects(cut.bounds):
					continue
				var remaining: Array[PackedVector2Array] = []
				for piece in pieces:
					var inner := piece
					for edge in 3:
						if inner.size() < 3:
							break
						var first: Vector2 = cut.polygon[edge]
						var second: Vector2 = cut.polygon[(edge + 1) % 3]
						var outside := clip_half_plane(inner, first, second, false)
						if polygon_area(outside) > EPS:
							remaining.append(outside)
						inner = clip_half_plane(inner, first, second, true)
					total_area += _emit_top(inner, cut.region)
				pieces = remaining
			for piece in pieces:
				total_area += _emit_top(piece, {})
	if absf(total_area - size.x * size.y) > .005:
		last_error = (
			"Grondoppervlakken sluiten niet aan (%s / %s m²)." % [total_area, size.x * size.y]
		)
		update_configuration_warnings()
		return false
	var mask := _bake_path_mask()
	var mesh := ArrayMesh.new()
	for style in _surface_groups:
		var settings: Resource = style if style else surface_style if surface_style else area_set
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/level_ground.gdshader")
		for key in ["ground_color", "path_color", "ground_texture", "path_texture"]:
			material.set_shader_parameter(key, settings.get(key))
		material.set_shader_parameter("has_ground_texture", settings.ground_texture != null)
		material.set_shader_parameter("has_path_texture", settings.path_texture != null)
		material.set_shader_parameter(
			"ground_pattern", settings.pattern if settings is SurfaceStyle else 0
		)
		material.set_shader_parameter("path_mask", mask)
		material.set_shader_parameter("has_path_mask", true)
		_surface_groups[style].set_material(material)
		_surface_groups[style].commit(mesh)
	if not regions.is_empty():
		var sides := SurfaceTool.new()
		sides.begin(Mesh.PRIMITIVE_TRIANGLES)
		for region in regions:
			var settings: Resource = (
				region.style if region.style else surface_style if surface_style else area_set
			)
			sides.set_color(settings.cliff_color.srgb_to_linear())
			_emit_sides(sides, region, regions)
		var rock := StandardMaterial3D.new()
		rock.vertex_color_use_as_albedo = true
		rock.roughness = .95
		rock.cull_mode = BaseMaterial3D.CULL_DISABLED
		sides.set_material(rock)
		sides.commit(mesh)
	var baked := Node3D.new()
	baked.name = "Baked"
	baked.set_meta("level_builder_generated", true)
	var visual := MeshInstance3D.new()
	visual.name = "Surface"
	visual.mesh = mesh
	baked.add_child(visual)
	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	baked.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "SurfaceShape"
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	if enclose_bounds:
		var boundary_height := 8.0
		for region in regions:
			boundary_height = maxf(boundary_height, region.height + 4)
		for item in [
			Vector3(-size.x / 2 - .25, 0, 0),
			Vector3(size.x / 2 + .25, 0, 0),
			Vector3(0, 0, -size.y / 2 - .25),
			Vector3(0, 0, size.y / 2 + .25)
		]:
			var wall := CollisionShape3D.new()
			wall.name = "Boundary%d" % body.get_child_count()
			var box := BoxShape3D.new()
			box.size = (
				Vector3(.5, boundary_height, size.y + 1)
				if item.x != 0
				else Vector3(size.x + 1, boundary_height, .5)
			)
			wall.shape = box
			wall.position = item + Vector3(0, boundary_height / 2 - 1, 0)
			body.add_child(wall)
	var previous := get_node_or_null("Baked")
	if previous:
		# A user may have selected a generated surface or collider. Move the editor
		# off those nodes before retiring them, and defer freeing live tree objects.
		var was_live := previous.is_inside_tree()
		if Engine.is_editor_hint() and was_live:
			var selection := EditorInterface.get_selection()
			for selected in selection.get_selected_nodes():
				if selected == previous or previous.is_ancestor_of(selected):
					selection.remove_node(selected)
					selection.add_node(self)
					EditorInterface.edit_node(self)
		remove_child(previous)
		if was_live:
			previous.queue_free()
		else:
			previous.free()
	add_child(baked)
	var scene_owner := owner if owner else self
	own_generated(baked, scene_owner)
	_surface_groups.clear()
	baked_signature = current
	dirty = false
	update_configuration_warnings()
	if Engine.is_editor_hint() and is_inside_tree():
		EditorInterface.mark_scene_as_unsaved()
	return true


func _bake_path_mask() -> ImageTexture:
	# A filtered mask follows the exact curve distances, independently of mesh cells.
	# Rasterize only each segment's footprint; empty ground costs no distance work.
	var pixels_per_meter := minf(32, 2048.0 / maxf(size.x, size.y))
	var dimensions := Vector2i(
		maxi(1, ceili(size.x * pixels_per_meter)), maxi(1, ceili(size.y * pixels_per_meter))
	)
	var pixel_size := size / Vector2(dimensions)
	var data := PackedByteArray()
	data.resize(dimensions.x * dimensions.y)
	for path in _paths:
		var source: PackedVector2Array = path.points
		var points := PackedVector2Array([source[0]])
		# Keep curved samples; collapse collinear runs to avoid redundant raster work.
		for i in range(1, source.size() - 1):
			if (
				source[i].distance_to(
					Geometry2D.get_closest_point_to_segment(source[i], points[-1], source[i + 1])
				)
				> .002
			):
				points.append(source[i])
		if source.size() > 1:
			points.append(source[-1])
		var feather := maxf(path.soft, maxf(pixel_size.x, pixel_size.y) * 2)
		var radius: float = path.width / 2
		var outer := radius + feather / 2
		for segment in maxi(1, points.size() - 1):
			var a := points[segment]
			var b := points[mini(segment + 1, points.size() - 1)]
			var low := (
				Vector2i(((a.min(b) - Vector2.ONE * outer + size / 2) / pixel_size).floor())
				. max(Vector2i.ZERO)
			)
			var high := (
				Vector2i(((a.max(b) + Vector2.ONE * outer + size / 2) / pixel_size).ceil())
				. min(dimensions - Vector2i.ONE)
			)
			for y in range(low.y, high.y + 1):
				for x in range(low.x, high.x + 1):
					var index := y * dimensions.x + x
					if data[index] == 255:
						continue
					var point := (Vector2(x, y) + Vector2(.5, .5)) * pixel_size - size / 2
					var distance := point.distance_to(
						Geometry2D.get_closest_point_to_segment(point, a, b)
					)
					var weight := roundi(
						(1 - smoothstep(radius - feather / 2, outer, distance)) * 255
					)
					data[index] = maxi(data[index], weight)
	var mask := Image.create_from_data(dimensions.x, dimensions.y, false, Image.FORMAT_R8, data)
	mask.generate_mipmaps()
	return ImageTexture.create_from_image(mask)


func save_baked_resources(scene_path: String) -> Error:
	# Keep large generated mesh/collider/mask data binary, and the authored scene readable.
	if not has_node("Baked/Surface") or not scene_path.begins_with("res://"):
		return ERR_INVALID_PARAMETER
	var directory := scene_path.get_basename() + ".terrain"
	DirAccess.make_dir_recursive_absolute(directory)
	var key := String(name).validate_filename()
	var mesh: Mesh = get_node("Baked/Surface").mesh
	var mesh_path := directory + "/" + key + ".res"
	var error := ResourceSaver.save(mesh, mesh_path)
	if error != OK:
		return error
	mesh.take_over_path(mesh_path)
	var collision: Shape3D = get_node("Baked/GroundCollision").get_child(0).shape
	var collision_path := directory + "/" + key + "_collision.res"
	error = ResourceSaver.save(collision, collision_path)
	if error == OK:
		collision.take_over_path(collision_path)
	return error


func path_weight(point: Vector2) -> float:
	var weight := 0.0
	for path in _paths:
		var points: PackedVector2Array = path.points
		var distance := point.distance_to(points[0])
		for i in range(1, points.size()):
			distance = minf(
				distance,
				point.distance_to(
					Geometry2D.get_closest_point_to_segment(point, points[i - 1], points[i])
				)
			)
		weight = maxf(
			weight,
			(
				1.0
				- smoothstep(
					path.width / 2 - path.soft / 2, path.width / 2 + path.soft / 2, distance
				)
			)
		)
	return weight


func _emit_top(points: PackedVector2Array, region: Dictionary) -> float:
	var area := polygon_area(points)
	if points.size() < 3 or area <= EPS:
		return 0.0
	var style: SurfaceStyle = region.get("style")
	if not _surface_groups.has(style):
		var top := SurfaceTool.new()
		top.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surface_groups[style] = top
	var surface: SurfaceTool = _surface_groups[style]
	var settings: Resource = style if style else surface_style if surface_style else area_set
	for i in range(1, points.size() - 1):
		# Clipping exactly on a cell edge can repeat a vertex or leave a collinear
		# fan triangle. Such faces cause spurious capsule recovery on steep ramps.
		if absf((points[i] - points[0]).cross(points[i + 1] - points[0])) <= EPS:
			continue
		for index in [0, i, i + 1]:
			var p := points[index]
			var normal := Vector3.UP
			if region.has("ramp_start"):
				var direction: Vector2 = region.ramp_end - region.ramp_start
				var gradient: Vector2 = (
					direction
					* (region.end_height - region.start_height)
					/ direction.length_squared()
				)
				normal = Vector3(-gradient.x, 1, -gradient.y).normalized()
			surface.set_normal(normal)
			surface.set_color(Color.BLACK)
			surface.set_uv(p / settings.texture_scale)
			surface.set_uv2(p / size + Vector2(.5, .5))
			surface.add_vertex(Vector3(p.x, region_height(region, p), p.y))
	return area


static func own_generated(node: Node, scene_owner: Node) -> void:
	node.owner = scene_owner
	for child in node.get_children():
		own_generated(child, scene_owner)


static func polygon_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in points.size():
		area += points[i].cross(points[(i + 1) % points.size()])
	return absf(area) * .5


static func clip_half_plane(
	points: PackedVector2Array, a: Vector2, b: Vector2, inside: bool
) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in points.size():
		var p := points[i]
		var q := points[(i + 1) % points.size()]
		var fp := (b - a).cross(p - a)
		var fq := (b - a).cross(q - a)
		var pin := fp >= 0 if inside else fp <= 0
		var qin := fq >= 0 if inside else fq <= 0
		if pin:
			result.append(p)
		if pin != qin and absf(fp - fq) > EPS * EPS:
			result.append(p.lerp(q, fp / (fp - fq)))
	return result


static func region_height(region: Dictionary, point: Vector2) -> float:
	if region.is_empty():
		return 0.0
	if not region.has("ramp_start"):
		return region.height
	var direction: Vector2 = region.ramp_end - region.ramp_start
	var t := clampf(
		(point - region.ramp_start).dot(direction) / maxf(.0001, direction.length_squared()), 0, 1
	)
	return lerpf(region.start_height, region.end_height, t)


func _emit_sides(surface: SurfaceTool, region: Dictionary, regions: Array[Dictionary]) -> void:
	var points: PackedVector2Array = region.polygon
	for edge in points.size():
		var a := points[edge]
		var b := points[(edge + 1) % points.size()]
		var line := b - a
		if line.length_squared() < EPS:
			continue
		var splits: Array[float] = [0.0, 1.0]
		for other in regions:
			if other.name == region.name:
				continue
			for p in other.polygon:
				if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) < .0001:
					var t: float = clampf((p - a).dot(line) / line.length_squared(), 0, 1)
					if not t in splits:
						splits.append(t)
		splits.sort()
		for i in range(splits.size() - 1):
			var start := a.lerp(b, splits[i])
			var end := a.lerp(b, splits[i + 1])
			# CCW X/Z polygon: its right-hand side is outside.
			var outside := (start + end) * .5 + Vector2(line.y, -line.x).normalized() * .001
			var adjacent := {}
			for other in regions:
				if (
					other.name != region.name
					and Geometry2D.is_point_in_polygon(outside, other.polygon)
				):
					adjacent = other
					break
			var top_a := region_height(region, start)
			var top_b := region_height(region, end)
			var low_a := region_height(adjacent, start)
			var low_b := region_height(adjacent, end)
			if top_a <= low_a + EPS and top_b <= low_b + EPS:
				continue
			var vertices := [
				Vector3(start.x, low_a, start.y),
				Vector3(end.x, low_b, end.y),
				Vector3(end.x, top_b, end.y),
				Vector3(start.x, top_a, start.y)
			]
			var normal := Vector3(line.y, 0, -line.x).normalized()
			for triangle in [[0, 1, 2], [0, 2, 3]]:
				var first: Vector3 = vertices[triangle[1]] - vertices[triangle[0]]
				var second: Vector3 = vertices[triangle[2]] - vertices[triangle[0]]
				if first.cross(second).length_squared() <= EPS * EPS:
					continue
				for index in triangle:
					surface.set_normal(normal)
					surface.add_vertex(vertices[index])
