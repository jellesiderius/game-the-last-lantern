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
@export_group("Kamer")
## Walls all around the ground, for interiors and dungeons. A LevelDoor standing on
## an edge cuts a doorway through the wall and the boundary.
@export var room_walls := false:
	set(value):
		room_walls = value
		request_bake()
@export_range(1, 6, .1, "suffix:m") var wall_height := 2.5:
	set(value):
		wall_height = value
		request_bake()
## The south and east walls face the camera and stay this low to keep the room readable.
@export_range(0, 3, .05, "suffix:m") var cutaway_height := .6:
	set(value):
		cutaway_height = value
		request_bake()
## Steen: walls in the cliff material. Huis: plastered walls with dark timber
## posts and a beam, low wooden walls at the front and a dark foundation.
@export_enum("Steen", "Huis") var room_look := 0:
	set(value):
		room_look = value
		request_bake()
@export_group("")
@export_storage var baked_signature := ""
@export_tool_button("Werk grond bij", "MeshInstance3D") var rebuild: Callable:
	get:
		return Callable(self, "bake")
var last_error := ""
var dirty := false
var bake_delay := 0.0
var _paths: Array[Dictionary] = []
var _surface_groups := {}
var _cliff_groups := {}
var _step_groups := {}
var _stair_collision: SurfaceTool
var _wall_collision: SurfaceTool
## Ground cell counts of the last bake; walls beside curved slopes split on this grid.
var _cells := Vector2i.ONE
var _fallback_style: SurfaceStyle
const EPS := .000001
const MAX_HEIGHT := 100.0
## Every plateau and stair end snaps to this; fixed so no global edit re-snaps a level.
const HEIGHT_STEP := .5
const PATH_FRINGE := .6
## Height of one visible step; the collision stays a smooth slope underneath.
const STAIR_RISE := .25
## Rise per metre of run for builder stairs and plain slopes.
const STAIR_SLOPE := .75
const RAMP_SLOPE := .45
## Older ramps are only stretched once they would pass this slope.
const MAX_RAMP_SLOPE := .9
## Steepest walkable bridge deck.
const BRIDGE_SLOPE := .6
## Generated surfaces snap to a 0.1 mm grid (inverse cell size).
const GRID_INV := 10000.0
## Stone curb along the sides of slopes (visual only).
const CURB_HEIGHT := .12
const BOUNDARY_THICKNESS := .5
const ROOM_WALL_THICKNESS := .35
## Floor length beyond a doorway, covering the short walk out during a transition.
const DOORWAY_DEPTH := 1.6
## Fraction of a slope's run eased at each end, and the steepest slope easing may reach.
const SLOPE_EASE := .35
## Enemies climb up to about 40 degrees; slopes already that steep stay linear.
const SLOPE_EASE_LIMIT := .8
const CURB_WIDTH := .2


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
	var plateaus: Array[Dictionary] = []
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
			plateaus.append(
				{
					"polygon": points,
					"height": snap_height(child.height + child.position.y),
					"name": child.name,
					"style": child.surface_style
				}
			)
	var ramps: Array[Dictionary] = []
	for child in get_children():
		if child is LevelRamp and child.curve and child.curve.point_count == 2:
			var start: Vector3 = child.transform * child.curve.get_point_position(0)
			var end: Vector3 = child.transform * child.curve.get_point_position(1)
			var a := Vector2(start.x, start.z)
			var b := Vector2(end.x, end.z)
			# An end lying exactly on a plateau edge makes the cut touch that edge, which
			# leaves the doorway of the flight as a wall; overlap the edge a little instead.
			var raw_a := a
			a = _clear_of_edges(a, b, plateaus)
			b = _clear_of_edges(b, raw_a, plateaus)
			var side: Vector2 = (b - a).normalized().orthogonal() * child.width / 2
			var points := PackedVector2Array([a - side, b - side, b + side, a + side])
			if Geometry2D.is_polygon_clockwise(points):
				points.reverse()
			var low := snap_height(start.y)
			var high := snap_height(end.y)
			if child.follow_ground:
				low = ramp_end_height(a, b, plateaus)
				high = ramp_end_height(b, a, plateaus)
			ramps.append(
				{
					"polygon": points,
					"height": maxf(low, high),
					"name": child.name,
					"style": child.surface_style,
					"stairs": child.stairs,
					"ramp_start": a,
					"ramp_end": b,
					"start_height": low,
					"end_height": high
				}
			)
	# A bridge that starts at a plateau edge squares that edge: a small landing at the
	# plateau height on the plateau side of the bridge end, and the plateau cut away
	# under the deck on the other side, so no corner of grass pokes through the planks
	# when the bridge meets a bent or angled edge.
	var landings: Array[Dictionary] = []
	var bridge_cuts: Array[PackedVector2Array] = []
	for child in get_children():
		if not child is LevelBridge or not child.curve or child.curve.point_count != 2:
			continue
		var start: Vector3 = child.transform * child.curve.get_point_position(0)
		var end: Vector3 = child.transform * child.curve.get_point_position(1)
		var ends := [Vector2(start.x, start.z), Vector2(end.x, end.z)]
		for i in 2:
			var here: Vector2 = ends[i]
			var there: Vector2 = ends[1 - i]
			if here.distance_to(there) < 1.0:
				continue
			var top := ramp_end_height(here, there, plateaus)
			if top <= EPS:
				continue
			var onward := (here - there).normalized()
			# Only at an edge: well under the deck the land must already be lower.
			if height_under(here - onward * 1.5, plateaus) >= top - EPS:
				continue
			# Only where that edge meets the bridge at a slant; a square edge needs nothing.
			var nearest := INF
			var edge_direction := Vector2.ZERO
			for plateau in plateaus:
				var outline: PackedVector2Array = plateau.polygon
				for k in outline.size():
					var a := outline[k]
					var b := outline[(k + 1) % outline.size()]
					var distance := here.distance_to(Geometry2D.get_closest_point_to_segment(here, a, b))
					if distance < nearest and a.distance_to(b) > EPS:
						nearest = distance
						edge_direction = (b - a).normalized()
			if nearest > 1.5 or absf(edge_direction.dot(onward)) < .17:
				continue
			var across: Vector2 = onward.orthogonal() * (float(child.width) / 2 + .2)
			var front := here + onward * 1.0
			var landing := PackedVector2Array([here - across, front - across, front + across, here + across])
			if Geometry2D.is_polygon_clockwise(landing):
				landing.reverse()
			landings.append(
				{"polygon": landing, "height": top, "name": String(child.name) + "Landing", "style": null, "landing": true}
			)
			var reach := minf(3.0, here.distance_to(there) * .45)
			var far := here - onward * reach
			var cut := PackedVector2Array([far - across, here - across, here + across, far + across])
			if Geometry2D.is_polygon_clockwise(cut):
				cut.reverse()
			bridge_cuts.append(cut)
	plateaus.append_array(landings)
	# Higher plateaus and ramps cut into lower plateaus, so regions never overlap:
	# a hill on a hill, or stairs set into a cliff.
	var result: Array[Dictionary] = []
	for i in plateaus.size():
		var cutters: Array[PackedVector2Array] = []
		for j in plateaus.size():
			if (
				plateaus[j].height > plateaus[i].height
				or (j < i and is_equal_approx(plateaus[j].height, plateaus[i].height))
			):
				cutters.append(plateaus[j].polygon)
		for ramp in ramps:
			cutters.append(ramp.polygon)
		if not plateaus[i].get("landing", false):
			cutters.append_array(bridge_cuts)
		var pieces: Array[PackedVector2Array] = [plateaus[i].polygon]
		for cutter in cutters:
			var next: Array[PackedVector2Array] = []
			for piece in pieces:
				next.append_array(cut(piece, cutter))
			pieces = next
		for piece in pieces:
			# Cutting stairs or bridges into an edge that runs almost along them leaves
			# hairline slivers; drop those, and doubled points, so one sliver never stops
			# the whole bake.
			var clean := PackedVector2Array()
			for point in piece:
				if clean.is_empty() or clean[-1].distance_to(point) > .005:
					clean.append(point)
			if clean.size() > 2 and clean[0].distance_to(clean[-1]) <= .005:
				clean.remove_at(clean.size() - 1)
			if clean.size() < 3 or polygon_area(clean) <= .01:
				continue
			if Geometry2D.triangulate_polygon(clean).is_empty():
				continue
			if Geometry2D.is_polygon_clockwise(clean):
				clean.reverse()
			var region: Dictionary = plateaus[i].duplicate()
			region.polygon = clean
			result.append(region)
	# Water replaces the clicked elevation, including plateau tops. Elevated water
	# is clipped to supporting surfaces; ground water keeps raised land as islands.
	var bounds := PackedVector2Array(
		[-size / 2, Vector2(size.x / 2, -size.y / 2), size / 2, Vector2(-size.x / 2, size.y / 2)]
	)
	var waters: Array[Dictionary] = []
	for child in get_children():
		if not child is LevelWater:
			continue
		var clipped := Geometry2D.intersect_polygons(child.outline(), bounds)
		for shore in clipped:
			if polygon_area(shore) <= EPS:
				continue
			if Geometry2D.is_polygon_clockwise(shore):
				shore.reverse()
			var water := {
				"polygon": shore,
				"height": child.elevation(),
				"name": child.name,
				"style": null,
				"water": true,
				"shore": shore,
				"depth": child.depth,
				"bank": child.bank
			}
			var supported: Array[Dictionary] = []
			if is_zero_approx(water.height):
				var pieces: Array[PackedVector2Array] = [shore]
				for obstacle in plateaus + ramps:
					pieces = _cut_pieces(pieces, obstacle.polygon)
				for piece in pieces:
					var region: Dictionary = water.duplicate()
					region.polygon = piece
					supported.append(region)
			for plateau in result:
				if not is_equal_approx(plateau.height, water.height):
					continue
				for piece in Geometry2D.intersect_polygons(shore, plateau.polygon):
					var region: Dictionary = water.duplicate()
					region.polygon = piece
					region.style = plateau.style
					supported.append(region)
			for region in supported:
				var pieces: Array[PackedVector2Array] = [region.polygon]
				for previous in waters:
					pieces = _cut_pieces(pieces, previous.polygon)
				for piece in pieces:
					if polygon_area(piece) <= EPS:
						continue
					if Geometry2D.is_polygon_clockwise(piece):
						piece.reverse()
					var part: Dictionary = region.duplicate()
					part.polygon = piece
					waters.append(part)
	var dry: Array[Dictionary] = []
	for plateau in result:
		var pieces: Array[PackedVector2Array] = [plateau.polygon]
		for water in waters:
			pieces = _cut_pieces(pieces, water.polygon)
		for piece in pieces:
			if polygon_area(piece) <= EPS:
				continue
			var region: Dictionary = plateau.duplicate()
			region.polygon = piece
			dry.append(region)
	result = dry
	result.append_array(waters)
	result.append_array(ramps)
	return result


