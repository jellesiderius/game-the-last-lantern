@tool
class_name RampConnection
extends RefCounted
## Fits a rectangular ramp flush to one edge of an existing plateau.


static func find_attachment(ramp: LevelRamp, curve: Curve3D, ground: LevelTerrain) -> Dictionary:
	if curve.point_count != 2:
		return {}
	for endpoint in [1, 0]:
		var point := ramp.transform * curve.get_point_position(endpoint)
		for child in ground.get_children():
			if not child is LevelTerrace or child.height <= 0 or child.connected_ramp() == ramp:
				continue
			if Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), polygon(child)):
				var result := fit(ramp, curve, child, endpoint)
				if not result.is_empty():
					result.terrace = child
					result.endpoint = endpoint
					return result
	return {}


static func polygon(terrace: LevelTerrace) -> PackedVector2Array:
	var points := PackedVector2Array()
	if terrace.curve:
		for i in terrace.curve.point_count:
			var point := terrace.transform * terrace.curve.get_point_position(i)
			points.append(Vector2(point.x, point.z))
	if points.size() > 1 and points[0].is_equal_approx(points[-1]):
		points.remove_at(points.size() - 1)
	if Geometry2D.is_polygon_clockwise(points):
		points.reverse()
	return points


static func fit(
	ramp: LevelRamp, curve: Curve3D, terrace: LevelTerrace, endpoint: int, prefer_endpoint := false
) -> Dictionary:
	var border := polygon(terrace)
	if border.size() < 3 or curve.point_count != 2:
		return {}
	var free := ramp.transform * curve.get_point_position(1 - endpoint)
	var requested := ramp.transform * curve.get_point_position(endpoint)
	var target_height := terrace.height + terrace.position.y
	var from := Vector2(free.x, free.z)
	var wanted := Vector2(requested.x, requested.z)
	var best := INF
	var result := {}
	for i in border.size():
		var a := border[i]
		var b := border[(i + 1) % border.size()]
		var length := a.distance_to(b)
		if length < .55:
			continue
		var tangent := (b - a) / length
		var outward := Vector2(tangent.y, -tangent.x)
		if (from - a).dot(outward) <= .05:
			continue
		var width := minf(ramp.width, length - .04)
		var anchor := wanted if prefer_endpoint else from
		var along := clampf((anchor - a).dot(tangent), width / 2 + .02, length - width / 2 - .02)
		var end := a + tangent * along
		var distance := maxf((from - end).dot(outward), absf(target_height - free.y) / .9 + .05)
		var start := end + outward * distance
		var side := tangent * width / 2
		var footprint := PackedVector2Array([end - side, end + side, start + side, start - side])
		var valid := true
		for overlap in Geometry2D.intersect_polygons(footprint, border):
			if LevelTerrain.polygon_area(overlap) > .00001:
				valid = false
		if not valid:
			continue
		var score := start.distance_squared_to(from) + end.distance_squared_to(wanted)
		if score < best:
			best = score
			var edited := curve.duplicate() as Curve3D
			edited.set_point_position(
				endpoint, ramp.transform.affine_inverse() * Vector3(end.x, target_height, end.y)
			)
			edited.set_point_position(
				1 - endpoint, ramp.transform.affine_inverse() * Vector3(start.x, free.y, start.y)
			)
			result = {"curve": edited, "width": width, "footprint": footprint}
	return result