static func _cut_pieces(
	pieces: Array[PackedVector2Array], cutter: PackedVector2Array
) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for piece in pieces:
		result.append_array(cut(piece, cutter))
	return result


## Removes cutter from piece. A cutter fully inside would leave a hole, which the
## mesher cannot express, so the piece is split through the cutter first.
static func cut(piece: PackedVector2Array, cutter: PackedVector2Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var clipped := Geometry2D.clip_polygons(piece, cutter)
	if not _has_hole(clipped):
		result.append_array(clipped)
		return result
	var center := Vector2.ZERO
	for point in cutter:
		center += point
	center /= cutter.size()
	var box := Rect2(piece[0], Vector2.ZERO)
	for point in piece:
		box = box.expand(point)
	box = box.grow(1)
	for half in [
		Rect2(box.position, Vector2(center.x - box.position.x, box.size.y)),
		Rect2(Vector2(center.x, box.position.y), Vector2(box.end.x - center.x, box.size.y))
	]:
		var rect := PackedVector2Array(
			[
				half.position,
				Vector2(half.end.x, half.position.y),
				half.end,
				Vector2(half.position.x, half.end.y)
			]
		)
		for part in Geometry2D.intersect_polygons(piece, rect):
			var kept := Geometry2D.clip_polygons(part, cutter)
			if not _has_hole(kept):
				result.append_array(kept)
	return result


static func _has_hole(parts: Array[PackedVector2Array]) -> bool:
	for i in parts.size():
		for j in parts.size():
			if i != j and Geometry2D.is_point_in_polygon(parts[i][0], parts[j]):
				return true
	return false


## Height for a ramp end, sampled just beyond the end (away from the other end).
## Ends usually sit exactly on a plateau edge, where "on the point" is ambiguous:
## beyond the high end is the plateau, beyond the low end is the ground below.
static func ramp_end_height(end: Vector2, other: Vector2, plateaus: Array[Dictionary]) -> float:
	return height_under(end + (end - other).normalized() * .05, plateaus)


## Highest plateau under a point, ignoring ramps; plain ground is 0.
## Moves a flight end that sits on a plateau edge 5 cm further out, away from the other end.
static func _clear_of_edges(point: Vector2, other: Vector2, plateaus: Array[Dictionary]) -> Vector2:
	if point.distance_to(other) < .2:
		return point
	for plateau in plateaus:
		var outline: PackedVector2Array = plateau.polygon
		for k in outline.size():
			var a := outline[k]
			var b := outline[(k + 1) % outline.size()]
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b)) < .02:
				return point + (point - other).normalized() * .05
	return point


static func height_under(point: Vector2, plateaus: Array[Dictionary]) -> float:
	var height := 0.0
	for plateau in plateaus:
		if Geometry2D.is_point_in_polygon(point, plateau.polygon):
			height = maxf(height, plateau.height)
	return height


func snap_height(value: float) -> float:
	return snappedf(maxf(0.0, value), HEIGHT_STEP)


## One fallback chain: region style, then terrain style, then the area set default.
func style_for(region_style: SurfaceStyle) -> SurfaceStyle:
	if region_style:
		return region_style
	if surface_style:
		return surface_style
	if area_set and area_set.default_surface:
		return area_set.default_surface
	if _fallback_style == null:
		_fallback_style = SurfaceStyle.new()
	return _fallback_style


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
		"surface_styles_v8",
		size,
		resolution,
		enclose_bounds,
		regions,
		style_for(null).signature(),
		room_walls,
		wall_height,
		cutaway_height,
		room_look,
		_door_openings()
	]
	for child in get_children():
		if child is LevelPath and child.curve:
			data.append(
				[child.transform, child.width, child.edge_softness, child.curve.get_baked_points()]
			)
	return str(data).sha256_text()


func bake() -> bool:
	dirty = false
	_sync_ramp_heights()
	_sync_bridge_heights()
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
	_cells = Vector2i(nx, nz)
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
	var mask := _bake_path_mask(regions)
	# The visual mesh shows real steps; the collision mesh keeps stairs as slopes.
	var mesh := ArrayMesh.new()
	var collision_mesh := ArrayMesh.new()
	for style in _surface_groups:
		_surface_groups[style].set_material(_ground_material(style_for(style), mask))
		_surface_groups[style].commit(mesh)
		_surface_groups[style].commit(collision_mesh)
	_step_groups.clear()
	for region in regions:
		if region.get("stairs", false):
			_emit_steps(region)
	for style in _step_groups:
		_step_groups[style].set_material(_ground_material(style_for(style), mask))
		_step_groups[style].commit(mesh)
	_step_groups.clear()
	if _stair_collision:
		_stair_collision.commit(collision_mesh)
		_stair_collision = null
	_cliff_groups.clear()
	for region in regions:
		_emit_sides(region, regions)
	for style in _cliff_groups:
		var settings := style_for(style)
		var cliff := ShaderMaterial.new()
		cliff.shader = preload("res://shaders/level_cliff.gdshader")
		cliff.set_shader_parameter("cliff_texture", settings.cliff_texture)
		cliff.set_shader_parameter("has_cliff_texture", settings.cliff_texture != null)
		cliff.set_shader_parameter("cliff_texture_scale", settings.cliff_texture_scale)
		cliff.set_shader_parameter("block_height", HEIGHT_STEP)
		cliff.set_shader_parameter("cliff_pattern", settings.cliff_pattern)
		_cliff_groups[style].set_material(cliff)
		_cliff_groups[style].commit(mesh)
	_cliff_groups.clear()
	if room_walls:
		_emit_room_walls(mesh)
	# Collision walls follow the smooth surfaces: no step sawtooth, rim or caps to snag on.
	if _wall_collision:
		_wall_collision.commit(collision_mesh)
		_wall_collision = null
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
	shape.shape = collision_mesh.create_trimesh_shape()
	body.add_child(shape)
	if enclose_bounds or room_walls:
		var boundary_height := maxf(8.0, wall_height + 1.0)
		for region in regions:
			boundary_height = maxf(boundary_height, region.height + 4)
		for segment in _boundary_segments(BOUNDARY_THICKNESS):
			var wall := CollisionShape3D.new()
			wall.name = "Boundary%d" % body.get_child_count()
			var box := BoxShape3D.new()
			box.size = Vector3(segment.size.x, boundary_height, segment.size.y)
			wall.shape = box
			wall.position = Vector3(segment.centre.x, boundary_height / 2 - 1, segment.centre.y)
			body.add_child(wall)
		# Doorways get a short floor and a back stop, so walking out never drops the player.
		for opening in _door_openings():
			var outward := _side_normal(opening.side)
			var across := Vector2(outward.y, outward.x).abs()
			var edge := _edge_point(opening.side, opening.along)
			for piece in [
				[edge + outward * DOORWAY_DEPTH / 2, Vector3(0, -.1, 0), .2],
				[edge + outward * (DOORWAY_DEPTH + .25), Vector3(0, boundary_height / 2 - 1, 0), boundary_height]
			]:
				var stop := CollisionShape3D.new()
				stop.name = "Doorway%d" % body.get_child_count()
				var shape_box := BoxShape3D.new()
				var span: Vector2 = across * opening.half * 2 + outward.abs() * (DOORWAY_DEPTH if piece[2] < 1 else .5)
				shape_box.size = Vector3(span.x, piece[2], span.y)
				stop.shape = shape_box
				stop.position = Vector3(piece[0].x, 0, piece[0].y) + piece[1]
				body.add_child(stop)
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
	for child in get_children():
		if child is LevelWater:
			child.rebuild()
		elif child is LevelBoundary:
			child.request_bake()
	dirty = false
	update_configuration_warnings()
	if Engine.is_editor_hint() and is_inside_tree():
		EditorInterface.mark_scene_as_unsaved()
	return true


## Ground-following ramps store the heights they currently resolve to, so gizmos,
## navigation and anything reading the curve see the real ends. Their length is
## refitted to the rise first: stairs attached to a plateau that is raised or
## lowered grow or shrink from their anchored end instead of turning too steep.
func _sync_ramp_heights() -> void:
	for pass_index in 2:
		for region in outlines():
			if not region.has("ramp_start"):
				continue
			var ramp := get_node_or_null(NodePath(String(region.name))) as LevelRamp
			if ramp == null or not ramp.follow_ground or ramp.curve == null:
				continue
			var edited := ramp.curve.duplicate() as Curve3D
			var changed := false
			if pass_index == 0:
				var anchor := clampi(ramp.anchor_end, 0, 1)
				var fixed := edited.get_point_position(anchor)
				var free := edited.get_point_position(1 - anchor)
				var run := Vector2(free.x - fixed.x, free.z - fixed.z)
				var rise := absf(region.end_height - region.start_height)
				var wanted := run.length()
				if ramp.fit_length and rise > EPS:
					wanted = rise / (STAIR_SLOPE if ramp.stairs else RAMP_SLOPE)
				elif rise / maxf(run.length(), .001) > MAX_RAMP_SLOPE:
					wanted = rise / MAX_RAMP_SLOPE
				if run.length() > .001 and absf(wanted - run.length()) > .001:
					var moved := run.normalized() * wanted
					free.x = fixed.x + moved.x
					free.z = fixed.z + moved.y
					edited.set_point_position(1 - anchor, free)
					changed = true
			else:
				for i in 2:
					var point := edited.get_point_position(i)
					var height: float = region.start_height if i == 0 else region.end_height
					var wanted_y := height - ramp.position.y
					if not is_equal_approx(point.y, wanted_y):
						point.y = wanted_y
						edited.set_point_position(i, point)
						changed = true
			if changed:
				ramp.curve = edited


## Bridges that follow the ground keep each deck end on the plateau (or ground) it rests on.
func _sync_bridge_heights() -> void:
	var bridges: Array[LevelBridge] = []
	for child in get_children():
		if (
			child is LevelBridge
			and child.follow_ground
			and child.curve
			and child.curve.point_count == 2
		):
			bridges.append(child)
	if bridges.is_empty():
		return
	var plateaus: Array[Dictionary] = []
	for region in outlines():
		if not region.has("ramp_start"):
			plateaus.append(region)
	for bridge in bridges:
		var a: Vector3 = bridge.transform * bridge.curve.get_point_position(0)
		var b: Vector3 = bridge.transform * bridge.curve.get_point_position(1)
		var ends := [Vector2(a.x, a.z), Vector2(b.x, b.z)]
		var edited := bridge.curve.duplicate() as Curve3D
		var changed := false
		for i in 2:
			var point := edited.get_point_position(i)
			var wanted := ramp_end_height(ends[i], ends[1 - i], plateaus) - bridge.position.y
			if not is_equal_approx(point.y, wanted):
				point.y = wanted
				edited.set_point_position(i, point)
				changed = true
		if changed:
			bridge.curve = edited


func _bake_path_mask(regions: Array[Dictionary]) -> ImageTexture:
	# A filtered mask follows the exact curve distances, independently of mesh cells.
	# Rasterize only each segment's footprint; empty ground costs no distance work.
	var pixels_per_meter := minf(32, 2048.0 / maxf(size.x, size.y))
	var dimensions := Vector2i(
		maxi(1, ceili(size.x * pixels_per_meter)), maxi(1, ceili(size.y * pixels_per_meter))
	)
	var pixel_size := size / Vector2(dimensions)
	var data := PackedByteArray()
	data.resize(dimensions.x * dimensions.y * 2)
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
		var outer := radius + maxf(feather / 2, PATH_FRINGE)
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
					var index := (y * dimensions.x + x) * 2
					if data[index] == 255:
						continue
					var point := (Vector2(x, y) + Vector2(.5, .5)) * pixel_size - size / 2
					var distance := point.distance_to(
						Geometry2D.get_closest_point_to_segment(point, a, b)
					)
					# 0.5 exactly at the path border; the outer half fades over the fringe.
					var coverage := (
						1.0 - .5 * smoothstep(radius - feather / 2, radius, distance)
						if distance < radius
						else .5 * (1.0 - smoothstep(radius, outer, distance))
					)
					var weight := roundi(coverage * 255)
					data[index] = maxi(data[index], weight)
	data = _bake_cliff_shadow(data, dimensions, pixel_size, regions)
	var mask := Image.create_from_data(dimensions.x, dimensions.y, false, Image.FORMAT_RG8, data)
	mask.generate_mipmaps()
	return ImageTexture.create_from_image(mask)


## Green channel: a soft shadow on lower ground along every plateau edge.
func _bake_cliff_shadow(
	data: PackedByteArray, dimensions: Vector2i, pixel_size: Vector2, regions: Array[Dictionary]
) -> PackedByteArray:
	var reach := 1.3
	var bounds: Array[Rect2] = []
	for region in regions:
		var box := Rect2(region.polygon[0], Vector2.ZERO)
		for point in region.polygon:
			box = box.expand(point)
		bounds.append(box)
	for r in regions.size():
		var region: Dictionary = regions[r]
		if region.has("ramp_start"):
			continue
		var polygon: PackedVector2Array = region.polygon
		for edge in polygon.size():
			var a := polygon[edge]
			var b := polygon[(edge + 1) % polygon.size()]
			var low := (
				Vector2i(((a.min(b) - Vector2.ONE * reach + size / 2) / pixel_size).floor())
				. max(Vector2i.ZERO)
			)
			var high := (
				Vector2i(((a.max(b) + Vector2.ONE * reach + size / 2) / pixel_size).ceil())
				. min(dimensions - Vector2i.ONE)
			)
			for y in range(low.y, high.y + 1):
				for x in range(low.x, high.x + 1):
					var point := (Vector2(x, y) + Vector2(.5, .5)) * pixel_size - size / 2
					var distance := point.distance_to(
						Geometry2D.get_closest_point_to_segment(point, a, b)
					)
					if distance >= reach:
						continue
					var index := (y * dimensions.x + x) * 2 + 1
					var weight := roundi(pow(1 - distance / reach, 1.4) * 255)
					if weight <= data[index] or Geometry2D.is_point_in_polygon(point, polygon):
						continue
					var here := 0.0
					for o in regions.size():
						if (
							bounds[o].grow(.01).has_point(point)
							and Geometry2D.is_point_in_polygon(point, regions[o].polygon)
						):
							here = maxf(here, region_height(regions[o], point))
					if here < region.height - EPS:
						data[index] = weight
	# Packed arrays are copied into functions; hand the result back explicitly.
	return data


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


func _ground_material(settings: SurfaceStyle, mask: Texture2D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/level_ground.gdshader")
	for key in ["ground_color", "path_color", "ground_texture", "path_texture"]:
		material.set_shader_parameter(key, settings.get(key))
	material.set_shader_parameter("has_ground_texture", settings.ground_texture != null)
	material.set_shader_parameter("has_path_texture", settings.path_texture != null)
	material.set_shader_parameter("ground_pattern", settings.pattern)
	material.set_shader_parameter("texture_scale", settings.texture_scale)
	# Steps are cut stone: a lighter version of the cliff, not the (grassy) lip colour.
	material.set_shader_parameter("stair_color", settings.cliff_color.lightened(.18))
	material.set_shader_parameter("path_mask", mask)
	material.set_shader_parameter("has_path_mask", true)
	return material


static func stair_steps(region: Dictionary) -> int:
	return maxi(1, roundi(absf(region.end_height - region.start_height) / STAIR_RISE))


## Surface height for walls: stairs report the tread above a point, others their plane.
static func side_height(region: Dictionary, point: Vector2) -> float:
	if not region.get("stairs", false):
		return region_height(region, point)
	var run: Vector2 = region.ramp_end - region.ramp_start
	var t := clampf((point - region.ramp_start).dot(run) / maxf(.0001, run.length_squared()), 0, 1)
	var steps := stair_steps(region)
	var k := clampi(floori(t * steps), 0, steps - 1)
	return maxf(
		lerpf(region.start_height, region.end_height, float(k) / steps),
		lerpf(region.start_height, region.end_height, float(k + 1) / steps)
	)


## Treads and risers for one flight, climbing from its low end to its high end.
func _emit_steps(region: Dictionary) -> void:
	var style: SurfaceStyle = region.get("style")
	if not _step_groups.has(style):
		var created := SurfaceTool.new()
		created.begin(Mesh.PRIMITIVE_TRIANGLES)
		created.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
		_step_groups[style] = created
	var surface: SurfaceTool = _step_groups[style]
	var settings := style_for(style)
	var low: Vector2 = region.ramp_start
	var high: Vector2 = region.ramp_end
	var low_height: float = region.start_height
	var high_height: float = region.end_height
	if low_height > high_height:
		var swap := low
		low = high
		high = swap
		low_height = region.end_height
		high_height = region.start_height
	var direction := (high - low).normalized()
	var side := direction.orthogonal()
	var half := absf((region.polygon[0] - low).dot(side))
	var steps := stair_steps(region)
	var rise := (high_height - low_height) / steps
	var back := Vector3(-direction.x, 0, -direction.y)
	for i in steps:
		var front := low.lerp(high, float(i) / steps)
		var rear := low.lerp(high, float(i + 1) / steps)
		var below := low_height + i * rise
		var tread := below + rise
		var corners := [
			front - side * half, front + side * half, rear + side * half, rear - side * half
		]
		_step_quad(
			surface,
			settings,
			[
				Vector3(corners[0].x, below, corners[0].y),
				Vector3(corners[1].x, below, corners[1].y),
				Vector3(corners[1].x, tread, corners[1].y),
				Vector3(corners[0].x, tread, corners[0].y)
			],
			back,
			true
		)
		_step_quad(
			surface,
			settings,
			[
				Vector3(corners[0].x, tread, corners[0].y),
				Vector3(corners[1].x, tread, corners[1].y),
				Vector3(corners[2].x, tread, corners[2].y),
				Vector3(corners[3].x, tread, corners[3].y)
			],
			Vector3.UP,
			false
		)


func _step_quad(
	surface: SurfaceTool, settings: SurfaceStyle, vertices: Array, normal: Vector3, riser: bool
) -> void:
	for index in _front_order(vertices, normal):
		var vertex: Vector3 = vertices[index]
		var flat := Vector2(vertex.x, vertex.z)
		surface.set_normal(normal)
		surface.set_color(Color.BLACK)
		surface.set_custom(0, Color(1, 1.0 if riser else 0.0, 0, 0))
		surface.set_uv(flat / settings.texture_scale)
		surface.set_uv2(flat / size + Vector2(.5, .5))
		surface.add_vertex(vertex)


## Triangle indices for a quad, wound so its front face looks along normal.
static func _front_order(vertices: Array, normal: Vector3) -> Array:
	var first: Vector3 = vertices[1] - vertices[0]
	var second: Vector3 = vertices[2] - vertices[0]
	# Godot treats clockwise (seen from the front) as the front face.
	if first.cross(second).dot(normal) > 0:
		return [0, 2, 1, 0, 3, 2]
	return [0, 1, 2, 0, 2, 3]


func _emit_top(points: PackedVector2Array, region: Dictionary) -> float:
	var area := polygon_area(points)
	if points.size() < 3 or area <= EPS:
		return 0.0
	# Snap to a 0.1 mm grid: clipped neighbours then share exact vertices, and
	# slivers collapse to nothing instead of surviving as zero-area float faces.
	var snapped := PackedVector2Array()
	for point in points:
		var grid := (point * GRID_INV).round() / GRID_INV
		if snapped.is_empty() or grid != snapped[snapped.size() - 1]:
			snapped.append(grid)
	if snapped.size() > 1 and snapped[0] == snapped[snapped.size() - 1]:
		snapped.remove_at(snapped.size() - 1)
	if snapped.size() < 3:
		return area
	points = snapped
	var style: SurfaceStyle = region.get("style")
	var surface: SurfaceTool
	if region.get("stairs", false):
		# Stairs are drawn as steps by _emit_steps; their slope is only walked on.
		if _stair_collision == null:
			_stair_collision = SurfaceTool.new()
			_stair_collision.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface = _stair_collision
	else:
		if not _surface_groups.has(style):
			var top := SurfaceTool.new()
			top.begin(Mesh.PRIMITIVE_TRIANGLES)
			_surface_groups[style] = top
		surface = _surface_groups[style]
	var settings := style_for(style)
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
				var along := clampf(
					(
						(p - region.ramp_start).dot(direction)
						/ maxf(.0001, direction.length_squared())
					),
					0,
					1
				)
				# The local steepness of the eased profile gives soft shading over the bend.
				var gradient: Vector2 = (
					direction
					* (region.end_height - region.start_height)
					* ramp_profile(region, along).y
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
	if region.has("water"):
		# The bed eases down from the shore; distances use the whole shore line, so
		# cutting the water around an island never raises a ridge through it.
		return region.height + LevelWater.bed_height(region.shore, region.depth, region.bank, point)
	if not region.has("ramp_start"):
		return region.height
	var direction: Vector2 = region.ramp_end - region.ramp_start
	var t := clampf(
		(point - region.ramp_start).dot(direction) / maxf(.0001, direction.length_squared()), 0, 1
	)
	return lerpf(region.start_height, region.end_height, ramp_profile(region, t).x)


## Normalised height (x) and relative steepness (y) along a ramp at t in 0..1.
## Slopes without treads ease in and out at both ends, so they meet the plateau and
## the ground tangentially instead of folding at a hard crease; stairs stay linear.
static func ramp_profile(region: Dictionary, t: float) -> Vector2:
	if region.get("stairs", false):
		return Vector2(t, 1.0)
	var run: float = (region.ramp_end - region.ramp_start).length()
	var average := absf(region.end_height - region.start_height) / maxf(run, .001)
	# Easing steepens the middle; keep that below the walkable limit.
	var blend := clampf(1.0 - average / SLOPE_EASE_LIMIT, 0.0, SLOPE_EASE)
	if blend <= .001:
		return Vector2(t, 1.0)
	var middle := 1.0 / (1.0 - blend)
	if t < blend:
		return Vector2(middle * t * t / (2.0 * blend), middle * t / blend)
	if t > 1.0 - blend:
		var rest := 1.0 - t
		return Vector2(1.0 - middle * rest * rest / (2.0 * blend), middle * rest / blend)
	return Vector2(middle * (t - blend * .5), middle)


func _emit_sides(region: Dictionary, regions: Array[Dictionary]) -> void:
	var style: SurfaceStyle = region.get("style")
	var settings := style_for(style)
	var wall_color := settings.cliff_color.srgb_to_linear()
	var rim_color := settings.cliff_rim_color.srgb_to_linear()
	var curb_color := settings.cliff_color.lightened(.15).srgb_to_linear()
	var rim_height := settings.cliff_rim_height
	var overhang := rim_height * .5
	var bevel := rim_height * .35
	var points: PackedVector2Array = region.polygon
	# Mitred corner offsets keep the overhanging rim closed around every corner.
	var count := points.size()
	var normals := PackedVector2Array()
	for e in count:
		var span := points[(e + 1) % count] - points[e]
		normals.append(Vector2(span.y, -span.x).normalized())
	var miters := PackedVector2Array()
	for v in count:
		var bisector := (normals[(v - 1 + count) % count] + normals[v]).normalized()
		if bisector.is_zero_approx():
			bisector = normals[v]
		miters.append(bisector / maxf(bisector.dot(normals[v]), .5))
	for edge in points.size():
		var a := points[edge]
		var b := points[(edge + 1) % points.size()]
		var line := b - a
		if line.length_squared() < EPS:
			continue
		# The first and last riser already close a flight's low and high ends;
		# only its sides get walls.
		if region.get("stairs", false):
			var run: Vector2 = region.ramp_end - region.ramp_start
			if absf(line.normalized().dot(run.normalized())) < .5:
				continue
		var splits: Array[float] = [0.0, 1.0]
		# Pieces of one plateau (split around a hill or stairs) are neighbours too,
		# so compare by identity, not by name.
		for other in regions:
			if is_same(other, region):
				continue
			for p in other.polygon:
				if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) < .0001:
					var t: float = clampf((p - a).dot(line) / line.length_squared(), 0, 1)
					if not t in splits:
						splits.append(t)
		# Walls beside stairs follow the step profile, so split them at every step.
		for other in regions:
			if not other.get("stairs", false):
				continue
			var run: Vector2 = other.ramp_end - other.ramp_start
			var across := run.normalized().orthogonal()
			var half := absf((other.polygon[0] - other.ramp_start).dot(across)) + .01
			var denominator := line.dot(run)
			if absf(denominator) < EPS:
				continue
			var steps := stair_steps(other)
			for k in range(1, steps):
				var boundary: Vector2 = other.ramp_start + run * (float(k) / steps)
				var t := (boundary - a).dot(run) / denominator
				if t <= 0 or t >= 1 or t in splits:
					continue
				if absf((a + line * t - boundary).dot(across)) <= half:
					splits.append(t)
		# Beside a curved slope, walls split on the ground's own cell grid so their top
		# edge matches the surface vertex for vertex: no gaps and no straight chords.
		if _near_eased_ramp(a, b, regions):
			for axis in 2:
				var span: float = line[axis]
				if absf(span) < EPS:
					continue
				for k in range(1, _cells[axis]):
					var grid_line: float = -size[axis] / 2 + k * size[axis] / _cells[axis]
					var t: float = (grid_line - a[axis]) / span
					if t > EPS and t < 1 - EPS and not t in splits:
						splits.append(t)
		splits.sort()
		# CCW X/Z polygon: its right-hand side is outside.
		var out := Vector2(line.y, -line.x).normalized()
		var normal := Vector3(out.x, 0, out.y)
		for i in range(splits.size() - 1):
			var start := a.lerp(b, splits[i])
			var end := a.lerp(b, splits[i + 1])
			var outside := (start + end) * .5 + out * .001
			var adjacent := {}
			for other in regions:
				if (
					not is_same(other, region)
					and Geometry2D.is_point_in_polygon(outside, other.polygon)
				):
					adjacent = other
					break
			_collision_wall(
				start,
				end,
				region_height(adjacent, start),
				region_height(adjacent, end),
				region_height(region, start),
				region_height(region, end)
			)
			var middle := (start + end) * .5
			var top_a := (
				side_height(region, middle)
				if region.get("stairs", false)
				else region_height(region, start)
			)
			var top_b := (
				side_height(region, middle)
				if region.get("stairs", false)
				else region_height(region, end)
			)
			var low_a := (
				side_height(adjacent, middle)
				if adjacent.get("stairs", false)
				else region_height(adjacent, start)
			)
			var low_b := (
				side_height(adjacent, middle)
				if adjacent.get("stairs", false)
				else region_height(adjacent, end)
			)
			if top_a <= low_a + EPS and top_b <= low_b + EPS:
				continue
			# Created on first wall only: committing an empty SurfaceTool is an error.
			if not _cliff_groups.has(style):
				var created := SurfaceTool.new()
				created.begin(Mesh.PRIMITIVE_TRIANGLES)
				_cliff_groups[style] = created
			var surface: SurfaceTool = _cliff_groups[style]
			if region.has("ramp_start"):
				if region.get("stairs", false):
					# Stair cheeks: plain stepped walls; the treads close their top.
					_quad(
						surface,
						[
							Vector3(start.x, low_a, start.y),
							Vector3(end.x, low_b, end.y),
							Vector3(end.x, top_b, end.y),
							Vector3(start.x, top_a, start.y)
						],
						normal,
						wall_color,
						0.0
					)
				else:
					_emit_curb(
						surface, region, start, end, low_a, low_b, normal, wall_color, curb_color
					)
				continue
			# Plateau walls keep a rim of constant thickness. Where the drop becomes
			# shallower than the rim (beside a slope) the rim is cut off square there
			# instead of tapering to a point.
			var pieces := [[start, end, top_a, top_b, low_a, low_b, splits[i], splits[i + 1]]]
			var drop_a := top_a - low_a
			var drop_b := top_b - low_b
			if (drop_a - rim_height) * (drop_b - rim_height) < 0:
				var cut := (rim_height - drop_a) / (drop_b - drop_a)
				var cut_point := start.lerp(end, cut)
				var cut_top := lerpf(top_a, top_b, cut)
				var cut_low := lerpf(low_a, low_b, cut)
				var cut_t := lerpf(splits[i], splits[i + 1], cut)
				pieces = [
					[start, cut_point, top_a, cut_top, low_a, cut_low, splits[i], cut_t],
					[cut_point, end, cut_top, top_b, cut_low, low_b, cut_t, splits[i + 1]]
				]
			var offset_from: Vector2 = miters[edge]
			var offset_to: Vector2 = miters[(edge + 1) % count]
			for piece in pieces:
				_emit_wall_piece(
					surface,
					piece,
					offset_from,
					offset_to,
					normal,
					wall_color,
					rim_color,
					rim_height,
					overhang,
					bevel
				)


## One stretch of plateau wall with, when it is tall enough, its overhanging rim.
func _emit_wall_piece(
	surface: SurfaceTool,
	piece: Array,
	offset_from: Vector2,
	offset_to: Vector2,
	normal: Vector3,
	wall_color: Color,
	rim_color: Color,
	rim_height: float,
	overhang: float,
	bevel: float
) -> void:
	var start: Vector2 = piece[0]
	var end: Vector2 = piece[1]
	var top_a: float = piece[2]
	var top_b: float = piece[3]
	var low_a: float = piece[4]
	var low_b: float = piece[5]
	if top_a <= low_a + EPS and top_b <= low_b + EPS:
		return
	var rim := rim_height if minf(top_a - low_a, top_b - low_b) >= rim_height - .001 else 0.0
	_quad(
		surface,
		[
			Vector3(start.x, low_a, start.y),
			Vector3(end.x, low_b, end.y),
			Vector3(end.x, top_b - rim, end.y),
			Vector3(start.x, top_a - rim, start.y)
		],
		normal,
		wall_color,
		0.0
	)
	if rim <= 0:
		return
	var offset_a := offset_from.lerp(offset_to, piece[6])
	var offset_b := offset_from.lerp(offset_to, piece[7])
	var so := start + offset_a * overhang
	var eo := end + offset_b * overhang
	var si := start + offset_a * (overhang - bevel)
	var ei := end + offset_b * (overhang - bevel)
	var chamfer := minf(bevel, rim)
	# Flat cap from the plateau edge, a chamfer, the outer rim face and its underside.
	_quad(
		surface,
		[
			Vector3(si.x, top_a, si.y),
			Vector3(ei.x, top_b, ei.y),
			Vector3(end.x, top_b, end.y),
			Vector3(start.x, top_a, start.y)
		],
		Vector3.UP,
		rim_color,
		1.0
	)
	_quad(
		surface,
		[
			Vector3(so.x, top_a - chamfer, so.y),
			Vector3(eo.x, top_b - chamfer, eo.y),
			Vector3(ei.x, top_b, ei.y),
			Vector3(si.x, top_a, si.y)
		],
		(normal + Vector3.UP).normalized(),
		rim_color * .93,
		1.0
	)
	_quad(
		surface,
		[
			Vector3(so.x, top_a - rim, so.y),
			Vector3(eo.x, top_b - rim, eo.y),
			Vector3(eo.x, top_b - chamfer, eo.y),
			Vector3(so.x, top_a - chamfer, so.y)
		],
		normal,
		rim_color * .82,
		1.0
	)
	_quad(
		surface,
		[
			Vector3(start.x, top_a - rim, start.y),
			Vector3(end.x, top_b - rim, end.y),
			Vector3(eo.x, top_b - rim, eo.y),
			Vector3(so.x, top_a - rim, so.y)
		],
		Vector3.DOWN,
		rim_color * .5,
		1.0
	)
	# Square end caps close the rim wherever it stops.
	var tangent := Vector3(end.x - start.x, 0, end.y - start.y).normalized()
	for cap in [[start, so, si, top_a, -tangent], [end, eo, ei, top_b, tangent]]:
		var edge_point: Vector2 = cap[0]
		var outer: Vector2 = cap[1]
		var inner: Vector2 = cap[2]
		var top: float = cap[3]
		_quad(
			surface,
			[
				Vector3(edge_point.x, top - rim, edge_point.y),
				Vector3(outer.x, top - rim, outer.y),
				Vector3(outer.x, top - chamfer, outer.y),
				Vector3(edge_point.x, top - chamfer, edge_point.y)
			],
			cap[4],
			rim_color * .75,
			1.0
		)
		_quad(
			surface,
			[
				Vector3(edge_point.x, top - chamfer, edge_point.y),
				Vector3(outer.x, top - chamfer, outer.y),
				Vector3(inner.x, top, inner.y),
				Vector3(edge_point.x, top, edge_point.y)
			],
			cap[4],
			rim_color * .75,
			1.0
		)


## A solid stone curb along the side of a slope: it follows the slope a little
## above it, meets the plateau top flush and ends in a square face at the bottom,
## so the side never thins out to a knife edge.
func _emit_curb(
	surface: SurfaceTool,
	region: Dictionary,
	start: Vector2,
	end: Vector2,
	low_a: float,
	low_b: float,
	normal: Vector3,
	wall_color: Color,
	curb_color: Color
) -> void:
	var high := maxf(region.start_height, region.end_height)
	var slope_a := region_height(region, start)
	var slope_b := region_height(region, end)
	var top_a := minf(slope_a + CURB_HEIGHT, high)
	var top_b := minf(slope_b + CURB_HEIGHT, high)
	if top_a <= low_a + EPS and top_b <= low_b + EPS:
		return
	var inward := Vector2(-normal.x, -normal.z) * CURB_WIDTH
	var start_in := start + inward
	var end_in := end + inward
	var inner_a := region_height(region, start_in)
	var inner_b := region_height(region, end_in)
	_quad(
		surface,
		[
			Vector3(start.x, low_a, start.y),
			Vector3(end.x, low_b, end.y),
			Vector3(end.x, top_b, end.y),
			Vector3(start.x, top_a, start.y)
		],
		normal,
		wall_color,
		0.0
	)
	_quad(
		surface,
		[
			Vector3(start.x, top_a, start.y),
			Vector3(end.x, top_b, end.y),
			Vector3(end_in.x, top_b, end_in.y),
			Vector3(start_in.x, top_a, start_in.y)
		],
		Vector3.UP,
		curb_color,
		1.0
	)
	_quad(
		surface,
		[
			Vector3(start_in.x, inner_a, start_in.y),
			Vector3(end_in.x, inner_b, end_in.y),
			Vector3(end_in.x, top_b, end_in.y),
			Vector3(start_in.x, top_a, start_in.y)
		],
		-normal,
		curb_color * .8,
		1.0
	)
	# Square face where the curb stands clear of the slope (its low end); the high
	# end meets the plateau flush and needs none.
	var tangent := Vector3(end.x - start.x, 0, end.y - start.y).normalized()
	for cap in [
		[start, start_in, top_a, low_a, inner_a, slope_a, -tangent],
		[end, end_in, top_b, low_b, inner_b, slope_b, tangent]
	]:
		var outer_point: Vector2 = cap[0]
		var inner_point: Vector2 = cap[1]
		var top: float = cap[2]
		if top - cap[5] < CURB_HEIGHT - .001:
			continue
		_quad(
			surface,
			[
				Vector3(outer_point.x, cap[3], outer_point.y),
				Vector3(inner_point.x, cap[4], inner_point.y),
				Vector3(inner_point.x, top, inner_point.y),
				Vector3(outer_point.x, top, outer_point.y)
			],
			cap[6],
			curb_color * .85,
			1.0
		)


## Doors standing on a ground edge: side (0 north, 1 east, 2 south, 3 west), position
## along that edge, half gap width and the doorway height.
func _door_openings() -> Array[Dictionary]:
	var openings: Array[Dictionary] = []
	for child in get_children():
		# Doors set into a plateau wall never open the outer boundary.
		if not child is LevelDoor or child.cliff_door:
			continue
		var p: Vector3 = child.position
		var distances := [
			absf(p.z + size.y / 2), absf(p.x - size.x / 2), absf(p.z - size.y / 2), absf(p.x + size.x / 2)
		]
		for side in 4:
			if distances[side] <= .75:
				openings.append(
					{
						"side": side,
						"along": p.x if side % 2 == 0 else p.z,
						"half": child.width / 2 + .3,
						"height": child.height + (.45 if child.style == LevelDoor.Style.STONE_ARCH else .22)
					}
				)
				break
	return openings


func _side_normal(side: int) -> Vector2:
	return [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][side]


func _edge_point(side: int, along: float) -> Vector2:
	return [
		Vector2(along, -size.y / 2), Vector2(size.x / 2, along), Vector2(along, size.y / 2), Vector2(-size.x / 2, along)
	][side]


## Wall pieces just outside each ground edge, with gaps where doors stand.
func _boundary_segments(thickness: float) -> Array[Dictionary]:
	var openings := _door_openings()
	var segments: Array[Dictionary] = []
	for side in 4:
		var length: float = size.x if side % 2 == 0 else size.y
		var intervals: Array = [[-length / 2 - thickness, length / 2 + thickness]]
		for opening in openings:
			if opening.side != side:
				continue
			var gap_from: float = opening.along - opening.half
			var gap_to: float = opening.along + opening.half
			var next: Array = []
			for interval in intervals:
				if gap_to <= interval[0] or gap_from >= interval[1]:
					next.append(interval)
					continue
				if gap_from > interval[0]:
					next.append([interval[0], gap_from])
				if gap_to < interval[1]:
					next.append([gap_to, interval[1]])
			intervals = next
		var outward := _side_normal(side)
		var offset: float = (size.y if side % 2 == 0 else size.x) / 2 + thickness / 2
		for interval in intervals:
			var extent: float = interval[1] - interval[0]
			if extent < .01:
				continue
			var middle: float = (interval[0] + interval[1]) / 2
			var centre := (
				Vector2(middle, 0) if side % 2 == 0 else Vector2(0, middle)
			) + outward * offset
			segments.append(
				{
					"side": side,
					"centre": centre,
					"size": Vector2(extent, thickness) if side % 2 == 0 else Vector2(thickness, extent)
				}
			)
	return segments


## Visible room walls: tall on the north and west, cut away on the camera sides,
## with a header above doors in the tall walls.
func _emit_room_walls(mesh: ArrayMesh) -> void:
	var settings := style_for(null)
	var house := room_look == 1
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The house look uses plain vertex colours (sRGB); the stone look the cliff shader.
	var wall_color := settings.cliff_color if house else settings.cliff_color.srgb_to_linear()
	var top_color := settings.cliff_color if house else settings.cliff_rim_color.srgb_to_linear()
	var wood := settings.cliff_rim_color
	var timber := wood.darkened(.6)
	var emitted := false
	for segment in _boundary_segments(ROOM_WALL_THICKNESS):
		var low: bool = not segment.side in [0, 3]
		var tall: float = cutaway_height if low else wall_height
		if tall <= .01:
			continue
		var colour: Color = wood if house and low else wall_color
		var centre: Vector2 = segment.centre
		var extent: Vector2 = segment.size
		if segment.side % 2 == 1:
			# The north and south walls own the corners; overlapping boxes would flicker.
			var from := maxf(centre.y - extent.y / 2, -size.y / 2)
			var to := minf(centre.y + extent.y / 2, size.y / 2)
			if to - from < .01:
				continue
			centre.y = (from + to) / 2
			extent.y = to - from
		_emit_box(surface, Vector3(centre.x, tall / 2, centre.y), Vector3(extent.x, tall, extent.y), colour, wood if house and low else top_color)
		emitted = true
	for opening in _door_openings():
		if not opening.side in [0, 3] or opening.height >= wall_height:
			continue
		var header: float = wall_height - opening.height
		var outward := _side_normal(opening.side)
		var centre := _edge_point(opening.side, opening.along) + outward * ROOM_WALL_THICKNESS / 2
		var span: Vector2 = Vector2(outward.y, outward.x).abs() * opening.half * 2 + outward.abs() * ROOM_WALL_THICKNESS
		_emit_box(surface, Vector3(centre.x, opening.height + header / 2, centre.y), Vector3(span.x, header, span.y), wall_color, top_color)
		emitted = true
	if house:
		_emit_house_timber(surface, timber)
		emitted = true
	if not emitted:
		return
	if house:
		var plain := StandardMaterial3D.new()
		plain.vertex_color_use_as_albedo = true
		plain.vertex_color_is_srgb = true
		plain.roughness = .92
		surface.set_material(plain)
		surface.commit(mesh)
		return
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/level_cliff.gdshader")
	material.set_shader_parameter("cliff_texture", settings.cliff_texture)
	material.set_shader_parameter("has_cliff_texture", settings.cliff_texture != null)
	material.set_shader_parameter("cliff_texture_scale", settings.cliff_texture_scale)
	material.set_shader_parameter("block_height", HEIGHT_STEP)
	material.set_shader_parameter("cliff_pattern", settings.cliff_pattern)
	surface.set_material(material)
	surface.commit(mesh)


## House look: a dark foundation under floor and walls, and timber posts with a
## beam along the inside of the tall north and west walls, skipping doorways.
func _emit_house_timber(surface: SurfaceTool, timber: Color) -> void:
	var half := size / 2
	var margin := ROOM_WALL_THICKNESS + .2
	_emit_box(surface, Vector3(0, -.36, 0), Vector3(size.x + margin * 2, .5, size.y + margin * 2), timber, timber)
	var openings := _door_openings()
	for side in [0, 3]:
		var length: float = size.x if side == 0 else size.y
		var inward := -_side_normal(side)
		var count := maxi(2, roundi(length / 2.2))
		for i in count + 1:
			var along := -length / 2 + .08 + (length - .16) * i / count
			# The north-west corner post belongs to the north wall.
			var blocked: bool = side == 3 and i == 0
			for opening in openings:
				if opening.side == side and absf(opening.along - along) < opening.half + .1:
					blocked = true
			if blocked:
				continue
			var at := _edge_point(side, along) + inward * .06
			_emit_box(surface, Vector3(at.x, wall_height / 2, at.y), Vector3(.13, wall_height, .13), timber, timber)
		# The west beam starts past the north beam so the two never overlap.
		var skip := 0.0 if side == 0 else .2
		var beam := _edge_point(side, skip / 2) + inward * .06
		var beam_size := Vector2(length, .15) if side == 0 else Vector2(.15, length - skip)
		_emit_box(surface, Vector3(beam.x, wall_height - .25, beam.y), Vector3(beam_size.x, .15, beam_size.y), timber, timber)


func _emit_box(surface: SurfaceTool, centre: Vector3, box: Vector3, color: Color, top_color: Color) -> void:
	var h := box / 2
	var faces := [
		[Vector3.UP, [Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]],
		[Vector3.FORWARD, [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z)]],
		[Vector3.BACK, [Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]],
		[Vector3.LEFT, [Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z)]],
		[Vector3.RIGHT, [Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z)]]
	]
	for face in faces:
		var corners: Array = []
		for corner in face[1]:
			corners.append(centre + corner)
		var top: bool = face[0] == Vector3.UP
		_quad(surface, corners, face[0], top_color if top else color, 1.0 if top else 0.0)


func _near_eased_ramp(a: Vector2, b: Vector2, regions: Array[Dictionary]) -> bool:
	var box := Rect2(a, Vector2.ZERO).expand(b).grow(.01)
	for other in regions:
		var curved: bool = (
			(other.has("ramp_start") and not other.get("stairs", false)) or other.has("water")
		)
		if not curved:
			continue
		var ramp_box := Rect2(other.polygon[0], Vector2.ZERO)
		for point in other.polygon:
			ramp_box = ramp_box.expand(point)
		if box.intersects(ramp_box.grow(.01)):
			return true
	return false


## A plain wall between two smooth surfaces for the collision mesh only.
func _collision_wall(
	start: Vector2, end: Vector2, low_a: float, low_b: float, top_a: float, top_b: float
) -> void:
	if top_a <= low_a + EPS and top_b <= low_b + EPS:
		return
	start = (start * GRID_INV).round() / GRID_INV
	end = (end * GRID_INV).round() / GRID_INV
	if _wall_collision == null:
		_wall_collision = SurfaceTool.new()
		_wall_collision.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices := [
		Vector3(start.x, low_a, start.y),
		Vector3(end.x, low_b, end.y),
		Vector3(end.x, maxf(top_b, low_b), end.y),
		Vector3(start.x, maxf(top_a, low_a), start.y)
	]
	var line := end - start
	var order := _front_order(vertices, Vector3(line.y, 0, -line.x).normalized())
	for triangle in [order.slice(0, 3), order.slice(3, 6)]:
		var first: Vector3 = vertices[triangle[1]] - vertices[triangle[0]]
		var second: Vector3 = vertices[triangle[2]] - vertices[triangle[0]]
		# A wall that tapers to nothing at one end leaves a zero-area triangle.
		if first.cross(second).length_squared() <= .0000000001:
			continue
		for index in triangle:
			_wall_collision.add_vertex(vertices[index])


static func _quad(
	surface: SurfaceTool, vertices: Array, normal: Vector3, color: Color, rim: float
) -> void:
	var order := _front_order(vertices, normal)
	for triangle in [order.slice(0, 3), order.slice(3, 6)]:
		var first: Vector3 = vertices[triangle[1]] - vertices[triangle[0]]
		var second: Vector3 = vertices[triangle[2]] - vertices[triangle[0]]
		if first.cross(second).length_squared() <= EPS * EPS:
			continue
		for index in triangle:
			surface.set_normal(normal)
			surface.set_color(color)
			surface.set_uv2(Vector2(rim, 0))
			surface.add_vertex(vertices[index])
